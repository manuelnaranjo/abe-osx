#!/bin/bash
#This script is an ad-hoc way of doing things pending a DejaGNU
#implementation that will avoid wheel re-invention. Let's not
#sink too much time into making this script beautiful.

#TODO Convert as much as possible into a function, so that we don't share global namespace with cbuild2 except where we mean to
#     Better - confine cbuild2 to a subshell

set -o pipefail

#Make sure that subscripts clean up - we must not leave benchmark sources or data lying around,
#we should not leave lava targets reserved
trap "kill -- -$BASHPID" EXIT >/dev/null 2>&1

#To be called from exit trap in run_benchmark
clean_benchmark()
{
  local error=$?

  if test x"${target_dir}" = x; then
    echo "No directory to remove from ${ip}" 1>&2
    exit "${error}"
  fi
  if test x"${keep}" = 'x-k'; then
    echo "Not removing ${target_dir} from ${ip} as -k was given. You might want to go in and clean up." 1>&2
    exit "${error}"
  fi

  #TODO: This is getting false negatives
  expr "${target_dir}" : '\(/tmp\)' > /dev/null
  if test $? -ne 0; then
    echo "Cowardly refusing to delete ${target_dir} from ${ip}. Not rooted at /tmp. You might want to go in and clean up." 1>&2
    exit 1
  fi

  (. "${topdir}"/lib/common.sh; remote_exec "${ip}" "rm -rf ${target_dir}")
  if test $? -eq 0; then
    echo "Removed ${target_dir} from ${ip}" 1>&2
    exit "${error}"
  else
    echo "Failed to remove ${target_dir} from ${ip}. You might want to go in and clean up." 1>&2
    exit 1
  fi
}

#Called from a subshell (important for the trap, and for avoiding env pollution)
run_benchmark()
{
    . "${confdir}/${device}.conf" #We can't use cbuild2's source_config here as it requires us to have something get_toolname can parse
    if test $? -ne 0; then
      echo "+++ Failed to source ${confdir}/${device}.conf" 1>&2
      exit 1
    fi
    local tee_output=/dev/null

    #Handle LAVA case
    echo "${ip}" | grep '\.json$' > /dev/null
    if test $? -eq 0; then
      local lava_target="${ip}"
      ip=''
      tee_output=/dev/console
      echo "Acquiring LAVA target ${lava_target}"
      echo "${topdir}/scripts/lava.sh -s ${lavaserver} -j ${confdir}/${lava_target} -b ${boot_timeout} ${keep}" 1>&2

      #Downside of this approach is that bash syntax errors from lava.sh get reported as occurring at non-existent lines - but it is
      #otherwise quite neat. And you can always run lava.sh separately to get the correct error.
      exec 3< <(${topdir}/scripts/lava.sh -s "${lavaserver}" -j "${confdir}/${lava_target}" -b "${boot_timeout}" ${keep}) #Don't enquote keep - if it is empty we want to pass nothing, not the empty string
      if test $? -ne 0; then
        echo "+++ Failed to acquire LAVA target ${lava_target}" 1>&2
        exit 1
      fi
      while read line <&3; do
        echo "${lava_target}: $line"
        if echo "${line}" | grep '^LAVA target ready at ' > /dev/null; then
          ip="`echo ${line} | cut -d ' ' -f 5`"
          break
        fi
      done
      if test x"${ip}" = x; then
        echo "+++ Failed to acquire LAVA target ${lava_target}" 1>&2
        exit 1
      fi
    fi
    #LAVA-agnostic from here

    #Fiddle IP if we are outside the network. Rather linaro-specific, and depends upon
    #having an ssh config equivalent to TODO wikiref
    if ! (. "${topdir}"/lib/common.sh; remote_exec "${ip}" true) > /dev/null 2>&1; then
      ip+='.lava'
      if ! (. "${topdir}"/lib/common.sh; remote_exec "${ip}" true) > /dev/null 2>&1; then
	echo "Unable to connect to target ${ip%.lava} (tried ${ip} first)" 1>&2
	exit 1
      fi
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
      flags+=" -s ${device}.services"
    fi
    if test x"${freqctl}" = xyes; then
      flags+=" -f"
    fi
    (. "${topdir}"/lib/common.sh
     remote_exec_async "${ip}" \
                       "cd ${target_dir} && ./controlledrun.sh ${cautious} ${flags} -l ${tee_output} -- make -C ${benchmark}.git linarobench" \
                       "${target_dir}/stdout" "${target_dir}/stderr")
    if test $? -ne 0; then
      echo "Something went wrong when we tried to dispatch job" 1>&2
      exit 1
    fi

    #TODO: Do we want a timeout around this? If stdout is not produced then we'll wedge. Timeout target and workload dependent.
    local ret=0
    while true; do
      ret="`. ${topdir}/lib/common.sh; remote_exec ${ip} \"grep '^EXIT CODE: [[:digit:]]' ${target_dir}/stdout\" 2> /dev/null`"
      if test $? -eq 0; then
	ret="`echo $ret | cut -d ' ' -f 3`"
	break
      else
	sleep 60
      fi
    done

    if test ${ret} -ne 0; then
      echo "Command failed: will try to get logs" 1>&2
      echo "Target: ${ip}:${target_dir}" 1>&2
      ret=1
    fi 
    local log
    for log in stdout stderr "${benchmark}.git/linarobenchlog"; do
      (. "${topdir}"/lib/common.sh; remote_download "${ip}" "${target_dir}/${log}" "${logdir}/${log}")
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

topdir="`dirname $0`/.." #cbuild2 global, but this should be the right value for cbuild2
if ! test -e "${topdir}/host.conf"; then
  echo "No host.conf, did you run ./configure?" 1>&2
  exit 1
fi

cautious='-c'
keep= #if set, don't clean up benchmark output on target, don't kill lava targets
while getopts t:b:kc flag; do
  case "${flag}" in
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

#cbuild2 can build the benchmarks just fine
(cd "${topdir}" && ./cbuild2.sh --build "${benchmark}.git" ${target})
if test $? -ne 0; then
  echo "Error while building benchmark ${benchmark}" 1>&2
  exit 1
fi
#devices not doing service ctrl need to have a ${device}.services file anyway, just so remote.sh doesn't complain it isn't there to copy.
#It'll be ignored unless we give the -s flag.
#benchmarks must have a 'lavabench' rule

#And remote.sh can work with controlledrun.sh to run them for us
for device in "${devices[@]}"; do
  (run_benchmark)&
  runpids+=("$!")
done
  
ret=0
for runpid in "${runpids[@]}"; do
  wait "${runpid}"
  if test $? -ne 0; then
    ret=1
  fi
done

echo
echo "All runs completed"
exit ${ret}

#TODO: I suppose I might want a 'delete local copies of source/built benchmark'

