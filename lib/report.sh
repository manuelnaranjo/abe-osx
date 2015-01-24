#!/bin/sh
# 
#   Copyright (C) 2015 Linaro, Inc
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

run_status ()
{
    local declare msgs=("${!1}")
    local declare refs=("${!2}")
    local declare ress=("${!3}")

    echo "                                             +---------+---------+"
    echo "o RUN STATUS                                 |   REF   |   RES   |"
    echo "  +------------------------------------------+---------+---------+"
    local i=0
    local count="${#msgs[@]}"
    while test $i -lt ${count}; do
	printf "  | %-40s | %7s | %7s |\n" "${msgs[$i]}" "${refs[$i]}" "${ress[$i]}"
	i="`expr $i + 1`"
	total="`expr ${total} + ${count}`"
    done
    echo "  +------------------------------------------+---------+---------+"
    echo ""
    
}

display_header () 
{
    local target="*** $1 ***"
    local dir1="$2"
    local dir2="$3"
    local files=$4

    local bar="# ============================================================== #"
    local pad="`expr ${#bar} / 2`"
    local length=${#target}
    local midway="`expr ${length} / 2`"
    echo "        ${bar}"
    printf "        # %45s \n" "${target}"
    echo "        ${bar}"
    echo ""

    echo "# Comparing directories"
    echo "# ${dir1}"
    echo "# ${dir2}"
    echo ""
 
#    FIXME: not sure how useful this is, we only compare two files always.
#    echo "# Comparing ${files} common sum files"
#    echo "" 
}

regression_table ()
{
    local title=${1:+$1}
    local declare msgs=("${!2}")
    local total=0
    local i=0
    local count="${#msgs[@]}"
    local declare num=("${!3}")

    echo "o  `echo ${title} | tr "[:lower:]" "[:upper:]"` :"
    echo   "  +------------------------------------------+---------+"
    while test $i -lt ${count}; do
	printf "  | %-40s | %7s |\n" "${msgs[$i]}" "${num[$i]}"
	total="`expr ${total} + "${num[$i]}"`"
	i="`expr $i + 1`"
    done
    echo   "  +------------------------------------------+---------+"
    printf "  | %-40s | %7s |\n" "TOTAL_REGRESSIONS" ${total}
    echo   "  +------------------------------------------+---------+"
    echo ""
}

extract_results ()
{
    local sum="$1"
    declare -A headerinfo
    headerinfo[FILESPEC]="${sum}"
    headerinfo[TARGET]="`grep "Target is" ${sum} | cut -d ' ' -f 3`"
    headerinfo[BOARD]="`grep "Running target" ${sum} | cut -d ' ' -f 3`"
    headerinfo[DATE]="`grep "Test Run" ${sum} | cut -d ' ' -f 6-10`"
    headerinfo[PASSES]="`grep "# of expected passes" ${sum} | grep -o "[0-9]*"`"
    headerinfo[XPASSES]="`grep "# of unexpected successes" ${sum} | grep -o "[0-9]*"`"
    headerinfo[FAILURES]="`grep "# of expected failures" ${sum} | grep -o "[0-9]*"`"
    headerinfo[XFAILURES]="`grep "# of unexpected failures" ${sum} | grep -o "[0-9]*"`"
    headerinfo[UNRESOLVED]="`grep "# of unresolved testcases" ${sum} | grep -o "[0-9]*"`"
    headerinfo[UNSUPPORTED]="`grep "# of unsupported tests" ${sum} | grep -o "[0-9]*"`"

    # This obscure option to declare dumps headerinfo as an associative array
    declare -p headerinfo 2>&1 | sed -e 's:^.*(::' -e 's:).*$::'
    return 0
}

# Process and diff two sum files.
dodiff ()
{
    sort $1 -o ${toplevel}/head-sort.sum
    sort $2 -o ${toplevel}/head-1-sort.sum

    diff -U 0 ${toplevel}/head-sort.sum ${toplevel}/head-1-sort.sum 2>&1 | egrep '^[+-]PASS|^[+-]FAIL|^[+-]XPASS|^[+-]XFAIL|^[+-]UNRESOLVED|^[+-]UNSUPPORTED|^[+-]UNTESTED' 2>&1 | sort -k 2 2>&1 > ${toplevel}/diff.txt
    
    if test -s ${toplevel}/diff.txt; then
	declare -a diff=()
	local i=0
	while read line
	do
	    diff[$i]="$line"
	    i="`expr $i + 1`"
	done < ${toplevel}/diff.txt

	local i=0
	local j=0
	declare -A status
	while test $j -lt ${#diff[@]}; do
	    j="`expr $i + 1`"
	    local str1="`echo ${diff[$i]} | cut -d ' ' -f 2-30`"
	    local str2="`echo ${diff[$j]} | cut -d ' ' -f 2-30`"
	    local sign[0]=`expr substr "${diff[$i]}" 1 1`
	    local sign[1]=`expr substr "${diff[$j]}" 1 1`
#	    echo "FIXIT: ${diff[$i]} ${diff[$j]}"
	    if test x"${str1}" = x"${str2}" -a x"${str1}" != x; then
#		echo "FIXME: regression in!!! ${str1}"
		case "${diff[$i]} ${diff[$j]}" in
		    -FAIL:*PASS:*)
#			echo "FIXME: FAIL->PASS"
			;;
		    -PASS:*+XFAIL:*)
#			echo "FIXME: PASS->XFAIL"
			;;
		    -PASS:*+FAIL:*)
			status[PASSNOWFAILS]="${str1}"
