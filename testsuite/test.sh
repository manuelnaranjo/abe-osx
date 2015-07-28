#!/bin/bash

# common.sh loads all the files of library functions.
if test x"`echo \`dirname "$0"\` | sed 's:^\./::'`" != x"testsuite"; then
    echo "WARNING: Should be run from top abe dir" > /dev/stderr
    topdir="`readlink -e \`dirname $0\`/..`"
else
    topdir=$PWD
fi

test_sources_conf="${topdir}/testsuite/test_sources.conf"
# configure generates host.conf from host.conf.in.
if test -e "${PWD}/host.conf"; then
    . "${PWD}/host.conf"
    . "${topdir}/lib/common.sh" || exit 1
else
    build="`sh ${topdir}/config.guess`"
    . "${topdir}/lib/common.sh" || exit 1
    warning "no host.conf file!  Synthesizing a framework for testing."

    remote_snapshots="${remote_snapshots:-/snapshots}"
    wget_bin=/usr/bin/wget
    NEWWORKDIR=/usr/local/bin/git-new-workdir
    sources_conf=${topdir}/testsuite/test_sources.conf
fi
echo "Testsuite using ${sources_conf}"

# Use wget -q in the testsuite
wget_quiet=yes

# We always override $local_snapshots so that we don't damage or move the
# local_snapshots directory of an existing build.
local_abe_tmp="`mktemp -d /tmp/abe.$$.XXX`"
local_snapshots="${local_abe_tmp}/snapshots"

# If this isn't being run in an existing build dir, create one in our
# temp directory.
if test ! -d "${local_builds}"; then
    local_builds="${local_abe_tmp}/builds"
    out="`mkdir -p ${local_builds}`"
    if test "$?" -gt 1; then
	error "Couldn't create local_builds dir ${local_builds}"
	exit 1
    fi
fi

# Let's make sure that the snapshots portion of the directory is created before
# we use it just to be safe.
out="`mkdir -p ${local_snapshots}`"
if test "$?" -gt 1; then
    error "Couldn't create local_snapshots dir ${local_snapshots}"
    exit 1
fi

# Let's make sure that the build portion of the directory is created before
# we use it just to be safe.
out="`mkdir -p ${local_snapshots}`"


# Since we're testing, we don't load the host.conf file, instead
# we create false values that stay consistent.
abe_top=/build/abe/test
hostname=test.foobar.org
target=x86_64-linux-gnu

if test x"$1" = x"-v"; then
    debug=yes
fi

fixme()
{
    if test x"${debug}" = x"yes"; then
	echo "($BASH_LINENO): $*" 1>&2
    fi
}

passes=0
pass()
{
    echo "PASS: $1"
    passes="`expr ${passes} + 1`"
}

xpasses=0
xpass()
{
    echo "XPASS: $1"
    xpasses="`expr ${xpasses} + 1`"
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

xfailures=0
xfail()
{
    echo "XFAIL: $1"
    xfailures="`expr ${xfailures} + 1`"
}

totals()
{
    echo ""
    echo "Total test results:"
    echo "	Passes: ${passes}"
    echo "	Failures: ${failures}"
    if test ${xpasses} -gt 0; then
	echo "	Unexpected Passes: ${xpasses}"
    fi
    if test ${xfailures} -gt 0; then
	echo "	Expected Failures: ${xfailures}"
    fi
    if test ${untested} -gt 0; then
	echo "	Untested: ${untested}"
    fi
}

#
# common.sh tests
#
# Pretty much everything uses the git parser so test it first.
. "${topdir}/testsuite/git-parser-tests.sh"
. "${topdir}/testsuite/stamp-tests.sh"
. "${topdir}/testsuite/normalize-tests.sh"
. "${topdir}/testsuite/builddir-tests.sh"
. "${topdir}/testsuite/dryrun-tests.sh"
#. "${topdir}/testsuite/gerrit-tests.sh"
#. "${topdir}/testsuite/report-tests.sh"

# ----------------------------------------------------------------------------------

echo "=========== is_package_in_runtests() tests ============="


# test the package at the beginning of the list
in_runtests="glibc gdb gcc binutils"
testing="is_package_in_runtests \"${in_runtests}\" glibc"
in_package="glibc"
out="`is_package_in_runtests "${in_runtests}" ${in_package}`"
ret=$?
if test ${ret} -eq 0; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "is_package_in_runtests \"${in_runtests}\" ${in_package} resulted in '${ret}'"
fi

# test the package at the end of the list
in_runtests="glibc gdb gcc binutils"
testing="is_package_in_runtests \"${in_runtests}\" binutils"
in_package="binutils"
out="`is_package_in_runtests "${in_runtests}" ${in_package}`"
ret=$?
if test ${ret} -eq 0; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "is_package_in_runtests \"${in_runtests}\" ${in_package} resulted in '${ret}'"
fi

# test the package in the middle of the list
in_runtests="glibc gdb gcc binutils"
testing="is_package_in_runtests \"${in_runtests}\" gdb"
in_package="gdb"
out="`is_package_in_runtests "${in_runtests}" ${in_package}`"
ret=$?
if test ${ret} -eq 0; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "is_package_in_runtests \"${in_runtests}\" ${in_package} resulted in '${ret}'"
fi

# test a package not in the list
in_runtests="glibc gdb gcc binutils"
testing="is_package_in_runtests \"${in_runtests}\" foo"
in_package="foo"
out="`is_package_in_runtests "${in_runtests}" ${in_package}`"
ret=$?
if test ${ret} -eq 1; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "is_package_in_runtests \"${in_runtests}\" ${in_package} resulted in '${ret}' expected '1'"
fi

# test a partial package name
in_runtests="glibc gdb gcc binutils"
testing="is_package_in_runtests \"${in_runtests}\" gd"
in_package="gd"
out="`is_package_in_runtests "${in_runtests}" ${in_package}`"
ret=$?
if test ${ret} -eq 1; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "is_package_in_runtests \"${in_runtests}\" ${in_package} resulted in '${ret}' expected '1'"
fi

# test that unquoted $runtests fails
in_runtests="glibc gdb gcc binutils"
testing="is_package_in_runtests ${in_runtests} glibc (unquoted \${in_runtests})"
in_package="glibc"
out="`is_package_in_runtests ${in_runtests} ${in_package}`"
ret=$?
if test ${ret} -eq 1; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "is_package_in_runtests ${in_runtests} ${in_package} resulted in '${ret}'"
fi



echo "============= get_toolname() tests ================"

testing="get_toolname: uncompressed tarball"
in="http://abe.validation.linaro.org/snapshots/gdb-7.6~20121001+git3e2e76a.tar"
out="`get_toolname ${in}`"
if test ${out} = "gdb"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out}"
fi

# ----------------------------------------------------------------------------------
testing="get_toolname: compressed tarball"
in="http://abe.validation.linaro.org/snapshots/gcc-linaro-4.8-2013.06-1.tar.xz"
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
# Bzr branches are no longer actively maintained in abe.
#testing="get_toolname: bzr <repo> -linaro/<branch>"
#in="lp:gdb-linaro/7.5"
#out="`get_toolname ${in}`"
#if test ${out} = "gdb"; then
#    pass "${testing}"
#else
#    fail "${testing}"
#    fixme "${in} returned ${out}"
#fi

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

testing="get_toolname: git://<repo>[no .git suffix]@<revision>."
# This works, but please don't do this.
in="git://git.linaro.org/toolchain/binutils@12345"
out="`get_toolname ${in}`"
match="binutils"
if test x"${out}" = x"${match}"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out} but expected ${match}"
fi

