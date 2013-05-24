#!/bin/sh

# Configure a source directory
configure()
{
    # If a target architecture isn't specified, then it's a native build
    if test x"${target}" = x; then
	target=${build}
    fi
    builddir="${hostname}/${target}/$1"
    if test ! -d ${builddir}; then
	notice "${builddir} doesn't exist, so creating it"
	mkdir -p ${builddir}
    fi
    srcdir="${local_snapshots}/$1"
    if test ! -f ${srcdir}/configure; then
	error "No configure script in ${srcdir}!"
	return 1
    fi
    opts=""

    tool="`echo $1 | sed -e 's:-[0-9].*::'`"
    case ${tool} in
	cortex-strings)
	    tool=cortex
	    ;;
	eglibc)
	    tool=eglibc
	    ;;
	eglibc-ports)
	    tool=eglibc
	    ;;
	binutils)
	    tool=binutils
	    ;;
	newlib)
	    tool=newlib
	    ;;
	gdb-linaro)
	    tool=gdb
	    ;;
	gdb)
	    tool=gdb
	    ;;
	gcc)
	    tool=gcc
	    ;;
	gcc-linaro)
	    tool=gcc
	    ;;
	qemu)
	    tool=qemu
	    ;;
	qemu-linaro)
	    tool=qemu
	    ;;
	meta-linaro)
	    tool=meta
	    ;;
	libffi)
	    tool=libffi
	    ;;
	*)
	    tool=gcc
	    ;;
    esac

    # Load the default config file for this component if it exists.
    if test -e "$(dirname "$0")/config/${tool}.conf"; then
	. "$(dirname "$0")/config/${tool}.conf"
	# if there is a local config file in the build directory, allow
	# it to override the default settings
	if test -e "${builddir}/${tool}.conf"; then
	    . "${builddir}/${tool}.conf"
	    notice "Local ${tool}.conf overiding defaults"
	else
	    # Since there is no local config file, make one using the
	    # default, and then add the target architecture so it doesn't
	    # have to be supplied for future reconfigures.
	    echo "target=${target}" > ${builddir}/${tool}.conf
	    cat $(dirname "$0")/config/${tool}.conf >> ${builddir}/${tool}.conf
	fi
    fi

    # See if this component depends on other components. They then need to be
    # built first.
    if test x"${depends}"; then
	for i in "${depends}"; do
	    # remove the current build component from the command line arguments
	    # so we can replace it with the dependent component name.
	    args="`echo ${command_line_arguments} | sed -e "s/$1//"`"
	    echo "FIXME: $0 ${args} $i"
	done
    fi

    # when configuring a cross compiler, add these flags
    if test x"${build}" != x"${target}"; then
	opts="--build=${build} --host=${build} --target=${target}"
    fi
    (cd ${builddir} && ${srcdir}/configure ${default_configure_flags} ${opts})
}