#			echo "FIXME: PASS->FAIL"
			;;
		    +XPASS:*-FAIL:*) 
#			echo "FIXME: XPASS->FAIL"
			;;
		    +XFAIL:*-FAIL:*)
#			echo "FIXME: XFAIL->FAIL"
			;;
		    +XFAIL:*-PASS:*) 
#			echo "FIXME: XFAIL->PASS"
			;;
		    -PASS:*XPASS:*)
#			echo "FIXME: PASS=>XPASS"
			;;
		    +FAIL:*-PASS:*)
			status[FAILNOWPASS]="${str1}"
#			echo "FIXME: FAIL->PASS"
			;;
		    *) echo
			"FIXEEE: ${foo}"
			;;
		esac
#		local state="`expr substr "${diff[$i]}" 1 5`"
		i="`expr $i + 2`"
	    else
		if test x"${sign[0]}" = x -a x"${sign[1]}" = x; then
		    break
		fi
#		echo "FIXME: New or deleted test!!!!"
		if test x"${sign[0]}" = x"-"; then
#		    echo "FIXME: ${str1} was removed"
		    status[DISAPPEARED]="${str1}"
		else
		    if test x"${sign[1]}" = x"+"; then
#			echo "FIXME: ${str2} was added"			
			status[APPEARS]="${str1}"
		    fi
		fi
		i="`expr $i + 1`"
	    fi
	done

	# This obscure option to declare dumps the array as an associative array
	declare -p status
	return 0
    fi
    
    return 1
}

if test x"${1}" != x; then
    toplevel="$1"
else
    # FIXME: for now this is hardcoded, but will be passed in by Jenkins
    toplevel="/work/logs/gcc-linaro/4.9-backport-218451-2/Backport32"
fi

builds="`find ${toplevel} -type d`"

sums="`find ${toplevel} -name gcc.sum*`"
declare -a head=()
i=0
for sum in ${sums}; do
    if test `echo ${sum} | grep -c "\.xz$"` -gt 0; then
	unxz ${sum}
    fi
    file="`echo ${sum} | sed -e 's:\.xz::'`"
    head[$i]="`extract_results ${file}`"
    i="`expr $i + 1`"
done

