#!/bin/sh

#
# The EEMBC and Coremark benchmarks write a 'host.txt' file, which contains the
# information we need to document this benchmark run.
#

# These are required to access the database
user="USER"
passwd="PASSWD"
benchrun=0
tmpdir="/tmp"

if test x"$1" != x; then
    hostdir=$1
    hostfile=${hostdir}/host.txt
else
    hostdir=${PWD}
    hostfile=${hostdir}/host.txt
fi

if test ! -e ${hostfile} -a ! -e ${hostdir}/benchmarks.txt; then
    echo "ERROR: no data to parse!"
    exit 1
fi

build_machine="`basename ${hostdir}| sed -e 's:^.*-::'`"

# Check the environment for the database access information
if test x"${CBUILD_DBUSER}" != x; then
    user="${CBUILD_DBUSER}"
fi
if test x"${CBUILD_DBPASSWD}" != x; then
    passwd="${CBUILD_DBPASSWD}"
fi

# Get an index number, which is just one more than the total number of testruns
benchrun="`mysql -uroot -pfu=br --local benchmark -e 'select count(*) from benchrun;' | tail -1 | tr -d '\n'`"
benchrun="`expr ${benchrun} + 1`"

date="`grep -A1 '^date:' ${hostfile} | tail -1`"

benchmark="EEMBC"
base_result=
status=		# enum('IDLE','RUNNING','DONE')
enabled_cores=
cores_per_chip=
threads_per_core=
target_arch="`grep "configured for a target of" ${hostfile} | sed -e 's/^.*\`//' -e 's/.\.//'`"
build_arch="`grep -A1 '^uname:' ${hostfile} | tail -1 | cut -d ' ' -f 14`"
build_os="`grep -A1 '^uname:' ${hostfile} | tail -1 | cut -d ' ' -f 3-4`"
enabled_chips="`grep '^processor' ${hostfile} | wc -l`"
codename="`grep '^Codename' ${hostfile} | cut -f 2`"
build_gcc="`grep -A1 '^gcc:' ${hostfile} | tail -1 | cut -d ' ' -f 2`"
binutils_version="`grep -A1 '^as:' ${hostfile} | tail -1 | cut -d ' ' -f 2`"
libc_version="`grep -A1 '^ldd:' ${hostfile} | tail -1 | cut -d ' ' -f 2-4`"
peak_result=
ram="`grep '^Mem:' ${hostfile} | cut -d ' ' -f 8`"
target_gcc="`grep mkdir ${hostdir}/toplevel.txt | head -1 | cut -d ' ' -f 3`"

dump()
{
    echo "Date benchmark run:         ${date}"
    echo "Benchmark is:               ${benchmark}"
    echo "Base Result:                ${base_result}"
    echo "Status:                     ${status}"
    echo "Target architcture:         ${target_arch}"
    echo "Build architecture:         ${build_arch}"
    echo "Build machine:              ${build_machine}"
    echo "Build os:                   ${build_os}"
    echo "Codename:                   ${codename}"
    echo "Enabled Cores are:          ${enabled_cores}"
    echo "Enabled chips are:          ${enabled_chips}"
    echo "Core per chip are:          ${cores_per_chip}"
    echo "Threads per Core are:       ${threads_per_core}"
    echo "GCC used for build is:      ${build_gcc}"
    echo "Target GCC version is:      ${target_gcc}"
    echo "Binutils used for build is: ${binutils_version}"
    echo "Libc used for build is:     ${libc_version}"
    echo "Peak Result is:             ${peak_result}"
    echo "RAM:                        ${ram}"
    echo "benchrun:                   ${benchrun}"
}

# Produce an SQL formatted text file to import the data for this
# benchmark run. This function only accesses the global data from
# parsing the ${hostfile} file.
sql()
{
    outfile="${tmpdir}/host.sql"
    rm -f ${outfile}

    if test x"${target_arch}" = x; then
	echo "ERROR: Couldn't get host config info for ${hostfile}"
	exit
    fi
    # Add header comment incase we ever have to edit this file manually
    echo "# date | benchmark | base_result | status | target_arch | build_arch | build_machine | build_os | codename | enabled_cores | enabled_chips | cores_per_chip | threads_per_core | gcc_version | binutils_version | libc_version | peak_result | ram" > ${outfile}

    echo -n "INSERT INTO benchrun VALUES " >> ${outfile}

    echo -n "('${date}'" >> ${outfile}
    echo -n ",'${benchmark}'"  >> ${outfile}
    echo -n ",'${base_result}'"  >> ${outfile}
    echo -n ",'${status}'"  >> ${outfile}
    echo -n ",'${target_arch}'"  >> ${outfile}
    echo -n ",'${build_arch}'"  >> ${outfile}
    echo -n ",'${build_machine}'"  >> ${outfile}
    echo -n ",'${build_os}'"  >> ${outfile}
    echo -n ",'${codename}'"  >> ${outfile}
    echo -n ",'${enabled_cores}'"  >> ${outfile}
    echo -n ",'${enabled_chips}'"  >> ${outfile}
    echo -n ",'${cores_per_chip}'"  >> ${outfile}
    echo -n ",'${threads_per_core}'" >> ${outfile}
    echo -n ",'${build_gcc}'" >> ${outfile}
    echo -n ",'${target_gcc}'" >> ${outfile}
    echo -n ",'${binutils_version}'" >> ${outfile}
    echo -n ",'${libc_version}'" >> ${outfile}
    echo -n ",'${peak_result}'" >> ${outfile}
    echo -n ",'${ram}'" >> ${outfile}
    echo -n ",'${benchrun}'" >> ${outfile}

    echo ");" >> ${outfile}
}

dump
sql

# Write the data into the benchmark.benchrun table
mysql -u${user} -p${passwd} --local benchmark < /${tmpdir}/host.sql
