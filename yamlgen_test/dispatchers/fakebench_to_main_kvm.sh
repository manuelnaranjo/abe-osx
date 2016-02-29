#!/bin/bash

abe_dir="${abe_dir:-$PWD/`dirname $0`/../..}"
${abe_dir}/scripts/dispatch-benchmark.py --dry-yaml \
  --lava-server validation.linaro.org/RPC2/ \
  --lava-user fred.implausible \
  --benchmark fakebench \
  --target-config brian:kvm \
  --triple native \
  --toolchain /usr/bin/gcc \
  --bundle-stream /private/personal/fred.implausible/ \
  --tags fred \
  -- \
  PUBLIC_KEY="`cat ~/.ssh/id_linaro.pub`"
