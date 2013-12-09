
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
SPEC2000=13


bench_init()
{
  if test x"$1" = x; then
    echo "bench_init  requires benchmark name as parameter"
    retuen 0
  fi
  case $1 in
    coremark)
      echo "Coremark"
      coremark_init 
      return $COREMARK
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
    error "clean  requires benchmark ID as parameter"
  fi
  case $1 in
    $COREMARK)
      clean
      ;;
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

dump_host_info ()
{
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
