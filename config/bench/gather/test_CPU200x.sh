#!/bin/bash
set -ue
set -o pipefail

cfp2000=(168.wupwise 171.swim 172.mgrid 173.applu 177.mesa 178.galgel 179.art 183.equake 187.facerec 188.ammp 189.lucas 191.fma3d 200.sixtrack 301.apsi)
cint2000=(164.gzip 175.vpr 176.gcc 181.mcf 186.crafty 197.parser 252.eon 253.perlbmk 254.gap 255.vortex 256.bzip2 300.twolf)
cfp2006=(410.bwaves 416.gamess 433.milc 434.zeusmp 435.gromacs 436.cactusADM 437.leslie3d 444.namd 447.dealII 450.soplex 453.povray 454.calculix 459.GemsFDTD 465.tonto 470.lbm 481.wrf 482.sphinx3)
cint2006=(400.perlbench 401.bzip2 403.gcc 429.mcf 445.gobmk 456.hmmer 458.sjeng 462.libquantum 464.h264ref 471.omnetpp 473.astar 483.xalancbmk)

declare -A names invalid
names['fp']=
names['int']=

function exit_handler {
  if test $? -eq 0; then
    echo "CPU2006 gather script passed self-tests"
  else
    echo "CPU2006 gather script FAILED self-tests" >&2
  fi
}

#This only works in some cases, keeping it as it is useful when it works,
#not wasting any more time trying to understand it.
function err_handler {
  exec 1>&2
  echo "ERROR"
  echo "Stack trace, excluding subshells:"
  local frame=0
  while caller ${frame}; do
    frame=$((frame + 1))
  done
}

trap exit_handler EXIT
trap err_handler ERR