# ----------------------------------------------------------------------------------
# Test git:// git combinations
testing="get_toolname: git://<repo>.git"
in="git://git.linaro.org/toolchain/binutils.git"
out="`get_toolname ${in}`"
if test x"${out}" = x"binutils"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out}"
fi

testing="get_toolname: git://<repo>.git/<branch>"
in="git://git.linaro.org/toolchain/binutils.git/2.4-branch"
out="`get_toolname ${in}`"
if test x"${out}" = x"binutils"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out}"
fi

testing="get_toolname: git://<repo>.git/<branch>@<revision>"
in="git://git.linaro.org/toolchain/binutils.git/2.4-branch@12345"
out="`get_toolname ${in}`"
if test x"${out}" = x"binutils"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out}"
fi

testing="get_toolname: git://<repo>.git@<revision>"
in="git://git.linaro.org/toolchain/binutils.git@12345"
out="`get_toolname ${in}`"
if test x"${out}" = x"binutils"; then
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
if test x"${out}" = x"binutils"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out}"
fi

testing="get_toolname: http://<repo>.git/<branch>"
in="http://staging.git.linaro.org/git/toolchain/binutils.git/2.4-branch"
out="`get_toolname ${in}`"
if test x"${out}" = x"binutils"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out}"
fi

testing="get_toolname: http://<repo>.git/<branch>@<revision>"
in="http://staging.git.linaro.org/git/toolchain/binutils.git/2.4-branch@12345"
out="`get_toolname ${in}`"
if test x"${out}" = x"binutils"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out}"
fi

testing="get_toolname: http://<repo>.git@<revision>"
in="http://staging.git.linaro.org/git/toolchain/binutils.git@12345"
out="`get_toolname ${in}`"
if test x"${out}" = x"binutils"; then
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
if test x"${out}" = x"binutils"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out}"
fi

testing="get_toolname: http://<user>@<repo>.git/<branch>"
in="http://git@staging.git.linaro.org/git/toolchain/binutils.git/2.4-branch"
out="`get_toolname ${in}`"
if test x"${out}" = x"binutils"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out}"
fi

testing="get_toolname: http://<user>@<repo>.git/<branch>@<revision>"
in="http://git@staging.git.linaro.org/git/toolchain/binutils.git/2.4-branch@12345"
out="`get_toolname ${in}`"
if test x"${out}" = x"binutils"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out}"
fi

testing="get_toolname: http://<user>@<repo>.git@<revision>"
in="http://git@staging.git.linaro.org/git/toolchain/binutils.git@12345"
out="`get_toolname ${in}`"
if test x"${out}" = x"binutils"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out}"
fi

# ----------------------------------------------------------------------------------
testing="get_toolname: sources.conf identifier <repo>.git"
in="eglibc.git"
out="`get_toolname ${in}`"
if test x"${out}" = x"eglibc"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out}"
fi

testing="get_toolname: sources.conf identifier <repo>.git/<branch>"
in="eglibc.git/linaro_eglibc-2_18"
out="`get_toolname ${in}`"
if test x"${out}" = x"eglibc"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out}"
fi

testing="get_toolname: sources.conf identifier <repo>.git/<branch>@<revision>"
in="eglibc.git/linaro_eglibc-2_18@12345"
out="`get_toolname ${in}`"
if test x"${out}" = x"eglibc"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out}"
fi

testing="get_toolname: sources.conf identifier <repo>.git@<revision>"
in="eglibc.git@12345"
out="`get_toolname ${in}`"
if test x"${out}" = x"eglibc"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out}"
fi

testing="get_toolname: combined binutils-gdb repository with gdb branch"
in="binutils-gdb.git/gdb_7_6-branch"
out="`get_toolname ${in}`"
match="gdb"
if test x"${out}" = x"${match}"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out} expected ${match}"
fi

testing="get_toolname: combined binutils-gdb repository with binutils branch"
in="binutils-gdb.git/binutils-2_24"
out="`get_toolname ${in}`"
match="binutils"
if test x"${out}" = x"${match}"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out} but expected ${match}"
fi

# The special casing for binutils-gdb.git was failing in this one.
testing="get_toolname: combined binutils-gdb repository with linaro binutils branch"
in="binutils-gdb.git/linaro_binutils-2_24_branch"
out="`get_toolname ${in}`"
match="binutils"
if test x"${out}" = x"${match}"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out} but expected ${match}"
fi



testing="get_toolname: svn archive with /trunk trailing designator"
in="http://llvm.org/svn/llvm-project/cfe/trunk"
out="`get_toolname ${in}`"
match="cfe"
if test x"${out}" = x"${match}"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out} but expected ${match}"
fi

# ----------------------------------------------------------------------------------
echo "============= fetch_http() tests ================"

# Download the first time without force.
out="`fetch_http infrastructure/gmp-5.1.3.tar.xz 2>/dev/null`"
if test $? -eq 0 -a -e ${local_snapshots}/infrastructure/gmp-5.1.3.tar.xz; then
    pass "fetch_http infrastructure/gmp-5.1.3.tar.xz"
else
    fail "fetch_http infrastructure/gmp-5.1.3.tar.xz"
fi

# Get the timestamp of the file.
gmp_stamp1=`stat -c %X ${local_snapshots}/infrastructure/gmp-5.1.3.tar.xz`

# Download it again
out="`fetch_http infrastructure/gmp-5.1.3.tar.xz 2>/dev/null`"
ret=$?

# Get the timestamp of the file after another fetch.
gmp_stamp2=`stat -c %X ${local_snapshots}/infrastructure/gmp-5.1.3.tar.xz`

# They should be the same timestamp.
if test $ret -eq 0 -a ${gmp_stamp1} -eq ${gmp_stamp2}; then
    pass "fetch_http infrastructure/gmp-5.1.3.tar.xz didn't update as expected (force=no)"
else
    fail "fetch_http infrastructure/gmp-5.1.3.tar.xz updated unexpectedly (force=no)"
fi

# Now try it with force on
out="`force=yes fetch_http infrastructure/gmp-5.1.3.tar.xz 2>/dev/null`"
if test $? -gt 0; then
    fail "fetch_http infrastructure/gmp-5.1.3.tar.xz with \${force}=yes when source exists"
else
    pass "fetch_http infrastructure/gmp-5.1.3.tar.xz with \${force}=yes when source exists"
fi

# Get the timestamp of the file after another fetch.
gmp_stamp3=`stat -c %X ${local_snapshots}/infrastructure/gmp-5.1.3.tar.xz`

if test ${gmp_stamp1} -eq ${gmp_stamp3}; then
    fail "fetch_http infrastructure/gmp-5.1.3.tar.xz with \${force}=yes has unexpected matching timestamps"
else
    pass "fetch_http infrastructure/gmp-5.1.3.tar.xz with \${force}=yes has unmatching timestamps as expected."
fi

# Make sure force doesn't get in the way of a clean download.
rm ${local_snapshots}/infrastructure/gmp-5.1.3.tar.xz

# force should override supdate and this should download for the first time.
out="`force=yes fetch_http infrastructure/gmp-5.1.3.tar.xz 2>/dev/null`"
if test $? -gt 0; then
    fail "fetch_http infrastructure/gmp-5.1.3.tar.xz with \${force}=yes and sources don't exist"
else
    pass "fetch_http infrastructure/gmp-5.1.3.tar.xz with \${force}=yes and sources don't exist"
fi

out="`fetch_http md5sums 2>/dev/null`"
if test $? -eq 0; then
    pass "fetch_http md5sums"
else
    fail "fetch_http md5sums"
fi

# Test the case where wget_bin isn't set.
rm ${local_snapshots}/infrastructure/gmp-5.1.3.tar.xz

