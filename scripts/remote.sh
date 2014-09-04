#!/bin/bash

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

cleanup=1
logdir=logs
while getopts t:f:c:mdl: flag; do
  case "${flag}" in
    t) target_ip="${OPTARG}";;
    f) things_to_run+=("${OPTARG}");;
    c) cmd_to_run="${OPTARG}";;
    m) cleanup=0;;
    d) dryrun=yes;;
    l) logdir="${OPTARG}";;
    *)
       echo 'Unknown option' 1>&2
       exit 1
    ;;
  esac
done
shift $((OPTIND - 1))
#Remaining args are log files to copy back

#Make sure we delete the remote dir when we're done
if test ${cleanup} -ne 0; then
  trap cleanup EXIT
fi

#Should be a sufficient UID, as we wouldn't want to run multiple benchmarks on the same target at the same time
uid="${target_ip}_`date +%s`"

target_dir="`remote_exec '${target_ip}' 'mktemp -dt XXXXXXX'`"
if test $? -ne 0; then
  error "Unable to get tmpdir on target"
  exit 1
fi
for thing_to_run in "${things_to_run[@]}"; do
  remote_upload "${target_ip}" "${thing_to_run}" "${target_dir}" #/`basename ${thing_to_run}`"
  if test $? -ne 0; then
    error "Unable to copy ${thing_to_run}" to "${target_ip}:${target_dir}/${thing_to_run}"
    exit 1
  fi
done
remote_exec "${target_ip}" "cd '${target_dir}' && ${cmd_to_run}"
if test $? -ne 0; then
  error "Command to run benchmark failed: will try to get logs"
  ret=1
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
  remote_exec "${target_ip}" "cd '${target_dir}' && cat '${log}'" | ccencrypt -k ~/.ssh/id_rsa > "${logdir}/${uid}/${log}" #TODO what about ssh-agent?
  if test $? -ne 0; then
    error "Failed to get encrypted log"
    exit 1
  fi
done
exit ${ret}
