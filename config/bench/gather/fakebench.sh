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

#Make sure we can see what this thing is doing
exec 1>/dev/console
exec 2>&1

function report {
  if test -e $1; then
    #The funky quoting is to stop test-case from confusing syntax highlighting
    'lava-test-case' "`basename $1`" --result "${result}" \
                      --measurement "`cat $1`" --units $2
  else
    'lava-test-case' "`basename $1`" --result fail
    failed=1
  fi
}

#dirname/basename remove trailing slashes, too
topdir="`dirname $1`"
handle="`basename $1`" #name of repository in sources.conf, or top
                       #dir of tarball for prebuilt benchmarks
resultsdir="${handle}/fake/fakeresults" #relative path from topdir

if ! test -d "${topdir}"; then
  echo "No such directory as ${topdir}"
  exit
fi

cd "${topdir}" #do everything in context of topdir - simpler, and results in
               #LAVA reporting sane paths for attachments

if ! test -d "${resultsdir}"; then
  echo "No such directory as ${topdir}/${resultsdir}" >&2
  exit
fi

#Report pass or fail, based on RETCODE
if ! test -e "RETCODE"; then
  echo "No RETCODE file" >&2
  exit
fi
if test x"`cat RETCODE`" = x0; then
  result='pass'
else
  result='fail'
  failed=1
fi

#Produce results
report "${resultsdir}/tallyman1" bananas
report "${resultsdir}/tallyman2" tarantulas

#Attach raw output
'lava-test-case' output --result pass
'lava-test-case-attach' output "RETCODE"
'lava-test-case-attach' output "stdout"
'lava-test-case-attach' output "stderr"
'lava-test-case-attach' output "${handle}/linarobenchlog"
for x in `find "${handle}/fake/fakeresults" -type f`; do
  'lava-test-case-attach' output "$x"
done

error=0
