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

    remote_snapshots="${remote_snapshots:-/snapshots-ref}"
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

# ----------------------------------------------------------------------------------
echo "============= fetch_http() tests ================"

# Download the first time without force.
out="`fetch_http infrastructure/gmp-6.0.0a.tar.xz 2>/dev/null`"
if test $? -eq 0 -a -e ${local_snapshots}/infrastructure/gmp-6.0.0a.tar.xz; then
    pass "fetch_http infrastructure/gmp-6.0.0a.tar.xz"
else
    fail "fetch_http infrastructure/gmp-6.0.0a.tar.xz"
fi

# Get the timestamp of the file.
gmp_stamp1=`stat -c %X ${local_snapshots}/infrastructure/gmp-6.0.0a.tar.xz`

# Download it again
out="`fetch_http infrastructure/gmp-6.0.0a.tar.xz 2>/dev/null`"
ret=$?

# Get the timestamp of the file after another fetch.
gmp_stamp2=`stat -c %X ${local_snapshots}/infrastructure/gmp-6.0.0a.tar.xz`

# They should be the same timestamp.
if test $ret -eq 0 -a ${gmp_stamp1} -eq ${gmp_stamp2}; then
    pass "fetch_http infrastructure/gmp-6.0.0a.tar.xz didn't update as expected (force=no)"
else
    fail "fetch_http infrastructure/gmp-6.0.0a.tar.xz updated unexpectedly (force=no)"
fi

# If the two operations happen within the same second then their timestamps will
# be equivalent.  This sleep operation forces the timestamps apart.
sleep 2s

# Now try it with force on
out="`force=yes fetch_http infrastructure/gmp-6.0.0a.tar.xz 2>/dev/null`"
if test $? -gt 0; then
    fail "fetch_http infrastructure/gmp-6.0.0a.tar.xz with \${force}=yes when source exists"
else
    pass "fetch_http infrastructure/gmp-6.0.0a.tar.xz with \${force}=yes when source exists"
fi

# Get the timestamp of the file after another fetch.
gmp_stamp3=`stat -c %X ${local_snapshots}/infrastructure/gmp-6.0.0a.tar.xz`

if test ${gmp_stamp1} -eq ${gmp_stamp3}; then
    fail "fetch_http infrastructure/gmp-6.0.0a.tar.xz with \${force}=yes has unexpected matching timestamps"
else
    pass "fetch_http infrastructure/gmp-6.0.0a.tar.xz with \${force}=yes has unmatching timestamps as expected."
fi

# Make sure force doesn't get in the way of a clean download.
rm ${local_snapshots}/infrastructure/gmp-6.0.0a.tar.xz

# force should override supdate and this should download for the first time.
out="`force=yes fetch_http infrastructure/gmp-6.0.0a.tar.xz 2>/dev/null`"
if test $? -gt 0; then
    fail "fetch_http infrastructure/gmp-6.0.0a.tar.xz with \${force}=yes and sources don't exist"
else
    pass "fetch_http infrastructure/gmp-6.0.0a.tar.xz with \${force}=yes and sources don't exist"
fi

# Test the case where wget_bin isn't set.
rm ${local_snapshots}/infrastructure/gmp-6.0.0a.tar.xz

out="`unset wget_bin; fetch_http infrastructure/gmp-6.0.0a.tar.xz 2>/dev/null`"
if test $? -gt 0; then
    pass "unset wget_bin; fetch_http infrastructure/gmp-6.0.0a.tar.xz should fail."
else
    fail "unset wget_bin; fetch_http infrastructure/gmp-6.0.0a.tar.xz should fail."
fi

# Verify that '1' is returned when a non-existent file is requested.
out="`fetch_http no_such_file 2>/dev/null`"
if test $? -gt 0; then
    pass "fetch_http no_such_file (implicit \${supdate}=yes) should fail."
else
    fail "fetch_http no_such_file (implicit \${supdate}=yes) should fail."
fi

echo "============= fetch() tests ================"

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
if test $? -gt 0 -o ! -e "${local_snapshots}/infrastructure/gmp-6.0.0a.tar.xz"; then
    fail "fetch infrastructure/gmp-5.1 (with partial name) from server failed unexpectedly."
else
    pass "fetch infrastructure/gmp-5.1 (with partial name) from server passed as expected."
fi

# Create a git_reference_dir
local_refdir="${local_snapshots}/../refdir"
mkdir -p ${local_refdir}/infrastructure
# We need a way to differentiate the refdir version.
cp ${local_snapshots}/infrastructure/gmp-5.1* ${local_refdir}/infrastructure/gmp-6.0.0a.tar.xz
rm ${local_snapshots}/infrastructure/gmp-5.1* &>/dev/null

