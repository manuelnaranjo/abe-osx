#!/bin/sh

git_parser()
{
    local part=$1
    local in=$2

    local service=
    local hasrevision=
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

    #local service="`echo ${in} | sed -e 's#\(^git\)://.*#\1#;s#\(^http\)://.*#\1#'`"
    local service="`echo ${in} | sed -n 's#\(^git\)://.*#\1#p;s#\(^http\)://.*#\1#p'`"

    if test x"${service}" = x; then
	error "Malformed input.  No service defined."
	err=1
    fi

    # This will only find a 'username' if it follows the <service>://
    # and precededs the first . and or / in the url.  Yes you could
    # get away with http://www<user>@.foo.com/.
    local user="`echo ${in} | sed -n "s;^${service}://\([^/]*\)@.*;\1;p"`"

    local hasrevision="`basename ${in}`"
    hasrevision="`echo ${hasrevision} | grep -c '@'`"

    # Use these to look for malformed input strings.
    local numfields="`echo ${in} | awk -F "@" '{ print NF }'`"
    local numats="`expr ${numfields} - 1`"

    # Bounds check to look for malformed input strings with @ in it.
    if test ${hasrevision} -eq 0 -a x"${user}" != x -a ${numats} -gt 1; then
	error "Malformed input. Spurious '@' detected."
	err=1
    elif test ${hasrevision} -eq 0 -a x"${user}" = x -a ${numats} -gt 0; then
	error "Malformed input. Spurious '@' detected."
	err=1
    elif test ${hasrevision} -eq 1 -a x"${user}" = x -a ${numats} -gt 1; then
	error "Malformed input. Spurious '@' detected."
	err=1
    elif test ${hasrevision} -eq 1 -a x"${user}" != x -a ${numats} -gt 2; then
	error "Malformed input. Spurious '@' detected."
	err=1
    fi

    local revision="`basename ${in}`"
    local revision="`echo ${revision} | sed -n 's#.*@\([[:alnum:]]*\)#\1#p'`"

    local hasdotgit="`echo ${in} | grep -c "\.git"`"

    local base="`basename ${in}`"
    if test ${hasdotgit} -gt 0; then
        if test "`echo ${base} | grep -c "\.git"`" -gt 0; then
	    # No branch if <repo>.git appears in base
	    local branch=
	    local repo="`echo ${base} | cut -d '@' -f '1'`"
	else
	    local branch="`echo ${base} | cut -d '@' -f '1'`"
	    local repo="`echo ${in} | sed -e "s#${base}##"`"
	    local repo="`basename ${repo}`"
	fi
    else
	# If there is no .git suffix, then we can't support a 'branch'.
	local branch=
	local repo="`echo ${base} | cut -d '@' -f '1'`"
    fi

    # If there's a branch then ${base} doesn't include ${repo}
    if test x"${service}" = x; then
	local url=
    elif test x"${branch}" = x; then
	local url="`echo ${in} | sed -n "s#^\(.*\)/${base}#\1${repo:+/${repo}}#p"`"
    else
	local url="`echo ${in} | sed -n "s#^\(.*\)/${base}#\1#p"`"
    fi

    if test x"${repo}" != x; then
	tool="`echo ${repo} | sed -e "s#\.git##"`"
    fi

    if test x"${url}" = x; then
	error "Malformed input. Missing url."
	err=1
    elif test x"${repo}" = x; then
	error "Malformed input. Missing repo."
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
    return ${ret}
}
