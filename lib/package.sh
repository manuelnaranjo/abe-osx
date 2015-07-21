#!/bin/bash
# 
#   Copyright (C) 2013, 2014, 2015 Linaro, Inc
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
# 

# This script contains functions for building binary packages.

build_deb()
{
    trace "$*"

    warning "unimplemented"
}

build_rpm()
{
    trace "$*"

    local infile="${abe_path}/packaging/redhat/tcwg.spec.in"
    local arch="`echo ${target} | tr '-' '_'`"
    local version="`echo ${gcc_version} | cut -d '~' -f 2 | grep -o "[4-6][\._][0-9\.]*" | tr '_' '.'`"

    rm -f /tmp/tcwg$$.spec
    sed -e "s:%global triplet.*:%global triplet ${arch}:" \
	-e "s:%global destdir.*:%global destdir $1:" \
	-e "s:%global gcc_version.*:%global gcc_version ${version}_${arch}:" \
	-e "s:%global snapshots.*:%global snapshots ${local_snapshots}:" \
	 ${infile} >> /tmp/tcwg$$.spec

    rpmbuild -bb -v /tmp/tcwg$$.spec
    return $?
}

# This removes files that don't go into a release, primarily stuff left
# over from development.
#
# $1 - the top level path to files to cleanup for a source release
sanitize()
{
    trace "$*"

    # the files left from random file editors we don't want.
    local edits="`find $1/ -name \*~ -o -name \.\#\* -o -name \*.bak -o -name x`"

    pushd ./ >/dev/null
    cd $1
    if test "`git status | grep -c "nothing to commit, working directory clean"`" -gt 0; then
	error "uncommited files in $1! Commit files before releasing."
	#return 1
    fi
    popd >/dev/null

    if test x"${edits}" != x; then
	rm -fr ${edits}
    fi

    return 0
}

# The runtime libraries are produced during dynamic builds of gcc, libgcc,
# listdc++, and gfortran.
binary_runtime()
{
    trace "$*"

#    local version="`${target}-gcc --version | head -1 | cut -d ' ' -f 3`"
    local version="`${target}-gcc --version | grep -o " [0-9]\.[0-9]" | tr -d ' ' | head -n 1`"

    # no expicit release tag supplied, so create one.
    if test x"${release}" = x; then
	if test x"${gcc_version}" = x; then
	    local gcc_version="~`grep ^latest= ${topdir}/config/gcc.conf | cut -d '\"' -f 2`"
	fi
	
	if test `echo ${gcc_version} | grep -c "\.git/"`; then
	    local branch="`basename ${gcc_version}`"
	else
	    if test `echo ${gcc_version} | grep -c "\.git"`; then
		local branch=
	    fi
	fi
	
	local builddir="`get_builddir ${gcc_version} stage2`"
	local srcdir="`get_srcdir ${gcc_version}`"

	local date="`date +%Y%m%d`"
	if test -d ${srcdir}/.gito -o -e ${srcdir}/.gitignore; then
	    local revision="@`cd ${srcdir} && git log --oneline | head -1 | cut -d ' ' -f 1`"
	fi
	if test `echo ${gcc_version} | grep -c "\.git/"`; then
	    local version="`echo ${gcc_version} | cut -d '/' -f 1 | sed -e 's:\.git:-linaro:'`-${version}"
	fi
	local tag="`echo runtime-${version}~${revision}-${target}-${date} | sed -e 's:-none-:-:' -e 's:-unknown-:-:'`"
    else
	# use an explicit tag for the release name
	local tag="`echo runtime-linaro-gcc${version}-${release}-${target}`"
    fi

    local destdir="${local_builds}/tmp.$$/${tag}"

    dryrun "mkdir -p ${destdir}/lib/${target} ${destdir}/usr/lib/${target}"

    # Get the binary libraries.
    if test x"${build}" != x"${target}"; then
	dryrun "rsync -av ${local_builds}/destdir/${host}/${target}/lib*/libgcc* ${destdir}/lib/${target}/"	
	dryrun "rsync -av ${local_builds}/destdir/${host}/${target}/lib*/libstdc++* ${destdir}/usr/lib/${target}/"
    else
	dryrun "rsync -av ${local_builds}/destdir/${host}/lib*/libgcc* ${destdir}/lib/${target}/"
	dryrun "rsync -av ${local_builds}/destdir/${host}/lib*/libstdc++* ${destdir}/usr/lib/${target}/"
    fi

    # make the tarball from the tree we just created.
    notice "Making binary tarball for runtime libraries, please wait..."
    dryrun "tar Jcf ${local_snapshots}/${tag}.tar.xz --directory ${local_builds}/tmp.$$ ${tag}"

    rm -f ${local_snapshots}/${tag}.tar.xz.asc
    dryrun "md5sum ${local_snapshots}/${tag}.tar.xz | sed -e 's:${local_snapshots}/::' > ${local_snapshots}/${tag}.tar.xz.asc"

    rm -fr ${local_builds}/tmp.$$

    return 0
}