# Use fetch that goes to a reference dir using a shortname
out="`git_reference_dir=${local_refdir} fetch infrastructure/gmp-5.1 2>/dev/null`"
if test $? -gt 0 -o ! -e "${local_snapshots}/infrastructure/gmp-6.0.0a.tar.xz"; then
    fail "fetch infrastructure/gmp-5.1 (with partial name) from reference dir failed unexpectedly."
else
    pass "fetch infrastructure/gmp-5.1 (with partial name) from reference dir passed as expected."
fi

rm ${local_snapshots}/infrastructure/gmp-5.1* &>/dev/null
# Use fetch that goes to a reference dir using a longname
out="`git_reference_dir=${local_refdir} fetch infrastructure/gmp-6.0.0a.tar.xz 2>/dev/null`"
if test $? -gt 0 -o ! -e "${local_snapshots}/infrastructure/gmp-6.0.0a.tar.xz"; then
    fail "fetch infrastructure/gmp-5.1 (with full name) from reference dir failed unexpectedly."
else
    pass "fetch infrastructure/gmp-5.1 (with full name) from reference dir passed as expected."
fi

rm ${local_snapshots}/infrastructure/gmp-5.1*

# Replace with a marked version so we can tell if it's copied the reference
# versions erroneously.
rm ${local_refdir}/infrastructure/gmp-6.0.0a.tar.xz
echo "DEADBEEF" > ${local_refdir}/infrastructure/gmp-6.0.0a.tar.xz

# Use fetch that finds a git reference dir but is forced to use the server.
out="`force=yes git_reference_dir=${local_refdir} fetch infrastructure/gmp-6.0.0a.tar.xz 2>/dev/null`"
if test $? -gt 0; then
    fail "fetch infrastructure/gmp-5.1 (with full name) from reference dir failed unexpectedly."
elif test x"$(grep DEADBEEF ${local_snapshots}/infrastructure/gmp-6.0.0a.tar.xz)" != x""; then
    fail "fetch infrastructure/gmp-5.1 pulled from reference dir instead of server."
else
    pass "fetch infrastructure/gmp-5.1 (with full name) from reference dir passed as expected."
fi

# The next test makes sure that the failure is due to a file md5sum mismatch.
rm ${local_refdir}/infrastructure/gmp-6.0.0a.tar.xz
echo "DEADBEEF" > ${local_refdir}/infrastructure/gmp-6.0.0a.tar.xz
out="`git_reference_dir=${local_refdir} fetch infrastructure/gmp-6.0.0a.tar.xz 2>/dev/null`"
if test $? -gt 0 -a x"$(grep DEADBEEF ${local_snapshots}/infrastructure/gmp-6.0.0a.tar.xz)" != x""; then
    pass "fetch infrastructure/gmp-5.1 --force=yes git_reference_dir=foo failed because md5sum doesn't match."
else
    fail "fetch infrastructure/gmp-5.1 --force=yes git_reference_dir=foo unexpectedly passed."
fi

# Make sure supdate=no where source doesn't exist fails
rm ${local_snapshots}/infrastructure/gmp-6.0.0a.tar.xz
rm ${local_refdir}/infrastructure/gmp-6.0.0a.tar.xz
out="`supdate=no fetch infrastructure/gmp-6.0.0a.tar.xz 2>/dev/null`"
if test $? -gt 0; then
    pass "fetch infrastructure/gmp-6.0.0a.tar.xz --supdate=no failed as expected when there's no source downloaded."
else
    fail "fetch infrastructure/gmp-6.0.0a.tar.xz --supdate=no passed unexpectedly when there's no source downloaded."
fi

# Make sure supdate=no --force=yes where source doesn't exist passes by forcing
# a download
rm ${local_snapshots}/infrastructure/gmp-6.0.0a.tar.xz &>/dev/null
rm ${local_refdir}/infrastructure/gmp-6.0.0a.tar.xz &>/dev/null
out="`force=yes supdate=no fetch infrastructure/gmp-6.0.0a.tar.xz 2>/dev/null`"
if test $? -eq 0 -a -e "${local_snapshots}/infrastructure/gmp-6.0.0a.tar.xz"; then
    pass "fetch infrastructure/gmp-6.0.0a.tar.xz --supdate=no --force=yes passed as expected when there's no source downloaded."
else
    fail "fetch infrastructure/gmp-6.0.0a.tar.xz --supdate=no --force=yes failed unexpectedly when there's no source downloaded."
fi

