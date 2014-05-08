
BZIP2BENCH=1
COREMARK=2
LIBAVBENCH=3
GMPBENCH=4
GNUGO=5
SKIBENCH=6
VORBISBENCH=7
BENCHNT=8
SKIABENCH=9
DENBENCH=10
EEMBC=11
EEMBC_OFFICE=12
SPEC2K=13
NBENCH=14
SPEC2006=15

TIME=time

_coremark_init=false
_libavbench_init=false;
_gmpbench_init=false;
_gnugo_init=false
_skiabench_init=false
_denbench_init=false
_eembc_init=false
_eembc_office_init=false
_spec2k_init=false
_nbench_init=false
_spec2006_init=false

check_pattern()
{
  COUNT=`ls $1| wc -l`
  if test $COUNT = 0; then
    error "pattern $1 does not match any file"
    exit
  fi
  if test $COUNT != 1; then
    error "pattern $1  matches more than one file"
    exit
  fi
}

#
# $1 is the benchmark name
#
get_bench_id()
{
  case $1 in
    coremark)
      return $COREMARK
      ;;
    libavbench)
      return $LIBAVBENCH
      ;;
    gmpbench)
      return $GMPBENCH
      ;;
    gnugo)
      return $GNUGO
      ;;
    skiabench)
      return $SKIABENCH
      ;;
    denbench)
      return $DENBENCH
      ;;
    nbench)
      return $NBENCH
      ;;
    eembc)
      return $EEMBC
      ;;
    eembc_office)
      return $EEMBC_OFFICE
      ;;
    spec2k)
      return $SPEC2K
      ;;
    spec2006)
      return $SPEC2006
      ;;
  esac

  return 0
}

#
# $1 is the benchmark ID
#
bench_init()
{
  if test x"$1" = x; then
    echo "bench_init requires benchmark name as parameter"
    return 1
  fi
  case $1 in
    $COREMARK)
      coremark_init
      ;;
    $LIBAVBENCH)
      libavbench_init
      ;;
    $GMPBENCH)
      gmpbench_init
      ;;
    $GNUGO)
      gnugo_init
      ;;
    $SKIABENCH)
      skiabench_init
      ;;
    $DENBENCH)
      denbench_init
      ;;
    $NBENCH)
      nbench_init
      ;;
    $EEMBC)
      eembc_init
      ;;
    $EEMBC_OFFICE)
      eembc_office_init
      ;;
    $SPEC2K)
      spec2k_init
      ;;
    $SPEC2006)
      spec2006_init
      ;;
    *)
      return 1
      ;;
  esac

  return $?
}

#
# $1 is the benchmark ID
#
clean()
{
  if test x"$1" = x; then
    error "clean requires benchmark ID as parameter"
  fi
  case $1 in
    $COREMARK)
      coremark_clean
      ;;
    $LIBAVBENCH)
      libavbench_clean
      ;;
    $GMPBENCH)
      gmpbench_clean
      ;;
    $GNUGO)
      gnugo_clean
      ;;
    $SKIABENCH)
      skiabench_clean
      ;;
    $DENBENCH)
      denbench_clean
      ;;
    $NBENCH)
      nbench_clean
      ;;
    $EEMBC)
      eembc_clean
      ;;
    $EEMBC_OFFICE)
      eembc_office_clean
      ;;
    $SPEC2K)
      spec2k_clean
      ;;
    $SPEC2006)
      spec2006_clean
      ;;
    *)
      error "unknown ID"
      exit -1
  esac
  if test $? != 0 ; then
    error "clean failed"
    exit
  fi
}

