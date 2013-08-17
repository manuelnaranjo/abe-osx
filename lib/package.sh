#!/bin/bash

# This script contains functions for building binary packages.
binary_tarball()
{
    if test x"$1" = x; then
	error "Need to supply a release version!!"
    fi

    if test x"$2" = x; then
	packages="toolchain sysroot"
    else
	packages="$2"
    fi

    for i in ${packages}; do
	case $i in
	    toolchain)
		tar Jcvf --exclude sysroots --directory ${local_snapshots} gcc-$1.tar.xz ${local_builds}/${host}
		;;
	    sysroot)
		tar Jcvf --directory ${local_snapshots} sysroot-$1.tar.xz ${local_builds}/sysroots/${target}
		;;
	    *)
		echo "unimplemented"
		;;
	esac
    done
}

build_deb()
{
    echo "unimplemented"
}

build_rpm()
{
    echo "unimplemented"
}
