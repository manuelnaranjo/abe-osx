#!/bin/bash

# This script contains functions for building binary packages.

build_deb()
{
    trace "$*"

    warning "unimplemented"
}

build_rpm()
{
    trace "$*"

    warning "unimplemented"
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

    local version="`${target}-gcc --version | head -1 | cut -d ' ' -f 3`"

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
	local tag="`echo runtime-${version}~${revision}-${host}-${date} | sed -e 's:-none-:-:' -e 's:-unknown-:-:'`"
    else
	# use an explicit tag for the release name
	local tag="`echo runtime-linaro-gcc${version}-${release}-${target} | sed -e 's:-none-:-:' -e 's:-unknown-:-:'`"	

    fi

    local destdir=/tmp/linaro/${tag}

    dryrun "mkdir -p ${destdir}/lib/${target} ${destdir}/usr/lib/${target}"

    # Get the binary libraries. aarch64 uses /lib64, arm uses /lib, s we use a wildcard
    # to get either.
    dryrun "rsync -av ${local_builds}/destdir/${host}/${target}/lib*/libgcc_s* ${destdir}/lib/${target}/"
    
    dryrun "rsync -av ${local_builds}/destdir/${host}/${target}/lib*/libstdc++* ${destdir}/usr/lib/${target}/"

    # make the tarball from the tree we just created.
    dryrun "cd /tmp/linaro && tar Jcvf ${local_snapshots}/${tag}.tar.xz ${tag}"

    rm -f ${local_snapshots}/${tag}.tar.xz.asc
    dryrun "md5sum ${local_snapshots}/${tag}.tar.xz | sed -e 's:${local_snapshots}/::' > ${local_snapshots}/${tag}.tar.xz.asc"

    return 0
}

