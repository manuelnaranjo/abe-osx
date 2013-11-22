#!/bin/bash

# common.sh loads all the files of library functions.
if test `dirname "$0"` != "testsuite"; then
    cbuild="`which cbuild2.sh`"
    topdir="`dirname ${cbuild}`"
else
    topdir=$PWD
fi

. "${topdir}/lib/common.sh" || exit 1

# configure generates host.conf from host.conf.in.
if test -e "${PWD}/host.conf"; then
    . "${PWD}/host.conf"
else
    warning "no host.conf file!"
    remote_snapshots=http://cbuild.validation.linaro.org/snapshots
    wget_bin=/usr/bin/wget
    sources_conf=${cbuild}testsuite/test_sources.conf
fi
echo "Testsuite using ${sources_conf}"

# Use wget -q in the testsuite
wget_quiet=yes

# We always override $local_snapshots so that we don't damage or move the
# local_snapshots directory of an existing build.
local_snapshots="`mktemp -d /tmp/cbuild2.$$.XXX`/snapshots"

# Let's make sure that the snapshots portion of the directory is created before
# we use it just to be safe.
out="`mkdir -p ${local_snapshots}`"
if test "$?" -gt 1; then
    exit 1
fi

# Since we're testing, we don't load the host.conf file, instead
# we create false values that stay consistent.
cbuild_top=/build/cbuild2/test
hostname=test.foobar.org
target=x86_64-linux-gnu

if test x"$1" = x"-v"; then
    debug=yes
fi

fixme()
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

untested=0
untested()
{
    echo "UNTESTED: $1"
    untested="`expr ${untested} + 1`"
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
    if test ${untested} -gt 0; then
	echo "	Untested: ${untested}"
    fi
}

#
# common.sh tests
#

. "${topdir}/testsuite/normalize-tests.sh"
. "${topdir}/testsuite/builddir-tests.sh"
. "${topdir}/testsuite/srcdir-tests.sh"

# ----------------------------------------------------------------------------------

echo "============= get_toolname() tests ================"

testing="get_toolname: uncompressed tarball"
in="http://cbuild.validation.linaro.org/snapshots/gdb-7.6~20121001+git3e2e76a.tar"
out="`get_toolname ${in}`"
if test ${out} = "gdb"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out}"
fi

# ----------------------------------------------------------------------------------
testing="get_toolname: compressed tarball"
in="http://cbuild.validation.linaro.org/snapshots/gcc-linaro-4.8-2013.06-1.tar.xz"
out="`get_toolname ${in}`"
if test ${out} = "gcc"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out}"
fi

# ----------------------------------------------------------------------------------
testing="get_toolname: svn branch"
in="svn://gcc.gnu.org/svn/gcc/branches/gcc-4_7-branch"
out="`get_toolname ${in}`"
if test ${out} = "gcc"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out}"
fi

# ----------------------------------------------------------------------------------
testing="get_toolname: bzr branch"
in="lp:gdb-linaro/7.5"
out="`get_toolname ${in}`"
if test ${out} = "gdb"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out}"
fi

testing="get_toolname: git://<repo>[no .git suffix]"
in="git://git.linaro.org/toolchain/binutils"
out="`get_toolname ${in}`"
if test ${out} = "binutils"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out}"
fi

testing="get_toolname: git://<repo>[no .git suffix]/<branch> isn't supported."
in="git://git.linaro.org/toolchain/binutils/branch"
out="`get_toolname ${in}`"
if test ${out} != "binutils"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out}"
fi

testing="get_toolname: git://<repo>[no .git suffix]/<branch>@<revision> isn't supported."
in="git://git.linaro.org/toolchain/binutils/branch@12345"
out="`get_toolname ${in}`"
if test ${out} != "binutils"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out}"
fi

testing="get_toolname: git://<repo>[no .git suffix]@<revision> isn't supported."
in="git://git.linaro.org/toolchain/binutils@12345"
out="`get_toolname ${in}`"
if test ${out} != "binutils"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out}"
fi


# ----------------------------------------------------------------------------------
# Test git:// git combinations
testing="get_toolname: git://<repo>.git"
in="git://git.linaro.org/toolchain/binutils.git"
out="`get_toolname ${in}`"
if test ${out} = "binutils"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out}"
fi

testing="get_toolname: git://<repo>.git/<branch>"
in="git://git.linaro.org/toolchain/binutils.git/2.4-branch"
out="`get_toolname ${in}`"
if test ${out} = "binutils"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out}"
fi

testing="get_toolname: git://<repo>.git/<branch>@<revision>"
in="git://git.linaro.org/toolchain/binutils.git/2.4-branch@12345"
out="`get_toolname ${in}`"
if test ${out} = "binutils"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out}"
fi

