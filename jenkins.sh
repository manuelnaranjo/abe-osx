#!/bin/bash

# Test the config parameters from the Jenkins Build Now page

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

# Remove the previous build
rm -fr _build

# Create a build directory
mkdir -p _build

# Use the newly created build directory
cd _build

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

$CONFIG_SHELL ../configure --with-local-snapshots=$WORKSPACE/cbuildv2/snapshots

# if runtests is true, then run make check after the build completes
if test x"${runtests}" = xtrue; then
    runtest=--check
fi

if test x"${tarballs}" = xtrue; then
    tarballs=--tarballs
fi

# For coss build. For cross builds we build a native GCC, and then use
# that to compile the cross compiler to bootstrap. Since it's just
# used to build the cross compiler, we don't bother to run 'make check'.
if test x"${bootstrap}" = xtrue; then
    $CONFIG_SHELL ../cbuild2.sh --nodepends --parallel ${change} --build all
fi

# Now we build the cross compiler, for a native compiler this becomes
# the stage2 bootstrap build.
$CONFIG_SHELL ../cbuild2.sh --nodepends --parallel ${change} ${runtest} ${tarballs} --target ${target} --build all

# Canadian Crosses are a win32 hosted cross toolchain built on a Linux
# machine.
if test x"${canadian}" = xtrue; then
    distro="`lsb_release -sc`"
    # Ubuntu Lucid uses an older version of Mingw32
    if test x"${distro}" = x"lucid"; then
	$CONFIG_SHELL ../cbuild2.sh --nodepends --parallel ${change} ${tarballs} --host=i586-mingw32msvc --target ${target} --build all
    else
	$CONFIG_SHELL ../cbuild2.sh --nodepends --parallel ${change} ${tarballs} --host=i686-w64-mingw32 --target ${target} --build all
    fi
fi

ls -F $WORKSPACE/cbuildv2/snapshots
sums="`find $WORKSPACE -name \*.sum`"

# This will go away when make check produces something
if test x"${sums}" != x; then
    echo "Found test results finally!!!"
else
    echo "Bummer, no test results yet..."
fi

for i in ${sums}; do
    name="`echo $i | cut -d '.' -f 1`"
    ../sum2junit.sh $i
done
junits="`find -name *.junit`"
cat ${junits}
rm ${junits}
