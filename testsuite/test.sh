#!/bin/sh

# common.sh loads all the files of library functions.
. "$(dirname "$0")/../lib/common.sh" || exit 1

# Since we're testing, we don't load the host.conf file, instead
# we create false values that stay consistent.
cbuild_top=/build/cbuild2/test
hostname=test.foobar.org
target=x86_64-linux-gnu

passes=0
pass()
{
    echo "PASS: $1"
    passes="`expr ${passes} + 1`"
}

failures=0
fail()
{
    echo "FAIL: $1"
    failures="`expr ${failures} + 1`"
}

totals()
{
    echo ""
    echo "Total test results:"
    echo "\tPasses: ${passes}"
    echo "\tFailures: ${failures}"
}

# test an uncompressed tarball
out=`normalize_path http://cbuild.validation.linaro.org/snapshots/gdb-7.6~20121001+git3e2e76a.tar`
if test ${out} = "gdb-7.6~20121001+git3e2e76a"; then
    pass "normalize_path: tarball uncompressed"
else
    fail "normalize_path: tarball uncompressed"
fi

out=`get_builddir http://cbuild.validation.linaro.org/snapshots/gdb-7.6~20121001+git3e2e76a.tar`
if test ${out} = "/build/cbuild2/test/test.foobar.org/x86_64-linux-gnu/"; then
    pass "get_builddir: tarball uncompressed"
else
    fail "get_builddir: tarball uncompressed"
fi

# test an compressed tarball
out=`normalize_path http://cbuild.validation.linaro.org/snapshots/gcc-linaro-4.8-2013.06-1.tar.xz`
if test ${out} = "gcc-linaro-4.8-2013.06-1"; then
    pass "normalize_path: tarball compressed"
else
    fail "normalize_path: tarball compressed"
fi

out=`get_builddir http://cbuild.validation.linaro.org/snapshots/gcc-linaro-4.8-2013.06-1.tar.xz`
if test ${out} = "/build/cbuild2/test/test.foobar.org/x86_64-linux-gnu/"; then
    pass "get_builddir: tarball compressed"
else
    fail "get_builddir: tarball compressed"
fi

# test an svn branch
out=`normalize_path svn://gcc.gnu.org/svn/gcc/branches/gcc-4_7-branch`
if test ${out} = "gcc-4_7-branch"; then
    pass "normalize_path: svn branch"
else
    fail "normalize_path: svn branch"
fi

out=`get_builddir svn://gcc.gnu.org/svn/gcc/branches/gcc-4_7-branch`
if test ${out} = "/build/cbuild2/test/test.foobar.org/x86_64-linux-gnu/"; then
    pass "get_builddir: svn branch"
else
    fail "get_builddir: svn branch"
fi

# test a bzr branch
out=`normalize_path lp:gdb-linaro/7.5`
if test ${out} = "gdb-linaro_7.5"; then
    pass "normalize_path: bzr branch"
else
    fail "normalize_path: bzr branch"
fi

out=`get_builddir lp:gdb-linaro/7.5`
if test ${out} = "/build/cbuild2/test/test.foobar.org/x86_64-linux-gnu/"; then
    pass "get_builddir: bzr branch"
else
    fail "get_builddir: bzr branch"
fi

# test a git branch
out=`normalize_path git://git.linaro.org/toolchain/binutils.git`
if test ${out} = "binutils.git"; then
    pass "normalize_path: git branch"
else
    fail "normalize_path: git branch"
fi

out=`get_builddir git://git.linaro.org/toolchain/binutils.git`
if test ${out} = "/build/cbuild2/test/test.foobar.org/x86_64-linux-gnu/"; then
    pass "get_builddir: git branch"
else
    fail "get_builddir: git branch"
fi

# print the total of test results
totals
