#!/bin/sh

# load all the global varibles. By default we look in the path to find the
# library directory. If running the cbuild2.sh testsuite, we assume we're
# running in the top level source directory.
if test `dirname "$0"` != "testsuite"; then
    libdir=`dirname "$0"`
else
    libdir=.
fi
# source all the library functions
. "${libdir}/lib/globals.sh" || exit 1
. "${libdir}/lib/fetch.sh" || exit 1
. "${libdir}/lib/configure.sh" || exit 1
. "${libdir}/lib/release.sh" || exit 1
. "${libdir}/lib/checkout.sh" || exit 1
. "${libdir}/lib/depend.sh" || exit 1
. "${libdir}/lib/make.sh" || exit 1
. "${libdir}/lib/merge.sh" || exit 1

#
# All the set* functions set global variables used by the other functions.
# This way there can be some error recovery and handing.
#

set_build()
{
    echo "Set build architecture $1..."
    build="$1"
}

set_target()
{
    echo "Set target architecture $1..."
    target="$1"
}

set_snapshots()
{
    echo "Set snapshot URL $1..."
    snapshots="$1"
}

set_gcc()
{
    echo "Set gcc version $1..."
    gcc="$1"
}

set_binutils()
{
    echo "Set binutils version $1..."
    binutils="$1"
}

set_sysroot()
{
    echo "Set sysroot to $1..."
    sysroot="$1"
}

set_libc()
{
    echo "Set libc to $1..."
    libc="$1"
}

set_config()
{
    echo "Set config file to $1..."
    configfile="$1"
}

set_dbuser()
{
    echo "Setting MySQL user to $1..."
    dbuser="$1"
}

set_dbpasswd()
{
    echo "Setting MySQL password to $1..."
    dbpasswd="$1"
}

error()
{
    echo "ERROR: $1"
    return 1
}

warning()
{
    echo "WARNING: $1"
}

notice()
{
    echo "NOTE: $1"
}

# Get the URL to checkout out development sources.
# $1 - The toolchain component to get the source URL for, which must be
# unique in the source.conf file.
get_URL()
{
    srcs="`dirname "$0"`/config/sources.conf"
    if test -e ${srcs}; then
	if test "`grep -c "^$1" ${srcs}`" -gt 1; then
	    echo "ERROR: Need unique component and version to get URL!"
	    echo ""
	    echo "Choose one from this list"
	    list_URL $1
	    return 1
	fi
	out="`grep "^$1" ${srcs}`"
	out="`echo ${out} | cut -d ' ' -f 2`"
	echo ${out}
	return 0
    else
	error "No config file for sources! Choose one from this list"
	return 1
    fi

    return 0
}

# display a list of matching URLS we know about. This is how you can see the
# correct name to pass to get_URL().
#
# $1 - The name of the toolchain component, partial strings ok
list_URL()
{
    srcs="`dirname "$0"`/config/sources.conf"
    if test -e ${srcs}; then
	notice "Supported sources for $1 are:"
	cat ${srcs} | sed -e 's:\t.*::' -e 's: .*::' -e 's:^:\t:' | grep $1
	return 0
    else
	error "No config file for sources!"
	return 1
    fi

    return 0
}

# This takes a URL and turns it into a name suitable for the build
# directory name.
# $1 - the path to fixup
normalize_path()
{
    case $1 in
	lp*)
	    node="`echo $1 | sed -e 's@lp:@@' -e 's:/:_:'`"
	    ;;
	bzr*)
	    node="`echo $1 | sed -e 's:^.*branch/::'`"
	    node="`echo ${node} | sed -e 's:/:_:'`"
	    ;;
	git*)
	    node="`echo $1 | sed -e 's@^.*/git/@@'`"
	    node="`basename ${node}`"
	    ;;
	svn*)
	    node="`echo $1 | sed -e 's@^.*/svn/@@'`"
	    node="`basename ${node}`"
	    ;;
	http*)
	    node="`echo $1 | sed -e 's@^.*/http/@@'`"
	    node="`basename ${node}`"
	    if test x"${node}" = x"trunk"; then
		node="`echo $1 | sed -e 's:-[0-9].*::' -e 's:/trunk::' `"
		node="`basename ${node}`"
	    else
		node="`basename $1 | sed -e 's:\.tar.*::'`"
	    fi
	    ;;
	*)
	    node="`echo $1 | sed -e 's:\.tar\..*::'`"
	    ;;
    esac

    echo ${node}
    return 0
}

# Extract the build directory from the URL of the source tree as it
# varies depending on which source code control system is used.
#
# $1 - The full URL to the source tree as returned by get_URL()
get_builddir()
{
    dir="`normalize_path $1`"
    if test `echo $1 | grep -c eglibc` -gt 0; then
	dir="${cbuild_top}/${hostname}/${target}/${dir}"
    else
	if test `echo $1 | grep -c trunk` -gt 0; then
	    dir="${cbuild_top}/${hostname}/${target}/${dir}/trunk"
	else
	    dir="${cbuild_top}/${hostname}/${target}/${dir}"
	fi
    fi

    echo ${dir}

    return 0
}

# Extract the name of the toolchain component being built
# $1 - The full URL to the source tree as returned by get_URL(), or the
#      tarball name.
get_toolname()
{
    if test `echo $1 | grep -c "lp:"` -eq 0; then
	tool="`echo $1 | sed -e 's:-[0-9].*::'`"
	tool="`basename ${tool}`"
    else
	tool="`echo $1 | sed -e 's/lp://' -e 's:/.*::'`"
    fi
    if test `echo $1 | grep -c "trunk"` -eq 1; then
	tool="`echo $1 | sed -e 's:-[0-9].*::' -e 's:/trunk::'`"
	tool="`basename ${tool}`"
    fi

    echo ${tool}

    return 0
}

# This look at a remote repository for  source tarball
#
# $1 - The file to look for, which needs to be unique
find_snapshot()
{
    snapshots="`lynx -dump ${remote_snapshots} | egrep -v "\.asc" | cut -d ']' -f 2 | grep "$1" | sed -e 's@.*$1@@' -e 's: .*::'`"
    if test x"${snapshots}" = x; then
	error "No results for $1!"
	return 1
    fi
    if test `echo "${snapshots}" | grep -c $1` -gt 1; then
	error "Too many results for $1!"
	return 1
    fi

    echo ${snapshots}
    return 0
}

