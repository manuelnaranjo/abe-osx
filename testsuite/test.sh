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

# test an uncompressed tarball
in="http://cbuild.validation.linaro.org/snapshots/gdb-7.6~20121001+git3e2e76a.tar"
out="`get_toolname ${in}`"
if test ${out} = "gdb"; then
    pass "get_toolname: tarball uncompressed"
else
    fail "get_toolname: tarball uncompressed"
    fixme "${in} returned ${out}"
fi

# ----------------------------------------------------------------------------------
# test an compressed tarball
in="http://cbuild.validation.linaro.org/snapshots/gcc-linaro-4.8-2013.06-1.tar.xz"
out="`get_toolname ${in}`"
if test ${out} = "gcc"; then
    pass "get_toolname: tarball compressed"
else
    fail "get_toolname: tarball compressed"
    fixme "${in} returned ${out}"
fi

# ----------------------------------------------------------------------------------
# test an svn branch
in="svn://gcc.gnu.org/svn/gcc/branches/gcc-4_7-branch"
out="`get_toolname ${in}`"
if test ${out} = "gcc"; then
    pass "get_toolname: svn branch"
else
    fail "get_toolname: svn branch"
    fixme "${in} returned ${out}"
fi

# ----------------------------------------------------------------------------------
# test a bzr branch
in="lp:gdb-linaro/7.5"
out="`get_toolname ${in}`"
if test ${out} = "gdb"; then
    pass "get_toolname: bzr branch"
else
    fail "get_toolname: bzr branch"
    fixme "${in} returned ${out}"
fi

# ----------------------------------------------------------------------------------
# test a git branch
in="git://git.linaro.org/toolchain/binutils.git"
out="`get_toolname ${in}`"
if test ${out} = "binutils"; then
    pass "get_toolname: git branch"
else
    fail "get_toolname: git branch"
    fixme "${in} returned ${out}"
fi

in="eglibc.git/linaro_eglibc-2_18"
out="`get_toolname ${in}`"
if test ${out} = "eglibc"; then
    pass "get_toolname: git branch"
else
    fail "get_toolname: git branch"
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

out="`find_snapshot gcc 2>/dev/null`"
if test $? -eq 1; then
    pass "find_snapshot: not unique tarball name"
else
    fail "find_snapshot: not unique tarball name"
    fixme "find_snapshot returned ${out}"
fi

out="`find_snapshot gcc-linaro-4.8-2013.08`"
if test $? -eq 0; then
    pass "find_snapshot: unique tarball name"
else
    fail "find_snapshot: unique tarball name"
    fixme "find_snapshot returned ${out}"
fi

out="`find_snapshot gcc-linaro-4.8-2013.06XXX 2>/dev/null`"
if test $? -eq 1; then
    pass "find_snapshot: unknown tarball name"
else
    fail "find_snapshot: unknown tarball name"
    fixme "find_snapshot returned ${out}"
fi

# ----------------------------------------------------------------------------------
echo "============= get_URL() tests ================"

# This will dump an error to stderr, so squelch it.
out="`get_URL gcc 2>/dev/null`"
if test $? -eq 1; then
    pass "get_URL: not unique in sources.conf file"
else
    fail "get_URL: not unique in sources.conf file"
    fixme "get_URL returned ${out}"
fi

out="`get_URL gcc-linaro-4.8-2013.06-1 2>/dev/null`"
if test $? -eq 1; then
    pass "get_URL: unmatching snapshot not found in sources.conf file"
else
    fail "get_URL: unmatching snapshot not found in sources.conf file"
    fixme "get_URL returned ${out}"
fi

out="`get_URL gcc.git`"
if test x"`echo ${out} | cut -d ' ' -f 1`" = x"git://git.linaro.org/toolchain/gcc.git"; then
    pass "get_URL: git URL with no branch or revision info"
else
    fail "get_URL: git URL with no branch or revision info"
    fixme "get_URL returned ${out}"
fi

out="`get_URL gcc.git@12345`"
if test x"`echo ${out} | cut -d ' ' -f 1`" = x"git://git.linaro.org/toolchain/gcc.git"; then
    pass "get_URL: match URL for URL.git@revision"
