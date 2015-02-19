#!/bin/bash
#This script takes a build of a benchmark and transfers it to, and runs it on
#a single target. The target may be LAVA or non-LAVA. The script is mostly
#LAVA-agnostic - apart from the section that initiates the LAVA session, there
#is some awareness of it in the exit handler, and that's all.
set -o pipefail
set -o nounset

trap clean_benchmark EXIT
trap 'exit ${error}' TERM INT HUP QUIT

tag=
session_pid=
lava_pid=
listener_pid=
benchmark=
device=
keep=
cautious=''
build_dir=
lava_target=
run_benchargs=
sysroot_path=
while getopts g:b:d:t:a:l:kc flag; do
  case "${flag}" in
    g) tag="${OPTARG}";;
    k) keep='-k';;
    c) cautious='-c';;
    b) benchmark="${OPTARG}";;
    d) device="${OPTARG}";;
    t) buildtar="${OPTARG}";;
    a) run_benchargs="${OPTARG}";;
    l) sysroot_path="${OPTARG}";;
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

# load the configure file produced by configure
if test -e "${PWD}/host.conf"; then
    . "${PWD}/host.conf"
else
    echo "ERROR: no host.conf file!  Did you run configure?" 1>&2
    exit 1
fi
topdir="${abe_path}" #abe global, but this should be the right value for abe
confdir="${topdir}/config/boards/bench"
if test x"${LAVA_SERVER:-}" != x; then
  lava_url="${LAVA_SERVER}"
else
  lava_url="${USER}@validation.linaro.org/RPC2/"
  echo "Environment variable LAVA_SERVER not set, defaulted to ${lava_url}" 1>&2
fi

benchlog="`. ${abe_top}/host.conf && . ${topdir}/lib/common.sh && read_config ${benchmark}.git benchlog`"
if test $? -ne 0; then
  echo "Unable to read benchmark config file for ${benchmark}" 1>&2
  exit 1
fi
safe_output="`. ${abe_top}/host.conf && . ${topdir}/lib/common.sh && read_config ${benchmark}.git safe_output`"
if test $? -ne 0; then
  echo "Unable to read benchmark config file for ${benchmark}" 1>&2
  exit 1
fi

. "${topdir}"/scripts/benchutil.sh
if test $? -ne 0; then
  echo "+++ Unable to source ${topdir}/benchutil.sh" 1>&2
  exit 1
fi
. "${confdir}/${device}.conf" #We can't use abe's source_config here as it requires us to have something get_toolname can parse
if test $? -ne 0; then
  echo "+++ Failed to source ${confdir}/${device}.conf" 1>&2
  exit 1
fi

temps="`mktemp -dt XXXXXXXXX`" || exit 1
listener_file="${temps}/listener_file"
listener_fifo="${temps}/listener_fifo"
lava_fifo="${temps}/lava_fifo"
mkfifo "${listener_fifo}" || exit 1
exec {listener_handle}<>${listener_fifo}
mkfifo "${lava_fifo}" || exit 1
exec {lava_handle}<>"${lava_fifo}"

