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

set -o pipefail

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
. "${topdir}/lib/git-parser.sh" || exit 1
. "${topdir}/lib/stamp.sh" || exit 1
. "${topdir}/lib/schroot.sh" || exit 1
. "${topdir}/lib/gerrit.sh" || exit 1

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

# if --dryrun is passed to abe.sh, then commands are echoed instead of
# of executed.
dryrun()
{
    if test x"${dryrun}" = xyes; then
	echo "DRYRUN: $1" 1>&2
    else
	if test x"${interactive}" = x"yes"; then
	    notice "About to execute $1"
	    notice "Hit any key to continue: "
	    read answer
	    return $?
	fi
	# Output this to stderr so we don't pollute functions that return
	# information to stdout.
        echo "RUN: $1" 1>&2

	# This block restricts the set -o pipefail to ONLY the command being
	# evaluated.  The set -o pipefail command will cause the right-most
	# non-zero return value of the expression ($1) being evaluated, to be
	# propogated through to the finally returned value in $?.  This means
	# that `foo | tee` will return the return value of 'foo' in $? if
	# it is non-zero and not always return the right-most success '0' from
	# tee.  Otherwise the tee command will always return '0'.  NOTE: the
	# behavior of eval $1 w/rt return value is different for external
	# programs than it is for internal functions.
	(
	    set -o pipefail
	    eval $1
	)
	return $?
    fi

    return 0
}

trace()
{
    echo "TRACE(#${BASH_LINENO}): ${FUNCNAME[1]} ($*)" 1>&2

}

fixme()
{
    echo "FIXME(#${BASH_LINENO}): ${FUNCNAME[1]} ($*)" 1>&2

}

error()
{
    echo "ERROR (#${BASH_LINENO}): ${FUNCNAME[1]} ($1)" 1>&2
    return 1
}

warning()
{
    if test "${verbose}" -gt 0; then
	echo "WARNING: $1" 1>&2
    fi
}

notice()
{
    if test "${verbose}" -gt 0; then
	echo "NOTE: $1" 1>&2
    fi
}

# Get the URL to checkout out development sources.
#
# $1 - The toolchain component identifier.
#
# Returns a string that represents the full URL for a git service
# that matches the identifier in the sources.conf file.
# 
# [Optional] Return a branch and revision number for git if tagged
# onto the identifier. e.g., get_URL repo.git~multi/slash/branch@12345
# will return a matching url in sources.conf such as:
#
# http://staging.linaro.org/git/toolchain/repo.git~multi/slash/branch@12345
#
# If get_URL is passed an identifier that already contains a URL it will fail.
#
get_URL()
{
#    trace "$*"

    if test "`echo $1 | grep -c "\.tar.*$"`" -gt 0; then
	error "not supported for .tar.* files."
	return 1
    fi

    # It makes no sense to call get_URL if you already have the URL.
    local service=
    service="`get_git_service $1`"
    if test x"${service}" != x; then
	error "Input already contains a url."
	return 1
    fi

    # Use the git parser functions to retrieve information about the
    # input parameters.  The git parser will always return the 'repo'
    # for an identifier as long as it follows some semblance of sanity.
    local node=
    node="`get_git_repo $1`"

    # Optional elements for git repositories.
    local branch=
    branch="`get_git_branch $1`"
    local revision=
    revision="`get_git_revision $1`"
   
    local srcs="${sources_conf}"
    if test -e ${srcs}; then
	if test "`grep -c "^${node}" ${srcs}`" -gt 1; then
	    error "Need unique component and version to get URL!"
	    return 1
	fi
	# We don't want to match on partial matches
	# (hence looking for a trailing space or \t).
	if test "`grep -c "^${node} " ${srcs}`" -lt 1 -a "`grep -Pc "^${node}\t" ${srcs}`" -lt 1; then
	    error "Component \"${node}\" not found in ${srcs} file!"
	    return 1
	fi
	local url="`grep "^${node}" ${srcs} | sed -e 's:^.*[ \t]::'`"
	echo "${url}${branch:+~${branch}}${revision:+@${revision}}"

	return 0
    else
	error "No config file for repository sources!"
    fi

    return 1
}