testing="get_toolname: git://<repo>.git@<revision>"
in="git://git.linaro.org/toolchain/binutils.git@12345"
out="`get_toolname ${in}`"
if test ${out} = "binutils"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out}"
fi
# ----------------------------------------------------------------------------------
# Test http:// git combinations
testing="get_toolname: http://<repo>.git"
in="http://staging.git.linaro.org/git/toolchain/binutils.git"
out="`get_toolname ${in}`"
if test ${out} = "binutils"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out}"
fi

testing="get_toolname: http://<repo>.git/<branch>"
in="http://staging.git.linaro.org/git/toolchain/binutils.git/2.4-branch"
out="`get_toolname ${in}`"
if test ${out} = "binutils"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out}"
fi

testing="get_toolname: http://<repo>.git/<branch>@<revision>"
in="http://staging.git.linaro.org/git/toolchain/binutils.git/2.4-branch@12345"
out="`get_toolname ${in}`"
if test ${out} = "binutils"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out}"
fi

testing="get_toolname: http://<repo>.git@<revision>"
in="http://staging.git.linaro.org/git/toolchain/binutils.git@12345"
out="`get_toolname ${in}`"
if test ${out} = "binutils"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out}"
fi

# ----------------------------------------------------------------------------------
# Test http://<user>@ git combinations
testing="get_toolname: http://<user>@<repo>.git"
in="http://git@staging.git.linaro.org/git/toolchain/binutils.git"
out="`get_toolname ${in}`"
if test ${out} = "binutils"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out}"
fi

testing="get_toolname: http://<user>@<repo>.git/<branch>"
in="http://git@staging.git.linaro.org/git/toolchain/binutils.git/2.4-branch"
out="`get_toolname ${in}`"
if test ${out} = "binutils"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out}"
fi

testing="get_toolname: http://<user>@<repo>.git/<branch>@<revision>"
in="http://git@staging.git.linaro.org/git/toolchain/binutils.git/2.4-branch@12345"
out="`get_toolname ${in}`"
if test ${out} = "binutils"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out}"
fi

testing="get_toolname: http://<user>@<repo>.git@<revision>"
in="http://git@staging.git.linaro.org/git/toolchain/binutils.git@12345"
out="`get_toolname ${in}`"
if test ${out} = "binutils"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out}"
fi

# ----------------------------------------------------------------------------------
testing="get_toolname: sources.conf identifier <repo>.git"
in="eglibc.git"
out="`get_toolname ${in}`"
if test ${out} = "eglibc"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out}"
fi

testing="get_toolname: sources.conf identifier <repo>.git/<branch>"
in="eglibc.git/linaro_eglibc-2_18"
out="`get_toolname ${in}`"
if test ${out} = "eglibc"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out}"
fi

testing="get_toolname: sources.conf identifier <repo>.git/<branch>@<revision>"
in="eglibc.git/linaro_eglibc-2_18@12345"
out="`get_toolname ${in}`"
if test ${out} = "eglibc"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out}"
fi

testing="get_toolname: sources.conf identifier <repo>.git@<revision>"
in="eglibc.git@12345"
out="`get_toolname ${in}`"
if test ${out} = "eglibc"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out}"
fi
# ----------------------------------------------------------------------------------
echo "============= fetch() tests ================"
out="`fetch md5sums 2>/dev/null`"
if test $? -eq 0; then
    pass "fetch md5sums"
else
    fail "fetch md5sums"
fi

# Fetching again to test the .bak functionality.
out="`fetch md5sums 2>/dev/null`"
if test $? -eq 0; then
    pass "fetch md5sums"
else
    fail "fetch md5sums"
fi

if test ! -e "${local_snapshots}/md5sums"; then
    fail "Did not find ${local_snapshots}/md5sums"
    echo "md5sums needed for snapshots, get_URL, and get_sources tests.  Check your network connectivity." 1>&2
    exit 1;
else
    pass "Found ${local_snapshots}/md5sums"
fi

if test ! -e "${local_snapshots}/md5sums.bak"; then
    fail "Did not find ${local_snapshots}/md5sums.bak"
else
    pass "Found ${local_snapshots}/md5sums.bak"
fi
# ----------------------------------------------------------------------------------
echo "============= find_snapshot() tests ================"

testing="find_snapshot: not unique tarball name"
out="`find_snapshot gcc 2>/dev/null`"
if test $? -eq 1; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "find_snapshot returned ${out}"
fi

testing="find_snapshot: unique tarball name"
out="`find_snapshot gcc-linaro-4.8-2013.08`"
if test $? -eq 0; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "find_snapshot returned ${out}"
fi

testing="find_snapshot: unknown tarball name"
out="`find_snapshot gcc-linaro-4.8-2013.06XXX 2>/dev/null`"
if test $? -eq 1; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "find_snapshot returned ${out}"
fi

# ----------------------------------------------------------------------------------
echo "============= get_URL() tests ================"

# This will dump an error to stderr, so squelch it.
testing="get_URL: non unique identifier shouldn't match in sources.conf."
out="`get_URL gcc 2>/dev/null`"
if test $? -eq 1; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_URL returned ${out}"
fi

