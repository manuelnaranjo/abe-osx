
libavbench_init()
{
  _libavbench_init=true
  LIBAVBENCH_SUITE=libavbench
  LBUILD=$LIBAVBENCH_SUITE/$LIBAVBENCH_SUITE

  LIBAVBENCH_LIBAVBENCH_SUITE="`grep ^VBUILD:= ${topdir}/config/libavbench.conf \
    | awk -F":=" '{print $2}'`"
  LIBAVBENCH_LIBAVBENCH_SUITE="`grep ^SUITE:= ${topdir}/config/libavbench.conf \
    | awk -F":=" '{print $2}'`"
  LIBAVBENCH_BENCH_RUNS="`grep ^BENCH_RUNS:= ${topdir}/config/libavbench.conf \
    | awk -F":=" '{print $2}'`"
  LIBAVBENCH_VCFLAGS="`grep ^VCFLAGS:= ${topdir}/config/libavbench.conf \
    | awk -F":=" '{print $2}'`"
  LIBAVBENCH_BUILD_LOG="`grep ^BUILD_LOG:= ${topdir}/config/libavbench.conf \
    | awk -F":=" '{print $2}'`"
  LIBAVBENCH_RUN_LOG="`grep ^RUN_LOG:= ${topdir}/config/libavbench.conf \
    | awk -F":=" '{print $2}'`"
  LIBAVBENCH_TARBALL="`grep ^TARBALL:= ${topdir}/config/libavbench.conf \
    | awk -F":=" '{print $2}'`"

  if test "x$LIBAVBENCH_BENCH_RUNS" = x; then
    LIBAVBENCH_BENCH_RUNS=1
  fi
  if test "x$LIBAVBENCH_BUILD_LOG" = x; then
    LIBAVBENCH_BUILD_LOG=libavbench_build_log.txt
  fi
  if test "x$LIBAVBENCH_RUN_LOG" = x; then
    LIBAVBENCH_RUN_LOG=libavbench_run_log.txt
  fi
  if test "x$LIBAVBENCH_TARBALL" = x; then
    error "TARBALL not defined in libavbench.conf"
    exit
  fi
}

libavbench_run ()
{
  for f in $LBUILD/libavbench-data*/*; do
    echo >> $LIBAVBENCH_RUN_LOG;
    echo `basename $f`:: >> $LIBAVBENCH_RUN_LOG;
    cat $f > /dev/null;
    for i in $(seq 1 $LIBAVBENCH_BENCH_RUNS); do
      echo "time -o -a $LIBAVBENCH_RUN_LOG -a $LIBAVBENCH_SUITE/install/bin/ffmpeg -benchmark \
      -loglevel quiet -i $f -f null -y /dev/null > $LIBAVBENCH_SUITE/benchmark.tmp"
      time -o -a $LIBAVBENCH_RUN_LOG -a $LIBAVBENCH_SUITE/install/bin/ffmpeg -benchmark \
      -loglevel quiet -i $f -f null -y /dev/null > $LIBAVBENCH_SUITE/benchmark.tmp
      cat $LIBAVBENCH_SUITE/benchmark.tmp >> $LIBAVBENCH_RUN_LOG
    done
  done
}

libavbench_build ()
{
  make -C $LIBAVBENCH_SUITE/build/ >> $LIBAVBENCH_BUILD_LOG 2>&1
  make -C $LIBAVBENCH_SUITE/build/ install>> $LIBAVBENCH_BUILD_LOG 2>&1
}

libavbench_clean ()
{
  echo "libavbench clean"
}


libavbench_build_with_pgo ()
{
  echo "libavbench build with pgo"
}

libavbench_install ()
{
  echo "libavbench install"

}

libavbench_testsuite ()
{
  echo "libavbench testsuite"
}

libavbench_extract ()
{
  rm -rf $LIBAVBENCH_SUITE
  mkdir -p $LIBAVBENCH_SUITE
  check_pattern "$SRC_PATH/$LIBAVBENCH_TARBALL*.tar.xz"
  get_becnhmark "$SRC_PATH/$LIBAVBENCH_TARBALL*.tar.xz" $LIBAVBENCH_SUITE
  tar xaf $LIBAVBENCH_SUITE/$LIBAVBENCH_TARBALL*.tar.xz -C $LIBAVBENCH_SUITE
  rm -f $LIBAVBENCH_SUITE/$LIBAVBENCH_TARBALL*.tar.xz

  echo $CONFIGURE_FLAGS >> $LIBAVBENCH_BUILD_LOG
  mkdir -p $LIBAVBENCH_SUITE/build
  pushd $LIBAVBENCH_SUITE/build
  ../libav*/configure --prefix=$PWD/../install $CONFIGURE_FLAGS  >> $LIBAVBENCH_BUILD_LOG 2>&1
  popd
  # Strip out any unwanted default flags
  for i in $REMOVE_CFLAGS; do
    sed -i~ s#$i## $LIBAVBENCH_SUITE/build/config.mak;
  done
  grep FLAGS $LIBAVBENCH_SUITE/build/config.mak >> $LIBAVBENCH_BUILD_LOG
}


