
gmpbench_init()
{
  _gmpbench_init=true
  GMPBENCH_SUITE=gmpbench
  GMPBENCH_BENCH_RUNS="`grep ^BENCH_RUNS= ${topdir}/config/gmpbench.conf \
    | cut -d '=' -f 2`"
  GMPBENCH_VCFLAGS="`grep ^VFLAGS= ${topdir}/config/gmpbench.conf \
    | cut -d '=' -f 2`"
  GMPBENCH_PARALEL="`grep ^PARELLEL= ${topdir}/config/gmpbench.conf \
    | cut -d '=' -f 2`"
  GMPBENCH_BUILD_LOG="`grep ^BUILD_LOG= ${topdir}/config/gmpbench.conf \
    | cut -d '=' -f 2`"
  GMPBENCH_RUN_LOG="`grep ^RUN_LOG= ${topdir}/config/gmpbench.conf \
    | cut -d '=' -f 2`"
  GMPBENCH_TARBALL="`grep ^TARBALL= ${topdir}/config/gmpbench.conf \
    | cut -d '=' -f 2`"

  if test "x$GMPBENCH_BENCH_RUNS" = x; then
    GMPBENCH_BENCH_RUNS=1
  fi
  if test "x$GMPBENCH_PARALLEL" = x; then
    GMPBENCH_PARALLEL=1
  fi
  if test "x$GMPBENCH_BUILD_LOG" = x; then
    GMPBENCH_BUILD_LOG=gmpbench_build_log.txt
  fi
  if test "x$GMPBENCH_RUN_LOG" = x; then
    GMPBENCH_RUN_LOG=gmpbench_run_log.txt
  fi
  if test "x$GMPBENCH_TARBALL" = x; then
    error "TARBALL not defined in gmpbench.conf"
    exit
  fi
}

gmpbench_run ()
{
  PATH=$PWD:$PATH
  ABI=$ABI
  CFLAGS="$GMPBENCH_VCFLAGS"
  pushd $GMPBENCH_SUITE/gmp*
  ./runbench >> $GMPBENCH_RUN_LOG 2>&1
  popd
}

gmpbench_build ()
{
  echo "gmpbench build"
  echo $CONFIGURE_FLAGS > $GMPBENCH_BUILD_LOG
  echo CFLAGS=$GMPBENCH_VCFLAGS >> $GMPBENCH_BUILD_LOG
  check_pattern "$SRC_PATH/gexpr.c"
  get_becnhmark  "$SRC_PATH/gexpr.c" $GMPBENCH_SUITE
  gcc -o $GMPBENCH_SUITE/gexpr $GMPBENCH_SUITE/gexpr.c -lm
}

gmpbench_clean ()
{
  echo "gmpbench clean"
}


gmpbench_build_with_pgo ()
{
  echo "gmpbench build with pgo"
}

gmpbench_install ()
{
  echo "gmpbench install"
}

gmpbench_testsuite ()
{
  echo "gmpbench testsuite"
}

gmpbench_extract ()
{
  rm -rf $GMPBENCH_SUITE
  mkdir -p $GMPBENCH_SUITE
  check_pattern "$SRC_PATH/$GMPBENCH_TARBALL*.tar.bz2"
  get_becnhmark  "$SRC_PATH/$GMPBENCH_TARBALL*.tar.bz2" $GMPBENCH_SUITE
  tar xaf $GMPBENCH_SUITE/$GMPBENCH_TARBALL*.tar.bz2 -C $GMPBENCH_SUITE
  rm -f $GMPBENCH_SUITE/$GMPBENCH_TARBALL*.tar.bz2
}