testing="get_URL: unmatching snapshot not found in sources.conf file"
out="`get_URL gcc-linaro-4.8-2013.06-1 2>/dev/null`"
if test $? -eq 1; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_URL returned ${out}"
fi

testing="get_URL: git URL where sources.conf has a tab"
if test ! -e "${PWD}/host.conf"; then
    out="`get_URL gcc_tab.git`"
    if test x"`echo ${out} | cut -d ' ' -f 1`" = x"http://staging.git.linaro.org/git/toolchain/gcc.git"; then
	pass "${testing}"
    else
	fail "${testing}"
	fixme "get_URL returned ${out}"
    fi
else
    untested "${testing}"
fi

# The regular sources.conf won't have this entry.
testing="get_URL: nomatch.git@<revision> shouldn't have a corresponding sources.conf url."
if test ! -e "${PWD}/host.conf"; then
    out="`get_URL nomatch.git@12345 2>/dev/null`"
    if test x"${out}" = x""; then
	pass "${testing}"
    else
	fail "${testing}"
	fixme "get_URL returned ${out}"
    fi
else
    untested "${testing}"
fi

# ----------------------------------------------------------------------------------
echo "============= get_URL() git:// tests ================"
testing="get_URL: sources.conf <repo>.git identifier should match git://<url>/<repo>.git"
out="`get_URL glibc.git`"
if test x"`echo ${out} | cut -d ' ' -f 1`" = x"git://git.linaro.org/toolchain/glibc.git"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_URL returned ${out}"
fi

testing="get_URL: sources.conf <repo>.git/<branch> identifier should match"
out="`get_URL glibc.git/branch`"
if test x"`echo ${out} | cut -d ' ' -f 1`" = x"git://git.linaro.org/toolchain/glibc.git"; then
    pass "${testing} git://<url>/<repo>.git"
else
    fail "${testing} git://<url>/<repo>.git"
    fixme "get_URL returned ${out}"
fi
if test x"`echo ${out} | cut -d ' ' -f 2`" = x"branch"; then
    pass "${testing} <branch>"
else
    fail "${testing} <branch>"
    fixme "get_URL returned ${out}"
fi

testing="get_URL: sources.conf <repo>.git/<branch>@<revision> identifier should match"
out="`get_URL glibc.git/branch@12345`"
if test x"`echo ${out} | cut -d ' ' -f 1`" = x"git://git.linaro.org/toolchain/glibc.git"; then
    pass "${testing} git://<url>/<repo>.git"
else
    fail "${testing} git://<url>/<repo>.git"
    fixme "get_URL returned ${out}"
fi
if test x"`echo ${out} | cut -d ' ' -f 2`" = x"branch"; then
    pass "${testing} <branch>"
else
    fail "${testing} <branch>"
    fixme "get_URL returned ${out}"
fi
if test x"`echo ${out} | cut -d ' ' -f 3`" = x"12345"; then
    pass "${testing} <revision>"
else
    fail "${testing} <revision>"
    fixme "get_URL returned ${out}"
fi

testing="get_URL: sources.conf <repo>.git@<revision> identifier should match"
out="`get_URL glibc.git@12345`"
if test x"`echo ${out} | cut -d ' ' -f 1`" = x"git://git.linaro.org/toolchain/glibc.git"; then
    pass "${testing} git://<url>/<repo>.git"
else
    fail "${testing} git://<url>/<repo>.git"
    fixme "get_URL returned ${out}"
fi
if test x"`echo ${out} | cut -d ' ' -f 2`" = x"12345"; then
    pass "${testing} <revision>"
else
    fail "${testing} <revision>"
    fixme "get_URL returned ${out}"
fi

# ----------------------------------------------------------------------------------
echo "============= get_URL() http:// tests ================"
testing="get_URL: sources.conf <repo>.git identifier should match http://<url>/<repo>.git"
out="`get_URL gcc.git`"
if test x"`echo ${out} | cut -d ' ' -f 1`" = x"http://staging.git.linaro.org/git/toolchain/gcc.git"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_URL returned ${out}"
fi

testing="get_URL: sources.conf <repo>.git/<branch> identifier should match"
out="`get_URL gcc.git/branch`"
if test x"`echo ${out} | cut -d ' ' -f 1`" = x"http://staging.git.linaro.org/git/toolchain/gcc.git"; then
    pass "${testing} http://<url>/<repo>.git"
else
    fail "${testing} http://<url>/<repo>.git"
    fixme "get_URL returned ${out}"
fi
if test x"`echo ${out} | cut -d ' ' -f 2`" = x"branch"; then
    pass "${testing} <branch>"
else
    fail "${testing} <branch>"
    fixme "get_URL returned ${out}"
fi

