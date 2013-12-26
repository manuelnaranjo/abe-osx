
eembc_init()
{
  _eembc_init=true
  EEMBC_SUITE=eembc
  EEMBC_BENCH_RUNS="`grep ^BENCH_RUNS:= ${topdir}/config/eembc.conf \
    | awk -F":=" '{print $2}'`"
  EEMBC_VCFLAGS="`grep ^VFLAGS:= ${topdir}/config/eembc.conf \
    | awk -F":=" '{print $2}'`"
  EEMBC_BUILD_LOG="`grep ^BUILD_LOG:= ${topdir}/config/eembc.conf \
    | awk -F":=" '{print $2}'`"
  EEMBC_RUN_LOG="`grep ^RUN_LOG:= ${topdir}/config/eembc.conf \
    | awk -F":=" '{print $2}'`"
  EEMBC_TARBALL="`grep ^TARBALL:= ${topdir}/config/eembc.conf \
    | awk -F":=" '{print $2}'`"

  if test "x$EEMBC_BENCH_RUNS" = x; then
    EEMBC_BENCH_RUNS=1
  fi
  if test "x$EEMBC_BUILD_LOG" = x; then
    EEMBC_BUILD_LOG=eembc_build_log.txt
  fi
  if test "x$EEMBC_RUN_LOG" = x; then
    EEMBC_RUN_LOG=eembc_run_log.txt
  fi
  if test "x$EEMBC_TARBALL" = x; then
    error "TARBALL not defined in eembc.conf"
    exit
  fi


}

eembc_run ()
{
  echo "Note: All results are estimates." >> $EEMBC_RUN_LOG
  for i in $(seq 1 $BENCH_RUNS); do
    echo -e \\nRun $$i:: >> $EEMBC_RUN_LOG;
    make -C $EEMBC_SUITE/eembc-linaro-* -s rerun $MAKE_EXTRAS >> $EEMBC_RUN_LOG 2>&1;
    cat `find $EEMBC_SUITE -name "gcc_time*.log"` >> $EEMBC_RUN_LOG;
  done
}

eembc_build ()
{
  echo COMPILER_FLAGS=$VCFLAGS >> $EEMBC_BUILD_LOG 2>&1
  make -k $EEMBC_PARALLEL -C $EEMBC_SUITE/eembc* build COMPILER_FLAGS=$EEMBC_VCFLAGS >> $EEMBC_BUILD_LOG 2>&1
}

eembc_clean ()
{
  echo "eembc clean"
}


eembc_build_with_pgo ()
{
  echo "eembc build with pgo"
}

eembc_install ()
{
  rm -rf $EEMBC_SUITE/install
  mkdir $EEMBC_SUITE/install
  pushd $EEMBC_SUITE
  for i in eembc-linaro-*/*; do
    if [ -d $$i/gcc/bin ];
	then ln -fs ../$i/gcc/bin install/`basename $$i`;
    fi
  done
  popd
}

eembc_testsuite ()
{
  echo "eembc testsuite"
}

eembc_extract ()
{
  rm -rf $EEMBC_SUITE
  mkdir -p $EEMBC_SUITE
  check_pattern "$SRC_PATH/$EEMBC_TARBALL*.cpt"
  get_becnhmark  "$SRC_PATH/$EEMBC_TARBALL*.cpt" $EEMBC_SUITE
  $CCAT $EEMBC_SUITE/$EEMBC_TARBALL*.cpt | tar xjf - -C $EEMBC_SUITE
  rm $EEMBC_SUITE/$EEMBC_TARBALL*.cpt
}