else
    fail "get_URL: match URL for URL.git@revision"
    fixme "get_URL returned ${out}"
fi
if test x"`echo ${out} | cut -d ' ' -f 2`" = x"12345"; then
    pass "get_URL: match revision for URL.git@revision"
else
    fail "get_URL: match revision for URL.git@revision"
    fixme "get_URL returned ${out}"
fi

out="`get_URL nomatch.git@12345 2>/dev/null`"
if test x"${out}" = x""; then
    pass "get_URL: match URL for nomatch.git@revision should fail"
else
    fail "get_URL: match URL for nomatch.git@revision should fail"
    fixme "get_URL returned ${out}"
fi

out="`get_URL gcc.git/linaro-4.8-branch@12345`"
if test x"`echo ${out} | cut -d ' ' -f 1`" = x"git://git.linaro.org/toolchain/gcc.git"; then
    pass "get_URL: URL with tool.git/branch@revision "
else
    fail "get_URL: URL with tool.git/branch@revision "
    fixme "get_URL returned ${out}"
fi
if test x"`echo ${out} | cut -d ' ' -f 2`" = x"linaro-4.8-branch"; then
    pass "get_URL: branch with tool.git/branch@revision "
else
    fail "get_URL: branch with tool.git/branch@revision "
    fixme "get_URL returned ${out}"
fi
if test x"`echo ${out} | cut -d ' ' -f 3`" = x"12345"; then
    pass "get_URL: revision with tool.git/branch@revision "
else
    fail "get_URL: revision with tool.git/branch@revision "
    fixme "get_URL returned ${out}"
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
in="asdfasdf"
out="`get_source ${in} 2>&1`"
if test $? -eq 1; then
    pass "get_source: unknown repository"
else
    fail "get_source: unknown repository"
    fixme "get_source returned \"${out}\""
fi

in=''
out="`get_source ${in} 2>/dev/null`"
if test $? -eq 1; then
    pass "get_source: empty url"
else
    fail "get_source: empty url"
    fixme "get_source returned \"${out}\""
fi

in="eglibc.git"
out="`get_source ${in}`"
if test x"${out}" = x"git://git.linaro.org/toolchain/eglibc.git"; then
    pass "get_source: git repository"
else
    fail "get_source: git repository"
    fixme "get_source returned ${out}"
fi

in="eglibc.git/linaro_eglibc-2_17"
out="`get_source ${in}`"
if test x"${out}" = x"git://git.linaro.org/toolchain/eglibc.git linaro_eglibc-2_17"; then
    pass "get_source: git repository with branch"
else
    fail "get_source: git repository with branch"
    fixme "get_source returned ${out}"
fi

in="newlib.git/binutils-2_23-branch@e9a210b"
out="`get_source ${in}`"
if test x"${out}" = x"git://git.linaro.org/toolchain/newlib.git binutils-2_23-branch e9a210b"; then
    pass "get_source: git repository with branch and commit"
else
    fail "get_source: git repository with branch and commit"
    fixme "get_source returned ${out}"
fi

in="newlib.git@e9a210b"
out="`get_source ${in}`"
if test x"${out}" = x"git://git.linaro.org/toolchain/newlib.git e9a210b"; then
    pass "get_source: <repo>.git@commit"
else
    fail "get_source: <repo>.git@commit"
    fixme "get_source returned ${out}"
fi

in="gcc-linaro-4.8-2013.05.tar.bz2"
out="`get_source ${in}`"
if test x"${out}" = x"gcc-linaro-4.8-2013.05.tar.bz2"; then
    pass "get_source: tar.bz2 archive"
else
    fail "get_source: tar.bz2 archive"
    fixme "get_source returned \"${out}\""
fi

in="gcc-linaro"
out="`get_source ${in} 2>/dev/null`"
if test $? -eq 1; then
    pass "get_source: Too many snapshot matches."
else
    fail "get_source: Too many snapshot matches."
    fixme "get_source returned ${out}"
fi

in="svn://gcc.gnu.org/svn/gcc/branches/gcc-4_7-branch"
out="`get_source ${in}`"
if test x"${out}" = x"svn://gcc.gnu.org/svn/gcc/branches/gcc-4_7-branch"; then
    pass "get_source: Non-git direct url"
