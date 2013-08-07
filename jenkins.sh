#!/bin/bash

# Test the config parameters from the Jenkins Build Now page
changes=""
if test x"${gmp_snapshot}" != x"latest"; then
    change="${change} ${gmp_snapshot}"
fi

if test x"${mpc_snapshot}" != x"latest"; then
    change="${change} ${mpc_snapshot}"
fi
if test x"${mpfr_snapshot}" != x"latest"; then
    change="${change} ${mpfr_snapshot}"
fi
if test x"${gcc_snapshot}" != x"latest"; then
    change="${change} ${gcc_snapshot}"
fi
if test x"${binutils_snapshot}" != x"latest"; then
    change="${change} ${binutils_snapshot}"
fi
if test x"${linux_snapshot}" != x"latest"; then
    change="${change} ${liux_snapshot}"
fi
# if test x"${runtests}" != x"latest"; then
# fi

mkdir -p _build
echo "Current working top level directory: $PWD"
cd _build
rm -f localhost/${target}/*/*.conf
../configure --with-local-snapshots=$WORKSPACE/cbuildv2/snapshots
export CONFIG_SHELL="/bin/bash"
$CONFIG_SHELL ../cbuild2.sh --force --parallel ${change} --target $target --build all
