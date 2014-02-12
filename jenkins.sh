#!/bin/bash

# Test the config parameters from the Jenkins Build Now page

# The files in this directory are shared across all platforms 
shared="`dirname ${WORKSPACE}`/shared"

# This is the source directory for Cbuildv2. Jenkins specifies this
# sub directory when it does a git clone or pull of Cbuildv2.
cbuild_dir="${shared}/cbuildv2"

if test x"${tarsrc}" = xtrue; then
    release="--tarsrc"
fi

if test x"${tarbin}" = xtrue; then
    release="${release} --tarbin "
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
fi
if test x"${binutils_snapshot}" != x"latest" -a x"${binutils_snapshot}" != x; then
    change="${change} binutils=${binutils_snapshot}"
fi
if test x"${linux_snapshot}" != x"latest" -a x"${linux_snapshot}" != x; then
    change="${change} linux-${linux_snapshot}"
fi

#if test x"${libc}" != x; then
#    change="${change} --set libc=${libc}"
#fi

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

# if runtests is true, then run make check after the build completes
if test x"${runtests}" = xtrue; then
    check=--check
fi

if test x"${target}" != x"native" -a x"${target}" != x; then
    platform="--target ${target}"
fi

# Delete the previous test resut fikes to avoid problems.
find ${WORKSPACE} -name \*.sum -exec rm {} \;  2>&1 > /dev/null

# For cross build. For cross builds we build a native GCC, and then use
# that to compile the cross compiler to bootstrap. Since it's just
# used to build the cross compiler, we don't bother to run 'make check'.
if test x"${bootstrap}" = xtrue; then
    $CONFIG_SHELL ${cbuild_dir}/cbuild2.sh --parallel ${change} --bootstrap --build all
fi

# Now we build the cross compiler, for a native compiler this becomes
# the stage2 bootstrap build.
$CONFIG_SHELL ${cbuild_dir}/cbuild2.sh --parallel ${check} ${release} ${platform} --build all

# Create the BUILD-INFO file for Jenkins.
cat << EOF > ${WORKSPACE}/BUILD-INFO.txt
Format-Version: 0.5

Files-Pattern: *
License-Type: open
EOF

# Remove any leftover junit files
rm -f ${WORKSPACE}/*.junit ${WORKSPACE}/*.sum 2>&1 > /dev/null

# Setup the remote directory for tcwgweb
gcc="`find ${WORKSPACE} -name ${target}-gcc`"
#
if test x"${release}" = x; then
    # date="`${gcc} --version | head -1 | cut -d ' ' -f 4 | tr -d ')'`"
    date="`date +%Y%m%d`"
else
    date=${release}
fi
version="`${gcc} --version | head -1 | cut -d ' ' -f 5`"
bversion="`${target}-ld --version | head -1 | cut -d ' ' -f 5 | cut -d '.' -f 1-3`"
distro=`lsb_release -c -s`
arch=`uname -m`

node="`echo ${node_selector} | tr '-' '_'`"
case ${target} in
    arm*-linux-gnueabihf)
	abbrev=armhf
	;;
    arm*-linux-gnueabi)
	abbrev=armel
	;;
    aarch64*-linux-gnu)
	abbrev=aarch64
	;;
    aarch64_be-linux-gnu)
	abbrev=aarch64be
	;;
    aarch64*-elf)
	abbrev=aarch64_bare
	;;
    aarch64_be-*elf)
	abbrev=aarch64be_bare
	;;
    native)
	build_arch="`grep build_arch= ${WORKSPACE}/_build/host.conf | cut -d '=' -f 2`"
	abbrev="${build_arch}"
	;;
    *)
	abbrev="`echo ${target} | cut -d '-' -f 3`"
	;;
esac
#board="${node}_${abbrev}"
board="${abbrev}"

dir="gcc-linaro-${version}-${date}/logs/${arch}-${distro}-${JOB_NAME}${BUILD_NUMBER}-${board}-${node}"

rm -fr ${WORKSPACE}/results
mkdir -p ${WORKSPACE}/results/${dir}

# If 'make check' works, we get .sum files with the results. These we
# convert to JUNIT format, which is what Jenkins wants it's results
# in. We then cat them to the console, as that seems to be the only
# way to get the results into Jenkins.
sums="`find ${WORKSPACE} -name *.sum`"
if test x"${sums}" != x; then
    for i in ${sums}; do
	name="`basename $i`"
	${cbuild_dir}/sum2junit.sh $i $WORKSPACE/${name}.junit
	cp $i ${WORKSPACE}/
    done
    junits="`find ${WORKSPACE} -name *.junit`"
    if test x"${junits}" = x; then
	echo "Bummer, no junit files yet..."
    fi
else
    echo "Bummer, no test results yet..."
fi

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
	$CONFIG_SHELL ${cbuild_dir}/cbuild2.sh --nodepends --parallel ${change} ${release} --host=i586-mingw32msvc ${platform} --build all
    else
	$CONFIG_SHELL ${cbuild_dir}/cbuild2.sh --nodepends --parallel ${change} ${release} --host=i686-w64-mingw32 ${platform} --build all
    fi
fi

touch $WORKSPACE/*.junit

# This setups al lthe files needed by tcwgweb
if test x"${sums}" != x; then
    date "+%Y-%m-%d %H:%M:%S%:z" > ${WORKSPACE}/results/${dir}/finished.txt

    cp ${WORKSPACE}/*.sum ${WORKSPACE}/results/${dir}
    for i in ${WORKSPACE}/results/${dir}; do
	xz $i
    done
    # Copy over the test results
    ssh toolchain64.lab mkdir -p /space/build/${dir}
    ssh toolchain64.lab touch /space/build/${dir}/started.txt
    scp ${WORKSPACE}/results/${dir}/*.sum.xz ${WORKSPACE}/results/${dir}/finished.txt toolchain64.lab:/space/build/${dir}/
    
    # Copy over the build logs
    logs="`find ${WORKSPACE} -name make.log`"
    rm -f ${WORKSPACE}/toplevel.txt
    cat ${logs} > ${WORKSPACE}/toplevel.txt
    scp ${WORKSPACE}/toplevel.txt toolchain64.lab:/space/build/${dir}/

    # Copy over the build machine config file
    scp ${WORKSPACE}/_build/host.conf toolchain64.lab:/space/build/${dir}/hosts.txt
fi