out="`unset wget_bin; fetch_http infrastructure/gmp-5.1.3.tar.xz 2>/dev/null`"
if test $? -gt 0; then
    pass "unset wget_bin; fetch_http infrastructure/gmp-5.1.3.tar.xz should fail."
else
    fail "unset wget_bin; fetch_http infrastructure/gmp-5.1.3.tar.xz should fail."
fi

# Verify that '1' is returned when a non-existent file is requested.
out="`fetch_http no_such_file 2>/dev/null`"
if test $? -gt 0; then
    pass "fetch_http no_such_file (implicit \${supdate}=yes) should fail."
else
    fail "fetch_http no_such_file (implicit \${supdate}=yes) should fail."
fi

echo "============= fetch() tests ================"

# remove md5sums so we can test that fetch() fails.
if test -e "${local_snapshots}/md5sums"; then
    rm ${local_snapshots}/md5sums
fi

fetch_http md5sums 2>/dev/null
if test ! -e "${local_snapshots}/md5sums"; then
    fail "Did not find ${local_snapshots}/md5sums"
    echo "md5sums needed for snapshots, get_URL, and get_sources tests.  Check your network connectivity." 1>&2
    exit 1;
else
    pass "Found ${local_snapshots}/md5sums"
fi

out="`fetch md5sums 2>/dev/null`"
if test $? -gt 0; then
    pass "fetch md5sums should fail because md5sums isn't in ${snapshots}/md5sums."
else
    fail "fetch md5sums should fail because md5sums isn't in ${snapshots}/md5sums."
fi

# Fetch with no file name should error.
out="`fetch 2>/dev/null`"
if test $? -gt 0; then
    pass "fetch <with no filename should error>"
else
    fail "fetch <with no filename should error>"
fi

# Test fetch from server with a partial name.
rm ${local_snapshots}/infrastructure/gmp-5.1* &>/dev/null
out="`fetch "infrastructure/gmp-5.1" 2>/dev/null`"
if test $? -gt 0 -o ! -e "${local_snapshots}/infrastructure/gmp-5.1.3.tar.xz"; then
    fail "fetch infrastructure/gmp-5.1 (with partial name) from server failed unexpectedly."
else
    pass "fetch infrastructure/gmp-5.1 (with partial name) from server passed as expected."
fi

# Create a git_reference_dir
local_refdir="${local_snapshots}/../refdir"
mkdir -p ${local_refdir}/infrastructure
# We need a way to differentiate the refdir version.
cp ${local_snapshots}/infrastructure/gmp-5.1* ${local_refdir}/infrastructure/gmp-5.1.3.tar.xz
rm ${local_snapshots}/infrastructure/gmp-5.1* &>/dev/null

# Use fetch that goes to a reference dir using a shortname
out="`git_reference_dir=${local_refdir} fetch infrastructure/gmp-5.1 2>/dev/null`"
if test $? -gt 0 -o ! -e "${local_snapshots}/infrastructure/gmp-5.1.3.tar.xz"; then
    fail "fetch infrastructure/gmp-5.1 (with partial name) from reference dir failed unexpectedly."
else
    pass "fetch infrastructure/gmp-5.1 (with partial name) from reference dir passed as expected."
fi

rm ${local_snapshots}/infrastructure/gmp-5.1* &>/dev/null
# Use fetch that goes to a reference dir using a longname
out="`git_reference_dir=${local_refdir} fetch infrastructure/gmp-5.1.3.tar.xz 2>/dev/null`"
if test $? -gt 0 -o ! -e "${local_snapshots}/infrastructure/gmp-5.1.3.tar.xz"; then
    fail "fetch infrastructure/gmp-5.1 (with full name) from reference dir failed unexpectedly."
else
    pass "fetch infrastructure/gmp-5.1 (with full name) from reference dir passed as expected."
fi

rm ${local_snapshots}/infrastructure/gmp-5.1*

# Replace with a marked version so we can tell if it's copied the reference
# versions erroneously.
rm ${local_refdir}/infrastructure/gmp-5.1.3.tar.xz
echo "DEADBEEF" > ${local_refdir}/infrastructure/gmp-5.1.3.tar.xz

# Use fetch that finds a git reference dir but is forced to use the server.
out="`force=yes git_reference_dir=${local_refdir} fetch infrastructure/gmp-5.1.3.tar.xz 2>/dev/null`"
if test $? -gt 0; then
    fail "fetch infrastructure/gmp-5.1 (with full name) from reference dir failed unexpectedly."
elif test x"$(grep DEADBEEF ${local_snapshots}/infrastructure/gmp-5.1.3.tar.xz)" != x""; then
    fail "fetch infrastructure/gmp-5.1 pulled from reference dir instead of server."
else
    pass "fetch infrastructure/gmp-5.1 (with full name) from reference dir passed as expected."
fi

# The next test makes sure that the failure is due to a file md5sum mismatch.
rm ${local_refdir}/infrastructure/gmp-5.1.3.tar.xz
echo "DEADBEEF" > ${local_refdir}/infrastructure/gmp-5.1.3.tar.xz
out="`git_reference_dir=${local_refdir} fetch infrastructure/gmp-5.1.3.tar.xz 2>/dev/null`"
if test $? -gt 0 -a x"$(grep DEADBEEF ${local_snapshots}/infrastructure/gmp-5.1.3.tar.xz)" != x""; then
    pass "fetch infrastructure/gmp-5.1 --force=yes git_reference_dir=foo failed because md5sum doesn't match."
else
    fail "fetch infrastructure/gmp-5.1 --force=yes git_reference_dir=foo unexpectedly passed."
fi

# Make sure supdate=no where source doesn't exist fails
rm ${local_snapshots}/infrastructure/gmp-5.1.3.tar.xz
rm ${local_refdir}/infrastructure/gmp-5.1.3.tar.xz
out="`supdate=no fetch infrastructure/gmp-5.1.3.tar.xz 2>/dev/null`"
if test $? -gt 0; then
    pass "fetch infrastructure/gmp-5.1.3.tar.xz --supdate=no failed as expected when there's no source downloaded."
else
    fail "fetch infrastructure/gmp-5.1.3.tar.xz --supdate=no passed unexpectedly when there's no source downloaded."
fi

# Make sure supdate=no --force=yes where source doesn't exist passes by forcing
# a download
rm ${local_snapshots}/infrastructure/gmp-5.1.3.tar.xz &>/dev/null
rm ${local_refdir}/infrastructure/gmp-5.1.3.tar.xz &>/dev/null
out="`force=yes supdate=no fetch infrastructure/gmp-5.1.3.tar.xz 2>/dev/null`"
if test $? -eq 0 -a -e "${local_snapshots}/infrastructure/gmp-5.1.3.tar.xz"; then
    pass "fetch infrastructure/gmp-5.1.3.tar.xz --supdate=no --force=yes passed as expected when there's no source downloaded."
else
    fail "fetch infrastructure/gmp-5.1.3.tar.xz --supdate=no --force=yes failed unexpectedly when there's no source downloaded."
fi

# Make sure supdate=no where source does exist passes
out="`supdate=no fetch infrastructure/gmp-5.1.3.tar.xz 2>/dev/null`"
if test $? -eq 0 -a -e "${local_snapshots}/infrastructure/gmp-5.1.3.tar.xz"; then
    pass "fetch infrastructure/gmp-5.1.3.tar.xz --supdate=no --force=yes passed as expected because the source already exists."
else
    fail "fetch infrastructure/gmp-5.1.3.tar.xz --supdate=no --force=yes failed unexpectedly when the source exists."
fi

