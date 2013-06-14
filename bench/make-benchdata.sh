#!/bin/sh

#
# This script executes a series of SQL calls to our testing
# database, and makes a data file for gnuplot.
#

# These are required to access the database
user="USER"
passwd="PASSWD"
tmpdir="/tmp"

# Check the environment for the database access information
if test x"${CBUILD_DBUSER}" != x; then
    user="${CBUILD_DBUSER}"
fi
if test x"${CBUILD_DBPASSWD}" != x; then
    passwd="${CBUILD_DBPASSWD}"
fi

# Create the output file
rm -f ${outfile}

# Extract the list of architectures supported for these results
benchmarks=`mysql -u${user} -p${passwd} --local -e "SELECT DISTINCT(testname) FROM benchmark.tabulate" | sed -e 's/testname//'`

# Get rid of the embedded newlines
benchmarks=`echo ${benchmarks} | tr -d '\n'`

echo -n "Processing data "
for i in ${benchmarks}; do
    rm -f  $i.data
    touch  $i.data
    echo -n " $i..."
    runs=`mysql -u${user} -p${passwd} --local -e "SELECT DISTINCT(benchrun) FROM benchmark.tabulate WHERE testname='$i'" | sed -e 's/benchrun//'`
    for j in ${runs}; do
	binfo=`mysql -u${user} -p${passwd} --local -e "SELECT date,target_arch,build_arch,build_machine,build_os,codename,build_gcc,target_gcc,binutils_version,libc_version FROM benchmark.benchrun WHERE benchrun='$j'" | tail -1 | tr -d '\n'`
        # Split the query result into fields
	date="`echo ${binfo} | cut -d ' ' -f 1-2 | cut -d ' ' -f 1`"
	target_arch=`echo ${binfo} | cut -d ' ' -f 3`
	build_arch=`echo ${binfo} | cut -d ' ' -f 4`
	build_machine=`echo ${binfo} | cut -d ' ' -f 5`
	build_os=`echo ${binfo} | cut -d ' ' -f 6-7 | cut -d ' ' -f 1`
	codename=`echo ${binfo} | cut -d ' ' -f 8`
	build_gcc=`echo ${binfo} | cut -d ' ' -f 9`
	target_gcc=`echo ${binfo} | cut -d ' ' -f 10`
	binutils_version=`echo ${binfo} | cut -d ' ' -f 11`
	libc_version=`echo ${binfo} | cut -d ' ' -f 12-14`

	bdata=`mysql -u${user} -p${passwd} --local -e "SELECT version,variant,min,max,best,span,mean,std,median,benchrun FROM benchmark.tabulate WHERE testname='$i' AND benchrun='$j'" | tail -1`
 
        # Get rid of the embedded newlines
	bdata=`echo ${bdata} | tr -d '\n'`
	
        # Split the query result into fields
	version=`echo ${bdata} | cut -d ' ' -f 1`
	variant=`echo ${bdata} | cut -d ' ' -f 2`
	min=`echo ${bdata} | cut -d ' ' -f 3`
	max=`echo ${bdata} | cut -d ' ' -f 4`
	best=`echo ${bdata} | cut -d ' ' -f 5`
	span=`echo ${bdata} | cut -d ' ' -f 6`
	mean=`echo ${bdata} | cut -d ' ' -f 7`
	std=`echo ${bdata} | cut -d ' ' -f 8`
	median=`echo ${bdata} | cut -d ' ' -f 9`
	benchrun=`echo ${bdata} | cut -d ' ' -f 10`

	# Do some filtering as some of the data is way out of range from a bad
	# run
	if test x"$i" = x"eembc"; then
	    if test `echo ${best} | sed -e 's:\.[0-9]*::'` -gt 20; then
		echo "WARNING: ${best} is out of range!"
		continue;
	    fi
	fi
	# Write the data line
	echo "${date} ${target_gcc}-${build_machine} ${variant} ${min} ${max} ${best} ${span} ${mean} ${std} ${median}" >> $i.data
    done
done

