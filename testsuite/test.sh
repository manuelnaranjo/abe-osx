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
. "${topdir}/testsuite/stamp-tests.sh"
#. "${topdir}/testsuite/normalize-tests.sh"
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

collect_data gmp

# Download the first time without force.
out="`fetch_http gmp 2>/dev/null`"
if test $? -eq 0 -a -e ${local_snapshots}/gmp-6.0.0a.tar.xz; then
    pass "fetch_http gmp"
else
    fail "fetch_http gmp"
fi

# Get the timestamp of the file.
gmp_stamp1=`stat -c %X ${local_snapshots}/gmp-6.0.0a.tar.xz`

# Download it again
out="`fetch_http gmp 2>/dev/null`"
ret=$?

# Get the timestamp of the file after another fetch.
gmp_stamp2=`stat -c %X ${local_snapshots}/gmp-6.0.0a.tar.xz`

# They should be the same timestamp.
if test $ret -eq 0 -a ${gmp_stamp1} -eq ${gmp_stamp2}; then
    pass "fetch_http gmp didn't update as expected (force=no)"
else
    fail "fetch_http gmp updated unexpectedly (force=no)"
fi

# If the two operations happen within the same second then their timestamps will
# be equivalent.  This sleep operation forces the timestamps apart.
sleep 2s

# Now try it with force on
out="`force=yes fetch_http gmp 2>/dev/null`"
if test $? -gt 0; then
    fail "fetch_http gmp with \${force}=yes when source exists"
else
    pass "fetch_http gmp with \${force}=yes when source exists"
fi

# Get the timestamp of the file after another fetch.
gmp_stamp3=`stat -c %X ${local_snapshots}/gmp-6.0.0a.tar.xz`

if test ${gmp_stamp1} -eq ${gmp_stamp3}; then
    fail "fetch_http gmp with \${force}=yes has unexpected matching timestamps"
else
    pass "fetch_http gmp with \${force}=yes has unmatching timestamps as expected."
fi

# Make sure force doesn't get in the way of a clean download.
rm ${local_snapshots}/gmp-6.0.0a.tar.xz

# force should override supdate and this should download for the first time.
out="`force=yes fetch_http gmp 2>/dev/null`"
if test $? -gt 0; then
    fail "fetch_http gmp with \${force}=yes and sources don't exist"
else
    pass "fetch_http gmp with \${force}=yes and sources don't exist"
fi

# Test the case where wget_bin isn't set.
rm ${local_snapshots}/gmp-6.0.0a.tar.xz

out="`unset wget_bin; fetch_http gmp 2>/dev/null`"
if test $? -gt 0; then
    pass "unset wget_bin; fetch_http gmp should fail."
else
    fail "unset wget_bin; fetch_http gmp should fail."
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

# Create a git_reference_dir
local_refdir="${local_snapshots}/../refdir"
mkdir -p ${local_refdir}
# We need a way to differentiate the refdir version.
cp ${local_snapshots}/gmp-* ${local_refdir}/
rm -f ${local_snapshots}/gmp-* &>/dev/null

rm -f ${local_snapshots}/gmp-* &>/dev/null
# Use fetch that goes to a reference dir using a longname
out="`git_reference_dir=${local_refdir} fetch gmp &>/dev/null`"
if test $? -gt 0 -o ! -e "${local_snapshots}/gmp-6.0.0a.tar.xz"; then
    fail "fetch gmp (with full name) from reference dir failed unexpectedly."
else
    pass "fetch gmp (with full name) from reference dir passed as expected."
fi

rm -f ${local_snapshots}/gmp-* &>/dev/null

# Replace with a marked version so we can tell if it's copied the reference
# versions erroneously.
rm -f ${local_refdir}/gmp-6.0.0a.tar.xz
echo "DEADBEEF" > ${local_refdir}/gmp-6.0.0a.tar.xz

# Use fetch that finds a git reference dir but is forced to use the server.
out="`force=yes git_reference_dir=${local_refdir} fetch gmp 2>/dev/null`"
if test $? -gt 0; then
    fail "fetch gmp (with full name) from reference dir failed unexpectedly."
elif test x"$(grep DEADBEEF ${local_snapshots}/gmp-6.0.0a.tar.xz)" != x""; then
    fail "fetch gmp pulled from reference dir instead of server."