# Download a clean/new copy for the check_md5sum tests
rm ${local_snapshots}/infrastructure/gmp-5.1.3.tar.xz* &>/dev/null
fetch_http infrastructure/gmp-5.1.3.tar.xz 2>/dev/null

out="`check_md5sum 'infrastructure/gmp-5.1.3.tar.xz' 2>/dev/null`"
if test $? -gt 0; then
    fail "check_md5sum failed for 'infrastructure/gmp-5.1.3.tar.xz"
else
    pass "check_md5sum passed for 'infrastructure/gmp-5.1.3.tar.xz"
fi

# Test with a non-infrastructure file
out="`check_md5sum 'infrastructure/foo.tar.xz' 2>/dev/null`"
if test $? -gt 0; then
    pass "check_md5sum failed as expected for 'infrastructure/foo.tar.xz"
else
    fail "check_md5sum passed as expected for 'infrastructure/foo.tar.xz"
fi

mv ${local_snapshots}/infrastructure/gmp-5.1.3.tar.xz ${local_snapshots}/infrastructure/gmp-5.1.3.tar.xz.back
echo "empty file" > ${local_snapshots}/infrastructure/gmp-5.1.3.tar.xz

# Test an expected failure case.
out="`check_md5sum 'infrastructure/gmp-5.1.3.tar.xz' 2>/dev/null`"
if test $? -gt 0; then
    pass "check_md5sum failed as expected for nonmatching 'infrastructure/gmp-5.1.3.tar.xz file"
else
    fail "check_md5sum passed unexpectedly for nonmatching 'infrastructure/gmp-5.1.3.tar.xz file"
fi

mv ${local_snapshots}/infrastructure/gmp-5.1.3.tar.xz.back ${local_snapshots}/infrastructure/gmp-5.1.3.tar.xz

cp ${local_snapshots}/md5sums ${local_refdir}/
rm ${local_snapshots}/md5sums
out="`git_reference_dir=${local_refdir} fetch_md5sums 2>/dev/null`"
if test $? -gt 0 -o ! -e ${local_snapshots}/md5sums; then
    fail "fetch_md5sum failed to copy file from git_reference_dir: ${local_refdir}"
else
    pass "fetch_md5sum successfully copied file from git_reference_dir: ${local_refdir}"
fi

# Empty refdir (no md5sums file) should pull a copy from the server.
rm ${local_snapshots}/md5sums
rm ${local_refdir}/md5sums
out="`git_reference_dir=${local_refdir} fetch_md5sums 2>/dev/null`"
if test $? -gt 0 -o ! -e ${local_snapshots}/md5sums; then
    fail "fetch_md5sum failed to copy file from the server"
else
    pass "fetch_md5sum successfully copied file from the server"
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

# The regular sources.conf won't have this entry.
testing="get_URL: git URL where sources.conf has a tab"
out="`sources_conf=${test_sources_conf} get_URL gcc_tab.git`"
if test x"`echo ${out}`" = x"http://staging.git.linaro.org/git/toolchain/gcc.git"; then
   pass "${testing}"
else
   fail "${testing}"
   fixme "get_URL returned ${out}"
fi

# The regular sources.conf won't have this entry.
testing="get_URL: nomatch.git@<revision> shouldn't have a corresponding sources.conf url."
out="`sources_conf=${test_sources_conf} get_URL nomatch.git@12345 2>/dev/null`"
if test x"${out}" = x""; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_URL returned ${out}"
fi

echo "============= get_URL() tests with erroneous service:// inputs ================"

testing="get_URL: Input contains an lp: service."
out="`get_URL lp:cortex-strings 2>/dev/null`"
if test $? -eq 1; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_URL returned ${out}"
fi

testing="get_URL: Input contains a git:// service."
out="`get_URL git://git.linaro.org/toolchain/eglibc.git 2>/dev/null`"
if test $? -eq 1; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_URL returned ${out}"
fi

testing="get_URL: Input contains an http:// service."
out="`get_URL http://staging.git.linaro.org/git/toolchain/eglibc.git 2>/dev/null`"
if test $? -eq 1; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_URL returned ${out}"
fi

testing="get_URL: Input contains an svn:// service."
out="`get_URL svn://gcc.gnu.org/svn/gcc/branches/gcc-4_6-branch 2>/dev/null`"
if test $? -eq 1; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_URL returned ${out}"
fi

# ----------------------------------------------------------------------------------
echo "============= get_URL() [git|http]:// tests ================"
testing="get_URL: sources.conf <repo>.git identifier should match git://<url>/<repo>.git"
out="`get_URL glibc.git`"
if test x"`echo ${out} | cut -d ' ' -f 1`" = x"http://git.linaro.org/git/toolchain/glibc.git"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_URL returned ${out}"
fi

testing="get_URL: sources.conf <repo>.git/<branch> identifier should match"
out="`get_URL glibc.git/branch`"
if test x"`echo ${out}`" = x"http://git.linaro.org/git/toolchain/glibc.git~branch"; then
    pass "${testing} http://<url>/<repo>.git"
else
    fail "${testing} http://<url>/<repo>.git"
    fixme "get_URL returned ${out}"
fi

testing="get_URL: sources.conf <repo>.git/<multi/part/branch> identifier should match"
out="`get_URL glibc.git/multi/part/branch`"
if test x"`echo ${out}`" = x"http://git.linaro.org/git/toolchain/glibc.git~multi/part/branch"; then
    pass "${testing} http://<url>/<repo>.git/multi/part/branch"
else
    fail "${testing} http://<url>/<repo>.git/multi/part/branch"
    fixme "get_URL returned ${out}"
fi

testing="get_URL: sources.conf <repo>.git~<branch> identifier should match"
out="`get_URL glibc.git~branch`"
if test x"`echo ${out}`" = x"http://git.linaro.org/git/toolchain/glibc.git~branch"; then
    pass "${testing} http://<url>/<repo>.git~branch"
else
    fail "${testing} http://<url>/<repo>.git~branch"
    fixme "get_URL returned ${out}"
fi

testing="get_URL: sources.conf <repo>.git~<multi/part/branch> identifier should match"
out="`get_URL glibc.git~multi/part/branch`"
if test x"`echo ${out}`" = x"http://git.linaro.org/git/toolchain/glibc.git~multi/part/branch"; then
    pass "${testing} http://<url>/<repo>.git~multi/part/branch"
else
    fail "${testing} http://<url>/<repo>.git~multi/part/branch"
    fixme "get_URL returned ${out}"
fi

testing="get_URL: sources.conf <repo>.git/<branch>@<revision> identifier should match"
out="`get_URL glibc.git/branch@12345`"
if test x"`echo ${out}`" = x"http://git.linaro.org/git/toolchain/glibc.git~branch@12345"; then
    pass "${testing} http://<url>/<repo>.git/<branch>@<revision>"
else
    fail "${testing} http://<url>/<repo>.git/<branch>@<revision>"
    fixme "get_URL returned ${out}"
fi

testing="get_URL: sources.conf <repo>.git/<mulit/part/branch>@<revision> identifier should match"
out="`get_URL glibc.git/multi/part/branch@12345`"
if test x"`echo ${out}`" = x"http://git.linaro.org/git/toolchain/glibc.git~multi/part/branch@12345"; then
    pass "${testing} http://<url>/<repo>.git/<multi/part/branch>@<revision>"
else
    fail "${testing} http://<url>/<repo>.git/<multi/part/branch>@<revision>"
    fixme "get_URL returned ${out}"
fi

testing="get_URL: sources.conf <repo>.git~<branch>@<revision> identifier should match"
out="`get_URL glibc.git~branch@12345`"
if test x"`echo ${out}`" = x"http://git.linaro.org/git/toolchain/glibc.git~branch@12345"; then
    pass "${testing} http://<url>/<repo>.git~<branch>@<revision>"
