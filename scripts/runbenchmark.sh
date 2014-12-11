#!/bin/bash
set -o pipefail

trap 'error=$?; kill -- -$BASHPID' EXIT
trap 'exit ${error}' TERM INT HUP QUIT

lava_pid=
benchmark=
device=
keep=
cautious=''
while getopts b:d:kc flag; do
  case "${flag}" in
    k) keep='-k';;
    c) cautious='-c';;
    b) benchmark="${OPTARG}";;
    d) device="${OPTARG}";;
    *)
       echo "Bad arg" 1>&2
       exit 1
    ;;
  esac
done
shift $((OPTIND - 1))
if test $# -ne 0; then
  echo "Surplus arguments: $@" 1>&2
  exit 1
fi

error=1
tee_output=/dev/null

topdir="`dirname $0`/.." #cbuild2 global, but this should be the right value for cbuild2
if ! test -e "${topdir}/host.conf"; then
  echo "No host.conf, did you run ./configure?" 1>&2
  exit 1
fi
confdir="${topdir}/config/boards/bench"
lavaserver="${USER}@validation.linaro.org/RPC2/"
builddir="`target2="${target}"; . ${topdir}/host.conf && . ${topdir}/lib/common.sh && if test x"${target2}" != x; then target="${target2}"; fi && get_builddir $(get_URL ${benchmark}.git)`"
if test $? -ne 0; then
  echo "Unable to get builddir" 1>&2
  exit 1
fi


benchlog="`. ${topdir}/host.conf && . ${topdir}/lib/common.sh && read_config ${benchmark}.git benchlog`"
if test $? -ne 0; then
  echo "Unable to read benchmark config file for ${benchmark}" 1>&2
  exit 1
fi

. "${topdir}"/scripts/listener.sh
if test $? -ne 0; then
  echo "+++ Unable to source `dirname $0`/listener.sh" 1>&2
  exit 1
fi
. "${confdir}/${device}.conf" #We can't use cbuild2's source_config here as it requires us to have something get_toolname can parse
if test $? -ne 0; then
  echo "+++ Failed to source ${confdir}/${device}.conf" 1>&2
  exit 1
fi

temps="`mktemp -dt XXXXXXXXX`" || exit 1
listener_file="${temps}/listener_file"
lava_fifo="${temps}/lava_fifo"
mkfifo "${lava_fifo}" || exit 1

#Make sure that subscripts clean up - we must not leave benchmark sources or data lying around,
#we should not leave lava targets reserved
clean_benchmark()
{
  error=$?
  local clean=0

  if test x"${target_dir}" = x; then
    echo "No directory to remove from ${ip}" 1>&2
  elif test x"${keep}" = '-k'; then
    echo "Not removing ${target_dir} from ${ip} as -k was given. You might want to go in and clean up."
    clean=1
  elif ! expr "${target_dir}" : '\(/tmp\)' > /dev/null; then
    echo "Cowardly refusing to delete ${target_dir} from ${ip}. Not rooted at /tmp. You might want to go in and clean up." 1>&2
    error=1
    clean=1
  else
    (. "${topdir}"/lib/common.sh; remote_exec "${ip}" "rm -rf ${target_dir}")
    if test $? -eq 0; then
      echo "Removed ${target_dir} from ${ip}"
    else
      echo "Failed to remove ${target_dir} from ${ip}. You might want to go in and clean up." 1>&2
      error=1
      clean=1
    fi
  fi

  if test -d "${temps}"; then
    rm -rf "${temps}"
    if test $? -ne 0; then
      echo "Failed to delete ${temps}" 1>&2
      error=1
    fi
  fi

  if test x"${lava_pid}" != x; then
    if test ${clean} -ne 0; then
      echo "Not killing lava.sh, to ensure session remains open for cleanup."
      echo "You can kill it with 'kill ${lava_pid}'."
    else
      kill "${lava_pid}"
      wait "${lava_pid}"
    fi
  fi
  kill -- -$BASHPID
}

#Set up our listener
#Has to happen before we deal with LAVA, so that we can port forward if we need to
listener_addr="`get_addr`"
if test $? -ne 0; then
  echo "Unable to get IP for listener" 1>&2
  exit 1
fi
listener_port="`establish_listener ${listener_addr} ${listener_file} 4200 5200`"
if test $? -ne 0; then
  echo "Unable to establish listener" 1>&2
  exit 1