binary_gdb()
{
    trace "$*"

    local version="`${target}-gdb --version | head -1 | grep -o " [0-9\.][0-9].*\." | tr -d ')'`"
    local tag="`create_release_tag ${gdb_version} | sed -e 's:binutils-::'`"
    local builddir="`get_builddir ${gdb_version} gdb`"
    local destdir="${local_builds}/tmp.$$/${tag}-tmp"
    local prefix="${local_builds}/destdir/${host}"

    local gdb_static="`grep ^static_link= ${topdir}/config/gdb.conf | cut -d '\"' -f 2`"

#    if test x"${gdb_static}" = x"yes"; then
#    fi

    # Use LSB to produce more portable binary releases.
    if test x"${LSBCC}" != x -a x"${LSBCXX}" != x; then
	local make_flags="${make_flags} CC=${LSBCC} CXX=${LSBCXX}"
    fi

    rm ${builddir}/gdb/gdb

    local make_flags="${make_flags}"
    # install in alternate directory so it's easier to build the tarball
    dryrun "make all ${make_flags} DESTDIR=${destdir} -w -C ${builddir}"
    dryrun "make install ${make_flags} DESTDIR=${destdir} -w -C ${builddir}"
    dryrun "make install ${make_flags} DESTDIR=${destdir} -w -C ${builddir}/gdb/gdbserver"
    dryrun "ln -sfnT ${destdir}/${prefix} /${local_builds}/tmp.$$/${tag}"

    local abbrev="`echo ${host}_${target} | sed -e 's:none-::' -e 's:unknown-::'`"
 
   # make the tarball from the tree we just created.
    notice "Making binary tarball for GDB, please wait..."
    dryrun "tar Jcfh ${local_snapshots}/${tag}-${abbrev}.tar.xz --directory=${local_builds}/tmp.$$ ${tag}"

    rm -f ${local_snapshots}/${tag}.tar.xz.asc
    dryrun "md5sum ${local_snapshots}/${tag}-${abbrev}.tar.xz | sed -e 's:${local_snapshots}/::' > ${local_snapshots}/${tag}-${abbrev}.tar.xz.asc"

    return 0    
}

