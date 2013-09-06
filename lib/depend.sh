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
	    version=""
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
		components="${components} ${tool}-${version}"
	    fi
	done
	depends=""
	version=""
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

# $1 - the toolchain component to see if it's already been compiled
built()
{
    tool=`get_toolname $1`
    latest="`grep ^latest= ${topdir}/config/${tool}.conf | cut -d '\"' -f 2`"
    builddir="`get_builddir $1`-${latest}"

    source_config ${tool}

    if test x"${installs}" != x; then
	# It the installed file is a library, then we have to look for both
	# static and shared versions.
	if test "`echo ${installs} | grep -c '^lib'`" -gt 0; then
	    if test -e ${builddir}/${installs}la; then
		notice "${tool} has already been built"
		return 0
	    fi
	else
	    if test -e ${builddir}/${installs}; then
		notice "${tool} has already been built"
		return 0
	    else
		warning "${tool} has not been built"
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
    rm -f ${local_snapshots}/infrastructure/md5sums
    fetch_http infrastructure/md5sums
    rm -f ${local_snapshots}/infrastructure/ChangeLog
    fetch_http infrastructure/ChangeLog

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
     	files="${files} `grep /$i ${local_snapshots}/md5sums ${local_snapshots}/*/md5sums| cut -d ' ' -f3`"
    done
    
    # first fetch and extract all the tarballs listed in the md5sums file
    for i in ${files}; do
	if test x"${build}" = x"${target}" -a `echo $i | grep -c /linux` -eq 0; then
	    fetch_http $i
	    extract $i
	fi
    done

    # Store the current value so we can reset it ater we're done.
    nodep=${nodepends}

    # Turn off dependency checking, as everything is handled here
    nodepends=yes
    for i in ${files}; do
	name="`echo $i | sed -e 's:\.tar\..*::' -e 's:infrastructure/::'  -e 's:testcode/::'`"
	if test x"${build}" = x"${target}" -a `echo $i | grep -c /linux` -eq 0; then
	    build ${name}
	fi
    done

    # Reset to the stored value
    nodepends=${nodep}
}

