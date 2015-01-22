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

    echo "                                           +---------+---------+"
    echo "o RUN STATUS                               |   REF   |   RES   |"
    echo "+------------------------------------------+---------+---------+"
    local i=0
    local count="${#msgs[@]}"
    while test $i -lt ${count}; do
	printf "| %-40s | %7s | %7s |\n" "${msgs[$i]}" ${count} ${count}
	i="`expr $i + 1`"
	total="`expr ${total} + ${count}`"
    done
    echo "+------------------------------------------+---------+---------+"
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
 
    echo "# Comparing ${files} common sum files"
    echo "" 
}

regression_table ()
{
    local title=${1:+$1}
    local declare msgs=("${!2}")
    local total=0
    local i=0
    local count="${#msgs[@]}"
    local declare num=("${!3}")

    echo "o `echo ${title} | tr "[:lower:]" "[:upper:]"`"
    echo   "+------------------------------------------+---------+"
    while test $i -lt ${count}; do
	printf "| %-40s | %7s |\n" "${msgs[$i]}" "${num[$i]}"
	total="`expr ${total} + "${num[$i]}"`"
	i="`expr $i + 1`"
    done
    echo   "+------------------------------------------+---------+"
    printf "| %-40s | %7s |\n" "TOTAL_REGRESSIONS" ${total}
    echo   "+------------------------------------------+---------+"
    echo ""
}

declare -a msgs=('burly adwdf bar' 'afsfsdf')
declare -a counts=('3' '1')

display_header "x6_64.arm-linux.gnueabihf" dir1 dir2 4

regression_table "REGRESSIONS" msgs[@] counts[@]
regression_table "MINOR TO BE CHECKED" msgs[@] counts[@]

run_status  msgs[@]

extract_results ()
{
    local sum="$1"
    declare -A headerinfo
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

#eval "`extract_results /linaro/build/x86_64-linux-gnu/abe/master/builds/x86_64-unknown-linux-gnu/aarch64-none-elf/gcc.git@9287b9627c3f1ce26f740820e144c941614ffcb9-stage2/gcc/testsuite/gcc/gcc.sum`"
#head="`extract_results /linaro/build/x86_64-linux-gnu/abe/master/builds/x86_64-unknown-linux-gnu/aarch64-none-elf/gcc.git@9287b9627c3f1ce26f740820e144c941614ffcb9-stage2/gcc/testsuite/gcc/gcc.sum`"

toplevel="/var/www/abe/logs/gcc-linaro-5.0.0/"
sums="`find ${toplevel} -name gcc.sum*`"
declare -a head=()
i=0
for sum in ${sums}; do
    head[$i]="`extract_results ${sum}`"
    i="`expr $i + 1`"
done

#echo "FOOBY ${#head[@]}"
eval declare -A header=(${head[4]})
#echo "FIXME: ${header[DATE]}"
#echo "FIXME: ${header[BOARD]}"

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
    echo "FUR: ${data[TARGET]}: ${data[PASSES]:-0}"
    totals[PASSES]="`expr ${totals[PASSES]} + ${data[PASSES]:-0}`"
    totals[XPASSES]="`expr ${totals[XPASSES]} + ${data[XPASSES]:-0}`"
    totals[FAILURES]="`expr ${totals[FAILURES]} + ${data[FAILURES]:-0}`"
    totals[XFAILURES]="`expr ${totals[XFAILURES]} + ${data[XFAILURES]:-0}`"
    totals[UNRESOLVED]="`expr ${totals[UNRESOLVED]} + ${data[UNRESOLVED]:-0}`"
    totals[UNSUPPORTED]="`expr ${totals[UNSUPPORTED]} + ${data[UNSUPPORTED]:-0}`"
    i="`expr $i + 1`"
done

echo "Total passes: ${totals[PASSES]}"
echo "Total xpasses: ${totals[XPASSES]}"
echo "Total failures: ${totals[FAILURES]}"
echo "Total xfailure : ${totals[XFAILURES]}"
echo "Total unresolved: ${totals[UNRESOLVED]}"
echo "Total unsupported: ${totals[UNSUPPORTED]}"

# To create a new associative array from a string, we have to eval it.
#eval declare -A header=(`extract_results /var/www/abe/logs/gcc-linaro-5.0.0/master-15d9538ce14ff5f8d8a1dc54b81d13d599edcbd8/x86_64.i686-linux-gnu-SchrootFarm319/gcc.sum`)
#head=`extract_results /var/www/abe/logs/gcc-linaro-5.0.0/master-15d9538ce14ff5f8d8a1dc54b81d13d599edcbd8/x86_64.i686-linux-gnu-SchrootFarm319/gcc.sum`
#declare  header
#header[0]=${head}
#header[1]=${head}

#eval declare -A foo=(${header[0]})
#echo "FIXME: ${foo[DATE]}"
#echo "FIXME: ${foo[BOARD]}"
#echo "FIXME00: ${head[0]}"
#echo "FIXME00: ${header[TARGET]}"
#echo "FIXME11: ${header[DATE]}"
#echo "FIXME22: ${header[BOARD]}"
#echo "FIXME33: ${header[PASSES]}"
#echo "FIXME44: ${header[XPASSES]}"
#echo "FIXME55: ${header[FAILURES]}"
#echo "FIXME66: ${header[XFAILURES]}"
#echo "FIXME77: ${header[UNRESOLVED]}"
#echo "FIXME88: ${header[UNSUPPORTED]}"