# Produce a binary toolchain tarball
# For daily builds produced by Jenkins, we use
# `date +%Y%m%d`-${BUILD_NUMBER}-${GIT_REVISION}
# e.g artifact_20130906-12-245f0869.tar.xz
binary_toolchain()
{
    trace "$*"

    local version="`${target}-gcc --version | grep -o " [0-9]\.[0-9]" | tr -d ' ' | head -n 1`"

    # no expicit release tag supplied, so create one.
    if test x"${release}" = x; then
	if test x"${gcc_version}" = x; then
	    local gcc_version="`grep ^latest= ${topdir}/config/gcc.conf | cut -d '\"' -f 2`"
	fi
	if test `echo ${gcc_version} | grep -c "\.git/"`; then
	    local branch="`basename ${gcc_version}`"
	else
	    if test `echo ${gcc_version} | grep -c "\.git"`; then
		local branch=
	    fi
	fi
	
	local date="`date +%Y%m%d`"
	local srcdir="`get_srcdir ${gcc_version}`"

	if test -d ${srcdir}/.git -o -e ${srcdir}/.gitignore; then
	    local revision="git`cd ${srcdir} && git log --oneline | head -1 | cut -d ' ' -f 1`"
	fi
	if test x"${host}" != x"${build}"; then
	    local tag="`echo gcc-linaro-${version}~${revision}-i686-mingw32_${target}-${date} | sed -e 's:-none-:-:' -e 's:-unknown-:-:'`"
	else
	    local tag="`echo gcc-linaro-${version}~${revision}-${build_arch}_${target}-${date} | sed -e 's:-none-:-:' -e 's:-unknown-:-:'`"
	fi
    else
	# use an explicit tag for the release name
	if test x"${host}" != x"${build}"; then
	    local tag="`echo gcc-linaro-${version}-${release}-i686-mingw32_${target} | sed -e 's:-none-:-:' -e 's:-unknown-:-:'`"	
	else
	    local tag="`echo gcc-linaro-${version}-${release}-${build_arch}_${target} | sed -e 's:-none-:-:' -e 's:-unknown-:-:'`"	
	fi

    fi

    local destdir="${local_builds}/tmp.$$/${tag}"
    dryrun "mkdir -p ${local_builds}/tmp.$$"

    # The manifest file records the versions of all of the components used to
    # build toolchain.
    dryrun "cp ${manifest} ${local_builds}/destdir/${host}/"

#    local installdir="`find ${destdir} -name ${target}-nm`"
#    local installdir="`dirname ${installdir} | sed -e 's:/bin::'`"
    dryrun "ln -sfnT ${local_builds}/destdir/${host} ${destdir}"

    if test x"${build}" != x"${target}"; then
	# FIXME: link the sysroot into the toolchain tarball
	dryrun "ln -sfnT ${sysroots} ${destdir}/${target}/libc"
    fi

    # Some mingw packages have a runtime dependency on libwinpthread-1.dll, so a copy
    # is put in bin so all executables will work.
    if test "`echo ${host} | grep -c mingw`" -gt 0 -a -e /usr/${host}/lib/libwinpthread-1.dll; then
	cp /usr/${host}/lib/libwinpthread-1.dll ${local_builds}/destdir/${host}/bin/
    fi

    if test x"${rpmbin}" = x"yes"; then
	notice "Making binary RPM for toolchain, please wait..."
	build_rpm ${destdir}
    fi
    if test x"${tarbin}" = x"yes"; then
	# make the tarball from the tree we just created.
	notice "Making binary tarball for toolchain, please wait..."
	dryrun "tar Jcfh ${local_snapshots}/${tag}.tar.xz --directory=${local_builds}/tmp.$$ ${exclude} ${tag}"

	rm -f ${local_snapshots}/${tag}.tar.xz.asc
	dryrun "md5sum ${local_snapshots}/${tag}.tar.xz | sed -e 's:${local_snapshots}/::' > ${local_snapshots}/${tag}.tar.xz.asc"
    fi
    
    rm -fr ${local_builds}/tmp.$$

    return 0
}

