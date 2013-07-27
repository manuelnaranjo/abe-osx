#!/bin/sh

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
    # Don't process any dependencies in the conf file.
    if test x"${nodepends}" = xno; then
	warning "Dependencies for $1 disabled!"
	return 0
    fi

    if test x"${depends}"  = x; then
	tool=`get_toolname $1`
	source_config ${tool}
    fi

    if test x"${depends}"  != x; then
	for i in ${depends}; do
	    latest_version="`grep ^latest= ${topdir}/config/$i.conf | cut -d '\"' -f 2`"

	    #  didn't find component
	    if test $? -gt 1; then
		warning "Couldn't find $1"
	    else
		notice "Need component ${latest_version}"
		components="${components} ${latest_version}"
	    fi
	done
	return $?
    fi
    
    notice "${components}"
    return 1
}

# $1 - the toolchain component to see if it's already installed
installed()
{
    tool=`get_toolname $1`
    source_config ${tool}

    if test x"${installs}" != x; then
	# It the installed file is a library, then we have to look for both
	# static and shared versions.
	if test "`echo ${installs} | grep -c '^lib'`" -gt 0; then
	    if test -e ${local_builds}/lib/${installs}so -o -e ${local_builds}/lib/${installs}a; then
		notice "${tool} already installed"
		return 0
	    fi
	else
	    if test -e ${local_builds}/bin/${installs}; then
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
# --disable-* options at configure time to GCC, these are use for
# good reason, so we download, build and install them.
infrastructure()
{
    fetch_http infrastructure/md5sums
    fetch_http infrastructure/ChangeLog

    # Get the list of files from the md5sums list
    files="`cat ${local_snapshots}/infrastructure/md5sums | cut -d ' ' -f 3`"
    if test -e "${topdir}/config/infrastructure.conf"; then
	. "${topdir}/config/infrastructure.conf"
    fi

    if test x"${depends}" = x; then
	error "No dependencies listed for infrastructure libraries!"
	return 1
    fi
    
    # We have to grep each dependency separetly to preserve the order, as
    # some libraries depend on other libraries being bult first. Egrep
    # unfortunately sorts the files, which screws up the order.
    files=
    for i in ${depends}; do
     	files="${files} `grep $i ${local_snapshots}/infrastructure/md5sums | cut -d ' ' -f3`"
    done
    
    # first fetch and extract all the tarballs listed in the md5sums file
    for i in ${files}; do
	fetch_http infrastructure/$i
	extract infrastructure/$i
    done

    for i in ${files}; do
	name="`echo $i | sed -e 's:\.tar\..*::'`"
	# get any configure flags specific to this program, which are
	# usually dependant libaries we've already built.
	tool="`echo $i | sed -e 's:-[0-9].*::'`"
	if test -e "${topdir}/config/${tool}.conf"; then
	    . "${topdir}/config/${tool}.conf"
	fi
	notice "Configuring infrastructure/${name}..."
	configure_build infrastructure/${name} --disable-shared --enable-static --prefix=${PWD}/${hostname}/${build}/depends ${default_configure_flags}
	if test $? != "0"; then
	    warning "Configure of ${name} failed!"
	fi
	# unset these two variables to avoid problems later
	default_configure_flags=
	make_all infrastructure/${name}
	if test $? = "0"; then
	    make_install infrastructure/${name}
	    if test $? != "0"; then
		warning "Make install of ${name} failed!"
	    fi
	fi
    done
}

