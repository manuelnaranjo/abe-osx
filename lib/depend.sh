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

# $1 - the toolchain component to see if it's already been compiled
built()
{
    trace "$*"

    local tool=`get_toolname $1`
    local latest="`grep ^latest= ${topdir}/config/${tool}.conf | cut -d '\"' -f 2`"
    local builddir="`get_builddir $1`-${latest}"

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
    trace "$*"

    rm -f ${local_snapshots}/infrastructure/ChangeLog
    fetch_http infrastructure/ChangeLog

    source_config infrastructure

    if test x"${depends}" = x; then
	error "No dependencies listed for infrastructure libraries!"
	return 1
    fi

    # This shouldn't happen, but it's nice for regression verification.
    if test ! -e ${local_snapshots}/md5sums; then
	error "Missing ${local_snapshots}/md5sums file needed for infrastructure libraries."
	return 1
    fi
   
    # We have to grep each dependency separately to preserve the order, as
    # some libraries depend on other libraries being bult first. Egrep
    # unfortunately sorts the files, which screws up the order.
    local files="`grep ^latest= ${topdir}/config/dejagnu.conf | cut -d '\"' -f 2`"
    for i in ${depends}; do
     	files="${files} `grep /$i ${local_snapshots}/md5sums | cut -d ' ' -f3 | uniq`"
    done

    # First fetch and extract all the tarballs listed in the md5sums file
#    for i in ${files}; do
#	if test "`echo $i | grep -c /linux`" -eq 1 -a x"${build}" = x"${target}"; then
#	    continue
#	fi
#	fetch_http $i
#	extract $i
#    done

    # Store the current value so we can reset it ater we're done.
    local nodep=${nodepends}

    # Turn off dependency checking, as everything is handled here.
    nodepends=yes
    for i in ${files}; do
	local name="`echo $i | sed -e 's:\.tar\..*::' -e 's:infrastructure/::'  -e 's:testcode/::'`"
	if test "`echo $i | grep -c /linux`" -eq 1 -a x"${build}" = x"${target}"; then
	    continue
	fi
	build ${name}
    done

    # Reset to the stored value
    nodepends=${nodep}
}

