git_parser_fixme()
{
    local buglineno=$1
    if test x"${debug}" = x"yes"; then
	shift
	echo "(${buglineno}): $*"
    fi
}

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
    local buglineno=$BASH_LINENO
    local feature=$1
    local in=$2
    local match=$3
    local errmatch=$4
    local ret=
    local out=
    if test x"${debug}" = x"yes"; then
	out="`get_git_${feature} ${in}`"
    else
	out="`get_git_${feature} ${in} 2>/dev/null`"
    fi
    ret=$?

    if test x"${debug}" = x"yes"; then
	echo -n "($buglineno) " 1>&2
    fi
    if test x"${out}" = x"${match}"; then
        pass "get_git_${feature} ${in} expected '${match}'"
    else 
        fail "get_git_${feature} ${in} expected '${match}'"
        git_parser_fixme "${buglineno}" "'get_git_${feature} ${in}' expected '${match}' but returned '${out}'"
    fi

    if test x"${errmatch}" != x; then
	if test x"${debug}" = x"yes"; then
	    echo -n "($buglineno) " 1>&2
	fi

	if test x"${errmatch}" = x"${ret}"; then
	    pass "get_git_${feature} ${in} expected return value '${errmatch}'"
	else
	    fail "'get_git_${feature} ${in}' expected return value '${errmatch}'"
	    git_parser_fixme "${buglineno}" "'get_git_${feature} ${in}' expected '${errmatch}' but returned '${ret}'"
	fi
    fi

    # Always return ret.  An individual test might have 'passed', as-in it
    # returned the expected result, but we still might want to check if there
    # was an error in parsing.
    return ${ret}
}

echo "============= git_parser() tests ================"

errmatch=0
in="gcc.git/linaro-4.8-branch"
match='linaro-4.8-branch'
test_parser branch "${in}" "${match}" "${errmatch}"
match='gcc.git'
test_parser repo "${in}" "${match}" "${errmatch}"

# No expected errors.
errmatch=0
in="git://address.com/directory/repo.git"
match=''
test_parser user "${in}" "${match}" "${errmatch}"
match='git'
test_parser service "${in}" "${match}" "${errmatch}"
match='repo.git'
test_parser repo "${in}" "${match}" "${errmatch}"
match='repo'
test_parser tool "${in}" "${match}" "${errmatch}"
match='git://address.com/directory/repo.git'
test_parser url "${in}" "${match}" "${errmatch}"
match=''
test_parser revision "${in}" "${match}" "${errmatch}"

# Minor variation with a different service
in="http://address.com/directory/repo.git"
match='http'
test_parser service "${in}" "${match}" "${errmatch}"

# Minor variation with a different service
in="gcc-svn-4.8"
match=''
test_parser service "${in}" "${match}" "${errmatch}"
match='gcc-svn-4.8'
test_parser repo "${in}" "${match}" "${errmatch}"
match='gcc-svn-4.8'
test_parser url "${in}" "${match}" "${errmatch}"
match=''
test_parser branch "${in}" "${match}" "${errmatch}"
match=''
test_parser revision "${in}" "${match}" "${errmatch}"
# We can't really know this this shouldn't be -svn-4.8
# without having a service identifier!
match='gcc-svn-4.8'
test_parser tool "${in}" "${match}" "${errmatch}"

# Minor variation with a different service
in="svn://gcc.gnu.org/svn/gcc/branches/gcc-4_7-branch"
match='svn'
test_parser service "${in}" "${match}" "${errmatch}"

# Minor variation with a different service
in="svn://gcc.gnu.org/svn/gcc/branches/gcc-4_7-branch"
match='svn'
test_parser service "${in}" "${match}" "${errmatch}"
match="svn://gcc.gnu.org/svn/gcc/branches/gcc-4_7-branch"
test_parser url "${in}" "${match}" "${errmatch}"
match='gcc-4_7-branch'
test_parser repo "${in}" "${match}" "${errmatch}"
match=''
test_parser branch "${in}" "${match}" "${errmatch}"
match=''
test_parser revision "${in}" "${match}" "${errmatch}"
match='gcc'
test_parser tool "${in}" "${match}" "${errmatch}"