else
    fail "get_source: Non-git direct url"
    fixme "get_source returned ${out}"
fi

in="git://git.linaro.org/toolchain/eglibc"
out="`get_source ${in}`"
if test x"${out}" = x"git://git.linaro.org/toolchain/eglibc"; then
    pass "get_source: git direct url not ending in .git"
else
    fail "get_source: git direct url not ending in .git"
    fixme "get_source returned ${out}"
fi

in="git://git.linaro.org/toolchain/eglibc/branchname@revision"
out="`get_source ${in} 2>/dev/null`"
if test x"${out}" = x"git://git.linaro.org/toolchain/eglibc/branchname@revision"; then
    pass "get_source: git direct url not ending in .git with revision returns bogus url."
else
    fail "get_source: git direct url not ending in .git with revision returns bogus url."
    fixme "get_source returned ${out}"
fi

in="git://git.linaro.org/toolchain/foo.git"
out="`get_source ${in} 2>/dev/null`"
if test x"${out}" = x""; then
    pass "get_source: full url with <repo>.git with no matching source.conf entry should fail."
else
    fail "get_source: full url with <repo>.git with no matching source.conf entry should fail."
    fixme "get_source returned ${out}"
fi

in="nomatch.git"
out="`get_source ${in} 2>/dev/null`"
if test x"${out}" = x""; then
    pass "get_source: <repo>.git identifier with no matching source.conf entry should fail."
else
    fail "get_source: <repo>.git identifier with no matching source.conf entry should fail."
    fixme "get_source returned ${out}"
fi

in="nomatch.git@revision"
out="`get_source ${in} 2>/dev/null`"
if test x"${out}" = x""; then
    pass "get_source: <repo>.git@rev identifier with no matching source.conf entry should fail."
else
    pass "get_source: <repo>.git@rev identifier with no matching source.conf entry should fail."
    fixme "get_source returned ${out}"
fi

in="gcc-4.8"
out="`get_source ${in} 2>/dev/null`"
if test x"${out}" = x"svn://gcc.gnu.org/svn/gcc/branches/gcc-4_8-branch"; then
    pass "get_source: tag matching an svn repo in ${sources_conf}"
else
    fail "get_source: tag matching an svn repo in ${sources_conf}"
    fixme "get_source returned ${out}"
fi

in="bitbake.git"
out="`get_source ${in} 2>/dev/null`"
if test x"${out}" = x"git://git.openembedded.org/bitbake"; then
    pass "get_source: ${sources_conf}:${in} matching non .git suffixed repo."
else
    fail "get_source: ${sources_conf}:${in} matching non .git suffixed repo."
    fixme "get_source returned ${out}"
fi

in="foo.git"
out="`get_source ${in} 2>/dev/null`"
if test x"${out}" = x"git://testingrepository/foo"; then
    pass "get_source: ${sources_conf}:${in} matching non .git suffixed repo."
else
    fail "get_source: ${sources_conf}:${in} matching non .git suffixed repo."
    fixme "get_source returned ${out}"
fi

in="foo.git/bar"
out="`get_source ${in} 2>/dev/null`"
if test x"${out}" = x"git://testingrepository/foo bar"; then
    pass "get_source: ${sources_conf}:${in} matching non .git suffixed repo with branch."
else
    fail "get_source: ${sources_conf}:${in} matching non .git suffixed repo with branch."
    fixme "get_source returned ${out}"
fi

in="foo.git/bar@rev"
out="`get_source ${in} 2>/dev/null`"
if test x"${out}" = x"git://testingrepository/foo bar rev"; then
    pass "get_source: ${sources_conf}:${in} matching non .git suffixed repo with branch and revision."
else
    fail "get_source: ${sources_conf}:${in} matching non .git suffixed repo with branch and revision."
    fixme "get_source returned ${out}"
fi

in="foo.git@rev"
out="`get_source ${in} 2>/dev/null`"
if test x"${out}" = x"git://testingrepository/foo rev"; then
    pass "get_source: ${sources_conf}:${in} matching non .git suffixed repo with revision."
