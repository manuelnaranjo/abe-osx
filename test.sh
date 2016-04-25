#!/bin/bash

# Improve debug logs
PRGNAME=`basename $0`
PS4='+ $PRGNAME: ${FUNCNAME+"$FUNCNAME : "}$LINENO: '

testabe="`basename $0`"
topdir=`dirname $0`
abe_path=`readlink -f ${topdir}`
export abe_path

# Source common.sh for some common utilities.
. ${abe_path}/lib/common.sh || exit 1

# We use a tmp/ directory for the builddir in order that we don't pollute the
# srcdir or an existing builddir.
tmpdir=`mktemp -d /tmp/abe.$$.XXX`
if test "$?" -gt 0; then
    error "mktemp of ${tmpdir} failed."
    exit 1
fi

# Log files for abe test runs are dumped here.
testlogs=${tmpdir}/testlogs
mkdir -p ${testlogs}
if test "$?" -gt 0; then
    error "couldn't create '${testlogs}' directory."
    exit 1
fi

runintmpdir=
# If the current working directory has a host.conf in it we assume it's an
# existing build dir, otherwise we're in the srcdir so we need to run
# configure in the tmpdir and run the tests from there.
if test ! -e "${PWD}/host.conf"; then
    (cd ${tmpdir} && ${abe_path}/configure --with-sources-conf=${abe_path}/testsuite/test_sources.conf --with-remote-snapshots=snapshots-ref)
    # Run it once outside of dryrun mode so that we pull the md5sums file.
    (cd ${tmpdir} && ${abe_path}/abe.sh --space 4096)
    runintmpdir=yes
else
    # copy the md5sums file from the existing snapshots directory to the new local_snapshots directory.

    # Override $local_snapshots so that the local_snapshots directory of an
    # existing build is not moved or damaged.  This affects all called
    # instances of abe.sh below.
    export local_snapshots="${tmpdir}/snapshots"
    out="`mkdir -p ${local_snapshots}`"
    if test "$?" -gt 0; then
        error "couldn't create '${local_snapshots}' directory."
        exit 1
    fi
    # Override the existing sources_conf setting in host.conf.
    export sources_conf=${abe_path}testsuite/test_sources.conf
fi

export wget_quiet=yes

usage()
{
    echo "  ${testabe} [--debug|-v]"
    echo "                 [--md5sums <path/to/alternative/snapshots/md5sums>]"
    echo ""
    echo "  ${testabe} is the abe frontend command conformance test."
    echo ""
    echo " ${testabe} should be run from the source directory."
}

passes=0

pass()
{
    local testlineno=$1
    if test x"${debug}" = x"yes"; then
	echo -n "($testlineno) " 1>&2
    fi
    echo "PASS: '$2'"
    passes="`expr ${passes} + 1`"
}

failures=0
fail()
{
    local testlineno=$1
    if test x"${debug}" = x"yes"; then
	echo -n "($testlineno) " 1>&2
    fi
    echo "FAIL: '$2'"
    failures="`expr ${failures} + 1`"
}

totals()
{
    echo ""
    echo "Total test results:"
    echo "	Passes: ${passes}"
    echo "	Failures: ${failures}"
}



cbtest()
{
    local testlineno=$1
    if test x"${debug}" = x"yes"; then
	echo "($testlineno) out: $2" 1>&2
    fi

    case "$2" in
	*$3*)
	    pass ${testlineno} "$4"
	    ;;
	*)
	    fail ${testlineno} "$4"
	    ;;
    esac

    if test x"${debug}" = x"yes"; then
	echo "-----------" 1>&2
    fi
}

