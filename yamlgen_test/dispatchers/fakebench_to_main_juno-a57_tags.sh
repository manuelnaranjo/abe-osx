#!/bin/bash

abe_dir="${abe_dir:-$PWD/`dirname $0`/../..}"
${abe_dir}/scripts/dispatch-benchmark.py --dry-yaml \
  --lava-server validation.linaro.org/RPC2/ \
  --lava-user fred.implausible \
  --benchmark fakebench \
  --target-config juno-a57 \
  --triple native \
  --toolchain /usr/bin/gcc \
  --bundle-stream /private/personal/fred.implausible/ \
  --tags host:tcwg juno-a57:armv8 \
  -- \
  PUBLIC_KEY="`cat ~/.ssh/id_linaro.pub`"