else
    fail "${testing} http://<url>/<repo>.git~<branch>@<revision>"
    fixme "get_URL returned ${out}"
fi

testing="get_URL: sources.conf <repo>.git~<mulit/part/branch>@<revision> identifier should match"
out="`get_URL glibc.git~multi/part/branch@12345`"
if test x"`echo ${out}`" = x"http://git.linaro.org/git/toolchain/glibc.git~multi/part/branch@12345"; then
    pass "${testing} http://<url>/<repo>.git~<multi/part/branch>@<revision>"
else
    fail "${testing} http://<url>/<repo>.git~<multi/part/branch>@<revision>"
    fixme "get_URL returned ${out}"
fi

testing="get_URL: sources.conf <repo>.git@<revision> identifier should match"
out="`get_URL glibc.git@12345`"
if test x"`echo ${out}`" = x"http://git.linaro.org/git/toolchain/glibc.git@12345"; then
    pass "${testing} http://<url>/<repo>.git@<revision>"
else
    fail "${testing} http://<url>/<repo>.git@<revision>"
    fixme "get_URL returned ${out}"
fi

testing="get_URL: sources.conf <repo>.git identifier should match http://<url>/<repo>.git"
out="`get_URL gcc.git`"
if test x"`echo ${out}`" = x"http://git.linaro.org/git/toolchain/gcc.git"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_URL returned ${out}"
fi

testing="get_URL: Don't match partial match of <repo>[spaces] to sources.conf identifier."
out="`get_URL "eglibc" 2>/dev/null`"
if test x"`echo ${out}`" = x; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_URL returned ${out}"
fi

testing="get_URL: Don't match partial match of <repo>[\t] to sources.conf identifier."
out="`get_URL "gcc_tab" 2>/dev/null`"
if test x"`echo ${out}`" = x; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_URL returned ${out}"
fi

# ----------------------------------------------------------------------------------
echo "============= get_URL() http://git@ tests ================"

# The regular sources.conf won't have this entry.
testing="get_URL: sources.conf <repo>.git identifier should match http://git@<url>/<repo>.git"
out="`sources_conf=${test_sources_conf} get_URL git_gcc.git`"
if test x"`echo ${out}`" = x"http://git@staging.git.linaro.org/git/toolchain/gcc.git"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_URL returned ${out}"
fi

# The regular sources.conf won't have this entry.
testing="get_URL: sources.conf <repo>.git/<branch> identifier should match"
out="`sources_conf=${test_sources_conf} get_URL git_gcc.git/branch`"
if test x"`echo ${out}`" = x"http://git@staging.git.linaro.org/git/toolchain/gcc.git~branch"; then
    pass "${testing} http://git@<url>/<repo>.git~<branch>"
else
    fail "${testing} http://git@<url>/<repo>.git~<branch>"
    fixme "get_URL returned ${out}"
fi

# The regular sources.conf won't have this entry.
testing="get_URL: sources.conf <repo>.git/<branch>@<revision> identifier should match"
out="`sources_conf=${test_sources_conf} get_URL git_gcc.git/branch@12345`"
if test x"`echo ${out} | cut -d ' ' -f 1`" = x"http://git@staging.git.linaro.org/git/toolchain/gcc.git~branch@12345"; then
    pass "${testing} http://git@<url>/<repo>.git~<branch>@<revision>"
else
    fail "${testing} http://git@<url>/<repo>.git~<branch>@<revision>"
    fixme "get_URL returned ${out}"
fi

# The regular sources.conf won't have this entry.
testing="get_URL: sources.conf <repo>.git@<revision> identifier should match"
out="`sources_conf=${test_sources_conf} get_URL git_gcc.git@12345`"
if test x"`echo ${out}`" = x"http://git@staging.git.linaro.org/git/toolchain/gcc.git@12345"; then
    pass "${testing} http://git@<url>/<repo>.git@<revision>"
else
    fail "${testing} http://git@<url>/<repo>.git@<revision>"
    fixme "get_URL returned ${out}"
fi

# ----------------------------------------------------------------------------------
echo "============= get_URL() http://user.name@ tests ================"
# We do these these tests to make sure that 'http://git@'
# isn't hardcoded in the scripts.

# The regular sources.conf won't have this entry.
testing="get_URL: sources.conf <repo>.git identifier should match http://user.name@<url>/<repo>.git"
out="`sources_conf=${test_sources_conf} get_URL user_gcc.git`"
if test x"`echo ${out}`" = x"http://user.name@staging.git.linaro.org/git/toolchain/gcc.git"; then
    pass "${testing} http://<user.name>@<url>/<repo>.git"
else
    fail "${testing} http://<user.name>@<url>/<repo>.git"
    fixme "get_URL returned ${out}"
fi

# The regular sources.conf won't have this entry.
testing="get_URL: sources.conf <repo>.git/<branch> identifier should match"
out="`sources_conf=${test_sources_conf} get_URL user_gcc.git/branch`"
if test x"`echo ${out}`" = x"http://user.name@staging.git.linaro.org/git/toolchain/gcc.git~branch"; then
    pass "${testing} http://user.name@<url>/<repo>.git~<branch>"
else
    fail "${testing} http://user.name@<url>/<repo>.git~<branch>"
    fixme "get_URL returned ${out}"
fi

# The regular sources.conf won't have this entry.
testing="get_URL: sources.conf <repo>.git/<branch>@<revision> identifier should match"
out="`sources_conf=${test_sources_conf} get_URL user_gcc.git/branch@12345`"
if test x"`echo ${out} | cut -d ' ' -f 1`" = x"http://user.name@staging.git.linaro.org/git/toolchain/gcc.git~branch@12345"; then
    pass "${testing} http://user.name@<url>/<repo>.git~<branch>@<revision>"
else
    fail "${testing} http://user.name@<url>/<repo>.git~<branch>@<revision>"
    fixme "get_URL returned ${out}"
fi

# The regular sources.conf won't have this entry.
testing="get_URL: sources.conf <repo>.git@<revision> identifier should match"
out="`sources_conf=${test_sources_conf} get_URL user_gcc.git@12345`"
if test x"`echo ${out}`" = x"http://user.name@staging.git.linaro.org/git/toolchain/gcc.git@12345"; then
    pass "${testing} http://user.name@<url>/<repo>.git@<revision>"
else
    fail "${testing} http://user.name@<url>/<repo>.git@<revision>"
    fixme "get_URL returned ${out}"
fi

echo "============= get_URL() svn and lp tests ================"
# The regular sources.conf won't have this entry.
testing="get_URL: sources.conf svn identifier should match"
out="`sources_conf=${test_sources_conf} get_URL gcc-svn-4.8`"
if test x"`echo ${out}`" = x"svn://gcc.gnu.org/svn/gcc/branches/gcc-4_8-branch"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_URL returned ${out}"
fi

testing="get_URL: sources.conf launchpad identifier should match"
out="`sources_conf=${test_sources_conf} get_URL cortex-strings`"
if test x"`echo ${out}`" = x"lp:cortex-strings"; then
    pass "${testing}"
else
    fail "${testing}"
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
if test x"${out}" = x"http://git.linaro.org/git/toolchain/eglibc.git"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_source returned ${out}"
fi

testing="get_source: git repository with / branch"
in="eglibc.git/linaro_eglibc-2_17"
out="`get_source ${in}`"
if test x"${out}" = x"http://git.linaro.org/git/toolchain/eglibc.git~linaro_eglibc-2_17"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_source returned ${out}"
fi