# Minor variation with a different service
in="lp:cortex-strings"
match='lp'
test_parser service "${in}" "${match}" "${errmatch}"
match='lp:cortex-strings'
test_parser url "${in}" "${match}" "${errmatch}"
match='cortex-strings'
test_parser repo "${in}" "${match}" "${errmatch}"
match=''
test_parser revision "${in}" "${match}" "${errmatch}"
match=''
test_parser branch "${in}" "${match}" "${errmatch}"
match='cortex-strings'
test_parser tool "${in}" "${match}" "${errmatch}"

in="lp:cortex-strings/foo"
match='lp'
test_parser service "${in}" "${match}" "${errmatch}"
match='lp:cortex-strings/foo'
test_parser url "${in}" "${match}" "${errmatch}"
match='cortex-strings'
test_parser repo "${in}" "${match}" "${errmatch}"
match=''
test_parser revision "${in}" "${match}" "${errmatch}"
match=''
test_parser branch "${in}" "${match}" "${errmatch}"
match='cortex-strings'
test_parser tool "${in}" "${match}" "${errmatch}"

# Minor variation with a different service
in="lp:/cortex-strings"
match='lp'
test_parser service "${in}" "${match}" "${errmatch}"
match='lp:/cortex-strings'
test_parser url "${in}" "${match}" "${errmatch}"
match='cortex-strings'
test_parser repo "${in}" "${match}" "${errmatch}"
match=''
test_parser revision "${in}" "${match}" "${errmatch}"
match=''
test_parser branch "${in}" "${match}" "${errmatch}"

# Minor variation with a different service
in="cortex-strings"
match=''
test_parser service "${in}" "${match}" "${errmatch}"
match='cortex-strings'
test_parser url "${in}" "${match}" "${errmatch}"
match='cortex-strings'
test_parser repo "${in}" "${match}" "${errmatch}"
match=''
test_parser revision "${in}" "${match}" "${errmatch}"
match=''
test_parser branch "${in}" "${match}" "${errmatch}"

in="git://address.com/directory/repo.git/branch"
match='branch'
test_parser branch "${in}" "${match}" "${errmatch}"

# Test with ~ style branch designation
in="git://address.com/directory/repo.git~branch"
match='branch'
test_parser branch "${in}" "${match}" "${errmatch}"

# Test with ~ style branch designation. Introduce a type and look
# for correct output but error condition.
in="git://address.com/directory/repo.git~/branch"
match='branch'
errmatch=1
test_parser branch "${in}" "${match}" "${errmatch}"

errmatch=0

# Test multi-/ branches with ~ style branch designation
in="git://address.com/directory/repo.git~branch/name/foo"
match='branch/name/foo'
test_parser branch "${in}" "${match}" "${errmatch}"

# Test multi-/ branches with / style branch designation
in="git://address.com/directory/repo.git/branch/name/foo"
match='branch/name/foo'
test_parser branch "${in}" "${match}" "${errmatch}"

# Test with not .git suffix and ~ style branch designation
in="git://address.com/directory/repo~branch"
match='branch'
test_parser branch "${in}" "${match}" "${errmatch}"

# Test with not .git suffix and ~ style branch designation with multi-/ branches.
in="git://address.com/directory/repo~branch/name/foo"
match='branch/name/foo'
test_parser branch "${in}" "${match}" "${errmatch}"

# Test with not .git suffix and ~ style branch designation
# KNOWN LIMITATION.  This can't know that 'branch' is a branch
# and repo is a repo.  So it will report erroneously.
in="git://address.com/directory/repo/branch"
match=''
test_parser branch "${in}" "${match}" "${errmatch}"
match='branch'
test_parser repo "${in}" "${match}" "${errmatch}"

# Test multi-/ branches with ~ style branch designation with revisions.
in="git://address.com/directory/repo.git~branch/name/foo@1234567"
match='branch/name/foo'
test_parser branch "${in}" "${match}" "${errmatch}"
match='1234567'
test_parser revision "${in}" "${match}" "${errmatch}"

# Test multi-/ branches with ~ style branch designation with revisions.
in="git://address.com/directory/repo.git~branch/name/foo@1234567"
match='branch/name/foo'
test_parser branch "${in}" "${match}" "${errmatch}"
match='1234567'
test_parser revision "${in}" "${match}" "${errmatch}"

# Test multi-/ branches with / style branch designation with revisions.
in="git://address.com/directory/repo.git/branch/name/foo@1234567"
match='branch/name/foo'
test_parser branch "${in}" "${match}" "${errmatch}"
match='1234567'
test_parser revision "${in}" "${match}" "${errmatch}"

