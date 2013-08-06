#!/bin/sh

cbuild="`which $0`"
topdir="`dirname ${cbuild}`"

# source all the library functions
. "${topdir}/lib/globals.sh" || exit 1
. "${topdir}/lib/fetch.sh" || exit 1
. "${topdir}/lib/configure.sh" || exit 1
. "${topdir}/lib/release.sh" || exit 1
. "${topdir}/lib/checkout.sh" || exit 1
. "${topdir}/lib/depend.sh" || exit 1
. "${topdir}/lib/make.sh" || exit 1
. "${topdir}/lib/merge.sh" || exit 1

#
# All the set* functions set global variables used by the other functions.
# This way there can be some error recovery and handing.
#

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
    if test "${verbose}" -gt 0; then
	echo "WARNING: $1"
    fi
}

notice()
{
    if test "${verbose}" -gt 0; then
	echo "NOTE: $1"
    fi
}

# Get the URL to checkout out development sources.
# $1 - The toolchain component to get the source URL for, which must be
# unique in the source.conf file.
get_URL()
{
    srcs="${topdir}/config/sources.conf"
    if test -e ${srcs}; then
	if test "`grep -c "^$1" ${srcs}`" -gt 1; then
	    echo "ERROR: Need unique component and version to get URL!"
	    echo ""
	    echo "Choose one from this list"
#	    list_URL $1
	    return 1
	fi
	url="`grep "^$1" ${srcs}`"
	url="`echo ${out} | cut -d ' ' -f 2`"
	echo ${url}
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
    srcs="${topdir}/config/sources.conf"
    
    if test -e ${srcs}; then
	notice "Supported source repositories for $1 are:"
#	sed -e 's:\t.*::' -e 's: .*::' -e 's:^:\t:' ${srcs} | grep $1
	url="`grep $1 ${srcs} | tr -s ' ' | cut -d ' ' -f 2`"
	for i in ${url}; do
	    echo "	$i"
	done
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
    if test x"${target}" = x; then
	target=${build}
    fi
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

# Source a bourne shell config file so we can access it's variables.
#
# $1 - the tool component that the config file needs to be sourced
source_config()
{
    # clear the existing values so we can avoid inheriting config setting
    # from previously sourced config files.
    depends=""
    installs=""
    latest=""
    default_configure_flags=""
    runtest_flags=""
    stage1_flags=""
    stage2_flags=""

    conf="`get_toolname $1`.conf"
    if test $? -gt 0; then
	return 1
    fi
    if test -e ${topdir}/config/${conf}; then
	. ${topdir}/config/${conf}
	return 0
    else
	tool="`echo ${tool} | sed -e 's:-linaro::'`"
	if test -e ${topdir}/config/${conf}; then
	    . ${topdir}/config/${conf}
	    return 0
	fi
    fi
    
    return 1
}

# Extract the name of the toolchain component being built
# $1 - The full URL to the source tree as returned by get_URL(), or the
#      tarball name.
get_toolname()
{
    if test x"$1" = x; then
	error "No toolchain component name argument!"
	return 1
    fi
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

    echo ${tool} | sed 's:-linaro::'

    return 0
}

# This look at a remote repository for  source tarball
#
# $1 - The file to look for, which should be unique or we get too many results
#
# returns ${snapshot}
find_snapshot()
{
    if test x"$1" = x; then
	error "find_snapshot() called without an argument!"
	return 1
   fi

    #rm -f ${local_snapshots}/md5sums
    #fetch_http md5sums
    #fetch_rsync ${remote_snapshots}/md5sums

    # Search for the snapshot in the md5sum file, and filter out anything we don't want.
    snapshot="`grep $1 ${local_snapshots}/md5sums | egrep -v "\.asc|\.diff|\.txt|xdelta" | cut -d ' ' -f 3`"
    if test x"${snapshot}" != x; then
	if test `echo "${snapshot}" | grep -c $1` -gt 1; then
	    error "Too many results for $1!"
	    return 1
	fi
	echo "${snapshot}"
	return 0
    fi

#    snapshot="`grep $1 ${local_snapshots}/md5sums | cut -d ' ' -f 3`"
#    snapshot="`lynx -dump ${remote_snapshots} | egrep -v "\.asc" | cut -d ']' -f 2 | grep "$1" | sed -e 's@.*$1@@' -e 's: .*::'`"
    if test x"${snapshot}" = x; then
	error "No results for $1!"
	return 1
    fi
    if test `echo "${snapshot}" | grep -c $1` -gt 1; then
	error "Too many results for $1!"
	return 1
    fi

    echo ${snapshot}
    return 0
}

# Get the full path or URL to checkout or download sources of a toolchain
# component.
#
# $1 - A toolchain component to search for, which should be something like
#      binutils, gcc, glibc, newlib, etc...
#
# returns ${url}
get_source()
{
    if test x"$1" = x; then
	error "get_source() called without an argument!"
	return 1
    fi
    # If a full URL isn't passed as an argument, assume we want a
    # tarball snapshot
    if test `echo $1 | egrep -c "^svn|^git|^http|^bzr|^lp"` -eq 0; then
	find_snapshot $1
	# got an error
	if test $? -gt 0; then
	    if test x"${interactive}" = x"yes"; then
	     	notice "Pick a unique snapshot name from this list: "
		for i in ${snapshot}; do
		    echo "	$i"
		done
	     	read answer
	     	url="`find_snapshot ${answer}`"
		return $?
	    else
		if test x"${snapshot}" != x; then
		    # If there is a config file for this toolchain component,
		    # see if it has a latest version set. If so, we use that.
		    if test x"${latest}"  != x; then
			url=`find_snapshot ${latest}`
			return $?
		    fi
		    notice "Pick a unique snapshot name from this list and try again: "
		    for i in ${snapshot}; do
			echo "	$i"
		    done
		    list_URL $1
		    return 0
		fi
	    fi
	fi
	url=${snapshot}
	return 0
    else
	url=$1
	return 0
    fi
    
    # If a full URL isn't passed as an argment, get one for the
    # toolchain component from the sources.conf file.
    # If passed a full URL, use that to checkout the sources
    if test x"${url}" = x; then
	url="`get_URL $1`"
	if test $? -gt 0; then
	    if test x"${interactive}" = x"yes"; then
	     	notice "Pick a unique URL from this list: "
		list_URL $3
		for i in ${url}; do
		    echo "\t$i"
		done
	     	read answer
		url="`get_URL ${answer}`"
	    fi
	else
	    notice "Pick a unique URL from this list: "
	    for i in ${url}; do
		echo "\t$i"
	    done
	fi
    fi

    echo ${url}
    return 0
}