testing="get_source: git repository with / branch and commit"
in="newlib.git/binutils-2_23-branch@e9a210b"
out="`get_source ${in}`"
if test x"${out}" = x"http://git.linaro.org/git/toolchain/newlib.git~binutils-2_23-branch@e9a210b"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_source returned ${out}"
fi

testing="get_source: git repository with ~ branch and commit"
in="newlib.git~binutils-2_23-branch@e9a210b"
out="`get_source ${in}`"
if test x"${out}" = x"http://git.linaro.org/git/toolchain/newlib.git~binutils-2_23-branch@e9a210b"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_source returned ${out}"
fi

testing="get_source: <repo>.git@commit"
in="newlib.git@e9a210b"
out="`get_source ${in}`"
if test x"${out}" = x"http://git.linaro.org/git/toolchain/newlib.git@e9a210b"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_source returned ${out}"
fi

testing="get_source: tar.bz2 archive"
in="gcc-linaro-4.8-2013.09.tar.xz"
out="`get_source ${in}`"
if test x"${out}" = x"gcc-linaro-4.8-2013.09.tar.xz"; then
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

for transport in ssh git http; do
  testing="get_source: git direct url not ending in .git (${transport})"
  in="${transport}://git.linaro.org/toolchain/eglibc"
  out="`get_source ${in}`"
  if test x"${out}" = x"${transport}://git.linaro.org/toolchain/eglibc"; then
      pass "${testing}"
  else
      fail "${testing}"
      fixme "get_source returned ${out}"
  fi

  testing="get_source: git direct url not ending in .git with revision returns bogus url. (${transport})"
  in="${transport}://git.linaro.org/git/toolchain/eglibc/branch@1234567"
  if test x"${debug}" = x"yes"; then
      out="`get_source ${in}`"
  else
      out="`get_source ${in} 2>/dev/null`"
  fi
  if test x"${out}" = x"${transport}://git.linaro.org/git/toolchain/eglibc/branch@1234567"; then
      pass "${testing}"
  else
      fail "${testing}"
      fixme "get_source returned ${out}"
  fi
done

# The regular sources.conf won't have this entry
testing="get_source: full url with <repo>.git with matching source.conf entry should succeed."
in="http://git.linaro.org/git/toolchain/foo.git"
if test x"${debug}" = x"yes"; then
    out="`sources_conf=${test_sources_conf} get_source ${in}`"
else
    out="`sources_conf=${test_sources_conf} get_source ${in} 2>/dev/null`"
fi
if test x"${out}" = x"http://git.linaro.org/git/toolchain/foo.git"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_source returned ${out}"
fi

# No sources.conf should have this entry, but use the one under test control
testing="get_source: <repo>.git identifier with no matching source.conf entry should fail."
in="nomatch.git"
if test x"${debug}" = x"yes"; then
    out="`sources_conf=${test_sources_conf} get_source ${in}`"
else
    out="`sources_conf=${test_sources_conf} get_source ${in} 2>/dev/null`"
fi
if test x"${out}" = x""; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_source returned ${out}"
fi

# No sources.conf should have this entry, but use the one under test control
testing="get_source: <repo>.git@<revision> identifier with no matching source.conf entry should fail."
in="nomatch.git@12345"
if test x"${debug}" = x"yes"; then
    out="`sources_conf=${test_sources_conf} get_source ${in}`"
else
    out="`sources_conf=${test_sources_conf} get_source ${in} 2>/dev/null`"
fi
if test x"${out}" = x""; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_source returned ${out}"
fi

testing="get_source: tag matching an svn repo in ${sources_conf}"
in="gcc-4.8-"
out="`get_source ${in} 2>/dev/null`"
if test x"${out}" = x"svn://gcc.gnu.org/svn/gcc/branches/gcc-4_8-branch"; then
    xpass "${testing}"
else
    # This currently is expected to fail because passing in gcc-4.8 is assumed
    # to be a tarball in md5sums, and so it;s never looked up in sources.conf.
    # Not sure if this is a bug or an edge case, as specifying  more unique
    # URL for svn works correctly.
    xfail "${testing}"
    fixme "get_source returned ${out}"
fi

# The regular sources.conf won't have this entry.
testing="get_source: <repo>.git matches non .git suffixed url."
in="foo.git"
out="`sources_conf=${test_sources_conf} get_source ${in} 2>/dev/null`"
if test x"${out}" = x"git://testingrepository/foo"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_source returned ${out}"
fi

# The regular sources.conf won't have this entry.
testing="get_source: <repo>.git/<branch> matches non .git suffixed url."
in="foo.git/bar"
out="`sources_conf=${test_sources_conf} get_source ${in} 2>/dev/null`"
if test x"${out}" = x"git://testingrepository/foo~bar"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_source returned ${out}"
fi

# The regular sources.conf won't have this entry.
testing="get_source: <repo>.git/<branch>@<revision> matches non .git suffixed url."
in="foo.git/bar@12345"
out="`sources_conf=${test_sources_conf} get_source ${in} 2>/dev/null`"
if test x"${out}" = x"git://testingrepository/foo~bar@12345"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_source returned ${out}"
fi

in="foo.git@12345"
testing="get_source: ${sources_conf}:${in} matching no .git in <repo>@<revision>."
out="`sources_conf=${test_sources_conf} get_source ${in} 2>/dev/null`"
if test x"${out}" = x"git://testingrepository/foo@12345"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_source returned ${out}"
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
latest="gcc-linaro-4.8-2013.09.tar.xz"
in="gcc-linaro-4.8"
out="`get_source ${in} 2>/dev/null`"
if test x"${out}" = x"gcc-linaro-4.8-2013.09.tar.xz"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_source returned ${out}"
fi

latest=${saved_latest}

for transport in ssh git http; do
  testing="get_source: git direct url with a ~ branch designation. (${transport})"
  in="${transport}://git.linaro.org/toolchain/eglibc.git~branch@1234567"
  if test x"${debug}" = x"yes"; then
      out="`get_source ${in}`"
  else
      out="`get_source ${in} 2>/dev/null`"
  fi
  if test x"${out}" = x"${transport}://git.linaro.org/toolchain/eglibc.git~branch@1234567"; then
      pass "${testing}"
  else
      fail "${testing}"
      fixme "get_source returned ${out}"
  fi

  testing="get_source: git direct url with a ~ branch designation. (${transport})"
  in="$transport://git.savannah.gnu.org/dejagnu.git~linaro"
  if test x"${debug}" = x"yes"; then
      out="`get_source ${in}`"
  else
      out="`get_source ${in} 2>/dev/null`"
  fi
  if test x"${out}" = x"${transport}://git.savannah.gnu.org/dejagnu.git~linaro"; then
      pass "${testing}"
  else
      fail "${testing}"
      fixme "get_source returned ${out}"
  fi
done




# ----------------------------------------------------------------------------------

echo "========= create_release_tag() tests ============"

testing="create_release_tag: repository with branch and revision"
date="`date +%Y%m%d`"
in="gcc.git/gcc-4.8-branch@12345abcde"
out="`create_release_tag ${in} | grep -v TRACE`"
toolname="`echo ${out} | cut -d ' ' -f 1`"
branch="`echo ${out} | cut -d ' ' -f 2`"
revision="`echo ${out} | cut -d ' ' -f 3`"
if test x"${out}" = x"gcc.git~gcc-4.8-branch@12345abcde-${date}"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "create_release_tag returned ${out}"
fi

branch=
revision=
testing="create_release_tag: repository branch empty"
in="gcc.git"
out="`create_release_tag ${in} | grep -v TRACE`"
if test "`echo ${out} | grep -c "gcc.git-${date}"`" -gt 0; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "create_release_tag returned ${out}"
fi