# Test multi-/ branches with / style branch designation with revisions
# and no .git suffix on the repo.  This will be bogus because we can't
# know about this situation.
in="git://address.com/directory/repo/branch/name/foo@1234567"
match='' 
test_parser branch "${in}" "${match}" "${errmatch}"
match='foo'
test_parser repo "${in}" "${match}" "${errmatch}"
match='1234567'
test_parser revision "${in}" "${match}" "${errmatch}"
 
# Test single name branches with ~ style branch designation with revisions.
in="git://address.com/directory/repo.git~branch@1234567"
match='branch'
test_parser branch "${in}" "${match}" "${errmatch}"
match='1234567'
test_parser revision "${in}" "${match}" "${errmatch}"
match='repo.git'
test_parser repo "${in}" "${match}" "${errmatch}"

# Test single name branches with / style branch designation with revisions.
in="git://address.com/directory/repo.git/branch@1234567"
match='branch'
test_parser branch "${in}" "${match}" "${errmatch}"
match='1234567'
test_parser revision "${in}" "${match}" "${errmatch}"
match='repo.git'
test_parser repo "${in}" "${match}" "${errmatch}"

# Test single name branches with / style branch designation with
# revisions but no .git suffixed repo.  We can't know this!
in="git://address.com/directory/repo/branch@1234567"
match=''
test_parser branch "${in}" "${match}" "${errmatch}"
match='1234567'
test_parser revision "${in}" "${match}" "${errmatch}"
match='branch'
test_parser repo "${in}" "${match}" "${errmatch}"

# Test .git suffixed repo with revisions.
in="git://address.com/directory/repo.git@1234567"
match=''
test_parser branch "${in}" "${match}" "${errmatch}"
match='1234567'
test_parser revision "${in}" "${match}" "${errmatch}"
match='repo.git'
test_parser repo "${in}" "${match}" "${errmatch}"
match='repo'
test_parser tool "${in}" "${match}" "${errmatch}"

# Test .git suffixed repo with revisions and empty ~ branch.
in="git://address.com/directory/repo.git~@1234567"
match=''
test_parser branch "${in}" "${match}" "${errmatch}"
match='1234567'
test_parser revision "${in}" "${match}" "${errmatch}"
match='repo.git'

# Test .git suffixed repo with revisions and empty / branch.
in="git://address.com/directory/repo.git/@1234567"
match=''
test_parser branch "${in}" "${match}" "${errmatch}"
match='1234567'
test_parser revision "${in}" "${match}" "${errmatch}"
match='repo.git'
test_parser repo "${in}" "${match}" "${errmatch}"

# Introduce 'user@'
in="git://user@address.com/directory/repo.git/branch"
match='user'
test_parser user "${in}" "${match}" "${errmatch}"

# Introduce 'user.name@'
in="git://user.name@address.com/directory/repo.git/branch"
match='user.name'
test_parser user "${in}" "${match}" "${errmatch}"

# Test with different service
in="http://user@address.com/directory/repo.git/branch"
match='http'
test_parser service "${in}" "${match}" "${errmatch}"
match='user'
test_parser user "${in}" "${match}" "${errmatch}"

# Start adding in superfluous @ symbols
errmatch=1
in="git://user@address.com/directory@/repo.git/branch@1234567"
match="user"
test_parser user "${in}" "${match}" "${errmatch}"
match="branch"
test_parser branch "${in}" "${match}" "${errmatch}"
match="1234567"
test_parser revision "${in}" "${match}" "${errmatch}"
match="repo.git"
test_parser repo "${in}" "${match}" "${errmatch}"
match="git://user@address.com/directory@/repo.git"
test_parser url "${in}" "${match}" "${errmatch}"

# Superfluous @ symbols but no 'user' and / branch.
in="git://address.com/directory@/repo.git/branch@1234567"
match=''
test_parser user "${in}" "${match}" "${errmatch}"
match="branch"
test_parser branch "${in}" "${match}" "${errmatch}"
match="1234567"
test_parser revision "${in}" "${match}" "${errmatch}"
match="repo.git"
test_parser repo "${in}" "${match}" "${errmatch}"
match="git://address.com/directory@/repo.git"
test_parser url "${in}" "${match}" "${errmatch}"

