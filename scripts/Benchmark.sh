#!/bin/bash
set -eu
set -o pipefail

if test x"${TARGET_CONFIG%%-*}" = xjuno; then
  TARGET_DEVICE_TYPE=juno
else
  TARGET_DEVICE_TYPE="${TARGET_CONFIG}"
fi

#TODO Benchmarking-specific builds will eliminate these special cases
TARGET_SESSION=config/bench/lava/target-session
if test x"${TARGET_CONFIG}" = xkvm; then
  TARGET_SESSION="${TARGET_SESSION}-kvm.yaml"
elif test x"${TARGET_CONFIG}" = xmustang; then
  TARGET_SESSION="${TARGET_SESSION}-mustang.yaml"
else
  TARGET_SESSION="${TARGET_SESSION}.yaml"
fi

LAVA_USER="${LAVA_USER:-${USER}}"

#TODO Add consistency tests
#For example, setting compiler/make flags makes no sense if prebuilt is set

#Parameters to be substituted into template
echo JOB_NAME="${BENCHMARK}-${LAVA_USER}"
echo BENCHMARK="${BENCHMARK}"
echo TOOLCHAIN="${TOOLCHAIN:-}"
echo RUN_FLAGS="${RUN_FLAGS:-}"
echo COMPILER_FLAGS="${COMPILER_FLAGS:-}"
echo MAKE_FLAGS="${MAKE_FLAGS:-}"
echo PREBUILT="${PREBUILT:-}"
echo HOST_SESSION="config/bench/lava/trusted-host-session.yaml"
echo HOST_IMAGE="http://images.validation.linaro.org/ubuntu-14-04-server-base.img.gz"
echo TARGET_SESSION="${TARGET_SESSION}"
#TODO Map from target types to specific images
echo TARGET_IMAGE="http://images.validation.linaro.org/ubuntu-14-04-server-base.img.gz"
echo TARGET_CONFIG="${TARGET_CONFIG}"
echo TARGET_DEVICE_TYPE="${TARGET_DEVICE_TYPE}"
echo BUNDLE_SERVER="https://${LAVA_SERVER}"
#TODO Change to uinstance user/stream, when they exist
echo BUNDLE_STREAM_NAME="/anonymous/${LAVA_USER}/"
echo ABE_REPO="https://git.linaro.org/toolchain/abe"
#TODO Fix this to appropriate branch when we have the uinstance
echo ABE_REVISION="${ABE_REVISION:-bernie/benchmarking-uinstance}"
#TODO Map this? Depend on benchmark and target.
echo TIMEOUT=1800
#End of parameters to substitute into template
