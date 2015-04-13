#!/bin/bash                                                                                                       

mydir="`dirname $0`"
logdir=/work/logs
status=0

if [ $# -lt 4 ]
then
    echo "Usage: $0 job1 build1 job2 build2"
    exit 1
fi

job1=$1
job2=$3

refnum=${job1}$2
buildnum=${job2}$4

tmptargets=/tmp/targets.$$
trap "rm -f ${tmptargets}" 0 1 2 3 5 9 13 15

rm -f ${tmptargets}

# For the time being, we expect different jobs to store their results
# in similar directories.

# Build list of all targets validated for ${refnum}                                                               
# Use grep -v '*' to skip the case where the first regexp does not                                                
# match any directory.                                                                                            
for dir in `echo ${logdir}/*/*/*-${refnum} | grep -v '*'`
do
    basename ${dir} | sed "s/-${refnum}//" >> ${tmptargets}
done

# Build list of all targets validated for ${buildnum}                                                             
for dir in `echo ${logdir}/*/*/*-${buildnum} | grep -v '*'`
do
    basename ${dir} | sed "s/-${buildnum}//" >> ${tmptargets}
done

if [ -s ${tmptargets} ]; then
    targets=`sort -u ${tmptargets}`
fi
rm -f ${tmptargets}

for target in ${targets}
do
    ref=`echo ${logdir}/*/*/${target}-${refnum} | grep -v '*'`
    build=`echo ${logdir}/*/*/${target}-${buildnum} | grep -v '*'`
    echo "REF = "${ref}
    echo "BUILD = "${build}
    printf "\t# ============================================================== #\n"
    printf "\t#\t\t*** ${target} ***\n"
    printf "\t# ============================================================== #\n\n"
    [ ! -z "${build}" -a ! -z "${ref}" ] && ${mydir}/compare_tests ${ref} ${build} || status=1
done

exit ${status}
