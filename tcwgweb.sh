#!/bin/bash
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

# $1 - the check.log file to scan
scancheck () 
{
    if ! test -e $1; then
#	echo "ERROR: $1 doesn't exist!"
	return 1
    fi

    # If there are no errors, just return
    if test "`egrep -c "^gcc: error: |^collect2: error: | undefined reference to | Download to .* failed, ssh: connect to host " $1`" -eq 0; then
	return 0
    fi

    local build="`basename $1`"
    local build="`basename ${build}`"

    # These are the errors we want to scan for
    declare -a errors=("^gcc: error:" "^collect2: error:" " undefined reference to" "Download to .* failed, ssh: connect to host")
    # These are the pretty print version for users for each error above
    declare -a errmsg=("compile error" "linker error" "undefined symbols" "target connectivity")
    rm -f /tmp/mail$$.txt
    echo "Testsuite build failures found in ${build}" > /tmp/mail$$.txt
    echo "" >> /tmp/mail$$.txt
    echo "Check build log: http://cbuild.validation.linaro.org/$1.xz" >> /tmp/mail$$.txt
    echo "" >> /tmp/mail$$.txt
    local i=0
    while test $i -lt ${#errors[@]}; do
	local count="`grep -c "${errors[$i]}" $1`"
	if test ${count} -gt 0; then
	    echo "# of ${errmsg[$i]}: ${count}" >> /tmp/mail$$.txt
	fi
	i="`expr $i + 1`"
    done

    mailto "Testsuite build failures in ${build}!" /tmp/mail$$.txt

    rm /tmp/mail$$.txt
}

# $1 - the current directory to use when comparing against the baseline
diffbaseline ()
{
    source $1/manifest.txt

    local baselines="/work/cbuildv2/baselines"
    local tool="`echo $2 | cut -d '-' -f 1`"
    local tool="`basename ${tool}`"
    local version="`echo $2 | grep -o "[0-9]\.[0-9]*" | head -1`"
    local dir="${baselines}/${tool}-${version}/"

    difftwodirs ${dir}/$1 $2
}

#
# diffall dir1 dir2
# Takes a two directories and compares the sum files
difftwodirs ()
{
    local prev=$1
    local next=$2

    if test -d ${prev}; then
	if ! test -e ${prev}/gcc.sum.xz; then
	    echo "WARNING: ${prev} has no test reults!"
	    return 0
	fi
    else
	echo "WARNING:${prev} doesn't exist!"
	return 0
    fi

    # Don't diff it's already been done
    if test -e $next/testsuite-diff.txt; then
	return 0
    fi
    
    echo "Diffing: ${prev} against ${next}..."
    local cversion="`grep 'gcc_revision=' ${next}/manifest.txt | cut -d '=' -f 2`"
    if test -e ${prev}/manifest.txt; then
	local pversion="`grep 'gcc_revision=' ${prev}/manifest.txt | cut -d '=' -f 2`"
    else
	local pversion=${cversion}
    fi
    local toplevel="`dirname ${prev}`"

    diffdir="/tmp/diffof-${pversion}-${cversion}"
    mkdir -p ${diffdir}
    local files="`ls ${prev}/*.sum.xz | wc -l`"
    if test ${files} -gt 0; then
	unxz ${prev}/*.sum.xz
    fi
    unxz ${next}/*.sum.xz
    unxz ${next}/check*.log.xz
    for i in gcc g\+\+ libstdc++ gfortran ld gas gdb glibc egibc newlib binutils libatomic libgomp libitm; do
	if test -e ${prev}/$i.sum -a -e ${next}/$i.sum; then
           sort ${prev}/$i.sum -o ${prev}/$i-sort.sum
           sort ${next}/$i.sum -o ${next}/$i-sort.sum
           diff -U 0 ${prev}/$i-sort.sum ${next}/$i-sort.sum 2>&1 | egrep '^[+-]PASS|^[-]FAIL|^[+-]XPASS|^[+-]XFAIL' 2>&1 | sort -k 2 2>&1 > ${diffdir}/diff-$i.txt
            rm ${prev}/$i-sort.sum ${next}/$i-sort.sum
	    if test -s ${diffdir}/diff-$i.txt; then
		echo "Comparison between:" > ${diffdir}/$i-test-results.txt
		echo "	${prev}/$i.sum and" >> ${diffdir}/$i-test-results.txt
		echo "	${next}/$i.sum" >> ${diffdir}/$i-test-results.txt
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
		echo "" >> ${diffdir}/$i-test-results.txt
		echo "Revision ${cversion} Summary:" >> ${diffdir}/$i-test-results.txt
		grep "^# of " ${next}/$i.sum >> ${diffdir}/$i-test-results.txt
		echo "" >> ${diffdir}/$i-test-results.txt
		echo "Build log: http://cbuild.validation.linaro.org${next}/make-$i.log.xz" >> ${diffdir}/$i-test-results.txt
		echo "Test summary: http://cbuild.validation.linaro.org${next}/$i.sum.xz" >> ${diffdir}/$i-test-results.txt
		echo "Test log: http://cbuild.validation.linaro.org${next}/check-$i.log.xz" >> ${diffdir}/$i-test-results.txt
		local userid="`grep 'email=' ${next}/manifest.txt | cut -d '=' -f 2`"
		if test -e ${diffdir}/$i-test-results.txt; then
		    mailto "$i had regressions between ${pversion} and ${cversion}!" ${diffdir}/$i-test-results.txt ${userid}
		fi
	    else
		echo "$i had no regressions between ${pversion} and ${cversion}!" > /tmp/mail$$.txt
		mailto "$i had no regressions between ${pversion} and ${cversion}!" /tmp/mail$$.txt
		rm /tmp/mail$$.txt
	    fi
	fi
	
	# Scan the check log for testsuite build errors
	scancheck ${next}/check-$i.log.xz
    done

    rm -fr ${diffdir}
    local incr=`expr ${incr} + 1`

    # Not all subdirectories have uncompressed sum files
    local files="`ls ${prev}/*.sum | wc -l`"
    if test ${files} -gt 0; then
	xz ${prev}/*.sum
    fi
    xz ${next}/*.sum ${next}/*.log
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
	echo "===================== $i ================"
	cat $2
    fi
}

usage()
{
    echo "--email          : Send email of the validation results"
    echo "--tdir dir1 dir2 : Compare the test results in 2 subdirectories"
    echo "--base dir       : Compare the test results in dir to the baseline"
    echo "These next two options are only used by --base"
    echo "  --target triplet : Thr target triplet or 'native'"
    echo "  --build cpu      : The cpu of the buuld machine"
}

# ----------------------------------------------------------------------
# Start to actually do something

# The top level is usually something like /space/build/gcc-linaro-4.8.3-2014.02

if test "`echo $* | grep -c email`" -gt 0; then
    email=yes    
fi

if test $# -eq 0; then
    usage
fi
args="$*"
while test $# -gt 0; do
    case "$1" in
	--email)
	    ;;
	--tdir*)
	    difftwodirs "$2" "$3"
	    shift
	    ;;
	--target*)
	    # Set the target triplet
	    target="$2"
	    shift
	    ;;
	--build*)
	    # Set the target triplet
	    buildarch="`echo $2 | cut -d '-' -f 1`"
	    shift
	    ;;
	--base*)
	    # For each revision we build the toolchain for this config triplet
	    if test x"${target}" = x; then
		echo "ERROR: No target to compare!"
		echo "tcwgweb.sh --target [triplet] ${args} --base [path]"
		exit
		
	    fi
	    shift
	    diffbaseline "${buildarch}.${target}" "$1"
	    ;;
    esac
    if test $# -gt 0; then
	shift
    fi
done