testing="get_URL: sources.conf <repo>.git/<branch>@<revision> identifier should match"
out="`get_URL gcc.git/branch@12345`"
if test x"`echo ${out} | cut -d ' ' -f 1`" = x"http://staging.git.linaro.org/git/toolchain/gcc.git"; then
    pass "${testing} http://<url>/<repo>.git"
else
    fail "${testing} http://<url>/<repo>.git"
    fixme "get_URL returned ${out}"
fi
if test x"`echo ${out} | cut -d ' ' -f 2`" = x"branch"; then
    pass "${testing} <branch>"
else
    fail "${testing} <branch>"
    fixme "get_URL returned ${out}"
fi
if test x"`echo ${out} | cut -d ' ' -f 3`" = x"12345"; then
    pass "${testing} <revision>"
else
    fail "${testing} <revision>"
    fixme "get_URL returned ${out}"
fi

testing="get_URL: sources.conf <repo>.git@<revision> identifier should match"
out="`get_URL gcc.git@12345`"
if test x"`echo ${out} | cut -d ' ' -f 1`" = x"http://staging.git.linaro.org/git/toolchain/gcc.git"; then
    pass "${testing} http://<url>/<repo>.git"
else
    fail "${testing} http://<url>/<repo>.git"
    fixme "get_URL returned ${out}"
fi
if test x"`echo ${out} | cut -d ' ' -f 2`" = x"12345"; then
    pass "${testing} <revision>"
else
    fail "${testing} <revision>"
    fixme "get_URL returned ${out}"
fi

# ----------------------------------------------------------------------------------
echo "============= get_URL() http://git@ tests ================"

# The regular sources.conf won't have this entry.
testing="get_URL: sources.conf <repo>.git identifier should match http://git@<url>/<repo>.git"
if test ! -e "${PWD}/host.conf"; then
    out="`get_URL git_gcc.git`"
    if test x"`echo ${out} | cut -d ' ' -f 1`" = x"http://git@staging.git.linaro.org/git/toolchain/gcc.git"; then
	pass "${testing}"
    else
	fail "${testing}"
	fixme "get_URL returned ${out}"
    fi
else
    untested "${testing}"
fi

# The regular sources.conf won't have this entry.
testing="get_URL: sources.conf <repo>.git/<branch> identifier should match"
if test ! -e "${PWD}/host.conf"; then
    out="`get_URL git_gcc.git/branch`"
    if test x"`echo ${out} | cut -d ' ' -f 1`" = x"http://git@staging.git.linaro.org/git/toolchain/gcc.git"; then
	pass "${testing} http://git@<url>/<repo>.git"
    else
	fail "${testing} http://git@<url>/<repo>.git"
	fixme "get_URL returned ${out}"
    fi
    if test x"`echo ${out} | cut -d ' ' -f 2`" = x"branch"; then
	pass "${testing} <branch>"
    else
	fail "${testing} <branch>"
	fixme "get_URL returned ${out}"
    fi
else
    untested "${testing} http://git@<url>/<repo>.git"
fi

# The regular sources.conf won't have this entry.
testing="get_URL: sources.conf <repo>.git/<branch>@<revision> identifier should match"
if test ! -e "${PWD}/host.conf"; then
    out="`get_URL git_gcc.git/branch@12345`"
    if test x"`echo ${out} | cut -d ' ' -f 1`" = x"http://git@staging.git.linaro.org/git/toolchain/gcc.git"; then
	pass "${testing} http://git@<url>/<repo>.git"
    else
	fail "${testing} http://git@<url>/<repo>.git"
	fixme "get_URL returned ${out}"
    fi
    if test x"`echo ${out} | cut -d ' ' -f 2`" = x"branch"; then
	pass "${testing} <branch>"
    else
	fail "${testing} <branch>"
	fixme "get_URL returned ${out}"
    fi
    if test x"`echo ${out} | cut -d ' ' -f 3`" = x"12345"; then
	pass "${testing} <revision>"
    else
	fail "${testing} <revision>"
	fixme "get_URL returned ${out}"
    fi
else
    untested "${testing} http://git@<url>/<repo>.git"
fi

# The regular sources.conf won't have this entry.
testing="get_URL: sources.conf <repo>.git@<revision> identifier should match"
if test ! -e "${PWD}/host.conf"; then
    out="`get_URL git_gcc.git@12345`"
    if test x"`echo ${out} | cut -d ' ' -f 1`" = x"http://git@staging.git.linaro.org/git/toolchain/gcc.git"; then
	pass "${testing} http://git@<url>/<repo>.git"
    else
	fail "${testing} http://git@<url>/<repo>.git"
	fixme "get_URL returned ${out}"
    fi
    if test x"`echo ${out} | cut -d ' ' -f 2`" = x"12345"; then
   	pass "${testing} <revision>"
    else
	fail "${testing} <revision>"
	fixme "get_URL returned ${out}"
    fi
else
    untested "${testing} http://git@<url>/<repo>.git"
fi

