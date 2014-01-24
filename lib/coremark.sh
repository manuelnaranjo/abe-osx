
coremark_init()
{
  coremark_init=true
  COREMARK_SUITE=coremark

  COREMARK_BENCH_RUNS="`grep ^BENCH_RUNS:= ${topdir}/config/coremark.conf \
    | awk -F":=" '{print $2}'`"
  COREMARK_VCFLAGS="`grep ^VCFLAGS:= ${topdir}/config/coremark.conf \
    | awk -F":=" '{print $2}'`"
  COREMARK_XCFLAGS="`grep ^XCFLAGS:= ${topdir}/config/coremark.conf \
    | awk -F":=" '{print $2}'`"
  COREMARK_BUILD_LOG="`grep ^BUILD_LOG:= ${topdir}/config/coremark.conf \
    | awk -F":=" '{print $2}'`"
  COREMARK_RUN_LOG="`grep ^RUN_LOG:= ${topdir}/config/coremark.conf \
    | awk -F":=" '{print $2}'`"
  COREMARK_TARBALL="`grep ^TARBALL:= ${topdir}/config/coremark.conf \
    | awk -F":=" '{print $2}'`"

  if test "x$COREMARK_BENCH_RUNS" = x; then
    COREMARK_BENCH_RUNS=1
  fi
  if test "x$COREMARK_BUILD_LOG" = x; then
    COREMARK_BUILD_LOG=coremark_build_log.txt
  fi
  if test "x$COREMARK_RUN_LOG" = x; then
    COREMARK_RUN_LOG=coremark_run_log.txt
  fi
  if test "x$COREMARK_TARBALL" = x; then
    error "TARBALL not defined in coremark.conf"
    exit
  fi

  COREMARK_XCFLAGS="$COREMARK_XCFLAGS $XCFLAGS"
}

coremark_run ()
{
  local COREMARK=`ls coremark`
  echo "Note: All results are estimates." >> $COREMARK_RUN_LOG
  for i in $(seq 1 $COREMARK_BENCH_RUNS)
  do
    echo  "\nRun $i::" >> $COREMARK_RUN_LOG
    echo "make -C $COREMARK_SUITE/$COREMARK -s rerun UNAME=`uname`"
    make -C $COREMARK_SUITE/$COREMARK -s rerun UNAME=`uname`
    cat $COREMARK_SUITE/$COREMARK/*.log >> $COREMARK_RUN_LOG
  done
}

coremark_clean()
{
  local COREMARK=`ls coremark`
  make -C $COREMARK_SUITE/$COREMARK -s clean UNAME=`uname`
}

coremark_build_with_pgo ()
{
  echo PORT_CFLAGS=$COREMARK_VCFLAGS >> $COREMARK_BUILD_LOG
  echo XCFLAGS=$COREMARK_XCFLAGS >> $COREMARK_BUILD_LOG
  local COREMARK=`ls coremark`
  # readme.txt sets what the training run should be
  make -C $COREMARK_SUITE/$COREMARK $PARALLEL run3.log REBUILD=1 \
    UNAME=`uname` PORT_CFLAGS="$COREMARK_VCFLAGS" XCFLAGS="$COREMARK_XCFLAGS -fprofile-generate \
    -DTOTAL_DATA_SIZE=1200 -DPROFILE_RUN=1" >> $COREMARK_BUILD_LOG 2>&1
  make -C $COREMARK_SUITE/$COREMARK -s clean UNAME=`uname`
  make -C $COREMARK_SUITE/$COREMARK $PARALLEL load UNAME=`uname`\
    PORT_CFLAGS="$COREMARK_VCFLAGS" XCFLAGS="$COREMARK_XCFLAGS \
    -fprofile-use" >> $COREMARK_BUILD_LOG 2>&1
}

coremark_build ()
{
  echo PORT_CFLAGS=$COREAMRK_VCFLAGS >> $COREMARK_BUILD_LOG
  echo XCFLAGS=$COREMARK_XCFLAGS >> $COREMARK_BUILD_LOG
  local COREMARK=`ls coremark`
  make -C $COREMARK_SUITE/$COREMARK -s clean UNAME=`uname`
  make -C $COREMARK_SUITE/$COREMARK $PARALLEL load UNAME=`uname` \
    PORT_CFLAGS="$COREMARK_VCFLAGS" XCFLAGS="$COREMARK_XCFLAGS" >> $COREMARK_BUILD_LOG 2>&1
}


coremark_install ()
{
  echo "FIXME: Implement it"
}

coremark_testsuite ()
{
  echo "FIXME: Implement it"
}

coremark_extract ()
{
  rm -rf $COREMARK_SUITE
  mkdir -p $COREMARK_SUITE
  check_pattern "$SRC_PATH/$COREMARK_TARBALL*.cpt"
  get_becnhmark  "$SRC_PATH/$COREMARK_TARBALL*.cpt" $COREMARK_SUITE
  $CCAT $COREMARK_SUITE/$COREMARK_TARBALL*.cpt | gunzip | tar xaf - -C $COREMARK_SUITE
  rm $COREMARK_SUITE/$COREMARK_TARBALL*.cpt
}