function random_benchmarks {
  local bset
  local reference_bset
  local i
  local range
  local candidate
  local index
  declare -A count #local (see 'help declare')

  #These must be empty before we start, otherwise we can get dups
  names['fp']=
  names['int']=
  count['fp']=$((RANDOM % 10))
  count['int']=$((9 - ${count[fp]}))

  for bset in fp int; do
    declare -A indices #(Re)declare to use (after clearing)

    reference_bset="c${bset}${year}[@]"
    reference_bset=("${!reference_bset}")
    range=${#reference_bset[@]}

    for i in `seq 0 ${count[${bset}]}`; do
      candidate=$((RANDOM % range))
      while test -n "${indices["${candidate}"]:-}"; do
        candidate=$((RANDOM % range))
      done
      indices["${candidate}"]=x
    done

    for index in `echo ${!indices[@]} | tr ' ' '\n' | sort -g`; do
      names["${bset}"]="${names[${bset}]} ${reference_bset[${index}]}"
    done
    names["${bset}"]="${names[${bset}]:1}" #strip leading whitespace

    unset indices #Clear
  done
}

function generate_subbenchmark {
  local median ratio base min max runtime count ratio base_multiplier min_mult max_mult
  if test x"${size}" = xtest; then
    median=0.${RANDOM} #Ensure that products have 0 integer part, so that we can test leading 0 output (except for the ratio case, will hope for the best there)
    ratio='--'
    base='--'
  elif test x"${size}" = xtrain; then
    median=${RANDOM}.${RANDOM}
    ratio='--'
    base='--'
  elif test x"${size}" = xref; then
    median=`echo "(${RANDOM}.${RANDOM} * 10)" | bc`
    base_multiplier=$((RANDOM % 25 + 25)) #25 - 49
    base=`echo "($median * $base_multiplier) / 1" | bc`
  else
    echo "Bad args" >&2
    exit 1
  fi
  min_mult=$((RANDOM % 5 + 95)) #95 - 99
  max_mult=$((RANDOM % 5 + 1)) #1 - 5
  min=`echo "scale=6; ${median} * 0.${min_mult}"  | bc -l | awk '{printf "%f", $0}'`
  max=`echo "scale=6; ${median} * 1.0${max_mult}" | bc -l | awk '{printf "%f", $0}'`
  runtime=(${min} ${median} ${max})

  count=0
  invalidate="${invalid[$1]:-}"
  for i in `echo -e "0\\n1\\n2" | sort -R`; do
    if test -n "${invalidate:-}" && test ${count} -eq ${invalidate}; then
      testcase=("${testcase[@]}" "lava-test-case $1[00${count}] --result fail")
      ratio='--'
    else
      testcase=("${testcase[@]}" "lava-test-case $1[00${count}] --result pass --measurement ${runtime[$i]} --units seconds")
      if test x${size} = xref; then
        ratio=`echo "${base}/${runtime[$i]}" | bc -l`
        if test x"${year}" = x2000; then
          ratio=`echo "${ratio} * 100" | bc -l`
        fi
        testcase=("${testcase[@]}" "lava-test-case $1[00${count}] --result pass --measurement ${ratio} --units ratio")
      fi
    fi
    if test $((i%2)) -eq 1; then
      if test -n "${invalidate:-}" && test ${count} -eq ${invalidate}; then
        testcase_selected=("${testcase_selected[@]}" "lava-test-case $1 --result fail")
      else
        testcase_selected=("${testcase_selected[@]}" "lava-test-case $1 --result pass --measurement ${runtime[$i]} --units seconds")
        selected_count=$((selected_count + 1))
        selected_product_runtime=`echo "${selected_product_runtime} * ${runtime[$i]}" | bc -l`
        if test x${size} = xref; then
          testcase_selected=("${testcase_selected[@]}" "lava-test-case $1 --result pass --measurement ${ratio} --units ratio")
          selected_product_ratio=`echo "${selected_product_ratio} * ${ratio}" | bc -l`
        fi
      fi
    fi
    echo "spec.cpu${year}.results.${1%%.*}_${1#*.}.base.00${count}.benchmark: $1"
    echo "spec.cpu${year}.results.${1%%.*}_${1#*.}.base.00${count}.reference: ${base}"
    echo "spec.cpu${year}.results.${1%%.*}_${1#*.}.base.00${count}.reported_time: ${runtime[$i]}"
    echo "spec.cpu${year}.results.${1%%.*}_${1#*.}.base.00${count}.ratio: ${ratio}"
    echo "spec.cpu${year}.results.${1%%.*}_${1#*.}.base.00${count}.selected: $((i % 2))"
    if test -n "${invalidate:-}" && test ${count} -eq ${invalidate}; then
      echo "spec.cpu${year}.results.${1%%.*}_${1#*.}.base.00${count}.valid: ${invalidmarker}"
    else
      echo "spec.cpu${year}.results.${1%%.*}_${1#*.}.base.00${count}.valid: ${validmarker}"
    fi
    count=$((count + 1))
  done
}

function test_benchmark {
  local reference_bset
  local unit

  #echo "test_benchmark $@" >&2

  rm -rf testing
  mkdir -p testing/input/result

  for bset in "$@"; do
    exec {STDOUT}>&1
    exec 1>testing/input/result/C${bset^^}${year}.001.${rawext}
    testcase=('')
    testcase_selected=('')
    selected_count=0
    selected_product_runtime=1
    selected_product_ratio=1
    reference_bset="c${bset}${year}[*]"
    echo "spec.cpu${year}.size: ${size}"

    #If we have set any subbenchmarks to fail in the current bset then,
    #probably, we should set spec.cpu${year}.invalid to 1. However, this
    #does not exercise anything we are not already testing and is a pain
    #to do neatly. So we don't bother.
    if test x"${names[${bset}]}" = x"${!reference_bset}"; then
      echo "spec.cpu${year}.invalid: 0"
      unit="SPEC${bset}"
    else
      echo "spec.cpu${year}.invalid: 1"
      unit="SPEC${bset} (invalid)"
    fi
    echo "spec.cpu${year}.metric: C${bset^^}${year}"
    echo "spec.cpu${year}.units: SPEC${bset}"
    for name in ${names[${bset}]}; do
      generate_subbenchmark $name
    done

    for x in "${testcase[@]:1}"; do
      echo "$x" >> testing/golden
    done
    for x in "${testcase_selected[@]:1}"; do
      echo "$x" >> testing/golden
    done
    printf 'lava-test-case %s --result pass --measurement %f --units %s\n' \
      "C${bset^^}${year} base runtime geomean" \
      `echo "scale=6; e(l(${selected_product_runtime})/${selected_count})" | bc -l` \
      'seconds' >> testing/golden
    if test x"${size}" = xref; then
      score=`echo "scale=6; e(l(${selected_product_ratio})/${selected_count})" | bc -l`
      echo "spec.cpu${year}.basemean: ${score}"
      printf 'lava-test-case %s --result pass --measurement %f --units %s\n' \
        "C${bset^^}${year} base score" \
        ${score} \
        "${unit}" >> testing/golden
    else
      echo "spec.cpu${year}.basemean: 0"
    fi
    exec 1>&${STDOUT}
  done

  echo 'lava-test-run-attach RETCODE text/plain' >> testing/golden
  echo 'lava-test-run-attach stdout text/plain' >> testing/golden
  echo 'lava-test-run-attach stderr text/plain' >> testing/golden
  echo 'lava-test-run-attach linarobenchlog text/plain' >> testing/golden
  for bset in "$@"; do
    echo "lava-test-run-attach C${bset^^}${year}.001.${rawext} text/plain" >> testing/golden
  done

  TESTING=1 ./CPU200x.sh testing/input > testing/output
  diff testing/golden testing/output
}

#Test 'should fail' cases
rm -rf testing
TESTING=1 ./CPU200x.sh testing/input &>/dev/null && false #Directory of runs of benchmark script (testing/input) not found, or is not a directory

mkdir testing
touch testing/input
TESTING=1 ./CPU200x.sh testing/input &>/dev/null && false #Directory of runs of benchmark script (testing/input) not found, or is not a directory

rm testing/input
mkdir testing/input
TESTING=1 ./CPU200x.sh testing/input &>/dev/null && false #No runs of SPEC!

rm -rf testing/input
mkdir -p testing/input/result
touch testing/input/result/CINT2000.001.raw
touch testing/input/result/CINT2000.002.raw
TESTING=1 ./CPU200x.sh testing/input &>/dev/null && false #Multiple runs of SPEC unsupported

rm -rf testing/input
mkdir -p testing/input/result
touch testing/input/result/CFP2000.001.raw
touch testing/input/result/CFP2000.002.raw
TESTING=1 ./CPU200x.sh testing/input &>/dev/null && false #Multiple runs of SPEC unsupported

rm -rf testing/input
mkdir -p testing/input/result
touch testing/input/result/CINT2006.test.001.rsf
touch testing/input/result/CINT2006.test.002.rsf
TESTING=1 ./CPU200x.sh testing/input &>/dev/null && false #Multiple runs of SPEC unsupported

rm -rf testing/input
mkdir -p testing/input/result
touch testing/input/result/CFP2006.test.001.rsf
touch testing/input/result/CFP2006.test.002.rsf
TESTING=1 ./CPU200x.sh testing/input &>/dev/null && false #Multiple runs of SPEC unsupported

rm -rf testing/input
mkdir -p testing/input/result
touch testing/input/result/CINT2006.test.001.rsf
touch testing/input/result/CINT2006.ref.002.rsf
TESTING=1 ./CPU200x.sh testing/input &>/dev/null && false #Multiple runs of SPEC unsupported

rm -rf testing/input
mkdir -p testing/input/result
touch testing/input/result/CINT2006.test.001.rsf
TESTING=1 ./CPU200x.sh testing/input &>/dev/null && false #Bad vintage (empty file?)
TESTING=1 ./CPU2000.sh testing/input &>/dev/null && false #SPEC vintage of input file does not match set year (empty file is among the possible causes)
TESTING=1 ./CPU2006.sh testing/input &>/dev/null && false #SPEC vintage of input file does not match set year (empty file is among the possible causes)

#Non-test: we don't test that we report the 'mixture of spec inputs' error,
#          just because this is so unlikely to ever happen.

#CPU2000
names['fp']="${cfp2000[*]}"
names['int']="${cint2000[*]}"
year=2000
validmarker='1'
invalidmarker='0'
rawext='raw'
for size in 'test' 'train' 'ref'; do
  test_benchmark fp int #order matters - CPU200x.sh always processes fp then int if both are present
  test_benchmark int
  test_benchmark fp
done

#Test that we work if called through the right wrapper
TESTING=1 ./CPU2000.sh testing/input > testing/output
diff testing/golden testing/output

#Test that we fail if called through the wrong wrapper
TESTING=1 ./CPU2006.sh testing/input &>/dev/null && false #SPEC vintage of input file does not match set year.

#Test that we handle invalid individual tests
unset invalid
declare -A invalid=(['172.mgrid']=1 ['178.galgel']=0 ['175.vpr']=2)
test_benchmark fp int
unset invalid
declare -A invalid

#test smaller runs
#1 int run
names['int']=254.gap
test_benchmark int
names['fp']=172.mgrid
#1 fp run
test_benchmark fp
#1 each in int and fp
test_benchmark fp int

#5 runs of 1-10 randomly selected benchmarks across both suites
for i in `seq 0 4`; do
  random_benchmarks
  #echo "CFP2000@${names[fp]}@CFP2000" >&2
  #echo "CINT2000@${names[int]}@CINT2000" >&2
  test_benchmark ${names['fp']:+fp} ${names['int']:+int}
done

#CPU2006
names['fp']="${cfp2006[*]}"
names['int']="${cint2006[*]}"
year=2006
size='ref'
validmarker='S'
invalidmarker='X'
for size in 'test' 'train' 'ref'; do
  rawext="${size}.rsf"
  test_benchmark fp int #order matters - CPU200x.sh always processes fp then int if both are present
  test_benchmark int
  test_benchmark fp
done

#Test that we work if called through the right wrapper
TESTING=1 ./CPU2006.sh testing/input > testing/output
diff testing/golden testing/output

#Test that we fail if called through the wrong wrapper
TESTING=1 ./CPU2000.sh testing/input &>/dev/null && false #SPEC vintage of input file does not match set year.

#Test that we handle invalid individual tests
unset invalid
declare -A invalid=(['410.bwaves']=0 ['483.xalancbmk']=2)
test_benchmark fp int
unset invalid
declare -A invalid

#test smaller runs
#1 int run
names['int']=254.gap
test_benchmark int
names['fp']=400.perlbench
#1 fp run
test_benchmark fp
#1 each in int and fp
test_benchmark fp int

#5 runs of 1-10 randomly selected benchmarks across both suites
for i in `seq 0 4`; do
  random_benchmarks
  #echo "CFP2006@${names[fp]}@CFP2006" >&2
  #echo "CINT2006@${names[int]}@CINT2006" >&2
  test_benchmark ${names['fp']:+fp} ${names['int']:+int}
done