# display a list of matching URLS we know about. This is how you can see the
# correct name to pass to get_URL().
#
# $1 - The name of the toolchain component, partial strings ok
list_URL()
{
#    trace "$*"

    local srcs="${sources_conf}"    
    if test -e ${srcs}; then
	notice "Supported source repositories for $1 are:"
#	sed -e 's:\t.*::' -e 's: .*::' -e 's:^:\t:' ${srcs} | grep $1
	local url="`grep $1 ${srcs} | tr -s ' ' | cut -d ' ' -f 2`"
	for i in ${url}; do
	    echo "	$i" 1>&2
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
# FIXME: ban non-service or tarball inputs.

    local process=
    if test "`echo $1 | egrep -c "^git://|^http://|^ssh://"`" -lt 1 -a "`echo $1 | grep -c "\.git"`" -gt 0; then
	# If the input is an identifier (not a service) then process \.git
	# identifiers as git URLs
	process="`get_URL $1`"
    else
	process=$1
    fi

    local branch=""
    case ${process} in
	git*|http*|ssh*)
            if test "`echo ${process} | grep -c "\.tar"`" -gt 0 -o "`echo ${process} | grep -c "\.tgz"`" -gt 0; then
                local node="`basename ${process} | sed -e 's:\.tar.*::' -e 's:\.tgz$::'`"
	    else
		local node=
		node="`get_git_repo ${process}`"

		local branch=
		branch="`get_git_branch ${process}`"

		# Multi-path branches should have forward slashes replaced with dashes.
		branch="`echo ${branch} | sed 's:/:-:g'`"

		local revision=
		revision="`get_git_revision ${process}`"
	    fi
	    ;;
	*.tar.*)
	    local node="`echo ${process} | sed -e 's:\.tar.*::' -e 's:\+git:@:' -e 's:\.git/:.git-:'`"
	    ;;
	*)
	    fixme "normalize_path should only be called with a URL or a tarball name, not a sources.conf identifier."
	    # FIXME: This shouldn't be handled here.
	    local node="`echo ${process} | sed -e 's:\.tar.*::' -e 's:\+git:@:' -e 's:\.git/:.git-:'`"
	    ;;
    esac

    if test "`echo $1 | grep -c glibc`" -gt 0; then
	local delim='_'
    else
	local delim='@'
    fi

    echo ${node}${branch:+~${branch}}${revision:+${delim}${revision}}

    return 0
}

# Extract the build directory from the URL of the source tree as it
# varies depending on which source code control system is used.
#
# $1 - The full URL to the source tree as returned by get_URL()
get_builddir()
{
    # We should be more strict but this works with identifiers
    # as well because we might be passed a tar file.
    local dir="`normalize_path $1`"

    if test x"$2" = x"libgloss"; then
     	echo "${local_builds}/${host}/${target}/${dir}/${target}/libgloss"
    else
	echo "${local_builds}/${host}/${target}/${dir}${2:+-$2}"
    fi

    return 0
}

get_config()
{
    conf="`get_toolname $1`.conf"
    if test $? -gt 0; then
	return 1
    fi
    if test -e ${topdir}/config/${conf}; then
	echo "${topdir}/config/${conf}"
	return 0
    else
	tool="`echo ${tool} | sed -e 's:-linaro::'`"
	if test -e ${topdir}/config/${conf}; then
	    echo "${topdir}/config/${conf}"
	    return 0
	fi
    fi
    error "Couldn't find ${topdir}/config/${conf}"

    return 1
}

# Extract the name of the toolchain component being built

# Source a bourne shell config file so we can access its variables.
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

    conf="`get_config $1`"
    if test $? -eq 0; then
        . "${conf}"
        return 0
    else
        return 1
    fi
}

