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

# Test the config parameters from the Jenkins Build Now page

# The files in this directory are shared across all platforms 
#shared="`dirname ${WORKSPACE}`/shared"
shared="/home/buildslave/workspace/shared/"

# This is the source directory for Cbuildv2. Jenkins specifies this
# sub directory when it does a git clone or pull of Cbuildv2.
cbuild_dir="${shared}/cbuildv2"

if test x"${tarsrc}" = xtrue; then
    tars="--tarsrc"
fi

if test x"${tarbin}" = xtrue; then
    tars="${tars} --tarbin "
fi

release=
releasestr=
if ! test x"${release}" = xsnapshot -o x"${release}" = x; then
    releasestr="--release ${release}"
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
if test x"${gcc_snapshot}" != x"latest" -a x"${gcc_snapshot}" != x; then
    change="${change} gcc=${gcc_snapshot}"
    branch="~`echo ${gcc_snapshot} | cut -d '~' -f 2`"
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
	*-*elf)
	    change="${change} --set libc=newlib"
	    ;;
	*)
#	    change="${change} --set libc=${libc}"
	    change="${change} --set libc=glibc"
	    ;;
    esac
fi

# Remove the previous build if specified, default to reusing the existing
# build directory.
if test x"${reuse}" != x"true"; then
    rm -fr ${WORKSPACE}/_build
fi

# Create a build directory
if test ! -d ${WORKSPACE}/_build; then
    mkdir -p ${WORKSPACE}/_build
fi

# Use the newly created build directory
pushd ${WORKSPACE}/_build

