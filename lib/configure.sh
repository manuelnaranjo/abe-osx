#!/bin/sh
# 
#   Copyright (C) 2013, 2014 Linaro, Inc
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
# 

# Configure a source directory
# $1 - the directory to configure
# $2 - [OPTIONAL] which gcc stage to build 
configure_build()
{
    trace "$*"

    flock --wait 100 ${local_builds}/git$$.lock --command echo
    if test $? -gt 0; then
	error "Timed out waiting for a git checkout to complete."
	return 1
    fi
    local gitinfo="`get_source $1`"

    local tool="`get_toolname ${gitinfo}`"

    # Linux isn't a build project, we only need the headers via the existing
    # Makefile, so there is nothing to configure.
    if test x"${tool}" = x"linux"; then
	return 0
    fi
    # The git parser functions shall return valid results for all
    # services, especially once we have a URL.

    local url="`get_git_url ${gitinfo}`" || return 1
    local tag="`get_git_tag ${gitinfo}`" || return 1
    local srcdir="`get_srcdir ${gitinfo} ${2:+$2}`"
    local stamp="`get_stamp_name configure ${gitinfo} ${2:+$2}`"
    local builddir="`get_builddir ${gitinfo} ${2:+$2}`"

    # Don't look for the stamp in the builddir because it's in builddir's
    # parent directory.
    local stampdir="`dirname ${builddir}`"

    local ret=
    check_stamp "${stampdir}" ${stamp} ${srcdir} configure ${force}
    ret=$?
    if test $ret -eq 0; then
	return 0 
    elif test $ret -eq 255; then
	# This means that the compare file ${srcdir} is not present.
	return 1
    fi

    if test ! -d "${builddir}"; then
	notice "The build directory '${builddir}' doesn't exist, so creating it"
	# Zlib has to be built in it's source directory.
#	if test x"${tool}" = x"zlib"; then
#	    dryrun "ln -s ${srcdir} ${builddir}"
#	else
	    dryrun "mkdir -p \"${builddir}\""
#	fi
    fi

    # Since Binutils and GDB have a shared git repository, this confuses the logic
    # of loading the right config file. If Binutils is already configured, then 
    # assume GDB.
    if test x"${2}" = x"gdb" -o x"${2}" = x"binutils"; then
	local tool="${2}"
    fi
    
    local configure="`grep ^configure= ${topdir}/config/${tool}.conf | cut -d '\"' -f 2`"
    if test x"${configure}" = x; then
      configure="yes"
    fi
    if test ! -f "${srcdir}/configure" -a x"${dryrun}" != x"yes" -a x"${configure}" != xno; then
	warning "No configure script in ${srcdir}!"
        # not all packages commit their configure script, so if it has autogen,
        # then run that to create the configure script.
	if test -f ${srcdir}/autogen.sh; then
	    (cd ${srcdir} && ./autogen.sh)
	fi
	if test ! -f "${srcdir}/configure"; then
	    error "No configure script in ${srcdir}!"
	    return 1
	fi
    fi

    # If a target architecture isn't specified, then it's a native build
#    if test x"${target}" = x; then
#	target=${build}
#	host=${build}
#    else
	# FIXME: this won't work yet when doing a Canadian Cross.
#	host=${build}
#    fi

    # Load the default config file for this component if it exists.
    local default_configure_flags=""
    local stage1_flags=""
    local stage2_flags=""
    local opts=""
    if test x"$2" = x"gdbserver"; then
	local toolname="gdbserver"
    else
	local toolname="${tool}"
    fi
    if test -e "${topdir}/config/${toolname}.conf"; then
	. "${topdir}/config/${toolname}.conf"
	# if there is a local config file in the build directory, allow
	# it to override the default settings
	# unset these two variables to avoid problems later
	if test -e "${builddir}/${toolname}.conf" -a ${builddir}/${toolname}.conf -nt ${topdir}/config/${toolname}.conf; then
	    . "${builddir}/${toolname}.conf"
	    notice "Local ${toolname}.conf overriding defaults"
	else
	    # Since there is no local config file, make one using the
	    # default, and then add the target architecture so it doesn't
	    # have to be supplied for future reconfigures.
	    echo "target=${target}" > ${builddir}/${toolname}.conf
	    cat ${topdir}/config/${toolname}.conf >> ${builddir}/${toolname}.conf
	fi
    else
	error "No ${topdir}/config/${tool}.conf file for ${tool}."
	exit 1
    fi
  
    local this_extraconfig="${extraconfig[${toolname}]}"
    if test -n "${this_extraconfig}"; then
	if test -e "${this_extraconfig}"; then
	    notice "Sourcing extra config: ${this_extraconfig}"
	    . "${this_extraconfig}"
	else
	    error "Warning: extraconfig file does not exist: ${this_extraconfig}"
	    exit 1
	fi
    fi

    # See if this component depends on other components. They then need to be
    # built first.
    if test x"${depends}"; then
	for i in "${depends}"; do
	    # remove the current build component from the command line arguments
	    # so we can replace it with the dependent component name.
	    local args="`echo ${command_line_arguments} | sed -e 's@$1@@'`"
	done
    fi


    # Force static linking unless dynamic linking is specified
    local static="`grep ^static_link= ${topdir}/config/${tool}.conf | cut -d '=' -f 2 | tr  -d '\"'`"
    if test x"${static}" = x"yes"; then
	if test "`echo ${tool} | grep -c glibc`" -eq 0; then
	    local opts="--disable-shared --enable-static"
	fi
    fi

    # prefix is the root everything gets installed under.
    if test x"${prefix}" = x; then
	local prefix="${local_builds}/destdir/${host}"
    fi

    # The release string is usually the date as well, but in YYYY.MM format.
    # For snapshots we add the day field as well.
    if test x"${release}" = x; then
	local date="`date "+%Y.%m"`"
    else
	local date="${release}"
    fi

    if test x"${override_cflags}" != x -a x"${tool}" != x"eglibc"; then
	local opts="${opts} CFLAGS=\"${override_cflags}\" CXXFLAGS=\"${override_cflags}\""
    fi

    # GCC and the binutils are the only toolchain components that need the
    # --target option set, as they generate code for the target, not the host.
    case ${tool} in
	# zlib)
	#     # zlib doesn't support most standard configure options
	#     local opts="--prefix=${sysroots}/usr"
	#     ;;
	newlib*|libgloss*)
	    local opts="${opts} --build=${build} --host=${target} --target=${target} --prefix=${sysroots}/usr CC=${target}-gcc"
	    ;;
	*libc)
	    # [e]glibc uses slibdir and rtlddir for some of the libraries and
	    # defaults to lib64/ for aarch64.  We need to override this.
	    # There's no need to install anything into lib64/ since we don't
	    # have biarch systems.

	    # libdir is where static libraries and linker scripts are installed,
	    # like libc.so, libc_nonshared.a, and libc.a.
	    echo libdir=/usr/lib > ${builddir}/configparms

	    # slibdir is where shared objects are installed.
	    echo slibdir=/lib >> ${builddir}/configparms

	    # rtlddir is where the dynamic-linker is installed.
	    echo rtlddir=/lib >> ${builddir}/configparms
	    local opts="${opts} --build=${build} --host=${target} --target=${target} --prefix=/usr"
	    dryrun "(mkdir -p ${sysroots}/usr/lib)"
	    ;;
	gcc*)
	    # Force a complete reconfigure, as we changed the flags. We could do a
	    # make distclean, but this builds faster, as not all files have to be
	    # recompiled.