# Superfluous @ symbols but no 'user' and multi-/ / branch.
in="git://address.com/directory@/repo.git/branch/name/foo@1234567"
match=''
test_parser user "${in}" "${match}" "${errmatch}"
match="branch/name/foo"
test_parser branch "${in}" "${match}" "${errmatch}"
match="1234567"
test_parser revision "${in}" "${match}" "${errmatch}"
match="repo.git"
test_parser repo "${in}" "${match}" "${errmatch}"
match="git://address.com/directory@/repo.git"
test_parser url "${in}" "${match}" "${errmatch}"

# Superfluous @ symbols but no 'user' and ~ branch.
in="git://address.com/directory@/repo.git~branch@1234567"
match=''
test_parser user "${in}" "${match}" "${errmatch}"
match="branch"
test_parser branch "${in}" "${match}" "${errmatch}"
match="1234567"
test_parser revision "${in}" "${match}" "${errmatch}"
match='repo.git'
test_parser repo "${in}" "${match}" "${errmatch}"

# Superfluous @ symbols but no 'user' and non .git suffixed repo.
in="git://address.com/directory@/repo@1234567"
match=''
test_parser user "${in}" "${match}" "${errmatch}"
match=""
test_parser branch "${in}" "${match}" "${errmatch}"
match="1234567"
test_parser revision "${in}" "${match}" "${errmatch}"
match='repo'
test_parser repo "${in}" "${match}" "${errmatch}"

# Superfluous @ symbols but no 'user' and ~ branch and non .git suffixed repo.
in="git://address.com/directory@/repo~branch@1234567"
match=''
test_parser user "${in}" "${match}" "${errmatch}"
match="branch"
test_parser branch "${in}" "${match}" "${errmatch}"
match="1234567"
test_parser revision "${in}" "${match}" "${errmatch}"
match='repo'
test_parser repo "${in}" "${match}" "${errmatch}"

# Superfluous @ symbols but no 'user' and ~ branch and non .git suffixed repo and multi-/ branches.
in="git://address.com/directory@/repo~branch/name/foo@1234567"
match=''
test_parser user "${in}" "${match}" "${errmatch}"
match="branch/name/foo"
test_parser branch "${in}" "${match}" "${errmatch}"
match="1234567"
test_parser revision "${in}" "${match}" "${errmatch}"
match='repo'
test_parser repo "${in}" "${match}" "${errmatch}"

# This one will bail early even though it's malformed so the error case won't be set.
errmatch=0
in="http://firstname.lastname@address.com/directory@/repo.git/branch"
match='http'
test_parser service "${in}" "${match}" "${errmatch}"
errmatch=1
match='firstname.lastname'
test_parser user "${in}" "${match}" "${errmatch}"

# No repo!  This will use the non .git suffixed code path.
in="http://firstname.lastname@address.com/directory/@1234567"
match=''
test_parser repo "${in}" "${match}" "${errmatch}"
match='http://firstname.lastname@address.com/directory'
test_parser url "${in}" "${match}" "${errmatch}"

errmatch=0
# This will assume that 'directory' is the repository.
in="http://firstname.lastname@address.com/directory~@1234567"
match='directory'
test_parser repo "${in}" "${match}" "${errmatch}"
match='http://firstname.lastname@address.com/directory'
test_parser url "${in}" "${match}" "${errmatch}"

errmatch=1
# No repo! 
in="http://firstname.lastname@address.com/directory/~@1234567"
match=''
test_parser repo "${in}" "${match}" "${errmatch}"
match='http://firstname.lastname@address.com/directory'
test_parser url "${in}" "${match}" "${errmatch}"

# Trailing trash and no valid repo!
in="http://firstname.lastname@address.com/directory///~@1234567"
match=''
test_parser repo "${in}" "${match}" "${errmatch}"
match='http://firstname.lastname@address.com/directory'
test_parser url "${in}" "${match}" "${errmatch}"

errmatch=1
# Trailing trash (extra tildes) and no valid repo!
in="http://firstname.lastname@address.com/directory///~~@1234567"
match=''
test_parser repo "${in}" "${match}" "${errmatch}"

errmatch=1
# Trailing trash (extra tildes) and no valid repo!
in="http://firstname.lastname@address.com/directory///~~@@1234567"
match=''
test_parser repo "${in}" "${match}" "${errmatch}"
match='1234567'
test_parser revision "${in}" "${match}" "${errmatch}"
match=''
test_parser branch "${in}" "${match}" "${errmatch}"
match="http://firstname.lastname@address.com/directory"
test_parser url "${in}" "${match}" "${errmatch}"

