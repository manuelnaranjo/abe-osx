

#!/bin/sh

init=false
DENBENCH_VBUILD="`grep ^VBUILD= ${topdir}/config/denbench.conf \
  | cut -d '=' -f 2`"
DENBENCH_SUITE="`grep ^SUITE= ${topdir}/config/denbench.conf \
  | cut -d '=' -f 2`"
DENBENCH_BENCH_RUNS="`grep ^BENCH_RUNS= ${topdir}/config/denbench.conf \
  | cut -d '=' -f 2`"
DENBENCH_VCFLAGS="`grep ^VFLAGS= ${topdir}/config/denbench.conf \
  | cut -d '=' -f 2`"
DENBENCH_PARALEL="`grep ^PARELLEL= ${topdir}/config/denbench.conf \
  | cut -d '=' -f 2`"
DENBENCH_PASSWOD_FILE="`grep ^PASSWORD_FILE= ${topdir}/config/denbench.conf \
  | cut -d '=' -f 2`"
DENBENCH_CCAT="`grep ^CCAT= ${topdir}/config/denbench.conf \
  | cut -d '=' -f 2`"
DENBENCH_BUILD_LOG="`grep ^BUILD_LOG= ${topdir}/config/denbench.conf \
  | cut -d '=' -f 2`"
DENBENCH_RUN_LOG="`grep ^RUN_LOG= ${topdir}/config/denbench.conf \
  | cut -d '=' -f 2`"

denbench_init()
{
  init=true
}

denbench_run ()
{
  echo "denbench run"
  echo "Note: All results are estimates." >> $DENBENCH_RUN_LOG
  for i in $(seq 1 $DENBENCH_BENCH_RUNS); do
    echo -e \\nRun $i:: >> $DENBENCH_RUN_LOG;
    make -C $DENBENCH_SUITE/* -s rerun;
    cat $DENBENCH_SUITE/consumer/*timev2.log >> $DENBENCH_RUN_LOG;
  done
}

denbench_build ()
{
  echo "denbench build"
  echo VCFLAGS=$VCFLAGS >> $DENBENCH_BUILD_LOG 2>&1
  make -C $DENBENCH_SUITE/*
  COMPILER_FLAGS="$(VCFLAGS)" $(TARGET) >> $DENBENCH_BUILD_LOG 2>&1
}

denbench_clean ()
{
  echo "denbench clean"
}


denbench_build_with_pgo ()
{
  echo "denbench build with pgo"
}

denbench_install ()
{
  echo "denbench install"
}

denbench_testsuite ()
{
  echo "denbench testsuite"
}

denbench_extract ()
{
  echo "denbench extract"
  extract: $(TOPDIR)/files/$(SUITE)*bzr*.cpt
	rm -rf $(VBUILD)
	mkdir -p $(VBUILD)
	$(CCAT) $^ | tar xjf - -C $(VBUILD)
}


