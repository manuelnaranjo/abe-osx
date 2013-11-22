
# tests for the get_<part>() functions that are part of the git string parser.

get_git_foo()
{
    local in=$1
    local out=
    local ret=
    out="`git_parser foo ${in}`"
    ret=$?
    echo "${out}"
    return ${ret}
}

test_parser()
{
    local feature=$1
    local in=$2
    local match=$3
    local errmatch=$4
    local ret=
    local out=
    out="`get_git_${feature} ${in} 2>/dev/null`"
    ret=$?
    if test x"${out}" = x"${match}"; then
        pass "get_git_${feature} ${in} = '${match}'"
    else 
        fail "get_git_${feature} ${in} = '${match}'"
        fixme "'get_git_${feature} ${in}' returned '${out}' and expected '${match}'"
    fi

    if test x"${errmatch}" != x; then
	if test x"${errmatch}" = x"${ret}"; then
	    pass "get_git_${feature} ${in}: expected err "
	else
	    fail "get_git_${feature} ${in}: expected err "
	fi
    fi

#   echo "ret: ${ret}" 1>&2

    # Always return err.  An individual test might have 'passed', as-in it
    # returned the expected result, but we still might want to check if there
    # was an error in parsing.
    return ${err}
}

echo "============= git_parser() tests ================"
errmatch=''

in="git://address.com/directory/repo.git/branch"
match=''
test_parser user "${in}" "${match}" "${errmatch}"
match='git'
test_parser service "${in}" "${match}" "${errmatch}"

in="git://user@address.com/directory/repo.git/branch@12345"
match="user"
test_parser user "${in}" "${match}" "${errmatch}"

in="git://user@address.com/directory/repo.git/branch"
match="user"
test_parser user "${in}" "${match}" "${errmatch}"

in="git://user@address.com/directory@/repo.git/branch@12345"
match="user"
test_parser user "${in}" "${match}" "${errmatch}"

in="git://address.com/directory@/repo.git/branch@12345"
match=''
test_parser user "${in}" "${match}" "${errmatch}"

in="git://address.com/directory@/repo.git/branch"
match=''
test_parser user "${in}" "${match}" "${errmatch}"

in="git://address.com/directory@/repo.git/branch"
match=''
test_parser user "${in}" "${match}" "${errmatch}"
match='repo'
test_parser tool "${in}" "${match}" "${errmatch}"
match='git://address.com/directory@/repo.git'
test_parser url "${in}" "${match}" "${errmatch}"



# Sadly this works.
in="git://address.com@/directory@/repo.git/branch"
match='address.com'
test_parser user "${in}" "${match}" "${errmatch}"
match='repo'
test_parser tool "${in}" "${match}" "${errmatch}"
match='git://address.com@/directory@/repo.git'
test_parser url "${in}" "${match}" "${errmatch}"


in="http://address.com/directory@/repo.git/branch"
match=''
test_parser user "${in}" "${match}" "${errmatch}"
match='http'
test_parser service "${in}" "${match}" "${errmatch}"
match='repo'
test_parser tool "${in}" "${match}" "${errmatch}"
match='http://address.com/directory@/repo.git'
test_parser url "${in}" "${match}" "${errmatch}"

in="http://firstname.lastname@address.com/directory@/repo.git/branch"
match='http'
test_parser service "${in}" "${match}" "${errmatch}"
match='firstname.lastname'
test_parser user "${in}" "${match}" "${errmatch}"
match=''
test_parser revision "${in}" "${match}" "${errmatch}"
match='branch'
test_parser branch "${in}" "${match}" "${errmatch}"
match='repo.git'
test_parser repo "${in}" "${match}" "${errmatch}"
match='repo'
test_parser tool "${in}" "${match}" "${errmatch}"
match='http://firstname.lastname@address.com/directory@/repo.git'
test_parser url "${in}" "${match}" "${errmatch}"

in="http://firstname.lastname@address.com/directory/repo.git/branch@12334677"
match='http'
test_parser service "${in}" "${match}" "${errmatch}"
match='firstname.lastname'
test_parser user "${in}" "${match}" "${errmatch}"
match='12334677'
test_parser revision "${in}" "${match}" "${errmatch}"
match='branch'
test_parser branch "${in}" "${match}" "${errmatch}"
match='repo.git'
test_parser repo "${in}" "${match}" "${errmatch}"
match='repo'
test_parser tool "${in}" "${match}" "${errmatch}"
match='http://firstname.lastname@address.com/directory/repo.git'
test_parser url "${in}" "${match}" "${errmatch}"



in="http://firstname.lastname@address.com/directory/repo.git@12334677"
match='http'
test_parser service "${in}" "${match}" "${errmatch}"
match='firstname.lastname'
test_parser user "${in}" "${match}" "${errmatch}"
match='12334677'
test_parser revision "${in}" "${match}" "${errmatch}"
match=''
test_parser branch "${in}" "${match}" "${errmatch}"
match='repo.git'
test_parser repo "${in}" "${match}" "${errmatch}"
match='repo'
test_parser tool "${in}" "${match}" "${errmatch}"
match='http://firstname.lastname@address.com/directory/repo.git'
test_parser url "${in}" "${match}" "${errmatch}"


