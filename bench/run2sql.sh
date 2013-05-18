#!/bin/sh

#
# This script converts the data in a *-run.txt file, and then imports it into
# a database.
#

# If there is an argument, process just the one file, otherwise process all
# the *-run.txt files in the directory.
if test x"$1" != x; then
  benchrun=$1
fi

if test x"$2" != x; then
  files="$2"
else
  files="`ls *-run.txt`"
fi

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

if test x"${benchrun}" = x; then
    benchrun="`mysql -uroot -pfu=br --local benchmark -e 'select count(*) from benchrun;' | tail -1 | tr -d '\n'`"
fi

for runfile in ${files}; do
    # The coremark run file is in a different format.
    if test x"${runfile}" = x"coremark-o3-neon-run.txt"; then
	continue;
    fi
    if test `grep -c '^Run' ${runfile}` -eq 0; then
	echo "WARNING: no run data in ${runfile}"
        continue;
    fi
    # Get the sections within the run file with the data we want
    run1="`grep -n 'Run 1' ${runfile} | cut -d ':' -f 1`"
    run2="`grep -n 'Run 2' ${runfile} | cut -d ':' -f 1`"
    run3="`grep -n 'Run 3' ${runfile} | cut -d ':' -f 1`"
    run4="`grep -n 'Run 4' ${runfile} | cut -d ':' -f 1`"
    run5="`grep -n 'Run 5' ${runfile} | cut -d ':' -f 1`"

    # Seperate each set of fields

    # delete all the tmp files that may be left over from a previus run
    rm -f run?.tmp

    # Split up the run file into separate temp files, one per run
    echo "Splitting the run file data into seperate temp files"
    sed -e "1,${run1} d" -e "${run2},$ d" ${runfile} > ${tmpdir}/run1.tmp
    sed -e "1,${run2} d" -e "${run3},$ d" ${runfile} > ${tmpdir}/run2.tmp
    sed -e "1,${run3} d" -e "${run4},$ d" ${runfile} > ${tmpdir}/run3.tmp
    sed -e "1,${run4} d" -e "${run5},$ d" ${runfile} > ${tmpdir}/run4.tmp
    sed -e "1,${run5} d"                  ${runfile} > ${tmpdir}/run5.tmp
    
    # The run files are just test files with fields delimited bt a TAB character.
    # MySQL can import these directly, so no more data massaging is necessary.
    echo "Adding the run file data into the benchmark.eembc table"
    mysql -u${user} -p${passwd} --local benchmark -e "LOAD DATA LOCAL INFILE '${tmpdir}/run1.tmp' INTO TABLE benchmark.eembc FIELDS TERMINATED BY '\t' SET benchrun = '${benchrun}';"
    mysql -u${user} -p${passwd} --local benchmark -e "LOAD DATA LOCAL INFILE '${tmpdir}/run2.tmp' INTO TABLE benchmark.eembc FIELDS TERMINATED BY '\t' SET benchrun = '${benchrun}';"
    mysql -u${user} -p${passwd} --local benchmark -e "LOAD DATA LOCAL INFILE '${tmpdir}/run3.tmp' INTO TABLE benchmark.eembc FIELDS TERMINATED BY '\t' SET benchrun = '${benchrun}';"
    mysql -u${user} -p${passwd} --local benchmark -e "LOAD DATA LOCAL INFILE '${tmpdir}/run4.tmp' INTO TABLE benchmark.eembc FIELDS TERMINATED BY '\t' SET benchrun = '${benchrun}';"
    mysql -u${user} -p${passwd} --local benchmark -e "LOAD DATA LOCAL INFILE '${tmpdir}/run5.tmp' INTO TABLE benchmark.eembc FIELDS TERMINATED BY '\t' SET benchrun = '${benchrun}';"
done