# Make sure supdate=no where source does exist passes
out="`supdate=no fetch infrastructure/gmp-6.0.0a.tar.xz 2>/dev/null`"
if test $? -eq 0 -a -e "${local_snapshots}/infrastructure/gmp-6.0.0a.tar.xz"; then
    pass "fetch infrastructure/gmp-6.0.0a.tar.xz --supdate=no --force=yes passed as expected because the source already exists."
else
    fail "fetch infrastructure/gmp-6.0.0a.tar.xz --supdate=no --force=yes failed unexpectedly when the source exists."
fi

cp ${local_snapshots}/infrastructure/gmp-6.0.0a.tar.xz ${local_refdir}/infrastructure/ &>/dev/null

# Test to make sure the fetch_reference creates the infrastructure directory.
rm -rf ${local_snapshots}/infrastructure &>/dev/null
out="`git_reference_dir=${local_refdir} fetch_reference infrastructure/gmp-6.0.0a.tar.xz 2>/dev/null`"
if test $? -eq 0 -a -e "${local_snapshots}/infrastructure/gmp-6.0.0a.tar.xz"; then
    pass "fetch_reference infrastructure/gmp-6.0.0a.tar.xz  passed as expected because the infrastructure/ directory was created."
else
    fail "fetch_reference infrastructure/gmp-6.0.0a.tar.xz fail unexpectedly because the infrastructure/ directory was not created."
fi

# Test the same, but through the fetch() function.
rm -rf ${local_snapshots}/infrastructure &>/dev/null
out="`git_reference_dir=${local_refdir} fetch infrastructure/gmp-6.0.0a.tar.xz 2>/dev/null`"
if test $? -eq 0 -a -e "${local_snapshots}/infrastructure/gmp-6.0.0a.tar.xz"; then
    pass "git_reference_dir=${local_refdir} fetch infrastructure/gmp-6.0.0a.tar.xz passed as expected because the infrastructure/ directory was created."
else
    fail "git_reference_dir=${local_refdir} fetch infrastructure/gmp-6.0.0a.tar.xz fail unexpectedly because the infrastructure/ directory was not created."
fi

# Download a clean/new copy for the check_md5sum tests
rm ${local_snapshots}/infrastructure/gmp-6.0.0a.tar.xz* &>/dev/null
fetch_http infrastructure/gmp-6.0.0a.tar.xz 2>/dev/null

out="`check_md5sum 'infrastructure/gmp-6.0.0a.tar.xz' 2>/dev/null`"
if test $? -gt 0; then
    fail "check_md5sum failed for 'infrastructure/gmp-6.0.0a.tar.xz"
else
    pass "check_md5sum passed for 'infrastructure/gmp-6.0.0a.tar.xz"
fi

# Test with a non-infrastructure file
out="`check_md5sum 'infrastructure/foo.tar.xz' 2>/dev/null`"
if test $? -gt 0; then
    pass "check_md5sum failed as expected for 'infrastructure/foo.tar.xz"
else
    fail "check_md5sum passed as expected for 'infrastructure/foo.tar.xz"
fi

mv ${local_snapshots}/infrastructure/gmp-6.0.0a.tar.xz ${local_snapshots}/infrastructure/gmp-6.0.0a.tar.xz.back
echo "empty file" > ${local_snapshots}/infrastructure/gmp-6.0.0a.tar.xz

# Test an expected failure case.
out="`check_md5sum 'infrastructure/gmp-6.0.0a.tar.xz' 2>/dev/null`"
if test $? -gt 0; then
    pass "check_md5sum failed as expected for nonmatching 'infrastructure/gmp-6.0.0a.tar.xz file"
else
    fail "check_md5sum passed unexpectedly for nonmatching 'infrastructure/gmp-6.0.0a.tar.xz file"
fi

mv ${local_snapshots}/infrastructure/gmp-6.0.0a.tar.xz.back ${local_snapshots}/infrastructure/gmp-6.0.0a.tar.xz

# ----------------------------------------------------------------------------------
#
# Test package building

# dryrun=yes
# #gcc_version=linaro-4.8-2013.09
# gcc_version=git://git.linaro.org/toolchain/gcc.git/fsf-gcc-4_8-branch

# out="`binary_toolchain 2>&1 | tee xx |grep "DRYRUN:.*Jcvf"`"

# ----------------------------------------------------------------------------------

echo "========= create_release_tag() tests ============"

mkdir -p ${local_abe_tmp}/builds/gcc
echo "5.1.1" > ${local_abe_tmp}/builds/gcc/BASE-VER
component_init gcc BRANCH="aa" REVISION="a1b2c3d4e5f6" SRCDIR="${local_abe_tmp}/builds"

