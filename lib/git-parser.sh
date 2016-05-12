#!/bin/bash
# 
#   Copyright (C) 2013, 2014, 2015, 2016 Linaro, Inc
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

# NOTICE: This service is most reliable when passed a full URL (including
#         service identifier, e.g., http://, git://).
#
# The get_git_<part> functions all operate on the same premise:
#
#    When given a string that represents a git url or git repository
#    identifier (plus branch and/or revision information) they will
#    parse the URL for the requested part.
#
# Forms:
#
#   get_git_service
#      The valid git services are: 'git', 'http' and 'ssh'.
#
#   get_git_user
#      Valid usernames are: 'username' and 'multi.part.username".
#
#   get_git_repo
#      The name of the respository including the '.git' suffix.
#
#   get_git_tool
#      The same as 'repo' but minus the '.git' suffix.
#
#   get_git_url
#       The full url of the repository, minus branch and/or revision
#       information.  This is valid for passing to git.
#
#   get_git_branch
#       The branch designation that follows the repository, e.g.,
#       binutils.git/branch
#
#   get_git_tag
#	Return a sanitized string of repository concatenated with optional
#	branch and revision information. The branch name has all '/'
#	characters converted to '-' characters. 
#
#       WARNING: A git tag is not parseable by the git parser.  It's a one
#		 way translation to be used for naming entities only. 
#
#	For example, calling get_git_tag with the following:
#	    git://foo.com/repo.git~multi/slash/branch
#	Will return the following:
#	    repo.git~multi-slash-branch as the 'tag'.
#
#   get_git_revision
#       The revision designation that follows the repository, e.g.,
#       binutils.git@12345
#
#         Note: abe allows <repo>.git/branch@revision even though
#               when a revision is present, the 'branch' is only used
#               in path names, since a revision implies a branch already.
#
# Calling convention:
#
#   Because the get_git_<part> functions return a string in stdout
#   they must be called in a subshell using the following convention:
#
#   local out=
#   out="`get_git_<part> <input_string>`"
#   if test $? -gt 1; then
#       # Parser detected malformed input.  Depending on what
#       # you expect, this might or might-not be an error.
#   elif test x"${out}" = x; then
#       # Parser didn't parse the requested part because
#       # it probably wasn't in the string OR the input
#       # is malformed.
#   fi
#
# Return Value
#   stdout: Returns the requested string (if parsed)
#   $?:     Returns the error status code
#   stderr: If $? != 0 then this contains information about
#           malformed input.
#
# Input String:
#   Valid inputs:
#      [{git|http}://[<username>@]{<url.foo>|127.0.0.1}/path/]<repo>.git[/<branch>][@<revision]
#
#   A full git url with branch and revision information, e.g.,
#
#      http://firstname.lastname@git.linaro.org/git/toolchain/gcc.git/linaro_4.9_branch@12345
#
#   A git repo identifier with branch and revision information:
#
#      gcc.git/linaro_4.9_branch@12345
#
# Examples:
#
#   For examples please see testsuite/git-parser-tests.sh
#

