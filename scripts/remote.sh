#!/bin/bash

topdir=`dirname $0`/..
. ${topdir}/lib/common.sh
. ${topdir}/lib/remote.sh

cleanup()
{
  local error=$?

  #Make sure we sweep up the async ssh process - it should die eventually
  #but this is a bit more tidy. We make sure that it is the same process,
  #and not some much later process that happens to have the same id, by
  #checking ppid.
  if test x"`ps -p ${sshpid} -o ppid=`" = x"$$"; then
    kill ${sshpid}
  fi

  if test x"${target_dir}" = x; then
    notice "No directory to remove from ${target_ip}"
    exit "${error}"
  fi
  if test ${cleanup} -eq 0; then
    notice "Not removing ${target_dir} from ${target_ip} as -m was given. You might want to go in and clean up."
    exit "${error}"
  fi

  expr "${target_dir}" : '\(/tmp\)' > /dev/null
  if test $? -ne 0; then
    error "Cowardly refusing to delete ${target_dir} from ${target_ip}. Not rooted at /tmp. You might want to go in and clean up."
    exit 1
  fi

  remote_exec "${target_ip}" "rm -rf ${target_dir}"
  if test $? -eq 0; then
    notice "Removed ${target_dir} from ${target_ip}"
    exit "${error}"
  else
    error "Failed to remove ${target_dir} from ${target_ip}. You might want to go in and clean up."
    exit 1
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

#Fiddle IP if we are outside the network. Rather linaro-specific, and depends upon
#having an ssh config equivalent to TODO wikiref
if ! remote_exec "${target_ip}" true > /dev/null 2>&1; then
  target_ip+='.lava'
  if ! remote_exec "${target_ip}" true > /dev/null 2>&1; then
    error "Unable to connect to target ${target_ip%.lava} (also tried ${target_ip})"
    exit 1
  fi
fi

#Make sure we delete the remote dir when we're done
trap cleanup EXIT

#Should be a sufficient UID, as we wouldn't want to run multiple benchmarks on the same target at the same time
uid="${target_ip}_`date +%s`"
if test -e "${logdir}/${uid}"; then
  error "Log output directory "${logdir}/${uid}" already exists"
fi
mkdir -p "${logdir}/${uid}"
if test $? -ne 0; then
  error "Failed to create dir ${logdir}/${uid}"
  exit 1
fi
for log in "$@"; do
  mkdir -p "${logdir}/${uid}/`dirname ${log}`"
  if test $? -ne 0; then
    error "Failed to create dir ${logdir}/${uid}/`dirname ${log}`"
    exit 1
  fi
done

target_dir="`remote_exec ${target_ip} 'mktemp -dt XXXXXXX'`"
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

#We have to run the ssh command asynchronously, because having the
#network down during a long-running benchmark will result in ssh
#death sooner or later - we can stop ssh client and ssh server from
#killing the connection, but the TCP layer will get it eventually.
remote_exec_async ${target_ip} "cd ${target_dir} && ${cmd_to_run}" "${target_dir}/stdout" "${target_dir}/stderr"
sshpid=$?
if test ${sshpid} -lt 2; then
  error "ssh command failed"
  exit 1
fi
#TODO: Do we want a timeout around this? If stdout is not produced then we'll wedge
while true; do
  ret="`remote_exec ${target_ip} \"grep '^EXIT CODE: [[:digit:]]' ${target_dir}/stdout\"`"
  if test $? -eq 0; then
    ret="`echo $ret | cut -d ' ' -f 3`"
    break
  else
    sleep 60
  fi
done

if test ${ret} -ne 0; then
  error "Command failed: will try to get logs"
  error "Failing command: ${cmd_to_run}"
  error "Target: ${target_ip}:${target_dir}"
  ret=1
fi 
for log in stdout stderr "$@"; do
  remote_exec "${target_ip}" "cd '${target_dir}' && cat '${log}'" | ccencrypt -k ~/.ssh/id_rsa > "${logdir}/${uid}/${log}" #TODO what about ssh-agent?
  if test $? -ne 0; then
    rm -f "${logdir}/${uid}/${log}" #We just encrypted nothing into this file, delete it to avoid confusion
    error "Failed to get encrypted log ${log}: will try to get others"
    ret=1
  fi
done
if test ${ret} -eq 0; then
  if test x`ccat -k ~/.ssh/id_rsa ${logdir}/${uid}/stdout | grep -c '^EXIT CODE: [[:digit:]]'` = x1; then
    ret=`ccat -k ~/.ssh/id_rsa ${logdir}/${uid}/stdout | grep '^EXIT CODE: [[:digit:]]' | sed 's/[^[:digit:]]*//'`
  fi
fi
exit ${ret}
