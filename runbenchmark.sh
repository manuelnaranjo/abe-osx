
#!/bin/bash

# load commonly used functions
script="`which $0`"
topdir="`dirname ${script}`"
app="`basename $0`"

. "${topdir}/lib/common.sh" || exit 1
. "${topdir}/lib/benchmark_common.sh" || exit 1
. "${topdir}/lib/libavbench.sh" || exit 1
. "${topdir}/lib/gmpbench.sh" || exit 1
. "${topdir}/lib/coremark.sh" || exit 1
. "${topdir}/lib/gnugo.sh" || exit 1
. "${topdir}/lib/spec2k.sh" || exit 1
. "${topdir}/lib/spec2006.sh" || exit 1
. "${topdir}/lib/denbench.sh" || exit 1
. "${topdir}/lib/eembc.sh" || exit 1
. "${topdir}/lib/eembc_office.sh" || exit 1
. "${topdir}/lib/nbench.sh" || exit 1
. "${topdir}/lib/skiabench.sh" || exit 1
. "${topdir}/lib/benchmark.sh" || exit 1

usage()
{
  # Format this section with 75 columns.
  cat << EOF
  ${app}	[-b, --build]
  [-r, --run]
  [-c, --clean]
  [-l, --list-of-benchmarks=benchmark1,benchmark2..]
  [-t, --gcc-binary-tarball=tarball]
  [-d, --dir-to-build=directory]
  [-C, --additional-cflags]
  [-L, --aditional-lflags]
EOF
  return 0
}

setup_cpu()
{
  sudo cpufreq-set -g performance
  for p in `(ps ax --format='%p' | tail -n +2)`; do
    sudo taskset -a -p 0x1 $p 2>&1;
  done
}

restore_cpu()
{
  for p in `(ps ax --format='%p' | tail -n +2)`; do
    sudo taskset -a -p 0xFFFFFFFF $p 2>&1;
  done
  sudo cpufreq-set -g  conservative
}

help()
{
  # Format this section with 75 columns.
  cat << EOF
  NAME

  ${app} - the Linaro Toolchain Becnhmarking Framework.

  SYNOPSIS

EOF
    usage
    cat << EOF

DESCRIPTION

  ${app} is a toolchain benchmarking framework.

PRECONDITIONS

  FIXME

OPTIONS

  -b, --build
	       Just build the benchmarks. Default behavior is
	       to clean, build and run the benchmark list.

  -r, --run
	       Just run the benchmarks. Default behavior is
	       to clean, build and run the benchmark list.

  -c, --clean
	       Just clean the benchmarks. Default behavior is
	       to clean, build and run the benchmark list.

  -l, --list-of-benchmarks=benchmark1,benchmark2..
	       Specify the list of benchmarks to run,

  -p, --gcc-binary-path=path
               Spevify the precompiled gcc path to use for
	       compiling benchmarks.

  -d, --dir-to-build=directory
	       Specify the path of directory in which bennchrks
	       should be placed and executed.

  -C, --additional-cflags
	       Additional CFLAGS for compiling benchmarks.

  -L, --aditional-lflags
	       Additional LFLAGS for linking benchmarks.

EXAMPLES


PRECONDITION FILES

AUTHOR
  Kugan Vivekanandarajah <kuganv@linaro.org>

EOF
    return 0
}

extract=true
clean=true
build=true
run=true
build_pgo=false

while :
do
  case $1 in
    -h | --help | -\?)
      uasge
      help
      exit 0
      ;;
    -b | --build)
      extract=false
      run=false
      shift
      ;;
    -c | --clean)
      extract=false
      run=false
      build=false
      shift
      ;;
    -r | --run)
      extract=false
      clean=false
      build=false
      shift
      ;;
    -l=* | --list=*)
      list=${1#*=}
      shift
      ;;
    -C=* | --additional-cflags=*)
      XCFLAGS=${1#*=}
      shift
      ;;
    -L=* | --aditional-lflags=*)
      XLFLAGS=${1#*=}
      shift
      ;;
    -p=* | --gcc-binary-path)
      GCC_PATH=${1#*=}
      shift
      ;;
    --pgo)
      build_pgo=true
      shift
      ;;
    --file=*)
      file=${1#*=}        # Delete everything up till "="
      shift
      ;;
    --) # End of all options
      shift
      break
      ;;
    -*)
      warn "Unknown option (ignored): $1" >&2
      shift
      ;;
    *)  # no more options. Stop while loop
      break
      ;;
  esac
done

if test x"$list" = x; then
  error "Benchmark list is empty"
fi
if test x"$list" = xall; then
  list=coremark,gmpbench,gnugo,skiabench,denbench,eembc,spec2k,libavbench,eembc_office,nbench
#  list=coremark,libavbench,gmpbench,gnugo,skiabench,denbench,eembc,eembc_office,spec2k,nbench
fi

if test "x$GCC_PATH" != x; then
  set_gcc_to_runwith "$GCC_PATH" 
fi

dump_host_info  > host.txt

for b in ${list//,/ };
do
  echo $b;
  bench_init $b
  ctx=$?
  if test $ctx = 0; then
    error "Unrecognized benchmark name $b"
  fi

  if $extract; then
    echo "Extract benchmark $b"
    extract $ctx
  fi

  if $clean; then
    echo "Clean benchmark $b"
    clean $ctx
  fi

  if $build; then
    if $build_pgo; then
      echo "Build benchmark $b with pgo"
      build_with_pgo $ctx
    else
      echo "Build benchmark $b"
      build $ctx
    fi
  fi

  if $run; then
    echo "Run benchmark $b"
    run $ctx
  fi
done
