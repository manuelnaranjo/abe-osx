#!/bin/bash
set -ue
error=1

function exit_handler {
  if test ${error} -eq 0; then
    echo "CoremarkPro gather script passed self-tests"
  else
    echo "CoremarkPro gather script FAILED self-tests" >&2
  fi
  exit ${error}
}

#This only works in some cases, keeping it as it is useful when it works,
#not wasting any more time trying to understand it.
#One fail case is:
#function ename { name; }
#ename
#This exits, but produces no stacktrace.
function err_handler {
  exec 1>&2
  echo "ERROR ${error}"
  echo "Stack trace, excluding subshells:"
  local frame=0
  while caller ${frame}; do
    frame=$((frame + 1))
  done
}

trap exit_handler EXIT
trap err_handler ERR

testcase=('')
last_time=
last_ratio=
exec {STDOUT}>&1

declare -A codesize datasize
workloads='cjpeg-rose7-preset sha-test core nnet_test linear_alg-mid-100x100-sp parser-125k loops-all-mid-10k-sp radix2-big-64k zip-test'
codesize['cjpeg-rose7-preset']=$((RANDOM % 1000000 + 10000))
codesize['sha-test']=$((RANDOM % 1000000 + 10000))
codesize['core']=$((RANDOM % 1000000 + 10000))
codesize['nnet_test']=$((RANDOM % 1000000 + 10000))
codesize['linear_alg-mid-100x100-sp']=$((RANDOM % 1000000 + 10000))
codesize['parser-125k']=$((RANDOM % 1000000 + 10000))
codesize['loops-all-mid-10k-sp']=$((RANDOM % 1000000 + 10000))
codesize['radix2-big-64k']=$((RANDOM % 1000000 + 10000))
codesize['zip-test']=$((RANDOM % 1000000 + 10000))
datasize['cjpeg-rose7-preset']=$((RANDOM % 1000000 + 10000))
datasize['sha-test']=$((RANDOM % 1000000 + 10000))
datasize['core']=$((RANDOM % 1000000 + 10000))
datasize['nnet_test']=$((RANDOM % 1000000 + 10000))
datasize['linear_alg-mid-100x100-sp']=$((RANDOM % 1000000 + 10000))
datasize['parser-125k']=$((RANDOM % 1000000 + 10000))
datasize['loops-all-mid-10k-sp']=$((RANDOM % 1000000 + 10000))
datasize['radix2-big-64k']=$((RANDOM % 1000000 + 10000))
datasize['zip-test']=$((RANDOM % 1000000 + 10000))

function _do_run {
  local name=$1
  local iterations=$2
  last_time=$((RANDOM % 10 + 1)).$((RANDOM % 100000000))
  last_ratio=`echo "${last_time} / ${iterations}" | bc -l`
  printf '123456789\tMLT\t%s\t1\t1\t0\t%f\t%i\t%f\t%i\t%i\n' \
    ${name} \
    ${last_time} \
    ${iterations} \
    ${last_ratio} \
    ${codesize[${name}]} \
    ${datasize[${name}]}
}

function do_verification {
  _do_run $1 1
  testcase=("${testcase[@]}" \
    "`printf 'lava-test-case %s[verification] --result pass' ${name}`" \
    "`printf "lava-test-case %s[code_size] --result pass --units bytes --measurement %i" \
      ${name} \
      ${codesize[${name}]}`" \
    "`printf "lava-test-case %s[data+bss_size] --result pass --units bytes --measurement %i" \
      ${name} \
      ${datasize[${name}]}`"
  )
}

