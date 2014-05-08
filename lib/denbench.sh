
denbench_init()
{
  _denbench_init=true
  DENBENCH_SUITE=denbench
  DENBENCH_BENCH_RUNS="`grep ^BENCH_RUNS:= ${topdir}/config/denbench.conf \
    | awk -F":=" '{print $2}'`"
  DENBENCH_VCFLAGS="`grep ^VFLAGS:= ${topdir}/config/denbench.conf \
    | awk -F":=" '{print $2}'`"
  DENBENCH_BUILD_LOG="`grep ^BUILD_LOG:= ${topdir}/config/denbench.conf \
    | awk -F":=" '{print $2}'`"
  DENBENCH_RUN_LOG="`grep ^RUN_LOG:= ${topdir}/config/denbench.conf \
    | awk -F":=" '{print $2}'`"
  DENBENCH_TARBALL="`grep ^TARBALL:= ${topdir}/config/denbench.conf \
    | awk -F":=" '{print $2}'`"

  if test "x$DENBENCH_BENCH_RUNS" = x; then
    DENBENCH_BENCH_RUNS=1
  fi
  if test "x$DENBENCH_BUILD_LOG" = x; then
    DENBENCH_BUILD_LOG=denbench_build_log.txt
  fi
  if test "x$DENBENCH_RUN_LOG" = x; then
    DENBENCH_RUN_LOG=denbench_run_log.txt
  fi
  if test "x$DENBENCH_TARBALL" = x; then
    error "TARBALL not defined in denbench.conf"
    return 1
  fi
  return 0
}

denbench_run ()
{
  echo "denbench run"
  echo "Note: All results are estimates." >> $DENBENCH_RUN_LOG
  for i in $(seq 1 $DENBENCH_BENCH_RUNS); do
    echo -e \\nRun $i:: >> $DENBENCH_RUN_LOG
    make -C $DENBENCH_SUITE/* -s rerun >> $DENBENCH_RUN_LOG
    cat $DENBENCH_SUITE/denbench*/consumer/*timev2.log >> $DENBENCH_RUN_LOG
  done
}

denbench_build ()
{
  echo VCFLAGS=$VCFLAGS >> $DENBENCH_BUILD_LOG 2>&1
  make -C $DENBENCH_SUITE/* COMPILER_FLAGS=$DENBENCH_VCFLAGS build >> $DENBENCH_BUILD_LOG 2>&1
}

denbench_clean ()
{
  echo "denbench clean"
}


denbench_build_with_pgo ()
{
  echo "denbench build with pgo"
}

denbench_install ()
{
  echo "denbench install"
}

denbench_testsuite ()
{
  echo "denbench testsuite"
}

denbench_extract ()
{
  rm -rf $DENBENCH_SUITE
  mkdir -p $DENBENCH_SUITE
  check_pattern "$SRC_PATH/$DENBENCH_TARBALL*.cpt"
  get_benchmark  "$SRC_PATH/$DENBENCH_TARBALL*.cpt" $DENBENCH_SUITE
  $CCAT $DENBENCH_SUITE/$DENBENCH_TARBALL*.cpt | tar xjf - -C $DENBENCH_SUITE
  rm -f $DENBENCH_SUITE/$DENBENCH_TARBALL*.cpt
}


