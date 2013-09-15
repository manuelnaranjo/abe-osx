#!/bin/sh

#
# This makes a a release tarball Linaro style. Note that this does NOT
# test building the soure, nor do it run any tests. it just packages
# everything necesary for the release.
#

# Get the tool name, which we use to differenciate between the various
# release processes.
get_tool()
{
    # tool names look like gdb-linaro-VERSION
    tool="`echo $1 | sed -e 's:-[0-9].*::'`"
    case ${tool} in
	eglibc*)
	    tool=eglibc
	    ;;
	binutils*)
	    tool=binutils
	    ;;
	newlib*)
	    tool=newlib
	    ;;
	gdb*)
	    tool=gdb
	    release_gdb
	    ;;
	gcc*)
	    tool=gcc
	    release_gcc
	    ;;
	qemu*)
	    tool=qemu
	    ;;
	meta-linaro*)
	    tool=meta
	    ;;
	*)
	    tool=gcc
	    ;;
    esac

    return ${tool}
}

release()
{
    tool="`get_tool $1`"
    notice "Releasing ${tool}"
    release_gdb $1		# FIXME: don't hardcode the tool name!
}

# Edit the ChangeLog.linaro file for this release
edit_changelog()
{
    # bzr uses slashes in it's path names, so convert them so we
    # can use the for accessing the source directory.
    url="`echo $1 | sed -e 's:/:_:'`"
    dir="`basename ${url} |sed -e 's/^.*://'`"

    clog="${local_snapshots}/${dir}/ChangeLog.linaro"
    # Edit ChangeLog.linaro and add "GDB Linaro 7.X-20XX.XX[-X] released."
    if test ! -e ${clog}; then
	warning "${clog} doesn't exist, so creating it"
	touch ${clog}
    fi

    year="`date +%Y`"
    month="`date +%m`"
    day="`date +%d`"

    if test x"${fullname}" = x; then
	case $1 in
	    bzr*|lp*)
	    # Pull the author and email from bzr whoami
		fullname="`bzr whoami | sed -e 's: <.*::'`"
		email="`bzr whoami --email`"
		;;
	    svn*)
		trunk="`echo $1 |grep -c trunk`"
		if test ${trunk} -gt 0; then
		    dir="`dirname $1`"
		    dir="`basename ${dir}`/trunk"
		fi
		;;
	    git*)
		if test -f ~/.gitconfig; then
		    fullname="`grep "name = " ~/.gitconfig | cut -d ' ' -f 3-6`"
		    email="`grep "email = " ~/.gitconfig | cut -d ' ' -f 3-6`"
		fi
		;;
	    *)
		;;
	esac
    fi

    if test x"$2" != x; then
	respin=-$2
	nextspin=$(($2 + 1))
    else
	respin=
	nextspin=1
    fi
    series="`echo $1 | sed -r 's#.+/(.+)#\1#'`"
    release=${year}.${month}${respin}

    mv ${clog} /tmp/ChangeLog.linaro

    #tool="`get_tool $1`"
    tool=gdb
    case ${tool} in
	gdb)
	    cat >> ${clog} <<EOF
${year}-${month}-${day}  ${fullname}  <${email}>
        GDB Linaro ${series}-${release} released.

        gdb/
        * version.in: Update.

EOF
	    echo "gdb/" >> ${clog}
	    echo "  * version.in: Update" >> ${clog}
	    ;;
	gcc)
	    cat >> ${clog} <<EOF
${year}-${month}-${day}  ${fullname}  <${email}>
        GCC Linaro ${series}-${release} released.

        gcc/
        * LINARO-VERSION: Update.

EOF
	    echo "gcc/" >> ${clog}
	    ;;
    esac

    # tack the original ChangeLog onto the new version with out update.
    cat /tmp/ChangeLog.linaro >> ${clog}   
}

# From: https://wiki.linaro.org/WorkingGroups/ToolChain/GDB/ReleaseProcess
# $1 - file name-version to grab from source code control.
release_gdb()
{ 
    # First, checkout all the sources
    if test -d ${local_snapshots}/$1; then
	checkout $1 
    fi

    # Edit ChangeLog.linaro and add "GDB Linaro 7.X-20XX.XX[-X] released."
    edit_changelog $1

    # Update gdb/version.in

    #
    # Check in the changes, and tag them
    # bzr commit -m "Make 7.X-20XX.XX[-X] release."
    # bzr tag gdb-linaro-7.X-20XX.XX[-X]
}

# From: https://wiki.linaro.org/WorkingGroups/ToolChain/GCC/ReleaseProcess
release_gcc()
{
    # First, checkout all the sources, or grab a snapshot

    Update every ChangeLog.linaro file.
    date="`date +%Y-%m-%d`"
    # release=$(cut -f1,2 -d. $REL_DIR/svn/gcc/BASE-VER)-$(date +%Y.%m)
}

release_binutils()
{
    # First, checkout all the sources, or grab a snapshot
    error "unimplemented"
}

release_newlib()
{
    # First, checkout all the sources, or grab a snapshot
    error "unimplemented"
}

release_eglibc()
{
    # First, checkout all the sources, or grab a snapshot
    error "unimplemented"
}

release_glibc()
{
    # First, checkout all the sources, or grab a snapshot
    error "unimplemented"
}

release_qemu()
{
    # First, checkout all the sources, or grab a snapshot
    error "unimplemented"
}

tag_release()
{
    if test x"$1" = x; then
	dccs=git
    else
	dccs = $1
    fi
    error "release TAGging unimplemented"
}