# This is the internal unified parser function.
# DO NOT USE THIS FUNCTION DIRECTLY.
# Use the get_git_<part> functions.
git_parser()
{
    local part=$1
    local in=$2

    local service=
    local revision=
    local numfields=
    local numats=
    local user=
    local url=
    local tool=
    local repo=
    local branch=

    # Set to '1' if something in ${in} is malformed.
    local err=0

    local service="`echo "${in}" | sed -n ' s#\(^git\)://.*#\1#p; s#\(^ssh\)://.*#\1#p; s#\(^http\)://.*#\1#p;  s#\(^https\)://.*#\1#p; '`"

    # Do this early because this is called often and we don't need all that
    # other parsing in this case.
    if test x"${part}" = x"service"; then
	# An http service with .git in the url is actually a git service.
	if test "`echo ${service} | grep -c http`" -gt 0 -a "`echo ${in} | egrep -c "\.git"`" -gt 0; then
	    service="git"
        # An ssh service is actually a git service.
        elif test x"${service}" = x"ssh"; then
            service="git"
        fi
	echo ${service}
	return 0
    fi

    # Just bail out early if this is a launch pad service. 
    if test x"${service}" = x"lp"; then
	case ${part} in
	    repo)
		local repo=""
		repo="`echo ${in} | sed -e "s#lp:[/]*##" -e 's:/.*::'`"
		echo "${repo}"
		;;
	    branch)
		local hastilde="`echo "${in}" | grep -c '\~'`"
		local hasslash="`echo "${in}" | grep -c '\/'`"
		if test ${hastilde} -gt 0; then
		    # Grab everything to the right of the ~
		    branch="`echo ${in} | sed -e 's:.*~\(.*\):\1:'`"
		elif test ${hasslash} -gt 0; then
		    branch="`basename ${in}`"
		fi
		echo ${branch}
		# otherwise there's no branch.
		;;	
	    url)
		echo "${in}"
		;;
	    tool)
		# Strip service information and any trailing branch information.
		local tool="`echo ${in} | sed -e 's/lp://' -e 's:/.*::'`"
		# Strip superflous -linaro tags
		local tool="`echo ${tool} | sed -e 's:-linaro::'`"
		echo ${tool}
		;;
	    *)
		;;
	esac
	return 0
    fi

    # This is tarball and it is unique
    if test "`echo ${in} | egrep -c "\.tar"`" -gt 0; then
	case ${part} in
	    repo)
		local repo=""
		repo="`basename ${in}`"
		repo="`echo ${repo} | sed -e 's:-[0-9].*::'`"
		echo "${repo}"
		;;
	    url)
		echo "${in}"
		;;
	    tool)
		# Special case binutils-gdb
		tool="`echo ${in} | sed -e 's:\(binutils-gdb\).*:\1:g'`"
		if test x"${tool}" != "xbinutils-gdb"; then
		    # Otherwise only grab up to the first -
		    tool="`echo ${in} | sed -e 's:\([^-]*\)-.*:\1:g'`"
	        fi
		# Strip service or directory information.
		tool="`basename ${tool}`"

		echo ${tool}
		;;
	    tag)
		local tag=
		tag="`echo ${in} | sed -e 's:\.tar.*::' -e 's:-[0-9][0-9][0-9][0-9]\.[0-9][0-9].*::'`"
		echo ${tag}
		;;
	    *)
		;;
	esac
	return 0
    fi

    # This will only find a username if it follows the <service>://
    # and precedes the first / in the url.  Yes you could
    # get away with http://www<user>@.foo.com/.
    local user="`echo "${in}" | sed -n "s;^${service}://\([^/]*\)@.*;\1;p"`"

    # This will only find a revision if it is a sequence of
    # alphanumerical characters following the last @ in the line.
    local revision="`echo "${in}" | sed -n 's/.*@\([[:alnum:]]*$\)/\1/p'`"

    local hasdotgit="`echo "${in}" | grep -c "\.git"`"
    local hastilde="`echo "${in}" | grep -c '\~'`"

    # Strip out the <service>::// part.
    local noservice="`echo "${in}" | sed -e "s#^${service}://##"`"

    local secondbase=
    if test ${hasdotgit} -gt 0; then
	local secondbase="`echo "${noservice}" | sed -e 's#.*\([/].*.git\)#\1#' -e 's#^/##' -e 's#@[[:alnum:]|@]*$##'`"
	local repo="`echo ${secondbase} | sed -e 's#\(.*\.git\).*#\1#' -e 's#.*/##'`"

	if test ${hastilde} -gt 0; then
	    local branch="`echo "${secondbase}" | sed -n 's#.*~\(.*\)$#\1#p'`"
	    if test "`echo ${branch} | grep -c "^/"`" -gt 0; then
		error "Malformed input.  Superfluous / after ~. Stripping."
		err=1
		local branch="`echo "${branch}" | sed -e 's#^/##'`"
	    fi 
	else
	    local branch="`echo ${secondbase} | sed -e 's#.*\.git##' -e 's#^[/]##' -e 's#@[[:alnum:]|@]*$##'`"
	fi
    elif test ${hastilde} -gt 0 -a ${hasdotgit} -lt 1; then
	# If the service is part of the designator then we have to strip
	# up to the leading /
	if test x"${service}" != x; then
	    local secondbase="`echo "${noservice}" | sed -e "s#[^/]*/##"`"
	else
	    # Otherwise we process it as if the repo is the leftmost
	    # element.
	    local secondbase=${in}
	fi

	# We've already processed the revision so strip that (and any trailing
	# @ symbols) off.
	local secondbase="`echo "${secondbase}" | sed -e 's#@[[:alnum:]|@]*$##'`"

	local branch="`echo "${secondbase}" | sed -n 's#.*~\(.*\)$#\1#p'`"
	
	if test "`echo ${branch} | grep -c "^/"`" -gt 0; then
	    error "Malformed input.  Superfluous / after ~. Stripping."
	    err=1
	    local branch="`echo "${branch}" | sed -e 's#^/##'`"
	fi 

	local repo="`echo ${secondbase} | sed -e 's#\(.*\)~.*#\1#' -e 's#.*/##'`"

	# Strip trailing trash introduced by erroneous inputs.	
	local repo="`echo ${repo} | sed -e  's#[[:punct:]]*$##'`"
    else # no .git and no tilde for branches
	# Strip off any trailing @<foo> sequences, even erroneous ones.
	local secondbase="`echo "${noservice}" | sed -e "s#[^/]*/##" -e 's#@[[:alnum:]|@]*$##'`"

	# If there's not <repo>.git then we can't possibly determine what's 
	# a branch vs. what's part of the url vs. what's a repository.  We
	# can only assume it's a repository.
	local branch=

	# The repo name is the content right of the rightmost /
	local repo="`echo ${secondbase} | sed 's#.*/##'`"
    fi

    # Strip trailing trash from the branch left by erroneous inputs.
    local branch="`echo ${branch} | sed -e 's#[[:punct:]]*$##'`"

    # The url is everything to the left of, and including the repo name itself.
    # Don't pick up any possibly superfluous @<blah> information, and filter
    # out any tildes.
    #local url="`echo ${in} | sed -n "s#\(.*${repo}\).*#\1#p" | sed -e 's#@[[:alnum:]|@]*$##'`"
    local url="`echo ${in} | sed -n "s#\(.*${repo}\).*#\1#p"`"

    # Strip trailing @ symbols from the url.
    local url="`echo ${url} | sed -e 's#@[[:alnum:]|@]*$##'`"

    # Strip trailing trash from the url, except leave the http|git://
    if test x"`echo ${url} | grep -e "^${service}://"`" != x; then
	local url="`echo ${url} | sed -e "s#^${service}://##"`"
	local url="`echo ${url} | sed -e 's#[[:punct:]]*$##'`"
	local url="${service}://${url}"
    else
	# If http|git:// isn't the last thing on the line
	#  just clean up the trailing trash.
	local url="`echo ${url} | sed -e 's#[[:punct:]]*$##'`"
    fi

    if test x"${repo}" != x; then
	tool="`echo ${repo} | sed -e "s#\.git##"`"
    fi

    local validats=0
    if test x"${revision}" != x; then
        validats="`expr ${validats} + 1`"
    fi
    if test x"${user}" != x; then
        validats="`expr ${validats} + 1`"
    fi

    local numats=0
    # This counts the number of fields separated by the @ symbols
    numats=`echo ${in} | awk -F "@" '{ print NF }'`
    # Minus one is the number of @ symbols.   
    numats="`expr ${numats} - 1`"
    if test ${numats} -gt ${validats}; then
	superfluousats="`expr ${numats} - ${validats}`"
	error "Malformed input.  Found ${superfluousats} superfluous '@' symbols. NUMATS: ${numats}   VALIDATS: ${validats}"
	err=1
    fi

    if test x"${url}" = x; then
	error "Malformed input. No url found."
	err=1
    elif test x"${repo}" = x; then
	error "Malformed input. No repo found."
	err=1
    fi

    case ${part} in
	service)
	    echo "${service}"
	    ;;
	user)
	    echo "${user}"
	    ;;
	tool)
	    echo "${tool}"
	    ;;
	url)
	    echo "${url}"
	    ;;
	repo)
	    echo "${repo}"
	    ;;
	branch)
	    echo "${branch}"
	    ;;
	revision)
	    echo "${revision}"
	    ;;
	*)
	    error "Unknown part '${part}' requested from input string."
	    err=1
	    ;;
    esac
    return ${err}
}

