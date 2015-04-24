#!/bin/bash

set -e
if [ -n "$MASTERFILES_DEBUG" ] ; then
    set -x
fi

# This should be a read-only mounted directory
if [ -z "$MASTERFILES_SOURCE" ] ; then
    echo "Missing environment variable: MASTERFILES_SOURCE" >&2
    exit 1
fi
# The build process will litter the work directory
if [ -z "$MASTERFILES_WORKDIR" ] ; then
    echo "Missing environment variable: MASTERFILES_WORKDIR" >&2
    exit 1
fi
# The parent directory for the masterfiles output
if [ -z "$MASTERFILES_HOME" ] ; then
    echo "Missing environment variable: MASTERFILES_HOME" >&2
    exit 1
fi
# The output directory is a git repository for the build
if [ -z "$MASTERFILES_OUTPUT" ] ; then
    echo "Missing environment variable: MASTERFILES_OUTPUT" >&2
    exit 1
fi
# A git repository will be initialized here after the integration test policy
# is built
if [ -z "$MASTERFILES_TEST_OUTPUT" ] ; then
    echo "Missing environment variable: MASTERFILES_TEST_OUTPUT" >&2
    exit 1
fi

# Duplicate source project as a work directory to run build
# If the source is a mounted volume, it may be read-only as
# no files should be created in it
rsync -a --delete --exclude "*.sw[op]" \
    $MASTERFILES_SOURCE/ $MASTERFILES_WORKDIR/

echo "Build started"

# Build masterfiles in workd directory
cd $MASTERFILES_WORKDIR
./autogen.sh --prefix $MASTERFILES_HOME
make install

echo "Build complete"

echo "Preparing for validation and test"

# Copy the built release
rsync -a --delete \
    "$MASTERFILES_OUTPUT/" "$MASTERFILES_TEST_OUTPUT/"

# Prevent CFEngine update from trying to start the services
sed -i '/"cfe_internal_update_processes",/d' \
    "$MASTERFILES_TEST_OUTPUT/update.cf"

# Prevent inventory bundle from refreshing packages
disable_pkg='"disable_inventory_package_refresh" expression =>'
sed -i "s/$disable_pkg \"!any\"/$disable_pkg \"any\"/" \
    "$MASTERFILES_TEST_OUTPUT/def.cf"

# Prevent inventory bundle from refreshing packages
disable_pkg='"disable_inventory_package_refresh" expression =>'
sed -i "s/$disable_pkg \"!any\"/$disable_pkg \"any\"/" \
    "$MASTERFILES_TEST_OUTPUT/def.cf"

# Enable autorun bundles for test
enable_autorun='"services_autorun" expression =>'
sed -i "s/$enable_autorun \"!any\"/$enable_autorun \"any\"/" \
    "$MASTERFILES_TEST_OUTPUT/def.cf"
# Always print greeting in hello.cf
sed -i "/verbose_mode::/d" \
    "$MASTERFILES_TEST_OUTPUT/services/autorun/hello.cf"

# Create the git repository to be the origin for the test

export GIT_AUTHOR_NAME="test"
export GIT_AUTHOR_EMAIL="test@example.com"
export GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME"
export GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"

cd "$MASTERFILES_TEST_OUTPUT"

git init
git add .
git commit -q -m "Initial commit"

# Clear the default masterfiles created when CFEngine was installed and clone
# the test origin
rm -rf /var/cfengine/masterfiles
mkdir /var/cfengine/masterfiles
chmod 700 /var/cfengine/masterfiles

git clone "$MASTERFILES_TEST_OUTPUT" /var/cfengine/masterfiles

echo "Validating the policy"

# Use CFEngine to validate policies
if ! cf-promises -f /var/cfengine/masterfiles/promises.cf ; then
    echo "ERROR: Validation of promises.cf failed" >&2
    exit 1
fi
if ! cf-promises -f /var/cfengine/masterfiles/update.cf ; then
    echo "ERROR: Validation of update.cf failed" >&2
    exit 1
fi

echo "Policies passed validation"

#
# To test the policies, cf-serverd needs to be started, as it is
# required by update.cf to copy the policies from
# /var/cfengine/masterfiles to /var/cfengine/inputs
#

# Bootstrap will run first update to copy masterfiles to inputs
cf-agent -B $(uname -n)
# Run policy
cf-agent -K

# Make an arbitrary change to the origin to test update.cf
sed -i 's/Hello/Hello again/' \
    "$MASTERFILES_TEST_OUTPUT/services/autorun/hello.cf"
git add .
git commit -q -m "Change greeting in hello.cf"

echo 'Testing the policy'

# Run update again
cf-agent -Kf update.cf

# Run policy again
expected='R: hello_world_autorun: Hello again, this is an automatically loaded bundle'
actual="$(cf-agent -K)"

if [ "$expected" != "$actual" ] ; then
    echo '-------------------------------------------------------------' >&2
    echo "Policies failed test" >&2
    echo "Expected" >&2
    echo "$expected" >&2
    echo "But received" >&2
    echo "$actual" >&2
    exit 1
fi

echo "Policies passed test"
