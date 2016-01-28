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
  runset=$1
  _do_run $2 1
  if test ${runset} -eq 0; then
    testcase=("${testcase[@]}" \
      "`printf "lava-test-case %s[code_size] --result pass --units bytes --measurement %i" \
        ${name} \
        ${codesize[${name}]}`" \
      "`printf "lava-test-case %s[data+bss_size] --result pass --units bytes --measurement %i" \
        ${name} \
        ${datasize[${name}]}`" \
    )
  fi
  testcase=("${testcase[@]}" \
    "`printf 'lava-test-case %s[verification[%i]] --result pass' ${name} $((runset + 1))`" \
  )
}

function do_performance {
  local runset=$1
  local name=$2
  local iterations=$3
  local runs=$4
  local all_times=
  for run in `seq 1 "${runs}"`; do
    _do_run ${name} ${iterations}
    all_times="${all_times} ${last_time}"
    testcase=("${testcase[@]}" \
      "`printf 'lava-test-case %s[iteration[%i]]:time --result pass --units seconds --measurement %f' \
      ${name} \
      $((run + runset * runs)) \
      ${last_time}`" \
      "`printf 'lava-test-case %s[iteration[%i]]:rate --result pass --units it/s --measurement %f' \
      ${name} \
      $((run + runset * runs)) \
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
    "`printf 'lava-test-case %s[median[%i]]:time --result pass --units seconds --measurement %f' \
    ${name} \
    $((runset + 1)) \
    ${median_time}`" \
    "`printf 'lava-test-case %s[median[%i]]:rate --result pass --units it/s --measurement %f' \
    ${name} \
    $((runset + 1)) \
    ${median_ratio}`")
}

function primary_runs {
  for x in `seq 0 $(($1 - 1))`; do
    for name in ${workloads}; do
      echo '#Results for verification run started at 15350:15:33:03 XCMD='
      do_verification $x "${name}"
      echo '#Results for performance runs started at 15350:15:33:03 XCMD='
      iterations=$((RANDOM % 100 + 1))
      do_performance $x $name $((iterations * 10)) 9 #i.e. will report 10 - 1000 iterations, will be a multiple of 10
    done
  done
}


rm -rf testing
mkdir -p testing/input/builds/TARGET/TOOLCHAIN/logs
mkdir -p testing/input/builds/TARGET/TOOLCHAIN/cert/DATE/{best,single}/perf/logs

#First test - certify-all run
exec 1>testing/input/builds/TARGET/TOOLCHAIN/logs/TARGET.TOOLCHAIN.log
echo 'UID     Suite   Name    Contexts        Workers Item Fails      Time(secs)      Iterations      It/s    Codesize        Datasize        Variance        Standard Deviation'
primary_runs 2

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
echo 'lava-test-run-attach RETCODE text/plain'
echo 'lava-test-run-attach stdout text/plain'
echo 'lava-test-run-attach stderr text/plain'
echo 'lava-test-run-attach linarobenchlog text/plain'
#We don't check for quite everything in perf, but we get enough coverage (both tail and non-tail files)
for context in best single; do
  for name in `echo ${workloads} | tr ' ' '\n' | sort`; do
    echo "lava-test-run-attach TARGET/TOOLCHAIN/cert/DATE/${context}/perf/logs/${name}.run.log text/plain"
    echo "lava-test-run-attach TARGET/TOOLCHAIN/cert/DATE/${context}/perf/logs/${name}.size.log text/plain"
  done
  echo "lava-test-run-attach TARGET/TOOLCHAIN/cert/DATE/${context}/TARGET.TOOLCHAIN.log text/plain"
  for name in `echo ${workloads} | tr ' ' '\n' | sort`; do
    echo "lava-test-run-attach TARGET/TOOLCHAIN/cert/DATE/${context}/workloads/${name}/logs/${name}.run.log text/plain"
    echo "lava-test-run-attach TARGET/TOOLCHAIN/cert/DATE/${context}/workloads/${name}/logs/${name}.size.log text/plain"
  done
done
echo 'lava-test-run-attach TARGET/TOOLCHAIN/logs/progress.log text/plain'
echo 'lava-test-run-attach TARGET/TOOLCHAIN/logs/TARGET.TOOLCHAIN.log text/plain'
echo 'lava-test-run-attach TARGET/TOOLCHAIN/logs/TARGET.TOOLCHAIN.mark text/plain'
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

exec 1>testing/input/builds/TARGET/TOOLCHAIN/logs/TARGET.TOOLCHAIN.log
echo 'UID     Suite   Name    Contexts        Workers Item Fails      Time(secs)      Iterations      It/s    Codesize        Datasize        Variance        Standard Deviation'
primary_runs 1

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
echo 'lava-test-run-attach RETCODE text/plain'
echo 'lava-test-run-attach stdout text/plain'
echo 'lava-test-run-attach stderr text/plain'
echo 'lava-test-run-attach linarobenchlog text/plain'
for name in `echo ${workloads} | tr ' ' '\n' | sort | sed '$ d'`; do
  echo "lava-test-run-attach TARGET/TOOLCHAIN/logs/${name}.run.log text/plain"
  echo "lava-test-run-attach TARGET/TOOLCHAIN/logs/${name}.size.log text/plain"
