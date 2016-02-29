#!/bin/bash
set -ue
set -o pipefail

abe_dir="${abe_dir:-`dirname $0`/../..}"
target_config="${target_config:-juno-a57}"
triple="${triple:-aarch64-linux-gnu}"

if test -z "${toolchain:-}"; then
  if test "${triple}" = 'aarch64-linux-gnu'; then
    toolchain='https://releases.linaro.org/components/toolchain/binaries/latest-5.1/aarch64-linux-gnu/gcc-linaro-5.1-2015.08-x86_64_aarch64-linux-gnu.tar.xz'
  elif test "${triple}" = 'arm-linux-gnueabihf'; then
    toolchain='https://releases.linaro.org/components/toolchain/binaries/latest-5.1/arm-linux-gnueabihf/gcc-linaro-5.1-2015.08-x86_64_arm-linux-gnueabihf.tar.xz'
  else
    echo "Unknown triple" >&2
    exit 1
  fi
fi
if test -z "${sysroot:-}"; then
  if test "${triple}" = 'aarch64-linux-gnu'; then
    sysroot='https://releases.linaro.org/components/toolchain/binaries/latest-5.1/aarch64-linux-gnu/sysroot-linaro-glibc-gcc5.1-2015.08-aarch64-linux-gnu.tar.xz'
  elif test "${triple}" = 'arm-linux-gnueabihf'; then
    sysroot='https://releases.linaro.org/components/toolchain/binaries/latest-5.1/arm-linux-gnueabihf/sysroot-linaro-glibc-gcc5.1-2015.08-arm-linux-gnueabihf.tar.xz'
  fi
fi

${abe_dir}/scripts/dispatch-benchmark.py --dry-yaml \
  --lava-server lava.tcwglab/RPC2/ \
  --lava-user fred.implausible \
  --benchmark Coremark-Pro \
  --target-config "${target_config}" \
  --triple "${triple}" \
  --toolchain "${toolchain}" \
  --sysroot "${sysroot}" \
  --bundle-stream /anonymous/fred.implausible/ \
  --make-flags='-j5' \
  -- \
  TIMEOUT=$((96*3600)) \
  PUBLIC_KEY=a_very_public_key