binary_sysroot()
{
    trace "$*"

    local version="`${target}-gcc --version | grep -o " [0-9]\.[0-9]" | tr -d ' ' | head -n 1`"

    # no expicit release tag supplied, so create one.
    if test x"${release}" = x; then
	if test x"${clibrary}" = x"newlib"; then
	    if test x"${newlb_version}" = x; then
		local libc_version="`grep ^latest= ${topdir}/config/newlib.conf | cut -d '=' -f 2 | cut -d '/' -f 1 | tr -d '\"'`"
	    else
		local libc_version="`echo ${newlib_version} | cut -d '/' -f 1`"
	    fi
	    local srcdir="`get_srcdir ${libc_version}`"
	elif test x"${clibrary}" = x"glibc"; then
	    if test x"${glibc_version}" = x; then
		local libc_version="`grep ^latest= ${topdir}/config/glibc.conf | cut -d '/' -f 2 | tr -d '\"'`"
		local srcdir="`get_srcdir ${libc_version}`"
		local libc_version="glibc-linaro-`grep VERSION ${local_snapshots}/${libc_version}/libc/version.h | tr -d '\"' | cut -d ' ' -f 3`"
	    else
		local libc_version="`echo ${glibc_version} | cut -d '/' -f 1`"
		local srcdir="`get_srcdir ${libc_version}`"
		local libc_version="glibc-linaro-`grep VERSION ${local_snapshots}/${libc_version}/libc/version.h | tr -d '\"' | cut -d ' ' -f 3`"
	    fi
	else
	    if test x"${eglibc_version}" = x; then
		local libc_version="`grep ^latest= ${topdir}/config/eglibc.conf | cut -d '/' -f 2 | tr -d '\"'`"
		local srcdir="`get_srcdir ${libc_version}`"
		local libc_version="eglibc-linaro-`grep VERSION ${local_snapshots}/${libc_version}/libc/version.h | tr -d '\"' | cut -d ' ' -f 3`"
	    else
		local libc_version="`echo ${eglibc_version} | cut -d '/' -f 1`"
		local srcdir="`get_srcdir ${libc_version}`"
		local libc_version="eglibc-linaro-`grep VERSION ${local_snapshots}/${libc_version}/libc/version.h | tr -d '\"' | cut -d ' ' -f 3`"
	    fi
	fi

	local builddir="`get_builddir ${libc_version}`"
	
        # if test "`echo $1 | grep -c '@'`" -gt 0; then
        # 	local commit="@`echo $1 | cut -d '@' -f 2`"
        # else
        # 	local commit=""
        # fi
	local version="`${target}-gcc --version | grep -o " [0-9]\.[0-9]" | tr -d ' ' | head -n 1`"
	date="`date +%Y%m%d`"
	if test -d ${srcdir}/.git -o -e ${srcdir}/.gitignore; then
	    local revision="`cd ${srcdir} && git log --oneline | head -1 | cut -d ' ' -f 1`"
	else
	    revision="${BUILD_NUMBER}"
	fi
	local tag="`echo sysroot-${libc_version}-${revision}-${target}-${date}-gcc_${version} | sed -e 's:\.git:-linaro:' -e 's:-none-:-:' -e 's:-unknown-:-:'`"
    else
	local tag="sysroot-linaro-${clibrary}-gcc${version}-${release}-${target}"
    fi

#    dryrun "cp -fr ${abe_top}/sysroots/${target} ${destdir}"
    local destdir="${local_builds}/tmp.$$/${tag}"
    dryrun "mkdir -p ${local_builds}/tmp.$$"
    if test x"${build}" != x"${target}"; then
	dryrun "ln -sfnT ${abe_top}/sysroots/${target} ${destdir}"
    else
	dryrun "ln -sfnT ${abe_top}/sysroots ${destdir}"
    fi

    # Generate the install script
#    sysroot_install_script ${destdir}

    notice "Making binary tarball for sysroot, please wait..."
    dryrun "tar Jcfh ${local_snapshots}/${tag}.tar.xz --directory=${local_builds}/tmp.$$ ${tag}"

    rm -fr ${local_snapshots}/${tag}.tar.xz.asc ${local_builds}/tmp.$$
    dryrun "md5sum ${local_snapshots}/${tag}.tar.xz > ${local_snapshots}/${tag}.tar.xz.asc"

    return 0
}

