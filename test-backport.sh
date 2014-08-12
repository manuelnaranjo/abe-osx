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
    echo "backport.sh --target triplet branch"
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
repo="gcc.git"

if test x"${git_reference_dir}" != x; then
    srcdir="${git_reference_dir}/gcc.git~${branch}"
    snapshots="${git_reference_dir}"
else
    srcdir="${local_snapshots}/gcc.git~${branch}"
    snapshots="${local_snapshots}"
fi

if ! test -e ${srcdir}; then
    (cd ${snapshots}/${repo} && git pull)
    git-new-workdir ${snapshots}/${repo} ${srcdir} ${branch}
else
    (cd ${srcdir} && git pull)
fi

# Get the last two revisions
declare -a revisions=(`cd ${srcdir} && git log -n 2 | grep ^commit | cut -d ' ' -f 2`)

resultsdir="/tmp/cbuild@"
i=0
while test $i -lt ${#revisions[@]}; do
    bash -x ${topdir}/cbuild2.sh --disable update --disable make_docs --check --target ${target} gcc=gcc.git@${revisions[$i]} --build all
    if test $? -gt 0; then
	echo "ERROR: Cbuild2 failed!"
	exit 1
    fi
    sums="`find ${local_builds}/${build}/${target} -name \*.sum`"
    logs="`find ${local_builds}/${build}/${target} -name \*.log`"
    manifest="`find ${local_builds}/${build}/${target} -name manifest.txt`"
    if test x"${sums}" != x; then
	mkdir -p ${resultsdir}${revisions[$i]}
	cp -f ${sums} ${logs} ${manifest} ${resultsdir}${revisions[$i]}/
	    # We don't need these files leftover from the DejaGnu testsuite
            # itself.
	xz -f ${resultsdir}${revisions[$i]}/*.{sum,log}
	rm -f ${resultsdir}${revisions[$i]}/{x,xXx,testrun}.sum
    fi
    i="`expr $i + 1`"
done

# Diff the two directories
${topdir}/tcwgweb.sh --tdir ${resultsdir}${revisions[0]} ${resultsdir}${revisions[1]}