declare -A totals=()
totals[PASSES]=0
totals[XPASSES]=0
totals[FAILURES]=0
totals[XFAILURES]=0
totals[UNRESOLVED]=0
totals[UNSUPPORTED]=0
i=0
while test $i -lt ${#head[@]}; do
    eval declare -A data=(${head[$i]})
    totals[PASSES]="`expr ${totals[PASSES]} + ${data[PASSES]:-0}`"
    totals[XPASSES]="`expr ${totals[XPASSES]} + ${data[XPASSES]:-0}`"
    totals[FAILURES]="`expr ${totals[FAILURES]} + ${data[FAILURES]:-0}`"
    totals[XFAILURES]="`expr ${totals[XFAILURES]} + ${data[XFAILURES]:-0}`"
    totals[UNRESOLVED]="`expr ${totals[UNRESOLVED]} + ${data[UNRESOLVED]:-0}`"
    totals[UNSUPPORTED]="`expr ${totals[UNSUPPORTED]} + ${data[UNSUPPORTED]:-0}`"
    i="`expr $i + 1`"
done

# Status messages
declare ok_msgs=(\
    "Still passes              [PASS => PASS]" \
    "Still fails               [FAIL => FAIL]")

declare checked_msgs=(\
    "Xfail appears             [PASS =>XFAIL]" \
    "Timeout                   [PASS =>T.OUT]" \
    "Fail disappears           [FAIL =>     ]" \
    "Expected fail passes      [XFAIL=>XPASS]" \
    "Fail now passes           [FAIL => PASS]" \
    "New pass                  [     => PASS]" \
    "Unhandled cases           [   ..??..   ]" \
    "Unstable cases            [PASS => FAIL]")

declare error_msgs=(
    "Passed now fails          [PASS => FAIL]" \
    "Fail now passes           [FAIL => PASS]" \
    "Pass disappears           [PASS =>     ]" \
    "Fail appears              [     => FAIL]" \
    "Timeout                   [PASS =>T.OUT]")

# Run status categories and totals
declare categories=(\
    "Passes                      [PASS+XPASS]" \
    "Unexpected fails                  [FAIL]" \
    "Expected fails                   [XFAIL]" \
    "Unresolved                  [UNRESOLVED]" \
    "Unsupported       [UNTESTED+UNSUPPORTED]")


declare -a dir=()
i=0
#j=1
while test $i -lt ${#head[@]}; do
    eval declare -A data=(${head[$i]})
    tmp="`dirname ${data[FILESPEC]}`"
   if test x"${tmp}" != dir[$i]; then
	dir[$i]="`dirname ${tmp}`"
	echo "DIR: ${dir[$i]}"
    fi
#    j="`expr $j - 1`"
    i="`expr $i + 1`"
done

i=0

eval "`dodiff ${sums[0]} ${sums[1]}`"
if test "$?" -eq 0; then
    echo "No regressions"
fi

if test x"${1}" != x; then
    toplevel="$1"
else
    # FIXME: for now this is hardcoded, but will be passed in by Jenkins
    toplevel="/work/logs/gcc-linaro/4.9-backport-218451-2/Backport32"
fi

builds="`find ${toplevel} -type d`"

sums="`find ${toplevel} -name gcc.sum*`"
declare -a head=()
i=0
for sum in ${sums}; do
    if test `echo ${sum} | grep -c "\.xz$"` -gt 0; then
	unxz ${sum}
    fi
    file="`echo ${sum} | sed -e 's:\.xz::'`"
    head[$i]="`extract_results ${file}`"
    i="`expr $i + 1`"
done


eval "`dodiff ${sums[0]} ${sums[1]}`"
dodiff ${sums[0]} ${sums[1]}
if test "$?" -eq 0; then
    echo "No regressions"
fi

echo "FIXME TOO: ${status[FAILNOWPASS]}"
echo "FIXME TOO: ${status[PASSNOWFAIL]}"
echo "FIXME TOO: ${status[DISAPPEARED]}"
echo "FIXME TOO: ${status[APPEARS]}"

i=0
while test $i -lt ${#head[@]}; do
    eval declare -A data=(${head[$i]})
    display_header "${data[TARGET]}" "${sums[0]}" "${sums[1]}" 2
    declare msgs=("${error_msgs[0]}" "${error_msgs[2]}")
    regression_table "REGRESSIONS" msgs[@] totals[@]
    #regression_table "MINOR TO BE CHECKED" msgs[@] counts[@]
    declare final=(\
         "${data[PASSES]}" \
	"${data[XFAILURES]}" \
	"${data[FAILURES]}" \
	"${data[UNRESOLVED]}" \
	"${data[UNSUPPORTED]}")
    run_status categories[@] final[@] final[@]
    i="`expr $i + 1`"
done

#local lineno="`grep -n -- "----" ${}/manifest.txt | grep -o "[0-9]*"`"
#if test x"${lineno}" != x; then
#    sed -e "1,${lineno}d" ${prev}/manifest.txt
#fi

#echo "Compressing sum files, will take a little while"
#for sum in ${sums}; do
#    if test `echo ${sum} | grep -c "\.xz$"` -gt 0; then
#	file="`echo ${sum} | sed -e 's:\.xz::'`"
#	printf "."
#	xz ${file} 2>&1 > /dev/null
#    fi
#done
#echo ""
