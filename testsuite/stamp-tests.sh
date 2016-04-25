#!/bin/bash
stamp_fixme()
{
    local buglineno=$1
    if test x"${debug}" = x"yes"; then
	shift
	echo "(${buglineno}): $*"
    fi
}

echo "============= get_stamp_name() tests ================"

test_get_stamp_name()
{
    local buglineno=$BASH_LINENO
    local feature="get"
    local in="$1"
    local match="$2"
    local errmatch="$3"
    local ret=
    local out=

    if test x"${debug}" = x"yes"; then
	out="`${feature}_stamp_name ${in}`"
    else
	out="`${feature}_stamp_name ${in} 2>/dev/null`"
    fi
    ret=$?

    if test x"${debug}" = x"yes"; then
	echo -n "($buglineno) " 1>&2
    fi
    if test x"${out}" = x"${match}"; then
        pass "${feature}_stamp_name ${in} expected '${match}'"
    else 
        fail "${feature}_stamp_name ${in} expected '${match}'"
        stamp_fixme "${buglineno}" "'${feature}_stamp_name ${in}' expected '${match}' but returned '${out}'"
    fi

    if test x"${errmatch}" != x; then
	if test x"${debug}" = x"yes"; then
	    echo -n "($buglineno) " 1>&2
	fi

	if test x"${errmatch}" = x"${ret}"; then
	    pass "${feature}_stamp_name ${in} expected return value '${errmatch}'"
	else
	    fail "'${feature}_stamp_name ${in}' expected return value '${errmatch}'"
	    stamp_fixme "${buglineno}" "'${feature}_stamp_name ${in}' expected '${errmatch}' but returned '${ret}'"
	fi
    fi

    # Always return ret.  An individual test might have 'passed', as-in it
    # returned the expected result, but we still might want to check if there
    # was an error with the stamps.
    return ${ret}
}

errmatch=0
in="configure gcc.git"
match="gcc.git-configure.stamp"
test_get_stamp_name "${in}" "${match}" "${errmatch}"

in="configure infrastructure/mpc-1.0.1.tar.xz"
match="mpc-1.0.1-configure.stamp"
test_get_stamp_name "${in}" "${match}" "${errmatch}"

in="configure gcc.git stage2"
match="gcc.git-stage2-configure.stamp"
test_get_stamp_name "${in}" "${match}" "${errmatch}"

in="configure gcc.git~bzr/custom_branch"
match="gcc.git~bzr-custom_branch-configure.stamp"
test_get_stamp_name "${in}" "${match}" "${errmatch}"

in="configure gcc.git~bzr/custom_branch stage2"
match="gcc.git~bzr-custom_branch-stage2-configure.stamp"
test_get_stamp_name "${in}" "${match}" "${errmatch}"

in="configure gcc.git@1234567"
match="gcc.git@1234567-configure.stamp"
test_get_stamp_name "${in}" "${match}" "${errmatch}"

in="configure gcc.git@1234567 stage2"
match="gcc.git@1234567-stage2-configure.stamp"
test_get_stamp_name "${in}" "${match}" "${errmatch}"

in="configure gcc.git~bzr/custom_branch@1234567"
match="gcc.git~bzr-custom_branch@1234567-configure.stamp"
test_get_stamp_name "${in}" "${match}" "${errmatch}"

in="configure gcc.git~bzr/custom_branch@1234567 stage2"
match="gcc.git~bzr-custom_branch@1234567-stage2-configure.stamp"
test_get_stamp_name "${in}" "${match}" "${errmatch}"

in="configure gcc-4.8-foo-bar_fiddle.diddle.tar.bz2"
match="gcc-4.8-foo-bar_fiddle.diddle-configure.stamp"
test_get_stamp_name "${in}" "${match}" "${errmatch}"

in="build infrastructure/linux-linaro-3.11-rc6-2013.08.tar.bz2"
match="linux-linaro-3.11-rc6-2013.08-build.stamp"
test_get_stamp_name "${in}" "${match}" "${errmatch}"

errmatch=0
in="configure http://.git.linaro.org/git/toolchain/gcc.git"
match="gcc.git-configure.stamp"
test_get_stamp_name "${in}" "${match}" "${errmatch}"


in="build gcc.git"
match="gcc.git-build.stamp"
test_get_stamp_name "${in}" "${match}" "${errmatch}"

in="fetch mpc.1.4.tar.gz"
match="mpc.1.4-fetch.stamp"
test_get_stamp_name "${in}" "${match}" "${errmatch}"

in="extract mpc.1.4.tar.gz"
match="mpc.1.4-extract.stamp"
test_get_stamp_name "${in}" "${match}" "${errmatch}"

errmatch=1
in="bogusstamp gcc.git"
match=""
test_get_stamp_name "${in}" "${match}" "${errmatch}"

# Partial match of a valid stamp SHOULDN'T match.
errmatch=1
in="buildfoo gcc.git"
match=""
test_get_stamp_name "${in}" "${match}" "${errmatch}"

