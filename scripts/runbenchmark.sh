#!/bin/bash
#This script takes a build of a benchmark and transfers it to, and runs it on
#a single target. The target may be LAVA or non-LAVA. The script is mostly
#LAVA-agnostic - apart from the section that initiates the LAVA session, there
#is some awareness of it in the exit handler, and that's all.
set -o pipefail

trap clean_benchmark EXIT
trap 'exit ${error}' TERM INT HUP QUIT

lava_pid=
listener_pid=
benchmark=
device=
keep=
cautious=''
lava_target=
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
listener_fifo="${temps}/listener_fifo"
lava_fifo="${temps}/lava_fifo"
mkfifo "${listener_fifo}" || exit 1
exec 3<> "${listener_fifo}"
mkfifo "${lava_fifo}" || exit 1
exec 4<> "${lava_fifo}"

#Make sure that subscripts clean up - we must not leave benchmark sources or data lying around,
#we should not leave lava targets reserved
clean_benchmark()
{
  error=$?
  local lava_release=1 #Default to not releasing the target

  if test x"${ip}" != x; then
    if test x"${target_dir}" = x; then
      echo "No directory to remove from ${ip}"
      lava_release=0
    elif test x"${keep}" = 'x-k'; then
      echo "Not removing ${target_dir} from ${ip} as -k was given. You might want to go in and clean up."
    elif ! expr "${target_dir}" : '\(/tmp\)' > /dev/null; then
      echo "Cowardly refusing to delete ${target_dir} from ${ip}. Not rooted at /tmp. You might want to go in and clean up." 1>&2
      error=1
    else
      (. "${topdir}"/lib/common.sh; remote_exec "${ip}" "rm -rf ${target_dir}" ${ssh_opts})
      if test $? -eq 0; then
        echo "Removed ${target_dir} from ${ip}"
        lava_release=0
      else
        echo "Failed to remove ${target_dir} from ${ip}. You might want to go in and clean up." 1>&2
        error=1
      fi
    fi
  else
    echo "Target post-boot initialisation did not happen, thus nothing to clean up."
    lava_release=0
  fi

  if test x"${listener_pid}" != x; then
    kill "${listener_pid}" 2>/dev/null
    wait "${listener_pid}"
  fi

  if test x"${lava_pid}" != x; then
    if test ${lava_release} -ne 0; then
      echo "Not killing lava session, to ensure session remains open for cleanup."
      kill "${lava_pid}" 2>/dev/null
      wait "${lava_pid}"
    else
      kill -USR1 "${lava_pid}" 2>/dev/null
      wait "${lava_pid}"
    fi

    #Make sure we see any messages from the lava.sh handlers
    dd iflag=nonblock <&4 2>/dev/null | awk "{print \"${lava_target}: \" \$0}"
  fi

  #Delete these last so that we can still get messages through the lava fifo
  if test -d "${temps}"; then
    exec 3>&-
    exec 4>&-
    rm -rf "${temps}"
    if test $? -ne 0; then
      echo "Failed to delete ${temps}" 1>&2
      error=1
    fi
  fi

  exit "${error}"
}

