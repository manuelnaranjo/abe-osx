
#!/bin/sh

init=false
COREMARK_SUITE=coremark
COREMARK=

COREMARK_BENCH_RUNS="`grep ^BENCH_RUNS= ${topdir}/config/coremark.conf \
  | cut -d '=' -f 2`"
COREMARK_VCFLAGS="`grep ^VFLAGS= ${topdir}/config/coremark.conf \
  | cut -d '=' -f 2`"
COREMARK_PARALEL="`grep ^PARELLEL= ${topdir}/config/coremark.conf \
  | cut -d '=' -f 2`"
COREMARK_CCAT="`grep ^CCAT= ${topdir}/config/coremark.conf \
  | cut -d '=' -f 2`"
COREMARK_BUILD_LOG="`grep ^BUILD_LOG= ${topdir}/config/coremark.conf \
  | cut -d '=' -f 2`"
COREMARK_RUN_LOG="`grep ^RUN_LOG= ${topdir}/config/coremark.conf \
  | cut -d '=' -f 2`"
COREMARK_TARBALL="`grep ^TARBALL= ${topdir}/config/coremark.conf \
  | cut -d '=' -f 2`"

coremark_init()
{
  init=true
}

coremark_run ()
{
  if test $init = false; then
    error "init not  called"
  fi
  local COREMARK=`ls coremark`
  echo "Note: All results are estimates." >> $COREMARK_RUN_LOG
  for i in $(seq 1 $COREMARK_BENCH_RUNS)
  do
    echo -e \\nRun $$i:: >> $COREMARK_RUN_LOG
    echo "make -C $COREMARK_SUITE/$COREMARK -s rerun UNAME=`uname`"
    make -C $COREMARK_SUITE/$COREMARK -s rerun UNAME=`uname`
    cat $COREMARK_SUITE/$COREMARK/*.log >> $COREMARK_RUN_LOG
  done
  exit
}

coremark_clean()
{
  local COREMARK=`ls coremark`
  make -C $COREMARK_SUITE/$COREMARK -s clean UNAME=`uname`
}

coremark_build_with_pgo ()
{
  if test $init = false; then
    error "init not  called"
  fi
  echo PORT_CFLAGS=$VCFLAGS >> $COREMARK_SUITE/$COREMARK_BUILD_LOG
  echo XCFLAGS=$XCFLAGS >> $COREMARK_SUIYE/$COREMARK_BUILD_LOG
  local COREMARK=`ls coremark`
  # readme.txt sets what the training run should be
  make -C $COREMARK_SUITE/$COREMARK $PARALLEL run3.log REBUILD=1 \
    UNAME=`uname` PORT_CFLAGS="$VCFLAGS" XCFLAGS="$XCFLAGS -fprofile-generate \
    -DTOTAL_DATA_SIZE=1200 -DPROFILE_RUN=1" >> $COREMARK_BUILD_LOG 2>&1
  make -C $COREMARK_SUITE/$COREMARK -s clean UNAME=`uname`
  make -C $COREMARK_SUITE/$COREMARK $PARALLEL load UNAME=`uname`\
    PORT_CFLAGS="$VCFLAGS" XCFLAGS="$XCFLAGS \
    -fprofile-use" >> $COREMARK_BUILD_LOG 2>&1
}

coremark_build ()
{
  if test $init = false; then
    error "init not  called"
  fi
  echo "on build"
  echo PORT_CFLAGS=$VCFLAGS >> $COREMARK_BUILD_LOG
  echo XCFLAGS=$XCFLAGS >> $COREMARK_BUILD_LOG
  local COREMARK=`ls coremark`
  make -C $COREMARK_SUITE/$COREMARK -s clean UNAME=`uname`
  make -C $COREMARK_SUITE/$COREMARK $PARALLEL load UNAME=`uname` \
    PORT_CFLAGS="$VCFLAGS" XCFLAGS="$XCFLAGS" >> $COREMARK_BUILD_LOG 2>&1
}


coremark_install ()
{
  if test $init = false; then
    error "init not  called"
  fi
  echo "FIXME: Implement it"
}

coremark_testsuite ()
{
  if test $init = false; then
    error "init not  called"
  fi
  echo "FIXME: Implement it"
}

coremark_extract ()
{
  echo "extract"
  if test $init = false; then
    error "init not  called"
  fi
  rm -rf $COREMARK_SUITE
  mkdir -p $COREMARK_SUITE
  get_becnhmark  "$SRC_PATH/$COREMARK_TARBALL*.cpt" $COREMARK_SUITE
  sync
  local FILE=`ls $COREMARK_SUITE*/$COREMARK_TARBALL*`
  $CCAT $FILE | gunzip | tar xaf - -C $COREMARK_SUITE
  rm $FILE
}


