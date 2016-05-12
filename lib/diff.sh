#!/bin/bash
# 
#   Copyright (C) 2013, 2014, 2015, 2016 Linaro, Inc
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

#
# diffall dir1 dir2
# Takes a two directories and compares the sum files
difftwodirs ()
{
    local prev="$1"
    local next="$2"

    # Don't diff it's already been done
    if test -e $next/testsuite-diff.txt; then
	return 0
    fi
    
    echo "Diffing: ${prev} against ${next}..."
    local resultsdir="${local_builds}/test-results"

    local pversion="`echo ${prev} | grep -o "test-results/abe[0-9a-z]*" | grep -o "abe[0-9a-z]*"`"
    local nversion="`echo ${next} | grep -o "test-results/abe[0-9a-z]*" | grep -o "abe[0-9a-z]*"`"

    diffdir="${resultsdir}/diffof-${pversion}-${nversion}"
    mkdir -p ${diffdir}
    unxz -f ${prev}/*.sum.xz
    unxz -f ${next}/*.sum.xz
    for i in gcc gdb glibc egibc newlib binutils; do
	if test -e ${prev}/$i.sum -a -e ${next}/$i.sum; then
	    diff -U 0 ${prev}/$i.sum ${next}/$i.sum 2>&1 | egrep '^[+-]PASS|^[+-]FAIL|^[+-]XPASS|^[+-]XFAIL' 2>&1 | sort -k 2 2>&1 > ${diffdir}/diff-$i.txt
	    if test -s ${diffdir}/diff-$i.txt; then
		echo "Comparison between:" > ${diffdir}/$i-test-results.txt
		echo "	${prev}/$i.sum and" >> ${diffdir}/$i-test-results.txt
		echo "	${next}/$i.sum" >> ${diffdir}/$i-test-results.txt
	    fi
	    if test `grep -c ^\+PASS ${diffdir}/diff-$i.txt` -gt 0; then
		echo "" >> ${diffdir}/$i-test-results.txt
		echo "Tests that were failing that now PASS" >> ${diffdir}/$i-test-results.txt
		echo "-------------------------------------" >> ${diffdir}/$i-test-results.txt
		grep ^\+PASS ${diffdir}/diff-$i.txt >> ${diffdir}/$i-test-results.txt
	    fi
	    if test `grep -c ^\+FAIL ${diffdir}/diff-$i.txt` -gt 0; then
		echo "" >> ${diffdir}/$i-test-results.txt
		echo "Tests that were passing that now FAIL" >> ${diffdir}/$i-test-results.txt
		echo "-------------------------------------" >> ${diffdir}/$i-test-results.txt
		grep ^\+FAIL ${diffdir}/diff-$i.txt >> ${diffdir}/$i-test-results.txt
	    fi
	    if test `grep -c ^\+XPASS ${diffdir}/diff-$i.txt` -gt 0; then
		echo "" >> ${diffdir}/$i-test-results.txt
		echo "Tests that were expected failures that now PASS" >> ${diffdir}/$i-test-results.txt
		echo "-----------------------------------------------" >> ${diffdir}/$i-test-results.txt
		grep ^\+XPASS ${diffdir}/diff-$i.txt >> ${diffdir}/$i-test-results.txt
	    fi
	    if test `grep -c ^\+UN ${diffdir}/diff-$i.txt` -gt 0; then
		echo "" >> ${diffdir}/$i-test-results.txt
		echo "Tests that have problems" >> ${diffdir}/$i-test-results.txt
		echo "------------------------" >> ${diffdir}/$i-test-results.txt
		grep ^\+UN ${diffdir}/diff-$i.txt >> ${diffdir}/$i-test-results.txt
	    fi
	    if test -e ${diffdir}/$i-test-results.txt; then
		mailto "[TEST] $i had regressions between ${prev} and ${next}!" ${diffdir}/$i-test-results.txt
	    else
		mailto "[TEST] $i had ZERO regressions between ${prev} and ${next}!"
	    fi
	fi
    done
    
#    rm -fr ${diffdir}
    local incr=`expr ${incr} + 1`

    xz -f ${prev}/*.sum
    xz -f ${next}/*.sum
}

#
# diffall "list"
# Takes a list of directories and compares them one by one in sequence.
diffall ()
{
    local count="`echo $1| wc -w`"
    if test ${count} -gt 0; then
	declare -a foo=($1)
	local incr=0
	while test ${incr} -lt ${count}; do
	    local next=`expr ${incr} + 1`
	    if test ${next} = ${count}; then
		return 0
	    fi

	    difftwodirs ${foo[${incr}]} ${foo[${next}]}
	    local incr=`expr ${incr} + 1`
	done
    fi
}


# This produces the test file, who's header needs to look like this:
#
# Difference in testsuite results between:
#  gcc-linaro-4.8-2014.01 build i686-precise-abe461-oort8-i686r1
# and the one before it:
#  gcc-linaro-4.8-2013.12 build i686-precise-abe461-oort2-i686r1

# ------
testfile()
{

    orig="`echo $1 | grep -o "[a-z]*-linaro[0-9\.\-]*"`"
    next="`echo $2 | grep -o "[a-z]*-linaro[0-9\.\-]*"`"
    origdir="`basename $1`"
    nextdir="`basename $2`"
 
    cat <<EOF > ${diffdir}/testsuite-diff.txt
Difference in testsuite results between:
 ${orig} build ${origdir}
and the one before it:
 ${next} build ${nextdir}

------
EOF
    
    cat ${diffdir}/diff.txt  >> ${diffdir}/testsuite-diff.txt
    cp  ${diffdir}/testsuite-diff.txt  $1
    cp  ${diffdir}/testsuite-diff.txt  $2
}

# $1 - the subject for the email
# $2 - the body of the email
# $3 - optional user to send email to
mailto()
{
    if test x"${email}" = xyes; then
	echo "Mailing test results!"
	mail -s "$1" tcwg-test-results@gnashdev.org < $2
	if test x"$3" != x; then
	    mail -s "$1" $3 < $2
	fi
    else
	echo "$1"
	echo "===================== $1 ================"
	cat $2
    fi
}
