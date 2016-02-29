#!/bin/bash

abe_dir="${abe_dir:-$PWD/`dirname $0`/../..}"
${abe_dir}/scripts/dispatch-benchmark.py --dry-yaml \
  --lava-server lava.tcwglab/RPC2/ \
  --lava-user fred.implausible \
  --benchmark CPU2006 \
  --target-config juno-a57 \
  --triple aarch64-linux-gnu \
  --prebuilt fred.implausible@148.251.136.42:benchsrc/a64/CPU2006.git.tar.xz \
  --run-flags='-n 1 --size test' \
  --bundle-stream /anonymous/fred.implausible2/ \
  -- \
  PUBLIC_KEY="`cat ~/.ssh/id_linaro.pub`" \
  TIMEOUT=$((96*3600))
