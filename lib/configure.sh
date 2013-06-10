#!/bin/sh

# Configure a source directory
# $1 - the directory to configure
# $2 - Other configure options
configure_build()
{
    # If a target architecture isn't specified, then it's a native build
    if test x"${target}" = x; then
	target=${build}
    fi
    node="`normalize_path $1`"
    if test `echo ${node} | grep -c eglibc` -gt 0; then
	builddir="${cbuild_top}/${hostname}/${target}/${node}"
	srcdir="${local_snapshots}/${node}/libc"
    else
	builddir="${cbuild_top}/${hostname}/${target}/${node}"
	srcdir="${local_snapshots}/${node}"
    fi
    tool="`echo $1 | sed -e 's:-[0-9].*::'`"
    tool="`basename ${tool}`"

    if test ! -d ${builddir}; then
	notice "${builddir} doesn't exist, so creating it"
	mkdir -p ${builddir}
    fi

    if test ! -f ${srcdir}/configure; then
	warning "No configure script in ${srcdir}!"
	return 0
    fi

    case ${tool} in
	cortex-strings*)
	    tool=cortex
	    ;;
	eglibc*)
	    tool=eglibc
	    ;;
	eglibc-ports)
	    tool=eglibc
	    ;;
	binutils*)
	    tool=binutils
	    ;;
	newlib*)
	    tool=newlib
	    ;;
	gdb-linaro*)
	    tool=gdb
	    ;;
	gdb*)
	    tool=gdb
	    ;;
	gcc*)
	    tool=gcc
	    ;;
	gcc-linaro*)
	    tool=gcc
	    ;;
	qemu*)
	    tool=qemu
	    ;;
	qemu-linaro*)
	    tool=qemu
	    ;;
	meta-linaro*)
	    tool=meta
	    ;;
	libffi*)
	    tool=libffi
	    ;;
	gmp*)
	    tool=gmp
	    ;;
	isl*)
	    tool=isl
	    ;;
	ppl*)
	    tool=ppl
	    ;;
	cloog*)
	    tool=cloog
	    ;;
	mpfr*)
	    tool=mpfr
	    ;;
	mpc*)
	    tool=mpc
	    ;;
	*)
	    warning "Coudn't parse the toolchain component!"
	    ;;
    esac

    # Load the default config file for this component if it exists.
    if test -e "$(dirname "$0")/config/${tool}.conf"; then
	default_configure_flags=
	. "$(dirname "$0")/config/${tool}.conf"
	# if there is a local config file in the build directory, allow
	# it to override the default settings
	# unset these two variables to avoid problems later
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
	    args="`echo ${command_line_arguments} | sed -e 's@$1@@'`"
	done
    fi

    opts="--prefix=${PWD}/${hostname}/${build}/depends"
    if test $# -gt 1; then
	opts="${opts} `echo $* | cut -d ' ' -f2-10`"
    fi
 
    if test x"${tool}" != x"qemu"; then
	opts="${opts} --build=${build} --host=${build} --target=${target} ${opts} --disable-shared --enable-static"
    fi
    if test -e ${builddir}/Makefile; then
	warning "${buildir} already configured!"
    else
	export CONFIG_SHELL=${bash_shell}
	(cd ${builddir} && ${bash_shell} ${srcdir}/configure ${default_configure_flags} ${opts})
	return $?
	# unset this to avoid problems later
	default_configure_flags=
    fi

    return 0
}