# Create a manifest file that lists all the versions of the other components
# used for this build.
manifest()
{
    trace "$*"


    # This function relies too heavily on the built toolchain to do anything
    # in dryrun mode.
    if test x"${dryrun}" = xyes; then
	return 0;
    fi

    if test x"${gmp_version}" = x; then
	local gmp_version="`grep ^latest= ${topdir}/config/gmp.conf | cut -d '\"' -f 2`"
    fi
    
    if test x"${mpc_version}" = x; then
	local mpc_version="`grep ^latest= ${topdir}/config/mpc.conf | cut -d '\"' -f 2`"
    fi
    
    if test x"${mpfr_version}" = x; then
	local mpfr_version="`grep ^latest= ${topdir}/config/mpfr.conf | cut -d '\"' -f 2`"
    fi
    
    if test x"${gdb_version}" = x; then
	local gdb_version="`grep ^latest= ${topdir}/config/gdb.conf | cut -d '\"' -f 2`"
    fi
    local gcc_branch="`echo ${gcc_version} | cut -d '~' -f 2`"

    local srcdir="`get_srcdir ${gcc_version}`"
    local gcc_revision="`srcdir_revision ${srcdir}`"

    local srcdir="`get_srcdir ${gdb_version}`"
    local gdb_revision="`srcdir_revision ${srcdir}`"
    
    if test x"${dejagnu_version}" = x; then
	local dejagnu_version="`grep ^latest= ${topdir}/config/dejagnu.conf | cut -d '\"' -f 2`"
    fi
    local srcdir="`get_srcdir ${dejagnu_version}`"
    local dejagnu_revision="`srcdir_revision ${srcdir}`"
    
    if test x"${linux_version}" = x; then
	local linux_version="`grep ^latest= ${topdir}/config/linux.conf | cut -d '\"' -f 2`"
    fi
    
    if test x"${binutils_version}" = x; then
	local binutils_version="`grep ^latest= ${topdir}/config/binutils.conf | cut -d '\"' -f 2`"
    fi
    local srcdir="`get_srcdir ${binutils_version}`"
    local binutils_revision="`srcdir_revision ${srcdir}`"

    local abe_revision="`srcdir_revision ${abe_path}`"

    if test x"${clibrary}" = x"eglibc"; then
	local srcdir="`get_srcdir ${eglibc_version}`"
    elif  test x"${clibrary}" = x"glibc"; then
	local srcdir="`get_srcdir ${glibc_version}`"
    elif test x"${clibrary}" = x"newlib"; then
	local srcdir="`get_srcdir ${newlib_version}`"
    fi
    local libc_version="`srcdir_revision ${abe_path}`"
    
    local mtag=
    if test x"$1" = x; then
	mtag="`create_release_tag ${gcc_version}`"
	local outfile=${local_builds}/${host}/${target}/${mtag}-manifest.txt
    else
	local outfile=$1
    fi

    rm -f ${outfile}
    cat >> ${outfile} <<EOF 
# Build machine data
build=${build}
host=${host}
target=${target}
kernel=${kernel}
hostname=${hostname}
distribution=${distribution}
host_gcc=${host_gcc_version}

Component versions
gmp_versionnum=${gmp_version}
mpc_versionnum=${mpc_version}
mpfr_versionnum=${mpfr_version}

# Binutils
binutils_branch=${binutils_version}
binutils_revision=${binutils_revision}
binutils_version=binutils-gdb.git@${binutils_revision}

# DejaGnu
dejagnu_version=${dejagnu_version}

# GDB
gdb_branch=${gdb_version}
gdb_revision=${gdb_revision}
gdb_version=binutils-gdb.git@${gdb_revision}

# GCC
gcc_branch=${gcc_branch}
gcc_revision=${gcc_revision}
gcc_version=gcc.git@${gcc_revision}

# C Library
clibrary=${clibrary}
libc_version=${libc_version}

# Kernel
linux_version=${linux_version}

# Abe revision used
abe_revision=${abe_revision}
abe_version="abe.git@${abe_revision}"

EOF

    # Gerrit info, if triggered
    if test x"${gerrit_trigger}" = xyes; then
	cat >> ${outfile} <<EOF 
gerrit_branch=${gerrit_branch}
gerrit_revision=${gerrit_revision}

EOF
    fi

    case ${clibrary} in
	glibc)
	    local srcdir="`get_srcdir ${glibc_version}`"
	    if test x"${glibc_version}" = x; then
	        glibc_version="`grep ^latest= ${topdir}/config/glibc.conf | cut -d '\"' -f 2`"
	    fi
	    local glibc_revision="`cd ${srcdir} && git log | head -1 | cut -d ' ' -f 2`"

	    echo "glibc_version=${glibc_version}" >> ${outfile}
	    echo "glibc_revision=${glibc_revision}" >> ${outfile}
	    ;;
	newlib)
	    local srcdir="`get_srcdir ${newlib_version}`"
	    if test x"${newlib_version}" = x; then
	        newlib_version="`grep ^latest= ${topdir}/config/newlib.conf | cut -d '\"' -f 2`"
	    fi
	    local newlib_revision="`cd ${srcdir} && git log | head -1 | cut -d ' ' -f 2`"

	    echo "newlib_version=${newlib_version}" >> ${outfile}
	    echo "newlib_revision=${newlib_revision}" >> ${outfile}
	    ;;
	eglibc|*)
	    local srcdir="`get_srcdir ${eglibc_version}`"
	    if test x"${eglibc_version}" = x; then
	        eglibc_version="`grep ^latest= ${topdir}/config/eglibc.conf | cut -d '\"' -f 2`"
	    fi
	    local eglibc_revision="`cd ${srcdir} && git log | head -1 | cut -d ' ' -f 2`"

	    echo "eglibc_version=${eglibc_version}" >> ${outfile}
	    echo "eglibc_revision=${eglibc_revision}" >> ${outfile}
	    ;;
    esac

    local srcdir="`get_srcdir ${gcc_version}`"
    echo "---------------------------------------------" >> ${outfile}
    cd ${srcdir} && git log -n 1 >> ${outfile}

    echo ${outfile}
    return 0
}

