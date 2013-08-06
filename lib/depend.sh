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
    if test x"${nodepends}" = xyes; then
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
	    installed $i
	    if test $? -gt 0; then
		notice "Need component ${latest}"
		components="${components} ${latest_version}"
	    fi
	done
	depends=""
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
	    if test -e ${local_builds}/bin/${installs} -o -e ${local_builds}/bin/${target}-${installs}; then
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
    #fetch_rsync infrastructure/md5sums
    #fetch_rsync infrastructure/ChangeLog

    source_config infrastructure

    if test x"${depends}" = x; then
	error "No dependencies listed for infrastructure libraries!"
	return 1
    fi
    
    # We have to grep each dependency separetly to preserve the order, as
    # some libraries depend on other libraries being bult first. Egrep
    # unfortunately sorts the files, which screws up the order.
    files=
    for i in ${depends}; do
     	files="${files} `grep /$i ${local_snapshots}/md5sums | cut -d ' ' -f3`"
    done
    
    # first fetch and extract all the tarballs listed in the md5sums file
    for i in ${files}; do
	fetch_http $i
	extract $i
    done

    for i in ${files}; do
	name="`echo $i | sed -e 's:\.tar\..*::' -e 's:infrastructure/::'`"
	build ${name}
    done
}

