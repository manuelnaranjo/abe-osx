#!/bin/bash
#This script is an ad-hoc way of doing things pending a DejaGNU
#implementation that will avoid wheel re-invention. Let's not
#sink too much time into making this script beautiful.

#TODO Convert as much as possible into a function, so that we don't share global namespace with abe except where we mean to
#     Better - confine abe to a subshell

set -o pipefail
set -o nounset

#Make sure that subscripts clean up - we must not leave benchmark sources or data lying around,
#we should not leave lava targets reserved
trap clean_top EXIT
trap 'error=1; exit' TERM INT HUP QUIT

error=0
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
  if test x"${cmpbuild:-}" != x; then
    rm -f "${cmpbuild}"
    if test $? -ne 0; then
      echo "Failed to delete compressed benchmark output ${cmpbuild}" 1>&2
      error=1
    fi
  fi
  exit ${error}
}

function usage
{
  cat << EOF
$0 [-tckhl] -b <benchmark> <board...>

  -b   Identify the benchmark to build, e.g. fakebench, eembc. Compulsory.
  -c   Cautious. If this is set, failure in any stage of target setup will
       be treated as an error, even if recoverable. On by default.
  -h   Show this help.
  -k   Keep. If this is set, benchmark sources and results will be left on
       target. LAVA targets will not be released.
  -l   Sysroot to install on target. Blank uses native libraries. This option
       can only be used for LAVA targets.

  <board...> may be anything that has a file in config/boards/bench, e.g. the
  existence of arndale.conf means that you can put arndale here. At least one
  target may be specified. ssh targets must only be specified once. LAVA
  targets can be specified as many times as you like.

  If building natively, board is optional. If not given, the benchmark will
  run on localhost.
EOF
}

# load the configure file produced by configure
if test -e "${PWD}/host.conf"; then
    . "${PWD}/host.conf"
else
    echo "ERROR: no host.conf file!  Did you run configure?" 1>&2
    exit 1
fi
topdir="${abe_path}" #abe global, but this should be the right value for abe


#Sanity Checks
if test "$((`umask` & 077))" -ne 63; then
  echo "umask grants permissions to group and world, will remove those permissions" 1>&2
  if ! umask g-rwx,o-rwx; then
    echo "umask failed, wibble, aborting" 1>&2
    exit 1
  fi
fi

#TODO: Really, this check should operate on the route from the git server to localhost
. "${topdir}/scripts/benchutil.sh"
if ! check_private_route localhost; then
  echo "Do not appear to be on private network, conservatively aborting" 1>&2
  exit 1
fi
#End sanity checks


compiler_flags=""
run_benchargs=""
skip_build=
benchmark_gcc_path=
cautious='-c'
keep= #if set, don't clean up benchmark output on target, don't kill lava targets
target=
sysroot_path=
while getopts f:a:i:b:l:kchs flag; do
  case "${flag}" in
    a) run_benchargs="${OPTARG}";;
    s) skip_build=1;;
    i) benchmark_gcc_path="`cd \`dirname ${OPTARG}\` && echo $PWD/\`basename ${OPTARG}\``";;
    l) sysroot_path="${OPTARG}";;
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
    f) compiler_flags="${OPTARG}";;
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

if test x"${benchmark:-}" = x; then
  echo "No benchmark given (-b)" 1>&2
  echo "Sensible values might be eembc, spec2000, spec2006" 1>&2
  exit 1
fi
if test x"${sysroot_path:-}" != x; then
  if ! test -d "${sysroot_path}"; then
    echo "Sysroot path '${sysroot_path}' does not exist" 1>&2
    exit 1
  else
    if ! test -d "${sysroot_path}"/lib -a -d "${sysroot_path}"/usr/lib; then
      echo "Sysroot path '${sysroot_path}' does not look like a sysroot" 1>&2
      exit 1
    fi
  fi
fi
if test x"${benchmark_gcc_path:-}" = x; then
  echo "No GCC given (-i)" 1>&2
  exit 1
fi
if ! test -x "${benchmark_gcc_path}"; then
  echo "GCC '${benchmark_gcc_path}' does not exist or is not executable" 1>&2
  exit 1
fi
if test x"`basename ${benchmark_gcc_path}`" = xgcc; then #native build
  benchmark_gcc_triple=
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
  benchmark_gcc_triple="`basename ${benchmark_gcc_path%-gcc}`"
  if test ${#devices[@]} -eq 0; then
    echo "Cross-compiling gcc '${benchmark_gcc_path} given, but no devices given for run" 1>&2
    exit 1
  fi
fi

if test x"${skip_build:-}" = x; then
  #abe can build the benchmarks just fine
  (PATH="`dirname ${benchmark_gcc_path}`":${PATH} COMPILER_FLAGS=${compiler_flags} "${topdir}"/abe.sh --build "${benchmark}.git" ${benchmark_gcc_triple:+--target "${benchmark_gcc_triple}"})
  if test $? -ne 0; then
    echo "Error while building benchmark ${benchmark}" 1>&2
    exit 1
  fi
fi

builddir="`. ${abe_top}/host.conf && . ${topdir}/lib/common.sh && if test x"${benchmark_gcc_triple}" != x; then target="${benchmark_gcc_triple}"; fi && get_builddir $(get_URL ${benchmark}.git)`"
if test $? -ne 0; then
  echo "Unable to get builddir" 1>&2
  exit 1
fi

#Compress build to a tmpfile in our top-level working directory
#This should be good for bandwidth
#By keeping file at top level, we make sure that everything sensitive is in one place
cmpbuild="`mktemp -p ${abe_top} -t ${benchmark}_XXXXXXX.tar.bz2`"
if test $? -ne 0; then
  echo "Unable to create temporary file for compressed build output" 1>&2
  exit 1
fi
if ! tar cjf "${cmpbuild}" -C "${builddir}/.." "`basename ${builddir}`"; then
  echo "Unable to compress ${builddir} to ${cmpbuild}" 1>&2
  exit 1
fi
for device in "${devices[@]}"; do
  "${topdir}"/scripts/runbenchmark.sh -b "${benchmark}" -d "${device}" -t "${cmpbuild}" -a "${run_benchargs}" ${sysroot_path:+-l "${sysroot_path}"} ${keep} ${cautious} < /dev/null &
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
    sleep 60&
    wait $!
  fi
done

echo
if test ${error} -eq 0; then
  echo "All runs succeeded"
else
  echo "At least one run failed"
fi
exit ${error}

#TODO: I suppose I might want a 'delete local copies of source/built benchmark'

