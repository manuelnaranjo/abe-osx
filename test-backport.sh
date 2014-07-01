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

# To run, this script takes arguments in the same format as cbuild2.sh. The two
# arguments it needs is the target archicture to build, and the gcc backport
# branch name. Example:
# $PATH/test-backport.sh --target arm-linux-gnueabihf gcc.git~4.9-backport-209419

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

# load the configure file produced by configure
if test -e "${PWD}/host.conf"; then
    . "${PWD}/host.conf"
else
    echo "ERROR: no host.conf file!  Did you run configure?" 1>&2
    echo "${PWD}"
    exit 1
fi

# load commonly used functions
cbuild="`which $0`"
topdir="${cbuild_path}"
cbuild2="`basename $0`"

. "${topdir}/lib/common.sh" || exit 1

# Set the target triplet
target="$1"
shift

# Get the list of revisions to build and compare
branch=$1
srcdir="`get_srcdir ${branch}`"
repo="`get_git_repo $1`"
branch="`get_git_branch $1`"

# If the branch doesn't exist yet, create it
dir="${PWD}"
if ! test -e ${srcdir}; then
    cd ${local_snapshots}/${repo} && git pull
    git-new-workdir ${local_snapshots}/${repo} ${srcdir} ${branch}
else
    cd ${srcdir} && git pull
fi
cd ${dir}

# Get the last two revisions
declare -a revisions=(`cd ${srcdir} && git log -n 2 | grep ^commit | cut -d ' ' -f 2`)

i=0
while test $i -lt ${#revisions[@]}; do
    bash -x ${topdir}/cbuild2.sh --disable update --target ${target} --check gcc=gcc.git@${revisions[$i]} --build all
    if test $? -gt 0; then
	echo "ERROR: Cbuild2 failed!"
	exit 1
    fi
    sums="`find ${local_builds}/${build}/${target} -name \*.sum`"
    if test x"${sums}" != x; then
	mkdir -p ${resultsdir}/cbuild${revisions[$i]}/${build}-${target}
	cp ${sums} ${resultsdir}/cbuild${revisions[$i]}/${build}-${target}
	    # We don't need these files leftover from the DejaGnu testsuite
            # itself.
	xz -f ${resultsdir}/cbuild${revisions[$i]}/${build}-${target}/*.sum
	rm ${resultsdir}/cbuild${revisions[$i]}/${build}-${target}/{x,xXx,testrun}.sum
    fi
    i=`expr $i + 1`
done

