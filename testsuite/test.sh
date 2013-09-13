#!/bin/bash

# common.sh loads all the files of library functions.
if test `dirname "$0"` != "testsuite"; then
    cbuild="`which cbuild2.sh`"
    topdir="`dirname ${cbuild}`"
else
    topdir=$PWD
fi

# load the configure file produced by configure
if test -e "${PWD}/host.conf"; then
    . "${PWD}/host.conf"
else
    warning "no host.conf file!"
fi

. "${topdir}/lib/common.sh" || exit 1
. "${topdir}/host.conf" || exit 1

# Since we're testing, we don't load the host.conf file, instead
# we create false values that stay consistent.
cbuild_top=/build/cbuild2/test
hostname=test.foobar.org
target=x86_64-linux-gnu

if test x"$1" = x"-v"; then
    debug=yes
fi

verbose()
{
    if test x"${debug}" = x"yes"; then
	echo "($BASH_LINENO): $*"
    fi
}

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
    echo "	Passes: ${passes}"
    echo "	Failures: ${failures}"
}

#
# common.sh tests
#

# ----------------------------------------------------------------------------------
# test an uncompressed tarball
in="http://cbuild.validation.linaro.org/snapshots/gdb-7.6~20121001+git3e2e76a.tar"
out="`normalize_path ${in}`"
if test ${out} = "gdb-7.6~20121001+git3e2e76a"; then
    pass "normalize_path: tarball uncompressed"
else
    fail "normalize_path: tarball uncompressed"
    verbose "${in} returned ${out}"
fi

out="`get_builddir ${in}`"
if test ${out} = "${local_builds}/x86_64-unknown-linux-gnu/x86_64-linux-gnu/gdb-7.6~20121001+git3e2e76a"; then
    pass "get_builddir: tarball uncompressed"
else
    fail "get_builddir: tarball uncompressed"
fi

out="`get_toolname ${in}`"
if test ${out} = "gdb"; then
    pass "get_toolname: tarball uncompressed"
else
    fail "get_toolname: tarball uncompressed"
    verbose "${in} returned ${out}"
fi

# ----------------------------------------------------------------------------------
# test an compressed tarball
in="http://cbuild.validation.linaro.org/snapshots/gcc-linaro-4.8-2013.06-1.tar.xz"
out="`normalize_path ${in}`"
if test ${out} = "gcc-linaro-4.8-2013.06-1"; then
    pass "normalize_path: tarball compressed"
else
    fail "normalize_path: tarball compressed"
    verbose "${in} should produce ${out}"
fi

out="`get_builddir ${in}`"
if test ${out} = "${local_builds}/x86_64-unknown-linux-gnu/x86_64-linux-gnu/gcc-linaro-4.8-2013.06-1"; then
    pass "get_builddir: tarball compressed"
else
    fail "get_builddir: tarball compressed"
    verbose "${in} returned ${out}"
fi

out="`get_toolname ${in}`"
if test ${out} = "gcc"; then
    pass "get_toolname: tarball compressed"
else
    fail "get_toolname: tarball compressed"
    verbose "${in} returned ${out}"
fi

# ----------------------------------------------------------------------------------
# test an svn branch
in="svn://gcc.gnu.org/svn/gcc/branches/gcc-4_7-branch"
out="`normalize_path ${in}`"
if test ${out} = "gcc-4_7-branch"; then
    pass "normalize_path: svn branch"
else
    fail "normalize_path: svn branch"
    verbose "${in} should produce ${out}"
fi

out="`get_builddir ${in}`"
if test ${out} = "${local_builds}/x86_64-unknown-linux-gnu/x86_64-linux-gnu/gcc-4_7-branch"; then
    pass "get_builddir: svn branch"
else
    fail "get_builddir: svn branch"
    verbose "${in} returned ${out}"
fi

out="`get_toolname ${in}`"
if test ${out} = "gcc"; then
    pass "get_toolname: svn branch"
else
    fail "get_toolname: svn branch"
    verbose "${in} returned ${out}"
fi

# ----------------------------------------------------------------------------------
# test a bzr branch
in="lp:gdb-linaro/7.5"
out="`normalize_path ${in}`"
if test ${out} = "gdb-linaro_7.5"; then
    pass "normalize_path: bzr branch"
else
    fail "normalize_path: bzr branch"
    verbose "${in} returned ${out}"
fi

out="`get_builddir ${in}`"
if test ${out} = "${local_builds}/x86_64-unknown-linux-gnu/x86_64-linux-gnu/gdb-linaro_7.5"; then
    pass "get_builddir: bzr branch"
else
    fail "get_builddir: bzr branch"
    verbose "${in} returned ${out}"
fi

out="`get_toolname ${in}`"
if test ${out} = "gdb"; then
    pass "get_toolname: bzr branch"
else
    fail "get_toolname: bzr branch"
    verbose "${in} returned ${out}"
fi

# ----------------------------------------------------------------------------------
# test a git branch
in="git://git.linaro.org/toolchain/binutils.git/linaro-4.7-branch"
out="`normalize_path ${in}`"
if test ${out} = "binutils.git"; then
    pass "normalize_path: git branch"
