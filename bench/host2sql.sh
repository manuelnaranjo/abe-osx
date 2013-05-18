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

date="`grep -A1 '^date:' host.txt | tail -1`"
benchmark="EEMBC"
base_result=
status=		# enum('IDLE','RUNNING','DONE')
enabled_cores=
cores_per_chip=
threads_per_core=
target_arch="`grep "configured for a target of" host.txt | sed -e 's/^.*\`//' -e 's/.\.//'`"
build_arch="`grep -A1 '^uname:' host.txt | tail -1 | cut -d ' ' -f 14`"
enabled_chips="`grep '^processor' host.txt | wc -l`"
gcc_version="`grep -A1 '^gcc:' host.txt | tail -1 | cut -d ' ' -f 2`"
binutils_version="`grep -A1 '^as:' host.txt | tail -1 | cut -d ' ' -f 2`"
libc_version="`grep -A1 '^ldd:' host.txt | tail -1 | cut -d ' ' -f 2-4`"
peak_result=
ram="`grep '^Mem:' host.txt | cut -d ' ' -f 8`"

dump()
{
    echo "Date benchmark run:         ${date}"
    echo "Benchmark is:               ${benchmark}"
    echo "Base Result:                ${base_result}"
    echo "Status:                     ${status}"
    echo "Target architcture:         ${target_arch}"
    echo "Build architecture:         ${build_arch}"
    echo "Enabled Cores are:          ${enabled_cores}"
    echo "Enabled chips are:          ${enabled_chips}"
    echo "Core per chip are:          ${cores_per_chip}"
    echo "Threads per Core are:       ${threads_per_core}"
    echo "GCC used for build is:      ${gcc_version}"
    echo "Binutils used for build is: ${binutils_version}"
    echo "Libc used for build is:     ${libc_version}"
    echo "Peak Result is:             ${peak_result}"
    echo "RAM:                        ${ram}"
    echo "benchrun:                   ${benchrun}"
}

# Produce an SQL formatted text file to import the data for this
# benchmark run. This function only accesses the global data from
# parsing the host.txt file.
sql()
{
    outfile="${tmpdir}/host.sql"
    rm -f ${outfile}

    # Add header comment incase we ever have to edit this file manually
    echo "# date | benchmark | base_result | status | target_arch | build_arch | enabled_cores | enabled_chips | cores_per_chip | threads_per_core | gcc_version | binutils_version | libc_version | peak_result | ram" > ${outfile}

    echo -n "INSERT INTO benchrun VALUES " >> ${outfile}

    echo -n "('${date}'" >> ${outfile}
    echo -n ",'${benchmark}'"  >> ${outfile}
    echo -n ",'${base_result}'"  >> ${outfile}
    echo -n ",'${status}'"  >> ${outfile}
    echo -n ",'${target_arch}'"  >> ${outfile}
    echo -n ",'${build_arch}'"  >> ${outfile}
    echo -n ",'${enabled_cores}'"  >> ${outfile}
    echo -n ",'${enabled_chips}'"  >> ${outfile}
    echo -n ",'${cores_per_chip}'"  >> ${outfile}
    echo -n ",'${threads_per_core}'" >> ${outfile}
    echo -n ",'${gcc_version}'" >> ${outfile}
    echo -n ",'${binutils_version}'" >> ${outfile}
    echo -n ",'${libc_version}'" >> ${outfile}
    echo -n ",'${peak_result}'" >> ${outfile}
    echo -n ",'${ram}'" >> ${outfile}
    echo -n ",'${benchrun}'" >> ${outfile}

    echo ");" >> ${outfile}
}

dump
sql

# Write the data into the banechmark.benchrun table
mysql -u${user} -p${passwd} --local benchmark < /${tmpdir}/host.sql