else
    pass "fetch gmp (with full name) from reference dir passed as expected."
fi

# Make sure supdate=no where source doesn't exist fails
rm ${local_snapshots}/gmp-6.0.0a.tar.xz
rm ${local_refdir}/gmp-6.0.0a.tar.xz
out="`supdate=no fetch gmp 2>/dev/null`"
if test $? -gt 0; then
    pass "fetch gmp --supdate=no failed as expected when there's no source downloaded."
else
    fail "fetch gmp --supdate=no passed unexpectedly when there's no source downloaded."
fi

# Make sure supdate=no --force=yes where source doesn't exist passes by forcing
# a download
rm ${local_snapshots}/gmp-6.0.0a.tar.xz &>/dev/null
rm ${local_refdir}/gmp-6.0.0a.tar.xz &>/dev/null
out="`force=yes supdate=no fetch gmp 2>/dev/null`"
if test $? -eq 0 -a -e "${local_snapshots}/gmp-6.0.0a.tar.xz"; then
    pass "fetch gmp --supdate=no --force=yes passed as expected when there's no source downloaded."
else
    fail "fetch gmp --supdate=no --force=yes failed unexpectedly when there's no source downloaded."
fi

# Make sure supdate=no where source does exist passes
out="`supdate=no fetch gmp 2>/dev/null`"
if test $? -eq 0 -a -e "${local_snapshots}/gmp-6.0.0a.tar.xz"; then
    pass "fetch gmp --supdate=no --force=yes passed as expected because the source already exists."
else
    fail "fetch gmp --supdate=no --force=yes failed unexpectedly when the source exists."
fi

cp ${local_snapshots}/gmp-6.0.0a.tar.xz ${local_refdir}/ &>/dev/null

# Download a clean/new copy for the check_md5sum tests
rm ${local_snapshots}/gmp-6.0.0a.tar.xz* &>/dev/null
fetch_http gmp 2>/dev/null

out="`check_md5sum 'gmp' 2>/dev/null`"
if test $? -gt 0; then
    fail "check_md5sum failed for 'gmp"
else
    pass "check_md5sum passed for 'gmp"
fi

# Test with a non-infrastructure file
out="`check_md5sum 'foo' 2>/dev/null`"
if test $? -gt 0; then
    pass "check_md5sum failed as expected for 'foo"
else
    fail "check_md5sum passed as expected for 'foo"
fi

mv ${local_snapshots}/gmp-6.0.0a.tar.xz ${local_snapshots}/gmp-6.0.0a.tar.xz.back
echo "empty file" > ${local_snapshots}/gmp-6.0.0a.tar.xz

# Test an expected failure case.
out="`check_md5sum 'gmp' 2>/dev/null`"
if test $? -gt 0; then
    pass "check_md5sum failed as expected for nonmatching 'gmp file"
else
    fail "check_md5sum passed unexpectedly for nonmatching 'gmp file"
fi

mv ${local_snapshots}/gmp-6.0.0a.tar.xz.back ${local_snapshots}/gmp-6.0.0a.tar.xz

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

mkdir -p ${local_abe_tmp}/builds
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
in="gcc-linaro-5.1.1-2015.08-rc1.tar.xz"
out="`create_release_tag ${in} | grep -v TRACE`"
toolname="`echo ${out} | cut -d ' ' -f 1`"
branch="`echo ${out} | cut -d ' ' -f 2`"
revision="`echo ${out} | cut -d ' ' -f 3`"
if test x"${out}" = x"gcc-linaro-5.1.1-2015.08-rc1"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "create_release_tag returned ${out}"
fi

export release="2015.08-2-rc1"
testing="create_release_tag: release candidate tarball with release"
in="gcc-linaro-5.1.1-2015.08-2-rc1.tar.xz"
out="`create_release_tag ${in} | grep -v TRACE`"
toolname="`echo ${out} | cut -d ' ' -f 1`"
branch="`echo ${out} | cut -d ' ' -f 2`"
revision="`echo ${out} | cut -d ' ' -f 3`"
if test x"${out}" = x"gcc-linaro-5.1.1-2015.08-2-rc1"; then
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

