#!/bin/bash

# The top level is usually something like /space/build/gcc-linaro-4.8.3-2014.02
toplevel=$1

#
# Take all of the .sum files from two directories and generate the differences.
# This function is blatentely ripped off from cbuild-tools. (which is in cbuildv1)
#
# Example:
#  difftests.sh \
#   build/gcc-4.6+svn173209/logs/armv7l-maverick-cbuild113-ursa3-cortexa9r1 \
#   build/gcc-4.6+svn173722/logs/armv7l-maverick-cbuild114-ursa4-cortexa9r1
#
difftests ()
{
    previous=$1
    current=$2
    
    mkdir -p ${diffdir}/previous
    mkdir -p ${diffdir}/current
    
    # Copy across all logs
    cp ${previous}/*.sum* ${diffdir}/previous
    cp ${current}/*.sum* ${diffdir}/current
    # uncompress the files if need be
    for i in ${diffdir}/previous/*.xz; do
	unxz -f ${diffdir}/previous/*.xz ${diffdir}/current/*.xz
    done
    for i in ${diffdir}/current/*.xz; do
	unxz -f ${diffdir}/current/*.xz
    done
    
    # Pull out just the PASS/FAIL/etc lines and sort by test name
    #  * Change absolute path names to .../
    #  * Drop all limits tests
    #
    # for i in `find $dir -name "*.sum"`; do
    # 	grep -E '^[A-Z]+:' $i \
    #         | grep -Ev limits- \
    #         | grep -Ev /guality/ \
    #         | sed -r 's#/scratch/\w+/\w+/\w+/\w+/[^/]+#...#g' \
    #         | sed -r "s#UNSUPPORTED: .+/testsuite/#UNSUPPORTED: #" \
    #         | sort -k 2 > $i.tmp
    # 	mv $i.tmp $i
    # done

    diff -U 0 -r ${diffdir}/previous ${diffdir}/current | egrep '^[+-]PASS|^[+-]FAIL|^[+-]XPASS|^[+-]XFAIL' ${diffdir}/diff.txt | sort -k 2 > ${diffdir}/diff.txt


    # Drop anything but changes in test lines
    return `egrep -c -E '^[+-]PASS|^[+-]FAIL|^[+-]XPASS|^[+-]XFAIL' ${diffdir}/diff.txt`
}

#
# diffall "list"
# Takes a list of directories and compares them one by one in sequence.
diffall ()
{
    local count="`echo $1 | wc -w`"
    if test ${count} -gt 0; then
	declare -a foo=($1)
	local incr=0
	while test ${incr} -lt ${count}; do
	    local next=`expr ${incr} + 1`
	    if test ${next} = ${count}; then
		break
	    fi
	    echo "Diffing: ${foo[${incr}]} against ${foo[${next}]}..."
	    local pversion=`echo ${foo[${incr}]} | grep -o "cbuild[0-9]*" | sed -e 's:cbuild::'`
	    local cversion=`echo ${foo[${next}]} | grep -o "cbuild[0-9]*" | sed -e 's:cbuild::'`
	    diffdir="${toplevel}/diffof-${pversion}-${cversion}"
	    rm -f ${foo[${incr}]}/testsuite-diff.txt
	    rm -f ${foo[${next}]}/testsuite-diff.txt
	    mkdir -p ${diffdir}
#	    diff -u -r ${foo[${incr}]} ${foo[${next}]} 2>&1 > ${diffdir}/diff.txt
	    diff -u -r ${foo[${incr}]} ${foo[${next}]} | egrep '^[+-]PASS|^[+-]FAIL|^[+-]XPASS|^[+-]XFAIL' | sort -k 2 > ${diffdir}/diff.txt

	    #difftests ${foo[${incr}]} ${foo[${next}]}
	    if test `wc -l ${diffdir}/diff.txt | cut -d ' ' -f 1` -gt 0; then
		testfile ${foo[${incr}]} ${foo[${next}]}
	    fi
	    #rm -fr ${diffdir}
	    local incr=`expr ${incr} + 1`
	done
    fi

}


# This produces the test file, who's header needs to look like this:
#
# Difference in testsuite results between:
#  gcc-linaro-4.8-2014.01 build i686-precise-cbuild461-oort8-i686r1
# and the one before it:
#  gcc-linaro-4.8-2013.12 build i686-precise-cbuild461-oort2-i686r1

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

# ----------------------------------------------------------------------
# Start to actually do something

# First get all the cross compilers
arm="`find ${toplevel} -name \*-arm-\* | sort -n`"
if test x"${arm}" != x; then
    diffall "${arm}"
fi
armel="`find ${toplevel} -name \*-armel-\* | sort -n`"
if test x"${armel}" != x; then
    diffall "${armel}"
fi
armhf="`find ${toplevel} -name \*-armhf-\* | sort -n`"
if test x"${armhf}" != x; then
    diffall "${armhf}"
fi
aarch64="`find ${toplevel} -name \*-aarch64-\* | sort -n`"
if test x"${aarch64}" != x; then
    diffall "${aarch64}"
fi
aarch64be="`find ${toplevel} -name \*-aarch64_be-\* | sort -n`"
if test x"${aarch64be}" != x; then
    diffall "${aarch64be}"
fi