# Build a source tarball
# $1 - the version to use, usually something like 2013.07-2
binutils_src_tarball()
{
    trace "$*"

    local version="`${target}-ld --version | head -1 | cut -d ' ' -f 5 | cut -d '.' -f 1-3`"

    # See if specific component versions were specified at runtime
    if test x"${binutils_version}" = x; then
	local binutils_version="binutils-`grep ^latest= ${topdir}/config/binutils.conf | cut -d '\"' -f 2`"
    fi

    local dir="`normalize_path ${binutils_version}`"
    local srcdir="`get_srcdir ${binutils_version}`"
    local builddir="`get_builddir ${binutils_version} binutils`"
    local branch="`echo ${binutils_version} | cut -d '/' -f 2`"

    # clean up files that don't go into a release, often left over from development
    if test -d ${srcdir}; then
	sanitize ${srcdir}
    fi

    # from /linaro/snapshots/binutils.git/src-release: do-proto-toplev target
    # Take out texinfo from a few places.
    local dirs="`find ${srcdir} -name Makefile.in`"
    for d in ${dirs}; do
	sed -i -e '/^all\.normal: /s/\all-texinfo //' -e '/^install-texinfo /d' $d
    done

    # Create .gmo files from .po files.
    for f in `find . -name '*.po' -type f -print`; do
        dryrun "msgfmt -o `echo $f | sed -e 's/\.po$/.gmo/'` $f"
    done
 
    if test x"${release}" != x; then
	local date="`date +%Y%m%d`"
	if test "`echo $1 | grep -c '@'`" -gt 0; then
	    local revision="`echo $1 | cut -d '@' -f 2`"
	fi
	if test -d ${srcdir}/.git; then
	    local binutils_version="${dir}-${date}"
	    local revision="-`cd ${srcdir} && git log --oneline | head -1 | cut -d ' ' -f 1`"
	    local exclude="--exclude .git"
	else
	    local binutils_version="`echo ${binutils_version} | sed -e "s:-2.*:-${date}:"`"
	fi
	local date="`date +%Y%m%d`"
	local tag="${binutils_version}-linaro${revision}-${date}"
    else
	local tag="binutils-linaro-${version}-${release}"
    fi

    dryrun "ln -s ${srcdir} ${local_builds}/${tag}"

# from /linaro/snapshots/binutils-2.23.2/src-release
#
# NOTE: No double quotes in the below.  It is used within shell script
# as VER="$(VER)"

    if grep 'AM_INIT_AUTOMAKE.*BFD_VERSION' binutils/configure.in >/dev/null 2>&1; then
	sed < bfd/configure.in -n 's/AM_INIT_AUTOMAKE[^,]*, *\([^)]*\))/\1/p';
    elif grep AM_INIT_AUTOMAKE binutils/configure.in >/dev/null 2>&1; then
	sed < binutils/configure.in -n 's/AM_INIT_AUTOMAKE[^,]*, *\([^)]*\))/\1/p';
    elif test -f binutils/version.in; then
	head -1 binutils/version.in;
    elif grep VERSION binutils/Makefile.in > /dev/null 2>&1; then
	sed < binutils/Makefile.in -n 's/^VERSION *= *//p';
    else
	echo VERSION;
    fi

    # Cleanup any temp files.
    #find ${srcdir} -name \*~ -o -name .\#\* -exec rm {} \;

    notice "Making source tarball for GCC, please wait..."
    dryrun "tar Jcfh ${local_snapshots}/${tag}.tar.xz ${exclude} --directory=${local_builds}/tmp.$$ ${tag}/)"

    rm -f ${local_snapshots}/${tag}.tar.xz.asc
    dryrun "md5sum ${local_snapshots}/${tag}.tar.xz > ${local_snapshots}/${tag}.tar.xz.asc"
    # We don't need the symbolic link anymore.
    dryrun "rm -f ${local_builds}/tmp.$$"

    return 0
}

