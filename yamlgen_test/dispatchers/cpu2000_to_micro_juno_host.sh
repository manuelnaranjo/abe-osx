#!/bin/bash

abe_dir="${abe_dir:-$PWD/`dirname $0`/../..}"
${abe_dir}/scripts/dispatch-benchmark.py --dry-yaml \
  --lava-server lava.tcwglab/RPC2/ \
  --host-device-type juno \
  --lava-user fred.implausible \
  --benchmark CPU2000 \
  --target-config juno-a57 \
  --triple aarch64-linux-gnu \
  --toolchain /usr/bin/gcc \
  --run-flags='-n 1 --size test' \
  --compiler-flags='-I/usr/include/aarch64-linux-gnu/c++/4.9/ -I/usr/include/c++/4.9/ -I/usr/include/c++/4.9/backward/' \
  --sysroot https://releases.linaro.org/components/toolchain/binaries/latest-5.1/aarch64-linux-gnu/sysroot-linaro-glibc-gcc5.1-2015.08-aarch64-linux-gnu.tar.xz \
  --bundle-stream /anonymous/fred.implausible2/ \
  --make-flags='-j5' \
  -- \
  PUBLIC_KEY="`cat ~/.ssh/id_linaro.pub`" \
  TIMEOUT=$((96*3600))