get_git_service()
{
    local in=$1
    local out=
    local ret=
    out="`git_parser service ${in}`"
    ret=$?
    echo "${out}"
    if test ${ret} -ne 0; then
	error "Malformed input \"${in}\""
    fi
    return ${ret}
}

get_git_user()
{
    local in=$1
    local out=
    local ret=
    out="`git_parser user ${in}`"
    ret=$?
    echo "${out}"
    if test ${ret} -ne 0; then
	error "Malformed input \"${in}\""
    fi
    return ${ret}
}

get_git_url()
{
    local in=$1
    local out=
    local ret=
    out="`git_parser url ${in}`"
    ret=$?
    echo "${out}"
    if test ${ret} -ne 0; then
	error "Malformed input \"${in}\""
    fi
    return ${ret}
}

get_git_tool()
{
    local in=$1
    local out=
    local ret=
    out="`git_parser tool ${in}`"
    ret=$?
    echo "${out}"
    if test ${ret} -ne 0; then
	error "Malformed input \"${in}\""
    fi
    return ${ret}
}

get_git_repo()
{
    local in=$1
    local out=
    local ret=
    out="`git_parser repo ${in}`"
    ret=$?
    echo "${out}"
    if test ${ret} -ne 0; then
	error "Malformed input \"${in}\""
    fi
    return ${ret}
}

get_git_branch()
{
    local in=$1
    local out=
    local ret=
    out="`git_parser branch ${in}`"
    ret=$?
    echo "${out}"
    if test ${ret} -ne 0; then
	error "Malformed input \"${in}\""
    fi
    return ${ret}
}

get_git_revision()
{
    local in=$1
    local out=
    local ret=
    out="`git_parser revision ${in}`"
    ret=$?
    echo "${out}"
    if test ${ret} -ne 0; then
	error "Malformed input \"${in}\""
    fi
    return ${ret}
}

get_git_tag()
{
    local in=$1
    local ret=
    local out=
    local repo=
    local branch=
    local revision=
    repo="`git_parser repo ${in}`"
    ret=$?
    if test ${ret} -ne 0; then
	error "Malformed input \"${in}\""
	return ${ret}
    fi
    if test x"${repo}" = x; then
	error "repository name required for meaningful response."
	return ${ret}
    fi

    branch="`get_git_branch ${in}`" || ( error "Malformed input \"${in}\""; return 1 )

    # Multi-path branches should have forward slashes replaced with dashes.
    branch="`echo ${branch} | sed 's:/:-:g'`"

    revision="`git_parser revision ${in}`" || ( error "Malformed input \"${in}\""; return 1 )
    echo "${repo}${branch:+~${branch}}${revision:+@${revision}}"
    return 0
}
