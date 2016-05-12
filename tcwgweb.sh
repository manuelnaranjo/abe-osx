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
fi

# load commonly used functions
abe="`which $0`"
abe_path="`dirname ${abe}`"
topdir="${abe_path}"
abe="`basename $0`"

. "${topdir}/lib/common.sh" || exit 1

# Globals shared between email and gerrit notifications
returncode="0"
returnstr="ALLGOOD"

usage()
{
    cat << EOF
--email          : Send email of the validation results
--tdir dir1 dir2 : Compare the test results in 2 subdirectories
EOF
    exit 0
}

if test $# -eq 0; then
    usage
fi

branch=""
email=no
resultsfile="/tmp/test-results$$.txt"

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
    echo "Check build log: http://148.251.136.42/$1.xz" >> /tmp/mail$$.txt
    echo "" >> /tmp/mail$$.txt
    local i=0
    while test $i -lt ${#errors[@]}; do
	local count="`grep -c "${errors[$i]}" $1`"
	if test ${count} -gt 0; then
	    echo "# of ${errmsg[$i]}: ${count}" >> /tmp/mail$$.txt
	fi
	i="`expr $i + 1`"
    done

    if test x"${email}" = x"yes"; then
	mailto "Testsuite build failures in ${build}!" /tmp/mail$$.txt
    fi

    rm /tmp/mail$$.txt
}