# ----------------------------------------------------------------------------------
echo "============= get_URL() http://username@ tests ================"
# We do these these tests to make sure that 'http://git@'
# isn't hardcoded in the scripts.

# The regular sources.conf won't have this entry.
testing="get_URL: sources.conf <repo>.git identifier should match http://username@<url>/<repo>.git"
if test ! -e "${PWD}/host.conf"; then
    out="`get_URL user_gcc.git`"
    if test x"`echo ${out} | cut -d ' ' -f 1`" = x"http://username@staging.git.linaro.org/git/toolchain/gcc.git"; then
	pass "${testing}"
    else
	fail "${testing}"
	fixme "get_URL returned ${out}"
    fi
else
    untested "${testing}"
fi

# The regular sources.conf won't have this entry.
testing="get_URL: sources.conf <repo>.git/<branch> identifier should match"
if test ! -e "${PWD}/host.conf"; then
    out="`get_URL user_gcc.git/branch`"
    if test x"`echo ${out} | cut -d ' ' -f 1`" = x"http://username@staging.git.linaro.org/git/toolchain/gcc.git"; then
	pass "${testing} http://username@<url>/<repo>.git"
    else
	fail "${testing} http://username@<url>/<repo>.git"
	fixme "get_URL returned ${out}"
    fi
    if test x"`echo ${out} | cut -d ' ' -f 2`" = x"branch"; then
	pass "${testing} <branch>"
    else
	fail "${testing} <branch>"
	fixme "get_URL returned ${out}"
    fi
else
    untested "${testing} http://username@<url>/<repo>.git"
fi

# The regular sources.conf won't have this entry.
testing="get_URL: sources.conf <repo>.git/<branch>@<revision> identifier should match"
if test ! -e "${PWD}/host.conf"; then
    out="`get_URL user_gcc.git/branch@12345`"
    if test x"`echo ${out} | cut -d ' ' -f 1`" = x"http://username@staging.git.linaro.org/git/toolchain/gcc.git"; then
	pass "${testing} http://username@<url>/<repo>.git"
    else
	fail "${testing} http://username@<url>/<repo>.git"
	fixme "get_URL returned ${out}"
    fi
    if test x"`echo ${out} | cut -d ' ' -f 2`" = x"branch"; then
	pass "${testing} <branch>"
    else
	fail "${testing} <branch>"
	fixme "get_URL returned ${out}"
    fi
    if test x"`echo ${out} | cut -d ' ' -f 3`" = x"12345"; then
	pass "${testing} <revision>"
    else
	fail "${testing} <revision>"
	fixme "get_URL returned ${out}"
    fi
else
    untested "${testing} http://username@<url>/<repo>.git"
fi

# The regular sources.conf won't have this entry.
testing="get_URL: sources.conf <repo>.git@<revision> identifier should match"
if test ! -e "${PWD}/host.conf"; then
    out="`get_URL user_gcc.git@12345`"
    if test x"`echo ${out} | cut -d ' ' -f 1`" = x"http://username@staging.git.linaro.org/git/toolchain/gcc.git"; then
	pass "${testing} http://username@<url>/<repo>.git"
    else
	fail "${testing} http://username@<url>/<repo>.git"
	fixme "get_URL returned ${out}"
    fi
    if test x"`echo ${out} | cut -d ' ' -f 2`" = x"12345"; then
   	pass "${testing} <revision>"
    else
	fail "${testing} <revision>"
	fixme "get_URL returned ${out}"
    fi
else
    untested "${testing} http://username@<url>/<repo>.git"
fi

# ----------------------------------------------------------------------------------
#
# Test package building

# dryrun=yes
# #gcc_version=linaro-4.8-2013.09
# gcc_version=git://git.linaro.org/toolchain/gcc.git/fsf-gcc-4_8-branch

# out="`binary_toolchain 2>&1 | tee xx |grep "DRYRUN:.*Jcvf"`"

# date="`date +%Y%m%d`"
# tarname="`echo $out | cut -d ' ' -f 9`"
# destdir="`echo $out | cut -d ' ' -f 10`"
# match="${local_snapshots}/gcc.git-${target}-${host}-${date}"

# if test "`echo ${tarname} | grep -c ${match}`" -eq 1; then
#     pass "binary_toolchain: git repository"
# else
#     fail "binary_toolchain: git repository"
#     fixme "get_URL returned ${out}"
# fi

# #binutils_version=linaro-4.8-2013.09
# binutils_version=git://git.linaro.org/toolchain/binutils.git
# out="`binary_sysroot 2>&1 | tee xx |grep "DRYRUN:.*Jcvf"`"
# tarname="`echo $out | cut -d ' ' -f 9`"
# destdir="`echo $out | cut -d ' ' -f 10`"
# match="${local_snapshots}/sysroot-eglibc-linaro-2.18-2013.09-${target}-${date}"
# echo "${tarname}"
# echo "${match}"
# if test "`echo ${tarname} | grep -c ${match}`" -eq 1; then
#     pass "binary_toolchain: git repository"
# else
#     fail "binary_toolchain: git repository"
#     fixme "get_URL returned ${out}"
# fi
# dryrun=no