m5sums=
debug=
while test $# -gt 0; do
    case "$1" in
	--h*|-h)
	    usage
	    exit 1
	    ;;
	--deb*|-deb|-v)
	    debug="yes"
	    ;;
	--md5*|-md5*)
	    if test `echo $1 | grep -c "\-md5.*="` -gt 0; then
		error "A '=' is invalid after --md5sums. A space is expected."
		exit 1;
	    fi
	    if test -z $2; then
		error "--md5sums requires a path to an md5sums file."
		exit 1;
	    fi 
	    md5sums=$2
	    if test ! -e "$md5sums"; then
		error "Path to md5sums is invalid."
		exit 1;
	    fi
	    echo "Copying ${md5sums} to ${local_snapshots} for snapshots file."
	    cp ${md5sums} ${local_snapshots}
	    ;; 
	*)
	    ;;
    esac

    if test $# -gt 0; then
	shift
    fi
done

test_failure()
{
    local testlineno=$BASH_LINENO
    local cb_commands=$1
    local match=$2
    local out=

    out="`(${runintmpdir:+cd ${tmpdir}} && ${abe_path}/abe.sh --space 4960 ${cb_commands} 2>&1 | tee ${testlogs}/${testlineno}.log | grep "${match}" | sed -e 's:\(^ERROR\).*\('"${match}"'\).*:\1 \2:')`"
    cbtest ${testlineno} "${out}" "ERROR ${match}" "ERROR ${cb_commands}"
}

test_pass()
{
    local testlineno=$BASH_LINENO
    local cb_commands=$1
    local match=$2
    local out=

    # Continue to search for error so we don't get false positives.
    out="`(${runintmpdir:+cd ${tmpdir}} && ${abe_path}/abe.sh --space 4960 ${cb_commands} 2>&1 | tee ${testlogs}/${testlineno}.log | grep "${match}" | sed -e 's:\(^ERROR\).*\('"${match}"'\).*:\1 \2:')`"
    cbtest ${testlineno} "${out}" "${match}" "VALID ${cb_commands}"
}

test_config_default()
{
  local feature="$1"
  local feature_match="$2"
  local skip_match="$3"
  local perform_match="$4"

  # If we're running in an existing build directory we don't know WHAT the
  # user has set as the default so we set it to 'yes' explicity, and preserve
  # the original.
  indir=${PWD}
  if test x"${runintmpdir}" != x""; then
    indir=${tmpdir}
  fi
  cp ${indir}/host.conf ${indir}/host.conf.orig
  trap "cp ${indir}/host.conf.orig ${indir}/host.conf" EXIT

  sed -i -e "s/^${feature}=.*/${feature}=yes/" "${indir}/host.conf"

  # The default.
  cb_commands="--dump"
  match="${feature_match} *yes"
  test_pass "${cb_commands}" "${match}"

  cb_commands="--dump --disable ${feature}"
  match="${feature_match} *no"
  test_pass "${cb_commands}" "${match}"

  # Change the configured default to 'no'
  sed -i -e "s/${feature}=.*/${feature}=no/" "${indir}/host.conf"

  # Verify that it's now 'no'
  cb_commands="--dump"
  match="${feature_match} *no"
  test_pass "${cb_commands}" "${match}"

  # Verify that 'enable ${feature}' now works.
  cb_commands="--dump --enable ${feature}"
  match="${feature_match} *yes"
  test_pass "${cb_commands}" "${match}"

  mv ${indir}/host.conf.orig ${indir}/host.conf
  trap - EXIT

  # Let's make sure the stage is actually skipped.
  # --force makes sure we run through to the stage even
  # if the builddir builds stamps are new.
  cb_commands="--dryrun --force --target arm-linux-gnueabihf --disable ${feature} --build all"
  test_pass "${cb_commands}" "${skip_match}"

  # Let's make sure the stage is actually NOT skipped.
  # --force makes sure we run through to the stage even
  # if the builddir builds stamps are new.
  cb_commands="--dryrun --force --target arm-linux-gnueabihf --enable ${feature} --build all"
  test_pass "${cb_commands}" "${perform_match}"
}

cb_commands="--dry-run"
match=''
test_pass "${cb_commands}" "${match}"

cb_commands="--dryrun"
match=''
test_pass "${cb_commands}" "${match}"

cb_commands="--dry"
match=''
test_pass "${cb_commands}" "${match}"

cb_commands="-dry"
match=''
test_pass "${cb_commands}" "${match}"

