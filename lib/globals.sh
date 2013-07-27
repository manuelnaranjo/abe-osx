#!/bin/sh

# These store all the data used for this test run that can be overwritten by
# command line options.
build="`gcc -v 2>&1 | grep Target: | cut -d ' ' -f 2`"
target=
sysroot="`gcc -print-sysroot`"
gcc="`which gcc`"
gcc_version="`${gcc} -v 2>&1 | tail -1`"
binutils="default"
libc="default"
snapshots="default"
configfile="default"
dbuser="default"
dbpasswd="default"

#
launchpad_id=
svn_id=

# config values for the build machine
cpus=
libc_version=
kernel=
build_arch=
hostname=
distribution=

# These are options flags to pass to make, usually just -j N as set by --parallel
make_flags=

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
interactive=no
nodepends=no

# source a user specific config file for commonly used configure options.
# These overide any of the above values.
if test -e ~/.cbuildrc; then
    . ~/.cbuildrc
fi
