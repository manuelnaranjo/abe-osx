
init=false
SPEC2k_SUITE=spec2k

SPEC2k_BENCH_RUNS="`grep ^BENCH_RUNS= ${topdir}/config/spec2k.conf \
  | cut -d '=' -f 2`"
SPEC2k_VCFLAGS="`grep ^VFLAGS= ${topdir}/config/spec2k.conf \
  | cut -d '=' -f 2`"
SPEC2k_XCFLAGS="`grep ^XCFLAGS= ${topdir}/config/spec2k.conf \
  | cut -d '=' -f 2`"
SPEC2k_PARALEL="`grep ^PARELLEL= ${topdir}/config/spec2k.conf \
  | cut -d '=' -f 2`"
SPEC2k_PASSWOD_FILE="`grep ^PASSWORD_FILE= ${topdir}/config/spec2k.conf \
  | cut -d '=' -f 2`"
SPEC2k_CCAT="`grep ^CCAT= ${topdir}/config/spec2k.conf \
  | cut -d '=' -f 2`"
SPEC2k_BUILD_LOG="`grep ^BUILD_LOG= ${topdir}/config/spec2k.conf \
  | cut -d '=' -f 2`"
SPEC2k_RUN_LOG="`grep ^RUN_LOG= ${topdir}/config/spec2k.conf \
  | cut -d '=' -f 2`"
SPEC2k_CONFIG="`grep ^CONFIG= ${topdir}/config/spec2k.conf \
  | cut -d '=' -f 2`"
SPEC2k_EXTENSION="`grep ^EXTENSION= ${topdir}/config/spec2k.conf \
  | cut -d '=' -f 2`"
SPEC2k_ITERATIONS="`grep ^ITERATIONS= ${topdir}/config/spec2k.conf \
  | cut -d '=' -f 2`"
SPEC2k_WORKLOAD="`grep ^WORKLOAD= ${topdir}/config/spec2k.conf \
  | cut -d '=' -f 2`"
SPEC2k_TESTS="`grep ^TESTS= ${topdir}/config/spec2k.conf \
  | cut -d '=' -f 2`"
SPEC2k_TARBALL="`grep ^TARBALL= ${topdir}/config/spec2k.conf \
  | cut -d '=' -f 2`"


RUNSPECFLAGS="-c $SPEC2k_CONFIG -e $SPEC2k_EXTENSION -n $SPEC2k_ITERATIONS -i $SPEC2k_WORKLOAD --ignoreerror"


spec2k_init()
{
  init=true
  source "$SPEC2k_SPEC2k_VBUILD/shrc"
}

spec2k_run ()
{
  runspec --I $RUNSPECFLAGS  $SPEC2k_TESTS
  for i in $SPEC2k_VBUILD/cpu2000*/result/C*.{asc,raw}; do
    echo $i:: >> $SPEC2k_RUN_LOG.txt;
    cat $i >> $SPEC2k_RUN_LOG.txt;
  done
  # Check to see if any errors happened in the run
  if cat $SPEC2k_RUN_LOG.txt | grep -v reportable | grep errors > $SPEC2k_RUN_LOG.tmp; then
    mv $SPEC2k_RUN_LOG.tmp $SPEC2k_RUN_LOG-failed.txt;
  fi

}

spec2k_build ()
{
  echo "spec2k build"
  echo VCFLAGS=$SPEC2k_VCFLAGS >> $SPEC2k_BUILD_LOG 2>&1
  runspec  $RUNSPECFLAGS -a build $SPEC2k_TESTS
}

spec2k_clean ()
{
  echo "spec2k clean"
  runspec $RUNSPECFLAGS -a nuke $SPEC2k_TESTS
  rm -rf out
}


spec2k_build_with_pgo ()
{
  echo "spec2k build with pgo"
}

spec2k_install ()
{
  echo "spec2k install"
  local FILE=`ls $SPEC2k_SUITE*`
  rm -rf $FILE/install
  mkdir $SPEC2k_SUITE/$FILE/install
  for i in $SPEC2k_SUITE/$FILE/benchspec/C*/*; do
    if [ -d $SPEC2k_SUITE/$FILE/$i/exe ]; then
      echo ">cp -a $SPEC2k_SUITE/$FILE/$i/exe/* $SPEC2k_SUITE/$FILE/install/`basename $i`<";
      cp -a $SPEC2k_SUITE/$FILE/$i/exe/* $SPEC2k_SUITE/$FILE/install/`basename $i`;
    fi;
  done
}

spec2k_testsuite ()
{
  echo "spec2k testsuite"
}

spec2k_extract ()
{
  echo "spec2k extract"
  # Extract SPEC
  rm -rf $SPEC2k_SUITE
  mkdir -p $SPEC2k_SUITE
  get_becnhmark  "$SRC_PATH/$SPEC2k_TARBALL*-[1-3\.]*.cpt" $SPEC2k_SUITE
  local FILE=`ls $SPEC2k_SUITE*/$SPEC2k_TARBALL*.cpt`
  $CCAT $FILE | tar xJf - -C $SPEC2k_SUITE
  chmod -R +w $SPEC2k_SUITE
  rm $FILE
  # and the tools for this architecture
  case `uname -m` in
    *x86_64*)
      MACHINE=x86_64
      ;;
    *arm*)
      MACHINE=arm
      ;;
    *)
     error ""
     ;;
  esac
  get_becnhmark  "$SRC_PATH/cpu2000tools-*$MACHINE$FLOAT_SUFFIX.tar*cpt" $SPEC2k_SUITE
  local TOOL=`ls $SPEC2k_SUITE/cpu2000tools-*$MACHINE*.cpt`
  $CCAT $TOOL | tar xJf - -C $SPEC2k_SUITE/cpu2000
  #rm $FILE
  #cp -alf $(LBUILD)/cpu2000* $(VBUILD)
  #ln -sf $(VBUILD)/cpu2000* $(NICEBUILD)
  # Create the config file
  cd $SPEC2k_SUITE/cpu2000/
  sed -e s#/home/michaelh/linaro/benchmarks/ref#$PWD/..//#g < ./bin/runspec > ./bin/runspec.new
  mv ./bin/runspec.new ./bin/runspec
  chmod +x ./bin/runspec
  source shrc
}