#	    find ${builddir} -name Makefile -o -name config.status -o -name config.cache -exec rm {} \;
#	    if test -e ${builddir}/Makefile; then
#		make ${make_flags} -C ${builddir} distclean -i -k
#	    fi
	    if test x"${build}" != x"${target}"; then
		if test x"$2" != x; then
		    case $2 in
			stage1*)
			    notice "Building stage 1 of GCC"
			    local opts="${opts} ${stage1_flags}"
			    ;;
			stage2*)
			    notice "Building stage 2 of GCC"
			    local opts="${opts} ${stage2_flags}"
			    # Only add the Linaro bug and version strings for
			    # Linaro branches.
			    if test "`echo ${gcc_version} | grep -ic linaro`" -gt 0; then
				local opts="${opts} --with-bugurl=\"https://bugs.linaro.org\""
			    fi
			    ;;
			gdbserver)
			    notice "Building gdbserver for the target"
			    local srcdir="${srcdir}/gdbserver"
			    ;;
			bootstrap*)
			    notice "Building bootstrapped GCC"
			    local opts="${opts} --enable-bootstrap"
			    ;;
			*)
			    if test -e ${sysroots}/usr/include/stdio.h; then
				notice "Building with stage 2 flags, sysroot found!"
				local opts="${opts} ${stage2_flags}"
			    else
				warning "Building with stage 1 flags, no sysroot found"
				local opts="${opts} ${stage1_flags}"
			    fi
			    ;;
		    esac
		else
		    if test -e ${sysroots}/usr/include/stdio.h; then
			notice "Building with stage 2 flags, sysroot found!"
			local opts="${opts} ${stage2_flags}"
		    else
			warning "Building with stage 1 flags, no sysroot found"
			local opts="${opts} ${stage1_flags}"
		    fi
		fi
	    else
		local opts="${opts} ${stage2_flags}"
	    fi
	    local version="`echo $1 | sed -e 's#[a-zA-Z\+/:@.]*-##' -e 's:\.tar.*::'`"
	    local opts="${opts} --build=${build} --host=${host} --target=${target} --prefix=${prefix}"
	    ;;
	binutils)
	    if test x"${override_linker}" = x"gold"; then
		local opts="${opts} --enable-gold=default"
	    fi
	    local opts="${opts} --build=${build} --host=${host} --target=${target} --prefix=${prefix}"
	    ;;
	gdb*)
 	    local opts="${opts} --with-bugurl=\"https://bugs.launchpad.net/gcc-linaro\" --with-pkgversion=\"Linaro GDB ${date}\""
	    if test x"$2" = x"gdbserver"; then
		local opts="${opts} --build=${build} --host=${target} --prefix=${prefix}"
		local srcdir="${srcdir}/gdb/gdbserver"
	    else
		local opts="${opts} --build=${build} --host=${host} --target=${target} --prefix=${prefix}"
	    fi
	    dryrun "mkdir -p ${builddir}"
	    ;;
	# These are only built for the host
	dejagnu|gmp|mpc|mpfr|isl|ppl|cloog|qt-everywhere-opensource-src|ffmpeg)
	    local opts="${opts} --build=${build} --host=${host} --prefix=${prefix}"
	    ;;
	*)
	    local opts="${opts} --build=${build} --host=${host} --target=${target} --prefix=${sysroots}/usr"
	    ;;
    esac

    if test -e ${builddir}/config.status -a x"${tool}" != x"gcc" -a x"${force}" = xno; then
	warning "${buildir} already configured!"
    else
	export PATH="${local_builds}/${host}/bin:$PATH"
	# Don't stop on CONFIG_SHELL if it's set in the environment.
	if test x"${CONFIG_SHELL}" = x; then
	    export CONFIG_SHELL=${bash_shell}
	fi
       # In release mode, use default pkgversion for GCC.