else
    fail "normalize_path: git branch"
    verbose "${in} returned ${out}"
fi

out="`get_builddir ${in}`"
if test ${out} = "${local_builds}/x86_64-unknown-linux-gnu/x86_64-linux-gnu/binutils.git"; then
    pass "get_builddir: git branch"
else
    fail "get_builddir: git branch"
    verbose "${in} returned ${out}"
fi

out="`get_toolname ${in}`"
if test ${out} = "binutils"; then
    pass "get_toolname: git branch"
else
    fail "get_toolname: git branch"
    verbose "${in} returned ${out}"
fi

# ----------------------------------------------------------------------------------
out="`find_snapshot gcc`"
if test $? -eq 1; then
    pass "find_snapshot: not unique tarball name"
else
    fail "find_snapshot: not unique tarball name"
    verbose "find_snapshot returned ${out}"
fi

out="`find_snapshot gcc-linaro-4.8-2013.08`"
if test $? -eq 0; then
    pass "find_snapshot: unique tarball name"
else
    fail "find_snapshot: unique tarball name"
    verbose "find_snapshot returned ${out}"
fi

out="`find_snapshot gcc-linaro-4.8-2013.06XXX`"
if test $? -eq 1; then
    pass "find_snapshot: unknown tarball name"
else
    fail "find_snapshot: unknown tarball name"
    verbose "find_snapshot returned ${out}"
fi

# ----------------------------------------------------------------------------------
out="`get_URL gcc`"
if test $? -eq 1; then
    pass "get_URL: not unique in repository"
else
    fail "get_URL: not unique in repository"
    verbose "get_URL returned ${out}"
fi

out="`get_URL gcc-linaro-4.8-2013.06-1`"
if test $? -eq 0; then
    pass "get_URL: unique name in repository"
else
    fail "get_URL: unique name in repository"
    verbose "get_URL returned ${out}"
fi

out="`get_URL gcc-linaro-4.8-2013.06-1`"
if test $? -eq 0; then
    pass "get_URL: unknown repository"
else
    fail "get_URL: unknown repository"
    verbose "get_URL returned ${out}"
fi

out="`get_URL gcc.git/linaro-4.8-branch@12345`"
if test x"`echo ${out} | cut -d ' ' -f 1`" = x"git://git.linaro.org/toolchain/gcc.git"; then
    pass "get_URL: git URL in latest field"
else
    fail "get_URL: git URL in latest field"
    verbose "get_URL returned ${out}"
fi
if test x"`echo ${out} | cut -d ' ' -f 2`" = x"linaro-4.8-branch"; then
    pass "get_URL: git URL branch in latest field"
else
    fail "get_URL: git URL branch in latest field"
    verbose "get_URL returned ${out}"
fi
if test x"`echo ${out} | cut -d ' ' -f 3`" = x"12345"; then
    pass "get_URL: git URL commit in latest field"
else
    fail "get_URL: git URL commit in latest field"
    verbose "get_URL returned ${out}"
fi

echo "FIXME: ${data[data]}"

# ----------------------------------------------------------------------------------
#
# Test package buildingru

dryrun=yes
#gcc_version=linaro-4.8-2013.09
gcc_version=git://git.linaro.org/toolchain/gcc.git/fsf-gcc-4_8-branch

out="`binary_toolchain 2>&1 | tee xx |grep "DRYRUN:.*Jcvf"`"

date="`date +%Y%m%d`"
tarname="`echo $out | cut -d ' ' -f 9`"
destdir="`echo $out | cut -d ' ' -f 10`"
match="${local_snapshots}/gcc.git-${target}-${host}-${date}"

if test "`echo ${tarname} | grep -c ${match}`" -eq 1; then
    pass "binary_toolchain: git repository"
else
    fail "binary_toolchain: git repository"
    verbose "get_URL returned ${out}"
fi

#binutils_version=linaro-4.8-2013.09
binutils_version=git://git.linaro.org/toolchain/binutils.git
out="`binary_sysroot 2>&1 | tee xx |grep "DRYRUN:.*Jcvf"`"
tarname="`echo $out | cut -d ' ' -f 9`"
destdir="`echo $out | cut -d ' ' -f 10`"
match="${local_snapshots}/sysroot-eglibc-linaro-2.18-2013.09-${target}-${date}"
echo "${tarname}"
echo "${match}"
if test "`echo ${tarname} | grep -c ${match}`" -eq 1; then
    pass "binary_toolchain: git repository"
else
    fail "binary_toolchain: git repository"
    verbose "get_URL returned ${out}"
fi


gcc_src_tarball

# list of dependencies for a toolchain component
# out="`dependencies gcc`"
# if test `echo $out |grep -c "gmp.*mpc.*mpfr.*binutils"` -eq 1; then
#     pass "dependencies"
# else
#     fail "dependencies"
#     verbose "dependencies returned ${out}"
# fi

# ----------------------------------------------------------------------------------
# print the total of test results
totals