#
# $1 is the benchmark ID
#
build()
{
  if test x"$1" = x; then
    error "build  requires benchmark ID as parameter"
  fi
  case $1 in
    $COREMARK)
      if test $_coremark_init; then
	coremark_build
      else
	error "coremark init not called"
	exit
      fi
      ;;
    $LIBAVBENCH)
      if test $_libavbench_init; then
	libavbench_build
      else
	error "libavbench init not called"
	exit
      fi
      ;;
    $GMPBENCH)
      if test $_gmpbench_init; then
	gmpbench_build
      else
	error "gmpbench init not called"
	exit
      fi
      ;;
    $GNUGO)
      if test $_gnugo_init; then
	gnugo_build
      else
	error "gnugo init not called"
	exit
      fi
      ;;
    $SKIABENCH)
      if test $_skiabench_init; then
	skiabench_build
      else
	error "skiabench init not called"
	exit
      fi
      ;;
    $DENBENCH)
      if test $_denbench_init; then
	denbench_build
      else
	error "denbench init not called"
	exit
      fi
      ;;
    $NBENCH)
      if test $_nbench_init; then
	nbench_build
      else
	error "nbench init not called"
	exit
      fi
      ;;
    $EEMBC)
      if test $_eembc_init; then
	eembc_build
      else
	error "eembc init not called"
	exit
      fi
      ;;
    $EEMBC_OFFICE)
      if test $_eembc_office_init; then
	eembc_office_build
      else
	error "eembc office init not called"
	exit
      fi
      ;;
    $SPEC2K)
      if test $_spec2k_init; then
	spec2k_build
      else
	error "spec2k init not called"
	exit
      fi
      ;;
    $SPEC2006)
      if test $_spec2006_init; then
	spec2006_build
      else
	error "spec2006 init not called"
	exit
      fi
      ;;
    *)
      error "unknown ID"
      exit -1
  esac
  if test $? != 0 ; then
    error "build failed"
    exit
  fi
}

#
# $1 is the benchmark ID
#
build_with_pgo()
{
  if test x"$1" = x; then
    error "build_with_pgo  requires benchmark ID as parameter"
  fi
  case $1 in
    $COREMARK)
      if test $_coremark_init; then
	coremark_build_with_pgo
      else
	error "coremark init not called"
	exit
      fi
      ;;
    $LIBAVBENCH)
      if test $_libavbench_init; then
	libavbench_build_with_pgo
      else
	error "libavbench init not called"
	exit
      fi
      ;;
    $GMPBENCH)
      if test $_gmpbench_init; then
	gmpbench_build_with_pgo
      else
	error "gmpbench init not called"
	exit
      fi
      ;;
    $GNUGO)
      if test $_gnugo_init; then
	gnugo_build_with_pgo
      else
	error "gnugo init not called"
	exit
      fi
      ;;
    $SKIABENCH)
      if test $_skiabench_init; then
	skiabench_build_with_pgo
      else
	error "skiabench init not called"
	exit
      fi
      ;;
    $DENBENCH)
      if test $_denbench_init; then
	denbench_build_with_pgo
      else
	error "denbench init not called"
	exit
      fi
      ;;
    $NBENCH)
      if test $_nbench_init; then
	nbench_build_with_pgo
      else
	error "nbench init not called"
	exit
      fi
      ;;
    $EEMBC)
      if test $_eembc_init; then
	eembc_build_with_pgo
      else
	error "eembc init not called"
	exit
      fi
      ;;
    $EEMBC_OFFICE)
      if test $_eembc_office_init; then
	eembc_office_build_with_pgo
      else
	error "eembc office init not called"
	exit
      fi
      ;;
    $SPEC2K)
      if test $_spec2k_init; then
	spec2k_build_with_pgo
      else
	error "spec2k init not called"
	exit
      fi
      ;;
    $SPEC2006)
      if test $_spec2006_init; then
	spec2006_build_with_pgo
      else
	error "spec2006 init not called"
	exit
      fi
      ;;
    *)
      error "unknown ID"
      exit -1
      ;;
  esac
  if test $? != 0 ; then
    error "build with pgo failed"
    exit
  fi
}

#
# $1 is the benchmark ID
#
run()
{
  if test x"$1" = x; then
    error "run requires benchmark ID as parameter"
  fi
  case $1 in
    $COREMARK)
      if test $_coremark_init; then
	coremark_run
      else
	error "coremark init not called"
	exit
      fi
      ;;
    $LIBAVBENCH)
      if test $_libavbench_init; then
	libavbench_run
      else
	error "libavbench init not called"
	exit
      fi
      ;;
    $GMPBENCH)
      if test $_gmpbench_init; then
	gmpbench_run
      else
	error "gmpbench init not called"
	exit
      fi
      ;;
    $GNUGO)
      if test $_gnugo_init; then
	gnugo_run
      else
	error "gnugo init not called"
	exit
      fi
      ;;
    $SKIABENCH)
      if test $_skiabench_init; then
	skiabench_run
      else
	error "skiabench init not called"
	exit
      fi
      ;;
    $DENBENCH)
      if test $_denbench_init; then
	denbench_run
      else
	error "denbench init not called"
	exit
      fi
      ;;
    $NBENCH)
      if test $_nbench_init; then
	nbench_run
      else
	error "nbench init not called"
	exit
      fi
      ;;
    $EEMBC)
      if test $_eembc_init; then
	eembc_run
      else
	error "eembc init not called"
	exit
      fi
      ;;
    $EEMBC_OFFICE)
      if test $_eembc_office_init; then
	eembc_office_run
      else
	error "eembc office init not called"
	exit
      fi
      ;;
    $SPEC2K)
      if test $_spec2k_init; then
	spec2k_run
      else
	error "spec2k init not called"
	exit
      fi
      ;;
    $SPEC2006)
      if test $_spec2006_init; then
	spec2006_run
      else
	error "spec2006 init not called"
	exit
      fi
      ;;
    *)
      error "unknown ID"
      exit -1
      ;;
  esac
  if test $? != 0 ; then
    error "run failed"
    exit
  fi
}

