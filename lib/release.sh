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

    local tag="`basename $1`"

    cat <<EOF > ${reldir}/MD5SUMS
# This file contains the MD5 checksums of the files in the 
# ${tag}.tar.xz tarball.
#
# Besides verifying that all files in the tarball were correctly expanded,
# it also can be used to determine if any files have changed since the
# tarball was expanded or to verify that a patchfile was correctly applied.
#
# Suggested usage:
# md5sum -c MD5SUMS | grep -v "OK$"
EOF

    find ${reldir}/ -type f | grep -v MD5SUMS | LC_ALL=C sort > /tmp/md5sums.$$
    xargs md5sum < /tmp/md5sums.$$ 2>&1 | sed -e "s:${reldir}/::" >> ${reldir}/MD5SUMS
    rm -f /tmp/md5sums.$$

#    for i in `cat /tmp/md5sums`; do
#	md5sum $i 2>&1 | sed -e 's:/tmp/::' >> ${reldir}/MD5SUMS
#    done
    return 0
}

# GPG sign the tarball
sign_tarball()
{
    trace "$*"

#    ssh -t cbuild@toolchain64.lab gpg --no-use-agent -q --yes --passphrase-file /home/cbuild/.config/cbuild/password --armor --sign --detach-sig --default-key cbuild "/home/cbuild/var/snapshots/gcc-linaro-${release}.tar.xz" scp cbuild@toolchain64.lab:/home/cbuild/var/snapshots/gcc-linaro-${release}.tar.xz.asc $REL_DIR

    return 0
}

release_binutils_src()
{
    # See if specific component versions were specified at runtime
    if test x"${binutils_version}" = x; then
	local binutils_version="`grep ^latest= ${topdir}/config/binutils.conf | cut -d '\"' -f 2` | tr -d '\"'"
    fi
    local srcdir="`get_srcdir ${binutils_version}`"
    local builddir="`get_builddir ${binutils_version}`"
    local tag="`create_release_tag ${binutils_version}`"
    local destdir=/tmp/${tag}

    # make a link with the correct name for the tarball's source directory
    dryrun "ln -sfnT ${srcdir} ${destdir}"

    # Update the Binutils version
    rm -f ${destdir}/binutils/LINARO-VERSION
    if test x"${release}" = x;then
	edit_changelogs ${srcdir} ${tag}
    else
	edit_changelogs ${srcdir} ${release}
    fi    

    # Create .gmo files from .po files.
    for i in `find ${srcdir} -name '*.po' -type f -print`; do
        dryrun "msgfmt -o `echo $i | sed -e 's/\.po$/.gmo/'` $i"
    done

    # Copy all the info files and man pages into the release directory
    local docs="`find ${builddir}/ -name \*.info -o -name \*.1 -o -name \*.7 | sed -e "s:${builddir}/::"`"
    for i in ${docs}; do
      	dryrun "cp -f ${builddir}/$i ${destdir}/$i"
    done

    dryrun "regenerate_checksums ${destdir}"

    # Remove extra files left over from any development hacking
    sanitize ${srcdir}

    # make a link with the correct name for the tarball's source directory
    dryrun "ln -sfnT ${srcdir}/ ${destdir}"
    
    local exclude="--exclude-vcs --exclude .gitignore --exclude .cvsignore --exclude .libs --exclude ${target}"
    dryrun "tar Jcvfh ${local_snapshots}/${tag}.tar.xz ${exclude} --directory=/tmp ${tag}/"

    # Make the md5sum file for this tarball
    rm -f ${local_snapshots}/${tag}.tar.xz.asc
    dryrun "md5sum ${local_snapshots}/${tag}.tar.xz > ${local_snapshots}/${tag}.tar.xz.asc"    
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
    local builddir="`get_builddir ${gcc_version} stage2`"
    local tag="`create_release_tag ${gcc_version}`"
    local version="`create_release_version ${gcc_version}`"
    local destdir=/tmp/linaro.$$/${tag}

    dryrun "mkdir -p ${destdir}/gcc/doc"

    dryrun "rsync --exclude .git -ar ${srcdir}/* ${destdir}"
    
    # Update the GCC version
    rm -f ${destdir}/gcc/LINARO-VERSION
    echo "${version}" > ${destdir}/gcc/LINARO-VERSION
    
    if test x"${release}" = x;then
	edit_changelogs ${destdir} ${tag}
    else
	edit_changelogs ${destdir} ${release}
    fi    
    
    dryrun "regenerate_checksums ${destdir}"

    # Remove extra files left over from any development hacking
    sanitize ${destdir}

    # Install the docs
    install_gcc_docs ${destdir} ${builddir} 

    local exclude="--exclude-vcs --exclude .gitignore --exclude .cvsignore --exclude .libs"
    dryrun "tar Jcvfh ${local_snapshots}/${tag}.tar.xz ${exclude} --directory=/tmp/linaro.$$ ${tag}/"

    # Make the md5sum file for this tarball
    rm -f ${local_snapshots}/${tag}.tar.xz.asc
    dryrun "md5sum ${local_snapshots}/${tag}.tar.xz > ${local_snapshots}/${tag}.tar.xz.asc"

    dryrun -fr /tmp/linaro.$$

    return 0
}

