#!/bin/sh

#
# This script converts the data in a tabulated benchmark.txt file, and then
# imports it into a database.
#

if test x"$1" != x; then
  infile="$1/benchmarks.txt"
else
  infile="./benchmarks.txt"
fi

if test x"$2" != x; then
    benchrun=$2
fi

if test x"${benchrun}" = x; then
    benchrun="`mysql -uroot -pfu=br --local benchmark -e 'select count(*) from benchrun;' | tail -1 | tr -d '\n'`"
fi

# These are required to access the database
user="USER"
passwd="PASSWD"
tmpdir="/tmp"
outfile="${tmpdir}/bench.tmp"

# Check the environment for the database access information
if test x"${ABE_DBUSER}" != x; then
    user="${ABE_DBUSER}"
fi
if test x"${ABE_DBPASSWD}" != x; then
    passwd="${ABE_DBPASSWD}"
fi

# The benchmark.txt files are just test files with fields delimited by a
# TAB character. MySQL can import these directly, so no more data massaging
# is necessary.

rm -f ${outfile}
grep -v "testname" ${infile} >> ${outfile}
 
echo "Adding the benchmark file data into the benchmark.tabulate table"
mysql -u${user} -p${passwd} --local benchmark -e "LOAD DATA LOCAL INFILE '${outfile}' INTO TABLE benchmark.tabulate FIELDS TERMINATED BY '\t' SET benchrun = '${benchrun}';"
