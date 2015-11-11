#!/bin/bash
#This script is an ad-hoc way of doing things pending a DejaGNU
#implementation that will avoid wheel re-invention. Let's not
#sink too much time into making this script beautiful.

#TODO Convert as much as possible into a function, so that we don't share global namespace with abe except where we mean to
#     Better - confine abe to a subshell

set -o pipefail
set -o nounset

#Make sure that subscripts clean up - we must not leave benchmark sources or data lying around,
trap clean_top EXIT
trap 'error=1; exit' TERM INT HUP QUIT

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
$0 [-tckh] -b <benchmark> <board...>

  -b   Identify the benchmark to build, e.g. fakebench, eembc. Compulsory.
  -c   Cautious. If this is set, failure in any stage of target setup will
       be treated as an error, even if recoverable. On by default.
  -h   Show this help.
  -k   Keep. If this is set, benchmark sources and results will be left on
       target.

  <board...> may be anything that has a file in config/bench/boards, e.g. the
  existence of arndale.conf means that you can put arndale here. At least one
  target may be specified. Each target must only be specified once.

  If building natively, board is optional. If not given, the benchmark will
  run on localhost.
EOF
}

# load the configure file produced by configure
if test -e "${PWD}/host.conf"; then
    . "${PWD}/host.conf"
else
    echo "ERROR: no host.conf file!  Did you run configure?" 1>&2
    error=1
    exit
fi
topdir="${abe_path}" #abe global, but this should be the right value for abe


#Sanity Checks
if test "$((`umask` & 077))" -ne 63; then
  echo "umask grants permissions to group and world, will remove those permissions" 1>&2
  if ! umask g-rwx,o-rwx; then
    echo "umask failed, wibble, aborting" 1>&2
    error=1
    exit
  fi
fi
#End sanity checks

tag=""
compiler_flags=""
run_benchargs=""
phases="both"
benchmark_gcc_path=
cautious='-c'
keep= #'-p' (polite)  - clean up and release target even if there is an error
      #''   (default) - clean up and release target unless there is an error
      #'-k' (keep)    - unconditionally keep target-side data and target
target=
post_run_cmd=
post_target_cmd=
while getopts a:b:ce:f:g:hi:km:pr:s: flag; do
  case "${flag}" in
    a) run_benchargs="${OPTARG}";;
    b) benchmark="${OPTARG}";;
    c) cautious=;;
    e) post_target_cmd="${OPTARG}";;
    f) compiler_flags="${OPTARG}";;
    g) tag="${OPTARG}";;
    h)
       usage
       error=0
       exit
    ;;
    i) benchmark_gcc_path="`cd \`dirname ${OPTARG}\` && echo $PWD/\`basename ${OPTARG}\``";;
    k)
       if test x"${keep}" = 'x-p'; then
         echo '-k overriding earlier -p'
       fi
       keep='-k'
       echo 'Unconditional keep (-k) set: possibly sensitive benchmark data will be left on target, even if run succeeds'
       echo 'Continue? (y/N)'
       read answer
       if ! echo "${answer}" | egrep -i '^(y|yes)[[:blank:]]*$' > /dev/null; then
         error=0
         exit
       fi
    ;;
    m) make_flags="${OPTARG}";;
    p)
       if test x"${keep}" = 'x-k'; then
         echo '-p overriding earlier -k'
       fi
       keep='-p'
       echo 'Unconditional release (-p) set: data will be scrubbed and target released, even if run fails'
    ;;
    r) post_run_cmd="${OPTARG}";;
    s)
       phases="${OPTARG}"
       if test x"${OPTARG}" = x; then
         echo "-s takes 'runonly', 'buildonly', 'both' or a tarball" 1>&2
         error=1
         exit
       fi
       if test x"${phases}" != xrunonly && test x"${phases}" != xbuildonly && test x"${phases}" != xboth; then
         if test -e "${phases}"; then
           cmpbuild="${phases}"
           phases='runonly'
         else
           echo "-s takes 'runonly', 'buildonly', 'both' or a tarball" 1>&2
           error=1
           exit
         fi
       fi
    ;;
    *)
       echo "Bad arg" 1>&2
       error=1
       exit
    ;;
  esac
