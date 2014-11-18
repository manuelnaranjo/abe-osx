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
if test x"${ABE_DBUSER}" != x; then
    user="${ABE_DBUSER}"
fi
if test x"${ABE_DBPASSWD}" != x; then
    passwd="${ABE_DBPASSWD}"
fi

# Create the output file
rm -f ${outfile}

# Extract the list of arc supported for these results
benchmarks=`mysql -u${user} -p${passwd} --local -e "SELECT DISTINCT(testname) FROM benchmark.tabulate" | sed -e 's/testname//' | tr '[:upper:]' '[:lower:]'`

# Get rid of the embedded newlines
benchmarks=`echo ${benchmarks} | tr -d '\n'`

echo -n "Processing data "
for i in ${benchmarks}; do
    rm -f  $i.*.data
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
	# benchmark run. This screws up accurate graphing.
	if test x"$i" = x"eembc"; then
	    # test runs that had problems produce bad data, so here we filter out
	    # anything wildly out of range
	    value="`echo ${best} | sed -e 's:\.[0-9]*::'`"
	    if test ${value} -gt 20 -o ${value} -lt 0; then
		echo "WARNING: ${best} is out of range for EEMBC!"
		continue;
	    fi
	    # here we filter out other bad parsing data. sometimes if a field is
	    # missing, things get out of order, and the target_gcc being wrong is
	    # a good clue this data is bogus
	    if test `echo ${target_gcc} | grep -c gcc` -eq 0; then
		echo "WARNING: ${target_gcc} is invalid!"
		continue;
	    fi
	fi
	if test x"$i" = x"denbench"; then	
	    value="`echo ${best} | sed -e 's:\.[0-9]*::'`"
	    #echo "FIXME: Denbench ${value}"
	    if test ${value} -gt 20 -o ${value} -lt 9; then
		echo "WARNING: ${value} is out of range for Denbench!"
		continue;
	    fi
	fi
	if test x"$i" = x"spec2000"; then	
	    value="`echo ${best} | sed -e 's:\.[0-9]*::'`"
	    if test ${value} -lt 300; then
		echo "WARNING: ${value} is out of range for Spec2000!"
		continue;
	    fi
	fi
	if test x"$i" = x"coremark"; then	
	    value="`echo ${best} | sed -e 's:\.[0-9]*::'`"
	    if test ${value} -gt 2800; then
		echo "WARNING: ${value} is out of range for Coremark!"
		continue;
	    fi
	fi
	# Write the data line
	touch $i.${build_machine}.data
	# Don't add any gcc-binary results
	if test `echo ${target_gcc} | grep -c 'gcc-binary'` -eq 0; then
	    gcc_version="`echo ${target_gcc} | sed -e 's:gcc-linaro-::'`"
	    echo "${date} ${gcc_version} ${variant} ${min} ${max} ${best} ${span} ${mean} ${std} ${median} ${build_machine}" >> $i.${build_machine}.data
	fi
    done
done

# Sort the data by version number
for k in $i.*.data; do
    mv -f $k /tmp/tmp.data
    sort -V -k 2 /tmp/tmp.data > $k
    rm /tmp/tmp.data
done
