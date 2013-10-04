#!/bin/sh

#cbuild="`which cbuild2.sh`"
#topdir="`dirname ${cbuild}`"

# source all the library functions
. "${topdir}/lib/globals.sh" || exit 1
. "${topdir}/lib/fetch.sh" || exit 1
. "${topdir}/lib/configure.sh" || exit 1
. "${topdir}/lib/release.sh" || exit 1
. "${topdir}/lib/checkout.sh" || exit 1
. "${topdir}/lib/depend.sh" || exit 1
. "${topdir}/lib/make.sh" || exit 1
. "${topdir}/lib/merge.sh" || exit 1
. "${topdir}/lib/package.sh" || exit 1
. "${topdir}/lib/testcode.sh" || exit 1

#
# All the set* functions set global variables used by the other functions.
# This way there can be some error recovery and handing.
#

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

# if --dryrun is passed to cbuild2.sh, then commands are echoed instead of
# of executed.
dryrun()
{
    if test x"${dryrun}" = xyes; then
	echo "DRYRUN: $1"
    else
	if test x"${interactive}" = x"yes"; then
	    notice "About to execute $1"
	    notice "Hit any key to continue: "
	    read answer
	    return $?
	fi
	eval $1
	return $?
    fi

    return 0
}

trace()
{
    echo "TRACE(#${BASH_LINENO}): ${FUNCNAME[1]} ($*)"

}

fixme()
{
    echo "FIXME(#${BASH_LINENO}): ${FUNCNAME[1]} ($*)"

}

error()
{
    echo "ERROR (#${BASH_LINENO}): $1"
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
#
# returns a string that represents the full URL for git, and optionally
# a branch and revision number. These are returned as a string with the
# fields separated by spaces, so the calling function can more easily
# parse the data. As URLs have embedded slashes, and slashes are also used
# for branches, spaces work better.
get_URL()
{
#    trace "$*"

    local srcs="${topdir}/config/sources.conf"
    local node="`echo $1 | cut -d '/' -f 1`"
    local branch="`echo $1 | cut -d '/' -f 2 | cut -d '@' -f 1`"
    if test x"${branch}" = x"${node}"; then
	local branch=
    fi
    if test "`echo $1 | grep -c '@'`" -eq 1; then
	local revision="`echo $1 | cut -d '@' -f 2`"
    else
	local revision=
    fi
    
    if test -e ${srcs}; then
	if test "`grep -c "^${node}" ${srcs}`" -gt 1; then
	    echo "ERROR: Need unique component and version to get URL!"
	    echo ""
	    echo "Choose one from this list"
#	    list_URL $1
	    return 1
	fi
	local url="`grep "^${node}" ${srcs} | sed -e 's:^.* ::'`"
	echo "${url} ${branch} ${revision}"

	return 0
    else
	error "No config file for repository sources!"
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
#    trace "$*"

    locals srcs="${topdir}/config/sources.conf"    
    if test -e ${srcs}; then
	notice "Supported source repositories for $1 are:"
#	sed -e 's:\t.*::' -e 's: .*::' -e 's:^:\t:' ${srcs} | grep $1
	local url="`grep $1 ${srcs} | tr -s ' ' | cut -d ' ' -f 2`"
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
#    trace "$*"

    local branch=""
    case $1 in
	lp*)
	    local node="`echo $1 | sed -e 's@lp:@@' -e 's:/:_:'`"
	    ;;
	bzr*)
	    local node="`echo $1 | sed -e 's:^.*branch/::'`"
	    local node="`echo ${node} | sed -e 's:/:_:'`"
	    ;;
	git*)
	    local node="`echo $1 | sed -e 's@^.*/git/@@' -e 's:\.git.*:.git:'`"
	    local node="`basename ${node}`"
	    local branch="`echo $1 | sed -e "s:^.*${node}::" | tr -d '/'`"
	    if test x"${branch}" != x; then
		branch="-${branch}"
	    fi
	    ;;
	svn*)
	    local node="`echo $1 | sed -e 's@^.*/svn/@@'`"
	    local node="`basename ${node}`"
	    ;;
	http*)
	    local node="`echo $1 | sed -e 's@^.*/http/@@'`"
	    local node="`basename ${node}`"
	    if test x"${node}" = x"trunk"; then
		local node="`echo $1 | sed -e 's:-[0-9].*::' -e 's:/trunk::' `"
		local node="`basename ${node}`"
	    else
		local node="`basename $1 | sed -e 's:\.tar.*::'`"
	    fi
	    ;;
	*)
	    local node="`echo $1 | sed -e 's:\.tar.*::' -e 's:\+git:@:'`"
	    ;;
    esac

    echo ${node}${branch}

    return 0
}