# At release time, we build additional docs. We do this after the main GCC
# sources have been tarred, and append these to the tarball to avoid contaminating
# the source directory.
# $1 - 
install_gcc_docs()
{
    trace "$*"

    local destdir=$1
    local srcdir=$1
    local builddir=$2

    # The destination directory for GCC is a symbolic link. For the docs we
    # create a similar directory structure to install the docs into.
#    if test ! -d ${destdir}/${srcdir}; then
#	dryrun "mkdir -p ${destdir}/${srcdir}"
#    fi

    # the GCC script needs these two values to work.
    SOURCEDIR=${srcdir}/gcc/doc
    DESTDIR=${destdir}/INSTALL
    dryrun ". ${srcdir}/gcc/doc/install.texi2html"

    # Create .gmo files from .po files.
    for i in `find ${destdir} -name '*.po' -type f -print`; do
        dryrun "msgfmt -o `echo $i | sed -e 's/\.po$/.gmo/'` $i"
    done

    # Make a man alias instead of copying the entire man page for G++
    if test ! -e ${builddir}/g++.1; then
	dryrun "echo ".so man1/gcc.1" > ${destdir}/gcc/doc/g++.1"
    fi

    # Copy all the info files and man pages into the release directory
    local docs="`find ${builddir}/ -name \*.info -o -name \*.1 -o -name \*.7 | sed -e "s:${builddir}/::"`"
    for i in ${docs}; do
      	dryrun "cp -fv ${builddir}/$i ${destdir}/gcc/doc"
    done

#    dryrun "rm -fr ${destdir}/${target}"

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

    if test `echo ${srcdir} | grep -c "/gdb"` -gt 0; then
	local tool=gdb
	if test `echo ${srcdir} | grep -c "/gcc"` -gt 0; then
	    local tool=gcc
	    if test `echo ${srcdir} | grep -c "/binutils"` -gt 0; then
		local tool=binutils
		if test `echo ${srcdir} | grep -c "/glibc"` -gt 0; then
		    local tool=glibc
		    if test `echo ${srcdir} | grep -c "/eglibc"` -gt 0; then
			local tool=eglibc
			if test `echo ${srcdir} | grep -c "/newlib"` -gt 0; then
			    local tool=newlib
			fi
		    fi
		fi
	    fi
	fi
    fi

    # Get all the ChangeLog files.
    local clogs="`find $1 -name ChangeLog`"
    #local uptool="`echo ${tool} | tr "[:lower:]" "[:upper:]"`"
    # For a dryrun, don't actually edit any ChangeLog files.
    if test x"${dryrun}" = x"no"; then
	for i in ${clogs}; do
	    if test -e $i.linaro; then
     		mv $i.linaro /tmp/
	    else
		touch /tmp/ChangeLog.linaro
	    fi
     	    echo "${date}  ${fullname}  <${email}>" >> $i.linaro
     	    echo "" >> $i.linaro 
	    echo "     ${uptool} Linaro $2 released." >> $i.linaro
     	    echo "" >> $i.linaro
     	    cat /tmp/ChangeLog.linaro >> $i.linaro
     	    rm -f /tmp/ChangeLog.linaro
	done
    fi
}

# From: https://wiki.linaro.org/WorkingGroups/ToolChain/GDB/ReleaseProcess
# $1 - file name-version to grab from source code control.
release_gdb_src()
{
    trace "$*"

    # See if specific component versions were specified at runtime
    if test x"${gdb_version}" = x; then
	local gdb_version="`grep ^latest= ${topdir}/config/gdb.conf | cut -d '\"' -f 2` | tr -d '\"'"
    fi
    local srcdir="`get_srcdir ${gdb_version}`"
#    local builddir="`get_builddir ${gdb_version}`"
    local tag="`create_release_tag ${gdb_version}`"
    local destdir=/tmp/${tag}

    # Update the GDB version
    rm -f ${destdir}/gdb/LINARO-VERSION
    echo "${tag}" > ${destdir}/gdb/LINARO-VERSION

    if test x"${release}" = x;then
	edit_changelogs ${srcdir} ${tag}
    else
	edit_changelogs ${srcdir} ${release}
    fi    
    
#    dryrun "regenerate_checksums ${destdir}"

    # Remove extra files left over from any development hacking
    sanitize ${srcdir}

    # make a link with the correct name for the tarball's source directory
    dryrun "ln -sfnT ${srcdir} /tmp/${tag}"
    
    local exclude="--exclude-vcs --exclude .gitignore --exclude .cvsignore --exclude .libs"
    dryrun "tar Jcvfh ${local_snapshots}/${tag}.tar.xz ${exclude} --directory=/tmp ${tag}/"

    # Make the md5sum file for this tarball
    rm -f ${local_snapshots}/${tag}.tar.xz.asc
    dryrun "md5sum ${local_snapshots}/${tag}.tar.xz > ${local_snapshots}/${tag}.tar.xz.asc"

    return 0
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

# $1 - The release ttee directory to put the script in for packaging.
sysroot_install_script()
{
    trace "$*"

    local script=$1/INSTALL-SYSROOT.sh
    local tag="`basename $1`"

    local sysroot="`${target}-gcc -print-sysroot`"
    if test ! -e ${script}; then
	cat <<EOF > ${script}
#!/bin/sh

# make the top level directory
if test ! -d /opt/linaro/; then
  echo "This script will install this sysroot in /opt/linaro. Write permission"
  echo "to /opt is required. The files will stay where they are, only a symbolic"
  echo "is created, which can be changed to swap sysroots at compile time."
  echo ""
  echo "Continue ? Hit any key..."
  read answer

  mkdir -p /opt/linaro
fi

# If it doesn't already exist, link to the sysroot path GCC will be using
if test ! -d /opt/linaro/${tag}; then
  ln -sf  \${PWD} ${sysroot}
fi
EOF
    fi

    return 0
}
