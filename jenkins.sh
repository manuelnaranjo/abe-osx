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

# # Get the build machine architecture
# case ${build_machine} in 
#     toolchain_cloud)
# 	;;
#     all_native)
# 	;;
#     all_cross)
# 	;;
#     a9-builder)
# 	;;
#     a9-daily)
# 	;;
#     a9-ref)
# 	;;
#     a9hf-builder)
# 	;;
#     a9hf-daily)
# 	;;
#     a9hf-ref)
# 	;;
#     armv5-builder)
# 	;;
#     armv6-ref)
# 	;;
#     i686)
# 	;;
#     i686-lucid)
# 	;;
#     lava-calxeda)
# 	;;
#     lava-panda-mock)
# 	;;
#     lava-panda-usbdrive)
# 	;;
#     lava-pandaes)
# 	;;
#     x86_64)
# 	;;
#     xaarch64)
# 	;;
#     xaarch64_bare)
# 	;;
#     xcortexa15hf)
# 	;;
#     *)
# 	;;
#  esac

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
$CONFIG_SHELL ../cbuild2.sh --force --parallel ${change} --target ${target} --build all

