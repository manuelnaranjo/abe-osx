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

topdir="`dirname $0`/.." #cbuild2 global, but this should be the right value for cbuild2
if ! test -e "${topdir}/host.conf"; then
  echo "No host.conf, did you run ./configure?" 1>&2
  exit 1
fi

keep='' #if set, don't clean up benchmark output on target, don't kill lava targets
while getopts t:b:k flag; do
  case "${flag}" in
    t) target="${OPTARG}";; #meaningful to sourced cbuild2 files in subshells below
    b) benchmark="${OPTARG}";;
    k)
       keep='-m'
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
devices=("$@") #Duplicate targets are fine for lava, they will resolve to different instances of the same machine. They're not fine for ssh access, where they will just resolve to the same machine every time.

confdir="${topdir}/config/boards/bench"
lavaserver="${USER}@validation.linaro.org/RPC2/"
builddir="`target2="${target}"; . ${topdir}/host.conf; . ${topdir}/lib/common.sh; if test x"${target2}" != x; then target="${target2}"; fi; get_builddir $(get_URL ${benchmark}.git)`"
benchlog="`. ${topdir}/host.conf; . ${topdir}/lib/common.sh; read_config ${benchmark}.git benchlog`"

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
  #       localhost and using it to dispatch benchmark jobs
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
#devices not doing service ctrl need to have a ${device}.services file anyway, just so remote.sh doesn't complain it isn't there to copy. It'll be ignored unless we give the -s flag.
#benchmarks must have a 'lavabench' rule

#And remote.sh can work with controlledrun.sh to run them for us
for device in "${devices[@]}"; do
  (
    . "${confdir}/${device}.conf" #source_config requires us to have something get_toolname can parse
    if test $? -ne 0; then
      echo "+++ Failed to source ${confdir}/${device}.conf" 1>&2
      exit 1
    fi
    flags="-b ${benchcore}"
    if test x"${othercore}" != x; then
      flags+=" -p ${othercore}"
    fi
    if test x"${netctl}" = xyes; then
      flags+=" -n"
    fi
    if test x"${servicectl}" = xyes; then
      flags+=" -s ${device}.services"
    fi
    if test x"${freqctl}" = xyes; then
      flags+=" -f"
    fi
    echo "${ip}" | grep '\.json$' > /dev/null
    if test $? -eq 0; then
      lava_target="${ip}"
      ip=''
      echo "Acquiring LAVA target ${lava_target}"
      exec 3< <(${topdir}/scripts/lava.sh "${lavaserver}" "${confdir}/${lava_target}" ${dispatch_timeout} ${boot_timeout} ${keep})
      if test $? -ne 0; then
        echo "+++ Failed to acquire LAVA target ${lava_target}" 1>&2
        exit 1
      fi
      while read <&3 line; do
        echo "${lava_target}: $line"
        if echo "${line}" | grep '^LAVA target ready at '; then
          ip="`echo ${line} | cut -d ' ' -f 5`"
          break
        fi
      done
      if test x"${ip}" = x; then
        echo "+++ Failed to acquire LAVA target ${lava_target}" 1>&2
        exit 1
      fi
    fi
    echo "${topdir}/scripts/remote.sh -t ${ip} \\"
    echo "${keep} \\"
    echo "-f ${builddir} -f ${topdir}/scripts/controlledrun.sh \\"
    echo "-f ${confdir}/${device}.services \\"
    echo "-c \"./controlledrun.sh -c ${flags} -- make -C ${benchmark}.git linarobench >stdout 2>stderr\" \\"
    echo "-l ${topdir}/${benchmark}-log stdout stderr ${benchmark}.git/linarobenchlog"
    "${topdir}"/scripts/remote.sh -t "${ip}" \
      ${keep} \
      -f "${builddir}" -f "${topdir}"/scripts/controlledrun.sh \
      -f "${confdir}/${device}.services" \
      -c "./controlledrun.sh -c ${flags} -l /dev/console -- make -C ${benchmark}.git linarobench >stdout 2>stderr" \
      -l "${topdir}/${benchmark}-log" stdout stderr ${benchmark}.git/linarobenchlog
    if test $? -eq 0; then
      echo "+++ Run of ${benchmark} on ${device} succeeded"
    else
      echo "+++ Run of ${benchmark} on ${device} failed"
    fi
    #TODO: Got a success report where I should have had a failure
  )&
done

wait
echo
echo "All runs completed"

#TODO: I suppose I might want a 'delete local copies of source/built benchmark'