# This installs a binary tarball produced by abe, and runs make check
test_binary_toolchain()
{
    local install="${local_builds}/install.$$"

    local testgcc=
    local testbin=
    is_package_in_runtests "${runtests}" gcc
    testgcc=$?

    is_package_in_runtests "${runtests}" binutils
    testbin=$?

    # Check early and bail if binutils or gcc aren't to be tested.  In reality
    # binary toolchains will probably be built with --check, or --check all
    # (which is the same thing).
    if test $testgcc -ne 0 -a $testbin -ne 0; then
	notice "Nothing to test in ${runtests} for test_binary_toolchain()."
	return 0
    fi

    # ${runtests} might contain something other than just gcc and binutils but
    # we only test those for binary toolchains.
    local testing="`if test ${testgcc} -eq 0; then echo -n ' gcc'; fi;`"
    testing="${testing}`if test ${testbin} -eq 0; then echo -n ' binutils'; fi`"

    notice "Testing the following binary toolchain packages:${testing}"

    if test ! -d ${install}; then
	dryrun "mkdir -p ${install}"
    fi

    # Untar everything in the install directory
    for i in ${local_snapshots}/*-x86_64*.xz; do
	tar Jxvf $i --directory="${install}"
    done

    # Put the installed toolchain first in the path so it gets picked up by make check.
    local compiler="`find ${install} -name ${target}-gcc`"
    local compiler="`dirname ${compiler}`"
    export PATH="${compiler}:$PATH"

    # Only test binutils if the user has requested it.
    if test $testbin -eq 0; then
	# test GCC using the build we just completed, since we need access to the test cases.
	make_clean ${binutils_version} binutils
	make_check ${binutils_version} binutils
	if test $? -gt 0; then
	    error "'make_check ${binutils_version} binutils'."
	    return 1
	fi
    fi

    # Only test gcc if the user has requested it.
    if test $testgcc -eq 0; then
	make_clean ${gcc_version} stage2
	make_check ${gcc_version} stage2
	if test $? -gt 0; then
	    error "'make_check ${gcc_version} stage2' failed."
	    return 1
	fi
    fi

    rm -fr ${install}
    return 0
}
