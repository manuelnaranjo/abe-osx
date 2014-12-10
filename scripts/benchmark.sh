#!/bin/bash
#This script is an ad-hoc way of doing things pending a DejaGNU
#implementation that will avoid wheel re-invention. Let's not
#sink too much time into making this script beautiful.

#TODO Convert as much as possible into a function, so that we don't share global namespace with cbuild2 except where we mean to
#     Better - confine cbuild2 to a subshell

set -o pipefail

#Make sure that subscripts clean up - we must not leave benchmark sources or data lying around,
#we should not leave lava targets reserved
trap clean_top EXIT >/dev/null 2>&1
trap 'exit ${error}' TERM INT HUP QUIT

error=1
declare -A runpids

clean_top()
{
  for runpid in "${!runpids[@]}"; do
    if kill -0 "${runpid}" 2>/dev/null; then
      kill "${runpid}"
      wait "${runpid}"
      if test $? -ne 0; then
        error=1
      fi
    fi
  done
  exit ${error}
}

#To be called from exit trap in run_benchmark
clean_benchmark()
{
  error=$?

  if test -f "${listener_file}"; then
    rm -f "${listener_file}"
    if test $? -ne 0; then
      echo "Failed to delete ${listener_file}" 1>&2
    fi
  fi

  if test x"${target_dir}" = x; then
    echo "No directory to remove from ${ip}" 1>&2
  elif test x"${keep}" = 'x-k'; then
    echo "Not removing ${target_dir} from ${ip} as -k was given. You might want to go in and clean up." 1>&2
  elif ! expr "${target_dir}" : '\(/tmp\)' > /dev/null; then
    echo "Cowardly refusing to delete ${target_dir} from ${ip}. Not rooted at /tmp. You might want to go in and clean up." 1>&2
  else
    (. "${topdir}"/lib/common.sh; remote_exec "${ip}" "rm -rf ${target_dir}")
    if test $? -eq 0; then
      echo "Removed ${target_dir} from ${ip}" 1>&2
    else
      echo "Failed to remove ${target_dir} from ${ip}. You might want to go in and clean up." 1>&2
      error=1
    fi
  fi

  #By now we've done our cleanup - it doesn't really matter what order the lava handler (if any) and listeners die in
  kill -- -$BASHPID >/dev/null 2>&1
  #Killing the group will kill this process too - but the TERM handler will exit with the correct exit code
}

#Called from a subshell. One consequence is that the 'global' variables are
#only global within the subshell - which some of them need to be for the exit trap.
run_benchmark()
{
    error=1
    trap 'exit ${error}' TERM INT HUP QUIT
    . "${topdir}"/scripts/listener.sh

    . "${confdir}/${device}.conf" #We can't use cbuild2's source_config here as it requires us to have something get_toolname can parse
    if test $? -ne 0; then
      echo "+++ Failed to source ${confdir}/${device}.conf" 1>&2
      exit 1
    fi
    local tee_output=/dev/null

    #Set up our listener
    #Has to happen before we deal with LAVA, so that we can port forward if we need to
    listener_file="`mktemp -t XXXXXXXXX`" || exit 1
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
      local lava_target="${ip}"
      ip=''
      tee_output=/dev/console
      echo "Acquiring LAVA target ${lava_target}"
      echo "${topdir}/scripts/lava.sh -s ${lavaserver} -j ${confdir}/${lava_target} -b ${boot_timeout:-30} ${keep}" 1>&2

      #Downside of this approach is that bash syntax errors from lava.sh get reported as occurring at non-existent lines - but it is
      #otherwise quite neat. And you can always run lava.sh separately to get the correct error.
      exec 3< <(${topdir}/scripts/lava.sh -s "${lavaserver}" -j "${confdir}/${lava_target}" -b "${boot_timeout-:30}" ${keep}) #Don't enquote keep - if it is empty we want to pass nothing, not the empty string
      if test $? -ne 0; then
        echo "+++ Failed to acquire LAVA target ${lava_target}" 1>&2
        exit 1
      fi
      while read line <&3; do
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
    local logdir="${topdir}/${benchmark}-log/${ip}_`date +%s`"
    if test -e "${logdir}"; then
      echo "Log output directory ${logdir} already exists" 1>&2
    fi
    mkdir -p "${logdir}/${benchmark}.git"
    if test $? -ne 0; then
      echo "Failed to create dir ${logdir}" 1>&2
      exit 1
    fi

    #Create and populate working dir on target
    local target_dir
    target_dir="`. ${topdir}/lib/common.sh; remote_exec ${ip} 'mktemp -dt XXXXXXX'`"
    if test $? -ne 0; then
      echo "Unable to get tmpdir on target" 1>&2
      exit 1
    fi
    local thing
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
    local flags="-b ${benchcore} ${othercore:+-p ${othercore}}"
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
     remote_exec_async "${ip}" \
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

    ret="`echo ${ip} | sed 's/.*://'`"
    if test $? -ne 0; then
      echo "Unable to determine exit code, assuming the worst." 1>&2
      ret=1
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

    if test ${ret} -ne 0; then
      echo "Command failed: will try to get logs" 1>&2
      echo "Target: ${ip}:${target_dir}" 1>&2
      ret=1
    fi 
    local log
    for log in ../stdout ../stderr linarobenchlog ${benchlog}; do
      mkdir -p "${logdir}/${benchmark}.git/`dirname ${log}`"
      (. "${topdir}"/lib/common.sh; remote_download "${ip}" "${target_dir}/${benchmark}.git/${log}" "${logdir}/${benchmark}.git/${log}")
      if test $? -ne 0; then
        echo "Error while getting log ${log}: will try to get others" 1>&2
	ret=1
      fi
    done

    if test ${ret} -eq 0; then
      echo "+++ Run of ${benchmark} on ${device} succeeded"
    else
      echo "+++ Run of ${benchmark} on ${device} failed"
    fi
    
    exit ${ret}
}