echo "============= get_source() tests ================"
# TODO Test ${sources_conf} for ${in} for relevant tests.
#      Mark tests as untested if the expected match isn't in sources_conf.
#      This might be due to running testsuite in a builddir rather than a
#      source dir.

# get_sources might, at times peak at latest for a hint if it can't find
# things.  Keep it unset unless you want to test a specific code leg.
saved_latest=${latest}
latest=''

# Test get_source with a variety of inputs
testing="get_source: unknown repository"
in="somethingbogus"
out="`get_source ${in} 2>&1`"
if test $? -eq 1; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_source returned \"${out}\""
fi

testing="get_source: empty url"
in=''
out="`get_source ${in} 2>/dev/null`"
if test $? -eq 1; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_source returned \"${out}\""
fi

testing="get_source: git repository"
in="eglibc.git"
out="`get_source ${in}`"
if test x"${out}" = x"git://git.linaro.org/toolchain/eglibc.git"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_source returned ${out}"
fi

testing="get_source: git repository with branch"
in="eglibc.git/linaro_eglibc-2_17"
out="`get_source ${in}`"
if test x"${out}" = x"git://git.linaro.org/toolchain/eglibc.git linaro_eglibc-2_17"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_source returned ${out}"
fi

testing="get_source: git repository with branch and commit"
in="newlib.git/binutils-2_23-branch@e9a210b"
out="`get_source ${in}`"
if test x"${out}" = x"git://git.linaro.org/toolchain/newlib.git binutils-2_23-branch e9a210b"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_source returned ${out}"
fi

testing="get_source: <repo>.git@commit"
in="newlib.git@e9a210b"
out="`get_source ${in}`"
if test x"${out}" = x"git://git.linaro.org/toolchain/newlib.git e9a210b"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_source returned ${out}"
fi

testing="get_source: tar.bz2 archive"
in="gcc-linaro-4.8-2013.05.tar.bz2"
out="`get_source ${in}`"
if test x"${out}" = x"gcc-linaro-4.8-2013.05.tar.bz2"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_source returned \"${out}\""
fi

testing="get_source: Too many snapshot matches."
in="gcc-linaro"
out="`get_source ${in} 2>/dev/null`"
if test $? -eq 1; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_source returned ${out}"
fi

testing="get_source: Non-git direct url"
in="svn://gcc.gnu.org/svn/gcc/branches/gcc-4_7-branch"
out="`get_source ${in}`"
if test x"${out}" = x"svn://gcc.gnu.org/svn/gcc/branches/gcc-4_7-branch"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_source returned ${out}"
fi

testing="get_source: git direct url not ending in .git"
in="git://git.linaro.org/toolchain/eglibc"
out="`get_source ${in}`"
if test x"${out}" = x"git://git.linaro.org/toolchain/eglibc"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_source returned ${out}"
fi

testing="get_source: git direct url not ending in .git with revision returns bogus url."
in="git://git.linaro.org/toolchain/eglibc/<branch>@<revision>"
out="`get_source ${in} 2>/dev/null`"
if test x"${out}" = x"git://git.linaro.org/toolchain/eglibc/<branch>@<revision>"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_source returned ${out}"
fi

# These aren't valid if testing from a build directory.
testing="get_source: full url with <repo>.git with no matching source.conf entry should fail."
if test ! -e "${PWD}/host.conf"; then
    in="git://git.linaro.org/toolchain/foo.git"
    out="`get_source ${in} 2>/dev/null`"
    if test x"${out}" = x""; then
	pass "${testing}"
    else
	fail "${testing}"
	fixme "get_source returned ${out}"
    fi
else
    untested "${testing}"
fi

# These aren't valid if testing from a build directory.
testing="get_source: <repo>.git identifier with no matching source.conf entry should fail."
if test ! -e "${PWD}/host.conf"; then
    in="nomatch.git"
    out="`get_source ${in} 2>/dev/null`"
    if test x"${out}" = x""; then
	pass "${testing}"
    else
	fail "${testing}"
	fixme "get_source returned ${out}"
    fi
else
    untested "${testing}"
fi

# These aren't valid if testing from a build directory.
testing="get_source: <repo>.git@<revision> identifier with no matching source.conf entry should fail."
if test ! -e "${PWD}/host.conf"; then
    in="nomatch.git@12345"
    out="`get_source ${in} 2>/dev/null`"
    if test x"${out}" = x""; then
	pass "${testing}"
    else
	fail "${testing}"
	fixme "get_source returned ${out}"
    fi
else
    untested "${testing}"
fi

testing="get_source: tag matching an svn repo in ${sources_conf}"
in="gcc-4.8"
out="`get_source ${in} 2>/dev/null`"
if test x"${out}" = x"svn://gcc.gnu.org/svn/gcc/branches/gcc-4_8-branch"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_source returned ${out}"
fi

