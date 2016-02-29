#!/bin/bash

abe_dir="${abe_dir:-`dirname $0`/../..}"
${abe_dir}/scripts/dispatch-benchmark.py --dry-yaml \
  --lava-server validation.linaro.org/RPC2/ \
  --lava-user fred.implausible \
  --benchmark fakebench \
  --target-config arndale \
                  juno-a53 \
                  juno-a57 \
                  kvm \
                  kvm \
                  mustang \
                  panda-es \
  --triple native \
  --toolchain /usr/bin/gcc \
  --bundle-stream /anonymous/fred.implausible/ \
  PUBLIC_KEY=a_very_public_key