# Delete all local config files, so any rebuilds use the currently
# committed versions.
rm -f localhost/${target}/*/*.conf

# Configure Cbuildv2 itself. Force the use of bash instead of the Ubuntu
# default of dash as some configure scripts go into an infinite loop with
# dash. Not good...
export CONFIG_SHELL="/bin/bash"
if test x"${debug}" = x"true"; then
    export CONFIG_SHELL="/bin/bash -x"
fi

$CONFIG_SHELL ${cbuild_dir}/configure --with-local-snapshots=${shared}/snapshots

# Delete the previous test resut files to avoid problems.
find ${WORKSPACE} -name \*.sum -exec rm {} \;  2>&1 > /dev/null

# For cross build. For cross builds we build a native GCC, and then use
# that to compile the cross compiler to bootstrap. Since it's just
# used to build the cross compiler, we don't bother to run 'make check'.
if test x"${bootstrap}" = xtrue; then
    $CONFIG_SHELL ${cbuild_dir}/cbuild2.sh --parallel ${change} --bootstrap --build all
fi

# Now we build the cross compiler, for a native compiler this becomes
# the stage2 bootstrap build.
$CONFIG_SHELL ${cbuild_dir}/cbuild2.sh --parallel ${check} ${tars} ${releasestr} ${platform} ${change} --build all

# Create the BUILD-INFO file for Jenkins.
cat << EOF > ${WORKSPACE}/BUILD-INFO.txt
Format-Version: 0.5

Files-Pattern: *
License-Type: open
EOF

# Remove any leftover junit files
#rm -f ${WORKSPACE}/*.junit ${WORKSPACE}/*.sum 2>&1 > /dev/null

# Setup the remote directory for tcwgweb
if test x"${target}" = x"native"; then
    gcc="`find ${WORKSPACE} -name gcc`"
else
    gcc="`find ${WORKSPACE} -name ${target}-gcc`"
fi

# If we can't find GCC, our build failed, so don't continue
if test x"${gcc}" = x; then
    exit 1
fi

#
if test x"${tars}" = x; then
    # date="`${gcc} --version | head -1 | cut -d ' ' -f 4 | tr -d ')'`"
    date="`date +%Y%m%d`"
else
    date=${release}
fi

version="`${gcc} --version | head -1 | cut -d ' ' -f 5`"
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

manifest="`find ${WORKSPACE} -name manifest.txt`"
if test x"${manifest}" != x; then
    echo "node=${node}" >> ${manifest}
    echo "requestor=${requestor}" >> ${manifest}
    revision="`grep 'gcc_revision=' ${manifest} | cut -d '=' -f 2
    if test x"${BUILD_USER_ID}" != x; then
	echo "email=${BUILD_USER_ID}" >> ${manifest}
    fi
    scp ${manifest} toolchain64.lab:${basedir}/${dir}/
else
    echo "ERROR: No manifest file, build probably failed!"
fi
    
dir="gcc-linaro-${version}/${branch}-${revision}/${arch}.${target}-${job}${BUILD_NUMBER}"

rm -fr ${WORKSPACE}/results
mkdir -p ${WORKSPACE}/results/${dir}

# Find all the test result files.
sums="`find ${WORKSPACE} -name *.sum`"

# If 'make check' works, we get .sum files with the results. These we
# convert to JUNIT format, which is what Jenkins wants it's results
# in. We then cat them to the console, as that seems to be the only
# way to get the results into Jenkins.
#if test x"${sums}" != x; then
#    for i in ${sums}; do
#	name="`basename $i`"
#	${cbuild_dir}/sum2junit.sh $i $WORKSPACE/${name}.junit
#	cp $i ${WORKSPACE}/results/${dir}
#    done
#    junits="`find ${WORKSPACE} -name *.junit`"
#    if test x"${junits}" = x; then
#	echo "Bummer, no junit files yet..."
#    fi
#else
#    echo "Bummer, no test results yet..."
#fi

if test "`echo ${sums} | grep -c gcc.sum`" -eq 0 -a x"${runtests}" = xtrue; then
    echo "ERROR: GCC testsuite wasn't run!"
    exit 1
fi

# Canadian Crosses are a win32 hosted cross toolchain built on a Linux
# machine.
if test x"${canadian}" = x"true"; then
    $CONFIG_SHELL ${cbuild_dir}/cbuild2.sh --nodepends --parallel ${change} ${platform} --build all
    distro="`lsb_release -sc`"
    # Ubuntu Lucid uses an older version of Mingw32
    if test x"${distro}" = x"lucid"; then
	$CONFIG_SHELL ${cbuild_dir}/cbuild2.sh --nodepends --parallel ${change} ${tars} --host=i586-mingw32msvc ${platform} --build all
    else
	$CONFIG_SHELL ${cbuild_dir}/cbuild2.sh --nodepends --parallel ${change} ${tars} --host=i686-w64-mingw32 ${platform} --build all
    fi
fi

#touch $WORKSPACE/*.junit

# This setups all the files needed by tcwgweb
if test x"${sums}" != x; then
    basedir="/work/logs"
    tdate="`date "+%Y-%m-%d %H:%M:%S%:z"`"
    echo ${tdate} > ${WORKSPACE}/results/${dir}/finished.txt

    cp ${sums} ${WORKSPACE}/results/${dir}
    # Copy over the test results
    ssh toolchain64.lab mkdir -p ${basedir}/${dir}
    ssh toolchain64.lab touch ${basedir}/${dir}/started.txt
    scp ${WORKSPACE}/results/${dir}/*.sum* ${WORKSPACE}/results/${dir}/finished.txt toolchain64.lab:/space/build/${dir}/
    
    # Copy over the build logs
    logs="`find ${WORKSPACE} -name make.log`"
    rm -f ${WORKSPACE}/toplevel.txt
    cat ${logs} > ${WORKSPACE}/toplevel.txt
    scp ${WORKSPACE}/toplevel.txt toolchain64.lab:${basedir}/${dir}/

#    logs="`find ${WORKSPACE} -name \*.log | grep -v make.log`"
#    for i in ${logs}; do
#	component="`dirname $i`"
#	component="`basename ${component}`"
#	scp $i toolchain64.lab:${basedir}/${dir}/${component}.log
#    done
    ssh toolchain64.lab xz ${basedir}/${dir}/\*.log ${basedir}/${dir}/\*.sum

    # Copy over the build machine config file
    scp ${WORKSPACE}/_build/host.conf toolchain64.lab:${basedir}/${dir}/hosts.txt

    date "+%Y-%m-%d %H:%M:%S%:z" > ${WORKSPACE}/results/${dir}/finished.txt
    scp ${WORKSPACE}/results/${dir}/finished.txt toolchain64.lab:${basedir}/${dir}/

    allfiles="`ls ${shared}/snapshots/*${release}*.xz`"
    if test x"${tarsrc}" = xtrue; then
	srcfiles="`echo ${allfiles} | egrep -v "arm|aarch"`"
	scp ${srcfiles} toolchain64.lab:/home/cbuild/var/snapshots/
    fi

    if test x"${tarbin}" = xtrue; then
	binfiles="`echo ${allfiles} | egrep "arm|aarch"`"
	scp ${binfiles} toolchain64.lab:/space/binaries/
    fi

    rdate="`date +%Y%m`"
    ssh toolchain64.lab /home/cbuild/tcwgweb.sh --base ${dir}
fi

