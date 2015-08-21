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
. "${topdir}/lib/component.sh" || exit 1

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
# Returns a string that represents the full URL for an svn, lp, or git service
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
	# We don't want to match on partial matches
	# (hence looking for a trailing space or \t).
	local node="`echo ${node} | sed -e 's:-[0-9a-z\.\-]*::'`"
	if test "`grep -c "^${node} " ${srcs}`" -lt 1 -a "`grep -c "^${node}.git" ${srcs}`" -lt 1; then
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
	lp*)
	    local node="`echo ${process} | sed -e 's@lp:@@' -e 's:/:_:'`"
	    ;;
	bzr*)
	    local node="`echo ${process} | sed -e 's:^.*branch/::'`"
	    local node="`echo ${node} | sed -e 's:/:_:'`"
	    ;;
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
	svn*)
	    local node="`echo ${process} | sed -e 's@^.*/svn/@@'`"
	    local node="`basename ${node}`"
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

    local conf="${topdir}/config/$1.conf"
    if test -e ${conf}; then
        . "${conf}"
        return 0
    else
        return 1
    fi
}

read_config()
{
    local conf="${topdir}/config/$1.conf"
    local value="`export ${2}= && . ${conf} && set -o posix && set | grep \"^${2}=\" | sed \"s:^[^=]\+=\(.*\):\1:\" | sed \"s:^'\(.*\)'$:\1:\"`"
    local retval=$?
    unset ${2}
    echo "${value}"

    return ${retval}
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

	local srcdir="`get_component_srcdir ${version}`"
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
	local srcdir="`get_component_srcdir ${version}`"
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
