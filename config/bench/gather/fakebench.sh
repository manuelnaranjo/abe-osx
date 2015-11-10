#!/bin/bash

set -eux
set -o pipefail

error=1
failed=0

function exit_handler {
  if test ${failed} -eq 0; then
    exit ${error}
  else
    exit 1
  fi
}

trap exit_handler EXIT

function report {
  if test -e $1; then
    #The funky quoting is to stop test-case from confusing syntax highlighting
    'lava-test-case' "`basename $1`" --result "${result}" --measurement "`cat $1`" --units $2
  else
    'lava-test-case' "`basename $1`" --result fail
    failed=1
  fi
}

resultsdir="$1/fake/fakeresults"
if ! test -d "${resultsdir}"; then
  echo "No such directory as ${resultsdir}" >&2
  exit
fi
if ! test -e "$1/../RETCODE"; then
  echo "No RETCODE file" >&2
  exit
fi
if test x"`cat $1/../RETCODE`" = x0; then
  result='pass'
else
  result='fail'
  failed=1
fi
report "${resultsdir}/tallyman1" bananas
report "${resultsdir}/tallyman2" tarantulas

error=0