function do_performance {
  local name=$1
  local iterations=$2
  local runs=$3
  local all_times=
  for run in `seq 1 "${runs}"`; do
    _do_run ${name} ${iterations}
    all_times="${all_times} ${last_time}"
    testcase=("${testcase[@]}" \
      "`printf 'lava-test-case %s[%i][time] --result pass --units seconds --measurement %f' \
      ${name} \
      ${run} \
      ${last_time}`" \
      "`printf 'lava-test-case %s[%i][rate] --result pass --units it/s --measurement %f' \
      ${name} \
      ${run} \
      ${last_ratio}`")
  done
  local middle=`echo ${all_times} | wc -w`
  middle=$((middle/2))
  local median_time="`echo ${all_times} | tr ' ' '\n' | sort -n | sed -n ${middle}p`"
  local median_ratio=`echo "${median_time} / ${iterations}" | bc -l`
  echo "#Median for final result ${name}"
  printf '123456789\tMLT\t%s\t1\t1\t0\t%f\t%i\t%f\t%i\t%i\n' \
    ${name} \
    ${median_time} \
    ${iterations} \
    ${median_ratio} \
    ${codesize[${name}]} \
    ${datasize[${name}]}
  testcase=("${testcase[@]}" \
    "`printf 'lava-test-case %s[median][time] --result pass --units seconds --measurement %f' \
    ${name} \
    ${median_time}`" \
    "`printf 'lava-test-case %s[median][rate] --result pass --units it/s --measurement %f' \
    ${name} \
    ${median_ratio}`")
}

function primary_runs {
  exec 1>testing/input/builds/TARGET/TOOLCHAIN/logs/TARGET.TOOLCHAIN.log
  echo 'UID     Suite   Name    Contexts        Workers Item Fails      Time(secs)      Iterations      It/s    Codesize        Datasize        Variance        Standard Deviation'
  for name in ${workloads}; do
    echo '#Results for verification run started at 15350:15:33:03 XCMD='
    do_verification "${name}"
    echo '#Results for performance runs started at 15350:15:33:03 XCMD='
    iterations=$((RANDOM % 100 + 1))
    do_performance $name $((iterations * 10)) 9 #i.e. will report 10 - 1000 iterations, will be a multiple of 10
  done
  exec 1>&${STDOUT}
}


rm -rf testing
mkdir -p testing/input/builds/TARGET/TOOLCHAIN/logs
mkdir -p testing/input/builds/TARGET/TOOLCHAIN/cert/DATE/{best,single}/perf/logs

#First test - certify-all run
primary_runs

exec 1>testing/input/builds/TARGET/TOOLCHAIN/logs/TARGET.TOOLCHAIN.mark
echo 'Mark,Performance,Scale,Comments'
echo "CoreMark-PRO,1.0 PROMarks / ...-gcc -foo -Obar,1,Optimal performance at one item for 9 results"
testcase=("${testcase[@]}" \
  "lava-test-case CoreMark-PRO --result pass --units PROMarks --measurement 1.0")

#Additional files to collect
for name in ${workloads}; do
  touch testing/input/builds/TARGET/TOOLCHAIN/cert/DATE/{best,single}/perf/logs/${name}.{run,size}.log
  mkdir -p testing/input/builds/TARGET/TOOLCHAIN/cert/DATE/{best,single}/workloads/${name}/logs
  touch testing/input/builds/TARGET/TOOLCHAIN/cert/DATE/{best,single}/workloads/${name}/logs/${name}.{run,size}.log
done
touch testing/input/builds/TARGET/TOOLCHAIN/logs/progress.log
touch testing/input/builds/TARGET/TOOLCHAIN/cert/DATE/{best,single}/TARGET.TOOLCHAIN.log

exec 1>testing/golden
#Generate golden comparison file
echo 'lava-test-run-attach RETCODE'
echo 'lava-test-run-attach stdout'
echo 'lava-test-run-attach stderr'
echo 'lava-test-run-attach linarobenchlog'
#We don't check for quite everything in perf, but we get enough coverage (both tail and non-tail files)
for context in best single; do
  for name in `echo ${workloads} | tr ' ' '\n' | sort`; do
    echo "lava-test-run-attach TARGET/TOOLCHAIN/cert/DATE/${context}/perf/logs/${name}.run.log"
    echo "lava-test-run-attach TARGET/TOOLCHAIN/cert/DATE/${context}/perf/logs/${name}.size.log"
  done
  echo "lava-test-run-attach TARGET/TOOLCHAIN/cert/DATE/${context}/TARGET.TOOLCHAIN.log"
  for name in `echo ${workloads} | tr ' ' '\n' | sort`; do
    echo "lava-test-run-attach TARGET/TOOLCHAIN/cert/DATE/${context}/workloads/${name}/logs/${name}.run.log"
    echo "lava-test-run-attach TARGET/TOOLCHAIN/cert/DATE/${context}/workloads/${name}/logs/${name}.size.log"
  done