cb_commands="--dr"
match="Directive not supported"
test_failure "${cb_commands}" "${match}"

cb_commands="-dr"
match="Directive not supported"
test_failure "${cb_commands}" "${match}"

cb_commands="--drnasdfa"
match="Directive not supported"
test_failure "${cb_commands}" "${match}"

# Test for expected failure for removed deprecated feature --dostep.
cb_commands="--dostep"
match="Directive not supported"
test_failure "${cb_commands}" "${match}"

# Test for expected failure for --libc=<foo>
# https://bugs.linaro.org/show_bug.cgi?id=1372
cb_commands="--libc"
match="Directive not supported"
test_failure "${cb_commands}" "${match}"

# Test for expected failure for --libc=<foo>
# https://bugs.linaro.org/show_bug.cgi?id=1372
cb_commands="--libc="
match="Directive not supported"
test_failure "${cb_commands}" "${match}"

# Test for expected failure for unknown toolchain component
# https://bugs.linaro.org/show_bug.cgi?id=1372
cb_commands="libc="
match="Component specified not supported"
test_failure "${cb_commands}" "${match}"

# Test for non-directive dangling command
# https://bugs.linaro.org/show_bug.cgi?id=1372
cb_commands="libc"
match="Command not recognized"
test_failure "${cb_commands}" "${match}"

cb_commands="--target=foo"
match="A space is expected"
test_failure "${cb_commands}" "${match}"

cb_commands="--target"
match="target requires a directive"
test_failure "${cb_commands}" "${match}"

cb_commands="--timeout"
match="timeout requires a directive"
test_failure "${cb_commands}" "${match}"

cb_commands="--timeout=foo"
match="A space is expected"
test_failure "${cb_commands}" "${match}"

cb_commands="--timeout 25"
match=''
test_pass "${cb_commands}" "${match}"

cb_commands="--target foo"
match=''
test_pass "${cb_commands}" "${match}"

cb_commands="--build=all"
match="A space is expected"
test_failure "${cb_commands}" "${match}"

cb_commands="--dryrun --build --foobar"
match="found the next"
test_failure "${cb_commands}" "${match}"

cb_commands="--dryrun --build"
match="requires a directive"
test_failure "${cb_commands}" "${match}"

cb_commands="--checkout"
match="requires a directive"
test_failure "${cb_commands}" "${match}"

cb_commands="--checkout=all"
match="A space is expected"
test_failure "${cb_commands}" "${match}"

cb_commands="--checkout --all"
match="found the next"
test_failure "${cb_commands}" "${match}"

cb_commands="--checkout --foo"
match="found the next"
test_failure "${cb_commands}" "${match}"

cb_commands="--dryrun --checkout all"
match=''
test_pass "${cb_commands}" "${match}"

cb_commands="--dryrun --checkout gcc.git"
match=''
test_pass "${cb_commands}" "${match}"

cb_commands="--dryrun --target arm-linux-gnueabihf --checkout glibc.git"
match=''
test_pass "${cb_commands}" "${match}"

cb_commands="--dryrun --target arm-linux-gnueabihf --checkout=glibc.git"
match="A space is expected"
test_failure "${cb_commands}" "${match}"

cb_commands="--dryrun --target arm-linux-gnueabihf --checkout all"
match=''
test_pass "${cb_commands}" "${match}"

cb_commands="--set=libc=glibc"
match="A space is expected"
test_failure "${cb_commands}" "${match}"

cb_commands="--set"
match="requires a directive"
test_failure "${cb_commands}" "${match}"

cb_commands="--release=foobar"
match="A space is expected"
test_failure "${cb_commands}" "${match}"

cb_commands="--release"
match="requires a directive"
test_failure "${cb_commands}" "${match}"

target="aarch64-none-elf"
libc="foo"
cb_commands="--target ${target} --set libc=${libc}"
match="set_package"
test_failure "${cb_commands}" "${match}"

