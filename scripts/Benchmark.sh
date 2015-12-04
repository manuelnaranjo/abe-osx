#!/bin/bash
set -eu
set -o pipefail

#Mapping from targets to images
#TODO Two maps to handle some cases having 1 line and some cases having 2 lines
#     Dreadful hack that will do for now.
declare -A image_map_1 image_map_2
image_map_1=(
[kvm]='image: "http://images.validation.linaro.org/ubuntu-14-04-server-base.img.gz"'
[juno]='hwpack: "http://people.linaro.org/~bernie.ogden/hwpack_linaro-lt-vexpress64-rtsm_20150114-706_arm64_supported.tar.gz"'
[arndale]='image: "http://people.linaro.org/~bernie.ogden/arndale/arndale.img"'
[panda-es]='hwpack: "http://releases.linaro.org/14.05/ubuntu/panda/hwpack_linaro-panda_20140525-654_armhf_supported.tar.gz"'
#[mustang]=#tricky, uses a completely different boot method
)
image_map_2=(
[juno]='rootfs: "http://people.linaro.org/~bernie.ogden/linaro-utopic-developer-20150114-87.tar.gz"'
[panda-es]='rootfs: "http://releases.linaro.org/14.05/ubuntu/panda/linaro-trusty-developer-20140522-661.tar.gz"'
)

if test x"${TARGET_CONFIG%%-*}" = xjuno; then
  TARGET_DEVICE_TYPE=juno
else
  TARGET_DEVICE_TYPE="${TARGET_CONFIG}"
fi
if test x"${image_map_1[${TARGET_DEVICE_TYPE}]:-}" = x; then
  echo "No image for target type ${TARGET_DEVICE_TYPE}" >&2
  exit 1
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

#Output parameter, escaping single quotes from YAML
function output_param {
  echo $1="${2//\'/\'\'}"
}

#Parameters to be substituted into template
output_param JOB_NAME "${BENCHMARK}-${LAVA_USER}"
output_param BENCHMARK "${BENCHMARK}"
output_param TOOLCHAIN "${TOOLCHAIN:-}"
output_param SYSROOT "${SYSROOT:-}"
output_param RUN_FLAGS "${RUN_FLAGS:-}"
output_param COMPILER_FLAGS "${COMPILER_FLAGS:-}"
output_param MAKE_FLAGS "${MAKE_FLAGS:-}"
output_param PREBUILT "${PREBUILT:-}"
output_param HOST_SESSION "config/bench/lava/host-session.yaml"
output_param HOST_IMAGE "http://images.validation.linaro.org/ubuntu-14-04-server-base.img.gz"
output_param TARGET_SESSION "${TARGET_SESSION}"
output_param TARGET_IMAGE_1 "${image_map_1[${TARGET_DEVICE_TYPE}]}"
output_param TARGET_IMAGE_2 "${image_map_2[${TARGET_DEVICE_TYPE}]:-}"
output_param TARGET_CONFIG "${TARGET_CONFIG}"
output_param TARGET_DEVICE_TYPE "${TARGET_DEVICE_TYPE}"
output_param BUNDLE_SERVER "https://${LAVA_SERVER}"
output_param BUNDLE_STREAM "${BUNDLE_STREAM:-/private/personal/${LAVA_USER}/}"
output_param TESTDEF_REPO "https://git.linaro.org/toolchain/abe"
output_param TESTDEF_REVISION "${TESTDEF_REVISION:-benchmarking}"
#TODO Map this? Depend on benchmark and target.
output_param TIMEOUT 1800
output_param PUBLIC_KEY "${PUBLIC_KEY:-}"
#End of parameters to substitute into template
