#!/bin/sh

# These store all the data used for this test run that can be overwritten by
# command line options.

# Start by assuming it's a native build
build="`${topdir}/config.guess`"
target=${build}
host=${target}

gcc="`which gcc`"
host_gcc_version="`${gcc} -v 2>&1 | tail -1`"
binutils="default"
# This is the default clibrary and can be overridden on the command line.
clibrary="eglibc"
snapshots="default"
configfile="default"
dbuser="default"
dbpasswd="default"

manifest=

# This doesn't do any real work, just prints the configure options and make commands
dryrun=no

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
verbose=1
network=""
runtests=no
ccache=no

# These are flags for the --disable option to cbuild, which are enabled by default
bootstrap=no
makecheck=no
tarballs=no
install=yes
release=""

if test x"${BUILD_NUMBER}" = x; then
    export BUILD_NUMBER=${RANDOM}
fi

# source a user specific config file for commonly used configure options.
# These overide any of the above values.
if test -e ~/.cbuildrc; then
    . ~/.cbuildrc
fi