# Extract the build directory from the URL of the source tree as it
# varies depending on which source code control system is used.
#
# $1 - The full URL to the source tree as returned by get_URL()
get_builddir()
{
#    trace "$*"

    local branch=""
    local dir="`normalize_path $1`"
#    local branch="`echo $1 | sed -e "s:^.*${dir}::" | cut -d '@' -f 1 | tr -d '/'`"
#    if test `echo ${dir} | grep -c 'infrastructure/'` -eq 0; then
    if test `echo ${dir} | grep -c '/'` -gt 0; then
	local branch="`echo ${dir} | cut -d '/' -f 2 | cut -d '@' -f 1 | tr -d '/'`"
	if test x"${branch}" != x; then
	    local branch="-${branch}"
	fi
    fi
    #local dir="`echo ${dir} | cut -d '/' -f 1`"
    # BUILD_TAG, BUILD_ID, and BUILD_NUMBER are set by Jenkins, and have valued
    # like these:
    # BUILD_ID 2013-09-02_20-23-02
    # BUILD_NUMBER 1077
    # BUILD_TAG	jenkins-cbuild-1077
    local tag="${dir}"
    local builddir="${local_builds}/${host}/${target}/${tag}"

    echo ${builddir}

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
#    trace "$*"

    if test x"$1" = x; then
	error "No toolchain component name argument!"
	return 1
    fi
    if test `echo $1 | grep -c "lp:"` -eq 0; then
	local tool="`echo $1 | sed -e 's:/linaro::' -e 's:-[0-9].*::' -e 's:\.git.*::'`"
	local tool="`basename ${tool}`"
    else
	local tool="`echo $1 | sed -e 's/lp://' -e 's:/.*::' -e 's:\.git.*::'`"
    fi
    if test `echo $1 | grep -c "trunk"` -eq 1; then
	local tool="`echo $1 | sed -e 's:-[0-9].*::' -e 's:/trunk::'`"
	local tool="`basename ${tool}`"
    fi

    echo ${tool} | sed -e 's:-linaro::' -e 's:\.git::'

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

    local dir="`dirname $1`/"
    if test x"${dir}" = x"."; then
	dir=""
    fi

    #rm -f ${local_snapshots}/md5sums
    #fetch_http md5sums
    #fetch_rsync ${remote_snapshots}/md5sums

    # Search for the snapshot in the md5sum file, and filter out anything we don't want.
    snapshot="`grep $1 ${local_snapshots}/${dir}md5sums | egrep -v "\.asc|\.diff|\.txt|xdelta" | cut -d ' ' -f 3`"
    if test x"${snapshot}" != x; then
	if test `echo "${snapshot}" | grep -c $1` -gt 1; then
	    error "Too many results for $1!"
	    return 1
	fi
	echo "${snapshot}"
	return 0
    fi

#    snapshot="`grep $1 ${local_snapshots}/${dir}md5sums | cut -d ' ' -f 3`"
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
# returns ${url} as a string with either a single string that is the tarball
# name, or a URL that can be used by git. The fields are as returned by
# get_URL(), which is 'git url' and optionally 'git branch' 'git revision'.
get_source()
{
#    trace "$*"

    if test x"$1" = x; then
	error "get_source() called without an argument!"
	return 1
    fi
    # If a full URL isn't passed as an argument, assume we want a
    # tarball snapshot
    if test `echo $1 | egrep -c "^svn|^git|^http|^bzr|^lp|\.git"` -eq 0; then
	find_snapshot $1
	# got an error
	if test $? -gt 0; then
	    if test x"${interactive}" = x"yes"; then
	     	notice "Pick a unique snapshot name from this list: "
		for i in ${snapshot}; do
		    echo "	$i"
		done
	     	read answer
	     	local url="`find_snapshot ${answer}`"
		return $?
	    else
		if test x"${snapshot}" != x; then
		    # If there is a config file for this toolchain component,
		    # see if it has a latest version set. If so, we use that.
		    if test x"${latest}"  != x; then
			local url=`find_snapshot ${latest}`
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
	local url=${snapshot}
	return 0
    else
	if test `echo $1 | egrep -c "\.git"` -eq 0; then
	    local url=$1
	    return 0
	fi
    fi
    
    # If a full URL isn't passed as an argment, get one for the
    # toolchain component from the sources.conf file.
    # If passed a full URL, use that to checkout the sources
    if test x"${url}" = x; then
	# get_URL() returns a string with the parsed fields separated by spaces.
	# These fields are 'git URL' 'git branch' 'git revision'.
	local gitinfo="`get_URL $1`"
	local url="`echo ${gitinfo} | cut -d ' ' -f 1`"
	if test `echo ${gitinfo} | wc -w` -gt 1; then
	    local branch="`echo ${gitinfo} | cut -d ' ' -f 2`"
	else
	    branch=
	fi
	if test `echo ${gitinfo} | wc -w` -gt 2; then
	    local revision="`echo ${gitinfo} | cut -d ' ' -f 3`"
	fi
	if test $? -gt 0; then
	    if test x"${interactive}" = x"yes"; then
	     	notice "Pick a unique URL from this list: "
		list_URL $3
		for i in ${url}; do
		    echo "\t$i"
		done
	     	read answer
		local url="`get_URL ${answer}`"
	    fi
	# else
	#     notice "Pick a unique URL from this list: "
	#     for i in ${url}; do
	# 	echo "	$i"
	#     done
	fi
    fi

    echo "${url} ${branch} ${revision}"

    return 0
}

# Get the proper source directory
# $1 - The component name
# returns the fully qualified srcdir
get_srcdir()
{
#    trace "$*"
    
    local tool="`get_toolname $1`"
    if test `echo $1 | grep -c '\.tar'` -gt 0; then
	local dir="`echo $1 | sed -e 's:\.tar.*::'`"
    else
	local dir="`echo $1 | sed -e "s:^.*/${tool}.git:${tool}.git:" -e 's:/:-:'`"
	local branch="-`echo ${dir} | sed -e "s:${tool}.git-::"`"
	if test x"${branch}" = x"-${dir}"; then
	    local branch=
	fi
	if test "`echo $1 | grep -c '@'`" -gt 0; then
	    local revision="@`echo $1 | cut -d '@' -f 2`"
	else
	    local revision=""
	fi
    fi
    
    local srcdir="${local_snapshots}/${dir}"

    # Some components have non-standard directory layouts.
    case ${tool} in
	gcc*)
	    local newdir="`echo ${srcdir} | sed -e 's:\.git-linaro::' | tr '.' '_'`"
	    local newdir="`basename ${newdir}`"
	    if test ! -e ${srcdir}/config.sub; then
		if test -e ${srcdir}/${newdir}${revision}/config.sub; then
		    local srcdir="${srcdir}/${newdir}"
		fi
	    fi
	    ;;
	eglibc*)
            # Eglibc has no top level configure script, it's in the libc
	    # subdirectory.
	    local srcdir="${srcdir}${branch}/libc"
	    ;;
	binutils*)
	    local srcdir="${srcdir}${branch}"
	    ;;
	*)
	    ;;
    esac
    
    echo ${srcdir}

    return 0
}
