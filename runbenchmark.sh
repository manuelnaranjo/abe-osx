#!/bin/bash

# load the configure file produced by configure
if test -e "`dirname $0`/host.conf"; then
    . "`dirname $0`/host.conf"
else
    echo "WARNING: no host.conf file!  Did you run configure?" 1>&2
fi

# load commonly used functions
script="`which $0`"
topdir="`dirname ${script}`"
app="`basename $0`"

. "${topdir}/lib/common.sh" || exit 1
. "${topdir}/lib/benchmark.sh" || exit 1

usage()
{
  # Format this section with 75 columns.
  cat << EOF
  ${app}	[-b, --build]
  [-r, --run]
  [-c, --clean]
  [-x, --extract]
  [-l, --list-of-benchmarks=benchmark1,benchmark2..]
  [-t, --gcc-binary-tarball=tarball]
  [-d, --dir-to-build=directory]
  [    --extract-dir=directory]
  [-C, --additional-cflags]
  [-L, --aditional-lflags]
  [    --controlled]
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
	       to extract, clean, build and run the benchmark list.

  -r, --run
	       Just run the benchmarks. Default behavior is
	       to extract, clean, build and run the benchmark list.

  -c, --clean
	       Just clean the benchmarks. Default behavior is
	       to extract, clean, build and run the benchmark list.

  -x, --extract
               Just extract the benchmarks. Default behavior is
	       to extract, clean, build and run the benchmark list.

  -l, --list-of-benchmarks=benchmark1,benchmark2..
	       Specify the list of benchmarks to run,

  -p, --gcc-binary-path=path
               Spevify the precompiled gcc path to use for
	       compiling benchmarks.

  -d, --dir-to-build=directory
	       Specify the path of directory in which bennchrks
	       should be placed and executed.

  --extract-dir=directory
               Specify the path of directory from which benchmarks
               should be extracted.

  -C, --additional-cflags
	       Additional CFLAGS for compiling benchmarks.

  -L, --aditional-lflags
	       Additional LFLAGS for linking benchmarks.

  --controlled
               Minimise sources of noise during run
               E.G. Shuts down unneeded services, shunts remaining
               services to a second CPU, shuts down network.

EXAMPLES

  Clean, build and run eembc without extracting:

    runbenchmark.sh -l=eembc -c -b -r

  Run spec2k in a controlled way:

    runbenchmark.sh -l=spec2k --controlled


PRECONDITION FILES

AUTHOR
  Kugan Vivekanandarajah <kuganv@linaro.org>
  Bernard Ogden <bernie.ogden@linaro.org>

EOF
    return 0
}

extract=false
clean=false
build=false
run=false
build_pgo=false
controlled=false

while :
do
  case $1 in
    -h | --help | -\?)
      help
      exit 0
      ;;
    --controlled)
      controlled=true
      shift
      ;;
    -x | --extract)
      extract=true
      shift
      ;;
    -b | --build)
      clean=true
      extract=true
      build=true
      shift
      ;;
    -c | --clean)
      extract=true
      clean=true
      shift
      ;;
    -r | --run)
      extract=true
      clean=true
      build=true
      run=true
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
    --pgo)
      build_pgo=true
      shift
      ;;
    --file=*)
      file=${1#*=}        # Delete everything up till "="
      shift
      ;;
    -x=* | --extract-dir==*)
      SRC_PATH=${1#*=}
      shift
      ;;
    --) # End of all options
      shift
      break
      ;;
    -*)
      warning "Unknown option (ignored): $1" >&2
      shift
      ;;
    *)  # no more options. Stop while loop
      break
      ;;
  esac
done

if test x"$list" = x; then
  error "Benchmark list is empty"
  exit 1
fi
if test x"$list" = xall; then
  list=coremark,gmpbench,gnugo,skiabench,denbench,eembc,spec2k,libavbench,eembc_office,nbench
fi

$extract || $clean || $build || $run || { extract=true;clean=true;build=true;run=true; }

#Cribbed from abe.sh
#TODO: Push this change back to last merge? Not really needed if I submit generated patches.
#      But may still be worth it for my sanity.
make_docs=no
install=no

#TODO How does primary abe do this?
dump_host_info  > host.txt
#fetch md5sums

for b in ${list//,/ };
do
  if $extract; then
    echo "Extract benchmark $b"
    url="`get_source $b`"
    if test $? -gt 0; then
      error "Couldn't find the source for ${do_checkout}"
      build_failure
    fi
    checkout ${url}
    if test $? -gt 0; then
      error "--checkout ${url} failed."
      build_failure
    fi
  fi

#TODO is this actually doing anything when we started from fresh checkout?
#TODO clean seems to need to run as part of 'build', fix that up so that I can run it (if I can't already)
  #if $clean; then
  #  echo "Clean benchmark $b"
  #  make_clean $b || exit
  #fi

  #TODO Delete the PGO part unless we find a benchmark that actually uses it
  if $build; then
    if $build_pgo; then
      echo "Build benchmark $b with pgo"
      build_with_pgo $ctx || exit
    else
      echo "Build benchmark $b"
      build $b || exit
    fi
  fi

  if $run; then
    echo "Run benchmark $b"
    bench_run $b $controlled || exit
  fi
done
