#!/bin/bash

set -eu
set -o pipefail

error=1

function ltc {
  #Funky quoting to help out syntax highlighters
  ${TESTING:+echo} 'lava-test-case' "$@"
}

function ltra {
  #Funky quoting to help out syntax highlighters
  ${TESTING:+echo} 'lava-test-run-attach' "$@"
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

#Doesn't need to check that there are pattern inputs - the
#pattern generated if there are no such inputs is guaranteed
#to fail. (The pattern will be 'spec\.cpu2000: ' or 'spec\.cpu2006: ' in this
#case.)
function lookup {
  local file
  local re
  file="$1"
  shift
  re="spec\.cpu${year}"
  while test $# -ne 0; do
    re="${re}\.$1"
    shift
  done
  #echo "grep \"${re}: \" \"${file}\" | cut -f 2 -d : | sed 's/^[[:blank:]]*//' | sed 's/[[:blank:]]*$//'" >&2
  grep "${re}: " "${file}" | cut -f 2 -d : | sed 's/^[[:blank:]]*//' | sed 's/[[:blank:]]*$//'
}

function valid {
  local res
  if test $# -eq 3; then
    test x"`lookup \"$1\" results \"$2\" '.*' \"$3\" valid`" = x"${validmarker}"
  elif test $# -eq 1; then
    test x"`lookup \"$1\" valid`" = x"${validmarker}"
  else
    echo "Bad arg for valid()" >&2
    exit 1
  fi
  return $?
}

function selected {
  test x"`lookup \"$1\" results \"$2\" '.*' \"$3\" selected`" = x1
  return $?
}

#TODO if there is a base and peak run, we should report both sides FUTURE WORK
#TODO pass other useful data as attributes - e.g. workload, other data from the csv file
run="$1"
if ! test -d "${run}"; then
  echo "Directory of runs of benchmark script ($1) not found, or is not a directory" >&2
  exit 1
fi
if test "`ls ${run}/result/CINT*.*.{raw,rsf} 2>/dev/null | wc -l`" -gt 1 ||
   test "`ls ${run}/result/CFP*.*.{raw,rsf}  2>/dev/null | wc -l`" -gt 1; then
  echo "Multiple runs of SPEC unsupported" >&2
  exit 1
fi
if test "`ls ${run}/result/CINT*.*.{raw,rsf} 2>/dev/null | wc -l`" -ne 1 &&
   test "`ls ${run}/result/CFP*.*.{raw,rsf}  2>/dev/null | wc -l`" -ne 1; then
  echo "No runs of SPEC!" >&2
  exit 1
fi

for raw in `ls ${run}/result/C{INT,FP}*.*.{raw,rsf} 2>/dev/null`; do
  #Only need to do this once, but we don't know which file will be present
  if grep -lq '^spec\.cpu2000\.' "${raw}"; then
    year='2000'
    rawext='raw'
    validmarker='1'
  elif grep -lq '^spec\.cpu2006\.' "${raw}"; then
    year='2006'
    rawext='*.rsf'
    validmarker='S'
  else
    echo "Bad vintage" >&2
    exit 1
  fi

  #data about the run
  run_index=$((`basename ${raw} | cut -d . -f 2` - 1)) || exit #Always 1 so long as we aren't supporting multiple runs of SPEC

  run_workload="`lookup "${raw}" size`"

  names="`lookup "${raw}" results '.*' benchmark | sort | uniq`"
  for name in ${names}; do
    iterations="`lookup ${raw} results ${name} '.*' benchmark | wc -l`"
    for iteration in `seq -w 001 ${iterations}`; do
      runtime="`lookup "${raw}" results ${name} '.*' ${iteration} reported_time`"
      ratio="`lookup   "${raw}" results ${name} '.*' ${iteration} ratio`"
      if valid "${raw}" "${name}" "${iteration}"; then
        ltc "${name}[${iteration}]" \
          --result pass --measurement "${runtime}" --units seconds
        if test x"${ratio}" != 'x--'; then
          ltc "${name}[${iteration}]" \
            --result pass --measurement "${ratio}" --units ratio
        fi
      else
        ltc "${name}[${iteration}]" --result fail
      fi
    done
  done

  #Output the selected ones at the end, always, so the results maintain the
  #same order in the LAVA interface. Shouldn't matter when looking at reports,
  #but kinda handy when looking at raw bundles.
  count=0
  base_runtime_product=1
  for name in ${names}; do
    iterations="`lookup ${raw} results ${name} '.*' benchmark | wc -l`"
    for iteration in `seq -w 001 ${iterations}`; do
      if selected "${raw}" "${name}" "${iteration}"; then
        if valid "${raw}" "${name}" "${iteration}"; then
          runtime="`lookup "${raw}" results ${name} '.*' ${iteration} reported_time`"
          ratio="`lookup   "${raw}" results ${name} '.*' ${iteration} ratio`"
          count=$((count + 1))
          base_runtime_product="`echo \"${base_runtime_product} * ${runtime}\" | bc`" || exit
          ltc "${name}" \
            --result pass --measurement "${runtime}" --units seconds
          if test x"${ratio}" != 'x--'; then
            ltc "${name}" \
              --result pass --measurement "${ratio}" --units ratio
          fi
        else
          ltc "${name}" --result fail
        fi
        break
      fi
    done
  done

  #compute and report geomean of runtime
  run_set="`lookup ${raw} metric`"
  if test ${count} -ne 0; then
    ltc "${run_set} base runtime geomean" --result pass \
      --measurement "`echo \"scale=6; e(l(${base_runtime_product})/${count})\" | bc -l`" \
      --units 'geomean of selected runtimes (seconds)' || exit

    #report score if there is one
    #tag it as invalid if the run is invalid
    #also report whether it is valid or not
    basemean="`lookup ${raw} basemean`"
    if test x"${basemean}" != x0; then
      units="`lookup ${raw} units`"
      if ! valid "${raw}"; then
	units="${units} (invalid)"
      fi
      ltc "${run_set} base score" --result pass \
       --measurement "${basemean}" \
       --units "${units}"
    fi
  else
    ltc "${run_set}" --result fail
  fi
done

#Attach raw output
pushd "${run}/.." > /dev/null
ltra "RETCODE"
ltra "stdout"
ltra "stderr"
popd > /dev/null
cd "${run}"
ltra "linarobenchlog"
cd result
for x in `find -type f | sed s/^..// | sort`; do
  ltra "$x"
done

error=0
