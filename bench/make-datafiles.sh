#!/bin/sh

#
# This script executes a series of SQL calls to our benchmark
# database, and makes a data file for gnuplot.
#
if test $# -eq 0; then
  echo "ERROR: no benchrun numbers specified!"
  exit
fi

user="USER"
passwd="PASSWD"
benchrun=0
tmpdir="/tmp"
outfile="benchrun.data"

# Check the environment for the database access information
if test x"${ABE_DBUSER}" != x; then
    user="${ABE_DBUSER}"
fi
if test x"${ABE_DBPASSWD}" != x; then
    passwd="${ABE_DBPASSWD}"
fi

# Create the output file
rm -f ${outfile}

# Add a header to make the file human readable
echo "# FIXME: " > ${outfile}

for benchrun in $*; do
  # Get the build info
  binfo=`mysql -u${user} -p${passwd} --local -e "SELECT tool,arch,date,version FROM dejagnu.benchruns WHERE benchrun=${benchrun}" | tail -1`
 
  # Get rid of the embedded newlines
  binfo=`echo $binfo | tr -d '\n'`

  # Split the query result into fields
  tool=`echo ${binfo} | cut -d ' ' -f 1`
  arch=`echo ${binfo} | cut -d ' ' -f 2`

  # Write the data line
  echo "${date} " >> ${outfile}
done

# Extract the list of architectures supported for these results
arches="`cat benchrun.data | grep -v '#' | cut -d ' ' -f 4 | sort | uniq`"
# echo "Architectures for this set of results: ${arches}"

# Make a separate data file for each architecture so gnuplot can keep them organized
for i in ${arches}; do
    grep $i benchrun.data | sort -n > $i.data
done

rm benchrun.data
