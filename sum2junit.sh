#!/bin/sh

#
# This script converts a DejaGnu .sum file into a Junit copatible
# XML file.
#

if test x"$1" = x; then
  outfile="/tmp/testrun.xml"
  infile="/tmp/testrun.sum"
else
  outfile=`echo $1 | sed -e 's/\.sum.*/.junit/'`
  infile=$1
fi

# Where to put the output file
if test x"$2" = x; then
  outfile=${outfile}
else
  outfile="/tmp/${outfile}"
fi

if test ! -e ${infile}; then
  echo "ERROR: no input file specified!"
  exit
fi

# If compressed, uncompress it
type="`file ${infile}`"
count=`echo ${type} | grep -c "XZ compressed data"`
if test ${count} -gt 0; then
  catprog="xzcat"
  decomp="xz -d"
  comp="xz"
else
  count=`echo ${type} | grep -c "XZ compressed data"`
  if test ${count} -gt 0; then
    catprog="gzcat"
    decomp="gzip"
    comp="gunzip"
  else
    catprog="cat"
  fi
fi

#
#${decomp} ${infile}
#infile="`echo ${infile} | sed -e 's:\.xz::' -e 's:\.gz::'`"
tool="`grep "tests ===" ${infile} | tr -s ' ' | cut -d ' ' -f 2`"

# Get the counts for tests that didn't work properly
skipped="`egrep -c '^UNRESOLVED|^UNTESTED|^UNSUPPORTED' ${infile}`"
if test x"${skipped}" = x; then
    skipped=0
fi

# The total of successful results are PASS and XFAIL
passes="`egrep -c '^PASS|XFAIL' ${infile}`"
if test x"${passes}" = x; then
    passes=0
fi

# The total of failed results are FAIL and XPASS
failures="`egrep -c '^XFAIL|XPASS' ${infile}`"
if test x"${failures}" = x; then
    failures=0
fi

# Calculate the total number of test cases
total="`expr ${passes} + ${failures}`"
total="`expr ${total} + ${skipped}`"    

cat <<EOF > ${outfile}
<?xml version="1.0"?>

<testsuites>
<testsuite name="DejaGnu" tests="${total}" failures="${failures}" skipped="${skipped}">

EOF

# Reduce the size of the file to be parsed to improve performance. Junit
# ignores sucessful test results, so we only grab the failures and test
# case problem results.
tmpfile="${infile}.tmp"
rm -f ${tmpfile}
egrep 'XPASS|FAIL|UNTESTED|UNSUPPORTED|UNRESOLVED' ${infile} > ${tmpfile}

while read line
do
    echo -n "."
    result="`echo ${line} | cut -d ' ' -f 1 | tr -d ':'`"
    name="`echo ${line} | cut -d ' ' -f 2`"
    message="`echo ${line} | cut -d ' ' -f 3-50 | tr -d '\"><;:\[\]^\\&?@'`"

    echo "    <testcase name=\"${name}\" classname=\"${tool}-${result}\">" >> ${outfile}
    case "${result}" in
	UNSUPPORTED|UNTESTED|UNRESOLVED)
	    if test x"${message}" != x; then
		echo -n "        <skipped message=\"${message}" >> ${outfile}  
	    else
		echo -n "        <skipped type=\"${result}" >> ${outfile}  
	    fi
	    ;;
	XPASS|XFAIL)
	    echo -n "        <failure message=\"${message}" >> ${outfile}  
	    ;;
	*)
	    echo -n "        <failure message=\"${message}" >> ${outfile}  
    esac
    echo "\"/>" >> ${outfile}  

    echo "    </testcase>" >> ${outfile}
done < ${tmpfile}
rm -f ${tmpfile}

# Write the closing tag for the test results
echo "</testsuite>" >> ${outfile}
echo "</testsuites>" >> ${outfile}

# compress the file again
#${comp} ${infile}

