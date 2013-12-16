

#!/bin/sh

init=false
DENBENCH_VBUILD="`grep ^VBUILD= ${topdir}/config/debench.conf \
  | cut -d '=' -f 2`"
DENBENCH_SUITE="`grep ^SUITE= ${topdir}/config/debench.conf \
  | cut -d '=' -f 2`"
DENBENCH_BENCH_RUNS="`grep ^BENCH_RUNS= ${topdir}/config/debench.conf \
  | cut -d '=' -f 2`"
DENBENCH_VCFLAGS="`grep ^VFLAGS= ${topdir}/config/debench.conf \
  | cut -d '=' -f 2`"
DENBENCH_PARALEL="`grep ^PARELLEL= ${topdir}/config/debench.conf \
  | cut -d '=' -f 2`"
DENBENCH_PASSWOD_FILE="`grep ^PASSWORD_FILE= ${topdir}/config/debench.conf \
  | cut -d '=' -f 2`"
DENBENCH_CCAT="`grep ^CCAT= ${topdir}/config/debench.conf \
  | cut -d '=' -f 2`"
DENBENCH_BUILD_LOG="`grep ^BUILD_LOG= ${topdir}/config/debench.conf \
  | cut -d '=' -f 2`"
DENBENCH_RUN_LOG="`grep ^RUN_LOG= ${topdir}/config/debench.conf \
  | cut -d '=' -f 2`"

denbench_init()
{
  init=true
}

denbench_run ()
{
  echo "denbench run"
  echo "Note: All results are estimates." >> $(STEP).txt
  for i in $$(seq $(BENCH_RUNS)); do \
    echo -e \\nRun $$i:: >> $(STEP).txt; \
    make -C $(VBUILD)/$(SUITE)* -s rerun; \
    cat $(VBUILD)/$(SUITE)*/consumer/*timev2.log >> $(STEP).txt; \
  done
}

denbench_build ()
{
  echo "denbench build"
  echo VCFLAGS=$(VCFLAGS) >> $(STEP).txt 2>&1
  make -C $(VBUILD)/$(SUITE)*
  COMPILER_FLAGS="$(VCFLAGS)" $(TARGET) >> $(STEP).txt 2>&1
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