read_config()
{
    conf="`get_config $1`"
    if test $? -gt 0; then
        return 1
    else
        local value="`export ${2}= && . ${conf} && set -o posix && set | grep \"^${2}=\" | sed \"s:^[^=]\+=\(.*\):\1:\" | sed \"s:^'\(.*\)'$:\1:\"`"
        local retval=$?
        echo "${value}"
        return ${retval}
    fi
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

    local tool=
    tool="`get_git_tool $1`"

    # binutils and gdb are special.  They share a repository and the tool is
    # designated by the branch.
    if test x"${tool}" = x"binutils-gdb"; then
	local branch=
	branch="`get_git_branch $1`"
	tool="`echo ${branch} | sed -e 's:.*binutils.*:binutils:' -e 's:.*gdb.*:gdb:'`"
    fi

    echo ${tool}
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
    snapshot="`grep $1 ${local_snapshots}/md5sums | egrep -v "\.asc|\.diff|\.txt|xdelta" | cut -d ' ' -f 3`"
    if test x"${snapshot}" != x; then
	if test `echo "${snapshot}" | grep -c $1` -gt 1; then
	    warning "Too many results for $1!"
	    echo "${snapshot}"
	    return 1
	fi
	echo "${snapshot}"
	return 0
    fi

#    snapshot="`grep $1 ${local_snapshots}/${dir}md5sums | cut -d ' ' -f 3`"
    if test x"${snapshot}" = x; then
	warning "No results for $1!"
	return 1
    fi
    if test `echo "${snapshot}" | grep -c $1` -gt 1; then
	warning "Too many results for $1!"
	echo "${snapshot}"
	return 1
    fi

    echo ${snapshot}
    return 0
}

# Get the full path or URL to checkout or download sources of a toolchain
# component.
# This is the kitchen sink of function.
#
# $1 - 
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

    local url=
    # If a full URL or git repo identifier isn't passed as an argument,
    # assume we want a tarball snapshot
    if test `echo $1 | egrep -c "^git|^http|^ssh|\.git"` -eq 0; then
        local snapshot
	snapshot=`find_snapshot $1`
	if test $? -gt 0; then
	    if test x"${interactive}" = x"yes"; then
		# TODO: Add a testcase for this leg, conditional on
		# interactive.
	     	echo "Pick a unique snapshot name from this list: " 1>&2
		for i in ${snapshot}; do
		    echo "	$i" 1>&2
		done
	     	read answer
		local url
	     	url="`find_snapshot ${answer}`"
		local ssret=$?
		echo "${url}"
		return ${ssret}
	    else
		if test x"${snapshot}" != x; then
		    # It's possible that the value passed in to get_sources
		    # didn't match any known snapshots OR there were too many
		    # matches.  Check <package>.conf:latest to see if there's a
		    # matching snapshot.
		    if test x"${latest}"  != x; then
			local url
			url=`find_snapshot ${latest}`
			local ssret=$?
			echo "${url}"
			return ${ssret}
		    fi
		    # Technically 'notice' and 'get_URL' already suppress without
		    # verbose being set but no reason to do unnecessary work.
		    if test "${verbose}" -gt 0; then
		        notice "Pick a unique snapshot name from this list and try again: "
			for i in ${snapshot}; do
			    echo "	$i" 1>&2
			done
		        list_URL $1
		    fi
		    return 1
		fi
	    fi
	else
	    echo ${snapshot}
	    return 0
	fi
    else
	# This leg captures direct urls that don't start or end in .git.
	# This includes git identifiers that start with http://.
	if test `echo $1 | egrep -c "\.git"` -eq 0 -a `echo $1 | egrep -c "^git"` -eq 0; then
	#if test `echo $1 | egrep -c "\.git"` -eq 0; then
	    local url=$1
	    echo "${url}"
	    return 0
	fi
    fi
    
    # If a full URL isn't passed as an argment, get one for the
    # toolchain component from the sources.conf file.
    # If passed a full URL, use that to checkout the sources
    if test x"${url}" = x; then

	local service=
	service="`get_git_service $1`"

	# This might be a full URL or just an identifier.  Use the
	# service field to determine this.
	local gitinfo=
	if test x"${service}" = x; then
	    # Just an identifier, so get the full git info.
	    local gitinfo="`get_URL $1`"
	    if test x"${gitinfo}" = x; then
		error "$1 not a valid sources.conf identifier."
		return 1;
	    fi
	else
	    # Full URL
	    local gitinfo="$1"
	fi

	local url=
	local url_ret=
	url="`get_git_url ${gitinfo}`"
	url_ret=$?
	local branch=
	branch="`get_git_branch ${gitinfo}`"
	local revision=
	revision="`get_git_revision ${gitinfo}`"

