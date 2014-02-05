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
if test x"${libc}" != x; then
    change="${change} --set libc=${libc}"
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
    $CONFIG_SHELL ${cbuild_dir}/cbuild2.sh --nodepends --parallel ${change} --bootstrap --build all
fi

# Now we build the cross compiler, for a native compiler this becomes
# the stage2 bootstrap build.
$CONFIG_SHELL ${cbuild_dir}/cbuild2.sh --nodepends --parallel ${change} ${check} ${release} ${platform} --build all

# Create the BUILD-INFO file for Jenkins.
cat << EOF > ${WORKSPACE}/BUILD-INFO.txt
Format-Version: 0.5

Files-Pattern: *
License-Type: open
EOF

# Remove any leftover junit files
rm -f ${WORKSPACE}/*.junit 2>&1 > /dev/null

# If 'make check' works, we get .sum files with the results. These we
# convert to JUNIT format, which is what Jenkins wants it's results
# in. We then cat them to the console, as that seems to be the only
# way to get the results into Jenkins.
sums="`find ${WORKSPACE} -name *.sum`"
if test x"${sums}" != x; then
    echo "Found test results finally!!!"
    for i in ${sums}; do
	name="`basename $i`"
	${cbuild_dir}/sum2junit.sh $i $WORKSPACE/${name}.junit
	cp $i $WORKSPACE
    done
    junits="`find ${WORKSPACE} -name *.junit`"
    if test x"${junits}" != x; then
	echo "Found junit files finally!!!"
    else
	echo "Bummer, no junit files yet..."
	touch $WORKSPACE/gcc.sum.junit
    fi
else
    echo "Bummer, no test results yet..."
    touch $WORKSPACE/gcc.sum.junit
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

# Setup the remote directory for tcwgweb
gcc="`find ${WORKSPACE} -name ${target}-gcc`"
date="`${gcc} --version | head -1 | cut -d ' ' -f 4 | tr -d ')'`"
version="`${gcc} --version | head -1 | cut -d ' ' -f 5`"

distro=`lsb_release -c -s`
arch=`uname -m`

echo "TCWGWEB dir: /space/build/${version}-${date}/logs/${arch}-${distro}-${JOB_NAME}${BUILD_NUMBER}-${node_selector}-${target}"

