#!/bin/bash
#This script is an ad-hoc way of doing things pending a DejaGNU
#implementation that will avoid wheel re-invention. Let's not
#sink too much time into making this script beautiful.

topdir="`dirname $0`/.."

while getopts t:b: flag; do
  case "${flag}" in
    t) target="--target '${OPTARG}'";;
    b) benchmark="${OPTARG}.git";;
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
else #cross-build, implies we need remote devices
  if test ${#devices[@]} -eq 0; then
    echo "--target implies cross-compilation, but no devices given for run" 1>&2
    exit 1
  fi
fi

#cbuild2 can build the benchmarks just fine
(cd "${topdir}" && ./cbuild2.sh --build $1 $target)
if test $? -ne 0; then
  echo "Error while building benchmark $1" 1>&2
  exit 1
fi

. "${topdir}/common.sh" #So we can read config files

#And remote.sh can work with controlledrun.sh to run them for us
for device in "${devices[@]}"; do
  "${topdir}"/scripts/remote.sh "${device}" -c `read_config ${topdir}/config/boards/bench/${benchmark}.conf benchcmd` -l "${topdir}/${benchmark}-log" &
  (
    wait $!;
    if test $? -eq 0; then
      echo "+++ Run of ${benchmark} on ${device} succeeded"
    else
      echo "+++ Run of ${benchmark} on ${device} failed"
    fi
    echo "+++ Logs/results under ${topdir}/${benchmark}-log"
  )&
done

wait
echo "All runs completed"
