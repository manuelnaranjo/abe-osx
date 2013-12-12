#!/bin/sh

testcbuild2="`basename $0`"

# The directory where the script lives.
topdir="`dirname $0`"
cbuild2="`realpath $0`"
topdir="`dirname ${cbuild2}`"
export cbuild_path=${topdir}

# We need a host.conf file to squelch cbuild2 error messages.
created_host_conf=
if test ! -e "${PWD}/host.conf"; then
    echo "Creating temporary host.conf file as ${PWD}/host.conf"
    echo "cbuild_path=${cbuild_path}" > ${PWD}/host.conf
    # source the host.conf file to get the values exported.
    . ${PWD}/host.conf
    created_host_conf="yes"
fi

# Source common.sh for some common utilities.
. ${topdir}/lib/common.sh || exit 1

# Override $local_snapshots so that the local_snapshots directory
# of an existing build is not moved or damaged.  This affects all
# called instances of cbuild2.sh below.
export local_snapshots="`mktemp -d /tmp/cbuild2.$$.XXX`/snapshots"
export sources_conf=${topdir}testsuite/test_sources.conf
export remote_snapshots=http://cbuild.validation.linaro.org/snapshots
export wget_bin=/usr/bin/wget
export wget_quiet=yes

# Create the snapshots/ subdir before it is used.
# It's possible that /tmp is out of space and this will fail.
out="`mkdir -p ${local_snapshots}`"
if test "$?" -gt 0; then
    exit 1
fi

usage()
{
    echo "  ${testcbuild2} [--debug|-v]"
    echo "                 [--md5sums <path/to/alternative/snapshots/md5sums>]"
    echo ""
    echo "  ${testcbuild2} is the cbuild2 frontend command conformance test."
    echo ""
    echo " ${testcbuild2} should be run from the source directory."
}

passes=0

pass()
{
    local testlineno=$1
    if test x"${debug}" = x"yes"; then
	echo -n "($testlineno) " 1>&2
    fi
    echo "PASS: '$2'"
    passes="`expr ${passes} + 1`"
}

failures=0
fail()
{
    local testlineno=$1
    if test x"${debug}" = x"yes"; then
	echo -n "($testlineno) " 1>&2
    fi
    echo "FAIL: '$2'"
    failures="`expr ${failures} + 1`"
}

totals()
{
    echo ""
    echo "Total test results:"
    echo "	Passes: ${passes}"
    echo "	Failures: ${failures}"
}



cbtest()
{
     local testlineno=$1
     case "$2" in
	 *$3*)
             pass ${testlineno} "$4"
             ;;
         *)
             fail ${testlineno} "$4"
             ;;
     esac
}

m5sums=
debug=
while test $# -gt 0; do
    case "$1" in
	--h*|-h)
	    usage
	    exit 1
	    ;;
	--deb*|-deb|-v)
	    debug="yes"
	    ;;
	--md5*|-md5*)
	    if test `echo $1 | grep -c "\-md5.*="` -gt 0; then
		error "A '=' is invalid after --md5sums. A space is expected."
		exit 1;
	    fi
	    if test -z $2; then
		error "--md5sums requires a path to an md5sums file."
		exit 1;
	    fi 
	    md5sums=$2
	    if test ! -e "$md5sums"; then
		error "Path to md5sums is invalid."
		exit 1;
	    fi
	    echo "Copying ${md5sums} to ${local_snapshots} for snapshots file."
	    cp ${md5sums} ${local_snapshots}
	    ;; 
	*)
	    ;;
    esac

    if test $# -gt 0; then
	shift
    fi
done

if test ! -e "${local_snapshots}/md5sums"; then
    out="`fetch md5sums 2>/dev/null`"
    if test $? -gt 0; then
	echo "Failed to fetch md5sums.  Use --snapshots for offline mode." 1>&2 
	exit 1;
    fi
    echo "Using ${local_snapshots}/md5sums for snapshots file."
fi