fi
listener_addr=${listener_port/%:*}
listener_port=${listener_port/#*:}
echo "Listener ${listener_addr}:${listener_port}, writing to file ${listener_file}"
#Pretty much use this as a pipe - using an actual fifo seems to give nc fits
exec 5< <(tail -f "${listener_file}")

#Handle LAVA case
echo "${ip}" | grep '\.json$' > /dev/null
if test $? -eq 0; then
  lava_target="${ip}"
  ip=''
  tee_output=/dev/console
  echo "Acquiring LAVA target ${lava_target}"
  echo "${topdir}/scripts/lava.sh -s ${lavaserver} -j ${confdir}/${lava_target} -b ${boot_timeout:-30} ${keep}" 1>&2

  ${topdir}/scripts/lava.sh -s "${lavaserver}" -j "${confdir}/${lava_target}" -b "${boot_timeout-:30}" ${keep} > "${lava_fifo}" & #Don't enquote keep - if it is empty we want to pass nothing, not the empty string
  if test $? -ne 0; then
    echo "+++ Failed to acquire LAVA target ${lava_target}" 1>&2
    exit 1
  fi
  lava_pid=$!
  while read line < "${lava_fifo}"; do
    echo "${lava_target}: $line"
    if echo "${line}" | grep '^LAVA target ready at ' > /dev/null; then
      ip="`echo ${line} | cut -d ' ' -f 5 | sed 's/\s*$//'`"
      break
    fi
  done
  if test x"${ip}" = x; then
    echo "+++ Failed to acquire LAVA target ${lava_target}" 1>&2
    exit 1
  fi

  lava_network
  if test $? -eq 1; then
    ip+='.lava'
  fi
fi
#LAVA-agnostic from here

if ! (. "${topdir}"/lib/common.sh; remote_exec "${ip}" true) > /dev/null 2>&1; then
  echo "Unable to connect to target ${ip}" 1>&2
  exit 1
fi

#Make sure we delete the remote dir when we're done
trap clean_benchmark EXIT

#Should be a sufficient UID, as we wouldn't want to run multiple benchmarks on the same target at the same time
logdir="${topdir}/${benchmark}-log/${ip}_`date +%s`"
if test -e "${logdir}"; then
  echo "Log output directory ${logdir} already exists" 1>&2
fi
mkdir -p "${logdir}/${benchmark}.git"
if test $? -ne 0; then
  echo "Failed to create dir ${logdir}" 1>&2
  exit 1
fi

#Create and populate working dir on target
target_dir="`. ${topdir}/lib/common.sh; remote_exec ${ip} 'mktemp -dt XXXXXXX'`"
if test $? -ne 0; then
  echo "Unable to get tmpdir on target" 1>&2
  exit 1
fi
for thing in "${builddir}" "${topdir}/scripts/controlledrun.sh" "${confdir}/${device}.services"; do
  (. "${topdir}"/lib/common.sh; remote_upload "${ip}" "${thing}" "${target_dir}/`basename ${thing}`")
  if test $? -ne 0; then
    echo "Unable to copy ${thing}" to "${ip}:${target_dir}/${thing}" 1>&2
    exit 1
  fi
done

#Compose and run the ssh command.
#We have to run the ssh command asynchronously, because having the network down during a long-running benchmark will result in ssh
#death sooner or later - we can stop ssh client and ssh server from killing the connection, but the TCP layer will get it eventually.

#These parameters sourced from the conf file at beginning of this function
flags="-b ${benchcore} ${othercore:+-p ${othercore}}"
if test x"${netctl}" = xyes; then
  flags+=" -n"
fi
if test x"${servicectl}" = xyes; then
  flags+=" -s ${target_dir}/${device}.services"
fi
if test x"${freqctl}" = xyes; then
  flags+=" -f"
fi
#TODO: Strictly, hostname -I might return multiple IP addresses
#TODO: Repetition of hostname echoing is ugly, but seems to be needed -
#      perhaps there is some delay after the interface comes up
(. "${topdir}"/lib/common.sh
   remote_exec_async \
     "${ip}" \
     "cd ${target_dir}/`basename ${builddir}` && \
     ../controlledrun.sh ${cautious} ${flags} -l ${tee_output} -- ./linarobench.sh ${board_benchargs} -- ${run_benchargs}; \
     ret=\\\$?; \
     for i in {1..10}; do \
       echo \"\\\${USER}@\\\`ifconfig eth0 | grep 'inet addr' | sed 's/[^:]*://' | cut -d ' ' -f 1\\\`:\\\${ret}\" | nc ${listener_addr} ${listener_port}; \
     done; \
     if test \\\${ret} -eq 0; then \
       true; \
     else \
       false; \
     fi" \
     "${target_dir}/stdout" "${target_dir}/stderr")
if test $? -ne 0; then
  echo "Something went wrong when we tried to dispatch job" 1>&2
  exit 1
fi

#TODO: Do we want a timeout around this? Timeout target and workload dependent.
read ip <&5

error="`echo ${ip} | sed 's/.*://'`"
if test $? -ne 0; then
  echo "Unable to determine exit code, assuming the worst." 1>&2
  error=1
fi
ip="`echo ${ip} | sed 's/:.*//' | sed 's/\s*$//'`"
if test $? -ne 0; then
  echo "Unable to determine IP, giving up." 1>&2
  exit 1
fi

#Rather Linaro-specific
lava_network
if test $? -eq 1; then
  ip+='.lava'
fi
if ! (. "${topdir}"/lib/common.sh; remote_exec "${ip}" true) > /dev/null 2>&1; then
  echo "Unable to connect to target ${ip}" 1>&2
  exit 1
fi

if test ${error} -ne 0; then
  echo "Command failed: will try to get logs" 1>&2
  echo "Target: ${ip}:${target_dir}" 1>&2
  error=1
fi
for log in ../stdout ../stderr linarobenchlog ${benchlog}; do
  mkdir -p "${logdir}/${benchmark}.git/`dirname ${log}`"
  (. "${topdir}"/lib/common.sh; remote_download "${ip}" "${target_dir}/${benchmark}.git/${log}" "${logdir}/${benchmark}.git/${log}")
  if test $? -ne 0; then
    echo "Error while getting log ${log}: will try to get others" 1>&2
    error=1
  fi
done

if test ${error} -eq 0; then
  echo "+++ Run of ${benchmark} on ${device} succeeded"
else
  echo "+++ Run of ${benchmark} on ${device} failed"
fi
exit ${error}
