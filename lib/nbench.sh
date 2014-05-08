
nbench_init()
{
  _nbench_init=true
  NBENCH_SUITE=nbench
  NBENCH_BENCH_RUNS="`grep ^BENCH_RUNS:= ${topdir}/config/nbench.conf \
    | awk -F":=" '{print $2}'`"
  NBENCH_VCFLAGS="`grep ^VCFLAGS:= ${topdir}/config/nbench.conf \
    | awk -F":=" '{print $2}'`"
  NBENCH_BUILD_LOG="`grep ^BUILD_LOG:= ${topdir}/config/nbench.conf \
    | awk -F":=" '{print $2}'`"
  NBENCH_RUN_LOG="`grep ^RUN_LOG:= ${topdir}/config/nbench.conf \
    | awk -F":=" '{print $2}'`"
  NBENCH_TARBALL="`grep ^TARBALL:= ${topdir}/config/nbench.conf \
    | awk -F":=" '{print $2}'`"

  if test "x$NBENCH_BENCH_RUNS" = x; then
    NBENCH_BENCH_RUNS=1
  fi
  if test "x$NBENCH_BUILD_LOG" = x; then
    NBENCH_BUILD_LOG=nbench_build_log.txt
  fi
  if test "x$NBENCH_RUN_LOG" = x; then
    NBENCH_RUN_LOG=nbench_run_log.txt
  fi
  if test "x$NBENCH_TARBALL" = x; then
    error "TARBALL not defined in nbench.conf"
    return 1
  fi
  NBENCH_VCFLAGS="-O2 -static $NBENCH_VCFLAGS $XCFLAGS"
  return 0
}


nbench_run ()
{
  for i in $(seq 1 $NBENCH_BENCH_RUNS); do
    pushd $NBENCH_SUITE/nbench*
    ./nbench >> $NBENCH_RUN_LOG 2>&1;
  done
}

nbench_build ()
{
  echo CFLAGS=$NBENCH_VCFLAGS > $NBENCH_BUILD_LOG
  make -k -C $NBENCH_SUITE/nbench-* CFLAGS="$NBENCH_VCFLAGS" > $NBENCH_BUILD_LOG 2>&1
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
  rm -rf $NBENCH_SUITE
  mkdir -p $NBENCH_SUITE
  check_pattern "$SRC_PATH/$NBENCH_TARBALL*.tar.*z"
  get_benchmark  $SRC_PATH/$NBENCH_TARBALL*.tar.*z $NBENCH_SUITE
  tar xaf $NBENCH_SUITE/$NBENCH_TARBALL*.tar.*z -C $NBENCH_SUITE
  rm $SRC_PATH/$NBENCH_TARBALL*.tar.*z
  #cat $(TOPDIR)/files/$(SUITE)/*.patch | patch -p1 -d $(VBUILD)/$(SUITE)-*
}


