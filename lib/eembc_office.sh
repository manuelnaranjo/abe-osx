
eembc_office_init()
{
  _eembc_office_init=true
  EEMBC_OFFICE_SUITE=eembc_office
  EEMBC_OFFICE_BENCH_RUNS="`grep ^BENCH_RUNS:= ${topdir}/config/eembc_office.conf \
    | awk -F":=" '{print $2}'`"
  EEMBC_OFFICE_VCFLAGS="`grep ^VFLAGS:= ${topdir}/config/eembc_office.conf \
    | awk -F":=" '{print $2}'`"
  EEMBC_OFFICE_BUILD_LOG="`grep ^BUILD_LOG:= ${topdir}/config/eembc_office.conf \
    | awk -F":=" '{print $2}'`"
  EEMBC_OFFICE_RUN_LOG="`grep ^RUN_LOG:= ${topdir}/config/eembc_office.conf \
    | awk -F":=" '{print $2}'`"
  EEMBC_OFFICE_TARBALL="`grep ^TARBALL:= ${topdir}/config/eembc_office.conf \
    | awk -F":=" '{print $2}'`"

  if test "x$EEMBC_OFFICE_BENCH_RUNS" = x; then
    EEMBC_OFFICE_BENCH_RUNS=1
  fi
  if test "x$EEMBC_OFFICE_BUILD_LOG" = x; then
    EEMBC_OFFICE_BUILD_LOG=eembc_office_build_log.txt
  fi
  if test "x$EEMBC_OFFICE_RUN_LOG" = x; then
    EEMBC_OFFICE_RUN_LOG=eembc_office_run_log.txt
  fi
  if test "x$EEMBC_OFFICE_TARBALL" = x; then
    error "TARBALL not defined in eembc_office.conf"
    exit
  fi
}

eembc_office_run ()
{
  echo "Note: All results are estimates." >> $EEMBC_OFFICE_RUN_LOG
  for i in $(seq 1 $BENCH_RUNS); do
    echo -e \\nRun $i:: >> $EEMBC_OFFICE_RUN_LOG;
    make -C $EEMBC_OFFICE_SUITE/eembc_office-linaro-* -s rerun $MAKE_EXTRAS;
    cat `find $EEMBC_OFFICE_SUITE -name "gcc_time*.log"` >> $EEMBC_OFFICE_RUN_LOG;
  done
}

eembc_office_build ()
{
  echo "eembc_office build"
  echo COMPILER_FLAGS=$VCFLAGS >> $EEMBC_OFFICE_BUILD_LOG 2>&1
  local SRCDIR=`ls $EEMBC_OFFICE_SUITE`
  make -k $EEMBC_OFFICE_PARALLEL -C $EEMBC_OFFICE_SUITE/$SRC_DIR $TARGET $MAKE_EXTRAS >> $EEMBC_OFFICE_BUILD_LOG 2>&1
}

eembc_office_clean ()
{
  echo "eembc_office clean"
}


eembc_office_build_with_pgo ()
{
  echo "eembc_office build with pgo"
}

eembc_office_install ()
{
  rm -rf $EEMBC_OFFICE_SUITE/install
  mkdir $EEMBC_OFFICE_SUITE/install
  pushd $EEMBC_OFFICE_SUITE
  for i in eembc_office-linaro-*/*; do
    if [ -d $$i/gcc/bin ];
	then ln -fs ../$i/gcc/bin install/`basename $$i`;
    fi
  done
  popd
}

eembc_office_testsuite ()
{
  echo "eembc_office testsuite"
}

eembc_office_extract ()
{
  rm -rf $EEMBC_OFFICE_SUITE
  mkdir -p $EEMBC_OFFICE_SUITE
  check_pattern "$SRC_PATH/$EEMBC_OFFICE_TARBALL*.cpt"
  get_becnhmark  "$SRC_PATH/$EEMBC_OFFICE_TARBALL*.cpt" $EEMBC_OFFICE_SUITE
  $CCAT $EEMBC_OFFICE_SUITE/$EEMBC_OFFICE_TARBALL*.cpt | tar xjf - -C $EEMBC_OFFICE_SUITE
  rm -f $EEMBC_OFFICE_SUITE/$EEMBC_OFFICE_TARBALL*.cpt
}


