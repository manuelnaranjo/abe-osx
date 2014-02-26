#!/bin/bash

#
# diffall dir1 dir2
# Takes a two directories and compares the sum file
difftwodirs ()
{
    local prev=$1
    local next=$2

    # Don't diff it's already been done
    if test -e $next/testsuite-diff.txt; then
	return 0
    fi
    
    echo "Diffing: ${prev} against ${next}..."
    local pversion=`echo ${prev} | grep -o "cbuild[0-9]*" | sed -e 's:cbuild::'`
    local cversion=`echo ${next} | grep -o "cbuild[0-9]*" | sed -e 's:cbuild::'`
    local toplevel="`dirname ${prev}`"

    diffdir="${toplevel}/diffof-${pversion}-${cversion}"
    mkdir -p ${diffdir}
#	    diff -u -r ${foo[${incr}]} ${foo[${next}]} 2>&1 | egrep '^[+-]PASS|^[+-]FAIL|^[+-]XPASS|^[+-]XFAIL' | sort -k 2 > ${diffdir}/diff.txt
    unxz ${prev}/*.sum.xz
    unxz ${next}/*.sum.xz
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
		mailto "[TEST] $i had regressions between ${pversion} and ${cversion}!" ${diffdir}/$i-test-results.txt
	    fi
	fi
    done
    
    # rm -fr ${diffdir}
    local incr=`expr ${incr} + 1`

    xz ${prev}/*.sum
    xz ${next}/*.sum
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

mailto()
{

    mail -s "$1" tcwg-test-results@linaro.org < $2
    # Hack till the mailing list lets me get messages
#    mail -s "$1" rob.savoye@linaro.org < $2
}

usage()
{
    echo "--find [directory] [pattern]"
    echo "--tdir [dir1] [dir2]"
}

# ----------------------------------------------------------------------
# Start to actually do something

# The top level is usually something like /space/build/gcc-linaro-4.8.3-2014.02

case "$1" in
    --find*)
	dirs="`find $2 -name $3 | sort -n`"
	for toplevel in ${dirs}; do
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
	done
	;;
    --tdir*)
	difftwodirs "$2" "$3"
	;;
    *)
	usage
	;;
esac
