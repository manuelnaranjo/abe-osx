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

#
# Build the dependencies needed to build the toolchain
#

# This takes a toolchain component and returns the fuly qualified package names to
# this toolchain component requires to configure and build. These other components
# are limited to packages built by Linaro.
#
# $1 - find the toolchain components to build to satisfiy necessary dependencies.
dependencies()
{
    trace "$*"

    # Don't process any dependencies in the conf file.
    if test x"${nodepends}" = xyes; then
	warning "Dependencies for $1 disabled!"
	return 0
    fi

    if test x"${depends}"  = x; then
	local tool=`get_toolname $1`
	local depends="`grep ^latest= ${topdir}/config/${tool}.conf | cut -d '\"' -f 2`"
	source_config ${tool}
    fi

    if test x"${depends}"  != x; then
	for i in ${depends}; do
	    local version=""
	    case $i in
		b*|binutils)
		    version="${binutils_version}"
		    ;;
		gm*|gmp)
		    version="${gmp_version}"
		    ;;
		gc*|gcc)
		    version="${gcc_version}"
		    ;;
		mpf*|mpfr)
		    version="${mpfr_version}"
		    ;;
		mpc)
		    version="${mpc_version}"
		    ;;
		eglibc)
		    version="${eglibc_version}"
		    ;;
		glibc)
		    version="${glibc_version}"
		    ;;
		n*|newlib)
		    version="${newlib_version}"
		    ;;
		*)
		    ;;
	    esac
	    if test x"${version}" = x; then
		version="`grep ^latest= ${topdir}/config/$i.conf | cut -d '\"' -f 2`"
	    fi
	    installed $i
	    if test $? -gt 0; then
		notice "Need component ${tool}-${version}"
		local components="${components} ${tool}-${version}"
	    fi
	done
	depends=""
	version=""
	return $?
    fi
    
    echo "${components}"
    return 1
}

# $1 - the toolchain component to see if it's already installed
installed()
{
    trace "$*"

    if test x"${tool}" = x; then
	local tool=`get_toolname $1`
    fi
    source_config ${tool}

    if test ! -d ${local_builds}/lib -a ! ${local_builds}/bin; then
	error "no existing installation in ${local_builds}!"
	return 1
    fi

    if test x"${installs}" != x; then
	# It the installed file is a library, then we have to look for both
	# static and shared versions.
	if test "`echo ${installs} | grep -c '^lib'`" -gt 0; then
	    if test -e ${local_builds}/lib/${installs}so -o -e ${local_builds}/lib/${installs}a; then
		notice "${tool} already installed"
		return 0
	    fi
	else
	    if test -e ${local_builds}/bin/${installs} -o -e ${local_builds}/bin/${target}-${installs} -o ${local_builds}/bin/${installs}.exe; then
		notice "${tool} already installed"
		return 0
	    else
		warning "${tool} not installed."
		return 1
	    fi
	fi
    else
	warning "No install dependency specified"
	return 1
    fi
    
    return 1
}

# These are the latest copies of the infrastructure files required to
# fully build GCC in all it's glory. While it is possible to pass
# --disable-* options at configure time to GCC, these are used for
# good reason, so we download, build and install them.
infrastructure()
{
    trace "$*"

    source_config infrastructure

    if test x"${depends}" = x; then
	error "No dependencies listed for infrastructure libraries!"
	return 1
    fi

    local files=
    local version=
    for i in ${depends}; do
	case $i in
	    linux) version=${linux_version} ;;
	    mpfr) version=${mpfr_version} ;;
	    mpc) version=${mpc_version} ;;
	    gmp) version=${gmp_version} ;;
	    dejagnu) version=${dejagnu_version} ;;
	    *)
		error "config/infrastructure.conf contains an unknown dependency: $i"
		return 1
		;;
	esac

	# If the user didn't set it, check the <component>.conf files for
	# 'latest'.
	if test "${version:+set}" != "set"; then
	    version="`grep ^latest= ${topdir}/config/${i}.conf | cut -d '\"' -f 2`"
	    version=${i}-${version#${i}-}
	fi

	if test "${version:+found}" != "found"; then
	    error "Can't find a version for component \"$i\" in ${i}.conf"
	    return 1
	fi

	# Hopefully we only return the exact match for each one.  Depending
	# how vague the user is it might match on multiple tarballs.
	files="${files} ${version}"
	collect_data ${version}

	unset version
    done

    # Store the current value so we can reset it after we're done.
    local nodep=${nodepends}

    # Turn off dependency checking, as everything is handled here.
    nodepends=yes
    local buildret=
    for i in ${files}; do
	# if make 4.0 is already installed, we don't need to build it everytime.
	if test $i = "make" -a "${makeversion}" = "4.0"; then
	    continue
	fi
	local component="`echo $i | sed -e 's:\.git.*::' -e 's:-[0-9a-z\.\-]*::'`"
	build $i
	buildret=$?
	if test ${buildret} -gt 0; then
	    error "Building ${name} failed."
	    return 1
	fi
    done

    # Reset to the stored value
    nodepends=${nodep}
}

