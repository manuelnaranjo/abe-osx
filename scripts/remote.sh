#!/bin/bash
#TODO trap exits and clean up target

topdir=`dirname $0`/..
. ${topdir}/lib/common.sh
. ${topdir}/lib/remote.sh

cleanup()
{
  if test x"${target_dir}" != x; then
    expr "${target_dir}" : '\(/tmp\)' > /dev/null
    if test $? -eq 0; then
      remote_exec "${target_ip}" "rm -rf ${target_dir}"
      return 0
    else
      error "Cowardly refusing to delete '${target_dir}' not rooted at /tmp. You might want to go in and clean up."
      return 1
    fi
  fi
}

dryrun=no

target_ip="$1"
thing_to_run="$2"
cmd_to_run="$3"
shift 3
#Remaining args are log files to copy back

uid="${thing_to_run}_${target_ip}_`date +%s`"

trap cleanup EXIT

target_dir="`remote_exec '${target_ip}' 'mktemp -dt XXXXXXX'`"
if test $? -ne 0; then
  error "Unable to get tmpdir on target"
  exit 1
fi
remote_upload "${target_ip}" "${thing_to_run}" "${target_dir}/${thing_to_run}"
if test $? -ne 0; then
  error "Unable to copy ${thing_to_run}" to "${target_ip}:${target_dir}/${thing_to_run}"
  exit 1
fi
remote_exec "${target_ip}" "cd '${target_dir}/${thing_to_run}' && ${cmd_to_run}"
if test $? -ne 0; then
  error "Command to run benchmark failed"
  exit 1
fi 
mkdir -p logs/"${uid}"
if test $? -ne 0; then
  error "Failed to create dir logs/${uid}"
  exit 1
fi
for log in "$@"; do
  mkdir -p "logs/${uid}/`dirname ${log}`"
  if test $? -ne 0; then
    error "Failed to create dir logs/${uid}/`dirname ${log}`"
    exit 1
  fi
  remote_exec "${target_ip}" "cd '${target_dir}/${thing_to_run}' && cat '${log}'" | ccencrypt -k ~/.ssh/id_rsa > "logs/${uid}/${log}" #TODO what about ssh-agent?
  if test $? -ne 0; then
    error "Failed to get encrypted log"
    exit 1
  fi
done