#Make sure that subscripts clean up - we must not leave benchmark sources or data lying around,
#we should not leave lava targets reserved
clean_benchmark()
{
  error=$?

  if test x"${ip:-}" != x; then
    if test x"${target_dir:-}" = x; then
      echo "No directory to remove from ${ip}"
    elif test x"${keep}" = 'x-k'; then
      echo "Not removing ${target_dir} from ${ip} as -k was given. You might want to go in and clean up."
    elif test ${error} -ne 0; then
      echo "Not removing ${target_dir} from ${ip} as there was an error. You might want to go in and clean up."
    elif ! expr "${target_dir}" : '\(/tmp\)' > /dev/null; then
      echo "Cowardly refusing to delete ${target_dir} from ${ip}. Not rooted at /tmp. You might want to go in and clean up." 1>&2
      error=1
    else
      (. "${topdir}"/lib/common.sh; remote_exec "${ip}" "rm -rf ${target_dir}" ${ssh_opts})
      if test $? -eq 0; then
        echo "Removed ${target_dir} from ${ip}"
      else
        echo "Failed to remove ${target_dir} from ${ip}. You might want to go in and clean up." 1>&2
        error=1
      fi
    fi
  else
    echo "Target post-boot initialisation did not happen, thus nothing to clean up."
  fi

  if test x"${session_pid:-}" != x; then
    kill "${session_pid}" 2>/dev/null
    wait "${session_pid}"
  fi

  if test x"${listener_pid:-}" != x; then
    kill "${listener_pid}" 2>/dev/null
    wait "${listener_pid}"
  fi

  if test x"${lava_pid:-}" != x; then
    if test ${error} -ne 0 || test x"${keep}" = 'x-k'; then
      echo "Not killing lava session, to ensure session remains open for investigation/cleanup."
      kill "${lava_pid}" 2>/dev/null
      wait "${lava_pid}"
    else
      kill -USR1 "${lava_pid}" 2>/dev/null
      wait "${lava_pid}"
    fi

    #Make sure we see any messages from the lava.sh handlers
    dd iflag=nonblock <&${lava_handle} 2>/dev/null | awk "{print \"${lava_target}: \" \$0}"
  fi

  #Delete these last so that we can still get messages through the lava fifo
  if test -d "${temps}"; then
    exec {listener_handle}>&-
    exec {listener_handle}<&-
    exec {lava_handle}>&-
    exec {lava_handle}<&-
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
  lava_user="`lava_user ${lava_url}`"
  if test $? -ne 0; then
    echo "Unable to find username from ${lava_url}" 1>&2
    exit 1
  fi
  lava_network "${lava_user}"
  case $? in
    2) echo "Unable to determing location w.r.t. lava lab: assuming outside" 1>&2 ;;
    1)
      gateway=lab.validation.linaro.org
      ssh_opts="-F /dev/null ${LAVA_SSH_KEYFILE:+-o IdentityFile=${LAVA_SSH_KEYFILE}} -o ProxyCommand='ssh ${lava_user}@${gateway} nc -q0 %h %p'"
      establish_listener_opts="-f 10.0.0.10:${lava_user}@${gateway}"

      #LAVA targets need to boot - do an early check that the route to the gateway is private, so that we can fail fast
      if ! check_private_route "${gateway}"; then
        echo "Failed to confirm that route to target is private, conservatively aborting" 1>&2
        exit 1
      fi
  esac

  lava_target="${ip}"
  ip=''
  tee_output=/dev/console
  echo "Acquiring LAVA target ${lava_target}"
  echo "${topdir}/scripts/lava.sh ${tag:+-g "${tag}"} -s ${lava_url} -j ${confdir}/${lava_target} -b ${boot_timeout:-30}"

  ${topdir}/scripts/lava.sh ${tag:+-g "${tag}"} -s "${lava_url}" -j "${confdir}/${lava_target}" -b "${boot_timeout-:30}" >&${lava_handle} 2>&1 &
  if test $? -ne 0; then
    echo "+++ Failed to acquire LAVA target ${lava_target}" 1>&2
    exit 1
  fi
  lava_pid=$!
  while true; do
    line="`bgread -t 5 ${lava_pid} <&${lava_handle}`"
    if test $? -ne 0; then
      echo "${lava_target}: Failed to read lava output" 1>&2
      exit 1
    fi
    echo "${lava_target}: $line"
    if echo "${line}" | grep '^LAVA target ready at ' > /dev/null; then
      ip="`echo ${line} | cut -d ' ' -f 5 | sed 's/\s*$//'`"
      break
    fi
  done

  if test x"${sysroot_path:-}" != x; then
    sysroot_lib="${sysroot_path#*:}"
    if test x"${sysroot_lib}" = x"${sysroot_path}"; then
      sysroot_lib=lib
    else
      sysroot_path="${sysroot_path%:*}"
    fi
    if ! (. "${topdir}"/lib/common.sh; remote_exec "${ip}" true ${ssh_opts}) > /dev/null 2>&1; then
      echo "Unable to connect to target ${ip:+(unknown)} after boot" 1>&2
      exit 1
    fi
    tmpsysdir="`(. ${topdir}/lib/common.sh; remote_exec ${ip} "mktemp -dt sysroot_XXXXX" ${ssh_opts})`"
    (. ${topdir}/lib/common.sh; remote_upload -r 3 "${ip}" "${sysroot_path}/" "${tmpsysdir}"/sysroot ${ssh_opts})
    if test $? -ne 0; then
      echo "Failed to upload sysroot to target" 1>&2
      exit 1
    fi
    #TODO We're relying on a symlink from lib to lib64 being present, where relevant
    #TODO Would really be better to do this with a (s)chroot, to allow use on non-LAVA
    #     targets. But after ~1 day of experimenting with test-schroot.sh, opted to do
    #     this to unblock this use case for LAVA targets.
    #Removed ldconfig - shouldn't be needed in at least this case, and I'm told it doesn't work.
    (. ${topdir}/lib/common.sh; remote_exec "${ip}" "echo -e '/lib\n/usr/lib\n > ld.so.conf.new' && \
                         cat /etc/ld.so.conf >> /etc/ld.so.conf.new && \
                         mv /etc/ld.so.conf.new /etc/ld.so.conf && \
                         rsync -a ${tmpsysdir}/sysroot/ /" ${ssh_opts})
    if test $? -ne 0; then
      echo "Failed to install sysroot on target" 1>&2
      exit 1
    fi
    if ! (. ${topdir}/lib/common.sh; remote_exec "${ip}" true ${ssh_opts}) > /dev/null 2>&1; then
      echo "Unable to run simple command on target after sysroot installation" 1>&2
      exit 1
    fi
  fi

  #After this point, lava.sh should produce no output until we reach the exit handlers.
  #Our exit handler checks the pipe from lava.sh before closing down.

  if test x"${ip:-}" = x; then
    echo "+++ Failed to acquire LAVA target ${lava_target}" 1>&2
    exit 1
  fi
else
  if test x"${sysroot_path:-}" != x; then
    echo "Cannot install a sysroot on non-LAVA targets" 1>&2
    exit 1
  fi
  gateway="${ip/*@}"
  ssh_opts=
  establish_listener_opts=