errmatch=0
# Trash but we have a valid repo and revision.
in="http://firstname.lastname@address.com/directory/repo.git~~@1234567"
match='repo.git'
test_parser repo "${in}" "${match}" "${errmatch}"
match=''
test_parser branch "${in}" "${match}" "${errmatch}"
match='1234567'
test_parser revision "${in}" "${match}" "${errmatch}"

# Trash but we have a valid repo and revision.
errmatch=0
in="http://firstname.lastname@address.com/directory/repo.git///~~@1234567"
match='repo.git'
test_parser repo "${in}" "${match}" "${errmatch}"
match=''
test_parser branch "${in}" "${match}" "${errmatch}"
match='1234567'
test_parser revision "${in}" "${match}" "${errmatch}"
match=''
test_parser branch "${in}" "${match}" "${errmatch}"
match='http://firstname.lastname@address.com/directory/repo.git'
test_parser url "${in}" "${match}" "${errmatch}"

errmatch=0
# We can't tell that this is an erroneous case so it shouldn't error.
in="http://git.address.com/directory/repo.git/branch~uhoh@1234567"
match='repo.git'
test_parser repo "${in}" "${match}" "${errmatch}"
match='http://git.address.com/directory/repo.git'
test_parser url "${in}" "${match}" "${errmatch}"
match='1234567'
test_parser revision "${in}" "${match}" "${errmatch}"

# because it takes the ~ leg of the .git branch.  There is no 'right'
# way to handle this and we can't detect it.
match='uhoh'
test_parser branch "${in}" "${match}" "${errmatch}"

# This detects 'directory' as the repo but there are too many @
# chars so this generates an error.
errmatch=1
in="http://firstname.lastname@address.com/directory@@@@1234567"
match='directory'
test_parser repo "${in}" "${match}" "${errmatch}"
match='1234567'
test_parser revision "${in}" "${match}" "${errmatch}"
match=''
test_parser branch "${in}" "${match}" "${errmatch}"
match="http://firstname.lastname@address.com/directory"
test_parser url "${in}" "${match}" "${errmatch}"

in="http://address.com/directory/@@@@1234567"
match='http://address.com/directory'
test_parser url "${in}" "${match}" "${errmatch}"
# Because of the trailing slash we can't interpret this as a repo.
match=''
test_parser repo "${in}" "${match}" "${errmatch}"

# Superfluous @ so this will generate errors.
in="http://address.com/directory/////@@@@1234567"
match='http://address.com/directory'
test_parser url "${in}" "${match}" "${errmatch}"


# Superfluous @ so this will generate errors.
in='http://firstname.lastname@address.com/direc@tory/'
match='http://firstname.lastname@address.com/direc@tory'
test_parser url "${in}" "${match}" "${errmatch}"
match=''
test_parser repo "${in}" "${match}" "${errmatch}"
match=''
test_parser revision "${in}" "${match}" "${errmatch}"

errmatch=0
# This is a bit messed up but it's not an error.
in="http://foo@1234567"
match='1234567'
test_parser revision "${in}" "${match}" "${errmatch}"
match='foo'
test_parser repo "${in}" "${match}" "${errmatch}"
match=''
test_parser branch "${in}" "${match}" "${errmatch}"
match='http://foo'
test_parser url "${in}" "${match}" "${errmatch}"

errmatch=1
# No repo so this will generate an error
in="http://@1234567"
match='1234567'
test_parser revision "${in}" "${match}" "${errmatch}"
match=''
test_parser repo "${in}" "${match}" "${errmatch}"
match='http://'
test_parser url "${in}" "${match}" "${errmatch}"

in="http:///@1234567"
match='http://'
test_parser url "${in}" "${match}" "${errmatch}"

in="http://////~~@1234567"
match='http://'
test_parser url "${in}" "${match}" "${errmatch}"

in="http://////~~~~@@@@@1234567"
match='http://'
test_parser url "${in}" "${match}" "${errmatch}"
match=''
test_parser repo "${in}" "${match}" "${errmatch}"
match=''
test_parser branch "${in}" "${match}" "${errmatch}"
match='1234567'
test_parser revision "${in}" "${match}" "${errmatch}"