in="http://firstname.lastname@address.com/directory/repo@12334677"
match='http'
test_parser service "${in}" "${match}" "${errmatch}"
match='firstname.lastname'
test_parser user "${in}" "${match}" "${errmatch}"
match='12334677'
test_parser revision "${in}" "${match}" "${errmatch}"
match=''
test_parser branch "${in}" "${match}" "${errmatch}"
match='repo'
test_parser repo "${in}" "${match}" "${errmatch}"
match='repo'
test_parser tool "${in}" "${match}" "${errmatch}"
match='http://firstname.lastname@address.com/directory/repo'
test_parser url "${in}" "${match}" "${errmatch}"

in="http://firstname.lastname@address.com/directory/@12334677"
match='http'
test_parser service "${in}" "${match}" "${errmatch}"
match='firstname.lastname'
test_parser user "${in}" "${match}" "${errmatch}"
match='12334677'
test_parser revision "${in}" "${match}" "${errmatch}"
match=''
test_parser branch "${in}" "${match}" "${errmatch}"
match=''
test_parser repo "${in}" "${match}" "${errmatch}"
match=''
test_parser tool "${in}" "${match}" "${errmatch}"
match='http://firstname.lastname@address.com/directory'
test_parser url "${in}" "${match}" "${errmatch}"

in="http://firstname.lastname@address.com/direc@tory/@12334677"
match='http'
test_parser service "${in}" "${match}" "${errmatch}"
match='firstname.lastname'
test_parser user "${in}" "${match}" "${errmatch}"
match='12334677'
test_parser revision "${in}" "${match}" "${errmatch}"
match=''
test_parser branch "${in}" "${match}" "${errmatch}"
match=''
test_parser repo "${in}" "${match}" "${errmatch}"
match=''
test_parser tool "${in}" "${match}" "${errmatch}"
match='http://firstname.lastname@address.com/direc@tory'
test_parser url "${in}" "${match}" "${errmatch}"

in="http://@12334677"
match='http'
test_parser service "${in}" "${match}" "${errmatch}"

in="http://repo.git@12334677"
match='http://repo.git'
test_parser url "${in}" "${match}" "${errmatch}"
match='repo.git'
test_parser repo "${in}" "${match}" "${errmatch}"
match=''
test_parser branch "${in}" "${match}" "${errmatch}"

in="http://repo.git/branch@12334677"
match='http://repo.git'
test_parser url "${in}" "${match}" "${errmatch}"
match='repo.git'
test_parser repo "${in}" "${match}" "${errmatch}"
match='branch'
test_parser branch "${in}" "${match}" "${errmatch}"
match='12334677'
test_parser revision "${in}" "${match}" "${errmatch}"
match='repo'
test_parser tool "${in}" "${match}" "${errmatch}"

in="http://repo/branch@12334677"
# This is because the parser can't tell if 'branch' is a
# branch name or a repo name if there is no .git.
match='http://repo/branch'
test_parser url "${in}" "${match}" "${errmatch}"
match='branch'
test_parser repo "${in}" "${match}" "${errmatch}"
match='branch'
test_parser tool "${in}" "${match}" "${errmatch}"
match=''
test_parser branch "${in}" "${match}" "${errmatch}"
match='12334677'
test_parser revision "${in}" "${match}" "${errmatch}"

in="http://firstname.lastname@127.0.0.1/directory/repo.git@12334677"
match='http'
test_parser service "${in}" "${match}" "${errmatch}"
match='firstname.lastname'
test_parser user "${in}" "${match}" "${errmatch}"
match='12334677'
test_parser revision "${in}" "${match}" "${errmatch}"
match=''
test_parser branch "${in}" "${match}" "${errmatch}"
match='repo.git'
test_parser repo "${in}" "${match}" "${errmatch}"
match='repo'
test_parser tool "${in}" "${match}" "${errmatch}"
match='http://firstname.lastname@127.0.0.1/directory/repo.git'
test_parser url "${in}" "${match}" "${errmatch}"

in="http://firstname.lastname@127.0.0.1/directory/repo.git/funky_branch-name@12334677"
match='http'
test_parser service "${in}" "${match}" "${errmatch}"
match='firstname.lastname'
test_parser user "${in}" "${match}" "${errmatch}"
match='12334677'
test_parser revision "${in}" "${match}" "${errmatch}"
match='funky_branch-name'
test_parser branch "${in}" "${match}" "${errmatch}"
match='repo.git'
test_parser repo "${in}" "${match}" "${errmatch}"
match='repo'
test_parser tool "${in}" "${match}" "${errmatch}"
match='http://firstname.lastname@127.0.0.1/directory/repo.git'
test_parser url "${in}" "${match}" "${errmatch}"

match=''
errmatch=1
test_parser foo "${in}" "${match}" "${errmatch}"

