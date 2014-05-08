

spec2006_init()
{
  spec2006_init=true
  SPEC2006_SUITE=spec2006
  SPEC2006_VCFLAGS="`grep ^VFLAGS:= ${topdir}/config/spec2006.conf \
    | awk -F":=" '{print $2}'`"
  SPEC2006_XCFLAGS="`grep ^XCFLAGS:= ${topdir}/config/spec2006.conf \
    | awk -F":=" '{print $2}'`"
  SPEC2006_BUILD_LOG="`grep ^BUILD_LOG:= ${topdir}/config/spec2006.conf \
    | awk -F":=" '{print $2}'`"
  SPEC2006_RUN_LOG="`grep ^RUN_LOG:= ${topdir}/config/spec2006.conf \
    | awk -F":=" '{print $2}'`"
  SPEC2006_CONFIG="`grep ^CONFIG:= ${topdir}/config/spec2006.conf \
    | awk -F":=" '{print $2}'`"
  SPEC2006_EXTENSION="`grep ^EXTENSION:= ${topdir}/config/spec2006.conf \
    | awk -F":=" '{print $2}'`"
  SPEC2006_ITERATIONS="`grep ^ITERATIONS:= ${topdir}/config/spec2006.conf \
    | awk -F":=" '{print $2}'`"
  SPEC2006_WORKLOAD="`grep ^WORKLOAD:= ${topdir}/config/spec2006.conf \
    | awk -F":=" '{print $2}'`"
  SPEC2006_TESTS="`grep ^TESTS:= ${topdir}/config/spec2006.conf \
    | awk -F":=" '{print $2}'`"
  SPEC2006_TARBALL="`grep ^TARBALL:= ${topdir}/config/spec2006.conf \
    | awk -F":=" '{print $2}'`"
  if test "x$SPEC2006_BUILD_LOG" = x; then
    SPEC2006_BUILD_LOG=spec2006_build_log.txt
  fi
  if test "x$SPEC2006_RUN_LOG" = x; then
    SPEC2006_RUN_LOG=spec2006_run_log.txt
  fi
  if test "x$SPEC2006_TARBALL" = x; then
    error "TARBALL not defined in spec2006.conf"
    return 1
  fi
  SPEC2006_VCFLAGS="-O2 -fno-common $SPEC2006_VCFLAGS $XCFLAGS"
  RUNSPECFLAGS="-c $SPEC2006_CONFIG -e $SPEC2006_EXTENSION -n $SPEC2006_ITERATIONS -i $SPEC2006_WORKLOAD"
  return 0
}

spec2006_run ()
{
  pushd $SPEC2006_SUITE/cpu2006-1.1-Linaro-ToolchainWG//
  source shrc
  echo "runspec --I $RUNSPECFLAGS  $SPEC2006_TESTS"
  runspec --I $RUNSPECFLAGS  $SPEC2006_TESTS
  echo `pwd`
  for i in result/C*.txt; do
    echo $i:: > ../../$SPEC2006_RUN_LOG;
    cat $i >> ../../$SPEC2006_RUN_LOG;
  done
  # Check to see if any errors happened in the run
  if cat ../../$SPEC2006_RUN_LOG | grep -v reportable | grep errors > ../../$SPEC2006_RUN_LOG.tmp; then
    mv ../../$SPEC2006_RUN_LOG.tmp ../../$SPEC2006_RUN_LOG-failed.txt;
  fi
  popd
}

spec2006_build ()
{
  pushd $SPEC2006_SUITE/cpu2006-1.1-Linaro-ToolchainWG/
  source shrc
  echo VCFLAGS=$SPEC2006_VCFLAGS > ../../$SPEC2006_BUILD_LOG 2>&1
  runspec  $RUNSPECFLAGS -a build $SPEC2006_TESTS >> ../../$SPEC2006_BUILD_LOG 2>&1
  popd
}

spec2006_clean ()
{
  pushd $SPEC2006_SUITE/cpu2006-1.1-Linaro-ToolchainWG//
  source shrc
  runspec $RUNSPECFLAGS -a clean $SPEC2006_TESTS
  rm -rf out
  popd
}


spec2006_build_with_pgo ()
{
  echo "spec2006 build with pgo"
}

spec2006_install ()
{
  echo "spec2006 install"
  local FILE=`ls $SPEC2006_SUITE*`
  rm -rf $FILE/install
  mkdir $SPEC2006_SUITE/$FILE/install
  for i in $SPEC2006_SUITE/$FILE/benchspec/C*/*; do
    if [ -d $SPEC2006_SUITE/$FILE/$i/exe ]; then
      echo ">cp -a $SPEC2006_SUITE/$FILE/$i/exe/* $SPEC2006_SUITE/$FILE/install/`basename $i`<";
      cp -a $SPEC2006_SUITE/$FILE/$i/exe/* $SPEC2006_SUITE/$FILE/install/`basename $i`;
    fi;
  done
}

spec2006_testsuite ()
{
  echo "spec2006 testsuite"
}

spec2006_extract ()
{
  echo "extract 2006"
  # Extract SPEC
  rm -rf $SPEC2006_SUITE
  mkdir -p $SPEC2006_SUITE
  check_pattern "$SRC_PATH/$SPEC2006_TARBALL*.cpt"
  get_benchmark "$SRC_PATH/$SPEC2006_TARBALL*.cpt" $SPEC2006_SUITE
  local FILE=`ls $SPEC2006_SUITE*/$SPEC2006_TARBALL*.cpt`
  echo "$CCAT $FILE | tar xJf - -C $SPEC2006_SUITE"
  $CCAT $FILE | tar xJf - -C $SPEC2006_SUITE
  chmod -R +w $SPEC2006_SUITE
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
  check_pattern "$SRC_PATH/cpu2006tools-*$MACHINE*$FLOAT_SUFFIX*.tar"
  get_benchmark  "$SRC_PATH/cpu2006tools-*$MACHINE*$FLOAT_SUFFIX*.tar" $SPEC2006_SUITE
  tar -xvzf $SPEC2006_SUITE/cpu2006tools-*$MACHINE*$FLOAT_SUFFIX*.tar -C $SPEC2006_SUITE/cpu2006-1.1-Linaro-ToolchainWG/tools/bin
  rm $SSPEC2006_SUITE/cpu2006tools-*$MACHINE*$FLOAT_SUFFIX*.tar

  # and the helper scripts
  check_pattern "$SRC_PATH/$SPEC2006_CONFIG"
  cp  "$SRC_PATH/$SPEC2006_CONFIG" $SPEC2006_SUITE/cpu2006-1.1-Linaro-ToolchainWG/config
  tar xJf  "$SRC_PATH/416.gamess.common.cpu2006.v1.1-1.2.tar.xz" -C $SPEC2006_SUITE/cpu2006-1.1-Linaro-ToolchainWG/


  pushd $SPEC2006_SUITE/cpu2006-1.1-Linaro-ToolchainWG/
  echo "yes" | ./install.sh
  sed -e s#/home/michaelh/linaro/benchmarks/ref#$PWD/..//#g < ./bin/runspec > ./bin/runspec.new
  mv ./bin/runspec.new ./bin/runspec
  chmod +x ./bin/runspec
  sed -e s#/home/michaelh/linaro/benchmarks/ref#$PWD/..//#g < ./bin/specdiff > ./bin/specdiff.new
  mv ./bin/specdiff.new ./bin/specdiff
  chmod +x ./bin/specdiff
  source shrc
  popd
}


