
gnugo_init()
{
  _gnugo_init=true
  GNUGO_SUITE=gnugo

  GNUGO_BENCH_RUNS="`grep ^BENCH_RUNS:= ${topdir}/config/gnugo.conf \
    | awk -F":=" '{print $2}'`"
  GNUGO_VCFLAGS="`grep ^VFLAGS:= ${topdir}/config/gnugo.conf \
    | awk -F":=" '{print $2}'`"
  GNUGO_BUILD_LOG="`grep ^BUILD_LOG:= ${topdir}/config/gnugo.conf \
    | awk -F":=" '{print $2}'`"
  GNUGO_RUN_LOG="`grep ^RUN_LOG:= ${topdir}/config/gnugo.conf \
    | awk -F":=" '{print $2}'`"
  GNUGO_TARBALL="`grep ^TARBALL:= ${topdir}/config/gnugo.conf \
    | awk -F":=" '{print $2}'`"

  if test "x$GNUGO_BENCH_RUNS" = x; then
    GNUGO_BENCH_RUNS=1
  fi
  if test "x$GNUGO_BUILD_LOG" = x; then
    GNUGO_BUILD_LOG=gnugo_build_log.txt
  fi
  if test "x$GNUGO_RUN_LOG" = x; then
    GNUGO_RUN_LOG=gnugo_run_log.txt
  fi
  if test "x$GNUGO_TARBALL" = x; then
    error "TARBALL not defined in gnugo.conf"
    return 1
  fi
  GNUGO_VCFLAGS="-O2 $GNUGO_VCFLAGS $XCFLAGS"
  return 0
}

gnugo_run ()
{
  echo "gnugo run"
  pushd $GNUGO_SUITE/gnugo-*/regression
  for i in $(seq 1 $GNUGO_BENCH_RUNS); do
    echo -e \\nRun $i:: >> $GNUGO_RUN_LOG;
    $TIME -o ../../../$GNUGO_RUN_LOG -a ../../../$GNUGO_SUITE/install/bin/gnugo --quiet --mode gtp\
      --gtp-input viking.tst;
  done
  popd
}

gnugo_build ()
{
  echo "gnugo build"
  mkdir -p $GNUGO_SUITE/build
  pushd $GNUGO_SUITE/build
  CFLAGS="$GNUGO_VCFLAGS" LDFLAGS="$XLFLAGS" ../gnugo-*/configure --prefix=$PWD/../install >> $GNUGO_BUILD_LOG 2>&1
  make >> ../../$GNUGO_BUILD_LOG 2>&1
  make install >> ../../$GNUGO_BUILD_LOG 2>&1
  popd
}

gnugo_clean ()
{
  echo "gnugo clean"
}


gnugo_build_with_pgo ()
{
  echo "gnugo build with pgo"
}

gnugo_install ()
{
  echo "gnugo install"
}

gnugo_testsuite ()
{
  echo "gnugo testsuite"
}

gnugo_extract ()
{
  echo "gnugo extract"
  rm -rf $GNUGO_SUITE
  mkdir -p $GNUGO_SUITE
  check_pattern "$SRC_PATH/$GNUGO_TARBALL*.tar.gz"
  get_becnhmark  "$SRC_PATH/$GNUGO_TARBALL*.tar.gz" $GNUGO_SUITE
  tar xaf $GNUGO_SUITE/$GNUGO_TARBALL*.tar.gz -C $GNUGO_SUITE
  rm -f $GNUGO_SUITE/$GNUGO_TARBALL*.tar.gz
}