#
#	local url="`echo ${gitinfo} | cut -d ' ' -f 1`"
#	if test `echo ${gitinfo} | wc -w` -gt 1; then
#	    local branch="`echo ${gitinfo} | cut -d ' ' -f 2`"
#	else
#	    branch=
#	fi
#	if test `echo ${gitinfo} | wc -w` -gt 2; then
#	    local revision="`echo ${gitinfo} | cut -d ' ' -f 3`"
#	fi

	#if test $? -gt 0; then
	if test ${url_ret} -gt 0; then
	    if test x"${interactive}" = x"yes"; then
	     	notice "Pick a unique URL (by identifier) from this list: "
		list_URL $3
		for i in ${url}; do
		    echo "\t$i" 1>&2
		done
	     	read answer
		local url="`get_URL ${answer}`"
	    fi
	# else
	#     notice "Pick a unique URL from this list: "
	#     for i in ${url}; do
	# 	echo "	$i" 1>&2
	#     done
	fi
    fi

    # We aren't guaranteed a match even after snapshots and sources.conf have
    # been checked.
    if test x"${url}" = x; then
	return 1
    fi

    echo "${url}${branch:+~${branch}}${revision:+@${revision}}"

    return 0
}

# Get the proper source directory
# $1 - The component name, which is one of the following:
# 
#   A git, http, ssh URL
#   A repository identifier mapping an entry in sources.conf
#   A tarball
# 
# Returns the fully qualified srcdir
get_srcdir()
{
#    trace "$*"
    
    if test `echo $1 | grep -c "\.tar"` -gt 0; then
	# tarballs have no branch or revision
	local dir="`echo $1 | sed -e 's:\.tar.*::'`"
    else
	local process=$1

	# The git parser will return results for all valid services.
	local service=
	service="`get_git_service ${process}`"

	# The git parser functions are most reliable when called with
	# a full URL and this verifies that a repo identifier has a
	# valid sources.conf entry.
	if test x"${service}" = x; then
	    local process=
	    process="`get_URL $1`"
	    if test $? -gt 0; then 
		error "get_srcdir called with invalid input."
		return 1
	    fi
	fi

	local tool=
	tool="`get_toolname ${process}`"

	local repo=
	repo="`get_git_repo ${process}`"

	local branch=
	branch="`get_git_branch ${process}`"

	# Multi-path branches should have / replaces with dashes.
	branch="`echo ${branch} | sed 's:/:-:g'`"

	local revision=
	revision="`get_git_revision ${process}`"

	local dir=${repo}${branch:+~${branch}}${revision:+@${revision}}
    fi
    
    local srcdir="${local_snapshots}/${dir}"

    # Some components have non-standard directory layouts.
    case ${tool} in
	gcc*)
# FIXME: How does this work with current g.l.o gcc sources?

	    # The Linaro gcc git branches are git repositories converted from
	    # bzr so they have goofy directory layouts which include the branch
	    # as a directory inside the source directory.
	    local newdir="`echo ${srcdir} | sed -e 's:\.git-linaro::' | tr '.' '_'`"
	    local newdir="`basename ${newdir}`"
	    # If the top level file doesn't yet exist then the user is asking
	    # where to put the source.  If it does exist then they're asking
	    # where the actual source is located.
	    if test ! -e ${srcdir}/config.sub; then
		# Fixme!
		if test -e ${srcdir}/${newdir}${revision}/config.sub; then
		    local srcdir="${srcdir}/${newdir}${revision}"
		fi
	    fi
	    ;;
	eglibc*)
            # Eglibc has no top level configure script, it's in the libc
	    # subdirectory.
	    if test -d "${srcdir}/libc"; then
	    	# If the directory already exists the caller wants to know
		# where the sources are.
		local srcdir="${srcdir}/libc"
	    fi
	    # Else if the directory does not yet exist the caller wants to know
	    # where to put the eglibc sources.
	    ;;
	*)
	    ;;
    esac
    
    if test x"$2" = x"libgloss"; then
	local srcdir="${srcdir}/libgloss"
    fi

    echo ${srcdir}

    return 0
}

