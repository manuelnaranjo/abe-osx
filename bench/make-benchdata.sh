#!/bin/sh

#
# This script executes a series of SQL calls to our testing
# database, and makes a data file for gnuplot.
#

# These are required to access the database
user="root"
passwd="fu=br"
tmpdir="/tmp"
outfile="benchrun.data"

# Check the environment for the database access information
if test x"${CBUILD_DBUSER}" != x; then
    user="${CBUILD_DBUSER}"
fi
if test x"${CBUILD_DBPASSWD}" != x; then
    passwd="${CBUILD_DBPASSWD}"
fi

# Create the output file
rm -f ${outfile}

#mysql -u${user} -p${passwd} --local -e "SELECT * INTO OUTFILE '${outfile}' from benchmark.tabulate WHERE subname=''" >> ${outfile}
mysql -u${user} -p${passwd} --local -e "SELECT * from benchmark.tabulate WHERE subname=''" >> ${outfile}

# Extract the list of architectures supported for these results
benchmarks=`mysql -u${user} -p${passwd} --local -e "SELECT DISTINCT(testname) FROM benchmark.tabulate"`

# Make a separate data file for each architecture so gnuplot can keep them organized
for i in ${benchmarks}; do
    grep $i ${outfile} | sort  -V -k 2 > $i.data
done

mv eembc.data tmp.data
grep eembc-office tmp.data > eembc-office.data
grep -v eembc-office tmp.data > eembc.data
rm tmp.data

# rm ${outfile}
