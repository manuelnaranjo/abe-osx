#!/bin/sh

#
# This makes a a release tarball Linaro style. Note that this does NOT
# test building the soure, nor do it run any tests. it just packages
# everything necesary for the release.
#


release()
{    
    tool="`echo $1 | sed -e 's:-[0-9].*::'`"
    case ${tool} in
	eglibc)
	    tool=eglibc
	    ;;
	binutils)
	    tool=binutils
	    ;;
	newlib)
	    tool=newlib
	    ;;
	gdb-linaro)
	    tool=gdb
	    release_gdb
	    ;;
	gdb)
	    tool=gdb
	    release_gdb
	    ;;
	gcc)
	    tool=gcc
	    release_gcc
	    ;;
	gcc-linaro)
	    tool=gcc
	    release_gcc
	    ;;
	qemu)
	    tool=qemu
	    ;;
	qemu-linaro)
	    tool=qemu
	    ;;
	meta-linaro)
	    tool=meta
	    ;;
	*)
	    tool=gcc
	    ;;
    esac

    return $?
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

    # Update gdb/version.in

    #
    # Check in the changes, and tag them
    # bzr commit -m "Make 7.X-20XX.XX[-X] release."
    # bzr tag gdb-linaro-7.X-20XX.XX[-X]
    error "release GDB unimplemented"
}

# From: https://wiki.linaro.org/WorkingGroups/ToolChain/GCC/ReleaseProcess
release_gcc()
{
    # First, checkout all the sources, or grab a snapshot

    Update every ChangeLog.linaro file.
    date="`date +%Y-%m-%d`"
    # release=$(cut -f1,2 -d. $REL_DIR/svn/gcc/BASE-VER)-$(date +%Y.%m)
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