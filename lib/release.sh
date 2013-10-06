#!/bin/sh

#
# This makes a a release tarball Linaro style. Note that this does NOT
# test building the soure, nor do it run any tests. it just packages
# everything necesary for the release.
#

# Regenerate the MD5SUMS file
regenerate_checksums()
{
    trace "$*"

    local reldir=$1

    local tag="`create_release_tag $1`"

    cat <<EOF > ${reldir}/MD5SUMS
# This file contains the MD5 checksums of the files in the 
# gcc-linaro-${tag}.tar.xz tarball.
#
# Besides verifying that all files in the tarball were correctly expanded,
# it also can be used to determine if any files have changed since the
# tarball was expanded or to verify that a patchfile was correctly applied.
#
# Suggested usage:
# md5sum -c MD5SUMS | grep -v "OK$"
EOF

    rm -f ${reldir}/MD5SUMS
    touch ${reldir}/MD5SUMS
 
    find ${reldir}/ -type f | grep -v MD5SUMS | sort > /tmp/md5sums
    for i in `cat /tmp/md5sums`; do
	md5sum $i 2>&1 | sed -e 's:/tmp/::' >> ${reldir}/MD5SUMS
    done

    return 0
}

# GPG sign the tarball
sign_tarball()
{
    trace "$*"

#    ssh -t cbuild@toolchain64.lab gpg --no-use-agent -q --yes --passphrase-file /home/cbuild/.config/cbuild/password --armor --sign --detach-sig --default-key cbuild "/home/cbuild/var/snapshots/gcc-linaro-${release}.tar.xz" scp cbuild@toolchain64.lab:/home/cbuild/var/snapshots/gcc-linaro-${release}.tar.xz.asc $REL_DIR

    return 0
}

release()
{
    trace "$*"

    local tool="`get_toolname $1`"
    notice "Releasing ${tool}"
    release_gdb $1		# FIXME: don't hardcode the tool name!
}

# From: https://wiki.linaro.org/WorkingGroups/ToolChain/GCC/ReleaseProcess
# $1 - 
release_gcc_src()
{
    trace "$*"

    # See if specific component versions were specified at runtime
    if test x"${gcc_version}" = x; then
	local gcc_version="`grep ^latest= ${topdir}/config/gcc.conf | cut -d '\"' -f 2` | tr -d '\"'"
    fi
    local srcdir="`get_srcdir ${gcc_version}`"
    local builddir="`get_builddir ${gcc_version}`"
    local tag="`create_release_tag ${gcc_version}`"
    local destdir=/tmp/${tag}

    install_gcc_docs ${destdir} ${srcdir} ${builddir}

    # Update the GCC version
    rm -f ${destdir}/gcc/LINARO-VERSION
    if test x"${release}" = x;then
	echo "${tag}" > ${destdir}/gcc/LINARO-VERSION
	edit_changelogs ${srcdir} ${tag}
    else
	echo "${release}" > ${destdir}/gcc/LINARO-VERSION
	edit_changelogs ${srcdir} ${release}
    fi
    
    regenerate_checksums ${destdir}

    # Remove extra files left over from any development hacking
    sanitize ${srcdir}

    # make a link with the correct name for the tarball's source directory
    dryrun "ln -sfnT ${srcdir} /tmp/${tag}"
    
    dryrun "tar Jcvfh ${local_snapshots}/${tag}.tar.xz --directory=/tmp --exclude .git ${tag}/"

    # Make the md5sum file for this tarball
    rm -f ${local_snapshots}/${tag}.tar.xz.asc
    dryrun "md5sum ${local_snapshots}/${tag}.tar.xz > ${local_snapshots}/${tag}.tar.xz.asc"

    return 0
}

# At release time, we build additional docs
# $1 - 
install_gcc_docs()
{
    trace "$*"

    local destdir=$1
    local srcdir=$2
    local builddir=$3

    if test ! -d ${destdir}; then
	dryrun "ln -sfnT ${srcdir} ${destdir}"
    fi

    # Create the html docs for the INSTALL directory

    # the GCC script needs these two values to work.
    SOURCEDIR=${srcdir}/gcc/doc
    DESTDIR=${destdir}/INSTALL
    . ${srcdir}/gcc/doc/install.texi2html
    
#    dryrun "cp -f ${builddir}/gcc/po/*.gmo ${destdir}/gcc/po/"
        
    # Copy all the info files and man pages into the release directory
    local docs="`find ${builddir}/ -name \*.info -o -name \*.1 -o -name \*.7 | sed -e "s:${builddir}/::"`"
    for i in ${docs}; do
      	dryrun "cp ${builddir}/$i ${destdir}/$i"
    done

    return 0
}

# Edit the ChangeLog.linaro file for this release
edit_changelogs()
{
    trace "$*"

    if test x"${fullname}" = x; then
	case $1 in
	    bzr*|lp*)
	    # Pull the author and email from bzr whoami
		local fullname="`bzr whoami | sed -e 's: <.*::'`"
		local email="`bzr whoami --email`"
		;;
	    svn*)
		local trunk="`echo $1 |grep -c trunk`"
		if test ${trunk} -gt 0; then
		    local dir="`dirname $1`"
		    local dir="`basename ${dir}`/trunk"
		fi
		;;
	    git*)
		if test -f ~/.gitconfig; then
		    local fullname="`grep "name = " ~/.gitconfig | cut -d ' ' -f 3-6`"
		    local email="`grep "email = " ~/.gitconfig | cut -d ' ' -f 3-6`"
		fi
		;;
	    *)
		;;
	esac
    fi

    local date="`date +%Y-%m-%d`"

    local clogs="`find $1 -name ChangeLog.linaro`"
    if test x"${clogs}" = x; then
	local clogs="`find $1 -type d`/ChangeLog.linaro"
    fi

    if test `echo ${srcdir} | grep -c "/gdb"`; then
	local tool=gdb
	if test `echo ${srcdir} | grep -c "/gcc"`; then
	    local tool=gdb
	    if test `echo ${srcdir} | grep -c "/binutils"`; then
		local tool=binutils
		if test `echo ${srcdir} | grep -c "/glibc"`; then
		    local tool=glibc
		    if test `echo ${srcdir} | grep -c "/eglibc"`; then
			local tool=eglibc
			if test `echo ${srcdir} | grep -c "/newlib"`; then
			    local tool=newlib
			fi
		    fi
		fi
	    fi
	fi
    fi
    for i in ${clogs}; do
	mv $i /tmp/
	echo "${date}  ${fullname}  <${email}>" >> $i
	echo "" >> $i
        echo "        GCC Linaro $2 released." >> $i
	echo "" >> $i
	cat /tmp/ChangeLog.linaro >> $i
	rm /tmp/ChangeLog.linaro
    done
}

# From: https://wiki.linaro.org/WorkingGroups/ToolChain/GDB/ReleaseProcess
# $1 - file name-version to grab from source code control.
release_gdb()
{ 
    trace "$*"

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
	local dccs=git
    else
	local dccs = $1
    fi
    error "release TAGging unimplemented"
}