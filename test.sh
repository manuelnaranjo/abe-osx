#!/bin/sh

testcbuild2="`basename $0`"
topdir=`dirname $0`
cbuild_path=`readlink -f ${topdir}`
export cbuild_path

# Source common.sh for some common utilities.
. ${cbuild_path}/lib/common.sh || exit 1

# We use a tmp/ directory for the builddir in order that we don't pollute the
# srcdir or an existing builddir.
tmpdir=`mktemp -d /tmp/cbuild2.$$.XXX`
if test "$?" -gt 0; then
    error "mktemp of ${tmpdir} failed."
    exit 1
fi

# Log files for cbuild test runs are dumped here.
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
    (cd ${tmpdir} && ${cbuild_path}/configure --with-sources-conf=${cbuild_path}/testsuite/test_sources.conf)
    runintmpdir=yes
else
    # copy the md5sums file from the existing snapshots directory to the new local_snapshots directory.

    # Override $local_snapshots so that the local_snapshots directory of an
    # existing build is not moved or damaged.  This affects all called
    # instances of cbuild2.sh below.
    export local_snapshots="${tmpdir}/snapshots"
    out="`mkdir -p ${local_snapshots}`"
    if test "$?" -gt 0; then
        error "couldn't create '${local_snapshots}' directory."
        exit 1
    fi
    # Override the existing sources_conf setting in host.conf.
    export sources_conf=${cbuild_path}testsuite/test_sources.conf
fi

export wget_quiet=yes

usage()
{
    echo "  ${testcbuild2} [--debug|-v]"
    echo "                 [--md5sums <path/to/alternative/snapshots/md5sums>]"
    echo ""
    echo "  ${testcbuild2} is the cbuild2 frontend command conformance test."
    echo ""
    echo " ${testcbuild2} should be run from the source directory."
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

    out="`(${runintmpdir:+cd ${tmpdir}} && ${cbuild_path}/cbuild2.sh ${cb_commands} 2>&1 | tee ${testlogs}/${testlineno}.log | grep "${match}" | sed -e 's:\(^ERROR\).*\('"${match}"'\).*:\1 \2:')`"
    cbtest ${testlineno} "${out}" "ERROR ${match}" "ERROR ${cb_commands}"
}

