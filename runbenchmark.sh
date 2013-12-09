
#!/bin/bash

# load commonly used functions
script="`which $0`"
topdir="`dirname ${script}`"
app="`basename $0`"

. "${topdir}/lib/common.sh" || exit 1
. "${topdir}/lib/coremark.sh" || exit 1
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

  -t, --gcc-binary-tarball=tarball
               Spevify the precompiled gcc tarball to use for
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

clean=true
build=true
run=true

while :
do
  case $1 in
    -h | --help | -\?)
      uasge
      help
      exit 0
      ;;
    -b | --build)
      run=false
      shift
      ;;
    -c | --clean)
      run=false
      build=false
      shift
      ;;
    -r | --run)
      clean=false
      build=false
      shift
      ;;
    -l=* | --list=*)
      list=${1#*=}
      shift
      ;;
    -C=* | --additional-cflags=*)
      CFLAGS=${1#*=}
      shift
      ;;
    -L=* | --aditional-lflags=*)
      LFLAGS=${1#*=}
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
      echo "WARN: Unknown option (ignored): $1" >&2
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

for b in ${list//,/ };
do
  echo $b;
  bench_init $b
  ctx=$?
  if test $ctx = 0; then
    error "Unrecognized benchmark name $b"
  fi

  if $clean; then
    echo "Clean benchmark $b"
    clean $ctx
  else
    echo "Extract benchmark $b"
    extract $ctx
  fi

  if $build; then
    echo "Build benchmark $b"
    build $ctx
  fi

  if $run; then
    echo "Run benchmark $b"
    run $ctx
  fi

done
