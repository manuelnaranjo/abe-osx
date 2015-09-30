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

    local rtag="`create_release_tag gcc`"
    local tag="runtime-${rtag}-${target}"

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
    local builddir="`get_component_builddir gdb`-gdb"
    local destdir="${local_builds}/tmp.$$/${tag}-tmp"
    local prefix="${local_builds}/destdir/${host}"

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

    local rtag="`create_release_tag gcc`"

    if test x"${host}" != x"${build}"; then
	local tag="${rtag}-i686-mingw32_${target}"
    else
	local tag="${rtag}-${build_arch}_${target}"
    fi

    local destdir="${local_builds}/tmp.$$/${tag}"
    dryrun "mkdir -p ${local_builds}/tmp.$$"

    # The manifest file records the versions of all of the components used to
    # build toolchain.
    dryrun "cp ${manifest} ${local_builds}/destdir/${host}/"

    dryrun "ln -sfnT ${local_builds}/destdir/${host} ${destdir}"

    if test x"${build}" != x"${target}"; then
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
#	if test `echo ${host} | grep -c mingw` -eq 0; then
	    # make the tarball from the tree we just created.
	    notice "Making binary tarball for toolchain, please wait..."
	    dryrun "tar Jcfh ${local_snapshots}/${tag}.tar.xz --directory=${local_builds}/tmp.$$ ${exclude} ${tag}"

	    rm -f ${local_snapshots}/${tag}.tar.xz.asc
	    dryrun "md5sum ${local_snapshots}/${tag}.tar.xz | sed -e 's:${local_snapshots}/::' > ${local_snapshots}/${tag}.tar.xz.asc"
#	else
#	    notice "Making binary toolchain package for Windows, please wait..."
#	    ${local_snapshots}/infrastructure/installjammer-1.2.15/installjammer --output-dir ${local_snapshots}/ --build ${abe_path}/config/LinaroGCC.mpi
#	fi
    fi
    
    rm -fr ${local_builds}/tmp.$$

    return 0
}

binary_sysroot()
{
    trace "$*"

    local rtag="`create_release_tag glibc`"
    local tag="sysroot-${rtag}-${target}"

    local destdir="${local_builds}/tmp.$$/${tag}"
    dryrun "mkdir -p ${local_builds}/tmp.$$"
    if test x"${build}" != x"${target}"; then
	dryrun "ln -sfnT ${abe_top}/sysroots/${target} ${destdir}"
    else
	dryrun "ln -sfnT ${abe_top}/sysroots ${destdir}"
    fi

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

    if test x"$1" = x; then
	mtag="`create_release_tag gcc`"
	local outfile=${local_builds}/${host}/${target}/${mtag}-manifest.txt
    else
	local outfile=$1
    fi

    rm -f ${outfile}
    for i in ${toolchain[*]}; do
	local component="$i"

	echo "# Component data for ${component}" >> ${outfile}

	local filespec="`get_component_filespec ${component}`"
	local url="`get_component_url ${component} `/${filespec}"
	echo "${component}_url=${url}" >> ${outfile}

	local branch="`get_component_branch ${component}`"
	if test x"${branch}" != x; then
	    echo "${component}_branch=${branch}" >> ${outfile}
	fi

	local revision="`get_component_revision ${component}`"
	if test x"${revision}" != x; then
	    echo "${component}_revision=${revision}" >> ${outfile}
	fi

	echo "" >> ${outfile}
    done

    cat >> ${outfile} <<EOF
# Build machine data
build=${build}
host=${host}
kernel=${kernel}
hostname=${hostname}
distribution=${distribution}
host_gcc=${host_gcc_version}

# Kernel
linux_version=${linux_version}

EOF

    # Gerrit info, if triggered
    if test x"${gerrit_trigger}" = xyes; then
	cat >> ${outfile} <<EOF
gerrit_branch=${gerrit_branch}
gerrit_revision=${gerrit_revision}

EOF
    fi

    for i in gcc binutils ${clibrary}; do
	if test "`component_is_tar ${package}`" = no; then
	    echo "--------------------- $i ----------------------" >> ${outfile}
	    local srcdir="`get_component_srcdir $i`"
	    # Invoke in a subshell in order to prevent state-change of the current
	    # working directory after manifest is called.
	    $(cd ${srcdir} && git log -n 1 >> ${outfile})
	    echo "" >> ${outfile}
	fi
    done
    
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

    local srcdir="`get_component_srcdir ${binutils_version}`"
    local builddir="`get_component_builddir ${binutils_version} binutils`"
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
