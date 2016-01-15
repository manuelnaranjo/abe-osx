#!/bin/bash
set -eu
set -o pipefail

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

#Output parameter, escaping single quotes from YAML
function output_param {
  echo $1="${2//\'/\'\'}"
}

#Parameters to be substituted into template
output_param JOB_NAME "${BENCHMARK}-${LAVA_USER}"
output_param BENCHMARK "${BENCHMARK:?BENCHMARK must be set}"

#By the time these parameters reach LAVA, None means unset
#Unset is not necessarily the same as empty string - for example,
#COMPILER_FLAGS="" may result in overriding default flags in makefiles
output_param TOOLCHAIN "${TOOLCHAIN:-None}"
output_param TRIPLE "${TRIPLE:-None}"
output_param SYSROOT "${SYSROOT:-None}"
output_param RUN_FLAGS "${RUN_FLAGS:-None}"
output_param COMPILER_FLAGS "${COMPILER_FLAGS:-None}"
output_param MAKE_FLAGS "${MAKE_FLAGS:-None}"
output_param PREBUILT "${PREBUILT:-None}"

output_param HOST_SESSION "config/bench/lava/host-session-multilib.yaml"
output_param HOST_IMAGE "http://images.validation.linaro.org/ubuntu-14-04-server-base.img.gz"
output_param TARGET_SESSION "${TARGET_SESSION}"
output_param TARGET_DEPLOY_ACTION "${TARGET_DEPLOY_ACTION}"
output_param TARGET_IMAGE_1 "${image_map_1[${TARGET_DEVICE_TYPE}]}"
output_param TARGET_IMAGE_2 "${image_map_2[${TARGET_DEVICE_TYPE}]:-}"
output_param TARGET_IMAGE_3 "${image_map_3[${TARGET_DEVICE_TYPE}]:-}"
output_param TARGET_CONFIG "${TARGET_CONFIG}"
output_param TARGET_DEVICE_TYPE "${TARGET_DEVICE_TYPE}"
output_param BUNDLE_SERVER "https://${LAVA_SERVER}"
output_param BUNDLE_STREAM "${BUNDLE_STREAM:-/private/personal/${LAVA_USER}/}"
output_param TESTDEF_REPO "https://git.linaro.org/toolchain/abe"
output_param TESTDEF_REVISION "${TESTDEF_REVISION:-benchmarking}"
#TODO Map this? Depend on benchmark and target.
output_param TIMEOUT ${TIMEOUT:-5400}
output_param PUBLIC_KEY "${PUBLIC_KEY:-}"
#End of parameters to substitute into template