errmatch=0
in="http://repo.git@1234567"
match='http://repo.git'
test_parser url "${in}" "${match}" "${errmatch}"
match='repo.git'
test_parser repo "${in}" "${match}" "${errmatch}"
match=''
test_parser branch "${in}" "${match}" "${errmatch}"
match='1234567'
test_parser revision "${in}" "${match}" "${errmatch}"
match='http://repo.git'
test_parser url "${in}" "${match}" "${errmatch}"


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

in="http://repo.git~branch@12334677"
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

in="http://repo.git~multi/part/branch@12334677"
match='http://repo.git'
test_parser url "${in}" "${match}" "${errmatch}"
match='repo.git'
test_parser repo "${in}" "${match}" "${errmatch}"
match='multi/part/branch'
test_parser branch "${in}" "${match}" "${errmatch}"
match='12334677'
test_parser revision "${in}" "${match}" "${errmatch}"
match='repo'
test_parser tool "${in}" "${match}" "${errmatch}"

in="http://repo.git~multi/part/branch/@12334677"
match='http://repo.git'
test_parser url "${in}" "${match}" "${errmatch}"
match='repo.git'
test_parser repo "${in}" "${match}" "${errmatch}"
match='multi/part/branch'
test_parser branch "${in}" "${match}" "${errmatch}"
match='12334677'
test_parser revision "${in}" "${match}" "${errmatch}"
match='repo'
test_parser tool "${in}" "${match}" "${errmatch}"

# Try it with numeric urls.
in="http://firstname.lastname@127.0.0.1/directory/repo.git"
match='http'
test_parser service "${in}" "${match}" "${errmatch}"
match='firstname.lastname'
test_parser user "${in}" "${match}" "${errmatch}"
match=''
test_parser revision "${in}" "${match}" "${errmatch}"
match=''
test_parser branch "${in}" "${match}" "${errmatch}"
match='repo.git'
test_parser repo "${in}" "${match}" "${errmatch}"
match='repo'
test_parser tool "${in}" "${match}" "${errmatch}"
match='http://firstname.lastname@127.0.0.1/directory/repo.git'
test_parser url "${in}" "${match}" "${errmatch}"

errmatch=
in="repo.git/funky_branch-name@12334677"
match=''
test_parser service "${in}" "${match}" "${errmatch}"
match=''
test_parser user "${in}" "${match}" "${errmatch}"
match='12334677'
test_parser revision "${in}" "${match}" "${errmatch}"
match='funky_branch-name'
test_parser branch "${in}" "${match}" "${errmatch}"
match='repo.git'
test_parser repo "${in}" "${match}" "${errmatch}"
match='repo'
test_parser tool "${in}" "${match}" "${errmatch}"
match='repo.git'
test_parser url "${in}" "${match}" "${errmatch}"

in="repo.git~funky/branch-name@12334677"
match=''
test_parser service "${in}" "${match}" "${errmatch}"
match=''
test_parser user "${in}" "${match}" "${errmatch}"
match='12334677'
test_parser revision "${in}" "${match}" "${errmatch}"
match='funky/branch-name'
test_parser branch "${in}" "${match}" "${errmatch}"
match='repo.git'
test_parser repo "${in}" "${match}" "${errmatch}"
match='repo'
test_parser tool "${in}" "${match}" "${errmatch}"
match='repo.git'
test_parser url "${in}" "${match}" "${errmatch}"


errmatch=
in="repo/funky_branch-name@12334677"
match=''
test_parser service "${in}" "${match}" "${errmatch}"
match=''
test_parser user "${in}" "${match}" "${errmatch}"
match='12334677'
test_parser revision "${in}" "${match}" "${errmatch}"
match=''
test_parser branch "${in}" "${match}" "${errmatch}"
match='funky_branch-name'
test_parser repo "${in}" "${match}" "${errmatch}"
match='funky_branch-name'
test_parser tool "${in}" "${match}" "${errmatch}"
# Unfortunately this is the case because 'funky_branch-name'
# is parsed as the repo.
match='repo/funky_branch-name'
test_parser url "${in}" "${match}" "${errmatch}"

errmatch=
in="repo~funky/branch-name@1234567"
match=''
test_parser service "${in}" "${match}" "${errmatch}"
match=''
test_parser user "${in}" "${match}" "${errmatch}"
match='1234567'
test_parser revision "${in}" "${match}" "${errmatch}"
match='funky/branch-name'
test_parser branch "${in}" "${match}" "${errmatch}"
match='repo'
test_parser repo "${in}" "${match}" "${errmatch}"

