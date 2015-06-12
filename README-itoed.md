# Custom CFEngine Masterfiles

These masterfiles are based on
[cfengine/masterfiles](https://github.com/cfengine/masterfiles).

Running the build will produce a finished masterfiles directory and running
the deploy will push the contents to a release branch of a git repository.

This release branch can then be checked out and used as the basis for building
new policies.

To use policies based on these masterfiles on a host where CFEngine has been
installed, empty the policies created by the installation of CFEngine at
`/var/cfengine/mastefiles`, and clone the repository of the policies based on
these masterfiles to that location.

Once `cf-execd` has started, every time `update.cf` is executed it will run
bundle `itoed-update` to pull changes from the upstream of the checked out
branch.

### Build and test

    docker-compose run --rm masterfiles

### Build and test with Wercker CLI

    wercker build