done
echo 'lava-test-run-attach TARGET/TOOLCHAIN/logs/TARGET.TOOLCHAIN.csv text/plain'
echo 'lava-test-run-attach TARGET/TOOLCHAIN/logs/TARGET.TOOLCHAIN.log text/plain'
echo 'lava-test-run-attach TARGET/TOOLCHAIN/logs/TARGET.TOOLCHAIN.noncert_mark text/plain'
echo 'lava-test-run-attach TARGET/TOOLCHAIN/logs/zip-test.run.log text/plain'
echo 'lava-test-run-attach TARGET/TOOLCHAIN/logs/zip-test.size.log text/plain'
for x in "${testcase[@]:1}"; do
  echo "$x"
done

exec 1>&${STDOUT}

TESTING=1 ./CoremarkPro.sh testing/input > testing/output

diff testing/{golden,output}

exec 1>/dev/null
TESTING=1 ./CoremarkPro.sh 2>&1 && false #should fail with no args ($1: unbound variable)

#should fail if *mark has other than 2 lines
rm -f testing/input/builds/TARGET/TOOLCHAIN/logs/TARGET.TOOLCHAIN.{,noncert_}mark
for x in '' noncert_; do
  mkdir testing/input/builds/TARGET/TOOLCHAIN/logs/TARGET.TOOLCHAIN.${x}mark
  TESTING=1 ./CoremarkPro.sh testing/input 2>&1 && false #not a file
  rmdir testing/input/builds/TARGET/TOOLCHAIN/logs/TARGET.TOOLCHAIN.${x}mark
  touch testing/input/builds/TARGET/TOOLCHAIN/logs/TARGET.TOOLCHAIN.${x}mark
  TESTING=1 ./CoremarkPro.sh testing/input 2>&1 && false #0 lines
  echo >> testing/input/builds/TARGET/TOOLCHAIN/logs/TARGET.TOOLCHAIN.${x}mark
  TESTING=1 ./CoremarkPro.sh testing/input 2>&1 && false #1 line
  echo >> testing/input/builds/TARGET/TOOLCHAIN/logs/TARGET.TOOLCHAIN.${x}mark
  echo >> testing/input/builds/TARGET/TOOLCHAIN/logs/TARGET.TOOLCHAIN.${x}mark
  TESTING=1 ./CoremarkPro.sh testing/input 2>&1 && false #3 lines
  rm testing/input/builds/TARGET/TOOLCHAIN/logs/TARGET.TOOLCHAIN.${x}mark
done

