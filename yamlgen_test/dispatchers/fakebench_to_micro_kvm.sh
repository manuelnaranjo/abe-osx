#!/bin/bash

abe_dir="${abe_dir:-$PWD/`dirname $0`/../..}"
${abe_dir}/scripts/dispatch-benchmark.py --dry-yaml \
  --lava-server lava.tcwglab/RPC2/ \
  --lava-user fred.implausible \
  --benchmark fakebench \
  --target-config kvm \
  --triple native \
  --toolchain /usr/bin/gcc \
  --bundle-stream /anonymous/fred.implausible/ \
  -- \
  PUBLIC_KEY="`cat ~/.ssh/id_linaro.pub`"
