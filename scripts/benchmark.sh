#!/bin/bash
#This script is an ad-hoc way of doing things pending a DejaGNU
#implementation that will avoid wheel re-invention. Let's not
#sink too much time into making this script beautiful.

topdir="`dirname $0`/.."

while getopts t:b: flag; do
  case "${flag}" in
    t) target="--target '${OPTARG}'";;
    b) benchmark="${OPTARG}";;
    *)
       echo "Bad arg" 1>&2
       exit 1
    ;;
  esac
done
shift $((OPTIND - 1))
devices=("$@")

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
  #       for measurement, that's fine
  fi
else #cross-build, implies we need remote devices
  if test ${#devices[@]} -eq 0; then
    echo "--target implies cross-compilation, but no devices given for run" 1>&2
    exit 1
  fi
fi

#cbuild2 can build the benchmarks just fine
(cd "${topdir}" && ./cbuild2.sh --build "${benchmark}.git" ${target})
if test $? -ne 0; then
  echo "Error while building benchmark ${benchmark}" 1>&2
  exit 1
fi
#TODO: Work out how I get the builddir back. Might mean that I have to source
#cbuild2 in and call functions to build it, but hopefully there's an easier way
builddir="${topdir}/builds/armv7l-unknown-linux-gnueabihf/armv7l-unknown-linux-gnueabihf/eembc.git"
#devices not doing service ctrl need to have a ${device}.services file anyway, just so remote.sh doesn't complain it isn't there to copy. It'll be ignored unless we give the -s flag.
#benchmarks must have a 'lavabench' rule
#TODO: lava. can give a special value to ip for lava targets.

. "${topdir}/lib/common.sh" #So we can read config files

benchlog="`read_config ${benchmark}.git benchlog`"

#And remote.sh can work with controlledrun.sh to run them for us
for device in "${devices[@]}"; do
  (
    lava=0
    . "${topdir}/config/boards/bench/${device}.conf" #source_config requires us to have something get_toolname can parse
    if test $? -ne 0; then
      echo "Failed to source ${topdir}/config/boards/bench/${device}.conf" 1>&2
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
    echo "${ip}" | grep '\.json$'
    if test $? -eq 0; then
      lava=1
      ip=`lava.sh https://bogden@validation.linaro.org/RPC2/ ${ip}`
      if test $? -ne 0; then
        echo "Failed to acquire lava target" 1>&2
        exit 1
      fi
    fi
    "${topdir}"/scripts/remote.sh -t "${ip}" \
-m \
      -f "${builddir}" -f "${topdir}"/scripts/controlledrun.sh \
      -f "${topdir}/config/boards/bench/${device}.services" \
      -c "./controlledrun.sh -c ${flags} -- make -C ${benchmark}.git linarobench >stdout 2>stderr" \
      -l "${topdir}/${benchmark}-log" stdout stderr ${benchmark}.git/linarobenchlog &
    if test $? -eq 0; then
      echo "+++ Run of ${benchmark} on ${device} succeeded"
    else
      echo "+++ Run of ${benchmark} on ${device} failed"
    fi
    if test ${lava} -eq 1; then
      #ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${ip}" stop_hacking
      echo "+++++ Would now release"
    fi
  )&

  #TODO Use a signal handler for this? - what signal does a child send on exit?
  #{
  #  wait $!
  #  if test $? -eq 0; then
  #    echo "+++ Run of ${benchmark} on ${device} succeeded"
  #  else
  #    echo "+++ Run of ${benchmark} on ${device} failed"
  #  fi
  #  echo "+++ Logs/results under ${topdir}/${benchmark}-log"
  #}&
done

wait
echo
echo "All runs completed"