done
shift $((OPTIND - 1))
devices=("$@")

if test x"${benchmark:-}" = x; then
  echo "No benchmark given (-b)" 1>&2
  echo "Sensible values might be eembc, spec2000, spec2006" 1>&2
  error=1
  exit
fi
if test x"${benchmark_gcc_path:-}" = x; then
  echo "No GCC given (-i)" 1>&2
  error=1
  exit
fi
if ! test -x "${benchmark_gcc_path}"; then
  echo "GCC '${benchmark_gcc_path}' does not exist or is not executable" 1>&2
  error=1
  exit
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
    error=1
    exit
  fi
fi

builddir="`. ${abe_top}/host.conf && . ${topdir}/lib/common.sh && if test x"${benchmark_gcc_triple}" != x; then target="${benchmark_gcc_triple}"; fi && get_builddir $(get_URL ${benchmark}.git)`"
if test $? -ne 0; then
  echo "Unable to get builddir" 1>&2
  error=1
  exit
fi

if test x"${phases}" != xrunonly; then
  #abe can build the benchmarks just fine
  (PATH="`dirname ${benchmark_gcc_path}`":${PATH} COMPILER_FLAGS=${compiler_flags} "${topdir}"/abe.sh --space 0 ${make_flags:+--set makeflags="${make_flags}"} --build "${benchmark}.git" ${benchmark_gcc_triple:+--target "${benchmark_gcc_triple}"})
  if test $? -ne 0; then
    echo "Error while building benchmark ${benchmark}" 1>&2
    error=1
    exit
  fi

  #Log information about build environment
  echo "Build Environment" > "${builddir}/build.log"
  echo "=================" >> "${builddir}/build.log"
  env >> "${builddir}/build.log"
  echo >> "${builddir}/build.log"

  echo "Toolchain" >> "${builddir}/build.log"
  echo "=========" >> "${builddir}/build.log"
  ${benchmark_gcc_path} -v >> "${builddir}/build.log" 2>&1
  ${benchmark_gcc_path} --version >> "${builddir}/build.log" 2>&1
  echo >> "${builddir}/build.log"

  echo "Sizes" >> "${builddir}/build.log"
  echo "=====" >> "${builddir}/build.log"
  (cd "${builddir}" && eval "stat -c '%n %s' `. ${abe_top}/host.conf && . ${topdir}/lib/common.sh && read_config ${benchmark}.git binaries`") >> "${builddir}/build.log"
  if test $? -ne 0; then
    echo "Failed to get sizes of benchmark binaries" 2>&1
    error=1
    exit
  fi
  (cd "${builddir}" && eval "size  `. ${abe_top}/host.conf && . ${topdir}/lib/common.sh && read_config ${benchmark}.git binaries`") >> "${builddir}/build.log"
  if test $? -ne 0; then
    echo "Failed to get sizes of benchmark binaries" 2>&1
    error=1
    exit
  fi
fi
if test x"${phases}" = xbuildonly; then
  error=0
  exit
fi

#If the user did not supply a tarball then compress our build
if test x"${cmpbuild:-}" = x; then
  #Compress build to a tmpfile in our top-level working directory
  #This should be good for bandwidth
  #By keeping file at top level, we make sure that everything sensitive is in one place
  cmpbuild="`mktemp -p ${abe_top} -t ${benchmark}_XXXXXXX.tar.bz2`"
  if test $? -ne 0; then
    echo "Unable to create temporary file for compressed build output" 1>&2
    error=1
    exit
  fi
  if ! tar cjf "${cmpbuild}" -C "${builddir}/.." "`basename ${builddir}`"; then
    echo "Unable to compress ${builddir} to ${cmpbuild}" 1>&2
    error=1
    exit
  fi
fi

for device in "${devices[@]}"; do
  "${topdir}"/scripts/runbenchmark.sh ${post_run_cmd:+-r "${post_run_cmd}"} ${post_target_cmd:+-e "${post_target_cmd}"} -g "${tag:-${device}-${benchmark}}" -b "${benchmark}" -d "${device}" -t "${cmpbuild}" -a "${run_benchargs}" ${keep} ${cautious} < /dev/null &
  runpids[$!]=''
done

error=0
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

