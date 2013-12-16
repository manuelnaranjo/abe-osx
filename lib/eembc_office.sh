

#!/bin/sh

init=false
EEMBC_OFFICE_EEMBC_OFFICE_VBUILD="`grep ^EEMBC_OFFICE_VBUILD= ${topdir}/config/eembc_office.conf \
  | cut -d '=' -f 2`"
EEMBC_OFFICE_SUITE="`grep ^SUITE= ${topdir}/config/eembc_office.conf \
  | cut -d '=' -f 2`"
EEMBC_OFFICE_BENCH_RUNS="`grep ^BENCH_RUNS= ${topdir}/config/eembc_office.conf \
  | cut -d '=' -f 2`"
EEMBC_OFFICE_VCFLAGS="`grep ^VFLAGS= ${topdir}/config/eembc_office.conf \
  | cut -d '=' -f 2`"
EEMBC_OFFICE_PARALEL="`grep ^PARELLEL= ${topdir}/config/eembc_office.conf \
  | cut -d '=' -f 2`"
EEMBC_OFFICE_PASSWOD_FILE="`grep ^PASSWORD_FILE= ${topdir}/config/eembc_office.conf \
  | cut -d '=' -f 2`"
EEMBC_OFFICE_CCAT="`grep ^CCAT= ${topdir}/config/eembc_office.conf \
  | cut -d '=' -f 2`"
EEMBC_OFFICE_BUILD_LOG="`grep ^BUILD_LOG= ${topdir}/config/eembc_office.conf \
  | cut -d '=' -f 2`"
EEMBC_OFFICE_RUN_LOG="`grep ^RUN_LOG= ${topdir}/config/eembc_office.conf \
  | cut -d '=' -f 2`"

eembc_office_init()
{
  init=true
}

eembc_office_run ()
{
  echo "eembc_office run"
  echo "Note: All results are estimates." >> $EEMBC_OFFICE_RUN_LOG
  for i in $(seq 1 $EEMBC_OFFICE_BENCH_RUNS); do
    echo -e \\nRun $i:: >> $EEMBC_OFFICE_RUN_LOG;
    make -C $EEMBC_OFFICE_VBUILD/eembc* -s rerun $MAKE_EXTRAS;
    cat `find $EEMBC_OFFICE_VBUILD -name "gcc_time*.log"` >> $EEMBC_OFFICE_RUN_LOG;
  done
}

eembc_office_build ()
{
  echo "eembc_office build"
  echo COMPILER_FLAGS=$EEMBC_OFFICE_VCFLAGS >> $EEMBC_OFFICE_BUILD_LOG 2>&1
  make -k $PARALLEL -C $EEMBC_OFFICE_VBUILD/eembc* $TARGET $MAKE_EXTRAS >> $EEMBC_OFFICE_BUILD_LOG 2>&1
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
  echo "eembc_office install"
  #make -f $(TOPDIR)/lib/fetch.mk fetch F=$@ CONTEXT=snapshots/prebuilt
  rm -rf $EEMBC_OFFICE_VBUILD/install
  mkdir $EEMBC_OFFICE_VBUILD/install
  cd $EEMBC_OFFICE_VBUILD
  for i in eembc*/*/gcc/bin*; do
    ln -fs ../$i install/`echo $i | awk -F/ '{print $$2}'`
  done
}

eembc_office_testsuite ()
{
  echo "eembc_office testsuite"
}

eembc_office_extract ()
{
  echo "eembc_office extract"
  rm -rf $EEMBC_OFFICE_VBUILD
  mkdir -p $EEMBC_OFFICE_VBUILD
  $CCAT eembc-office+bzr20.tar.xz.cpt | tar xJf - -C $EEMBC_OFFICE_VBUILD
}


