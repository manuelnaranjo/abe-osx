#!/bin/bash

# This script contains functions for building binary packages.

build_deb()
{
    echo "unimplemented"
}

build_rpm()
{
    echo "unimplemented"
}


# Build a binary tarball
# $1 - the version to use, usually something like 2013.07-2
source_tarball()
{
    if test x"$1" = x; then
	error "Need to supply a release version!!"
	return 1
    else
	release="$1"
    fi


    
}

# Build a binary tarball
# $1 - the version to use, usually something like 2013.07-2
binary_tarball()
{
    packages="sysroot toolchain"
    
    for i in ${packages}; do
	case $i in
	    toolchain)
		binary_toolchain ${release}
		;;
	    sysroot)
		binary_sysroot ${release}
		;;
	    *)
		echo "$i package building unimplemented"
		;;
	esac
    done
}

# Produce a binary toolchain tarball
binary_toolchain()
{
    # See if specific component versions were specified at runtime
    if test x"${gcc_version}" = x; then
#	gcc_version="gcc-linaro-`${target}-gcc -v 2>&1 | grep "gcc version " | cut -d ' ' -f 3 | cut -d '.' -f 1-2`-$1"
	gcc_version="gcc-`grep ^latest= ${topdir}/config/gcc.conf | cut -d '\"' -f 2`"
    fi

    builddir="`get_builddir ${gcc_version}`"

    tag="${gcc_version}-${target}-${host}"
    destdir=/tmp/linaro/${tag}
    mkdir -p ${destdir}/bin
    mkdir -p ${destdir}/share
    mkdir -p ${destdir}/lib/gcc
    mkdir -p ${destdir}/libexec/gcc

    # Get the binaries
    cp -r ${local_builds}/destdir/${host}/bin/${target}-* ${destdir}/bin/
    cp -r ${local_builds}/destdir/${host}/${target} ${destdir}/
    cp -r ${local_builds}/destdir/${host}/lib/gcc/${target} ${destdir}/lib/gcc/
    cp -r ${local_builds}/destdir/${host}/libexec/gcc/${target} ${destdir}/libexec/gcc/

    if test -e /tmp/manifest.txt; then
	cp /tmp/manifest.txt ${destdir}
    fi

    # install in alternate directory so it's easier to build the tarball
    dryrun "make install SHELL=${bash_shell} ${make_flags} DESTDIR=${destdir} -w -C ${builddir}"

    # make the tarball from the tree we just created.
    dryrun "cd /tmp/linaro && tar Jcvf ${local_snapshots}/${tag}.tar.xz ${tag}"

    return 0
}

binary_sysroot()
{
    if test x"${clibrary}" = x"newlib"; then
	if test x"${newlb_version}" = x; then
	    libc_version="newlib-`grep ^latest= ${topdir}/config/newlib.conf | cut -d '\"' -f 2`"
	else
	    libc_version="newlib-${newlib_version}"
	fi
    else
	if test x"${newlb_version}" = x; then
	    libc_version="eglibc-`grep ^latest= ${topdir}/config/eglibc.conf | cut -d '\"' -f 2`"
	else
	    libc_version="eglibc-${eglibc_version}"
	fi
    fi
    tag="sysroot-${libc_version}-${target}"

    cp -fr ${local_builds}/sysroots/${target} /tmp/${tag}

    dryrun "cd /tmp && tar Jcvf ${local_snapshots}/${tag}.tar.xz ${tag}"

    return 0
}

# Create a manifest file that lists all the versions of the other components
# used for this build.
manifest()
{
    if test x"$1" = x; then
	dest=/tmp
    else
	dest="`get_builddir $1`"
    fi

    if test x"${gcc_version}" = x; then
	gcc_version="`grep ^latest= ${topdir}/config/gcc.conf | cut -d '\"' -f 2`"
    fi
    
    if test x"${gmp_version}" = x; then
	gmp_version="`grep ^latest= ${topdir}/config/gmp.conf | cut -d '\"' -f 2`"
    fi
    
    if test x"${mpc_version}" = x; then
	mpc_version="`grep ^latest= ${topdir}/config/mpc.conf | cut -d '\"' -f 2`"
    fi
    
    if test x"${mpfr_version}" = x; then
	mpfr_version="`grep ^latest= ${topdir}/config/mpfr.conf | cut -d '\"' -f 2`"
    fi
    
    if test x"${binutils_version}" = x; then
	binutils_version="`grep ^latest= ${topdir}/config/binutils.conf | cut -d '\"' -f 2`"
    fi

    if test x"${eglibc_version}" = x; then
	eglibc_version="`grep ^latest= ${topdir}/config/eglibc.conf | cut -d '\"' -f 2`"
    fi
        
    if test x"${newlib_version}" = x; then
	newlib_version="`grep ^latest= ${topdir}/config/newlib.conf | cut -d '\"' -f 2`"
    fi
        
    if test x"${glibc_version}" = x; then
	glibc_version="`grep ^latest= ${topdir}/config/glibc.conf | cut -d '\"' -f 2`"
    fi        

    outfile=${dest}/manifest.txt
    cat <<EOF > ${outfile}
gmp_version=${gmp_version}
mpc_version=${mpc_version}
mpfr_version=${mpfr_version}
gcc_version=${gcc_version}
binutils_version=${binutils_version}
EOF
    
    if test x"${clibrary}" = x; then
	echo "eglibc_version=${eglibc_version}" >> ${outfile}
    else
	case ${clibrary} in
	    eglibc)
		echo "eglibc_version=${eglibc_version}" >> ${outfile}
		;;
	    glibc)
		echo "glibc_version=${glibc_version}" >> ${outfile}
		;;
	    newlib)
		echo "newlib_version=${newlib_version}" >> ${outfile}
		;;
	    *)
		echo "eglibc_version=${eglibc_version}" >> ${outfile}
		;;
	esac
    fi
}