#should fail with bad log file
echo > testing/input/builds/TARGET/TOOLCHAIN/logs/TARGET.TOOLCHAIN.log
TESTING=1 ./CoremarkPro.sh testing/input 2>&1 && false #header ${line[$i]} (will fail with $1: unbound variable)
echo '#Results foo verification' > testing/input/builds/TARGET/TOOLCHAIN/logs/TARGET.TOOLCHAIN.log
TESTING=1 ./CoremarkPro.sh testing/input 2>&1 && false #fails on absence of next line (will fail with line[$i]: unbound variable)
echo 'foo foo' >> testing/input/builds/TARGET/TOOLCHAIN/logs/TARGET.TOOLCHAIN.log
TESTING=1 ./CoremarkPro.sh testing/input 2>&1 && false #fails on trying to read name from next line ($3: unbound variable)
sed -i '$d' testing/input/builds/TARGET/TOOLCHAIN/logs/TARGET.TOOLCHAIN.log
echo 'foo foo name' >> testing/input/builds/TARGET/TOOLCHAIN/logs/TARGET.TOOLCHAIN.log
TESTING=1 ./CoremarkPro.sh testing/input 2>&1 && false #fails on being unable to read code size (will fail with $9: unbound variable)
sed -i '$d' testing/input/builds/TARGET/TOOLCHAIN/logs/TARGET.TOOLCHAIN.log
echo '1 2 3 4 5 6 7 8 9 10' >> testing/input/builds/TARGET/TOOLCHAIN/logs/TARGET.TOOLCHAIN.log
TESTING=1 ./CoremarkPro.sh testing/input 2>&1 && false #fails on being unable to read data size (will fail with $9: unbound variable)
echo '#Results foo performance' > testing/input/builds/TARGET/TOOLCHAIN/logs/TARGET.TOOLCHAIN.log
TESTING=1 ./CoremarkPro.sh testing/input 2>&1 && false #fails on absence of following line (line[$((i+1))]: unbound variable)
echo >> testing/input/builds/TARGET/TOOLCHAIN/logs/TARGET.TOOLCHAIN.log
TESTING=1 ./CoremarkPro.sh testing/input 2>&1 && false #fails on looking for comment character in following line (1: unbound variable)
sed -i '$d' testing/input/builds/TARGET/TOOLCHAIN/logs/TARGET.TOOLCHAIN.log
echo 'foo foo' >> testing/input/builds/TARGET/TOOLCHAIN/logs/TARGET.TOOLCHAIN.log
TESTING=1 ./CoremarkPro.sh testing/input 2>&1 && false #fails on trying to read name from next line ($3: unbound variable)
sed -i '$d' testing/input/builds/TARGET/TOOLCHAIN/logs/TARGET.TOOLCHAIN.log
echo 'foo foo name' >> testing/input/builds/TARGET/TOOLCHAIN/logs/TARGET.TOOLCHAIN.log
TESTING=1 ./CoremarkPro.sh testing/input 2>&1 && false #fails on being unable to read performance data (will fail with $6: unbound variable, because first thing report_measured looks at is pass/fail)
sed -i '$d' testing/input/builds/TARGET/TOOLCHAIN/logs/TARGET.TOOLCHAIN.log
echo 'foo foo name 4 5 0' >> testing/input/builds/TARGET/TOOLCHAIN/logs/TARGET.TOOLCHAIN.log
TESTING=1 ./CoremarkPro.sh testing/input 2>&1 && false #fails on being unable to read runtime (will fail with $7: unbound variable)
sed -i '$d' testing/input/builds/TARGET/TOOLCHAIN/logs/TARGET.TOOLCHAIN.log
echo 'foo foo name 4 5 0 7' >> testing/input/builds/TARGET/TOOLCHAIN/logs/TARGET.TOOLCHAIN.log
TESTING=1 ./CoremarkPro.sh testing/input 2>&1 && false #fails on being unable to read it_per_sec (will fail with $9: unbound variable)
echo '#Median' > testing/input/builds/TARGET/TOOLCHAIN/logs/TARGET.TOOLCHAIN.log
TESTING=1 ./CoremarkPro.sh testing/input 2>&1 && false #fails on absence of next line (will fail with line[$i]: unbound variable)
echo 'foo foo' >> testing/input/builds/TARGET/TOOLCHAIN/logs/TARGET.TOOLCHAIN.log
TESTING=1 ./CoremarkPro.sh testing/input 2>&1 && false #fails on trying to read name from next line ($3: unbound variable)
sed -i '$d' testing/input/builds/TARGET/TOOLCHAIN/logs/TARGET.TOOLCHAIN.log
echo 'foo foo name' >> testing/input/builds/TARGET/TOOLCHAIN/logs/TARGET.TOOLCHAIN.log
TESTING=1 ./CoremarkPro.sh testing/input 2>&1 && false #fails on being unable to read performance data (will fail with $6: unbound variable, because first thing report_measured looks at is pass/fail)
sed -i '$d' testing/input/builds/TARGET/TOOLCHAIN/logs/TARGET.TOOLCHAIN.log
echo 'foo foo name 4 5 0' >> testing/input/builds/TARGET/TOOLCHAIN/logs/TARGET.TOOLCHAIN.log
TESTING=1 ./CoremarkPro.sh testing/input 2>&1 && false #fails on being unable to read runtime (will fail with $7: unbound variable)
sed -i '$d' testing/input/builds/TARGET/TOOLCHAIN/logs/TARGET.TOOLCHAIN.log
echo 'foo foo name 4 5 0 7' >> testing/input/builds/TARGET/TOOLCHAIN/logs/TARGET.TOOLCHAIN.log
TESTING=1 ./CoremarkPro.sh testing/input 2>&1 && false #fails on being unable to read it_per_sec (will fail with $9: unbound variable)

#should fail with bad dir
TESTING=1 ./CoremarkPro.sh testing/input/fail 2>&1 && false #check_dir "${run}"
mkdir testing/input/fail
TESTING=1 ./CoremarkPro.sh testing/input/fail 2>&1 && false #check_dir "${run}/builds" (exists)
touch testing/input/fail/builds
TESTING=1 ./CoremarkPro.sh testing/input/fail 2>&1 && false #check_dir "${run}/builds" (is a dir)
rm testing/input/fail/builds
mkdir -p testing/input/fail/builds/TARGET/TOOLCHAIN/logs
touch    testing/input/fail/builds/TARGET/TOOLCHAIN/logs/TARGET.TOOLCHAIN.log
touch    testing/input/fail/builds/TARGET/TOOLCHAIN/cert
TESTING=1 ./CoremarkPro.sh testing/input/fail  #cert existing as a non-directory is harmless

#Check number of logs
rm -rf testing/input/fail
mkdir -p testing/input/fail/builds
TESTING=1 ./CoremarkPro.sh testing/input/fail 2>&1 && false #echo "Found no log"
mkdir -p testing/input/fail/builds/TARGET1/TOOLCHAIN/logs
touch    testing/input/fail/builds/TARGET1/TOOLCHAIN/logs/TARGET1.TOOLCHAIN.log
mkdir -p testing/input/fail/builds/TARGET2/TOOLCHAIN/logs
touch    testing/input/fail/builds/TARGET2/TOOLCHAIN/logs/TARGET2.TOOLCHAIN.log
TESTING=1 ./CoremarkPro.sh testing/input/fail 2>&1 && false #echo "Found more than one log"

exec 1>&${STDOUT}
error=0
