#!/bin/bash
#This script is an ad-hoc way of doing things pending a DejaGNU
#implementation that will avoid wheel re-invention. Let's not
#sink too much time into making this script beautiful.

#TODO Convert as much as possible into a function, so that we don't share global namespace with cbuild2 except where we mean to
#     Better - confine cbuild2 to a subshell

set -o pipefail

#Make sure that subscripts clean up - we must not leave benchmark sources or data lying around,
#we should not leave lava targets reserved
trap clean_top EXIT
trap 'exit ${error}' TERM INT HUP QUIT

error=1
declare -A runpids

clean_top()
{
  for runpid in "${!runpids[@]}"; do
    if kill -0 "${runpid}" 2>/dev/null; then
      kill "${runpid}" 2>/dev/null
      wait "${runpid}"
      if test $? -ne 0; then
        error=1
      fi
    fi
  done
  exit ${error}
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

#TODO: Really, this check should operate on the route from the git server to localhost
. "${topdir}/scripts/listener.sh"
if ! check_private_route localhost; then
  echo "Do not appear to be on private network, conservatively aborting" 1>&2
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
fi

if test x"$skip_build" = x; then
  #cbuild2 can build the benchmarks just fine
  (cd "${topdir}" && ./cbuild2.sh --build "${benchmark}.git" ${target:+--target "${target}"})
  if test $? -ne 0; then
    echo "Error while building benchmark ${benchmark}" 1>&2
    exit 1
  fi
fi

builddir="`target2="${target}"; . ${topdir}/host.conf && . ${topdir}/lib/common.sh && if test x"${target2}" != x; then target="${target2}"; fi && get_builddir $(get_URL ${benchmark}.git)`"
if test $? -ne 0; then
  echo "Unable to get builddir" 1>&2
  exit 1
fi
for device in "${devices[@]}"; do
  "${topdir}"/scripts/runbenchmark.sh -b "${benchmark}" -d "${device}" -t "${builddir}" ${keep} ${cautious} &
  runpids[$!]=''
done

running_pids=("${!runpids[@]}")
while true; do
  for running_pid in "${running_pids[@]}"; do
    kill -0 "${running_pid}" 2>/dev/null
    if test $? -ne 0; then #Process cannot be signalled, reap it
      wait "${running_pid}"
      if test $? -ne 0; then
        error=1
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
exit ${error}

#TODO: I suppose I might want a 'delete local copies of source/built benchmark'

