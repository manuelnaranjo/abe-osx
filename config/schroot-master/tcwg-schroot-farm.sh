#!/bin/bash

set -e
set -x

master="$(dirname $0)"
test_schroot="$master/../../scripts/test-schroot.sh"

tcwgbuild_archs=(
    aarch64-linux-gnu
    arm-linux-gnueabi
    arm-linux-gnueabihf
    i686-linux-gnu
    mips-linux-gnu
    mipsel-linux-gnu
    powerpc-linux-gnu
    x86_64-linux-gnu
)

# Generate chroots for all supported targets on tcwgbuild01 ...
pids=""
for a in "${tcwgbuild_archs[@]}"; do
    eval $test_schroot -v -g -c $master -a $a tcwgbuild01 &
    pids="$pids $!"
done
wait $pids

# ... then copy them to all other tcwgbuildXX machines.
pids=""
for m in $(for i in `seq 2 6`; do echo tcwgbuild0$i; done); do
    for a in "${tcwgbuild_archs[@]}"; do
	eval $test_schroot -c $master -a $a $m &
	pids="$pids $!"
    done
done
# Copy ARMv7 hard-fp and soft-fp chroots to all chromebooks and some blacks.
for m in linaro@tcwg-d01-01 linaro@tcwg-d01-02 $(for i in `seq 1 8`; do echo linaro@tcwgchromebook0$i; done) $(for i in `seq 1 6`; do echo tcwgblack0$i; done); do
    for a in arm-linux-gnueabi arm-linux-gnueabihf; do
	eval $test_schroot -c $master -a $a $m &
	pids="$pids $!"
    done
done
# Copy Aarch64 and ARM 32-bit chroots to AArch64 boards.
for m in $(for i in `seq 1 3`; do echo linaro@tcwg-apm-0$i; done); do
    for a in aarch64-linux-gnu arm-linux-gnueabi arm-linux-gnueabihf; do
	eval $test_schroot -c $master -a $a $m &
	pids="$pids $!"
    done
done


wait $pids
echo ALL DONE
