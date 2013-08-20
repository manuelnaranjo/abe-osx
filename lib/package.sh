#!/bin/bash

# This script contains functions for building binary packages.
# $1 - the version to use, usually something like 2013.07-2
binary_tarball()
{
    if test x"$1" = x; then
	error "Need to supply a release version!!"
	return 1
    else
	if test `echo $1 | grep -c -- "linaro"` -eq 0; then
	    release="linaro-$1"
	else
	    release="$1"
	fi
    fi

    if test x"$2" = x; then
#	packages="toolchain sysroot"
	packages="toolchain"
    else
	packages="$2"
    fi

    for i in ${packages}; do
	case $i in
	    toolchain)
		binary_toolchain ${release}
		;;
	    sysroot)
		binary_sysroot ${release}
		;;
	    *)
		echo "unimplemented"
		;;
	esac
    done
}

# Produce a binary toolchain tarball
binary_toolchain()
{
    release="$1-${target}"

    destdir=/tmp/gcc-${release}

    # install in alternate directory so it's easier to build the tarball
    make_install gcc-$1 DESTDIR=${destdir}

    cd /tmp && tar Jcvf ${local_snapshots}/gcc-${release}.tar.xz gcc-${release}

    return 0
}

binary_sysroot()
{
    cd ${local_builds}/sysroots/${host} && tar Jcvf --exclude-vcs --exclude-backups ${local_snapshots}/sysroot-$1.tar.xz 

    return 0
}

build_deb()
{
    echo "unimplemented"
}

build_rpm()
{
    echo "unimplemented"
}