else
    fail "get_source: ${sources_conf}:${in} matching non .git suffixed repo with revision."
    fixme "get_source returned ${out}"
fi

latest=''
in="gcc-linaro-4.8"
out="`get_source ${in} 2>/dev/null`"
if test x"${out}" = x""; then
    pass "get_source: partial match in snapshots, latest not set."
else
    fail "get_source: partial match in snapshots, latest not set."
    fixme "get_source returned ${out}"
fi

latest="gcc-linaro-4.8-2013.06.tar.bz2"
in="gcc-linaro-4.8"
out="`get_source ${in} 2>/dev/null`"
if test x"${out}" = x"gcc-linaro-4.8-2013.06.tar.bz2"; then
    pass "get_source: too many matches in snapshots, latest set."
else
    fail "get_source: partial matches in snapshots, latest set."
    fixme "get_source returned ${out}"
fi

latest=${saved_latest}

# ----------------------------------------------------------------------------------

echo "========= create_release_tag() tests ============"

date="`date +%Y%m%d`"
in="gcc.git/gcc-4.8-branch@12345abcde"
out="`create_release_tag ${in} | grep -v TRACE`"
toolname="`echo ${out} | cut -d ' ' -f 1`"
branch="`echo ${out} | cut -d ' ' -f 2`"
revision="`echo ${out} | cut -d ' ' -f 3`"
if test x"${out}" = x"gcc-linaro~gcc-4.8-branch@12345abcde-${date}"; then
    pass "create_release_tag: repository with branch and revision"
else
    fail "create_release_tag: repository with branch and revision"
    fixme "create_release_tag returned ${out}"
fi

branch=
revision=
if test -d ${srcdir}; then
    in="gcc.git"
    out="`create_release_tag ${in} | grep -v TRACE`"
    if test "`echo ${out} | grep -c "gcc-linaro\@[a-z0-9]*-${date}"`" -gt 0; then
	pass "create_release_tag: repository branch empty"
    else
	fail "create_release_tag: repository branch empty"
	fixme "create_release_tag returned ${out}"
    fi
else
    untested "create_release_tag: repository branch empty"
fi

in="gcc-linaro-4.8-2013.06-1.tar.xz"
out="`create_release_tag ${in} | grep -v TRACE`"
if test x"${out}" = x"gcc-linaro-4.8-${date}"; then
    pass "create_release_tag: tarball"
else
    fail "create_release_tag: tarball"
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
    in="${package}${branch:+/${branch}}${revision:+@${revision}}"
    url="`get_URL ${in}`"

    if test `echo $url | grep -c "\.git "` -gt 0; then
	package_url=`echo $url | cut -d ' ' -f 1`
	url="${package_url}${branch:+/${branch}}${revision:+@${revision}}"
    fi

    out="`(cd ${local_snapshots} && checkout ${url} 2>/dev/null)`"
    tmp_workdir="${local_snapshots}/${package}${branch:+-${branch}}${revision:+@${revision}}"
    if test ! -d ${tmp_workdir}; then
	branch_test=0
    elif test x"${branch}" = x -a x"${revision}" = x; then
	branch_test=`(cd ${tmp_workdir} && git branch | grep -c "^* master")`
    else
	branch_test=`(cd ${tmp_workdir} && git branch | grep -c "^* ${branch:+${branch}${revision:+_}}${revision:+${revision}}")`
    fi

    if test x"${branch_test}" = x1; then
	pass "checkout: ${in}."
	return 0
    else
	fail "checkout: ${in}."
	return 1
    fi
}

package="newlib.git"
branch=
revision=
test_checkout

package="newlib.git"
branch=
revision="71a86aef245be6fd9cc"
test_checkout

package="newlib.git"
branch="phonybranchname"
revision="71a86aef245be6fd9cc"
test_checkout

package="newlib.git"
branch="linaro_newlib-branch"
revision=
test_checkout

# A real branch name is treated like a phony branch name if there
# is a revision, i.e., it's ignored and used as a directory tag.
package="newlib.git"
branch="linaro_newlib-branch"
revision="71a86aef245be6fd9cc"
test_checkout

# ----------------------------------------------------------------------------------
# print the total of test results
totals

