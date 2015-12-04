#!/bin/bash
set -ue

function doit {
  min_mult=$((RANDOM % 5 + 95)) #95 - 99
  max_mult=$((RANDOM % 5 + 1)) #1 - 5

  median=${RANDOM}.${RANDOM}
  min=`echo "scale=6; ${median} * 0.${min_mult}" | bc -l`
  max=`echo "scale=6; ${median} * 1.0${max_mult}" | bc -l`

  runtime=(${min} ${median} ${max})
  base_multiplier=$((RANDOM % 25 + 25)) #25 - 49
  base=`echo "($median * $base_multiplier) / 1" | bc`

  count=1
  for i in `echo -e "0\\n1\\n2" | sort -R`; do
    ratio=`echo "${base}/${runtime[$i]}" | bc -l`
    line="`printf '%s,%i,%f,%f,%i,S,,,,,,ref iteration #%i\n' \
      $1 \
      $base \
      ${runtime[$i]} \
      ${ratio} \
      $((i % 2)) \
      ${count}`"
    testcase=("${testcase[@]}" \
      "`printf 'lava-test-case %s[%i] --result pass --measurement %f --units %s\n' \
        $1 ${count} ${runtime[$i]} 'seconds'`" \
      "`printf 'lava-test-case %s[%i] --result pass --measurement %f --units %s\n' \
        $1 ${count} ${ratio} 'ratio'`"
      )
    if test $((i%2)) -eq 1; then
      selected=("${selected[@]}" "$line")
      testcase_selected=("${testcase_selected[@]}" \
      "`printf 'lava-test-case %s --result pass --measurement %f --units %s\n' \
        $1 ${runtime[$i]} 'seconds'`" \
      "`printf 'lava-test-case %s --result pass --measurement %f --units %s\n' \
        $1 ${ratio} 'ratio'`"
      )
      selected_count=$((selected_count + 1))
      selected_product_runtime=`echo "${selected_product_runtime} * ${runtime[$i]}" | bc -l`
      selected_product_ratio=`echo "${selected_product_ratio} * ${ratio}" | bc -l`
    fi
    count=$((count + 1))
    echo $line
  done
}

declare -A names
names['fp']='410.bwaves 416.gamess 433.milc 434.zeusmp 435.gromacs 436.cactusADM 437.leslie3d 444.namd 447.dealII 450.soplex 453.povray 454.calculix 459.GemsFDTD 465.tonto 470.lbm 481.wrf 482.sphinx3'
names['int']='400.perlbench 401.bzip2 403.gcc 429.mcf 445.gobmk 456.hmmer 458.sjeng 462.libquantum 464.h264ref 471.omnetpp 473.astar 483.xalancbmk'
rm -rf testing
mkdir -p testing/input/result
for bset in fp int; do
  exec {STDOUT}>&1
  exec 1>testing/input/result/C${bset^^}2006.1.test.csv
  echo '"Full Results Table"'
  echo
  selected=('"Selected Results Table"' '')
  testcase=('')
  testcase_selected=('')
  selected_count=0
  selected_product_runtime=1
  selected_product_ratio=1
  for name in ${names[${bset}]}; do
    doit $name
  done
  echo
  for x in "${selected[@]}"; do
    echo "$x"
  done
  echo
  score=`echo "scale=6; e(l(${selected_product_ratio})/${selected_count})" | bc -l`
  echo "SPEC${bset}_base2006,${score},,${score}"

  for x in "${testcase[@]:1}"; do
    echo "$x" >> testing/golden
  done
  for x in "${testcase_selected[@]:1}"; do
    echo "$x" >> testing/golden
  done
  printf 'lava-test-case %s --result pass --measurement %f --units %s\n' \
    "C${bset^^}2006 base runtime geomean" \
    `echo "scale=6; e(l(${selected_product_runtime})/${selected_count})" | bc -l` \
    'geomean of selected runtimes (seconds)' >> testing/golden
  printf 'lava-test-case %s --result pass --measurement %f --units %s\n' \
    "C${bset^^}2006 base score" \
    ${score} \
    'base score (geomean of selected ratios)' >> testing/golden
  exec 1>&${STDOUT}
done

echo 'lava-test-run-attach RETCODE' >> testing/golden
echo 'lava-test-run-attach stdout' >> testing/golden
echo 'lava-test-run-attach stderr' >> testing/golden
echo 'lava-test-run-attach linarobenchlog' >> testing/golden
echo 'lava-test-run-attach CFP2006.1.test.csv' >> testing/golden
echo 'lava-test-run-attach CINT2006.1.test.csv' >> testing/golden

TESTING=1 ./CPU2006.sh testing/input > testing/output

if diff testing/{golden,output}; then
  echo "CPU2006 gather script passed self-tests"
  exit 0
else
  echo "CPU2006 gather script FAILED self-tests"
  exit 1
fi