errmatch=
in="repo@12334677"
match=''
test_parser service "${in}" "${match}" "${errmatch}"
match=''
test_parser user "${in}" "${match}" "${errmatch}"
match='12334677'
test_parser revision "${in}" "${match}" "${errmatch}"
match=''
test_parser branch "${in}" "${match}" "${errmatch}"
match='repo'
test_parser repo "${in}" "${match}" "${errmatch}"
match='repo'
test_parser tool "${in}" "${match}" "${errmatch}"
match='repo'
test_parser url "${in}" "${match}" "${errmatch}"


errmatch=
in="repo.git/multi/part/branch-name@12334677"
match=''
test_parser service "${in}" "${match}" "${errmatch}"
match=''
test_parser user "${in}" "${match}" "${errmatch}"
match='12334677'
test_parser revision "${in}" "${match}" "${errmatch}"
match='multi/part/branch-name'
test_parser branch "${in}" "${match}" "${errmatch}"
match='repo.git'
test_parser repo "${in}" "${match}" "${errmatch}"
match='repo'
test_parser tool "${in}" "${match}" "${errmatch}"
match='repo.git'
test_parser url "${in}" "${match}" "${errmatch}"

in="repo/multi/part/branch-name@12334677"
match=''
test_parser branch "${in}" "${match}" "${errmatch}"
# The unfortunate situation when there's not .git
match='branch-name'
test_parser repo "${in}" "${match}" "${errmatch}"

errmatch=1
in="repo/multi/pa@rt/branch-name@12334677"
match=''
test_parser branch "${in}" "${match}" "${errmatch}"
# The unfortunate situation when there's not .git
match='branch-name'
test_parser repo "${in}" "${match}" "${errmatch}"

#totals; exit 1

errmatch=
in="repo.git@123/34677"
match=''
test_parser revision "${in}" "${match}" "${errmatch}"

errmatch=1
in="repo.git//@123/34677"
match=''
test_parser revision "${in}" "${match}" "${errmatch}"
match='repo.git'
test_parser url "${in}" "${match}" "${errmatch}"

in="repo.git//~~~@@@123/34677"
match='repo.git'
test_parser url "${in}" "${match}" "${errmatch}"
match=''
test_parser revision "${in}" "${match}" "${errmatch}"
match='repo.git'
test_parser repo "${in}" "${match}" "${errmatch}"
match=''
# This will fail.. but this is getting ridiculous.
#test_parser $BASH_LINENO branch "${in}" "${match}" "${errmatch}"


errmatch=1
in="re@po.git@1234567"
match='1234567'
test_parser revision "${in}" "${match}" "${errmatch}"
match='re@po.git'
test_parser repo "${in}" "${match}" "${errmatch}"
match=''
test_parser branch "${in}" "${match}" "${errmatch}"

in="re@po.git@1234567"
match=''
test_parser user "${in}" "${match}" "${errmatch}"

in="re@po.git@123@4567"
match='4567'
test_parser revision "${in}" "${match}" "${errmatch}"

errmatch=

in="http://user.name@git.linaro.org/git/toolchain/repo.git@1234567"
match='1234567'
test_parser revision "${in}" "${match}" "${errmatch}"
match='user.name'
test_parser user "${in}" "${match}" "${errmatch}"

in="http://user.name@git.linaro.org/git/toolchain/repo.git@1234~67"
match=''
test_parser revision "${in}" "${match}" "${errmatch}"
# Screwy but true.
match='67'
test_parser branch "${in}" "${match}" "${errmatch}"

in="http://user.name@git.linaro.org/git/toolchain/repo.git@1234#67"
match=''
test_parser revision "${in}" "${match}" "${errmatch}"

in="http://user.name@git.linaro.org/git/toolch#ain/repo.git@1234567"
match='1234567'
test_parser revision "${in}" "${match}" "${errmatch}"

in="http://user.name@git.linaro.org/git/toolchain/repo.git@1234@67"
match='67'
test_parser revision "${in}" "${match}" "${errmatch}"

in="http://user.name@git.linaro.org/git/toolchain/repo.git@1234@67"
match='repo.git'
test_parser repo "${in}" "${match}" "${errmatch}"
match='67'
test_parser revision "${in}" "${match}" "${errmatch}"