# Partial match of a valid stamp SHOULDN'T match.
errmatch=1
in="foobuild gcc.git"
match=""
test_get_stamp_name "${in}" "${match}" "${errmatch}"

# Partial match of a valid stamp SHOULDN'T match.
errmatch=1
in="build http://@revision"
match=""
test_get_stamp_name "${in}" "${match}" "${errmatch}"

echo "============= check_stamp () and create_stamp () tests ================"

# Only test these outside of an active build tree since they write
# to the ${local_builds} directory.

test_check_stamp()
{
    local buglineno=$BASH_LINENO
    local feature="check"
    local testing="$1"
    local in="$2"
    local match="$3"
    local ret=
    local out=

    if test x"${debug}" = x"yes"; then
	out="`${feature}_stamp ${in}`"
    else
	out="`${feature}_stamp ${in} 2>/dev/null`"
    fi
    ret=$?

    if test x"${debug}" = x"yes"; then
	echo -n "($buglineno) " 1>&2
    fi

    if test x"${match}" = x"${ret}"; then
        pass "${feature}_stamp: ${testing} expected return value '${match}'"
    else
        fail "'${feature}_stamp: ${testing}' expected return value '${match}'"
        stamp_fixme "${buglineno}" "'${feature}_stamp ${in}' expected '${match}' but returned '${ret}'"
    fi
    
    # Always return ret.  An individual test might have 'passed', as-in it
    # returned the expected result, but we still might want to check if there
    # was an error with the stamps.
    return ${ret}
}

test_create_stamp()
{
    local buglineno=$BASH_LINENO
    local feature="create"
    local testing="$1"
    local in="$2"
    local match="$3"
    local ret=
    local out=

    if test x"${debug}" = x"yes"; then
	out="`${feature}_stamp ${in}`"
    else
	out="`${feature}_stamp ${in} 2>/dev/null`"
    fi
    ret=$?

    if test x"${debug}" = x"yes"; then
	echo -n "($buglineno) " 1>&2
    fi

    if test x"${match}" = x"${ret}"; then
        pass "${feature}_stamp: ${testing} expected return value '${match}'"
    else
        fail "'${feature}_stamp: ${testing}' expected return value '${match}'"
        stamp_fixme "${buglineno}" "'${feature}_stamp ${in}' expected '${match}' but returned '${ret}'"
    fi
    
    # Always return ret.  An individual test might have 'passed', as-in it
    # returned the expected result, but we still might want to check if there
    # was an error with the stamps.
    return ${ret}
}


stamp_name="`get_stamp_name configure gcc.git~bzr/custom_branch@1234567 stage2`"
testing="check_stamp: no existing stamp."
check_dir="${local_snapshots}/stamp_checkdir"
if test -d ${local_builds} -a ! -e "${PWD}/host.conf"; then
    if test x"${stamp_name}" = x; then
	echo "get_stamp_name failed prior to check_stamp tests."
	exit 1
    fi

    # A fake temporary gcc.git directory used for testing.
    mkdir -p ${check_dir}
    # We need time between when we create the directory and when we create
    # the stamp so that the modifications times differ.
    sleep 1

    in="${local_builds} ${stamp_name} ${check_dir} configure no"
    ret=1
    test_check_stamp "${testing}" "${in}" "${ret}"
else
    untested "${testing}"
fi

if test -d ${local_builds} -a ! -e "${PWD}/host.conf"; then
    testing="create_stamp: Create a new stamp: ${local_builds}/${stamp_name}"
    in="${local_builds} ${stamp_name}"
    ret=0
    test_create_stamp "${testing}" "${in}" "${ret}"
else
    testing="create_stamp: Create a new stamp."
    untested "${testing}"
fi

testing="check_stamp: Check a just created stamp."
if test -d ${local_builds} -a ! -e "${PWD}/host.conf"; then
    in="${local_builds} ${stamp_name} ${check_dir} configure no"
    ret=0
    test_check_stamp "${testing}" "${in}" "${ret}"
else
    untested "${testing}"
fi

testing="check_stamp: Check a newer compare file."
if test -d ${local_builds} -a ! -e "${PWD}/host.conf"; then

    # This should update the time stamp on the ${check_dir}.
    rmdir ${check_dir}/

    # We need time between when the stamp was created and when we modify the
    # check dir so so that the modifications times differ.
    sleep 1

    mkdir -p ${check_dir}

    in="${local_builds} ${stamp_name} ${check_dir} configure no"
    ret=1
    test_check_stamp "${testing}" "${in}" "${ret}"
else
    untested "${testing}"
fi

testing="check_stamp: Check a bogus check file."
if test -d ${local_builds} -a ! -e "${PWD}/host.conf"; then

    in="${local_builds} ${stamp_name} ${local_builds}/bogusfile configure no"
    ret=255
    test_check_stamp "${testing}" "${in}" "${ret}"
else
    untested "${testing}"
fi
