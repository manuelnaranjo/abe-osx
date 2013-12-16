

#!/bin/sh

init=false
EEMBC_VBUILD="`grep ^VBUILD= ${topdir}/config/eembc.conf \
  | cut -d '=' -f 2`"
EEMBC_SUITE="`grep ^SUITE= ${topdir}/config/eembc.conf \
  | cut -d '=' -f 2`"
EEMBC_BENCH_RUNS="`grep ^BENCH_RUNS= ${topdir}/config/eembc.conf \
  | cut -d '=' -f 2`"
EEMBC_VCFLAGS="`grep ^VFLAGS= ${topdir}/config/eembc.conf \
  | cut -d '=' -f 2`"
EEMBC_PARALEL="`grep ^PARELLEL= ${topdir}/config/eembc.conf \
  | cut -d '=' -f 2`"
EEMBC_PASSWOD_FILE="`grep ^PASSWORD_FILE= ${topdir}/config/eembc.conf \
  | cut -d '=' -f 2`"
EEMBC_CCAT="`grep ^CCAT= ${topdir}/config/eembc.conf \
  | cut -d '=' -f 2`"
EEMBC_BUILD_LOG="`grep ^BUILD_LOG= ${topdir}/config/eembc.conf \
  | cut -d '=' -f 2`"
EEMBC_RUN_LOG="`grep ^RUN_LOG= ${topdir}/config/eembc.conf \
  | cut -d '=' -f 2`"

eembc_init()
{
  init=true
}

eembc_run ()
{
  echo "eembc run"
  echo "Note: All results are estimates." >> $(STEP).txt
  for i in $(seq 1 $BENCH_RUNS); do
    echo -e \\nRun $$i:: >> $(STEP).txt;
    make -C $(VBUILD)/eembc-linaro-* -s rerun $(MAKE_EXTRAS);
    cat `find $(VBUILD) -name "gcc_time*.log"` >> $(STEP).txt;
  done
}

eembc_build ()
{
  echo "eembc build"
  echo COMPILER_FLAGS=$(VCFLAGS) >> $(STEP).txt 2>&1
  make -k $(PARALLEL) -C $(VBUILD)/eembc-linaro-* $(TARGET) $(MAKE_EXTRAS) >> $(STEP).txt 2>&1
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
  echo "eembc install"
  rm -rf $(VBUILD)/install
  mkdir $(VBUILD)/install
  cd $(VBUILD)
  for i in eembc-linaro-*/*; do
    if [ -d $$i/gcc/bin ];
	then ln -fs ../$i/gcc/bin install/`basename $$i`;
    fi
  done
}

eembc_testsuite ()
{
  echo "eembc testsuite"
}

eembc_extract ()
{
  echo "eembc extract"
  rm -rf $VBUILD
  mkdir -p $VBUILD
  $CCAT eembc-linaro-v1*.tar* | tar xjf - -C $EEMBC_VBUILD
}