#	if test x"${release}" != x;then
#            case ${tool} in
#		gcc*)
#                    default_configure_flags=`echo "${default_configure_flags}" | sed -e 's/--with-pkgversion=.* //'`
#                    ;;
#            esac
#	fi

	# zlib can only be configured in the source tree, and doesn't like any of the
	# stadard GNU configure options
#	if test x"${tool}" = x"zlib"; then
#	    dryrun "(cd ${builddir} && ${CONFIG_SHELL} ./configure --prefix=${prefix})"
#	else
        if test x"${configure}" = xyes; then
	    dryrun "(cd ${builddir} && ${CONFIG_SHELL} ${srcdir}/configure SHELL=${bash_shell} ${default_configure_flags} ${opts})"
	    if test $? -gt 0; then
	        error "Configure of $1 failed."
	        return $?
	    fi
        else
            dryrun "rsync -a --exclude=.git/ ${srcdir}/ ${builddir}"
	    if test $? -gt 0; then
	        error "Copy of $1 failed (rsync -a ${srcdir} ${builddir})"
	        return $?
	    fi
        fi
#       fi

	# unset this to avoid problems later
	unset default_configure_flags
	unset opts
	unset stage1_flags
	unset stage2_flags
    fi

    notice "Done configuring ${gitinfo}"

    #touch ${stampdir}/${stamp}
    create_stamp "${stampdir}" "${stamp}"

    return 0
}