# $1 - the current directory to use when comparing against the baseline
diffbaseline ()
{
    source $1/manifest.txt

    local baselines="/work/abe/baselines"
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
	    echo "WARNING: ${prev} has no test results!"
	    return 0
	fi
    else
	echo "WARNING:${prev} doesn't exist!"
	return 0
    fi

    # Don't diff it's already been done
    if test -e $next/testsuite-diff-$(basename ${prev}).txt; then
	return 0
    fi

    local prev0=${prev}
    local next0=${next}
    tmpdir=$(mktemp -d)
    prev=${tmpdir}/prev
    next=${tmpdir}/next
    rsync -a ${prev0}/ ${prev}/
    rsync -a ${next0}/ ${next}/
    
    echo "Diffing: ${prev0} against ${next0}..."

    local gcc_version="`grep 'gcc_version=' ${next}/manifest.txt | cut -d '=' -f 2`"
    if test x"${gcc_version}" = x"gcc.git"; then
	local gcc_branch="gcc.git~master"
    else
	local gcc_branch="${gcc_version}"
    fi
    local binutils_version="`grep 'binutils_version=' ${next}/manifest.txt | cut -d '=' -f 2`"
    local binutils_revision="`grep 'binutils_revision=' ${next}/manifest.txt | cut -d '=' -f 2`"
    local cversion="`grep 'gcc_revision=' ${next}/manifest.txt | cut -d '=' -f 2`"
    if test -e ${prev}/manifest.txt; then
	local pversion="`grep 'gcc_revision=' ${prev}/manifest.txt | cut -d '=' -f 2`"
    else
	local pversion=${cversion}
    fi

    diffdir="${tmpdir}/diffof-${pversion}-${cversion}"
    mkdir -p ${diffdir}
    local files="`ls ${prev}/*.sum.xz | wc -l`"
    if test ${files} -gt 0; then
	unxz ${prev}/*.sum.xz
    fi
    unxz ${next}/*.xz
    # FIXME: LD and gfortran has problems in the testsuite, so it's temporarily not
    # analyzed for errors.
    local regressions=0
    touch ${resultsfile}
    echo "Comparison of ${gcc_branch} between:" >> ${resultsfile}
    echo "	${prev0} and" >> ${resultsfile}
    echo "	${next0}" >> ${resultsfile}
    for i in gcc g\+\+ libstdc++ ld gas gdb glibc egibc newlib binutils libatomic libgomp libitm; do
	if test -e ${prev}/$i.sum -a -e ${next}/$i.sum; then
           sort ${prev}/$i.sum -o ${prev}/$i-sort.sum
           sort ${next}/$i.sum -o ${next}/$i-sort.sum
           diff -U 0 ${prev}/$i-sort.sum ${next}/$i-sort.sum 2>&1 | egrep '^[+-]PASS|^[+-]FAIL|^[+-]XPASS|^[+-]XFAIL' 2>&1 | sort -k 2 2>&1 > ${diffdir}/diff-$i.txt
            rm ${prev}/$i-sort.sum ${next}/$i-sort.sum
	    if test -s ${diffdir}/diff-$i.txt; then
		if test `grep -c ^\+PASS ${diffdir}/diff-$i.txt` -gt 0; then
		    echo "" >> ${resultsfile}
		    echo "Tests that were failing that now PASS" >> ${resultsfile}
		    echo "-------------------------------------" >> ${resultsfile}
		    grep ^\+PASS ${diffdir}/diff-$i.txt >> ${resultsfile}
		    local regressions=1
		fi
		if test `grep -c ^\+FAIL ${diffdir}/diff-$i.txt` -gt 0; then
		    echo "" >> ${resultsfile}
		    echo "Tests that were passing that now FAIL" >> ${resultsfile}
		    echo "-------------------------------------" >> ${resultsfile}
		    grep ^\+FAIL ${diffdir}/diff-$i.txt >> ${resultsfile}
		    local regressions=1
		fi
		if test `grep -c ^\+XPASS ${diffdir}/diff-$i.txt` -gt 0; then
		    echo "" >> ${resultsfile}
		    echo "Tests that were expected failures that now PASS" >> ${resultsfile}
		    echo "-----------------------------------------------" >> ${resultsfile}
		    grep ^\+XPASS ${diffdir}/diff-$i.txt >> ${resultsfile}
		    local regressions=1
		fi
		if test `grep -c ^\+UN ${diffdir}/diff-$i.txt` -gt 0; then
		    echo "" >> ${resultsfile}
		    echo "Tests that have problems" >> ${resultsfile}
		    echo "------------------------" >> ${resultsfile}
		    grep ^\+UN ${diffdir}/diff-$i.txt >> ${resultsfile}
		    local regressions=1
		fi
		echo "" >> ${resultsfile}
		grep "^# of " ${next}/$i.sum >> ${resultsfile}
		echo "" >> ${resultsfile}
		local userid="`grep 'email=' ${next}/manifest.txt | cut -d '=' -f 2`"
		if test ${regressions} -gt 0; then
		    echo "$i had regressions between ${pversion} and ${cversion}!" >> ${resultsfile}
#		    echo "" >> ${resultsfile}
		    returncode="1"
		    returnstr="REGRESSIONS"
		fi
	    else
		echo "$i had no regressions" >> ${resultsfile}
	    fi
	fi
	
	# Scan the check log for testsuite build errors
	scancheck ${next}/check-$i.log.xz
    done

    local wwwpath="/logs/gcc-linaro-${gcc_version}/`echo ${next} | sed -e 's:/work::' -e 's:/space::'`"
    echo "Build logs: http://148.251.136.42${wwwpath}/" >> ${resultsfile}
    echo "" >> ${resultsfile}
    local lineno="`grep -n -- "----" ${prev}/manifest.txt | grep -o "[0-9]*"`"
    if test x"${lineno}" != x; then
	sed -e "1,${lineno}d" ${prev}/manifest.txt >> ${resultsfile}
	echo "" >> ${resultsfile}
    fi

    if test x"${email}" = x"yes"; then
	mailto "Test results for ${gcc_branch}" ${resultsfile} ${userid}
    fi

    rm -fr ${tmpdir}

    echo ${returnstr}
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
 
    cat <<EOF > ${diffdir}/testsuite-diff-${origdir}.txt
Difference in testsuite results between:
 ${orig} build ${origdir}
and the one before it:
 ${next} build ${nextdir}

------
EOF
    
    cat ${diffdir}/diff.txt  >> ${diffdir}/testsuite-diff-${origdir}.txt
    cp  ${diffdir}/testsuite-diff.txt  $2
}

OPTS="`getopt -o etb:o:h -l email,tdir:,help,outfile:,branch -- "$@"`"
while test $# -gt 0; do
    case $1 in
	-e|--email) email=yes ;;
	-o|--outfile) resultsfile=$2 ;;
	-b|--branch) branch=$2 ;;
	-t|--tdir) difftwodirs "$2" "$3"
	    shift ; shift ;;
        -h|--help) usage ;;
	--) break ;;
    esac
    shift
done

# Don't try to add comments to Gerrit if run manually
if test x"${GERRIT_PATCHSET_REVISION}" != x; then
    srcdir="/linaro/shared/snapshots/gcc.git"
    gerrit_info ${srcdir}
    gerrit_build_status ${srcdir} 0 ${resultsfile}
fi

#cat ${resultsfile}
#rm -fr ${resultsfile}