testing="create_release_tag: tarball"
in="gcc-linaro-4.8-2013.09.tar.xz"
out="`create_release_tag ${in} | grep -v TRACE`"
if test x"${out}" = x"gcc-linaro-4.8-${date}"; then
    xpass "${testing}"
else
    # This fails because the tarball name fails to extract the version. This
    # behavious isn't used by Abe, it was an early feature to have some
    # compatability with abev1, which used tarballs. Abe produces the
    # tarballs, it doesn't need to import them anymore.
    xfail "${testing}"
    fixme "create_release_tag returned ${out}"
fi

# ----------------------------------------------------------------------------------
echo "============= checkout () tests ================"
echo "  Checking out sources into ${local_snapshots}"
echo "  Please be patient while sources are checked out...."
echo "================================================"

# These can be painfully slow so test small repos.

#confirm that checkout works with raw URLs
rm -rf "${local_snapshots}"/*.git*
testing="http://abe.git@staging.git.linaro.org/git/toolchain/abe.git"
in="${testing}"
if test x"${debug}" = xyes; then
  out="`cd ${local_snapshots} && checkout ${testing}`"
else
  out="`cd ${local_snapshots} && checkout ${testing} 2>/dev/null`"
fi
if test $? -eq 0; then
  pass "${testing}"
else
  fail "${testing}"
fi

#confirm that checkout fails approriately with a range of bad services in raw URLs
for service in "foomatic://" "http:" "http:/fake.git" "http/" "http//" ""; do
  rm -rf "${local_snapshots}"/*.git*
  in="${service}abe.git@staging.git.linaro.org/git/toolchain/abe.git"
  testing="checkout: ${in} should fail with 'proper URL required' message."
  if test x"${debug}" = xyes; then
    out="`cd ${local_snapshots} && checkout ${in} 2> >(tee /dev/stderr)`"
  else
    out="`cd ${local_snapshots} && checkout ${in} 2>&1`"
  fi
  if test $? -eq 0; then
    fail "${testing}"
  else
    if echo "${out}" | tail -n1 | grep -q "^ERROR.*: checkout (Unable to parse service from '${in}'\\. You have either a bad URL, or an identifier that should be passed to get_URL\\.)$"; then
      pass "${testing}"
    else
      fail "${testing}"
    fi
  fi
done

#confirm that checkout fails with bad repo - abe is so forgiving that I can only find one suitable input
rm -rf "${local_snapshots}"/*.git*
in="http://"
testing="checkout: ${in} should fail with 'cannot parse repo' message."
if test x"${debug}" = xyes; then
  out="`cd ${local_snapshots} && checkout ${in} 2> >(tee /dev/stderr)`"
else
  out="`cd ${local_snapshots} && checkout ${in} 2>&1`"
fi
if test $? -eq 0; then
  fail "${testing}"
else
  if echo "${out}" | tail -n1 | grep -q "^ERROR.*: git_parser (Malformed input\\. No repo found\\.)$"; then
    pass "${testing}"
  else
    fail "${testing}"
  fi
fi

rm -rf "${local_snapshots}"/*
in="`get_URL abe.git`"
testing="checkout: abe.git should produce ${local_snapshots}/abe.git"
if (cd "${local_snapshots}" && \
    if test x"${debug}" = xyes; then checkout "${in}" > /dev/null; else checkout "${in}" > /dev/null 2>&1; fi && \
    test `ls | wc -l` -eq 1 && \
    ls abe.git > /dev/null); then
  pass "${testing}"
else
  fail "${testing}"
fi

rm -rf "${local_snapshots}"/*
in="`get_URL abe.git`"
in="`get_git_url ${in}`"
testing="checkout: abe.git~staging should produce ${local_snapshots}/abe.git and ${local_snapshots}/abe.git~staging"
if (cd "${local_snapshots}" && \
    if test x"${debug}" = xyes; then checkout "${in}~staging" > /dev/null; else
      checkout "${in}~staging" >/dev/null 2>&1; fi && \
    test `ls | wc -l` -eq 2 && \
    ls abe.git > /dev/null && \
    ls abe.git~staging > /dev/null); then
  pass "${testing}"
else
  fail "${testing}"
fi

test_checkout ()
{
    local should="$1"
    local testing="$2"
    local package="$3"
    local branch="$4"
    local revision="$5"
    local expected="$6"

    #in="${package}${branch:+/${branch}}${revision:+@${revision}}"
    in="${package}${branch:+~${branch}}${revision:+@${revision}}"

    local gitinfo=
    gitinfo="`sources_conf=${test_sources_conf} get_URL ${in}`"

    local tag=
    tag="`sources_conf=${test_sources_conf} get_git_url ${gitinfo}`"
    tag="${tag}${branch:+~${branch}}${revision:+@${revision}}"

    # We also support / designated branches, but want to move to ~ mostly.
    #tag="${tag}${branch:+~${branch}}${revision:+@${revision}}"

    #Make sure there's no hanging state relating to this test before it runs
    if ls "${local_snapshots}/${package}"* > /dev/null 2>&1; then
      rm -rf "${local_snapshots}/${package}"*
    fi

    if test x"${debug}" = x"yes"; then
        if test x"${expected}" = x; then
	    out="`(cd ${local_snapshots} && sources_conf=${test_sources_conf} checkout ${tag})`"
        else
            out="`(cd ${local_snapshots} && sources_conf=${test_sources_conf} checkout ${tag} 2> >(tee /dev/stderr))`"
        fi
    else
        if test x"${expected}" = x; then
	    out="`(cd ${local_snapshots} && sources_conf=${test_sources_conf} checkout ${tag} 2>/dev/null)`"
        else
	    out="`(cd ${local_snapshots} && sources_conf=${test_sources_conf} checkout ${tag} 2>&1)`"
        fi
    fi

    local srcdir=
    srcdir="`sources_conf=${test_sources_conf} get_srcdir "${tag}"`"

    local branch_test=
    if test ! -d ${srcdir}; then
	branch_test=0
    elif test x"${branch}" = x -a x"${revision}" = x; then
	branch_test=`(cd ${srcdir} && git branch | grep -c "^\* master$")`
    elif test x"${revision}" = x; then
        branch_test=`(cd ${srcdir} && git branch | grep -c "^\* ${branch}$")`
    else
        branch_test=`(cd ${srcdir} && git branch | grep -c "^\* local_${revision}$")`
    fi

    #Make sure we leave no hanging state
    if ls "${local_snapshots}/${package}"* > /dev/null 2>&1; then
      rm -rf "${local_snapshots}/${package}"*
    fi

    if test x"${branch_test}" = x1 -a x"${should}" = xpass; then
        if test x"${expected}" = x; then
            pass "${testing}"
        else
            if echo "${out}" | grep -q "${expected}"; then
	        pass "${testing}"
	        return 0
            else
                fail "${testing}"
                return 1
            fi
        fi
    elif test x"${branch_test}" = x1 -a x"${should}" = xfail; then
	fail "${testing}"
	return 1
    elif test x"${branch_test}" = x0 -a x"${should}" = xfail; then
        if test x"${expected}" = x; then
            pass "${testing}"
        else
            if echo "${out}" | grep -q "${expected}"; then
	        pass "${testing}"
	        return 0
            else
                fail "${testing}"
                return 1
            fi
        fi
    else
	fail "${testing}"
	return 1
    fi
}

testing="checkout: http://git@<url>/<repo>.git"
package="abe.git"
branch=''
revision=''
should="pass"
expected=''
test_checkout "${should}" "${testing}" "${package}" "${branch}" "${revision}" "${expected}"

testing="checkout: http://git@<url>/<repo>.git/<branch>"
package="abe.git"
branch="gerrit"
revision=''
should="pass"
expected=''
test_checkout "${should}" "${testing}" "${package}" "${branch}" "${revision}" "${expected}"

testing="checkout: http://git@<url>/<repo>.git@<revision>"
package="abe.git"
branch=''
revision="9bcced554dfc"
should="pass"
expected=''
test_checkout "${should}" "${testing}" "${package}" "${branch}" "${revision}" "${expected}"

testing="checkout: http://git@<url>/<repo>.git/unusedbranchname@<revision>"
package="abe.git"
branch="unusedbranchname"
revision="9bcced554dfc"
should="pass"
expected=''
test_checkout "${should}" "${testing}" "${package}" "${branch}" "${revision}" "${expected}"

testing="checkout: svn://testingrepository/foo should fail with 'checkout failed' message."
package="foo-svn"
branch=''
revision=''
should="fail"
expected="^ERROR.*: checkout (Failed to check out svn://testingrepository/foo to ${local_snapshots}/foo)$"
test_checkout "${should}" "${testing}" "${package}" "${branch}" "${revision}" "${expected}"

testing="checkout: git://testingrepository/foo should fail with 'clone failed' message."
package="foo.git"
branch=''
revision=''
should="fail"
expected="^ERROR.*: checkout (Failed to clone master branch from git://testingrepository/foo to ${local_snapshots}/foo)$"
test_checkout "${should}" "${testing}" "${package}" "${branch}" "${revision}" "${expected}"

testing="checkout: http://git@<url>/<repo>.git/<nonexistentbranch> should fail with 'branch does not exist' message."
package="abe.git"
branch="nonexistentbranch"
revision=''
should="fail"
expected="^ERROR.*: checkout (Branch ${branch} likely doesn't exist in git repo ${package}\\!)$"
test_checkout "${should}" "${testing}" "${package}" "${branch}" "${revision}" "${expected}"

testing="checkout: http://git@<url>/<repo>.git@<nonexistentrevision> should fail with 'revision does not exist' message."
package="abe.git"
branch=''
revision="123456bogusbranch"
should="fail"
expected="^ERROR.*: checkout (Revision ${revision} likely doesn't exist in git repo ${package}\\!)$"
test_checkout "${should}" "${testing}" "${package}" "${branch}" "${revision}" "${expected}"

testing="checkout: http://git@<url>/<repo>.git~<branch> should pass with appropriate notice"
package="abe.git"
branch='staging'
revision=""
should="pass"
expected="^NOTE: Checking out branch staging for abe in .\\+~staging$"
test_checkout "${should}" "${testing}" "${package}" "${branch}" "${revision}" "${expected}"

rm -rf "${local_snapshots}"/*.git*

echo "============= misc tests ================"
testing="pipefail"
out="`false | tee /dev/null`"
if test $? -ne 0; then
    pass "${testing}"
else
    fail "${testing}"
fi

#Do not pollute env
testing="source_config"
depends="`depends= && source_config isl && echo ${depends}`"
static_link="`static_link= && source_config isl && echo ${static_link}`"
default_configure_flags="`default_configure_flags= && source_config isl && echo ${default_configure_flags}`"
if test x"${depends}" != xgmp; then
  fail "${testing}"
elif test x"${static_link}" != xyes; then
  fail "${testing}"
elif test x"${default_configure_flags}" != x"--with-gmp-prefix=${PWD}/${hostname}/${build}/depends"; then
  fail "${testing}"
else
  pass "${testing}"
fi
depends=
default_configure_flags=
static_link=

testing="read_config one arg"
if test x"`read_config isl static_link`" = xyes; then
  pass "${testing}"
else
  fail "${testing}"
fi

testing="read_config multiarg"
if test x"`read_config glib default_configure_flags`" = x"--disable-modular-tests --disable-dependency-tracking --cache-file=/tmp/glib.cache"; then
  pass "${testing}"
else
  fail "${testing}"
fi

testing="read_config set then unset"
out="`default_makeflags=\`read_config binutils default_makeflags\` && default_makeflags=\`read_config newlib default_makeflags\` && echo ${default_makeflags}`"
if test $? -gt 0; then
  fail "${testing}"
elif test x"${out}" != x; then
  fail "${testing}"
else
  pass "${testing}"
fi

dryrun="yes"
tool="binutils" #this is a nice tool to use as it checks the substitution in make install, too
cmp_makeflags="`read_config ${tool} default_makeflags`"
testing="postfix make args (make_all)"
if test x"${cmp_makeflags}" = x; then
  untested "${testing}" #implies that the config for this tool no longer contains default_makeflags
else
  out="`. ${topdir}/config/${tool}.conf && make_all ${tool}.git 2>&1`"
  if test x"${debug}" = x"yes"; then
    echo "${out}"
  fi
  echo "${out}" | grep -- "${cmp_makeflags}" > /dev/null 2>&1
  if test $? -eq 0; then
    pass "${testing}"
  else
    fail "${testing}"
  fi
fi
testing="postfix make args (make_install)"
cmp_makeflags="`echo ${cmp_makeflags} | sed -e 's:\ball-:install-:g'`"
if test x"${cmp_makeflags}" = x; then
  untested "${testing}" #implies that the config for this tool no longer contains default_makeflags
else
  out="`. ${topdir}/config/${tool}.conf && make_install ${tool}.git 2>&1`"
  if test x"${debug}" = x"yes"; then
    echo "${out}"
  fi
  echo "${out}" | grep -- "${cmp_makeflags}" > /dev/null 2>&1
  if test $? -eq 0; then
    pass "${testing}"
  else
    fail "${testing}"
  fi
fi
cmp_makeflags=

testing="configure"
tool="dejagnu"
configure="`grep ^configure= ${topdir}/config/${tool}.conf | cut -d '\"' -f 2`"
if test x"${configure}" = xno; then
  untested "${testing}"
else
  out=`configure_build ${tool}.git 2>&1`
  if test x"${debug}" = x"yes"; then
    echo "${out}"
  fi
  echo "${out}" | grep -- '^DRYRUN: .*/configure ' > /dev/null
  if test $? -eq 0; then
    pass "${testing}"
  else
    fail "${testing}"
  fi