target="aarch64-none-elf"
libc="glibc"
cb_commands="--target ${target} --set libc=${libc}"
match="crosscheck_clibrary_target"
test_failure "${cb_commands}" "${match}"

target="aarch64-none-elf"
libc="glibc"
cb_commands="--target ${target} --set libc=${libc}"
match="crosscheck_clibrary_target"
test_failure "${cb_commands}" "${match}"

target="aarch64-none-elf"
# A baremetal target should pick the right clibrary (newlib)
cb_commands="--target ${target}"
match=''
test_pass "${cb_commands}" "${match}"

target="aarch64-none-elf"
# A baremetal target should pick the right clibrary (newlib)
cb_commands="--target ${target} --dump"
match='newlib'
test_pass "${cb_commands}" "${match}"

target="armeb-linux-gnueabihf"
# A baremetal target should pick the right clibrary (newlib)
cb_commands="--target ${target} --dump"
match='glibc'
test_pass "${cb_commands}" "${match}"

target="armeb-linux-gnueabihf"
# A baremetal target should pick the right clibrary (newlib)
cb_commands="--target ${target} --dump"
match='glibc'
test_pass "${cb_commands}" "${match}"

target="armeb-linux-gnueabi"
cb_commands="--target ${target} --dump"
match='glibc'
test_pass "${cb_commands}" "${match}"

target="armeb-linux-gnueabi"
cb_commands="--target ${target} --dump"
match='glibc'
test_pass "${cb_commands}" "${match}"

target="armeb-linux-gnueabi"
# A baremetal target should pick the right clibrary (newlib)
cb_commands="--target ${target} --dump"
match='glibc'
test_pass "${cb_commands}" "${match}"

target="armeb-none-eabi"
# A baremetal target should pick the right clibrary (newlib)
cb_commands="--target ${target} --dump"
match='newlib'
test_pass "${cb_commands}" "${match}"

target="arm-none-eabi"
# A baremetal target should pick the right clibrary (newlib)
cb_commands="--target ${target} --dump"
match='newlib'
test_pass "${cb_commands}" "${match}"

target="aarch64-none-elf"
libc="newlib"
cb_commands="--target ${target} --set libc=${libc}"
match=''
test_pass "${cb_commands}" "${match}"

# Verify that setting glibc=glibc.git will fail for baremetal.
cb_commands="--dryrun --target aarch64-none-elf glibc=glibc.git"
match='crosscheck_clibrary_target'
test_failure "${cb_commands}" "${match}"

# Verify that glibc=glibc.git will fail when se before the target
# for baremetal.
cb_commands="--dryrun glibc=glibc.git --target aarch64-none-elf"
match='crosscheck_clibrary_target'
test_failure "${cb_commands}" "${match}"

cb_commands="--snapshots"
match='requires a directive'
test_failure "${cb_commands}" "${match}"

cb_commands="--stage"
match='requires a directive'
test_failure "${cb_commands}" "${match}"

cb_commands="--stage a"
match='stage requires a 2 or 1 directive'
test_failure "${cb_commands}" "${match}"

cb_commands="--stage 3"
match='stage requires a 2 or 1 directive'
test_failure "${cb_commands}" "${match}"

cb_commands="--stage 3"
match='stage requires a 2 or 1 directive'
test_failure "${cb_commands}" "${match}"


cb_commands="--snapshots --sooboo"
match='found the next'
test_failure "${cb_commands}" "${match}"

cb_commands="--snapshots=foo/bar --build all"
match="A space is expected"
test_failure "${cb_commands}" "${match}"

cb_commands="--dryrun --snapshots ${local_snapshots} --build all"
match=''
test_pass "${cb_commands}" "${match}"

cb_commands="--dryrun --build gcc.git"
match=''
test_pass "${cb_commands}" "${match}"

cb_commands="--dryrun --build asdflkajsdflkajsfdlasfdlaksfdlkaj.git"
match="Malformed input. No url found"
test_failure "${cb_commands}" "${match}"

# This tests that --build can go before --target and --target is still processed correctly.
cb_commands="--dryrun --build all --target arm-linux-gnueabihf --dump"
match='arm-linux-gnueabihf'
test_pass "${cb_commands}" "${match}"