#
# $1 is the benchmark ID
#
install()
{
  if test x"$1" = x; then
    error "install requires benchmark ID as parameter"
  fi
  case $1 in
    $COREMARK)
      if test $_coremark_init; then
	coremark_install
      else
	error "coremark init not called"
	exit
      fi
      ;;
    $LIBAVBENCH)
      if test $_libavbench_init; then
	libavbench_install
      else
	error "libavbench init not called"
	exit
      fi
      ;;
    $GMPBENCH)
      if test $_gmpbench_init; then
	gmpbench_install
      else
	error "gmpbench init not called"
	exit
      fi
      ;;
    $GNUGO)
      if test $_gnugo_init; then
	gnugo_install
      else
	error "gnugo init not called"
	exit
      fi
      ;;
    $SKIABENCH)
      if test $_skiabench_init; then
	skiabench_install
      else
	error "skiabench init not called"
	exit
      fi
      ;;
    $DENBENCH)
      if test $_denbench_init; then
	denbench_install
      else
	error "denbench init not called"
	exit
      fi
      ;;
    $NBENCH)
      if test $_nbench_init; then
	nbench_install
      else
	error "nbench init not called"
	exit
      fi
      ;;
    $EEMBC)
      if test $_eembc_init; then
	eembc_install
      else
	error "eembc init not called"
	exit
      fi
      ;;
    $EEMBC_OFFICE)
      if test $_eembc_office_init; then
	eembc_office_install
      else
	error "eembc office init not called"
	exit
      fi
      ;;
    $SPEC2K)
      if test $_spec2k_init; then
	spec2k_install
      else
	error "spec2k init not called"
	exit
      fi
      ;;
    $SPEC2006)
      if test $_spec2006_init; then
	spec2006_install
      else
	error "spec2006 init not called"
	exit
      fi
      ;;
    *)
      error "unknown ID"
      exit -1
      ;;
  esac
  if test $? != 0 ; then
    error "install failed"
    exit
  fi
}

#
# $1 is the benchmark ID
#
testsuit()
{
  if test x"$1" = x; then
    error "testsuite requires benchmark ID as parameter"
  fi
  case $1 in
    $COREMARK)
      if test $_coremark_init; then
	coremark_testsuite
      else
	error "coremark init not called"
	exit
      fi
      ;;
    $LIBAVBENCH)
      if test $_libavbench_init; then
	libavbench_testsuite
      else
	error "libavbench init not called"
	exit
      fi
      ;;
    $GMPBENCH)
      if test $_gmpbench_init; then
	gmpbench_testsuite
      else
	error "gmpbench init not called"
	exit
      fi
      ;;
    $GNUGO)
      if test $_gnugo_init; then
	gnugo_testsuite
      else
	error "gnugo init not called"
	exit
      fi
      ;;
    $SKIABENCH)
      if test $_skiabench_init; then
	skiabench_testsuite
      else
	error "skiabench init not called"
	exit
      fi
      ;;
    $DENBENCH)
      if test $_denbench_init; then
	denbench_testsuite
      else
	error "denbench init not called"
	exit
      fi
      ;;
    $NBENCH)
      if test $_nbench_init; then
	nbench_testsuite
      else
	error "nbench init not called"
	exit
      fi
      ;;
    $EEMBC)
      if test $_eembc_init; then
	eembc_testsuite
      else
	error "eembc init not called"
	exit
      fi
      ;;
    $EEMBC_OFFICE)
      if test $_eembc_office_init; then
	eembc_office_testsuite
      else
	error "eembc office init not called"
	exit
      fi
      ;;
    $SPEC2K)
      if test $_spec2k_init; then
	spec2k_testsuite
      else
	error "spec2k init not called"
	exit
      fi
      ;;
    $SPEC2006)
      if test $_spec2006_init; then
	spec2006_testsuite
      else
	error "spec2006 init not called"
	exit
      fi
      ;;
    *)
      error "unknown ID"
      exit -1
      ;;
  esac
  if test $? != 0 ; then
    error "testsuite failed"
    exit
  fi
}

