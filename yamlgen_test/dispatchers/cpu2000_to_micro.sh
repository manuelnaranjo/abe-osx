#!/bin/bash

abe_dir="${abe_dir:-$PWD/`dirname $0`/../..}"
${abe_dir}/scripts/dispatch-benchmark.py --dry-yaml \
  --lava-server lava.tcwglab/RPC2/ \
  --lava-user fred.implausible \
  --benchmark CPU2000 \
  --target-config juno-a57 \
  --triple aarch64-linux-gnu \
  --toolchain https://releases.linaro.org/components/toolchain/binaries/latest-5.1/aarch64-linux-gnu/gcc-linaro-5.1-2015.08-x86_64_aarch64-linux-gnu.tar.xz \
  --run-flags='-n 1 --size test' \
  --sysroot https://releases.linaro.org/components/toolchain/binaries/latest-5.1/aarch64-linux-gnu/sysroot-linaro-glibc-gcc5.1-2015.08-aarch64-linux-gnu.tar.xz \
  --bundle-stream /anonymous/fred.implausible2/ \
  -- \
  PUBLIC_KEY="`cat ~/.ssh/id_linaro.pub`" \
  TIMEOUT=$((96*3600))