# This tests that --checkout can go before --target and --target is still processed correctly.
cb_commands="--dryrun --checkout all --target arm-linux-gnueabihf --dump"
match='arm-linux-gnueabihf'
test_pass "${cb_commands}" "${match}"

test_config_default make_docs 'Make Documentation' 'Skipping make docs'    'Making docs in'
test_config_default install   'Install'            'Skipping make install' 'Making install in'

# The default.
cb_commands="--dump"
match='Bootstrap          no'
test_pass "${cb_commands}" "${match}"

cb_commands="--enable bootstrap --dump"
match='Bootstrap          yes'
test_pass "${cb_commands}" "${match}"

cb_commands="--dump"
match='Install            yes'
test_pass "${cb_commands}" "${match}"

cb_commands="--disable install --dump"
match='Install            no'
test_pass "${cb_commands}" "${match}"

cb_commands="--dump"
match='Source Update      yes'
test_pass "${cb_commands}" "${match}"

cb_commands="--disable update --dump"
match='Source Update      no'
test_pass "${cb_commands}" "${match}"

# Test dump ordering.  --target processing is immediate, so --dump
# should work before or after --target.
cb_commands="--target arm-linux-gnueabihf --dump"
match='Target is\:         arm-linux-gnueabihf'
test_pass "${cb_commands}" "${match}"

cb_commands="--dump --target arm-linux-gnueabihf"
match='Target is\:         arm-linux-gnueabihf'
test_pass "${cb_commands}" "${match}"

# This tests that --checkout and --build can be run together.
cb_commands="--dryrun --target arm-linux-gnueabihf --checkout all --build all"
match=''
test_pass "${cb_commands}" "${match}"

cb_commands="--set"
match='requires a directive'
test_failure "${cb_commands}" "${match}"

cb_commands="--set --foobar"
match='found the next'
test_failure "${cb_commands}" "${match}"

cb_commands="--set=libc=glibc"
match="A space is expected"
test_failure "${cb_commands}" "${match}"

cb_commands="--set gcc=meh"
match="'gcc' is not a supported package"
test_failure "${cb_commands}" "${match}"

cb_commands="--set libc=glibc"
match=''
test_pass "${cb_commands}" "${match}"

cb_commands="glibc=glibc.git"
match=''
test_pass "${cb_commands}" "${match}"

target="aarch64-none-elf"
cb_commands="--target ${target} glibc=glibc.git"
match="crosscheck_clibrary_target"
test_failure "${cb_commands}" "${match}"

target="aarch64-none-elf"
cb_commands="--target ${target} glibc=eglibc.git"
match="crosscheck_clibrary_target"
test_failure "${cb_commands}" "${match}"

target="aarch64-none-elf"
cb_commands="--target ${target} newlib=newlib.git"
match=''
test_pass "${cb_commands}" "${match}"

target="aarch64-none-elf"
cb_commands="--target ${target} --set libc=glibc"
match="crosscheck_clibrary_target"
test_failure "${cb_commands}" "${match}"

target="aarch64-none-elf"
cb_commands="--set libc=glibc --target ${target}"
match="crosscheck_clibrary_target"
test_failure "${cb_commands}" "${match}"

target="aarch64-none-elf"
cb_commands="--set libc=newlibv --target ${target}"
match=''
test_failure "${cb_commands}" "${match}"

target="aarch64-none-elf"
cb_commands="--target ${target} --set libc=newlib"
match=''
test_pass "${cb_commands}" "${match}"

# The same as previous but with other commands mixed in.
target="aarch64-none-elf"
cb_commands="--set libc=glibc --dry-run --build all --target ${target}"
match="crosscheck_clibrary_target"
test_failure "${cb_commands}" "${match}"

# The same as previous but with other commands mixed in.
target="arm-linux-gnueabihf"
cb_commands="--set libc=glibc --dry-run --build all --target ${target}"
match=''
test_pass "${cb_commands}" "${match}"

