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
fi

# Download the first time without force.
#out="`fetch_http gmp 2>/dev/null`"
out="`fetch_http README`"
if test $? -eq 0 -a -e ${local_snapshots}/README.tar.xz; then
    pass "fetch_http README"
else
    fail "fetch_http README"
fi

# Get the timestamp of the file.
readme1=`stat -c %X ${local_snapshots}/README.tar.xz`

# Download it again
out="`fetch_http README 2>/dev/null`"
ret=$?

# Get the timestamp of the file after another fetch.
readme2=`stat -c %X ${local_snapshots}/README.tar.xz`

# They should be the same timestamp.
if test $ret -eq 0 -a ${readme1} -eq ${readme2}; then
    pass "fetch_http README didn't update as expected (force=no)"
else
    fail "fetch_http README updated unexpectedly (force=no)"
fi

# Now try it with force on
out="`force=yes fetch_http README 2>/dev/null`"
if test $? -gt 0; then
    fail "fetch_http README with \${force}=yes when source exists"
else
    pass "fetch_http README with \${force}=yes when source exists"
fi

# Get the timestamp of the file after another fetch.
readme_stamp3=`stat -c %X ${local_snapshots}/README.tar.xz`

if test ${readme_stamp1} -eq ${readme_stamp3}; then
    fail "fetch_http README with \${force}=yes has unexpected matching timestamps"
else
    pass "fetch_http README with \${force}=yes has unmatching timestamps as expected."
fi

# Make sure force doesn't get in the way of a clean download.
rm ${local_snapshots}/README.tar.xz

# force should override supdate and this should download for the first time.
out="`force=yes fetch_http README 2>/dev/null`"
if test $? -gt 0; then
    fail "fetch_http README with \${force}=yes and sources don't exist"
else
    pass "fetch_http README with \${force}=yes and sources don't exist"
fi

# Test the case where wget_bin isn't set.
#rm ${local_snapshots}/README.tar.xz

out="`unset wget_bin; fetch_http README 2>/dev/null`"
if test $? -gt 0; then
    pass "unset wget_bin; fetch_http README should fail."
else
    fail "unset wget_bin; fetch_http README should fail."
fi

<<<<<<< HEAD
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
=======
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
>>>>>>> array
else
    fail "fetch <with no filename should error>"
fi

rm ${local_snapshots}/READMEi* &>/dev/null
out="`fetch "READMEi" 2>/dev/null`"
if test $? -gt 0 -o ! -e "${local_snapshots}/READMEi.tar.xz"; then
    fail "fetch READMEi from server failed unexpectedly."
else
    pass "fetch READMEi from server passed as expected."
fi

# Create a git_reference_dir
local_refdir="${local_snapshots}/../refdir"
# We need a way to differentiate the refdir version.
cp ${local_snapshots}/READMEi* ${local_refdir}
rm ${local_snapshots}/READMEi* &>/dev/null

# Use fetch that goes to a reference dir using a shortname
out="`git_reference_dir=${local_refdir} fetch READMEi >/dev/null`"
if test $? -gt 0 -o ! -e "${local_snapshots}/READMEi.tar.xz"; then
    fail "fetch READMEi from reference dir failed unexpectedly."
else
    pass "fetch READMEi from reference dir passed as expected."
fi

rm ${local_snapshots}/READMEi* &>/dev/null
# Use fetch that goes to a reference dir using a longname
out="`git_reference_dir=${local_refdir} fetch READMEi >/dev/null`"
if test $? -gt 0 -o ! -e "${local_snapshots}/READMEi.tar.xz"; then
    fail "fetch READMEi (with full name) from reference dir failed unexpectedly."
else
    pass "fetch READMEi (with full name) from reference dir passed as expected."
fi

rm ${local_snapshots}/READMEi*

# Replace with a marked version so we can tell if it's copied the reference
# versions erroneously.
rm ${local_refdir}/infrastructure/README.tar.xz
echo "DEADBEEF" > ${local_refdir}/READMEi.tar.xz

<<<<<<< HEAD
testing="get_source: Too many snapshot matches."
in="gcc-linaro"
out="`get_source ${in} 2>/dev/null`"
if test $? -eq 1; then
    pass "${testing}"
