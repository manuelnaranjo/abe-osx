#!/bin/bash
# 
#   Copyright (C) 2013, 2014 Linaro, Inc
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
# 


usage()
{
    # Format this section with 75 columns.
    cat << EOF
  jenkins.sh [--help] [-s snapshot dir] [g git reference dir] [abe path] [w workspace]
EOF
    return 0
}

if test $# -lt 1; then
    echo "ERROR: No options for build!"
    usage
#    exit
fi

# load commonly used functions
which_dir="`which $0`"
topdir="`dirname ${which_dir}`"

# This is where all the builds go
if test x"${WORKSPACE}" = x; then
    WORKSPACE="`pwd`"
fi
user_workspace="${WORKSPACE}"

# The files in this directory are shared across all platforms 
shared="${HOME}/workspace/shared"

# This is where all the git repositories live
user_git_repo="--with-git-reference-dir=${shared}/snapshots"

# set default values for options to make life easier
user_snapshots="${user_workspace}/snapshots"

# The release version string, usually a date
releasestr=

# This is a string of optional extra arguments to pass to abe at runtime
user_options=""

OPTS="`getopt -o s:g:c:w:o:f:t:h -l snapshots:gitrepo:abe:workspace:options:fileserver:target:help -- "$@"`"
while test $# -gt 0; do
    echo 1 = "$1"
    case $1 in
        -s|--snapshots) user_snapshots=$2 ;;
        -g|--gitrepo) user_git_repo=$2 ;;
        -c|--abe) abe_dir=$2 ;;
	-t|--target) target=$2 ;;
        -w|--workspace) user_workspace=$2 ;;
        -o|--options) user_options=$2 ;;
        -f|--fileserver) fileserver=$2 ;;
        -r|--runtests) runtests="true" ;;
	-h|--help) usage ;;
    esac
    shift
done

# Test the config parameters from the Jenkins Build Now page

# See if we're supposed to build a source tarball
if test x"${tarsrc}" = xtrue -o "`echo $user_options | grep -c -- --tarsrc`" -gt 0; then
    tars="--tarsrc"
fi

# See if we're supposed to build a binary tarball
if test x"${tarbin}" = xtrue -o "`echo $user_options | grep -c -- --tarbin`" -gt 0; then
    tars="${tars} --tarbin "
fi

# Set the release string if specefied
if ! test x"${release}" = xsnapshot -o x"${release}"; then
    releasestr="--release ${release}"
fi
if test "`echo $user_options | grep -c -- --release`" -gt 0; then
    release="`echo  $user_options | grep -o -- "--release [a-zA-Z0-9]* " | cut -d ' ' -f 2`"
    releasestr="--release ${release}"
fi

# This is an optional directory for the master copy of the git repositories.
if test x"${user_git_repo}" = x; then
    user_git_repo="--with-git-reference-dir=${shared}/snapshots"
fi

# Get the versions of dependant components to use
changes=""
if test x"${gmp_snapshot}" != x"latest" -a x"${gmp_snapshot}" != x; then
    change="${change} gmp=${gmp_snapshot}"
fi
if test x"${mpc_snapshot}" != x"latest" -a x"${mpc_snapshot}" != x; then
    change="${change} mpc=${mpc_snapshot}"
fi
if test x"${mpfr_snapshot}" != x"latest" -a x"${mpfr_snapshot}" != x; then
    change="${change} mpfr=${mpfr_snapshot}"
fi

# Get the version of GCC we're supposed to build
if test x"${gcc_branch}" != x"latest" -a x"${gcc_branch}" != x; then
    change="${change} gcc=${gcc_branch}"
    branch="`echo ${gcc_branch} | cut -d '~' -f 2 | sed -e 's:\.tar\.xz::'`"
else
    branch=
fi

if test x"${binutils_snapshot}" != x"latest" -a x"${binutils_snapshot}" != x; then
    change="${change} binutils=${binutils_snapshot}"
fi
if test x"${linux_snapshot}" != x"latest" -a x"${linux_snapshot}" != x; then
    change="${change} linux-${linux_snapshot}"
fi

# if runtests is true, then run make check after the build completes
if test x"${runtests}" = xtrue; then
    check=--check
fi

if test x"${target}" != x"native" -a x"${target}" != x; then
    platform="--target ${target}"
fi

