#!/bin/bash

set -e

# Here is the source as pushed to the repository
if [ -z "$MASTERFILES_SOURCE" ] ; then
    echo "Missing environment variable: MASTERFILES_SOURCE" >&2
    exit 1
fi
# Here is where the new release was created by the build
if [ -z "$MASTERFILES_OUTPUT" ] ; then
    echo "Missing environment variable: MASTERFILES_OUTPUT" >&2
    exit 1
fi
# Here is where release history will be pulled and the release committed
if [ -z "$MASTERFILES_RELEASE" ] ; then
    echo "Missing environment variable: MASTERFILES_RELEASE" >&2
    exit 1
fi
# These specify where to pull the history and where to push the built releases
if [ -z "$MASTERFILES_RELEASE_URL" ] ; then
    echo "Missing environment variable: MASTERFILES_RELEASE_URL" >&2
    exit 1
fi
if [ -z "$MASTERFILES_RELEASE_BRANCH" ] ; then
    echo "Missing environment variable: MASTERFILES_RELEASE_BRANCH" >&2
    exit 1
fi

# Inspect the author properties from the source project
cd "$MASTERFILES_SOURCE"
# HEAD of source branch should be tagged as a release
tag="$(git describe --exact-match HEAD)"
msg="$tag - $(git for-each-ref --format '%(subject)' refs/tags/$tag)"
author="$(git for-each-ref --format '%(taggername)' refs/tags/$tag)"
email="$(git for-each-ref --format '%(taggeremail)' refs/tags/$tag)"

# Make the release repository
git clone --depth 1 "$MASTERFILES_RELEASE_URL" "$MASTERFILES_RELEASE"
cd "$MASTERFILES_RELEASE"
if git ls-remote --exit-code origin "$MASTERFILES_RELEASE_BRANCH" ; then
    git checkout "$MASTERFILES_RELEASE_BRANCH"
else
    git checkout --orphan "$MASTERFILES_RELEASE_BRANCH"
fi

# Sync the new changes
rsync -a --delete \
    --exclude '.git' \
    "$MASTERFILES_OUTPUT/" "$MASTERFILES_RELEASE/"

# Commit and push the new release
git config user.name "$author"
git config user.email "$email"

git add -A .
git commit -m "$msg"
git push origin "$MASTERFILES_RELEASE_BRANCH"
