
gmpbench_init()
{
  _gmpbench_init=true
  GMPBENCH_SUITE=gmpbench
  GMPBENCH_VCFLAGS="`grep ^VFLAGS:= ${topdir}/config/gmpbench.conf \
    | awk -F":=" '{print $2}'`"
  GMPBENCH_BUILD_LOG="`grep ^BUILD_LOG:= ${topdir}/config/gmpbench.conf \
    | awk -F":=" '{print $2}'`"
  GMPBENCH_RUN_LOG="`grep ^RUN_LOG:= ${topdir}/config/gmpbench.conf \
    | awk -F":=" '{print $2}'`"
  GMPBENCH_TARBALL="`grep ^TARBALL:= ${topdir}/config/gmpbench.conf \
    | awk -F":=" '{print $2}'`"

  if test "x$GMPBENCH_BUILD_LOG" = x; then
    GMPBENCH_BUILD_LOG=gmpbench_build_log.txt
  fi
  if test "x$GMPBENCH_RUN_LOG" = x; then
    GMPBENCH_RUN_LOG=gmpbench_run_log.txt
  fi
  if test "x$GMPBENCH_TARBALL" = x; then
    error "TARBALL not defined in gmpbench.conf"
    return 1
  fi

  EEMBC_VCFLAGS="-O2 $EEMBC_VCFLAGS $XCFLAGS"
  return 0
}

gmpbench_run ()
{
  PATH=$PWD/$GMPBENCH_SUITE:$PATH
  ABI=$ABI
  CFLAGS="$GMPBENCH_VCFLAGS"
  pushd $GMPBENCH_SUITE/gmp*
  ./runbench >> ../../$GMPBENCH_RUN_LOG 2>&1
  popd
}

gmpbench_build ()
{
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


