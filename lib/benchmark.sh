
#!/bin/sh

#
# $1 benchamark name coremark, etc
#


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

TIME=time


bench_init()
{
  if test x"$1" = x; then
    echo "bench_init requires benchmark name as parameter"
    retuen 0
  fi
  case $1 in
    coremark)
      echo "Coremark"
      coremark_init
      return $COREMARK
      ;;
    libavbench)
      echo "Libavbench"
      libavbench_init
      return $LIBAVBENCH
      ;;
    gmpbench)
      echo "Gmpbench"
      gmpbench_init
      return $GMPBENCH
      ;;
    gnugo)
      echo "Gnugo"
      gnugo_init
      return $GNUGO
      ;;
    skiabench)
      echo "Skiabench"
      skiabench_init
      return $SKIABENCH
      ;;
    denbench)
      denbench_init
      return $DENBENCH
      ;;
    eembc)
      eembc_init
      return $EEMBC
      ;;
    eembc_office)
      eembc_office_init
      return $EEMBC_OFFICE
      ;;
    spec2k)
      echo "Spec2k"
      spec2k_init
      return $SPEC2K
      ;;
  esac

  return 0
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
    $DEBENCH)
      denbench_clean
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
    *)
      error "unknown ID"
      exit -1
  esac
}

#
# $1 is the benchmark ID
#

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
      coremark_build
      ;;
    $LIBAVBENCH)
      libavbench_build
      ;;
    $GMPBENCH)
      gmpbench_build
      ;;
    $GNUGO)
      gnugo_build
      ;;
    $SKIABENCH)
      skiabench_build
      ;;
    $DEBENCH)
      denbench_build
      ;;
    $EEMBC)
      eembc_build
      ;;
    $EEMBC_OFFICE)
      eembc_office_build
      ;;
    $SPEC2K)
      spec2k_build
      ;;
    *)
      error "unknown ID"
      exit -1
  esac
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
      coremark_build_with_pgo
      ;;
    $LIBAVBENCH)
      libavbench_build_with_pgo
      ;;
    $GMPBENCH)
      gmpbench_build_with_pgo
      ;;
    $GNUGO)
      gnugo_build_with_pgo
      ;;
    $SKIABENCH)
      skiabench_build_with_pgo
      ;;
    $DEBENCH)
      denbench_build_with_pgo
      ;;
    $EEMBC)
      eembc_build_with_pgo
      ;;
    $EEMBC_OFFICE)
      eembc_office_build_with_pgo
      ;;
    $SPEC2K)
      spec2k_build_with_pgo
      ;;
    *)
      error "unknown ID"
      exit -1
  esac
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
      coremark_run
      ;;
    $LIBAVBENCH)
      libavbench_run
      ;;
    $GMPBENCH)
      gmpbench_run
      ;;
    $GNUGO)
      gnugo_run
      ;;
    $SKIABENCH)
      skiabench_run
      ;;
    $DEBENCH)
      denbench_run
      ;;
    $EEMBC)
      eembc_run
      ;;
    $EEMBC_OFFICE)
      eembc_office_run
      ;;
    $SPEC2K)
      spec2k_run
      ;;
    *)
      error "unknown ID"
      exit -1
  esac
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
      coremark_install
      ;;
    $LIBAVBENCH)
      libavbench_install
      ;;
    $GMPBENCH)
      gmpbench_install
      ;;
    $GNUGO)
      gnugo_install
      ;;
    $SKIABENCH)
      skiabench_install
      ;;
    $DEBENCH)
      denbench_install
      ;;
    $EEMBC)
      eembc_install
      ;;
    $EEMBC_OFFICE)
      eembc_office_install
      ;;
    $SPEC2K)
      spec2k_install
      ;;
    *)
      error "unknown ID"
      exit -1
  esac
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
      coremark_testsuite
      ;;
    $LIBAVBENCH)
      libavbench_testsuite
      ;;
    $GMPBENCH)
      gmpbench_testsuite
      ;;
    $GNUGO)
      gnugo_testsuite
      ;;
    $SKIABENCH)
      skiabench_testsuite
      ;;
    $DEBENCH)
      denbench_testsuite
      ;;
    $EEMBC)
      eembc_testsuite
      ;;
    $EEMBC_OFFICE)
      eembc_office_testsuite
      ;;
    $SPEC2K)
      spec2k_testsuite
      ;;
    *)
      error "unknown ID"
      exit -1
  esac
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
      coremark_extract
      ;;
    $LIBAVBENCH)
      libavbench_extract
      ;;
    $GMPBENCH)
      gmpbench_extract
      ;;
    $GNUGO)
      gnugo_extract
      ;;
    $SKIABENCH)
      skiabench_extract
      ;;
    $DEBENCH)
      denbench_extract
      ;;
    $EEMBC)
      eembc_extract
      ;;
    $EEMBC_OFFICE)
      eembc_office_extract
      ;;
    $SPEC2K)
      spec2k_extract
      ;;
    *)
      error "unknown ID"
      exit -1
  esac
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
  fi
}

get_becnhmark ()
{
  if test x$1 != x; then
    echo "fetching $1 into $2"
    cp $1 $2/
  fi
}

dump_host_info ()
{
  GCCVERSION = $(shell $(CROSS_COMPILE)gcc --version | head -n1)
  GXXVERSION = $(shell $(CROSS_COMPILE)g++ --version | head -n1)
  DATE = $(shell date +%Y-%m-%d)
  ARCH = $(shell uname -m)
  CPU = $(shell grep -E "^(model name|Processor)" /proc/cpuinfo | head -n1 | tr -s [:space:] | awk -F: '{print $$2;}')
  OS = $(shell lsb_release -sd)
  TOPDIR = $(shell pwd)
  echo date:
  date --rfc-3339=seconds -u
  echo
  echo uname:
  uname -a
  echo
  echo lsb_release:
  lsb_release -a
  echo
  echo /proc/version:
  cat /proc/version
  echo
  echo gcc:
  dpkg -s gcc | grep ^Version
  gcc --version
  echo as:
  dpkg -s binutils | grep ^Version
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
  echo df:
  echo `df -h / /scratch`
  echo
  echo cpufreq-info:
  echo `cpufreq-info`
  echo
 }
