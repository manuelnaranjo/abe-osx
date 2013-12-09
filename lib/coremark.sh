
#!/bin/sh

init=false
COREMARK_VBUILD="`grep ^VBUILD= ${topdir}/config/coremark.conf \
  | cut -d '=' -f 2`"
COREMARK_SUITE="`grep ^SUITE= ${topdir}/config/coremark.conf \
  | cut -d '=' -f 2`"
COREMARK_BENCH_RUNS="`grep ^BENCH_RUNS= ${topdir}/config/coremark.conf \
  | cut -d '=' -f 2`"
COREMARK_VCFLAGS="`grep ^VFLAGS= ${topdir}/config/coremark.conf \
  | cut -d '=' -f 2`"
COREMARK_XCFLAGS="`grep ^XCFLAGS= ${topdir}/config/coremark.conf \
  | cut -d '=' -f 2`"
COREMARK_PARALEL="`grep ^PARELLEL= ${topdir}/config/coremark.conf \
  | cut -d '=' -f 2`"
COREMARK_PASSWOD_FILE="`grep ^PASSWORD_FILE= ${topdir}/config/coremark.conf \
  | cut -d '=' -f 2`"
COREMARK_CCAT="`grep ^CCAT= ${topdir}/config/coremark.conf \
  | cut -d '=' -f 2`"
COREMARK_BUILD_LOG="`grep ^BUILD_LOG= ${topdir}/config/coremark.conf \
  | cut -d '=' -f 2`"
COREMARK_RUN_LOG="`grep ^RUN_LOG= ${topdir}/config/coremark.conf \
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
  echo "Note: All results are estimates." >> $COREMARK_RUN_LOG.txt
  for i in $(seq 1 $BENCH_RUNS)
  do 
    echo -e \\nRun $$i:: >> $COREMARK_RUN_LOG
    make -C $COREMARK_VBUILD/$COREMARK_SUITE -s rerun UNAME=`uname`
    cat $COREMARK_VBUILD/$COREMARK_SUITE/*.log >> $COREMARK_RUN_LOG
  done
}

coremark_build_with_pgo ()
{
  if test $init = false; then
    error "init not  called"
  fi
  echo PORT_CFLAGS=$VCFLAGS >> $COREMARK_BUILD_LOG
  echo XCFLAGS=$XCFLAGS >> $COREMARK_BUILD_LOG
  # readme.txt sets what the training run should be
  make -C $COREMARK_VBUILD/$COREMARK_SUITE $PARALLEL run3.log REBUILD=1 \
    UNAME=`uname` PORT_CFLAGS="$VCFLAGS" XCFLAGS="$XCFLAGS -fprofile-generate \
    -DTOTAL_DATA_SIZE=1200 -DPROFILE_RUN=1" >> $COREMARK_BUILD_LOG 2>&1
  make -C $COREMARK_VBUILD/$COREMARK_SUITE -s clean UNAME=`uname`
  make -C $COREMARK_VBUILD/$COREMARK_SUITE $PARALLEL load UNAME=`uname`\
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
  make -C $COREMARK_VBUILD/$COREMARK_SUITE -s clean UNAME=`uname`
  make -C $COREMARK_VBUILD/$COREMARK_SUITE $PARALLEL load UNAME=`uname` \
    PORT_CFLAGS="$VCFLAGS" XCFLAGS="$XCFLAGS" >> $COREMARK_BUILD_LOG 2>&1
}


#cd $(VBUILD) && ln -s $(SUITE)* install
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
  if test $init = false; then
    error "init not  called"
  fi
  echo "extract"
  #FIXME src
  $CCAT 'src' | gunzip | tar xaf - -C $COREMARK_VBUILD
}