if test x"${libc}" != x; then
    # ELF based targets are bare metal only
    case ${target} in
	arm*-none-*)
	    change="${change} --set libc=newlib"
	    ;;
	*)
	    change="${change} --set libc=${libc}"
	    ;;
    esac
fi

# This is the top level directory where builds go.
if test x"${user_workspace}" = x; then
    user_workspace="${WORKSPACE}"
fi

# Create a build directory
if test ! -d ${user_workspace}/_build; then
    mkdir -p ${user_workspace}/_build
fi

# Use the newly created build directory
pushd ${user_workspace}/_build

# Configure Abe itself. Force the use of bash instead of the Ubuntu
# default of dash as some configure scripts go into an infinite loop with
# dash. Not good...
export CONFIG_SHELL="/bin/bash"
if test x"${debug}" = x"true"; then
    export CONFIG_SHELL="/bin/bash -x"
fi

if test x"${abe_dir}" = x; then
    abe_dir=${topdir}
fi
$CONFIG_SHELL ${abe_dir}/configure --with-local-snapshots=${user_snapshots} --with-git-reference-dir=${shared}/snapshots

# load commonly used varibles set by configure
if test -e "${PWD}/host.conf"; then
    . "${PWD}/host.conf"
fi

# This is the top level directory for the abe sources.
#abe_dir="${abe_path}"

# Delete the previous test result files to avoid problems.
find ${user_workspace} -name \*.sum -exec rm {} \;  2>&1 > /dev/null

# For cross build. For cross builds we build a native GCC, and then use
# that to compile the cross compiler to bootstrap. Since it's just
# used to build the cross compiler, we don't bother to run 'make check'.
if test x"${bootstrap}" = xtrue; then
    $CONFIG_SHELL ${abe_dir}/abe.sh --parallel ${change} --bootstrap --build all
fi

# Now we build the cross compiler, for a native compiler this becomes
# the stage2 bootstrap build.
$CONFIG_SHELL ${abe_dir}/abe.sh --parallel ${check} ${tars} ${releasestr} ${platform} ${change} --timeout 100 --build all

# If abe returned an error, make jenkins see this as a build failure
if test $? -gt 0; then
    exit 1
fi

# Create the BUILD-INFO file for Jenkins.
cat << EOF > ${user_workspace}/BUILD-INFO.txt
Format-Version: 0.5

Files-Pattern: *
License-Type: open
EOF

if test x"${tars}" = x; then
    # date="`${gcc} --version | head -1 | cut -d ' ' -f 4 | tr -d ')'`"
    date="`date +%Y%m%d`"
else
    date=${release}
fi

# Setup the remote directory for tcwgweb
if test x"${target}" = x"native"; then
    gcc="`find ${user_workspace} -name \*-gcc`"
else
    gcc="`find ${user_workspace} -name ${target}-gcc`"
fi

# If we can't find GCC, our build failed, so don't continue
if test x"${gcc}" = x; then
    exit 1
fi

version="`${gcc} --version | head -1 | cut -d ' ' -f 5`"
if test x"${version}" = x"(experimental)" ; then
    version=4.10
fi
# bversion="`${target}-ld --version | head -1 | cut -d ' ' -f 5 | cut -d '.' -f 1-3`"
distro="`lsb_release -c -s`"
arch="`uname -m`"

# Non matrix builds use node_selector, but matrix builds use NODE_NAME
if test x"${node_selector}" != x; then
    node="`echo ${node_selector} | tr '-' '_'`"
    job=${JOB_NAME}
else
    node="`echo ${NODE_NAME} | tr '-' '_'`"
    job="`echo ${JOB_NAME}  | cut -d '/' -f 1`"
fi

# This is the remote directory for tcwgweb where all test results and log
# files get copied too.

# These fields are enabled by the buikd-user-vars plugin.
if test x"${BUILD_USER_FIRST_NAME}" != x; then
    requestor="-${BUILD_USER_FIRST_NAME}"
fi
if test x"${BUILD_USER_LAST_NAME}" != x; then
    requestor="${requestor}.${BUILD_USER_LAST_NAME}"
fi

echo "Build by ${requestor} on ${NODE_NAME} for branch ${branch}"

