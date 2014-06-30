#!/bin/bash
# 
#   Copyright (C) 2014 Linaro, Inc
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

# load the configure file produced by configure
if test -e "${PWD}/host.conf"; then
    . "${PWD}/host.conf"
else
    echo "Error: this script needs to be run from a configured Cbuild2 tree!" 1>&2
fi

if test $# -lt 2; then
    echo "ERROR: No branches to build!"
    echo "backport.sh [branch name]"
    exit
fi
# For each revision we build the toolchain for this config triplet
if test `echo $* | grep -c target` -eq 0; then
    echo "ERROR: No target to build!"
    echo "backport.sh --target triplet 1111 2222 [3333...]"
    exit
fi
shift
target=$1
shift

# load commonly used functions
cbuild="`which $0`"
topdir="${cbuild_path}"
. "${topdir}/lib/diff.sh" || exit 1
. "${topdir}/lib/common.sh" || exit 1

# Get the list of revisions to build and compare

branch=$1
srcdir="`get_srcdir ${branch}`"
branchdir=${srcdir}~${branch}
repo="`get_git_repo $1`"
#git-new-workdir ${srcdir} ${branchdir} ${branch}
echo "FIXM: ${srcdir} ${branchdir} ${branch}"

declare -a revisions=(`cd ${local_snapshots}/${repo} && git log -n 2 | grep ^commit | cut -d ' ' -f 2`)

# Validate does the real work
shell="/bin/bash -x"
${shell} validate.sh --target ${target} ${revisions[0]} ${revisions[1]}
