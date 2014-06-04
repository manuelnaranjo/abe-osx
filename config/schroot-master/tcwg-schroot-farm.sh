#!/bin/bash

set -e
set -x

master="$(dirname $0)"
test_schroot="$master/../../scripts/test-schroot.sh"

# Generate chroots for all supported targets on tcwgbuild01, and then copy them to all other tcwgbuildXX machines.
gen="-g"
for m in $(for i in `seq 1 6`; do echo tcwgbuild0$i; done); do
    for a in aarch64-linux-gnu arm-linux-gnueabi arm-linux-gnueabihf i686-linux-gnu mips-linux-gnu mipsel-linux-gnu powerpc-linux-gnu x86_64-linux-gnu; do
	$test_schroot -v -c $master $gen -a $a $m
    done
    gen=""
done

# Copy ARMv7 hard-fp and soft-fp chroots to all chromebooks and some blacks.
for m in $(for i in `seq 1 8`; do echo tcwgchromebook0$i tcwgblack0$i; done); do
    for a in arm-linux-gnueabi arm-linux-gnueabihf; do
	$test_schroot -v -c $master $gen -a $a $m
    done
done
