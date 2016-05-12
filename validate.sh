#!/bin/bash
# 
#   Copyright (C) 2014, 2015, 2016 Linaro, Inc
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

# Improve debug logs
PRGNAME=`basename $0`
PS4='+ $PRGNAME: ${FUNCNAME+"$FUNCNAME : "}$LINENO: '

# load the configure file produced by configure
if test -e "${PWD}/host.conf"; then
    . "${PWD}/host.conf"
else
    echo "Error: this script needs to be run from a configured Abe tree!" 1>&2
fi

if test $# -lt 4; then
    echo "ERROR: No revisions to build!"
    echo "validate.sh --target triplet 1111 2222 [3333...]"
    exit
fi

# For each revision we build the toolchain for this config triplet
if test `echo $* | grep -c target` -eq 0; then
    echo "ERROR: No target to build!"
    echo "validate.sh --target triplet 1111 2222 [3333...]"
    exit
fi
shift
target=$1
shift

# load commonly used functions
abe="`which $0`"
topdir="${abe_path}"
abe="`basename $0`"

. "${topdir}/lib/diff.sh" || exit 1

# Get the list of revisions to build and compare
declare -a revisions=($*)

# Get the path for the other scripts.
fullpath="`which $0`"
abe="`dirname ${fullpath}`/abe.sh"
tcwgweb="`dirname ${fullpath}`/tcwgweb.sh"

# We'll move all the results to subdirectories under here
resultsdir="${local_builds}/test-results"
mkdir -p ${resultsdir}

# Build all the specified revisions.
i=0
while test $i -lt ${#revisions[@]}; do
    stamps="`ls -C1 ${local_builds}/${build}/${target}/*-stage2-build.stamp`"
    if test "`echo ${stamps} | grep -c ${revisions[$i]}`" -eq 0; then
     	${abe} --target ${target} --check all gcc=gcc.git@${revisions[$i]} --build all
    fi
    sums="`find ${local_builds}/${build}/${target} -name \*.sum`"
    if test x"${sums}" != x; then
	mkdir -p ${resultsdir}/abe${revisions[$i]}/${build}-${target}
	cp ${sums} ${resultsdir}/abe${revisions[$i]}/${build}-${target}
	    # We don't need these files leftover from the DejaGnu testsuite
            # itself.
	xz -f ${resultsdir}/abe${revisions[$i]}/${build}-${target}/*.sum
	rm ${resultsdir}/abe${revisions[$i]}/${build}-${target}/{x,xXx,testrun}.sum
    fi
    i=`expr $i + 1`
done

# Compare the test results. If we only have 2, just do those. If there
# is a series, do them all in the order they were specified on the
# command line.
if test ${#revisions[@]} -eq 2; then
    difftwodirs ${resultsdir}/abe${revisions[0]} ${resultsdir}/abe${revisions[1]}
else
    j=0
    while test $j -lt ${#revisions[@]}; do
	first=abe${revisions[$j]}/${build}-${target}
	j=`expr $j + 1`
	second=abe${revisions[$j]}/${build}-${target}
	if test x"${second}" = x; then
	    break
	else
	    difftwodirs ${resultsdir}/${first} ${resultsdir}/${second}
	fi
    done
fi
