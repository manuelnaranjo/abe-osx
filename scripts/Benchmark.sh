#!/bin/bash
set -eu
set -o pipefail

#Output parameter, with no escaping.
#Suitable for cases where $2 is itself a chunk of YAML.
function output_slot {
  echo $1="$2"
}

#Output parameter, escaping single quotes from YAML.
#Suitable for cases where $2 is the RHS of a YAML expression in a template.
function output_value {
  echo $1="${2//\'/\'\'}"
}

#Mapping from targets to images
#TODO 3 maps to handle some cases having 1 line, some cases having 2 lines and
#     some cases having 3 lines. Dreadful hack that will do for now.
declare -A image_map_1 image_map_2 image_map_3
image_map_1=(
[kvm]='image: "http://images.validation.linaro.org/ubuntu-14-04-server-base.img.gz"'
[juno]='hwpack: "http://people.linaro.org/~bernie.ogden/hwpack_linaro-lt-vexpress64-rtsm_20150114-706_arm64_supported.tar.gz"'
[arndale]='image: "http://people.linaro.org/~bernie.ogden/arndale/arndale.img"'
[panda-es]='hwpack: "http://releases.linaro.org/14.05/ubuntu/panda/hwpack_linaro-panda_20140525-654_armhf_supported.tar.gz"'
[mustang]='dtb: "http://kernel-build.s3-website-eu-west-1.amazonaws.com/next-20151022/arm64-defconfig/dtbs/apm-mustang.dtb"'
)
image_map_2=(
[juno]='rootfs: "http://people.linaro.org/~bernie.ogden/linaro-utopic-developer-20150114-87.tar.gz"'
[panda-es]='rootfs: "http://releases.linaro.org/14.05/ubuntu/panda/linaro-trusty-developer-20140522-661.tar.gz"'
[mustang]='kernel: "http://kernel-build.s3-website-eu-west-1.amazonaws.com/next-20151022/arm64-defconfig/uImage-mustang"'
)
image_map_3=(
[mustang]='nfsrootfs: "http://people.linaro.org/~bernie.ogden/linaro-utopic-developer-20150319-701.tar.gz"'
)

echo ${TARGET_CONFIG:?TARGET_CONFIG must be set} > /dev/null
HOST_DEVICE_TYPE="${HOST_DEVICE_TYPE:-kvm}"
if test x"${HOST_SESSION:-}" = x; then
  HOST_SESSION=config/bench/lava/host-session
  if test x"${HOST_DEVICE_TYPE}" = xjuno ||
     test x"${HOST_DEVICE_TYPE}" = xarndale ||
     test x"${HOST_DEVICE_TYPE}" = xpanda-es; then
    HOST_SESSION="${HOST_SESSION}-no-multilib.yaml"
    HOST_DEPLOY_ACTION="${HOST_DEPLOY_ACTION:-deploy_linaro_image}"
  elif test x"${HOST_DEVICE_TYPE}" = xmustang; then
    HOST_SESSION="${HOST_SESSION}.yaml"
    HOST_DEPLOY_ACTION="${HOST_DEPLOY_ACTION:-deploy_linaro_kernel}"
  elif test x"${HOST_DEVICE_TYPE}" = xkvm; then
    HOST_SESSION="${HOST_SESSION}-multilib.yaml"
    HOST_DEPLOY_ACTION="${HOST_DEPLOY_ACTION:-deploy_linaro_image}"
  else
    echo "Unable to determine HOST_SESSION for ${HOST_DEVICE_TYPE}" >&2
    exit 1
  fi
fi
#guarantee that HOST_DEPLOY_ACTION is set
HOST_DEPLOY_ACTION="${HOST_DEPLOY_ACTION:-deploy_linaro_image}"

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
if test x"${TARGET_SESSION:-}" = x; then
  TARGET_SESSION=config/bench/lava/target-session
  if test x"${TARGET_CONFIG}" = xmustang; then
    TARGET_SESSION="${TARGET_SESSION}.yaml"
    TARGET_DEPLOY_ACTION="${TARGET_DEPLOY_ACTION:-deploy_linaro_kernel}"
  else
    TARGET_SESSION="${TARGET_SESSION}-tools.yaml"
    TARGET_DEPLOY_ACTION="${TARGET_DEPLOY_ACTION:-deploy_linaro_image}"
  fi
fi
#guarantee that TARGET_DEPLOY_ACTION is set
TARGET_DEPLOY_ACTION="${TARGET_DEPLOY_ACTION:-deploy_linaro_image}"

LAVA_USER="${LAVA_USER:-${USER}}"

#TODO Add consistency tests
#For example, setting compiler/make flags makes no sense if prebuilt is set

#Parameters to be substituted into template
output_value JOB_NAME "${BENCHMARK}-${LAVA_USER}"
output_value BENCHMARK "${BENCHMARK:?BENCHMARK must be set}"

#By the time these parameters reach LAVA, None means unset
#Unset is not necessarily the same as empty string - for example,
#COMPILER_FLAGS="" may result in overriding default flags in makefiles
output_value TOOLCHAIN "${TOOLCHAIN:-None}"
output_value TRIPLE "${TRIPLE:-None}"
output_value SYSROOT "${SYSROOT:-None}"
output_value RUN_FLAGS "${RUN_FLAGS:-None}"
output_value COMPILER_FLAGS "${COMPILER_FLAGS:-None}"
output_value MAKE_FLAGS "${MAKE_FLAGS:-None}"
output_value PREBUILT "${PREBUILT:-None}"

output_value HOST_SESSION "${HOST_SESSION}"
output_slot HOST_DEPLOY_ACTION "${HOST_DEPLOY_ACTION}"
output_slot HOST_IMAGE_1 "${image_map_1[${HOST_DEVICE_TYPE}]}"
output_slot HOST_IMAGE_2 "${image_map_2[${HOST_DEVICE_TYPE}]:-}"
output_slot HOST_IMAGE_3 "${image_map_3[${HOST_DEVICE_TYPE}]:-}"
output_value HOST_DEVICE_TYPE "${HOST_DEVICE_TYPE}"
output_value TARGET_SESSION "${TARGET_SESSION}"
output_slot TARGET_DEPLOY_ACTION "${TARGET_DEPLOY_ACTION}"
output_slot TARGET_IMAGE_1 "${image_map_1[${TARGET_DEVICE_TYPE}]}"
output_slot TARGET_IMAGE_2 "${image_map_2[${TARGET_DEVICE_TYPE}]:-}"
output_slot TARGET_IMAGE_3 "${image_map_3[${TARGET_DEVICE_TYPE}]:-}"
output_value TARGET_CONFIG "${TARGET_CONFIG}"
output_value TARGET_DEVICE_TYPE "${TARGET_DEVICE_TYPE}"
output_value BUNDLE_SERVER "https://${LAVA_SERVER}"
output_value BUNDLE_STREAM "${BUNDLE_STREAM:-/private/personal/${LAVA_USER}/}"
output_value TESTDEF_REPO "https://git.linaro.org/toolchain/abe"
output_value TESTDEF_REVISION "${TESTDEF_REVISION:-benchmarking}"
#TODO Map this? Depend on benchmark and target.
output_value TIMEOUT ${TIMEOUT:-5400}
output_value PUBLIC_KEY "${PUBLIC_KEY:-}"
#End of parameters to substitute into template