# Parse a version string and produce a release version string suitable
# for the LINARO-VERSION file.
create_release_version()
{
#    trace "$*"

    local version=$1
    local branch=
    local revision=

    if test x"${release}" = x; then
    # extract the branch from the version
	if test "`echo $1 | grep -c "\.git/"`" -gt 0; then
	    local branch="~`echo ${version} | cut -d '/' -f 2 | cut -d '@' -f 1`"
	fi

	local srcdir="`get_srcdir ${version}`"
	if test -d "${srcdir}/.git" -o -e "${srcdir}/.gitignore"; then
	    local revision="@`cd ${srcdir} && git log --oneline | head -1 | cut -d ' ' -f 1`"
	fi

	local date="`date +%Y%m%d`"

	# return the version string array
	local rtag="${branch}${revision}-${date}"
	# when 'linaro' is part of the branch name, we get a duplicate
	# identifier, which we remove to be less confusing, as the tag name
	# is long enough as it is...
	local rtag="`echo ${rtag} | sed -e 's:-linaro~linaro:~linaro:'`"
    else
	local version="`echo $1 | sed -e 's:[a-z\./-]*::' -e 's:-branch::' -e 's:^_::' | tr '_' '.' `"
	if test x"${version}" = x; then
	    local version="`grep ^latest= ${topdir}/config/gcc.conf | cut -d '\"' -f 2`"
	    local version="`echo ${version} | sed -e 's:[a-z\./-]*::' -e 's:-branch::'`"
	fi
	local rtag="${version}-${release}"
    fi

    echo ${rtag}

    return 0
}


# Parse a version string and produced the proper output fields. This is
# used when naming releases for both directories, tarballs, and
# internal version numbers. The version string looks like
# 'gcc.git/gcc-4.8-branch' or 'gcc-linaro-4.8-2013.09'
#
# returns "version~branch@revision"
create_release_tag()
{
#    trace "$*"

    local version=$1
    local branch=
    local revision=

    local rtag="`get_git_tag $1`"

    local name="`echo ${version} | cut -d '/' -f 1 | cut -d '~' -f 1 | sed -e 's:\.git:-linaro:' -e 's:\.tar.*::' -e 's:-[-0-9\.]\.[0-9\.\-]*::'`"

    if test x"${release}" = x; then
	# extract the branch from the version
	local srcdir="`get_srcdir ${version}`"
	if test -d "${srcdir}/.git" -o -e "${srcdir}/.gitignore"; then
	    local revision="@`cd ${srcdir} && git log --oneline | head -1 | cut -d ' ' -f 1`"
	fi
	
	local date="`date +%Y%m%d`"
	
        # return the version string array
	local rtag="${rtag}${revision}-${date}"
    else
	local version="`echo $1 | grep -o '\-[0-9\.]*\-' | tr -d '-'`"
	local tool="`get_toolname $1`"
	if test x"${version}" = x; then
	    local version="`grep ^latest= ${topdir}/config/${tool}.conf | cut -d '\"' -f 2`"
	    local version="`echo ${version} | sed -e 's:[a-z\./-]*::' -e 's:-branch::'`"
	fi
	local rtag="${name}-${version}-${release}"
        # For a release, we don't need the .git~ identifier.
	local rtag="`echo ${rtag} | sed -e 's:\.git~:-:'`"

    fi

    if test x"${release}" != x;then
	rtag="`echo ${rtag} | sed -e 's:~linaro/gcc-::' -e 's:~linaro-::'`"
    fi

    echo `echo ${rtag} | tr '/' '-'`
    
    return 0
}

# Get the SHA-1 for the latest commit to the git repository
srcdir_revision()
{
#    trace "$*"
    
    local srcdir=$1
    local revision="`cd ${srcdir} && git log -n 1 | head -1 | cut -d ' ' -f 2`"
    
    echo ${revision}
    return 0
}

# Search $runtests to see if $package should be unit tested.
# List of tests to run
# $1: ${runtests}
# $2: ${package} to check
# Return Value(s)
# 0 = package found in runtests
# 1 = package not found in runtests
is_package_in_runtests()
{
    local unit_test="$1"
    local package="$2"

    for i in ${unit_test}; do
        if test x"$i" = x"$package"; then
            return 0
	fi
    done
    return 1
}