in="http://user.name@git.linaro.org/git/toolchain/repo@1234567"
match='repo'
test_parser repo "${in}" "${match}" "${errmatch}"

in="http://user.name@git.linaro.org/git/toolchain/repo@12345@67"
match='repo'
test_parser repo "${in}" "${match}" "${errmatch}"

in="http://user.name@git.linaro.org/git/toolchain/repo.git/multi/part/branch-name@12345@67"
match='repo.git'
test_parser repo "${in}" "${match}" "${errmatch}"
match='multi/part/branch-name'
test_parser branch "${in}" "${match}" "${errmatch}"

in="http://user.name@git.linaro.org/git/toolchain/repo/multi/part/branch-name@12345@67"
match='branch-name'
test_parser repo "${in}" "${match}" "${errmatch}"
match=''
test_parser branch "${in}" "${match}" "${errmatch}"

in="http://user.name@git.linaro.org/git/toolchain/repo~multi/part/branch-name@12345@67"
match='repo'
test_parser repo "${in}" "${match}" "${errmatch}"
match='multi/part/branch-name'
test_parser branch "${in}" "${match}" "${errmatch}"
# This should error as it has an superfluous @ in the revision.
# It will give a bogus revision.
errmatch=1
match='67'
test_parser revision "${in}" "${match}" "${errmatch}"
errmatch=
match='http://user.name@git.linaro.org/git/toolchain/repo'
test_parser url "${in}" "${match}" "${errmatch}"


in="http://user.name@git.linaro.org/git/toolchain/repo~multi/part/branch-name@12345@"
# This should error as it has an superfluous @ in the revision.
# It will give a bogus revision.
errmatch=1
match=''
test_parser revision "${in}" "${match}" "${errmatch}"

in="http://user.name@git.linaro.org/git/toolchain/repo~multi/part/branch-name@"
# This should error as it has an superfluous @ in the revision.
# It will give a bogus revision.
errmatch=1
match=''
test_parser revision "${in}" "${match}" "${errmatch}"

in="http://user.name@git.linaro.org/git/toolchain/repo~multi/part/branch-name@@@@"
# This should error as it has an superfluous @ in the revision.
# It will give a bogus revision.
errmatch=1
match=''
test_parser revision "${in}" "${match}" "${errmatch}"

in="http://user.name@git.linaro.org/git/toolchain/repo~multi/part/branch-name@@@@1234567"
# This should error as it has an superfluous @ in the revision.
# It will give a bogus revision.
errmatch=1
match='1234567'
test_parser revision "${in}" "${match}" "${errmatch}"

# The following tests all have a superflous / after the ~
errmatch=1
# This will strip the superflous / in between ~ and multi
in="http://user.name@git.linaro.org/git/toolchain/repo~/multi/part/branch-name@12345@67"
match='repo'
test_parser repo "${in}" "${match}" "${errmatch}"
match='multi/part/branch-name'
test_parser branch "${in}" "${match}" "${errmatch}"
match='http://user.name@git.linaro.org/git/toolchain/repo'
test_parser url "${in}" "${match}" "${errmatch}"

errmatch=0
# This will strip the superflous / in between ~ and multi
in="infrastructure/mpc-1.0.1.tar.gz"
match='mpc'
test_parser repo "${in}" "${match}" "${errmatch}"
match=''
test_parser branch "${in}" "${match}" "${errmatch}"
match=''
test_parser revision "${in}" "${match}" "${errmatch}"
match='infrastructure/mpc-1.0.1.tar.gz'
test_parser url "${in}" "${match}" "${errmatch}"
match='mpc'
test_parser tag "${in}" "${match}" "${errmatch}"

errmatch=0
in="http://user.name@git.linaro.org/git/toolchain/repo.git~multi/part/branch-name@1234567"
match='repo.git~multi-part-branch-name@1234567'
test_parser tag "${in}" "${match}" "${errmatch}"

in="http://user.name@git.linaro.org/git/toolchain/repo.git/multi/part/branch-name@1234567"
match='repo.git~multi-part-branch-name@1234567'
test_parser tag "${in}" "${match}" "${errmatch}"

in="http://user.name@git.linaro.org/git/toolchain/repo.git@1234567"
match='repo.git@1234567'
test_parser tag "${in}" "${match}" "${errmatch}"

errmatch=
