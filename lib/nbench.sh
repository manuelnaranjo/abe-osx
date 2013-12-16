

#!/bin/sh

init=false
NBENCH_VBUILD="`grep ^VBUILD= ${topdir}/config/nbench.conf \
  | cut -d '=' -f 2`"
NBENCH_SUITE="`grep ^SUITE= ${topdir}/config/nbench.conf \
  | cut -d '=' -f 2`"
NBENCH_BENCH_RUNS="`grep ^BENCH_RUNS= ${topdir}/config/nbench.conf \
  | cut -d '=' -f 2`"
NBENCH_VCFLAGS="`grep ^VFLAGS= ${topdir}/config/nbench.conf \
  | cut -d '=' -f 2`"
NBENCH_PARALEL="`grep ^PARELLEL= ${topdir}/config/nbench.conf \
  | cut -d '=' -f 2`"
NBENCH_PASSWOD_FILE="`grep ^PASSWORD_FILE= ${topdir}/config/nbench.conf \
  | cut -d '=' -f 2`"
NBENCH_CCAT="`grep ^CCAT= ${topdir}/config/nbench.conf \
  | cut -d '=' -f 2`"
NBENCH_BUILD_LOG="`grep ^BUILD_LOG= ${topdir}/config/nbench.conf \
  | cut -d '=' -f 2`"
NBENCH_RUN_LOG="`grep ^RUN_LOG= ${topdir}/config/nbench.conf \
  | cut -d '=' -f 2`"

nbench_init()
{
  init=true
}

nbench_run ()
{
  echo "nbench run"
}

nbench_build ()
{
  echo "nbench build"
}

nbench_clean ()
{
  echo "nbench clean"
}


nbench_build_with_pgo ()
{
  echo "nbench build with pgo"
}

nbench_install ()
{
  echo "nbench install"
}

nbench_testsuite ()
{
  echo "nbench testsuite"
}

nbench_extract ()
{
  echo "nbench extract"
}


