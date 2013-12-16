

#!/bin/sh

init=false
LIBAVBENCH_SUITE=libavbench

LIBAVBENCH_LIBAVBENCH_SUITE="`grep ^VBUILD= ${topdir}/config/libavbench.conf \
  | cut -d '=' -f 2`"
LIBAVBENCH_LIBAVBENCH_SUITE="`grep ^SUITE= ${topdir}/config/libavbench.conf \
  | cut -d '=' -f 2`"
LIBAVBENCH_BENCH_RUNS="`grep ^BENCH_RUNS= ${topdir}/config/libavbench.conf \
  | cut -d '=' -f 2`"
LIBAVBENCH_VCFLAGS="`grep ^VFLAGS= ${topdir}/config/libavbench.conf \
  | cut -d '=' -f 2`"
LIBAVBENCH_PARALEL="`grep ^PARELLEL= ${topdir}/config/libavbench.conf \
  | cut -d '=' -f 2`"
LIBAVBENCH_PASSWOD_FILE="`grep ^PASSWORD_FILE= ${topdir}/config/libavbench.conf \
  | cut -d '=' -f 2`"
LIBAVBENCH_CCAT="`grep ^CCAT= ${topdir}/config/libavbench.conf \
  | cut -d '=' -f 2`"
LIBAVBENCH_BUILD_LOG="`grep ^BUILD_LOG= ${topdir}/config/libavbench.conf \
  | cut -d '=' -f 2`"
LIBAVBENCH_RUN_LOG="`grep ^RUN_LOG= ${topdir}/config/libavbench.conf \
  | cut -d '=' -f 2`"
LIBAVBENCH_TARBALL="`grep ^TARBALL= ${topdir}/config/libavbench.conf \
  | cut -d '=' -f 2`"

LBUILD=$LIBAVBENCH_SUITE/$LIBAVBENCH_SUITE

libavbench_init()
{
  init=true
}

libavbench_run ()
{
  echo "libavbench run"
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
  echo "libavbench build"
  make -C $LIBAVBENCH_SUITE/build/ >> $LIBAVBENCH_BUILD_LOG.txt 2>&1
  make -C $LIBAVBENCH_SUITE/build/ install>> $LIBAVBENCH_BUILD_LOG.txt 2>&1
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
  echo "libavbench extract"
  rm -rf $LIBAVBENCH_SUITE
  mkdir -p $LIBAVBENCH_SUITE
  get_becnhmark  "$SRC_PATH/$LIBAVBENCH_TARBALL*.tar.xz" $LIBAVBENCH_SUITE
  local FILE=`ls $LIBAVBENCH_SUITE/$LIBAVBENCH_TARBALL*.tar.xz`
  tar xaf $FILE -C $LIBAVBENCH_SUITE
  rm -f $FILE
  local SRC_DIR=`ls $LIBAVBENCH_SUITE`

  echo $CONFIGURE_FLAGS >> $LIBAVBENCH_BUILD_LOG
  mkdir -p $LIBAVBENCH_SUITE/build
  cd $LIBAVBENCH_SUITE/build
  echo ">>$SRC_DIR"
  ../$SRC_DIR/configure --prefix=$PWD/../install $CONFIGURE_FLAGS  >> $LIBAVBENCH_BUILD_LOG 2>&1
  cd ../../
  # Strip out any unwanted default flags
  for i in $REMOVE_CFLAGS; do
    sed -i~ s#$i## $LIBAVBENCH_SUITE/build/config.mak;
  done
  grep FLAGS $LIBAVBENCH_SUITE/build/config.mak >> $LIBAVBENCH_BUILD_LOG.txt
}


