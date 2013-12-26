
# Number of iterations for each sub-benchmark.  Calibrated so that
# each run takes about 10 s on a Cortex-A9
fps_bitmap_565_scale=200
fps_bitmap_565_noscale=200
fps_bitmap_X888_scale=340
fps_bitmap_X888_noscale=300
fps_bitmap_8888_scale=200
fps_bitmap_8888_noscale=180
fps_blend=700
fps_fill=4800
repeatTile_index8=14
repeatTile_4444=12
repeatTile_565=14
repeatTile_8888=14
bitmap_index8=6
bitmap_index8_A=10
bitmap_4444=6
bitmap_4444_A=10
bitmap_565=10
bitmap_8888=6
bitmap_8888_A=10
polygon=20
lines=80
points=240
rrects3=140
rrects1=40
ovals3=160
ovals1=50
rects3=80
rects1=20

# Names of all of the sub-benchmarks
ALL_NAMES='fps_bitmap_565_scale fps_bitmap_565_noscale fps_bitmap_X888_scale \
	fps_bitmap_X888_noscale fps_bitmap_8888_scale fps_bitmap_8888_noscale \
	fps_blend fps_fill repeatTile_index8 \
	repeatTile_4444 repeatTile_565 repeatTile_8888 \
	bitmap_index8 bitmap_index8_A bitmap_4444 \
	bitmap_4444_A bitmap_565 bitmap_8888 \
	bitmap_8888_A polygon lines \
	points rrects3 rrects1 \
	ovals3 ovals1 rects3 \
	rects1'


skiabench_init()
{
  _skiabench_init=true
  SKIABENCH_SUITE=skiabench

  SKIABENCH_SKIABENCH_SUITE="`grep ^SKIABENCH_SUITE:= ${topdir}/config/skiabench.conf \
    | awk -F":=" '{print $2}'`"
  SKIABENCH_RUNS="`grep ^BENCH_RUNS:= ${topdir}/config/skiabench.conf \
    | awk -F":=" '{print $2}'`"
  SKIABENCH_VCFLAGS="`grep ^VCFLAGS:= ${topdir}/config/skiabench.conf \
    | awk -F":=" '{print $2}'`"
  SKIABENCH_BUILD_LOG="`grep ^BUILD_LOG:= ${topdir}/config/skiabench.conf \
    | awk -F":=" '{print $2}'`"
  SKIABENCH_RUN_LOG="`grep ^RUN_LOG:= ${topdir}/config/skiabench.conf \
    | awk -F":=" '{print $2}'`"
  SKIABENCH_TARBALL="`grep ^TARBALL:= ${topdir}/config/skiabench.conf \
    | awk -F":=" '{print $2}'`"

  if test "x$SKIABENCH_BENCH_RUNS" = x; then
    SKIABENCH_BENCH_RUNS=1
  fi
  if test "x$SKIABENCH_BUILD_LOG" = x; then
    SKIABENCH_BUILD_LOG=skiabench_build_log.txt
  fi
  if test "x$SKIABENCH_RUN_LOG" = x; then
    SKIABENCH_RUN_LOG=skiabench_run_log.txt
  fi
  if test "x$SKIABENCH_TARBALL" = x; then
    error "TARBALL not defined in skiabench.conf"
    exit
  fi
}

skiabench_run ()
{
  echo "skiabench run"
  for i in $(seq 1 $SKIABENCH_RUNS); do
    echo Run $i:: >> $SKIABENCH_RUN_LOG;
    for j in $ALL_NAMES; do
      echo $j >> $SKIABENCH_RUN_LOG;
      $TIME -o $SKIABENCH_RUN_LOG -a $SKIABENCH_SUITE/skia-*/out/bench/bench $RUN_FLAGS -repeat "$`echo $j`" -match $j
    done
  done
}

skiabench_clean()
{
  echo "skiabench clean"
}

skiabench_build_with_pgo ()
{
  echo "skiabench build with pgo"
}

skiabench_build ()
{
  echo "skiabench build"
  make -s -j $SKIABENCH_PARALLEL -C $SKIABENCH_SUITE/skia-* CFLAGS="$SKIABENCH_VCFLAGS" bench > $SKIABENCH_BUILD_LOG 2>&1
}


skiabench_install ()
{
  echo "skiabench install"
  ln -s $PWD/$SKIABENCH_SUITE/skia-*/out $SKIABENCH_SUITE/install
}

skiabench_testsuite ()
{
  echo "skiabench testsuite"
}

skiabench_extract ()
{
  rm -rf $SKIABENCH_SUITE
  mkdir -p $SKIABENCH_SUITE
  check_pattern "$SRC_PATH/$SKIABENCH_TARBALL*.tar.xz"
  get_becnhmark "$SRC_PATH/$SKIABENCH_TARBALL*.tar.xz" $SKIABENCH_SUITE
  tar xaf $SKIABENCH_SUITE/$SKIABENCH_TARBALL*.tar.xz -C $SKIABENCH_SUITE
  rm -f $SKIABENCH_SUITE/$SKIABENCH_TARBALL*.tar.xz
  local SRCDIR=`ls $SKIABENCH_SUITE`
  sed -e s#gcc#g\+\+#g < $SKIABENCH_SUITE/$SRCDIR/Makefile > $SKIABENCH_SUITE/$SRCDIR/Makefile.new
  mv $SKIABENCH_SUITE/$SRCDIR/Makefile.new $SKIABENCH_SUITE/$SRCDIR/Makefile
}


