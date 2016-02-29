#!/bin/bash

abe_dir="${abe_dir:-$PWD/`dirname $0`/../..}"
${abe_dir}/scripts/dispatch-benchmark.py --dry-yaml \
  --lava-server validation.linaro.org/RPC2/ \
  --lava-user fred.implausible \
  --benchmark fakebench \
  --target-config mustang \
  --triple aarch64-linux-gnu \
  --toolchain https://releases.linaro.org/components/toolchain/binaries/latest-5.1/aarch64-linux-gnu/gcc-linaro-5.1-2015.08-x86_64_aarch64-linux-gnu.tar.xz \
  --sysroot https://releases.linaro.org/components/toolchain/binaries/latest-5.1/aarch64-linux-gnu/sysroot-linaro-glibc-gcc5.1-2015.08-aarch64-linux-gnu.tar.xz \
  --bundle-stream /private/personal/fred.implausible/ \
  -- \
  PUBLIC_KEY="`cat ~/.ssh/id_linaro.pub`"
