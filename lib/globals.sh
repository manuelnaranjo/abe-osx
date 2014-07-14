#!/bin/sh
# 
#   Copyright (C) 2013, 2014 Linaro, Inc
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
# 

# These store all the data used for this test run that can be overwritten by
# command line options.

# Start by assuming it's a native build
build="${build}"
host="${build}"
target="${host}"

gcc="`which gcc`"
host_gcc_version="`${gcc} -v 2>&1 | tail -1`"
binutils="default"
# This is the default clibrary and can be overridden on the command line.
clibrary="eglibc"
snapshots="default"
configfile="default"
dbuser="default"
dbpasswd="default"

# Don't set this unless you need to modify it.
default_march=

manifest=

# The prefix for installing the toolchain
prefix=

# The default timeout.  If you're on a wireless network this
# might not be sufficient and can be overridden at the command
# line.
wget_timeout=10
wget_quiet=
# Try something like "dot:mega"
wget_progress_style=

# This doesn't do any real work, just prints the configure options and make commands
dryrun=no

#
launchpad_id=
svn_id=

# config values for the build machine
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
parallel=no
nodepends=no
verbose=1
network=""
runtests=no
ccache=no

release=""

if test x"${BUILD_NUMBER}" = x; then
    export BUILD_NUMBER=${RANDOM}
fi

# source a user specific config file for commonly used configure options.
# These overide any of the above values.
if test -e ~/.cbuildrc; then
    . ~/.cbuildrc
fi
