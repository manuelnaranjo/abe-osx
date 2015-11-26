#!/bin/bash
set -eu
set -o pipefail

if test x"${TARGET_CONFIG%%-*}" = xjuno; then
  target_device_type=juno
else
  target_device_type="${TARGET_CONFIG}"
fi

#TODO Benchmarking-specific builds will eliminate these special cases
target_session=config/bench/lava/target-session
if test x"${TARGET_CONFIG}" = xkvm; then
  target_session="${target_session}-kvm.yaml"
elif test x"${TARGET_CONFIG}" = xmustang; then
  target_session="${target_session}-mustang.yaml"
else
  target_session="${target_session}.yaml"
fi

#TODO Change to uinstance server and 'safe benchmarks' user, when they exist
lava_server=https://validation.linaro.org/RPC2/

#Parameters to be substituted into template
echo JOB_NAME=${BENCHMARK}
echo BENCHMARK=${BENCHMARK}
echo TOOLCHAIN=${TOOLCHAIN:-}
echo RUN_FLAGS=${RUN_FLAGS:-}
echo COMPILER_FLAGS=${COMPILER_FLAGS:-}
echo MAKE_FLAGS=${MAKE_FLAGS:-}
echo PREBUILT=${PREBUILT:-}
echo HOST_SESSION=config/bench/lava/trusted-host-session.yaml
echo HOST_IMAGE=http://images.validation.linaro.org/ubuntu-14-04-server-base.img.gz
echo TARGET_SESSION=${target_session}
#TODO Map from target types to specific images
echo TARGET_IMAGE=http://images.validation.linaro.org/ubuntu-14-04-server-base.img.gz
echo TARGET_CONFIG=${TARGET_CONFIG}
echo TARGET_DEVICE_TYPE=${target_device_type}

#TODO Change to uinstance server/user/stream, when they exist
echo BUNDLE_SERVER=${lava_server}
echo BUNDLE_STREAM_NAME=/anonymous/bogden/

echo ABE_REPO=https://git.linaro.org/toolchain/abe
#TODO Fix this to appropriate branch when we have the uinstance
echo ABE_REVISION=${ABE_REVISION:-bernie/benchmarking-uinstance}

echo TIMEOUT=1800
#End of parameters to substitute into template
