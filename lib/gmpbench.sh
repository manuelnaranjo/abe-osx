
#!/bin/sh

init=false
GMPBENCH_SUITE=gmpbench

GMPBENCH_BENCH_RUNS="`grep ^BENCH_RUNS= ${topdir}/config/gmpbench.conf \
  | cut -d '=' -f 2`"
GMPBENCH_VCFLAGS="`grep ^VFLAGS= ${topdir}/config/gmpbench.conf \
  | cut -d '=' -f 2`"
GMPBENCH_PARALEL="`grep ^PARELLEL= ${topdir}/config/gmpbench.conf \
  | cut -d '=' -f 2`"
GMPBENCH_PASSWOD_FILE="`grep ^PASSWORD_FILE= ${topdir}/config/gmpbench.conf \
  | cut -d '=' -f 2`"
GMPBENCH_CCAT="`grep ^CCAT= ${topdir}/config/gmpbench.conf \
  | cut -d '=' -f 2`"
GMPBENCH_BUILD_LOG="`grep ^BUILD_LOG= ${topdir}/config/gmpbench.conf \
  | cut -d '=' -f 2`"
GMPBENCH_RUN_LOG="`grep ^RUN_LOG= ${topdir}/config/gmpbench.conf \
  | cut -d '=' -f 2`"
GMPBENCH_TARBALL="`grep ^TARBALL= ${topdir}/config/gmpbench.conf \
  | cut -d '=' -f 2`"

gmpbench_init()
{
  init=true
}

gmpbench_run ()
{
  echo "gmpbench run"
  PATH=$PWD:$PATH
  ABI=$ABI
  CFLAGS="$GMPBENCH_VCFLAGS"
  ./runbench >> $GMPBENCH_RUN_LOG 2>&1
}

gmpbench_build ()
{
  echo "gmpbench build"
  local SRC_DIR=`ls $GMPBENCH_SUITE`
  echo $CONFIGURE_FLAGS > $GMPBENCH_BUILD_LOG
  echo CFLAGS=$GMPBENCH_VCFLAGS >> $GMPBENCH_BUILD_LOG
  cd $GMPBENCH_SUITE/$SRC_DIR
  gcc -o gexpr $SRC_PATH/gexpr.c -lm
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
  echo "gmpbench extract"
  rm -rf $GMPBENCH_SUITE
  mkdir -p $GMPBENCH_SUITE
  get_becnhmark  "$SRC_PATH/$GMPBENCH_TARBALL*.tar.bz2" $GMPBENCH_SUITE
  local FILE=`ls $GMPBENCH_SUITE/$GMPBENCH_TARBALL*.tar.bz2`
  tar xaf $FILE -C $GMPBENCH_SUITE
  rm -f $FILE
}


