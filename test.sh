#!/bin/sh

testcbuild2="`basename $0`"

# The directory where the script lives.
topdir="`dirname $0`"

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
    echo "  ${testcbuild2} [--snapshots <path/to/snapshots/md5sums>]"
    echo ""
    echo "  ${testcbuild2} is the cbuild2 frontend command conformance test."
    echo ""
    echo " ${testcbuild2} should be run from the source directory."
}

pass()
{
    echo "PASS: '$1'"
}

fail()
{
    echo "FAIL: '$1'"
}

cbtest()
{
     case "$1" in
	 *$2*)
             pass "$3"
             ;;
         *)
             fail "$3"
             ;;
     esac
}

m5sums=
while test $# -gt 0; do
    case "$1" in
	--h*|-h)
	    usage
	    exit 1
	    ;;
	--snap*|-snap*)
	    if test `echo $1 | grep -c "\-snap.*="` -gt 0; then
		error "A '=' is invalid after --snapshots. A space is expected."
		exit 1;
	    fi
	    if test -z $2; then
		error "--snapshots requires a path to an md5sums file."
		exit 1;
	    fi 
	    md5sums=$2
	    if test ! -e "$md5sums"; then
		error "Path to snapshots/md5sums is invalid."
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

test_xfailure()
{
    local cb_commands=$1
    local match=$2
    local out
    out="`./cbuild2.sh ${cb_commands} 2>&1 | grep "${match}" | sed -e 's:\(^ERROR\).*\('"${match}"'\).*:\1 \2:'`"
    cbtest "${out}" "ERROR ${match}" "ERROR ${cb_commands}"
}

test_xpass()
{
    local cb_commands=$1
    local match=$2
    local out
    # Continue to search for error so we don't get false positives.
    out="`./cbuild2.sh ${cb_commands} 2>&1 | grep "${match}" | sed -e 's:\(^ERROR\).*\('"${match}"'\).*:\1 \2:'`"
    cbtest "${out}" "${match}" "VALID ${cb_commands}"
}

cb_commands="--dry-run"
match="Complete build process took"
test_xpass "${cb_commands}" "${match}"

cb_commands="--dryrun"
match="Complete build process took"
test_xpass "${cb_commands}" "${match}"

cb_commands="--dryrunas"
match="Command not recognized"
test_xfailure "${cb_commands}" "${match}"

cb_commands="--target=foo"
match="A space is expected"
test_xfailure "${cb_commands}" "${match}"

cb_commands="--target foo"
match="Complete build process took"
test_xpass "${cb_commands}" "${match}"

cb_commands="--build=all"
match="A space is expected"
test_xfailure "${cb_commands}" "${match}"

exit 0