testing="get_source: <repo>.git matches non .git suffixed url."
in="foo.git"
if test ! -e "${PWD}/host.conf"; then
    out="`get_source ${in} 2>/dev/null`"
    if test x"${out}" = x"git://testingrepository/foo"; then
	pass "${testing}"
    else
	fail "${testing}"
	fixme "get_source returned ${out}"
    fi
else
    untested "${testing}"
fi

testing="get_source: <repo>.git/<branch> matches non .git suffixed url."
in="foo.git/bar"
if test ! -e "${PWD}/host.conf"; then
    out="`get_source ${in} 2>/dev/null`"
    if test x"${out}" = x"git://testingrepository/foo bar"; then
	pass "${testing}"
    else
	fail "${testing}"
	fixme "get_source returned ${out}"
    fi
else
    untested "${testing}"
fi

testing="get_source: <repo>.git/<branch>@<revision> matches non .git suffixed url."
in="foo.git/bar@12345"
if test ! -e "${PWD}/host.conf"; then
    out="`get_source ${in} 2>/dev/null`"
    if test x"${out}" = x"git://testingrepository/foo bar 12345"; then
	pass "${testing}"
    else
	fail "${testing}"
	fixme "get_source returned ${out}"
    fi
else
    untested "${testing}"
fi

in="foo.git@12345"
testing="get_source: ${sources_conf}:${in} matching no .git in <repo>@<revision>."
if test ! -e "${PWD}/host.conf"; then
    out="`get_source ${in} 2>/dev/null`"
    if test x"${out}" = x"git://testingrepository/foo 12345"; then
	pass "${testing}"
    else
	fail "${testing}"
	fixme "get_source returned ${out}"
    fi
else
    untested "${testing}"
fi

testing="get_source: partial match in snapshots, latest not set."
latest=''
in="gcc-linaro-4.8"
out="`get_source ${in} 2>/dev/null`"
if test x"${out}" = x""; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_source returned ${out}"
fi

testing="get_source: too many matches in snapshots, latest set."
latest="gcc-linaro-4.8-2013.06.tar.bz2"
in="gcc-linaro-4.8"
out="`get_source ${in} 2>/dev/null`"
if test x"${out}" = x"gcc-linaro-4.8-2013.06.tar.bz2"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_source returned ${out}"
fi

latest=${saved_latest}

# ----------------------------------------------------------------------------------

echo "========= create_release_tag() tests ============"

testing="create_release_tag: repository with branch and revision"
date="`date +%Y%m%d`"
in="gcc.git/gcc-4.8-branch@12345abcde"
out="`create_release_tag ${in} | grep -v TRACE`"
toolname="`echo ${out} | cut -d ' ' -f 1`"
branch="`echo ${out} | cut -d ' ' -f 2`"
revision="`echo ${out} | cut -d ' ' -f 3`"
if test x"${out}" = x"gcc-linaro~gcc-4.8-branch@12345abcde-${date}"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "create_release_tag returned ${out}"
fi

branch=
revision=
testing="create_release_tag: repository branch empty"
if test -d ${srcdir}; then
    in="gcc.git"
    out="`create_release_tag ${in} | grep -v TRACE`"
    if test "`echo ${out} | grep -c "gcc-linaro\@[a-z0-9]*-${date}"`" -gt 0; then
	pass "${testing}"
    else
	fail "${testing}"
	fixme "create_release_tag returned ${out}"
    fi
else
    untested "${testing}"
fi

testing="create_release_tag: tarball"
in="gcc-linaro-4.8-2013.06-1.tar.xz"
out="`create_release_tag ${in} | grep -v TRACE`"
if test x"${out}" = x"gcc-linaro-4.8-${date}"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "create_release_tag returned ${out}"
fi

# ----------------------------------------------------------------------------------
echo "============= checkout () tests ================"
echo "  Checking out sources into ${local_snapshots}"
echo "  Please be patient while sources are checked out...."
echo "================================================"

# These can be painfully slow so test small repos.

test_checkout ()
{
    local should=$1
    local testing=$2
    local package=$3
    local branch=$4
    local revision=$5

    in="${package}${branch:+/${branch}}${revision:+@${revision}}"
    local url=
    url="`get_URL ${in}`"

    if test `echo $url | grep -c "\.git "` -gt 0; then
	local package_url=`echo $url | cut -d ' ' -f 1`
	url="${package_url}${branch:+/${branch}}${revision:+@${revision}}"
    fi

    out="`(cd ${local_snapshots} && checkout ${url} 2>/dev/null)`"
    local tmp_workdir="${local_snapshots}/${package}${branch:+-${branch}}${revision:+@${revision}}"
    local branch_test=
    if test ! -d ${tmp_workdir}; then
	branch_test=0
    elif test x"${branch}" = x -a x"${revision}" = x; then
	branch_test=`(cd ${tmp_workdir} && git branch | grep -c "^\* master$")`
    else
	branch_test=`(cd ${tmp_workdir} && git branch | grep -c "^\* ${branch:+${branch}${revision:+_}}${revision:+${revision}}$")`
    fi

    if test x"${branch_test}" = x1 -a x"${should}" = xpass; then
	pass "${testing}"
	return 0
    elif test x"${branch_test}" = x1 -a x"${should}" = xfail; then
	fail "${testing}"
	return 1
    elif test x"${branch_test}" = x0 -a x"${should}" = xfail; then
	pass "${testing}"
	return 0
    else
	fail "${testing}"
	return 1
    fi
}