=======
# Use fetch that finds a git reference dir but is forced to use the server.
out="`force=yes git_reference_dir=${local_refdir} fetch READMEi >/dev/null`"
if test $? -gt 0; then
    fail "fetch READMEi (with full name) from reference dir failed unexpectedly."
elif test x"$(grep DEADBEEF ${local_snapshots}/infrastructure/README.tar.xz)" != x""; then
    fail "fetch READMEi pulled from reference dir instead of server."
else
    pass "fetch READMEi (with full name) from reference dir passed as expected."
fi

# The next test makes sure that the failure is due to a file md5sum mismatch.
rm ${local_refdir}/READMEi.tar.xz
echo "DEADBEEF" > ${local_refdir}/infrastructure/README.tar.xz
out="`git_reference_dir=${local_refdir} fetch READMEi >/dev/null`"
if test $? -gt 0 -a x"$(grep DEADBEEF ${local_snapshots}/READMEi.tar.xz)" != x""; then
    pass "fetch READMEi --force=yes git_reference_dir=foo failed because md5sum doesn't match."
>>>>>>> array
else
    fail "fetch READMEi --force=yes git_reference_dir=foo unexpectedly passed."
fi

<<<<<<< HEAD
for transport in ssh git http; do
  testing="get_source: git direct url not ending in .git (${transport})"
  in="${transport}://git.linar9o.org/toolchain/eglibc"
  out="`get_source ${in}`"
  if test x"${out}" = x"${transport}://git.linaro.org/toolchain/eglibc"; then
      xpass "${testing}"
  else
      xfail "${testing}"
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
      xpass "${testing}"
  else
      xfail "${testing}"
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
=======
# Make sure supdate=no where source doesn't exist fails
rm ${local_snapshots}/READMEi.tar.xz
rm ${local_refdir}/READMEi.tar.xz
out="`supdate=no fetch README2>/dev/null`"
if test $? -gt 0; then
    pass "fetch README2 --supdate=no failed as expected when there's no source downloaded."
else
    fail "fetch README2 --supdate=no passed unexpectedly when there's no source downloaded."
fi

# Make sure supdate=no --force=yes where source doesn't exist passes by forcing
# a download
rm ${local_snapshots}/READMEi.tar.* &>/dev/null
rm ${local_refdir}/READMEi.tar.* &>/dev/null
# out="`force=yes supdate=no fetchREADME2>/dev/null`"
out="`force=yes supdate=no fetch READMEi`"
if test $? -eq 0 -a -e "${local_snapshots}/READMEi.tar.xz"; then
    pass "fetch READMEi.tar.xz --supdate=no --force=yes passed as expected when there's no source downloaded."
>>>>>>> array
else
    fail "fetch READMEi.tar.xz --supdate=no --force=yes failed unexpectedly when there's no source downloaded."
fi

# Make sure supdate=no where source does exist passes
out="`supdate=no fetch README2>/dev/null`"
if test $? -eq 0 -a -e "${local_snapshots}/READMEi.tar.xz"; then
    pass "fetch READMEi --supdate=no --force=yes passed as expected because the source already exists."
else
    fail "fetch READMEi --supdate=no --force=yes failed unexpectedly when the source exists."
fi

cp ${local_snapshots}/READMEi.tar.xz ${local_refdir}/infrastructure/ &>/dev/null

<<<<<<< HEAD
# The regular sources.conf won't have this entry.
testing="get_source: <repo>.git matches non .git suffixed url."
in="foo.git"
out="`sources_conf=${test_sources_conf} get_source ${in} 2>/dev/null`"
if test x"${out}" = x"git://testingrepository/foo"; then
    pass "${testing}"
=======
# Test to make sure the fetch_reference creates the infrastructure directory.
rm -rf ${local_snapshots}/infrastructure &>/dev/null
out="`git_reference_dir=${local_refdir} fetch_reference READMEi.tar.xz 2>/dev/null`"
if test $? -eq 0 -a -e "${local_snapshots}/READMEi.tar.xz"; then
    pass "fetch_reference READMEi.tar.xz  passed as expected because the infrastructure/ directory was created."
