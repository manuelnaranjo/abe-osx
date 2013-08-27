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

# if test x"${runtests}" != x"latest"; then
# fi

# Create a build directory
mkdir -p _build
cd _build

# Delete all local config files, so any rebuilds use the currently
# committed versions.
rm -f localhost/${target}/*/*.conf

# Configure Cbuildv2 itself. Force the use of bash instead of the Ubuntu
# default of dash as some configure scripts go into an infinite loop with
# dash. Not good...
export CONFIG_SHELL="/bin/bash"
$CONFIG_SHELL ../configure --with-local-snapshots=$WORKSPACE/cbuildv2/snapshots

# Run Cbuildv2. We force all components to rebuild cleanly, and do parallel builds.
# if test x"${build_type}" = x"true"; then
#     $CONFIG_SHELL ../cbuild2.sh --force --parallel ${change} --target ${target} --build all
# else
#     $CONFIG_SHELL ../cbuild2.sh --force --parallel ${change} --build all
# fi

# If 'ALL' is selected as the target, build all cross compilers
if test x"${target}" = x"all"; then
    arches="arm-none-linux-gnueabihf arm-none-linux-gnueabi armeb-none-linux-gnueabihf aarch64-none-linux-gnu aarch64_be-none-linux-gnu aarch64-none-elf aarch64_be-none-elf"
else
    arches="${target}"
fi

for i in ${arches}; do
    $CONFIG_SHELL ../cbuild2.sh --force --parallel ${change} --target $i --build all
done
