#!/bin/bash

set -eu
set -o pipefail

error=1

function ltc {
  #Funky quoting to help out syntax highlighters
  ${TESTING:+echo} 'lava-test-case' "$@"
}

function exit_handler {
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

function base_status {
  local field
  field="`echo $1 | cut -d , -f 6`" || exit
  if test x"${field}" = xS; then
    return 0
  else
    return 1
  fi
}

function name {
  echo $1 | cut -d , -f 1 || exit
}

function base_runtime {
  echo $1 | cut -d , -f 3 || exit
}

function base_ratio {
  echo $1 | cut -d , -f 4 || exit
}

#TODO if there is a base and peak run, we should report both sides FUTURE WORK
#TODO pass other useful data as attributes - e.g. workload, other data from the csv file
if test x"${1:-}" = x; then
  echo "Directory of runs of benchmark script not given" >&2
  exit
fi
if ! test -d $1; then
  echo "Directory of runs of benchmark script ($1) not found, or is not a directory" >&2
  exit 1
fi
if test "`ls $1 | wc -l`" -gt 1; then
  echo "Multiple runs of benchmark script not supported" >&2
  exit 1
fi
if test "`ls $1 | wc -l`" -ne 1; then
  echo "No runs of benchmark script!" >&2
  exit 1
fi

run="$1"
if ! test -d "${run}"; then
  echo "Run directory ${run} not a directory!" >&2
  exit 1
fi
if test "`ls ${run}/result/CINT2006.*.*.csv 2>/dev/null | wc -l`" -gt 1 ||
   test "`ls ${run}/result/CFP2006.*.*.csv  2>/dev/null | wc -l`" -gt 1; then
  echo "Multiple runs of SPEC unsupported" >&2
  exit 1
fi
if test "`ls ${run}/result/CINT2006.*.*.csv 2>/dev/null | wc -l`" -ne 1 &&
   test "`ls ${run}/result/CFP2006.*.*.csv  2>/dev/null | wc -l`" -ne 1; then
  echo "No runs of SPEC!" >&2
  exit 1
fi

for csv in `ls ${run}/result/C{INT,FP}2006.*.*.csv 2>/dev/null`; do
  #data about the run
  run_set="`basename ${csv} | cut -d . -f 1`" || exit #CINT2006 or CFP2006
  run_index=$((`basename ${csv} | cut -d . -f 2` - 1)) || exit #Always 1 so long as we aren't supporting multiple runs of SPEC
  run_workload="`basename ${csv} | cut -d . -f 3`" || exit #test, train, ref

  #slurp results file
  line=("")
  while IFS='' read -r l; do line=("${line[@]}" "${l}"); done < "${csv}"
  line_max=$((${#line[@]} - 1))

  #submit full results
  for i in `seq 0 ${line_max}`; do
    if test x"${line[$i]}"x = x'"Full Results Table"'x; then break; fi
  done

  iteration=0
  oldname=""
  for i in `seq $((i + 2)) ${line_max}`; do
    if test x"${line[$i]}"x = xx; then break; fi
    name="`name ${line[$i]}`"
    runtime="`base_runtime ${line[$i]}`"
    ratio="`base_ratio ${line[$i]}`"

    if test x"${name}" = x"${oldname}"; then
      iteration=$((iteration + 1))
    else
      iteration=1
    fi

    if base_status "${line[$i]}"; then
      ltc "${name}[${iteration}]" \
        --result pass --measurement "${runtime}" --units seconds
      if test x"${ratio}" != x; then
        ltc "${name}[${iteration}]" \
          --result pass --measurement "${ratio}" --units ratio
      fi
    else
      ltc "${name}[${iteration}]" --result fail
    fi

    oldname="${name}"
  done

  #submit selected results
  for i in `seq $((i + 1)) ${line_max}`; do
    if test x"${line[$i]}"x = x'"Selected Results Table"'x; then break; fi
  done

  count=0
  base_runtime_product=1
  for i in `seq $((i + 2)) ${line_max}`; do
    if test x"${line[$i]}"x = xx; then break; fi
    name="`name ${line[$i]}`"
    runtime="`base_runtime ${line[$i]}`"
    ratio="`base_ratio ${line[$i]}`"
    if base_status "${line[$i]}"; then
      count=$((count + 1))
      base_runtime_product="`echo \"${base_runtime_product} * ${runtime}\" | bc`" || exit
      ltc "${name}" --result pass \
        --measurement "${runtime}" --units seconds
      if test x"${ratio}" != x; then
        ltc "${name}" --result pass \
          --measurement "${ratio}" --units ratio
      fi
    else
      ltc "${name}" --result fail
    fi
  done

  #compute and report geomean of runtime
  if test ${count} -ne 0; then
    ltc "${run_set} base runtime geomean" --result pass \
      --measurement "`echo \"scale=6; e(l(${base_runtime_product})/${count})\" | bc -l`" \
      --units 'geomean of selected runtimes (seconds)' || exit
  else
    ltc "${run_set}" --result fail
  fi

  #if we have ratios, we will have a score to report
  if test x"`base_ratio ${line[$i-1]}`" != x; then
    i=$((i + 1))
    score="`echo ${line[$i]} | cut -d , -f 2`" || exit
    ltc "${run_set} base score" --result pass \
      --measurement "${score}" --units 'base score (geomean of selected ratios)'
  fi
done

error=0