binary_gdb()
{
    trace "$*"

    local version="`${target}-gdb --version | head -1 | cut -d ' ' -f 4`"
    local tag="`create_release_tag ${gdb_version}`"
    local destdir=/tmp/linaro/${tag}
    local builddir="`get_builddir ${gdb_version}`"

    dryrun "mkdir -p ${destdir}-tmp"

    local prefix="${local_builds}/destdir/${host}"

    # install in alternate directory so it's easier to build the tarball
    dryrun "make install ${make_flags} DESTDIR=${destdir}-tmp -w -C ${builddir}"
    dryrun "ln -sfnT ${destdir}-tmp/${prefix} ${destdir}"

    local abbrev="`echo ${host}_${target} | sed -e 's:none-::' -e 's:unknown-::'`"
    # make the tarball from the tree we just created.
    dryrun "tar JcvCfh /tmp/linaro ${local_snapshots}/${tag}-${abbrev}.tar.xz ${tag}"

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

    local version="`${target}-gcc --version | head -1 | cut -d ' ' -f 3`"

    local destdir=/tmp/linaro-gcc-${version}.$$

    # no expicit release tag supplied, so create one.
    if test x"${release}" = x; then
	if test x"${gcc_version}" = x; then
	    local gcc_version="`grep ^latest= ${topdir}/config/gcc.conf | cut -d '\"' -f 2`"
	    local gcc_static="`grep ^static_link= ${topdir}/config/gcc.conf | cut -d '\"' -f 2`"
	fi
	if test x"${binutils_version}" = x; then
	    local binutils_version="`grep ^latest= ${topdir}/config/binutils.conf | cut -d '\"' -f 2`"
	    local binutils_static="`grep ^static_link= ${topdir}/config/binutils.conf | cut -d '\"' -f 2`"
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
	if test `echo ${gcc_version} | grep -c "\.git/"`; then
	    local version="`echo ${gcc_version} | cut -d '/' -f 1 | sed -e 's:\.git:-linaro:'`-${version}"
	fi
	local tag="`echo ${version}~${revision}-${target}-${host}-${date} | sed -e 's:-none-:-:' -e 's:-unknown-:-:'`"
    else
	# use an explicit tag for the release name
	local gcc_static="`grep ^static_link= ${topdir}/config/gcc.conf | cut -d '\"' -f 2`"
	local binutils_static="`grep ^static_link= ${topdir}/config/binutils.conf | cut -d '\"' -f 2`"
	local tag="`echo gcc-linaro-${version}-${release}-${target}-${host} | sed -e 's:-none-:-:' -e 's:-unknown-:-:'`"	

    fi

    # install in alternate directory so it's easier to build the tarball.
    local builddir="`get_builddir ${gcc_version} stage2`"

    # All invocations of make in this function use these additional flags
    local make_flags="${make_flags} DESTDIR=${destdir} -w"

    if test x"${gcc_static}" = x"yes"; then
	# If the default is a statically linked GCC, we only have to relink
	# the executables,
        # GCC executables we want to relink
	local bins="gcc/as gcc/collect-ld gcc/nm gcc/gcc-ranlib gcc/xgcc gcc/xg++ gcc/lto1 gcc/gcc-nm gcc/gcov-dump gcc/cc1 gcc/lto-wrapper gcc/collect2 gcc/gcc-ar gcc/cpp gcc/gcov gcc/gengtype gcc/gcc-cross gcc/g++-cross"
	dryrun "cd ${builddir} && rm ${bins}"
	dryrun "make SHELL=${bash_shell} ${make_flags} LDFLAGS=-static CXXFLAGS_FOR_BUILD=-static -C ${builddir}/gcc"
	dryrun "make install SHELL=${bash_shell} ${make_flags} -C ${builddir}"
	# Install the documentation too
	dryrun "make install-man install-html install-info SHELL=${bash_shell} ${make_flags} -C ${builddir}/gcc"
    else
	# If the default is a dynamically linked GCC, we have to recompile everything
	dryrun "make clean all install SHELL=${bash_shell} LDFLAGS=-static ${make_flags} -C ${builddir}" 
    fi

    local builddir="`get_builddir ${binutils_version}`"
    if test x"${binutils_static}" = x"yes"; then
        # Binutils executables we want to relink
	local bins="bfd/doc/chew gold/ld-new gold/incremental-dump gold/dwp gprof/gprof binutils/ranlib binutils/objdump binutils/readelf binutils/nm-new binutils/bfdtest1 binutils/size binutils/cxxfilt binutils/addr2line binutils/elfedit binutils/ar binutils/strings binutils/bfdtest2 binutils/strip-new binutils/sysinfo binutils/objcopy ld/ld-new gas/as-new"
	dryrun "cd ${builddir} && rm ${bins}"
	# If the default is a statically linked binutils, we only have to relink
	# the excutables,
	dryrun "make install SHELL=${bash_shell} ${make_flags} LDFLAGS=-all-static -C ${builddir}"
    else
	dryrun "make clean install SHELL=${bash_shell} ${make_flags} LDFLAGS=-all-static -C ${builddir}"
    fi

    # Install the documentation too. The different components unfortunately 
    # install differently, so just do the right thing.
    dryrun "make SHELL=${bash_shell} diststuff install-man install-html install-info ${make_flags} -C ${builddir}/bfd "
    dryrun "make SHELL=${bash_shell} diststuff install-man install-html install-info ${make_flags} -C ${builddir}/ld "
    dryrun "make SHELL=${bash_shell} diststuff install-man install-html install-info ${make_flags} -C ${builddir}/gas"
    dryrun "make SHELL=${bash_shell}  diststuff install-man install-html install-info ${make_flags} -C ${builddir}/gprof"
    dryrun "make SHELL=${bash_shell} install-html install-info ${make_flags} -C ${builddir} "

    # We build and test GCCGO, but we don't release it yet
    # dryrun "rm -fr ${destdir}/bin/${target}-gccgo"

    # The manifest file records the versions of all of the components used to
    # build toolchain.
    manifest
    mv /tmp/manifest.txt ${destdir}/manifest.txt

    local installdir="`find ${destdir} -name ${target}-gcc`"
    local installdir="`dirname ${installdir} | sed -e 's:/bin::'`"
    dryrun "ln -sfnT ${installdir} /tmp/${tag}"

    # make the tarball from the tree we just created.
    dryrun "cd /tmp && tar Jcvfh ${local_snapshots}/${tag}.tar.xz ${exclude} ${tag}"

    rm -f ${local_snapshots}/${tag}.tar.xz.asc
    dryrun "md5sum ${local_snapshots}/${tag}.tar.xz | sed -e 's:${local_snapshots}/::' > ${local_snapshots}/${tag}.tar.xz.asc"

    dryrun "rm -fr /tmp/${tag} ${destdir}"
    return 0
}