test_pass()
{
    local testlineno=$BASH_LINENO
    local cb_commands=$1
    local match=$2
    local out=

    # Continue to search for error so we don't get false positives.
    out="`(${runintmpdir:+cd ${tmpdir}} && ${cbuild_path}/cbuild2.sh ${cb_commands} 2>&1 | tee ${testlogs}/${testlineno}.log | grep "${match}" | sed -e 's:\(^ERROR\).*\('"${match}"'\).*:\1 \2:')`"
    cbtest ${testlineno} "${out}" "${match}" "VALID ${cb_commands}"
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
match="Command not recognized"
test_failure "${cb_commands}" "${match}"

cb_commands="-dr"
match="Command not recognized"
test_failure "${cb_commands}" "${match}"

cb_commands="--drnasdfa"
match="Command not recognized"
test_failure "${cb_commands}" "${match}"

# Test for expected failure for removed deprecated feature --dostep.
cb_commands="--dostep"
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

cb_commands="--dryrun --target arm-none-linux-gnueabihf --checkout glibc.git"
match=''
test_pass "${cb_commands}" "${match}"

cb_commands="--dryrun --target arm-none-linux-gnueabihf --checkout=glibc.git"
match="A space is expected"
test_failure "${cb_commands}" "${match}"

cb_commands="--dryrun --target arm-none-linux-gnueabihf --checkout all"
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
libc="eglibc"
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

target="armeb-none-linux-gnueabihf"
# A baremetal target should pick the right clibrary (newlib)
cb_commands="--target ${target} --dump"
match='eglibc'
test_pass "${cb_commands}" "${match}"

target="armeb-linux-gnueabihf"
# A baremetal target should pick the right clibrary (newlib)
cb_commands="--target ${target} --dump"
match='eglibc'
test_pass "${cb_commands}" "${match}"

target="armeb-none-linux-gnueabi"
cb_commands="--target ${target} --dump"
match='eglibc'
test_pass "${cb_commands}" "${match}"

target="armeb-linux-gnueabi"
cb_commands="--target ${target} --dump"
match='eglibc'
test_pass "${cb_commands}" "${match}"

target="armeb-none-linux-gnueabi"
# A baremetal target should pick the right clibrary (newlib)
cb_commands="--target ${target} --dump"
match='eglibc'
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
match="Couldn't find the source for"
test_failure "${cb_commands}" "${match}"

# This tests that --build can go before --target and --target is still processed correctly.
cb_commands="--dryrun --build all --target arm-none-linux-gnueabihf --dump"
match='arm-none-linux-gnueabihf'
test_pass "${cb_commands}" "${match}"

# This tests that --checkout can go before --target and --target is still processed correctly.
cb_commands="--dryrun --checkout all --target arm-none-linux-gnueabihf --dump"
match='arm-none-linux-gnueabihf'
test_pass "${cb_commands}" "${match}"

# If we're running in an existing build directory we don't know WHAT the
# user has set as the default so we set it to 'yes' explicity, and preserve
# the original.
indir=${PWD}
if test x"${runintmpdir}" != x""; then
  indir=${tmpdir}
fi
cp ${indir}/host.conf ${indir}/host.conf.orig
cat ${indir}/host.conf | sed -e 's/make_docs=.*/make_docs=yes/' > ${indir}/host.conf.make_doc.yes
cp ${indir}/host.conf.make_doc.yes ${indir}/host.conf
rm ${indir}/host.conf.make_doc.yes

# The default.
cb_commands="--dump"
match='Make Documentation yes'
test_pass "${cb_commands}" "${match}"

cb_commands="--dump --disable make_docs"
match='Make Documentation no'
test_pass "${cb_commands}" "${match}"

# Change the configured default to 'no'
cp ${indir}/host.conf ${indir}/host.conf.orig
cat ${indir}/host.conf | sed -e 's/make_docs=.*/make_docs=no/' > ${indir}/host.conf.make_doc.no
cp ${indir}/host.conf.make_doc.no ${indir}/host.conf
rm ${indir}/host.conf.make_doc.no

# Verify that it's now 'no'
cb_commands="--dump"
match='Make Documentation no'
test_pass "${cb_commands}" "${match}"

# Verify that 'enable make_docs' now works.
cb_commands="--dump --enable make_docs"
match='Make Documentation yes'
test_pass "${cb_commands}" "${match}"

# Return the default host.conf
mv ${indir}/host.conf.orig ${indir}/host.conf

# Let's make sure the make_docs stage is actually skipped.
# --force makes sure we run through to the make docs stage even
# if the builddir builds stamps are new.
cb_commands="--dryrun --force --target arm-none-linux-gnueabihf --disable make_docs --build all"
match='Skipping make docs'
test_pass "${cb_commands}" "${match}"

# Let's make sure the make_docs stage is NOT skipped.
# --force makes sure we run through to the make docs stage even
# if the builddir builds stamps are new.
cb_commands="--dryrun --force --target arm-none-linux-gnueabihf --enable make_docs --build all"
match='Making docs in'
test_pass "${cb_commands}" "${match}"

# Verify the default is restored.
cb_commands="--dump"
match='Make Documentation yes'
test_pass "${cb_commands}" "${match}"

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
cb_commands="--dryrun --target arm-none-linux-gnueabihf --checkout all --build all"
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
cb_commands="--target ${target} eglibc=eglibc.git"
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
target="arm-none-linux-gnueabihf"
cb_commands="--set libc=glibc --dry-run --build all --target ${target}"
match=''
test_pass "${cb_commands}" "${match}"

# This one's a bit different because it doesn't work by putting the phrase to
# be grepped in 'match'... yet.
cb_commands="--dryrun --build gcc.git --stage 2"
testlineno="`expr $LINENO + 1`"
out="`(${runintmpdir:+cd ${tmpdir}} && ${cbuild_path}/cbuild2.sh ${cb_commands} 2>&1 | tee ${testlogs}/${testlineno}.log | grep -c " build.*gcc.*stage2")`"
if test ${out} -gt 0; then
    pass ${testlineno} "VALID: --dryrun --build gcc.git --stage 2"
else
    fail ${testlineno} "VALID: --dryrun --build gcc.git --stage 2"
fi

# If the tests pass successfully clean up /tmp/<tmpdir> but only if the
# directory name is conformant.  We don't want to accidentally remove /tmp.
if test x"${tmpdir}" = x"/tmp"; then
    echo ""
    echo "\n${local_snapshots} doesn't conform to /tmp/<tmpdir>/snapshots. Not safe to remove."
elif test -d "${tmpdir}/snapshots" -a ${failures} -lt 1; then
    echo ""
    echo "${testcbuild2} finished with no unexpected failures. Removing ${tmpdir}"
    rm -rf ${tmpdir}
fi

# ----------------------------------------------------------------------------------
# print the total of test results
totals

exit 0
