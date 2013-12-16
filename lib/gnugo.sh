#!/bin/sh

init=false
GNUGO_SUITE=gnugo

GNUGO_BENCH_RUNS="`grep ^BENCH_RUNS= ${topdir}/config/gnugo.conf \
  | cut -d '=' -f 2`"
GNUGO_VCFLAGS="`grep ^VFLAGS= ${topdir}/config/gnugo.conf \
  | cut -d '=' -f 2`"
GNUGO_PARALEL="`grep ^PARELLEL= ${topdir}/config/gnugo.conf \
  | cut -d '=' -f 2`"
GNUGO_PASSWOD_FILE="`grep ^PASSWORD_FILE= ${topdir}/config/gnugo.conf \
  | cut -d '=' -f 2`"
GNUGO_CCAT="`grep ^CCAT= ${topdir}/config/gnugo.conf \
  | cut -d '=' -f 2`"
GNUGO_BUILD_LOG="`grep ^BUILD_LOG= ${topdir}/config/gnugo.conf \
  | cut -d '=' -f 2`"
GNUGO_RUN_LOG="`grep ^RUN_LOG= ${topdir}/config/gnugo.conf \
  | cut -d '=' -f 2`"
GNUGO_TARBALL="`grep ^TARBALL= ${topdir}/config/gnugo.conf \
  | cut -d '=' -f 2`"

gnugo_init()
{
  init=true
}

gnugo_run ()
{
  echo "gnugo run"
  cd $GNUGO_SUITE/gnugo-*/regression
  for i in $(seq 1 $GNUGO_BENCH_RUNS); do
    echo -e \\nRun $i:: >> $GNUGO_RUN_LOG;
    $TIME -o ../../../$GNUGO_RUN_LOG -a ../../../$GNUGO_SUITE/install/bin/gnugo --quiet --mode gtp\
      --gtp-input viking.tst;
  done
  cd ../../..
}

gnugo_build ()
{
  echo "gnugo build"
  mkdir -p $GNUGO_SUITE/build
  cd $GNUGO_SUITE/build
  CFLAGS="$VCFLAGS" LDFLAGS="$VLDFLAGS" ../gnugo-*/configure --prefix=$PWD/../install >> $GNUGO_BUILD_LOG 2>&1
  echo $PWD
  make >> $GNUGO_BUILD_LOG 2>&1
  make install >> $GNUGO_BUILD_LOG 2>&1
  cd ../..
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
  get_becnhmark  "$SRC_PATH/$GNUGO_TARBALL*.tar.gz" $GNUGO_SUITE
  local FILE=`ls $GNUGO_SUITE/$GNUGO_TARBALL*.tar.gz`
  tar xaf $FILE -C $GNUGO_SUITE
  rm -f $FILE
}


