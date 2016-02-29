#!/bin/bash

abe_dir="${abe_dir:-$PWD/`dirname $0`/../..}"
${abe_dir}/scripts/dispatch-benchmark.py --dry-yaml \
  --lava-server validation.linaro.org/RPC2/ \
  --lava-user fred.implausible \
  --benchmark fakebench \
  --target-config panda-es \
  --triple arm-linux-gnueabihf \
  --toolchain https://releases.linaro.org/components/toolchain/binaries/latest-5.1/arm-linux-gnueabihf/gcc-linaro-5.1-2015.08-x86_64_arm-linux-gnueabihf.tar.xz \
  --sysroot https://releases.linaro.org/components/toolchain/binaries/latest-5.1/arm-linux-gnueabihf/sysroot-linaro-glibc-gcc5.1-2015.08-arm-linux-gnueabihf.tar.xz \
  --bundle-stream /private/personal/fred.implausible/ \
  -- \
  PUBLIC_KEY="`cat ~/.ssh/id_linaro.pub`"