component_init abe TOOL=abe URL=http://git.linaro.org/toolchain FILESPEC=abe.git SRCDIR=${local_snapshots}/abe.git BRANCH=master

# confirm that checkout works with raw URLs
rm -rf "${local_snapshots}"/*.git*
testing="http://abe.git@git.linaro.org/git/toolchain/abe.git"
in="abe"
if test x"${debug}" = xyes; then
  out="`cd ${local_snapshots} && checkout ${in}`"
else
  out="`cd ${local_snapshots} && checkout ${in} 2>/dev/null`"
fi
if test $? -eq 0; then
  pass "${testing}"
else
  fail "${testing}"
fi

# confirm that checkout fails approriately with a range of bad services in raw URLs
for service in "foomatic://" "http:" "http:/fake.git" "http/" "http//" ""; do
  rm -rf "${local_snapshots}"/*.git*
  url="${service}abe.git@git.linaro.org/git/toolchain"
  set_component_url abe ${url}
  in="abe"
  testing="checkout: ${in} should fail with 'proper URL required' message for ${service}."
  if test x"${debug}" = xyes; then
    out="`cd ${local_snapshots} && checkout ${in} 2> >(tee /dev/stderr)`"
  else
    out="`cd ${local_snapshots} && checkout ${in} 2>&1`"
  fi
  if test $? -eq 0; then
    fail "${testing}"
  else
    if echo "${out}" | grep -q "^ERROR.*: checkout (proper URL required)"; then
      pass "${testing}"
    else
      fail "${testing}"
    fi
  fi
done

# only find one suitable input
rm -rf "${local_snapshots}"/*.git*
set_component_url abe "http://"
in="abe"
testing="checkout: ${in} should fail with 'Malformed input' message."
if test x"${debug}" = xyes; then
  out="`cd ${local_snapshots} && checkout ${in} 2> >(tee /dev/stderr)`"
else
  out="`cd ${local_snapshots} && checkout ${in} 2>&1`"
fi
if test $? -eq 0; then
  fail "${testing}"
else
  if echo "${out}" | grep -q "^ERROR.*: checkout (proper URL required)"; then
    pass "${testing}"
  else
    fail "${testing}"
  fi
fi

# Reset the URL
set_component_url abe "http://git.linaro.org/toolchain"

test_checkout ()
{
    local should="$1"
    local testing="$2"
    local package="$3"
    local branch="$4"
    local revision="$5"
    local ret=
    local out=
    
    # Make sure there's no hanging state relating to this test before it runs
    rm -rf ${local_snapshots}/${package}*

    if test x"${branch}" != x; then
	set_component_branch ${package} ${branch}
    fi
    if test x"${branch}" != x; then
	set_component_revision ${package} ${revision}
    fi
    if test x"${debug}" = x"yes"; then
	out="`(cd ${local_snapshots} && checkout ${package})`"
	ret=$?
	if test ${ret} -eq 0 -a x"${should}" = x"pass"; then
	    pass "function ${testing}"
	fi
	if test ${ret} -eq 0 -a x"${should}" = x"fail"; then
	    fail "function ${testing}"
	fi
	if test ${ret} -eq 1 -a x"${should}" = x"pass"; then
	    fail "function ${testing}"
	fi
	if test ${ret} -eq 1 -a x"${should}" = x"fail"; then
	    pass "function ${testing}"
	fi
    else
	out="`(cd ${local_snapshots} && checkout ${package})`"
	local ret=$?
	if test ${ret} -eq 0 -a x"${should}" = x"pass"; then
	    pass "function ${testing}"
	fi
	if test ${ret} -eq 0 -a x"${should}" = x"fail"; then
	    fail "function ${testing}"
	fi
	if test ${ret} -eq 1 -a x"${should}" = x"pass"; then
	    fail "function ${testing}"
	fi
	if test ${ret} -eq 1 -a x"${should}" = x"fail"; then
	    pass "function ${testing}"
	fi
    fi

    set_component_branch ${package} ""
    set_component_revision ${package} ""

    local srcdir="`get_component_srcdir ${package}`"
    local branch_test=0
    if test -d ${srcdir}; then
	if test x"${branch}" = x -a x"${revision}" = x; then
            branch_test=`(cd ${srcdir} && git branch -a | egrep -c "^\* (local_HEAD|master)$")`
	elif test x"${revision}" = x; then
            branch_test=`(cd ${srcdir} && git branch -a | grep -c "^\* ${branch}$")`
	else
            branch_test=`(cd ${srcdir} && git branch -a | grep -c "^\* local_${revision}$")`
	fi
    else
	untested "${testing}"
	return 1
    fi

    # Make sure we leave no hanging state
    rm -rf "${local_snapshots}/${package}"*
    case ${should} in
	*pass)
	    if test "${branch_test}" -gt 0; then
		pass "${testing}"
		return 0
	    fi
	    fail "${testing}"
	    return 1
	    ;;
	*fail)
	    if test "${branch_test}" -eq 0; then
		pass "${testing}"
		return 0
	    fi
	    fail "${testing}"
	    return 1
	    ;;
	*)
	    fail "${testing}"
	    return 1
	    ;;
    esac
}

testing="checkout: http://git@<url>/<repo>.git"
package="abe"
branch=''
revision=''
should="pass"
test_checkout "${should}" "${testing}" "${package}" "${branch}" "${revision}"

testing="checkout: http://git@<url>/<repo>.git/<branch>"
package="abe"
branch="stable"
revision=''
should="pass"
test_checkout "${should}" "${testing}" "${package}" "${branch}" "${revision}"

testing="checkout: http://git@<url>/<repo>.git@<revision>"
package="abe"
branch='master'
revision="9bcced554dfc"
should="pass"
test_checkout "${should}" "${testing}" "${package}" "${branch}" "${revision}"

testing="checkout: http://git@<url>/<repo>.git/unusedbranchname@<revision>"
package="abe.git"
branch="unusedbranchname"
revision="9bcced554dfc"
should="pass"
test_checkout "${should}" "${testing}" "${package}" "${branch}" "${revision}"

# This should fail because it's an unknown repository
component_init foo TOOL=foo

testing="checkout: git://testingrepository/foo should fail with 'clone failed' message."
package="foo.git"
branch=''
revision=''
should="fail"
test_checkout "${should}" "${testing}" "${package}" "${branch}" "${revision}"

# This should fail because an unknown branch is specified
testing="checkout: http://git@<url>/<repo>.git/<nonexistentbranch> should fail with 'branch does not exist' message."
package="abe.git"
branch="nonexistentbranch"
revision=''
should="fail"
test_checkout "${should}" "${testing}" "${package}" "${branch}" "${revision}"

# This should fail because an unknown revision is specified
testing="checkout: http://git@<url>/<repo>.git@<nonexistentrevision> should fail with 'revision does not exist' message."
package="abe.git"
branch=''
revision="123456bogusbranch"
should="fail"
test_checkout "${should}" "${testing}" "${package}" "${branch}" "${revision}"

testing="checkout: http://git@<url>/<repo>.git~<branch> should pass with appropriate notice"
package="abe.git"
branch='staging'
revision=""
should="pass"
test_checkout "${should}" "${testing}" "${package}" "${branch}" "${revision}"

rm -rf "${local_snapshots}"/*.git*

echo "============= misc tests ================"
testing="pipefail"
out="`false | tee /dev/null`"
if test $? -ne 0; then
    pass "${testing}"
else
    fail "${testing}"
fi

# Do not pollute env
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

component_init dejagnu TOOL=dejagnu BRANCH=linaro SRCDIR=${local_snapshots}/dejagnu.git~linaro BUILDDIR=${local_builds}/dejagnu.git~linaro FILESPEC=dejagnu.git URL=http://git.linaro.org/git/toolchain

checkout dejagnu
if test $? -eq 0; then
    pass "Checking out Dejagnu for configure test"
else
    fail "Checking out Dejagnu for configure test"
fi

testing="configure"
tool="dejagnu"
configure="`grep ^configure= ${topdir}/config/${tool}.conf | cut -d '\"' -f 2`"
if test x"${configure}" = xno; then
    untested "${testing}"
else
    out=`configure_build ${tool} 2>&1`
    ret=$?
    if test x"${debug}" = x"yes"; then
	echo "${out}"
    fi
    if test -f ${local_builds}/dejagnu.git~linaro/config.log -a ${ret} -eq 0; then
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
