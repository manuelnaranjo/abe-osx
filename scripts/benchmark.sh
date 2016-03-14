#!/bin/bash
#This script is an ad-hoc way of doing things pending a DejaGNU
#implementation that will avoid wheel re-invention. Let's not
#sink too much time into making this script beautiful.

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
$0 -b <benchmark> <target...>

  -a   Flags to pass to the benchmark's execution harness.
  -b   Identify the benchmark to build, e.g. fakebench, CPU2006. Compulsory.
  -c   Careless. If this is not set, failure in any stage of target setup will
       be treated as an error, even if recoverable.
  -e   Command to run on target after benchmark results have been copied back
       (in other words, when runbenchmark.sh exits).
  -f   Compiler flags, to use when building the benchmark.
  -h   Show this help.
  -i   GCC binary to build the benchmark with.
  -k   Keep. If this is set, benchmark sources and results will be left on
       target, even if the run succeeds.
  -m   Make flags, to use when building the benchmark. (Note that these
       do not relate to running the benchmark, even if the benchmark's
       execution harness is based on make).
  -p   Polite. If this is set, benchmarks sources and results will be removed
       from the target, even if the run fails.
  -r   Command to run on target immediately after benchmark runs, in same
       ssh session (shell) as the benchmark run itself.
  -s   Phases to execute. May be 'runonly', 'buildonly' or 'both'. Defaults
       to 'both'. 'runonly' usually implies reusing a benchmark that this
       script had used before. As a special case, if this option is given a
       tarball of a prebuilt benchmark, -s is set to 'runonly' and the passed
       tarball is the benchmark to run.
  -x   Triple describing target(s). Would typically be set to aarch64-linux-gnu
       or arm-linux-gnueabihf.

  <target...> may be anything that has a file in config/bench/boards, e.g. the
  existence of arndale.conf means that you can put arndale here. Can run
  locally by specifying localhost as the only target.
EOF
}

function read_binaries
{
  (
    . ${abe_top}/host.conf &&
    . ${topdir}/lib/common.sh &&
    if test -n "${triple}"; then
      target="${triple}"
    fi &&
    cd "${builddir}" &&
    eval ls --color=none `read_config ${benchmark}.git binaries`
  )
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

compiler_flags=""
run_benchargs=""
phases="both"
toolchain_path=
triple=
cautious='-c'
keep= #'-p' (polite)  - clean up and release target even if there is an error
      #''   (default) - clean up and release target unless there is an error
      #'-k' (keep)    - unconditionally keep target-side data and target
target=
post_run_cmd=
post_target_cmd=
while getopts a:b:ce:f:hi:km:pr:s:x: flag; do
  case "${flag}" in
    a) run_benchargs="${OPTARG}";;
    b) benchmark="${OPTARG}";;
    c) cautious=;;
    e) post_target_cmd="${OPTARG}";;
    f) compiler_flags="${OPTARG}";;
    h)
       usage
       error=0
       exit
    ;;
    i) toolchain_path="`cd \`dirname ${OPTARG}\` && echo $PWD/\`basename ${OPTARG}\``";;
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
    x) triple="${OPTARG}";;
    *)
       echo "Bad arg" 1>&2
       error=1
       exit
    ;;
  esac
done
shift $((OPTIND - 1))
devices=("$@")

if test ${#devices[@]} -eq 0; then
  if test x"${phases}" != xbuildonly; then
    echo "No devices given for run" 1>&2
    echo "To run locally, give 'localhost'" 1>&2
    exit 1
  fi
fi
if test x"${benchmark:-}" = x; then
  echo "No benchmark given (-b)" 1>&2
  echo "Sensible values might be Coremark-Pro, CPU2000, CPU2006" 1>&2
  error=1
  exit
fi
if test x"${toolchain_path}" = x; then
  toolchain_path="`which ${triple:+${triple}-}gcc`"
fi
if test x"${phases}" != xrunonly; then
  if ! test -x "${toolchain_path}"; then
    echo "Toolchain '${toolchain_path}' does not exist or is not executable" 1>&2
    error=1
    exit
  fi
fi

builddir="`. ${abe_top}/host.conf && . ${topdir}/lib/common.sh && if test x"${triple}" != x; then target="${triple}"; fi && get_builddir $(get_URL ${benchmark}.git)`"
if test $? -ne 0; then
  echo "Unable to get builddir" 1>&2
  error=1
  exit
fi

if test x"${phases}" != xrunonly; then
  #abe can build the benchmarks just fine
  #echo PATH="`dirname ${toolchain_path}`":${PATH}
  #echo COMPILER_FLAGS=${compiler_flags}
  #echo "${topdir}"/abe.sh --space 0 ${make_flags:+--set makeflags="${make_flags}"} --build "${benchmark}.git" ${triple:+--target "${triple}"}

  #TODO: If/when BZ2052 and 2053 are fixed, we can change this code such that COMPILER_FLAGS is passed through with the other makeflags.
  #This will cause COMPILER_FLAGS to always be a CLI make variable, and allow us to drop the workaround in the abe commit with message 'Pass COMPILER_FLAGS through default_makeflags'
  (PATH="`dirname ${toolchain_path}`":${PATH} COMPILER_FLAGS=${compiler_flags} "${topdir}"/abe.sh --space 0 ${make_flags:+--set makeflags="${make_flags}"} --build "${benchmark}.git" ${triple:+--target "${triple}"})
  if test $? -ne 0; then
    echo "Error while building benchmark ${benchmark}" 1>&2
    error=1
    exit
  fi

  #Log information about build environment
  executables=(`read_binaries`)
  cat > "${builddir}"/build.log << EOF
Build Environment
=================
`env 2>&1`

abe Source
==========
SHA1 of HEAD: `git -C "${topdir}" rev-parse HEAD 2>&1`
Name ref for HEAD: `git -C "${topdir}" name-rev HEAD 2>&1`

Status
------
`git -C "${topdir}" status --ignored 2>&1`

Remote(s)
---------
`git -C "${topdir}" remote -v 2>&1`

${benchmark} Source
`echo "${benchmark}" | tr '[:print:]' '='`=======
SHA1 of HEAD: `git -C snapshots/"${benchmark}".git rev-parse HEAD 2>&1`
Name ref for HEAD: `git -C snapshots/"${benchmark}".git name-rev HEAD 2>&1`

Status
------
`git -C snapshots/"${benchmark}".git status --ignored 2>&1`

Remote(s)
---------
`git -C snapshots/"${benchmark}".git remote -v 2>&1`

Toolchain
=========
`${toolchain_path} -v 2>&1`
`${toolchain_path} --version 2>&1`

Sizes
=====
EOF
  (cd "${builddir}" && size "${executables[@]}") >> "${builddir}/build.log" 2>&1
  if test $? -ne 0; then
    echo "Failed to get sizes of benchmark binaries" 2>&1
    error=1
    exit
  fi
fi #if we have done a build

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
  bash `echo ${-/x/-x} | grep -o -- -x` "${topdir}"/scripts/runbenchmark.sh ${post_run_cmd:+-r "${post_run_cmd}"} ${post_target_cmd:+-e "${post_target_cmd}"} -b "${benchmark}" -d "${device}" -t "${cmpbuild}" -a "${run_benchargs}" -f "${triple}" ${keep} ${cautious} < /dev/null &
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