testing="create_release_tag: GCC repository without release string set"
date="`date +%Y%m%d`"
out="`create_release_tag gcc | grep -v TRACE`"
toolname="`echo ${out} | cut -d '~' -f 1`"
branch="`echo ${out} | cut -d '~' -f 2 | cut -d '@' -f 1`"
revision="`echo ${out} | cut -d '@' -f 2`"
if test x"${out}" = x"gcc-linaro-5.1.1~aa@a1b2c3d4-${date}"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "create_release_tag returned ${out}"
fi

mkdir -p ${local_abe_tmp}/builds
echo "#define RELEASE \"development\""  > ${local_abe_tmp}/builds/version.h
echo "#define VERSION \"2.22.90\"" >> ${local_abe_tmp}/builds/version.h
component_init glibc BRANCH="aa/bb/cc" REVISION="1a2b3c4d5e6f" SRCDIR="${local_abe_tmp}/builds"

testing="create_release_tag: GLIBC repository without release string set"
date="`date +%Y%m%d`"
out="`create_release_tag glibc | grep -v TRACE`"
toolname="`echo ${out} | cut -d '~' -f 1`"
branch="`echo ${out} | cut -d '~' -f 2 | cut -d '@' -f 1`"
revision="`echo ${out} | cut -d '@' -f 2`"
if test x"${out}" = x"glibc-linaro-2.22.90~aa-bb-cc@1a2b3c4d-${date}"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "create_release_tag returned ${out}"
fi

release=foobar
testing="create_release_tag: GCC repository with release string set"
out="`create_release_tag gcc | grep -v TRACE`"
if test x"${out}" = x"gcc-linaro-5.1.1-${release}"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "create_release_tag returned ${out}"
fi

# rm ${local_abe_tmp}/builds/BASE-VER

export release="2015.08-rc1"
testing="create_release_tag: release candidate tarball with release"
in="gcc-linaro-5.1-2015.08-rc1.tar.xz"
out="`create_release_tag ${in} | grep -v TRACE`"
toolname="`echo ${out} | cut -d ' ' -f 1`"
branch="`echo ${out} | cut -d ' ' -f 2`"
revision="`echo ${out} | cut -d ' ' -f 3`"
if test x"${out}" = x"gcc-linaro-5.1-2015.08-rc1"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "create_release_tag returned ${out}"
fi

export release="2015.08-2-rc1"
testing="create_release_tag: release candidate tarball with release"
in="gcc-linaro-5.1-2015.08-2-rc1.tar.xz"
out="`create_release_tag ${in} | grep -v TRACE`"
toolname="`echo ${out} | cut -d ' ' -f 1`"
branch="`echo ${out} | cut -d ' ' -f 2`"
revision="`echo ${out} | cut -d ' ' -f 3`"
if test x"${out}" = x"gcc-linaro-5.1-2015.08-2-rc1"; then
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

#confirm that checkout works with raw URLs
rm -rf "${local_snapshots}"/*.git*
testing="http://abe.git@git.linaro.org/git/toolchain/abe.git"
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
  in="${service}abe.git@git.linaro.org/git/toolchain/abe.git"
  testing="checkout: ${in} should fail with 'proper URL required' message."
  if test x"${debug}" = xyes; then
    out="`cd ${local_snapshots} && checkout ${in} 2> >(tee /dev/stderr)`"
  else
    out="`cd ${local_snapshots} && checkout ${in} 2>&1`"
  fi
  if test $? -eq 0; then
    fail "${testing}"
  else
    if echo "${out}" | tail -n1 | grep -q "^ERROR.*: checkout (Unable to parse service from '${in}'\\. You have either a bad URL, or an identifier that should be passed to get_component_url\\.)$"; then
      pass "${testing}"
    else
      fail "${testing}"
    fi
  fi
done

#confirm that checkout fails with bad repo - abe is so forgiving that I can only find one suitable input
rm -rf "${local_snapshots}"/*.git*
in="http://"
testing="checkout: ${in} should fail with 'Malformed input' message."
if test x"${debug}" = xyes; then
  out="`cd ${local_snapshots} && checkout ${in} 2> >(tee /dev/stderr)`"
else
  out="`cd ${local_snapshots} && checkout ${in} 2>&1`"
fi
if test $? -eq 0; then
  fail "${testing}"
else
  if echo "${out}" | tail -n1 | grep -q "^ERROR.*: get_git_repo (Malformed input \"http://\")$"; then
    pass "${testing}"
  else
    fail "${testing}"
  fi
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
    gitinfo="`sources_conf=${test_sources_conf} get_component_url ${in}`"

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

set +x

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

# ----------------------------------------------------------------------------------
# print the total of test results
totals

# We can't just return ${failures} or it could overflow to 0 (success)
if test ${failures} -gt 0; then
    exit 1
fi
exit 0