test_failure()
{
    local testlineno=$BASH_LINENO
    local cb_commands=$1
    local match=$2
    local out=

    out="`./cbuild2.sh ${cb_commands} 2>&1 | grep "${match}" | sed -e 's:\(^ERROR\).*\('"${match}"'\).*:\1 \2:'`"
    cbtest ${testlineno} "${out}" "ERROR ${match}" "ERROR ${cb_commands}"
}

test_pass()
{
    local testlineno=$BASH_LINENO
    local cb_commands=$1
    local match=$2
    local out=

    # Continue to search for error so we don't get false positives.
    out="`./cbuild2.sh ${cb_commands} 2>&1 | grep "${match}" | sed -e 's:\(^ERROR\).*\('"${match}"'\).*:\1 \2:'`"
    cbtest ${testlineno} "${out}" "${match}" "VALID ${cb_commands}"
}

cb_commands="--dry-run"
match="Complete build process took"
test_pass "${cb_commands}" "${match}"

cb_commands="--dryrun"
match="Complete build process took"
test_pass "${cb_commands}" "${match}"

cb_commands="--dry"
match="Complete build process took"
test_pass "${cb_commands}" "${match}"

cb_commands="-dry"
match="Complete build process took"
test_pass "${cb_commands}" "${match}"

cb_commands="--dr"
match="Command not recognized"
test_failure "${cb_commands}" "${match}"

cb_commands="-dr"
match="Command not recognized"
test_failure "${cb_commands}" "${match}"

cb_commands="--drnasdfa"
match="Command not recognized"
test_failure "${cb_commands}" "${match}"

# Test for expected failure for removed deprecated feature --dostep.
cb_commands="--dostep"
match="Command not recognized"
test_failure "${cb_commands}" "${match}"

cb_commands="--target=foo"
match="A space is expected"
test_failure "${cb_commands}" "${match}"

cb_commands="--target"
match="target requires a directive"
test_failure "${cb_commands}" "${match}"

cb_commands="--timeout"
match="timeout requires a directive"
test_failure "${cb_commands}" "${match}"

cb_commands="--timeout=foo"
match="A space is expected"
test_failure "${cb_commands}" "${match}"

cb_commands="--timeout 25"
match=''
test_pass "${cb_commands}" "${match}"

cb_commands="--target foo"
match="Complete build process took"
test_pass "${cb_commands}" "${match}"

cb_commands="--build=all"
match="A space is expected"
test_failure "${cb_commands}" "${match}"

cb_commands="--dryrun --build --foobar"
match="found the next"
test_failure "${cb_commands}" "${match}"

cb_commands="--dryrun --build"
match="requires a directive"
test_failure "${cb_commands}" "${match}"

cb_commands="--checkout"
match="requires a directive"
test_failure "${cb_commands}" "${match}"

cb_commands="--checkout=all"
match="A space is expected"
test_failure "${cb_commands}" "${match}"

cb_commands="--checkout --all"
match="found the next"
test_failure "${cb_commands}" "${match}"

cb_commands="--checkout --foo"
match="found the next"
test_failure "${cb_commands}" "${match}"

cb_commands="--dryrun --checkout all"
match=''
test_pass "${cb_commands}" "${match}"

cb_commands="--dryrun --checkout gcc.git"
match=''
test_pass "${cb_commands}" "${match}"




cb_commands="--dryrun --target arm-none-linux-gnueabihf --checkout glibc.git"
match=''
test_pass "${cb_commands}" "${match}"

cb_commands="--dryrun --target arm-none-linux-gnueabihf --checkout=glibc.git"
match="A space is expected"
test_failure "${cb_commands}" "${match}"

cb_commands="--dryrun --target arm-none-linux-gnueabihf --checkout all"
match=''
test_pass "${cb_commands}" "${match}"

libc="glibc"
target="aarch64-none-elf"
cb_commands="--target ${target} --set libc=${libc}"
match="crosscheck_clibrary_target"
test_failure "${cb_commands}" "${match}"

cb_commands="--set=libc=glibc"
match="A space is expected"
test_failure "${cb_commands}" "${match}"