else
    fail "fetch_reference READMEi.tar.xz fail unexpectedly because the infrastructure/ directory was not created."
fi

# Test the same, but through the fetch() function.
rm -rf ${local_snapshots}/infrastructure &>/dev/null
out="`git_reference_dir=${local_refdir} fetch READMEi >/dev/null`"
if test $? -eq 0 -a -e "${local_snapshots}/READMEi.tar.xz"; then
    pass "git_reference_dir=${local_refdir} fetch READMEi passed as expected because the infrastructure/ directory was created."
>>>>>>> array
else
    fail "git_reference_dir=${local_refdir} fetch READMEi fail unexpectedly because the infrastructure/ directory was not created."
fi

# Download a clean/new copy for the check_md5sum tests
rm ${local_snapshots}/READMEi.tar.xz* &>/dev/null
fetch_http READMEi 2>/dev/null

out="`check_md5sum 'READMEi' 2>/dev/null`"
if test $? -gt 0; then
    fail "check_md5sum failed for 'READMEi.tar.xz"
else
    pass "check_md5sum passed for 'READMEi.tar.xz"
fi

# Test with a non-infrastructure file
out="`check_md5sum 'README1' 2>/dev/null`"
if test $? -gt 0; then
    pass "check_md5sum failed as expected for 'infrastructure/foo.tar.xz"
else
    fail "check_md5sum passed as expected for 'infrastructure/foo.tar.xz"
fi

mv ${local_snapshots}/READMEi.tar.xz ${local_snapshots}/READMEi.tar.xz.back
echo "empty file" > ${local_snapshots}/READMEi.tar.xz

<<<<<<< HEAD
testing="get_source: too many matches in snapshots, latest set."
latest="gcc-linaro-4.8-2013.09.tar.xz"
in="gcc-linaro-4.8"
out="`get_source ${in} 2>/dev/null`"
if test x"${out}" = x"gcc-linaro-4.8-2013.09.tar.xz"; then
    xpass "${testing}"
else
    xfail "${testing}"
    fixme "get_source returned ${out}"
=======
# Test an expected failure case.
out="`check_md5sum 'READMEi.tar.xz' 2>/dev/null`"
if test $? -gt 0; then
    pass "check_md5sum failed as expected for nonmatching 'READMEi'"
else
    fail "check_md5sum passed unexpectedly for nonmatching 'READMEi'"
>>>>>>> array
fi

mv ${local_snapshots}/READMEi.tar.xz.back ${local_snapshots}/READMEi.tar.xz

exit 				# HACK ALERT!

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

testing="create_release_tag: GLIBC repository with release string set"
out="`create_release_tag glibc | grep -v TRACE`"
if test x"${out}" = x"glibc-linaro-2.22.90-foobar"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "create_release_tag returned ${out}"
fi

# rm ${local_abe_tmp}/builds/BASE-VER

# ----------------------------------------------------------------------------------
echo "============= checkout () tests ================"
echo "  Checking out sources into ${local_snapshots}"
echo "  Please be patient while sources are checked out...."
echo "================================================"

# These can be painfully slow so test small repos.

#confirm that checkout works with raw URLs
rm -rf "${local_snapshots}"/*.git*
testing="http://abe.git@.git.linaro.org/git/toolchain/abe.git"
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
  in="${service}abe.git@.git.linaro.org/git/toolchain/abe.git"
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
    srcdir="`sources_conf=${test_sources_conf} get_component_srcdir "abe"`"

    local branch_test=
    if test ! -d ${srcdir}; then
	branch_test=0
    elif test x"${branch}" = x -a x"${revision}" = x; then
	branch_test=`(cd ${srcdir} && git branch | egrep -c "^\* (local_HEAD|master)$")`
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

testing="configure"
tool="dejagnu"
configure="`grep ^configure= ${topdir}/config/${tool}.conf | cut -d '\"' -f 2`"
if test x"${configure}" = xno; then
  untested "${testing}"
else
  out=`configure_build ${t_htool}.git 2>&1`
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
tool="gmp"
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