manifest="`find ${user_workspace} -name manifest.txt`"
if test x"${manifest}" != x; then
    echo "node=${node}" >> ${manifest}
    echo "requestor=${requestor}" >> ${manifest}
    revision="`grep 'gcc_revision=' ${manifest} | cut -d '=' -f 2 | tr -s ' '`"
    if test x"${revision}" != x; then
	revision="-${revision}"
    fi
    if test x"${BUILD_USER_ID}" != x; then
	echo "email=${BUILD_USER_ID}" >> ${manifest}
    fi
    echo "build_url=${BUILD_URL}" >> ${manifest}
else
    echo "ERROR: No manifest file, build probably failed!"
fi

# This becomes the path on the remote file server    
if test x"${runtests}" = xtrue; then
    basedir="/work/logs"
    dir="gcc-linaro-${version}/${branch}${revision}/${arch}.${target}-${job}${BUILD_NUMBER}"
    ssh ${fileserver} mkdir -p ${basedir}/${dir}
    if test x"${manifest}" != x; then
	scp ${manifest} ${fileserver}:${basedir}/${dir}/
    fi

# If 'make check' works, we get .sum files with the results. These we
# convert to JUNIT format, which is what Jenkins wants it's results
# in. We then cat them to the console, as that seems to be the only
# way to get the results into Jenkins.
#if test x"${sums}" != x; then
#    for i in ${sums}; do
#	name="`basename $i`"
#	${abe_dir}/sum2junit.sh $i $user_workspace/${name}.junit
#	cp $i ${user_workspace}/results/${dir}
#    done
#    junits="`find ${user_workspace} -name *.junit`"
#    if test x"${junits}" = x; then
#	echo "Bummer, no junit files yet..."
#    fi
#else
#    echo "Bummer, no test results yet..."
#fi
#touch $user_workspace/*.junit
fi

# Find all the test result files.
sums="`find ${user_workspace} -name *.sum`"

# Canadian Crosses are a win32 hosted cross toolchain built on a Linux
# machine.
if test x"${canadian}" = x"true"; then
    $CONFIG_SHELL ${abe_dir}/abe.sh --nodepends --parallel ${change} ${platform} --build all
    distro="`lsb_release -sc`"
    # Ubuntu Lucid uses an older version of Mingw32
    if test x"${distro}" = x"lucid"; then
	$CONFIG_SHELL ${abe_dir}/abe.sh --nodepends --parallel ${change} ${tars} --host=i586-mingw32msvc ${platform} --build all
    else
	$CONFIG_SHELL ${abe_dir}/abe.sh --nodepends --parallel ${change} ${tars} --host=i686-w64-mingw32 ${platform} --build all
    fi
fi

# This setups all the files needed by tcwgweb
if test x"${sums}" != x -o x"${runtests}" != x"true"; then
    if test x"${sums}" != x; then
	test_logs=""
	for s in ${sums}; do
	    test_logs="$test_logs ${s%.sum}.log"
	done
	scp ${sums} $test_logs ${fileserver}:${basedir}/${dir}/
	
	# Copy over the logs from make check, which we need to find testcase errors.
	checks="`find ${user_workspace} -name check\*.log`"
	scp ${checks} ${fileserver}:${basedir}/${dir}/
	
	# Copy over the build logs
	logs="`find ${user_workspace} -name make\*.log`"
	scp ${logs} ${fileserver}:${basedir}/${dir}/
	ssh ${fileserver} xz ${basedir}/${dir}/\*.sum ${basedir}/${dir}/\*.log
	scp ${abe_dir}/tcwgweb.sh ${fileserver}:/tmp/tcwgweb$$.sh
	ssh ${fileserver} /tmp/tcwgweb$$.sh --email --base ${basedir}/${dir}
	ssh ${fileserver} rm -f /tmp/tcwgweb$$.sh

	echo "Sent test results"
    fi
    if test x"${tarsrc}" = xtrue -a x"${release}" != x; then
	allfiles="`ls ${shared}/snapshots/*${release}*.xz`"
	srcfiles="`echo ${allfiles} | egrep -v "arm|aarch"`"
	scp ${srcfiles} ${fileserver}:/home/abe/var/snapshots/
	rm -f ${srcfiles}
    fi

    if test x"${tarbin}" = xtrue -a x"${release}" != x; then
	allfiles="`ls ${shared}/snapshots/*${release}*.xz`"
	binfiles="`echo ${allfiles} | egrep "arm|aarch"`"
	scp ${binfiles} ${fileserver}:/work/space/binaries/
	rm -f ${binfiles}
    fi

fi

