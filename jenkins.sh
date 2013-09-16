#!/bin/bash

# Test the config parameters from the Jenkins Build Now page

# Get the versions of dependant components to use
changes=""
if test x"${gmp_snapshot}" != x"latest"; then
    change="${change} gmp=${gmp_snapshot}"
fi
if test x"${mpc_snapshot}" != x"latest"; then
    change="${change} mpc=${mpc_snapshot}"
fi
if test x"${mpfr_snapshot}" != x"latest"; then
    change="${change} mpfr=${mpfr_snapshot}"
fi
if test x"${gcc_snapshot}" != x"latest"; then
    change="${change} gcc=${gcc_snapshot}"
fi
if test x"${binutils_snapshot}" != x"latest"; then
    change="${change} binutils=${binutils_snapshot}"
fi
if test x"${linux_snapshot}" != x"latest"; then
    change="${change} linux-${linux_snapshot}"
fi

# Delete the previous build directory
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

# if build_type is true, then this is a cross build. For cross builds we build a
# native GCC, and then use that to compile the cross compiler to bootstrap.
if test x"${bootstrap}" = xtrue; then
    $CONFIG_SHELL ../cbuild2.sh --nodepends --parallel ${change} --disable bootstrap --build all
fi

$CONFIG_SHELL ../cbuild2.sh --nodepends --parallel ${change} ${runtest} --tarballs --target ${target} --build all

if test $? -eq 0; then
    if test x"${runtests}" = xtrue; then
	sums="`find -name \*.sum`"
	for i in ${sums}; do
	    name="`echo $i | cut -d '.' -f 1`"
	    ../sum2junit.sh $i ${name}.junit
	done
	cat *.junit
	rm *.junit
    fi
fi