fi
#LAVA-agnostic from here, apart from a section in the exit handler, and bgread
#monitoring of the LAVA process while we're waiting for the benchmark to end

#Set up our listener
listener_addr="`get_addr`"
if test $? -ne 0; then
  echo "Unable to get IP for listener" 1>&2
  exit 1
fi
"${topdir}"/scripts/establish_listener.sh ${establish_listener_opts} "${listener_addr}" 4200 5200 >&${listener_handle} &
listener_pid=$!
listener_addr="`bgread -T 60 ${listener_pid} <&${listener_handle}`"
if test $? -ne 0; then
  echo "Failed to read listener address" 1>&2
  exit 1
fi
listener_port="`bgread -T 60 ${listener_pid} <&${listener_handle}`"
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
logdir="${abe_top}/${benchmark}-log/${device}_${ip}_`date -u +%F_%T.%N`"
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
if ! check_private_route "${gateway}"; then
  echo "Failed to confirm that route to target is private, conservatively aborting" 1>&2
  exit 1
fi
for thing in "${buildtar}" "${topdir}/scripts/controlledrun.sh" "${confdir}/${device}.services"; do
  (. "${topdir}"/lib/common.sh; remote_upload -r 3 "${ip}" "${thing}" "${target_dir}/`basename ${thing}`" ${ssh_opts})
  if test $? -ne 0; then
    echo "Unable to copy ${thing}" to "${ip}:${target_dir}/${thing}" 1>&2
    exit 1
  fi
done

#Compose and run the ssh command.
#We have to run the ssh command asynchronously, because having the network down during a long-running benchmark will result in ssh
#death sooner or later - we can stop ssh client and ssh server from killing the connection, but the TCP layer will get it eventually.

#These parameters sourced from the board conf file at beginning of this function
flags="${benchcore:+-b ${benchcore}} ${othercore:+-p ${othercore}}"
if test x"${netctl:-}" = xyes; then
  flags+=" -n"
fi
if test x"${servicectl:-}" = xyes; then
  flags+=" -s ${target_dir}/${device}.services"
fi
if test x"${freqctl:-}" = xyes; then
  flags+=" -f"
fi

#This parameter read from the benchmark conf file earlier in this script
if test x"${safe_output}" = xyes; then
  flags+=" -t"
fi

#But, if uncontrolled is set, override all other flags
if test x"${uncontrolled:-}" = xyes; then
  echo "Running without any target controls or special (sudo) privileges, due to 'uncontrolled=yes' in target config file"
  flags="-u"
fi

#TODO: Repetition of hostname echoing is ugly, but seems to be needed -
#      perhaps there is some delay after the interface comes up
(
   pids=()
   cleanup()
   {
     local pid
     for pid in "${pids[@]}"; do
       if test x"${pid:-}" != x; then
         kill ${pid} 2>/dev/null
         wait ${pid} 2>/dev/null
       fi
     done
     exit
   }
   trap cleanup EXIT

   . "${topdir}"/lib/common.sh
   remote_exec_async \
     "${ip}" \
     "echo 'STARTED' | nc ${listener_addr} ${listener_port} && \
      cd ${target_dir} && \
      tar xjf `basename ${buildtar}` && \
      cd `tar tjf ${buildtar} | head -n1` && \
     ../controlledrun.sh ${cautious} ${flags} -l ${tee_output} -- ./linarobench.sh ${board_benchargs:-} -- ${run_benchargs:-}; \
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
     ${ssh_opts}
   if test $? -ne 0; then
     echo "Something went wrong when we tried to dispatch job" 1>&2
     exit 1
   fi
   pids+=($!)
   sleep infinity&
   waiter=$!
   pids+=(${waiter})
   wait ${waiter}
)&
session_pid=$!

#lava_pid will expand to empty if we're not using lava
handshake="`bgread -T 300 ${listener_pid} ${lava_pid} <&${listener_handle}`"
if test $? -ne 0 -o x"${handshake:-}" != 'xSTARTED'; then
  echo "Did not get handshake from target, giving up" 1>&2
  exit 1
fi

#lava_pid will expand to empty if we're not using lava
#No sense in setting a deadline on this one, it's order of days for many cases
ip="`bgread ${listener_pid} ${lava_pid} <&${listener_handle}`"
if test $? -ne 0; then
  if test x"${lava_pid:-}" = x; then
    echo "Failed to read post-benchmark-run IP" 1>&2
  else
    echo "LAVA process died, or otherwise failed while waiting to read post-benchmark-run IP" 1>&2
  fi
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

#Several days might have passed, re-check the route
if ! check_private_route "${gateway}"; then
  echo "Failed to confirm that route to target is private, conservatively aborting" 1>&2
  exit 1
fi
for log in ../stdout ../stderr linarobenchlog ${benchlog}; do
  mkdir -p "${logdir}/${benchmark}.git/`dirname ${log}`"
  (. "${topdir}"/lib/common.sh; remote_download -r 3 "${ip}" "${target_dir}/${benchmark}.git/${log}" "${logdir}/${benchmark}.git/${log}" ${ssh_opts})
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