# This one's a bit different because it doesn't work by putting the phrase to
# be grepped in 'match'... yet.
cb_commands="--dryrun --build gcc.git --stage 2"
testlineno="`expr $LINENO + 1`"
out="`(${runintmpdir:+cd ${tmpdir}} && ${abe_path}/abe.sh --space 4960 ${cb_commands} 2>&1 | tee ${testlogs}/${testlineno}.log | grep -c " build.*gcc.*stage2")`"
if test ${out} -gt 0; then
    pass ${testlineno} "VALID: --dryrun --build gcc.git --stage 2"
else
    fail ${testlineno} "VALID: --dryrun --build gcc.git --stage 2"
fi

cb_commands="--dry-run --target arm-linux-gnueabihf --set arch=armv8-a"
match='Overriding default --with-arch to armv8-a'
test_pass "${cb_commands}" "${match}"

cb_commands="--dry-run --target arm-linux-gnueabihf --set cpu=cortex-a57"
match='Overriding default --with-cpu to cortex-a57'
test_pass "${cb_commands}" "${match}"

cb_commands="--dry-run --target arm-linux-gnueabihf --set tune=cortex-a53"
match='Overriding default --with-tune to cortex-a53'
test_pass "${cb_commands}" "${match}"

cb_commands="--dry-run --target arm-linux-gnueabihf --check=foo"
match='is invalid after'
test_failure "${cb_commands}" "${match}"

cb_commands="--dry-run --target arm-linux-gnueabihf --dump --check"
match='check              all'
test_pass "${cb_commands}" "${match}"

cb_commands="--dry-run --target arm-linux-gnueabihf --dump --check --dump"
match='check              all'
test_pass "${cb_commands}" "${match}"

# Yes this won't work because we match on 'exact' package name only.
cb_commands="--dry-run --target arm-linux-gnueabihf --dump --check gdb--dump"
match='dump is an invalid package'
test_failure "${cb_commands}" "${match}"

cb_commands="--dry-run --target arm-linux-gnueabihf --check --dump"
match='check              all'
test_pass "${cb_commands}" "${match}"

cb_commands="--dry-run --target arm-linux-gnueabihf --check gdb --dump"
match='check              gdb'
test_pass "${cb_commands}" "${match}"

cb_commands="--dry-run --target arm-linux-gnueabihf --check all --dump"
match='check              all'
test_pass "${cb_commands}" "${match}"

# Verify that --check without a directive doesn't strip the next switch from
# the command line.
cb_commands="--dry-run --check --target arm-linux-gnueabihf --dump"
match='         arm-linux-gnueabihf'
test_pass "${cb_commands}" "${match}"

# test various combinations of --check and --excludecheck

# This should explicitly add all tests to runtests but NOT include 'all' in the text
cb_commands="--check all --dump"
match='checking           glibc gcc gdb binutils'
test_pass "${cb_commands}" "${match}"

# Simply exclude 'gdb' from the list of all runtests.
cb_commands="--check all --excludecheck gdb --dump"
match='checking           glibc gcc binutils'
test_pass "${cb_commands}" "${match}"

# This should be the same as --check all --excludecheck gdb
cb_commands="--check  --excludecheck gdb --dump"
match='checking           glibc gcc binutils'
test_pass "${cb_commands}" "${match}"

# 'binutils' is on the end of the list which might have some whitespace issues.
cb_commands="--check all --excludecheck binutils --dump"
match='checking           glibc gcc gdb'
test_pass "${cb_commands}" "${match}"

# 'glibc' is at the beginning of the list which might have some whitespace issues.
cb_commands="--check all --excludecheck glibc --dump"
match='checking           gcc gdb binutils'
test_pass "${cb_commands}" "${match}"

# Make sure both are accounted for.
cb_commands="--check all --excludecheck glibc --excludecheck binutils --dump"
match='checking           gcc gdb'
test_pass "${cb_commands}" "${match}"

# Check a single test
cb_commands="--check gdb --dump"
match='checking           gdb'
test_pass "${cb_commands}" "${match}"