fi
testing="copy instead of configure"
tool="eembc"
configure="`grep ^configure= ${topdir}/config/${tool}.conf | cut -d '\"' -f 2`"
if test \! x"${configure}" = xno; then
  untested "${testing}" #implies that the tool's config no longer contains configure, or that it has a wrong value
elif test x"${configure}" = xno; then
  out=`configure_build ${tool}.git 2>&1`
  if test x"${debug}" = x"yes"; then
    echo "${out}"
  fi
  echo "${out}" | grep -- '^DRYRUN: rsync -a --exclude=.git/ .\+/ ' > /dev/null
  if test $? -eq 0; then
    pass "${testing}"
  else
    fail "${testing}"
  fi
fi
# TODO: Test checkout directly with a non URL.
# TODO: Test checkout with a multi-/ branch

#testing="checkout: http://git@<url>/<repo>.git~multi/part/branch."
#package="glibc.git"
#branch='release/2.18/master'
#revision=""
#should="pass"
#test_checkout "${should}" "${testing}" "${package}" "${branch}" "${revision}"

. "${topdir}/testsuite/srcdir-tests.sh"

# ----------------------------------------------------------------------------------
# print the total of test results
totals

# We can't just return ${failures} or it could overflow to 0 (success)
if test ${failures} -gt 0; then
    exit 1
fi
exit 0