done
echo 'lava-test-run-attach TARGET/TOOLCHAIN/logs/progress.log'
echo 'lava-test-run-attach TARGET/TOOLCHAIN/logs/TARGET.TOOLCHAIN.log'
echo 'lava-test-run-attach TARGET/TOOLCHAIN/logs/TARGET.TOOLCHAIN.mark'
for x in "${testcase[@]:1}"; do
  echo "$x"
done

exec 1>&${STDOUT}

TESTING=1 ./CoremarkPro.sh testing/input > testing/output

diff testing/{golden,output}


#Second test - quickrun
rm -rf testing
mkdir -p testing/input/builds/TARGET/TOOLCHAIN/logs
testcase=('')

primary_runs

exec 1>testing/input/builds/TARGET/TOOLCHAIN/logs/TARGET.TOOLCHAIN.noncert_mark
echo 'Mark,Performance,Scale,Comments'
echo "CoreMark-PRO,1.0 PROMarks / ...-gcc -foo -Obar,1,Optimal performance at one item for 9 results"
testcase=("${testcase[@]}" \
  "lava-test-case CoreMark-PRO --result pass --units PROMarks --measurement 1.0")

touch testing/input/builds/TARGET/TOOLCHAIN/logs/TARGET.TOOLCHAIN.csv
for name in ${workloads}; do
  touch testing/input/builds/TARGET/TOOLCHAIN/logs/${name}.{run,size}.log
done

exec 1>testing/golden
#Generate golden comparison file
echo 'lava-test-run-attach RETCODE'
echo 'lava-test-run-attach stdout'
echo 'lava-test-run-attach stderr'
echo 'lava-test-run-attach linarobenchlog'
for name in `echo ${workloads} | tr ' ' '\n' | sort | sed '$ d'`; do
  echo "lava-test-run-attach TARGET/TOOLCHAIN/logs/${name}.run.log"
  echo "lava-test-run-attach TARGET/TOOLCHAIN/logs/${name}.size.log"
done
echo 'lava-test-run-attach TARGET/TOOLCHAIN/logs/TARGET.TOOLCHAIN.csv'
echo 'lava-test-run-attach TARGET/TOOLCHAIN/logs/TARGET.TOOLCHAIN.log'
echo 'lava-test-run-attach TARGET/TOOLCHAIN/logs/TARGET.TOOLCHAIN.noncert_mark'
echo 'lava-test-run-attach TARGET/TOOLCHAIN/logs/zip-test.run.log'
echo 'lava-test-run-attach TARGET/TOOLCHAIN/logs/zip-test.size.log'
for x in "${testcase[@]:1}"; do
  echo "$x"
done

exec 1>&${STDOUT}

TESTING=1 ./CoremarkPro.sh testing/input > testing/output

diff testing/{golden,output}

exec 1>/dev/null
TESTING=1 ./CoremarkPro.sh 2>&1 && false #should fail with no args

#should fail if *mark has other than 2 lines
echo > testing/input/builds/TARGET/TOOLCHAIN/logs/TARGET.TOOLCHAIN.noncert_mark
TESTING=1 ./CoremarkPro.sh 2>&1 testing/input && false
echo > testing/input/builds/TARGET/TOOLCHAIN/logs/TARGET.TOOLCHAIN.mark
TESTING=1 ./CoremarkPro.sh 2>&1 testing/input && false

#should fail with bad log file
echo > testing/input/builds/TARGET/TOOLCHAIN/logs/TARGET.TOOLCHAIN.log
TESTING=1 ./CoremarkPro.sh 2>&1 testing/input && false

exec 1>&${STDOUT}
error=0