cb_commands="--set"
match="requires a directive"
test_failure "${cb_commands}" "${match}"

cb_commands="--release=foobar"
match="A space is expected"
test_failure "${cb_commands}" "${match}"

cb_commands="--release"
match="requires a directive"
test_failure "${cb_commands}" "${match}"

target="aarch64-none-elf"
libc="foo"
cb_commands="--target ${target} --set libc=${libc}"
match="set_package"
test_failure "${cb_commands}" "${match}"

target="aarch64-none-elf"
libc="eglibc"
cb_commands="--target ${target} --set libc=${libc}"
match="crosscheck_clibrary_target"
test_failure "${cb_commands}" "${match}"

target="aarch64-none-elf"
libc="glibc"
cb_commands="--target ${target} --set libc=${libc}"
match="crosscheck_clibrary_target"
test_failure "${cb_commands}" "${match}"

target="aarch64-none-elf"
# A baremetal target should pick the right clibrary (newlib)
cb_commands="--target ${target}"
match=''
test_pass "${cb_commands}" "${match}"

target="aarch64-none-elf"
libc="newlib"
cb_commands="--target ${target} --set libc=${libc}"
match=''
test_pass "${cb_commands}" "${match}"

cb_commands="--snapshots"
match='requires a directive'
test_failure "${cb_commands}" "${match}"

cb_commands="--snapshots --sooboo"
match='found the next'
test_failure "${cb_commands}" "${match}"

cb_commands="--snapshots=foo/bar --build all"
match="A space is expected"
test_failure "${cb_commands}" "${match}"

cb_commands="--dryrun --snapshots ${local_snapshots} --build all"
match=''
test_pass "${cb_commands}" "${match}"

cb_commands="--dryrun --build gcc.git"
match=''
test_pass "${cb_commands}" "${match}"

cb_commands="--dryrun --build asdflkajsdflkajsfdlasfdlaksfdlkaj.git"
match="Couldn't find the source for"
test_failure "${cb_commands}" "${match}"

cb_commands="--set"
match='requires a directive'
test_failure "${cb_commands}" "${match}"

cb_commands="--set --foobar"
match='found the next'
test_failure "${cb_commands}" "${match}"

cb_commands="--set=libc=glibc"
match="A space is expected"
test_failure "${cb_commands}" "${match}"

cb_commands="--set gcc=meh"
match="'gcc' is not a supported package"
test_failure "${cb_commands}" "${match}"

cb_commands="--set libc=glibc"
match=''
test_pass "${cb_commands}" "${match}"

cb_commands="glibc=glibc.git"
match=''
test_pass "${cb_commands}" "${match}"

target="aarch64-none-elf"
cb_commands="--target ${target} glibc=glibc.git"
match="crosscheck_clibrary_target"
test_failure "${cb_commands}" "${match}"

target="aarch64-none-elf"
cb_commands="--target ${target} eglibc=eglibc.git"
match="crosscheck_clibrary_target"
test_failure "${cb_commands}" "${match}"

target="aarch64-none-elf"
cb_commands="--target ${target} newlib=newlib.git"
match=''
test_pass "${cb_commands}" "${match}"

tmpdir=`dirname ${local_snapshots}`

# If the tests pass successfully clean up /tmp/<tmpdir> but only if the
# directory name is conformant.  We don't want to accidentally remove /tmp.
if test x"${tmpdir}" = x"/tmp"; then
    echo ""
    echo "\n${local_snapshots} doesn't conform to /tmp/<tmpdir>/snapshots. Not safe to remove."
elif test -d "${tmpdir}/snapshots" -a ${failures} -lt 1; then
    echo ""
    echo "${testcbuild2} finished with no unexpected failures. Removing ${tmpdir}"
    rm -rf ${tmpdir}
fi

if test x"$created_host_conf" = x"yes"; then
    echo "Removing temporary ${PWD}/host.conf file."
    rm ${PWD}/host.conf
fi

# ----------------------------------------------------------------------------------
# print the total of test results
totals

exit 0
