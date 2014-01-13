

spec2k_init()
{
  spec2k_init=true
  SPEC2k_SUITE=spec2k
  SPEC2k_VCFLAGS="`grep ^VFLAGS:= ${topdir}/config/spec2k.conf \
    | awk -F":=" '{print $2}'`"
  SPEC2k_XCFLAGS="`grep ^XCFLAGS:= ${topdir}/config/spec2k.conf \
    | awk -F":=" '{print $2}'`"
  SPEC2k_BUILD_LOG="`grep ^BUILD_LOG:= ${topdir}/config/spec2k.conf \
    | awk -F":=" '{print $2}'`"
  SPEC2k_RUN_LOG="`grep ^RUN_LOG:= ${topdir}/config/spec2k.conf \
    | awk -F":=" '{print $2}'`"
  SPEC2k_CONFIG="`grep ^CONFIG:= ${topdir}/config/spec2k.conf \
    | awk -F":=" '{print $2}'`"
  SPEC2k_EXTENSION="`grep ^EXTENSION:= ${topdir}/config/spec2k.conf \
    | awk -F":=" '{print $2}'`"
  SPEC2k_ITERATIONS="`grep ^ITERATIONS:= ${topdir}/config/spec2k.conf \
    | awk -F":=" '{print $2}'`"
  SPEC2k_WORKLOAD="`grep ^WORKLOAD:= ${topdir}/config/spec2k.conf \
    | awk -F":=" '{print $2}'`"
  SPEC2k_TESTS="`grep ^TESTS:= ${topdir}/config/spec2k.conf \
    | awk -F":=" '{print $2}'`"
  SPEC2k_TARBALL="`grep ^TARBALL:= ${topdir}/config/spec2k.conf \
    | awk -F":=" '{print $2}'`"
  if test "x$SPEC2k_BUILD_LOG" = x; then
    SPEC2k_BUILD_LOG=spec2k_build_log.txt
  fi
  if test "x$SPEC2k_RUN_LOG" = x; then
    SPEC2k_RUN_LOG=spec2k_run_log.txt
  fi
  if test "x$SPEC2k_TARBALL" = x; then
    error "TARBALL not defined in spec2k.conf"
    exit
  fi
  SPEC2k_VCFLAGS="-O2 -fno-common $SPEC2k_VCFLAGS $XCFLAGS"
  RUNSPECFLAGS="-c $SPEC2k_CONFIG -e $SPEC2k_EXTENSION -n $SPEC2k_ITERATIONS -i $SPEC2k_WORKLOAD"
}

spec2k_run ()
{
  pushd $SPEC2k_SUITE/cpu2000/
  source shrc
  echo "runspec --I $RUNSPECFLAGS  $SPEC2k_TESTS"
  runspec --I $RUNSPECFLAGS  $SPEC2k_TESTS
  echo `pwd`
  for i in result/C*.{asc,raw}; do
    echo $i:: > ../../$SPEC2k_RUN_LOG;
    cat $i >> ../../$SPEC2k_RUN_LOG;
  done
  # Check to see if any errors happened in the run
  if cat ../../$SPEC2k_RUN_LOG | grep -v reportable | grep errors > ../../$SPEC2k_RUN_LOG.tmp; then
    mv ../../$SPEC2k_RUN_LOG.tmp ../../$SPEC2k_RUN_LOG-failed.txt;
  fi
  popd
}

spec2k_build ()
{
  pushd $SPEC2k_SUITE/cpu2000/
  source shrc
  echo VCFLAGS=$SPEC2k_VCFLAGS > ../../$SPEC2k_BUILD_LOG 2>&1
  runspec  $RUNSPECFLAGS -a build $SPEC2k_TESTS >> ../../$SPEC2k_BUILD_LOG 2>&1
  popd
}

spec2k_clean ()
{
  pushd $SPEC2k_SUITE/cpu2000/
  source shrc
  runspec $RUNSPECFLAGS -a nuke $SPEC2k_TESTS
  rm -rf out
  popd
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
  # Extract SPEC
  rm -rf $SPEC2k_SUITE
  mkdir -p $SPEC2k_SUITE
  check_pattern "$SRC_PATH/$SPEC2k_TARBALL*.cpt"
  get_becnhmark "$SRC_PATH/$SPEC2k_TARBALL*.cpt" $SPEC2k_SUITE
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
      BUILD_ARCH=`dpkg-architecture -qDEB_BUILD_ARCH`
      case $BUILD_ARCH in
	*hf*)
	  FLOAT_SUFFIX=hf
	  ;;
	*)
	  ;;
      esac
      ;;
    *)
     error "MACHINE=`uname -m` is not supported"
     ;;
  esac
  # Create the config file
  check_pattern "$SRC_PATH/cpu2000tools-*$MACHINE*$FLOAT_SUFFIX*.tar*cpt"
  get_becnhmark  "$SRC_PATH/cpu2000tools-*$MACHINE*$FLOAT_SUFFIX*.tar*cpt" $SPEC2k_SUITE
  $CCAT $SPEC2k_SUITE/cpu2000tools-*$MACHINE*$FLOAT_SUFFIX*.cpt | tar xJf - -C $SPEC2k_SUITE/cpu2000
  rm $SSPEC2k_SUITE/cpu2000tools-*$MACHINE*$FLOAT_SUFFIX*.tar*cpt

  # and the helper scripts
  check_pattern "$SRC_PATH/spec2000-*.tar*"
  get_becnhmark  "$SRC_PATH/spec2000-*.tar*" $SPEC2k_SUITE
  tar xaf $SPEC2k_SUITE/spec2000-*.tar* -C $SPEC2k_SUITE/cpu2000* --strip-components=1
  rm $SPEC2k_SUITE/spec2000-*.tar*

  pushd $SPEC2k_SUITE/cpu2000/
  sed -e s#/home/michaelh/linaro/benchmarks/ref#$PWD/..//#g < ./bin/runspec > ./bin/runspec.new
  mv ./bin/runspec.new ./bin/runspec
  chmod +x ./bin/runspec
  sed -e s#/home/michaelh/linaro/benchmarks/ref#$PWD/..//#g < ./bin/specdiff > ./bin/specdiff.new
  mv ./bin/specdiff.new ./bin/specdiff
  chmod +x ./bin/specdiff
  source shrc
  popd
}


