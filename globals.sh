#!/bin/sh

# These store all the data used for this test run that can be overwritten by
# command line options.
build="`config.guess`"
target=
sysroot="`gcc -print-sysroot`"
gcc="`which gcc`"
binutils="default"
libc="default"
snapshots="default"
configfile="default"
dbuser="default"
dbpasswd="default"

# config values for the build machine
cpus=
libc_version=
kernel=
build_arch=
hostname=
distribution=

# These can be changed by environment variables
if test x"${SNAPSHOTS_URL}" != x -o x"${CBUILD_SNAPSHOTS}" != x; then
    snapshots="${SNAPSHOTS_URL}"
fi
if test x"${CBUILD_DBUSER}" != x; then
    dbuser="${CBUILD_DBUSER}"
fi
if test x"${CBUILD_DBPASSWD}" != x; then
    dbpasswd="${CBUILD_DBPASSWD}"
fi

clobber=no
force=no