#
# $1 is the benchmark ID
#
extract()
{
  if test x"$1" = x; then
    error "extract  requires benchmark ID as parameter"
  fi
  case $1 in
    $COREMARK)
      if test $_coremark_init; then
	coremark_extract
      else
	error "coremark init not called"
	exit
      fi
      ;;
    $LIBAVBENCH)
      if test $_libavbench_init; then
	libavbench_extract
      else
	error "libavbench init not called"
	exit
      fi
      ;;
    $GMPBENCH)
      if test $_gmpbench_init; then
	gmpbench_extract
      else
	error "gmpbench init not called"
	exit
      fi
      ;;
    $GNUGO)
      if test $_gnugo_init; then
	gnugo_extract
      else
	error "gnugo init not called"
	exit
      fi
      ;;
    $SKIABENCH)
      if test $_skiabench_init; then
	skiabench_extract
      else
	error "skiabench init not called"
	exit
      fi
      ;;
    $DENBENCH)
      if test $_denbench_init; then
	denbench_extract
      else
	error "denbench init not called"
	exit
      fi
      ;;
    $NBENCH)
      if test $_nbench_init; then
	nbench_extract
      else
	error "nbench init not called"
	exit
      fi
      ;;
    $EEMBC)
      if test $_eembc_init; then
	eembc_extract
      else
	error "eembc init not called"
	exit
      fi
      ;;
    $EEMBC_OFFICE)
      if test $_eembc_office_init; then
	eembc_office_extract
      else
	error "eembc office init not called"
	exit
      fi
      ;;
    $SPEC2K)
      if test $_spec2k_init; then
	spec2k_extract
      else
	error "spec2k init not called"
	exit
      fi
      ;;
    $SPEC2006)
      if test $_spec2006_init; then
	spec2006_extract
      else
	error "spec2006 init not called"
	exit
      fi
      ;;
    *)
      error "unknown ID"
      exit -1
      ;;
  esac
  if test $? != 0 ; then
    error "extract failed"
    exit
  fi
}

set_gcc_to_runwith ()
{
  if test x"$1" = x; then
    error "set_gcc_to_runwith called without an argument!"
    return 1
  fi
  dir=$1
  if test -d $dir/bin; then
    #
    # Set the environment for a gcc-binary based build
    #
    export PATH=$dir/bin:$PATH
    export LD_LIBRARY_PATH=$dir/lib32:$dir/lib
    # Work around multiarch library paths
    export LIBRARY_PATH=/usr/lib/$(dpkg-architecture -qDEB_BUILD_MULTIARCH)
  else
    error "runwith gcc directory doesnot have bin directory!"
    exit -1
  fi
}

get_benchmark ()
{
  if test x$1 != x; then
    echo "fetching $1 into $2"
    cp $1 $2/
  fi
}

dump_host_info ()
{
  echo "GCCVERSION=`${CROSS_COMPILE}gcc --version | head -n1`"
  echo "GXXVERSION=`${CROSS_COMPILE}g++ --version | head -n1`"
  echo "DATE=`date +%Y-%m-%d`"
  echo "ARCH=`uname -m`"
  echo "CPU=`grep -E "^(model name|Processor)" /proc/cpuinfo | head -n1 | tr -s [:space:] | awk -F: '{print $2;}'`"
  echo "OS=`lsb_release -sd`"
  echo "TOPDIR=`pwd`"
  echo "date:`date --rfc-3339=seconds -u`"
  echo
  echo "uname:`uname -a`"
  echo
  echo lsb_release:
  lsb_release -a
  echo
  echo /proc/version:
  cat /proc/version
  echo
  echo "gcc: `dpkg -s gcc | grep ^Version`"
  gcc --version
  echo "as: `dpkg -s binutils | grep ^Version`"
  as --version
  echo
  echo ldd:
  ldd --version
  echo
  echo free:
  free
  echo
  echo ulimit:
  bash -c "ulimit -a"
  echo
  echo cpuinfo:
  cat /proc/cpuinfo
  echo gdb:
  dpkg -s gdb | grep ^Version
  gdb --version
  echo gcc-binary:
  #$(PWD)/$(@D)/gcc-binary/bin/gcc --version || true
  echo
  echo libc6:
  dpkg -s libc6 | grep ^Version
  echo PATH:
  echo $PATH
  echo
  echo cpufreq-info:
  echo `cpufreq-info`
  echo
 }