#Handle LAVA case
echo "${ip}" | grep '\.json$' > /dev/null
if test $? -eq 0; then
  lava_network
  case $? in
    2) echo "Unable to determing location w.r.t. lava lab: assuming outside" 1>&2 ;;
    1)
      ssh_opts="-l 200 ${LAVA_SSH_KEYFILE:+-o IdentityFile=${LAVA_SSH_KEYFILE}} -o ProxyCommand='ssh lab.validation.linaro.org nc -q0 %h %p'"
      establish_listener_opts="-f 10.0.0.10:lab.validation.linaro.org"
  esac

  lava_target="${ip}"
  ip=''
  tee_output=/dev/console
  echo "Acquiring LAVA target ${lava_target}"
  echo "${topdir}/scripts/lava.sh -s ${lavaserver} -j ${confdir}/${lava_target} -b ${boot_timeout:-30}"

  ${topdir}/scripts/lava.sh -s "${lavaserver}" -j "${confdir}/${lava_target}" -b "${boot_timeout-:30}" >&4 &
  if test $? -ne 0; then
    echo "+++ Failed to acquire LAVA target ${lava_target}" 1>&2
    exit 1
  fi
  lava_pid=$!
  while true; do
    line="`bgread ${lava_pid} 60 <&4`"
    if test $? -ne 0; then
      echo "Failed to read lava output" 1>&2
      exit 1
    fi
    echo "${lava_target}: $line"
    if echo "${line}" | grep '^LAVA target ready at ' > /dev/null; then
      ip="`echo ${line} | cut -d ' ' -f 5 | sed 's/\s*$//'`"
      break
    fi
  done
  #After this point, lava.sh should produce no output until we reach the exit handlers.
  #Our exit handler checks the pipe from lava.sh before closing down.

  if test x"${ip}" = x; then
    echo "+++ Failed to acquire LAVA target ${lava_target}" 1>&2
    exit 1
  fi
fi
#LAVA-agnostic from here, apart from a section in the exit handler

#Set up our listener
listener_addr="`get_addr`"
if test $? -ne 0; then
  echo "Unable to get IP for listener" 1>&2
  exit 1
fi
"${topdir}"/scripts/establish_listener.sh ${establish_listener_opts} `get_addr` 4200 5200 >&3 &
listener_pid=$!
listener_addr="`bgread ${listener_pid} 60 <&3`"
if test $? -ne 0; then
  echo "Failed to read listener address" 1>&2
  exit 1
fi
listener_port="`bgread ${listener_pid} 60 <&3`"
if test $? -ne 0; then
  echo "Failed to read listener port" 1>&2
  exit 1
fi
echo "Listener ${listener_addr}:${listener_port}"

if ! (. "${topdir}"/lib/common.sh; remote_exec "${ip}" true ${ssh_opts}) > /dev/null 2>&1; then
  echo "Unable to connect to target ${ip:+(unknown)} after boot" 1>&2
  exit 1
fi

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
target_dir="`. ${topdir}/lib/common.sh; remote_exec ${ip} 'mktemp -dt XXXXXXX' ${ssh_opts}`"
if test $? -ne 0; then
  echo "Unable to get tmpdir on target" 1>&2
  exit 1
fi
for thing in "${builddir}" "${topdir}/scripts/controlledrun.sh" "${confdir}/${device}.services"; do
  (. "${topdir}"/lib/common.sh; remote_upload "${ip}" "${thing}" "${target_dir}/`basename ${thing}`" ${ssh_opts})
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
     "${target_dir}/stdout" "${target_dir}/stderr" \
     ${ssh_opts})
if test $? -ne 0; then
  echo "Something went wrong when we tried to dispatch job" 1>&2
  exit 1
fi

ip="`bgread ${listener_pid} 60 <&3`"
if test $? -ne 0; then
  echo "Failed to read IP following benchmark run" 1>&2
  exit 1
fi

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

if ! (. "${topdir}"/lib/common.sh; remote_exec "${ip}" true ${ssh_opts}) > /dev/null 2>&1; then
  echo "Unable to connect to target after ${ip:+(unknown)} benchmark run" 1>&2
  exit 1
fi

if test ${error} -ne 0; then
  echo "Command failed: will try to get logs" 1>&2
  echo "Target: ${ip}:${target_dir}" 1>&2
  error=1
fi
for log in ../stdout ../stderr linarobenchlog ${benchlog}; do
  mkdir -p "${logdir}/${benchmark}.git/`dirname ${log}`"
  (. "${topdir}"/lib/common.sh; remote_download "${ip}" "${target_dir}/${benchmark}.git/${log}" "${logdir}/${benchmark}.git/${log}" ${ssh_opts})
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