function usage
{
  cat << EOF
$0 [-tckh] -b <benchmark> <board...>

  -b   Identify the benchmark to build, e.g. fakebench, eembc. Compulsory.
  -c   Cautious. If this is set, failure in any stage of target setup will
       be treated as an error, even if recoverable. On by default.
  -h   Show this help.
  -k   Keep. If this is set, benchmark sources and results will be left on
       target. LAVA targets will not be released.
  -t   Target triple to build benchmark for e.g. arm-linux-gnueabihf. Used
       only for building. Blank implies native build.

  <board...> may be anything that has a file in config/boards/bench, e.g. the
  existence of arndale.conf means that you can put arndale here. At least one
  target may be specified. ssh targets must only be specified once. LAVA
  targets can be specified as many times as you like.

  If building natively, board is optional. If not given, the benchmark will
  run on localhost.
EOF
}

set_toolchain()
{
  local target_gcc="${target:+${target}-}gcc"
  if test x"${toolchain_path}" = x; then
    which "${target_gcc}" > /dev/null 2>&1
    if test $? -ne 0; then
      echo "No toolchain specified and unable to find a suitable gcc on the path" 1>&2
      echo "Looked for ${target:+${target}-}gcc" 1>&2
      exit 1
    else
      echo "No toolchain specified, using `which ${target_gcc}`, found on PATH" 1>&2
    fi
  else
    if test -f "${toolchain_path}/bin/${target_gcc}"; then
      PATH="${toolchain_path}/bin:$PATH"
    else
      echo "Toolchain directory ${toolchain_path} does not contain bin/${target_gcc}" 1>&2
      exit 1
    fi
  fi
}

topdir="`dirname $0`/.." #cbuild2 global, but this should be the right value for cbuild2
if ! test -e "${topdir}/host.conf"; then
  echo "No host.conf, did you run ./configure?" 1>&2
  exit 1
fi

run_benchargs=""
skip_build=
toolchain_path=
cautious='-c'
keep= #if set, don't clean up benchmark output on target, don't kill lava targets
while getopts a:i:t:b:kchs flag; do
  case "${flag}" in
    a) run_benchargs="${OPTARG}";;
    s) skip_build=1;;
    i) toolchain_path="${OPTARG}";;
    t) target="${OPTARG}";; #have to be careful with this one, it is meaningful to sourced cbuild2 files in subshells below
    b) benchmark="${OPTARG}";;
    c) cautious=;;
    k)
       keep='-k'
       echo 'Keep (-k) set: possibly sensitive benchmark data will be left on target'
       echo 'Continue? (y/N)'
       read answer
       if ! echo "${answer}" | egrep -i '^(y|yes)[[:blank:]]*$' > /dev/null; then
         exit 0
       fi
    ;;
    h)
       usage
       exit 0
    ;;
    *)
       echo "Bad arg" 1>&2
       exit 1
    ;;
  esac
done
shift $((OPTIND - 1))
devices=("$@") #Duplicate targets are fine for lava, they will resolve to different instances of the same machine.
               #Duplicate targets not fine for ssh access, where they will just resolve to the same machine every time.
               #TODO: Check for multiple instances of a given non-lava target
set_toolchain

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

if test x"${benchmark}" = x; then
  echo "No benchmark given (-b)" 1>&2
  echo "Sensible values might be eembc, spec2000, spec2006" 1>&2
  exit 1
fi
if test x"${target}" = x; then #native build
  if test ${#devices[@]} -eq 0; then
    devices=("localhost") #Note that we still need passwordless ssh to
                          #localhost. This could be fixed if anyone _really_
                          #needs it, but DejaGNU will presumably fix for free.
  #else - we're doing a native build and giving devices other than localhost
  #       for measurement, that's fine. But giving both localhost and other
  #       devices is unlikely to work, given that we'll be both shutting down
  #       localhost and using it to dispatch benchmark jobs. Therefore TODO:
  #       check for a device list composed of localhost plus other targets
  fi
else #cross-build, implies we need remote devices
  if test ${#devices[@]} -eq 0; then
    echo "--target implies cross-compilation, but no devices given for run" 1>&2
    exit 1
  fi
  target="--target ${target}"
fi

if test x"$skip_build" = x; then
  #cbuild2 can build the benchmarks just fine
  (cd "${topdir}" && ./cbuild2.sh --build "${benchmark}.git" ${target})
  if test $? -ne 0; then
    echo "Error while building benchmark ${benchmark}" 1>&2
    exit 1
  fi
fi
#devices not doing service ctrl need to have a ${device}.services file anyway, just so remote.sh doesn't complain it isn't there to copy.
#It'll be ignored unless we give the -s flag.
#benchmarks must have a 'lavabench' rule

#And remote.sh can work with controlledrun.sh to run them for us
for device in "${devices[@]}"; do
  (run_benchmark)&
  runpids[$!]=''
done
  
ret=0
running_pids=("${!runpids[@]}")
while true; do
  for running_pid in "${running_pids[@]}"; do
    kill -0 "${running_pid}" 2>/dev/null
    if test $? -ne 0; then #Process cannot be signalled, reap it
      wait "${running_pid}"
      if test $? -ne 0; then
        ret=1
      fi
      unset runpids["${running_pid}"]
    fi
  done
  running_pids=("${!runpids[@]}")
  if test ${#running_pids[@]} -eq 0; then
    break
  else
    sleep 60
  fi
done

echo
echo "All runs completed"
exit ${ret}

#TODO: I suppose I might want a 'delete local copies of source/built benchmark'

