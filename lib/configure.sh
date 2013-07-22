#!/bin/sh

# Configure a source directory
# $1 - the directory to configure
# $2 - Other configure options
configure_build()
{
    # If a target architecture isn't specified, then it's a native build
    if test x"${target}" = x; then
	target=${build}
	host=${build}
    fi

    builddir=`get_builddir $1`    
    dir="`normalize_path $1`"
    if test `echo $1 | grep -c trunk` -gt 0; then
	srcdir="${local_snapshots}/${dir}/trunk"
    else
	srcdir="${local_snapshots}/${dir}"
    fi

    if test ! -d ${builddir}; then
	notice "${builddir} doesn't exist, so creating it"
	mkdir -p ${builddir}
    fi

    # not all packages commit their configure script, so if it has autogen,
    # then run that to create the configure script.
    if test ! -f ${srcdir}/configure; then
	warning "No configure script in ${srcdir}!"
	if test -f ${srcdir}/autogen.sh; then
	    (cd ${srcdir} && ./autogen.sh)
	fi
	return 0
    fi

    # Extract the toolchain component name, stripping off the linaro
    # part if it exists as it's not used for the config file name.
    tool="`get_toolname $1 | sed -e 's:-linaro::'`"

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
 
    if test x"${tool}" = x"gcc"; then
	opts="${opts} --build=${build} --host=${build} --target=${target} ${opts} --disable-shared --enable-static"
    else
	if test x"${tool}" != x"glibc"; then
	    opts="${opts} --build=${build} --host=${target} ${opts}"
	fi
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