# Check binutils
cb_commands="--check binutils --dump"
match='checking           binutils'
test_pass "${cb_commands}" "${match}"

# Check glibc
cb_commands="--check glibc --dump"
match='checking           glibc'
test_pass "${cb_commands}" "${match}"

# Check gcc
cb_commands="--check gcc --dump"
match='checking           gcc'
test_pass "${cb_commands}" "${match}"

# Check that --dump is processed after --check.
cb_commands="--dump --check gcc"
match='checking           gcc'
test_pass "${cb_commands}" "${match}"

# What happens when you add several tests?
cb_commands="--check gdb --check gcc --dump"
match='checking           gdb gcc'
test_pass "${cb_commands}" "${match}"

# This should result in 'gdb gcc' in runtests because the order depends on when they were added with --check.
cb_commands="--check gdb --check gcc --dump"
match='checking           gdb gcc'
test_pass "${cb_commands}" "${match}"

# what if you mix 'all' and individual tests?  It should be all tests in all_unit_tests and no redundant tests.
cb_commands="--check all --check gdb --check glibc --dump"
match='checking           glibc gcc gdb binutils'
test_pass "${cb_commands}" "${match}"

# Make sure we get the same result with --check (without a directive) since this is the same as 'all'.
# It should be all tests in all_unit_tests and no redundant tests.
cb_commands="--check --check gdb --check glibc --dump"
match='checking           glibc gcc gdb binutils'
test_pass "${cb_commands}" "${match}"

# Make sure we can exclude binutils when 'all' is mixed with individual tests.
cb_commands="--check all --check gdb --check glibc --excludecheck binutils --dump"
match='checking           glibc gcc gdb'
test_pass "${cb_commands}" "${match}"

# Make sure we can exclude several packages when 'all' is mixed with individual tests.
cb_commands="--check all --check gdb --check glibc --excludecheck binutils --excludecheck gdb --dump"
match='checking           glibc gcc'
test_pass "${cb_commands}" "${match}"

# Order of where --check all shows up shouldn't affect outcome.
# Make sure we can exclude several packages when 'all' is mixed with individual tests.
cb_commands="--check gdb --check glibc --excludecheck binutils --excludecheck gdb --check all --dump"
match='checking           glibc gcc'
test_pass "${cb_commands}" "${match}"

# Order of where --check shows up shouldn't affect outcome.
# Make sure we can exclude several packages when 'all' is mixed with individual tests.
cb_commands="--check gdb --check glibc --excludecheck binutils --excludecheck gdb --check --dump"
match='checking           glibc gcc'
test_pass "${cb_commands}" "${match}"

# Make sure we can exclude several packages when 'all' is implicitly mixed with individual tests.
cb_commands="--check --check gdb --check glibc --excludecheck binutils --excludecheck gdb --dump"
match='checking           glibc gcc'
test_pass "${cb_commands}" "${match}"

# Order of --check and --excludecheck doesn't matter.  We always 'exclude' after we process 'check'.
# If we add --check gdb after we've already excluded it, it'll remain excluded.
cb_commands="--check --check gdb --check glibc --excludecheck binutils --excludecheck gdb --check gdb --dump"
match='checking           glibc gcc'
test_pass "${cb_commands}" "${match}"

# Removing everything that was added should result in no unit tests being run.
cb_commands="--check gdb --check glibc --excludecheck gdb --excludecheck glibc --dump"
match='checking           {none}'
test_pass "${cb_commands}" "${match}"

# Redundant check tests should have all instances overridden by excludecheck.
cb_commands="--check gdb --check gdb --check glibc --excludecheck gdb --excludecheck glibc --dump"
match='checking           {none}'
test_pass "${cb_commands}" "${match}"

# Redundant excludecheck tests shouldn't do anything unexpected.
cb_commands="--check gdb --check glibc --excludecheck glibc --excludecheck gdb --excludecheck glibc --dump"
match='checking           {none}'
test_pass "${cb_commands}" "${match}"

