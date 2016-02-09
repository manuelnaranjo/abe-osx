#!/bin/bash
set -eu
set -o pipefail

#Must match up with METADATA_* slots in config/bench/jobdefs files
metadata_index=0 #1 less than lowest slot
metadata_index_max=50 #highest slot

#Output parameter, with no escaping.
#Do not log as metadata.
#Suitable for cases where $2 is itself a chunk of YAML, and there is no
#need to log as metadata.
function output_slot {
  echo $1="$2"
}

function output_metadata {
  local slot
  metadata_index=$((metadata_index + 1))
  if test ${metadata_index} -gt ${metadata_index_max}; then
    echo "Too much metadata." >&2
    echo "Ran out of slots at METADATA_${metadata_index} \"$1: '$2'\"" >&2
    exit 1
  fi
  slot="METADATA_${metadata_index}"
  if test -n "${!slot:-}"; then #If user has defined metadata in this slot, enter the user's metadata
    output_slot "${slot}" "${!slot}"
    output_metadata "$1" "$2" #Try again, until we find a free slot, or run out of slots
  else
    if test -n "${1:-}"; then
      output_slot "${slot}" "$1: '${2:-}'" #Enter this value in this slot
    else
      output_slot "${slot}" "" #Blank out this slot
    fi
  fi
}

#Output parameter, escaping single quotes from YAML.
#Log the parameter as metadata.
#Suitable for cases where $2 is the RHS of a YAML expression in a template.
function output_value {
  echo $1="${2//\'/\'\'}"
  output_metadata "$1" "$2"
}

#Convert board config file into job metadata, outputting any user-specified
#metadata first.
function external_metadata {
  local line
  local name
  local value
  local conf="`dirname $0`/../config/bench/boards/${1,,}.conf"
  if ! test -f "${conf}"; then
    echo "No conf file for '$1'" >&2
    echo "Should have been at '${conf}'" >&2
    exit 1
  fi

  #Output metadata from config file
  while read line; do
    echo "${line}" | grep -q '^[[:blank:]]*#' && continue
    echo "${line}" | grep -q '.=' || continue
    name="`echo ${line} | cut -d = -f 1`"
    value="`echo ${line} | cut -d = -f 2-`"
    output_metadata "${name}" "${value}"
  done < "${conf}"
}

function validate {
  local x ret
  ret=0
  for x in TARGET_CONFIG BENCHMARK; do
    if test -z "${!x:-}"; then
      echo "${x} must be set" >&2
      ret=1
    fi
  done
  if test -n "${PREBUILT:-}"; then
    for x in TOOLCHAIN SYSROOT COMPILER_FLAGS MAKE_FLAGS; do
      if test -n "${!x:-}"; then
        echo "Must not specify $x with PREBUILT" >&2
        ret=1
      fi
    done
  fi
  if test -z "${PREBUILT:-}" &&
     test -z "${TOOLCHAIN:-}"; then
    echo "Exactly one of TOOLCHAIN and PREBUILT must be set" >&2
    ret=1
  fi
  for x in LAVA_SERVER BUNDLE_SERVER; do
    if test -n "${!x:-}"; then
      if echo "${!x}" | grep -q '://'; then
        eval ${x}="${!x/#*:\/\/}"
        echo "${x} must not specify protocol" >&2
        echo "Stripped ${x} to ${!x}" >&2
      fi
      if echo "${!x}" | grep -q '/RPC2$'; then
        eval ${x}="${!x}/"
        echo "${x} must have '/' following /RPC2" >&2
        echo "Added trailing '/' to ${x}" >&2
      elif ! echo "${!x}" | grep -q '/RPC2/$'; then
        eval ${x}="${!x}/RPC2/"
        echo "${x} must end with /RPC2/" >&2
        echo "Added /RPC2/ to ${x}" >&2
      fi
    fi
  done
  if test -n "${BUNDLE_STREAM:-}"; then
    if test "${BUNDLE_STREAM: -1}" != /; then
      BUNDLE_STREAM="${BUNDLE_STREAM}/"
      echo "BUNDLE_STREAM must end with '/'" >&2
      echo "Added '/' to end of BUNDLE_STREAM" >&2
    fi
  fi
  return ${ret}
}

validate #Fails on error due to set -e

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

external_metadata "${TARGET_CONFIG}"
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
output_value JOB_NAME "${JOB_NAME:-${BENCHMARK}-${LAVA_USER}}"
output_value BENCHMARK "${BENCHMARK}" #Known to be set, see validation above

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
output_value BUNDLE_SERVER "https://${BUNDLE_SERVER:-${LAVA_SERVER}}"
output_value BUNDLE_STREAM "${BUNDLE_STREAM:-/private/personal/${LAVA_USER}/}"
output_value TESTDEF_REPO "https://git.linaro.org/toolchain/abe"
output_value TESTDEF_REVISION "${TESTDEF_REVISION:-benchmarking}"
#TODO Map this? Depend on benchmark and target.
output_value TIMEOUT ${TIMEOUT:-5400}
output_value PUBLIC_KEY "${PUBLIC_KEY:-}"
#End of parameters to substitute into template

#Make sure we end up with valid file if there are empty slots
while test ${metadata_index} -lt ${metadata_index_max}; do
  output_metadata ""
done