binary_sysroot()
{
    trace "$*"

    local version="`${target}-gcc --version | head -1 | cut -d ' ' -f 3`"

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
	local version="`${target}-gcc --version | head -1 | cut -d ' ' -f 3`"
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

    dryrun "cp -fr ${cbuild_top}/sysroots/${target} /tmp/${tag}"

    # Generate the install script
    sysroot_install_script /tmp/${tag}

    dryrun "cd /tmp && tar Jcvf ${local_snapshots}/${tag}.tar.xz ${tag}"

    rm -f ${local_snapshots}/${tag}.tar.xz.asc
    dryrun "md5sum ${local_snapshots}/${tag}.tar.xz > ${local_snapshots}/${tag}.tar.xz.asc"
    return 0
}

# Create a manifest file that lists all the versions of the other components
# used for this build.
manifest()
{
    if test x"$1" = x; then
	local outfile=/tmp/manifest.txt
    else
	local outfile=$1
    fi

    if test x"${gcc_version}" = x; then
	gcc_version="`grep ^latest= ${topdir}/config/gcc.conf | cut -d '\"' -f 2`"
    fi
    
    if test x"${gmp_version}" = x; then
	gmp_version="`grep ^latest= ${topdir}/config/gmp.conf | cut -d '\"' -f 2`"
    fi
    
    if test x"${mpc_version}" = x; then
	mpc_version="`grep ^latest= ${topdir}/config/mpc.conf | cut -d '\"' -f 2`"
    fi
    
    if test x"${mpfr_version}" = x; then
	mpfr_version="`grep ^latest= ${topdir}/config/mpfr.conf | cut -d '\"' -f 2`"
    fi
    
    if test x"${binutils_version}" = x; then
	binutils_version="`grep ^latest= ${topdir}/config/binutils.conf | cut -d '\"' -f 2`"
    fi

    if test x"${eglibc_version}" = x; then
	eglibc_version="`grep ^latest= ${topdir}/config/eglibc.conf | cut -d '\"' -f 2`"
    fi
        
    if test x"${newlib_version}" = x; then
	newlib_version="`grep ^latest= ${topdir}/config/newlib.conf | cut -d '\"' -f 2`"
    fi
        
    if test x"${glibc_version}" = x; then
	glibc_version="`grep ^latest= ${topdir}/config/glibc.conf | cut -d '\"' -f 2`"
    fi        

     rm -f ${outfile}
    cat >> ${outfile} <<EOF 
# Build machine data
build=${build}
kernel=${kernel}
hostname=${hostname}
distribution=${distribution}
host_gcc="${host_gcc_version}"

# Component versions
gmp_version=${gmp_version}
mpc_version=${mpc_version}
mpfr_version=${mpfr_version}
gcc_version=${gcc_version}
binutils_version=${binutils_version}
EOF
    
    case ${clibrary} in
	eglibc)
	    echo "eglibc_version=${eglibc_version}" >> ${outfile}
	    ;;
	glibc)
	    echo "glibc_version=${glibc_version}" >> ${outfile}
	    ;;
	newlib)
	    echo "newlib_version=${newlib_version}" >> ${outfile}
	    ;;
	*)
	    echo "eglibc_version=${eglibc_version}" >> ${outfile}
	    ;;
    esac
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
    local builddir="`get_builddir ${binutils_version}`"
    local branch="`echo ${binutils_version} | cut -d '/' -f 2`"

    # clean up files that don't go into a release, often left over from development
    sanitize ${srcdir}

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

    dryrun "ln -s ${srcdir} /tmp/${tag}"

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

    dryrun "cd /tmp && tar Jcvfh ${local_snapshots}/${tag}.tar.xz ${exclude} ${tag}/"

    rm -f ${local_snapshots}/${tag}.tar.xz.asc
    dryrun "md5sum ${local_snapshots}/${tag}.tar.xz > ${local_snapshots}/${tag}.tar.xz.asc"
    # We don't need the symbolic link anymore.
    dryrun "rm -f /tmp/${tag}"

    return 0
}