# Redundant excludecheck tests shouldn't accidentally remove an included test.
cb_commands="--check gdb --check glibc --excludecheck glibc --excludecheck glibc --dump"
match='checking           gdb'
test_pass "${cb_commands}" "${match}"

# Redundant check tests should only result in one instance of the test
cb_commands="--check gdb --check gdb --check glibc --dump"
match='checking           gdb glibc'
test_pass "${cb_commands}" "${match}"

# There should be nothing in runtests because nothing was specified with --check
cb_commands="--excludecheck glibc --dump"
match='checking           {none}'
test_pass "${cb_commands}" "${match}"

# This should error out because 'excludecheck' requires a directive
cb_commands="--check gdb --check gdb --check glibc --excludecheck --dump"
match='excludecheck requires a directive'
test_pass "${cb_commands}" "${match}"

# excluding a test that isn't being checked should work fine.
cb_commands="--check gdb --check gdb --check glibc --excludecheck gcc --dump"
match='checking           gdb glibc'
test_pass "${cb_commands}" "${match}"

# excluding this combination shouldn't leave extraneous spaces in runtests.
cb_commands="--check --excludecheck gcc --excludecheck gdb --dump"
match='checking           glibc binutils'
test_pass "${cb_commands}" "${match}"


# excluding all tests should work
cb_commands="--check all --excludecheck all --dump"
match='checking           {none}'
test_pass "${cb_commands}" "${match}"

# excluding all tests should work regardless of what other tests are included or excluded.
cb_commands="--check all --excludecheck all --check gdb --excludecheck gcc --dump"
match='checking           {none}'
test_pass "${cb_commands}" "${match}"

# excluding all tests should work even if no other tests have been included.
cb_commands="--excludecheck all --dump"
match='checking           {none}'
test_pass "${cb_commands}" "${match}"

# excluding all tests should work even if only one test has been included.
cb_commands="--check glibc --excludecheck all --dump"
match='checking           {none}'
test_pass "${cb_commands}" "${match}"

# checking a partial package name shoulderror
cb_commands="--check gd --dump"
match='gd is an invalid package name'
test_failure "${cb_commands}" "${match}"

# checking an invalid package should error.
cb_commands="--check foo --dump"
match='foo is an invalid package name'
test_failure "${cb_commands}" "${match}"

# excluding a partial package name should error
cb_commands="--check --excludecheck gd --dump"
match='gd is an invalid package name'
test_failure "${cb_commands}" "${match}"

# excluding an invalid package name should error
cb_commands="--check --excludecheck foo --dump"
match='foo is an invalid package name'
test_failure "${cb_commands}" "${match}"

# Only perform this test if we're running in the tmpdir because we
# don't want to damage the builds/ dir for a valid run.
if test x"${runintmpdir}" = xyes; then
    rm -rf ${tmpdir}/builds

    # Test that builds/ is restored if it is removed.
    cb_commands="--dry-run --target arm-linux-gnueabihf --dump --build all"
    match=''
    test_pass "${cb_commands}" "${match}"

    if test ! -d "${tmpdir}/builds"; then
	fail ${testlineno} "VALID: test that builds/ is restored if it is removed."
    else
	pass ${testlineno} "VALID: tests that builds/ is restored if it is removed."
    fi
fi

# If the tests pass successfully clean up /tmp/<tmpdir> but only if the
# directory name is conformant.  We don't want to accidentally remove /tmp.
if test x"${tmpdir}" = x"/tmp"; then
    echo ""
    echo "\n${local_snapshots} doesn't conform to /tmp/<tmpdir>/snapshots. Not safe to remove."
elif test -d "${tmpdir}/snapshots" -a ${failures} -lt 1; then
    echo ""
    echo "${testabe} finished with no unexpected failures. Removing ${tmpdir}"
    rm -rf ${tmpdir}
fi

# ----------------------------------------------------------------------------------
# print the total of test results
totals

# We can't just return ${failures} or it could overflow to 0 (success)
if test ${failures} -gt 0; then
    exit 1
fi
exit 0