testing="checkout: http://git@<url>/<repo>.git"
if test ! -e "${PWD}/host.conf"; then
   package="cbuild2.git"
   branch=''
   revision=''
   should="pass"
   test_checkout "${should}" "${testing}" "${package}" "${branch}" "${revision}"
else
    untested "${testing}"
fi

testing="checkout: http://git@<url>/<repo>.git/<branch>"
if test ! -e "${PWD}/host.conf"; then
   package="cbuild2.git"
   branch="gerrit"
   revision=''
   should="pass"
   test_checkout "${should}" "${testing}" "${package}" "${branch}" "${revision}"
else
    untested "${testing}"
fi

testing="checkout: http://git@<url>/<repo>.git@<revision>"
if test ! -e "${PWD}/host.conf"; then
   package="cbuild2.git"
   branch=''
   revision="9bcced554dfc"
   should="pass"
   test_checkout "${should}" "${testing}" "${package}" "${branch}" "${revision}"
else
    untested "${testing}"
fi

testing="checkout: http://git@<url>/<repo>.git/unusedbranchnanme@<revision>"
if test ! -e "${PWD}/host.conf"; then
   package="cbuild2.git"
   branch="unusedbranchname"
   revision="9bcced554dfc"
   should="pass"
   test_checkout "${should}" "${testing}" "${package}" "${branch}" "${revision}"
else
    untested "${testing}"
fi

testing="checkout: http://git@<url>/<repo>.git/<nonexistentbranch> should fail."
if test ! -e "${PWD}/host.conf"; then
   package="cbuild2.git"
   branch="nonexistentbranch"
   revision=''
   should="fail"
   test_checkout "${should}" "${testing}" "${package}" "${branch}" "${revision}"
else
    untested "${testing}"
fi

testing="checkout: http://git@<url>/<repo>.git@<nonexistentrevision> should fail."
if test ! -e "${PWD}/host.conf"; then
   package="cbuild2.git"
   branch=''
   revision="123456bogusbranch"
   should="fail"
   test_checkout "${should}" "${testing}" "${package}" "${branch}" "${revision}"
else
    untested "${testing}"
fi


echo "============= additional get_srcdir () tests ================"
# Some of these are redundant with those in srcdir_tests but since
# already have cbuild2.git checked out we might as well test them here.
testing="get_srcdir: <repo>.git"
in="cbuild2.git"
out="`get_srcdir $in | grep -v TRACE`"
if test x"${out}" = x"${local_snapshots}/cbuild2.git"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_srcdir returned ${out}"
fi

testing="get_srcdir: <repo>.git@<revision>"
in="cbuild2.git@12345"
out="`get_srcdir $in | grep -v TRACE`"
if test x"${out}" = x"${local_snapshots}/cbuild2.git@12345"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_srcdir returned ${out}"
fi

testing="get_srcdir: <repo>.git/<branch>"
in="cbuild2.git/branch"
out="`get_srcdir $in | grep -v TRACE`"
if test x"${out}" = x"${local_snapshots}/cbuild2.git-branch"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_srcdir returned ${out}"
fi

testing="get_srcdir: <repo>.git/<branch>@<revision>"
in="cbuild2.git/branch@12345"
out="`get_srcdir $in | grep -v TRACE`"
if test x"${out}" = x"${local_snapshots}/cbuild2.git-branch@12345"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_srcdir returned ${out}"
fi

testing="get_srcdir: http://<user>@<url>/<repo>.git"
in="http://git@staging.git.linaro.org/git/toolchain/cbuild2.git"
out="`get_srcdir $in | grep -v TRACE`"
if test x"${out}" = x"${local_snapshots}/cbuild2.git"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_srcdir returned ${out}"
fi

testing="get_srcdir: http://<user>@<url>/<repo>.git@<revision>"
in="http://git@staging.git.linaro.org/git/toolchain/cbuild2.git@12345"
out="`get_srcdir $in | grep -v TRACE`"
if test x"${out}" = x"${local_snapshots}/cbuild2.git@12345"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_srcdir returned ${out}"
fi

. testsuite/git-parser-tests.sh
# ----------------------------------------------------------------------------------
# print the total of test results
totals

