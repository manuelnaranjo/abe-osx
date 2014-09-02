#!/bin/bash
# 
#   Copyright (C) 2013, 2014 Linaro, Inc
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

# This performs all the steps to build a full cross toolchain
build_all()
{
    trace "$*"

    # Turn off dependency checking, as everything is handled here
    nodepends=yes

    # Specify the components, in order to get a full toolchain build
    if test x"${target}" != x"${build}"; then
	local builds="infrastructure binutils stage1 libc stage2 gdb" #  gdbserver
        notice "Buildall: Building \"${builds}\" for cross target ${target}."
    else
	local builds="infrastructure binutils stage2 gdb" # native build
        notice "Buildall: Building \"${builds}\" for native target ${target}."
    fi

    # See if specific component versions were specified at runtime
    if test x"${gcc_version}" = x; then
	gcc_version="`grep ^latest= ${topdir}/config/gcc.conf | cut -d '\"' -f 2`"
    fi
    if test x"${binutils_version}" = x; then
	binutils_version="`grep ^latest= ${topdir}/config/binutils.conf | cut -d '\"' -f 2`"
    fi
    if test x"${eglibc_version}" = x; then
	eglibc_version="`grep ^latest= ${topdir}/config/eglibc.conf | cut -d '\"' -f 2`"
    fi
    if test x"${newlib_version}" = x; then
	newlib_version="`grep ^latest= ${topdir}/config/newlib.conf | cut -d '\"' -f 2`"
	libgloss_version="`grep ^latest= ${topdir}/config/newlib.conf | cut -d '\"' -f 2`"
    fi
    if test x"${glibc_version}" = x; then
	glibc_version="`grep ^latest= ${topdir}/config/glibc.conf | cut -d '\"' -f 2`"
    fi

    if test x"${gdb_version}" = x; then
	gdb_version="`grep ^latest= ${topdir}/config/gdb.conf | cut -d '\"' -f 2`"
    fi
    
    # cross builds need to build a minimal C compiler, which after compiling
    # the C library, can then be reconfigured to be fully functional.

    if test x"${building}" != xno; then
	local build_all_ret=
	# build each component
	for i in ${builds}; do
	    notice "Building all, current component $i"
	    # If an interactive build, stop betweeen each step so we can
	    # check the build and config options.
	    if test x"${interactive}" = x"yes"; then
	        echo "Hit any key to continue..."
	        read answer		
	    fi
	    case $i in
		infrastructure)
		    infrastructure
		    build_all_ret=$?
		    ;;
		# Build stage 1 of GCC, which is a limited C compiler used to compile
		# the C library.
		libc)
		    if test x"${clibrary}" = x"eglibc"; then
			build ${eglibc_version}
		    elif  test x"${clibrary}" = x"glibc"; then
			build ${glibc_version}
		    elif test x"${clibrary}" = x"newlib"; then
			build ${newlib_version}
			build ${newlib_version} libgloss
		    else
			error "\${clibrary}=${clibrary} not supported."
			return 1
		    fi
		    build_all_ret=$?
		    ;;
		stage1)
		    build ${gcc_version} stage1
		    build_all_ret=$?
		    # Don't create the sysroot if the clibrary build didn't succeed.
		    if test ${build_all_ret} -lt 1; then
			# If we don't install the sysroot, link to the one we built so
			# we can use the GCC we just built.
			# FIXME: if ${dryrun} ${target}-gcc doesn't exist so this will error.
			local sysroot="`${target}-gcc -print-sysroot`"
			if test ! -d ${sysroot}; then
		            dryrun "mkdir -p /opt/linaro"
		            dryrun "ln -sfnT ${cbuild_top}/sysroots/${target} ${sysroot}"
			fi
		    fi
		    ;; 
		# Build stage 2 of GCC, which is the actual and fully functional compiler
		stage2)
		    build ${gcc_version} stage2
		    build_all_ret=$?
		    ;;
		gdb)
		    build ${gdb_version}
		    build_all_ret=$?
		    ;;
		gdbserver)
		    build ${gdb_version} gdbserver
		    build_all_ret=$?
		    ;;
		# Build anything not GCC or infrastructure
		*)
		    build ${binutils_version}
		    build_all_ret=$?
		    ;;
	    esac
	    #if test $? -gt 0; then
	    if test ${build_all_ret} -gt 0; then
		error "Failed building $i."
		return 1
	    fi
	done
	
	manifest ${local_builds}/${host}/${target}/manifest.txt
	
	notice "Build took ${SECONDS} seconds"
    fi
    
    if test x"${tarsrc}" = x"yes"; then
	if test "`echo ${with_packages} | grep -c toolchain`" -gt 0; then
            release_binutils_src
            release_gcc_src
	fi
	if test "`echo ${with_packages} | grep -c gdb`" -gt 0; then
            release_gdb_src
	fi
# FIXME: release_sysroot isn't implemented yet, this is a reminder
#	if test "`echo ${with_packages} | grep -c sysroot`" -gt 0; then
#            release_sysroot
#	fi
    fi

    if test x"${tarbin}" = x"yes"; then
	# Delete any previous release files
        # First delete the symbolic links first, so we don't delete the
	# actual files
	dryrun "rm -fr /tmp/linaro.*/*-tmp /tmp/linaro.*/runtime*"
	dryrun "rm -f /tmp/linaro.*/*"
        # delete temp files from making the release
	dryrun "rm -fr /tmp/linaro.*"

	if test "`echo ${with_packages} | grep -c toolchain`" -gt 0; then
	    if test x"${clibrary}" != x"newlib"; then
		binary_runtime
	    fi
            binary_toolchain
	fi
	if test "`echo ${with_packages} | grep -c sysroot`" -gt 0; then
            binary_sysroot
	fi
	if test "`echo ${with_packages} | grep -c gdb`" -gt 0; then
            binary_gdb
	fi
	notice "Packaging took ${SECONDS} seconds"
    fi


    return 0
}

build()
{
    trace "$*"

    # gitinfo contains the service://url~branch@revision
    local gitinfo="`get_source $1`"
    if test -z "${gitinfo}"; then
	error "No matching source found for \"$1\"."
	return 1
    fi

    # The git parser functions shall return valid results for all
    # services, especially once we have a URL.

    # tag is a sanitized string that's only used for naming and information
    # because it can't be reparsed by the parser (since '/' characters are
    # converted to '-' characters in branch names.
    local tag=
    tag="`get_git_tag ${gitinfo}`"

    local srcdir="`get_srcdir ${gitinfo} ${2:+$2}`"

    local stamp=
    stamp="`get_stamp_name build ${gitinfo} ${2:+$2}`"

    local builddir="`get_builddir ${gitinfo} ${2:+$2}`"

    # The stamp is in the buildir's parent directory.
    local stampdir="`dirname ${builddir}`"

    notice "Building ${tag}${2:+ $2}"
    
    # If this is a native build, we always checkout/fetch.  If it is a 
    # cross-build we only checkout/fetch if this is stage1
    if test x"${target}" == x"${build}" \
	    -o "${target}" != x"${build}" -a x"$2" != x"stage2"; then
	if test `echo ${gitinfo} | egrep -c "^bzr|^svn|^git|^lp|^http|^git|\.git"` -gt 0; then	
	    # Don't update the compiler sources between stage1 and stage2 builds if this
	    # is a cross build.
	    notice "Checking out ${tag}${2:+ $2}"
	    checkout ${gitinfo} ${2:+$2}
	    if test $? -gt 0; then
	        warning "Sources not updated, network error!"
	    fi
	else
	    # Don't update the compiler sources between stage1 and stage2 builds if this
	    # is a cross build.
	    fetch ${gitinfo}
	    if test $? -gt 0; then
	        error "Couldn't fetch tarball ${gitinfo}"
	        return 1
	    fi
	    extract ${gitinfo}
	    if test $? -gt 0; then
	        error "Couldn't extract tarball ${gitinfo}"
	        return 1
	    fi
	fi
    fi

    # We don't need to build if the srcdir has not changed!  We check the
    # build stamp against the timestamp of the srcdir.
    local ret=
    check_stamp "${stampdir}" ${stamp} ${srcdir} build ${force}
    ret=$?
    if test $ret -eq 0; then
	if test x"${runtests}" != xyes; then
	    return 0 
	fi
    elif test $ret -eq 255; then
	# Don't proceed if the srcdir isn't present.  What's the point?
	return 1
	warning "no source dir for the stamp!"
   fi

    notice "Configuring ${tag}${2:+ $2}"
    configure_build ${gitinfo} $2
    if test $? -gt 0; then
	error "Configure of $1 failed!"
	return $?
    fi
    
    # Clean the build directories when forced
    if test x"${force}" = xyes; then
	make_clean ${gitinfo} $2
	if test $? -gt 0; then
	    return 1
	fi
    fi
    
    # Finally compile and install the libaries
    make_all ${gitinfo} $2
    if test $? -gt 0; then
	return 1
    fi

    # Build the documentation, unless it has been disabled at the command line.
    if test x"${make_docs}" = xyes; then
	make_docs ${gitinfo} $2
	if test $? -gt 0; then
	    return 1
	fi
    else
	notice "Skipping make docs as requested (check host.conf)."
    fi

    make_install ${gitinfo} $2
    if test $? -gt 0; then
	return 1
    fi

    # See if we can compile and link a simple test case.
    if test x"$2" = x"stage2" -a x"${clibrary}" != x"newlib"; then
	dryrun "(hello_world)"
	if test $? -gt 0; then
	    error "Hello World test failed for ${gitinfo}..."
	    return 1
	else
	    notice "Hello World test succeeded for ${gitinfo}..."
	fi
    fi

    create_stamp "${stampdir}" "${stamp}"

    notice "Done building ${tag}${2:+ $2}"

    # For cross testing, we need to build a C library with our freshly built
    # compiler, so any tests that get executed on the target can be fully linked.
    if test x"${runtests}" = xyes; then
	if test x"$2" != x"stage1" -a x"$2" != x"gdbserver"; then
	    notice "Starting test run for ${tag}${2:+ $2}"
	    make_check ${gitinfo}${2:+ $2}
	    if test $? -gt 0; then
		return 1
	    fi
	fi
    fi
    
    return 0
}

make_all()
{
    trace "$*"

    local tool="`get_toolname $1`"

    # Linux isn't a build project, we only need the headers via the existing
    # Makefile, so there is nothing to compile.
    if test x"${tool}" = x"linux"; then
	return 0
    fi

    # FIXME: This should be a URL 
    local builddir="`get_builddir $1 ${2:+$2}`"
    notice "Making all in ${builddir}"

    local make_flags="${make_flags} -j ${cpus}"

    # Some components require extra flags to make
    local default_makeflags="`grep ^default_makeflags= ${topdir}/config/${tool}.conf | cut -d '\"' -f 2`"
    if test x"${default_makeflags}" !=  x; then
	local make_flags="${make_flags} ${default_makeflags}"
    fi

    # Use pipes instead of /tmp for temporary files.
    local make_flags="${make_flags} CFLAGS_FOR_BUILD=\"-pipe -g -O2\" ${append_cflags} CXXFLAGS_FOR_BUILD=\"-pipe -g -O2\""
    if test x"${append_ldflags}" != x; then
	local make_flags="${make_flags} LDFLAGS=\"${append_ldflags}\""
    fi

    if test x"${use_ccache}" = xyes -a x"${build}" = x"${host}"; then
     	local make_flags="${make_flags} CC='ccache gcc' CXX='ccache g++'"
    fi 

    # All tarballs are statically linked
    if test x"${tarbin}" = x"yes" -o x"${tarsrc}" = x"yes"; then
	local make_flags="${make_flags} LDFLAGS_FOR_BUILD=\"-static-libgcc -static\" -C ${builddir}"
    fi

    if test x"${CONFIG_SHELL}" = x; then
	export CONFIG_SHELL=${bash_shell}
    fi

    local makeret=
    # GDB and Binutils share the same top level files, so we have to explicitly build
    # one or the other, or we get duplicates.
    local logfile="${builddir}/make-${tool}.log"
    dryrun "make SHELL=${bash_shell} ${make_flags} -w -C ${builddir} 2>&1 | tee ${logfile}"
    local makeret=$?

    local errors="`egrep 'fatal error:|configure: error:|Error' ${logfile}`"
    if test x"${errors}" != x -a ${makeret} -gt 0; then
	if test "`echo ${errors} | egrep -c "ignored"`" -eq 0; then
	    error "Couldn't build ${tool}: ${errors}"
	    exit 1
	fi
    fi

    # Make sure the make.log file is in place before grepping or the -gt
    # statement is ill formed.  There is not make.log in a dryrun.
    if test -e "${builddir}/make-${tool}.log"; then
       if test `grep -c "configure-target-libgcc.*ERROR" ${logfile}` -gt 0; then
           error "libgcc wouldn't compile! Usually this means you don't have a sysroot installed!"
       fi
    fi
    if test ${makeret} -gt 0; then
	warning "Make had failures!"
	return 1
    fi

    return 0
}

# Print path to dynamic linker in sysroot
# $1 -- sysroot path
find_dynamic_linker()
{
    local sysroots="$1"
    local dynamic_linker c_library_version

    # Programmatically determine the embedded glibc version number for
    # this version of the clibrary.
    c_library_version="`${sysroots}/usr/bin/ldd --version | head -n 1 | sed -e "s/.* //"`"
    dynamic_linker="`find ${sysroots} -type f -name ld-${c_library_version}.so`"
    if [ -z "$dynamic_linker" ]; then
	error "Couldn't find dynamic linker ld-${c_library_version}.so in ${sysroots}"
	exit 1
    fi
    echo "$dynamic_linker"
}

make_install()
{
    trace "$*"

    if test x"${parallel}" = x"yes"; then
	local make_flags="${make_flags} -j ${cpus}"
    fi

    local tool="`get_toolname $1`"
    if test x"${tool}" = x"linux"; then
     	local srcdir="`get_srcdir $1 ${2:+$2}`"
	if test `echo ${target} | grep -c aarch64` -gt 0; then
	    dryrun "make ${make_opts} -C ${srcdir} headers_install ARCH=arm64 INSTALL_HDR_PATH=${sysroots}/usr"
	else
	    dryrun "make ${make_opts} -C ${srcdir} headers_install ARCH=arm INSTALL_HDR_PATH=${sysroots}/usr"
	fi
	if test $? != "0"; then
	    warning "Make headers_install failed!"
	    return 1
	fi
	return 0
    fi

    local builddir="`get_builddir $1 ${2:+$2}`"
    notice "Making install in ${builddir}"

    if test "`echo ${tool} | grep -c glibc`" -gt 0; then
	local make_flags=" install_root=${sysroots} ${make_flags} PARALLELMFLAGS=\"-j ${cpus}\"cLDFLAGS=-static-libgcc"
    fi

    if test x"${append_ldflags}" != x; then
	local make_flags="${make_flags} LDFLAGS=\"${append_ldflags}\""
    fi

    # NOTE: $make_flags is dropped, as newlib's 'make install' doesn't
    # like parallel jobs. We also change tooldir, so the headers and libraries
    # get install in the right place in our non-multilib'd sysroot.
    if test x"${tool}" = x"newlib"; then
        # as newlib supports multilibs, we force the install directory to build
        # a single sysroot for now. FIXME: we should not disable multilibs!
	local make_flags=" tooldir=${sysroots}/usr/"
#	if test x"$2" = x"libgloss"; then
#	    local make_flags="${make_flags} install-rdimon install-rdpmon install-redboot install"
#	    local builddir="${builddir}/aarch64"
#	fi
    fi

    # Don't stop on CONFIG_SHELL if it's set in the environment.
    if test x"${CONFIG_SHELL}" = x; then
	export CONFIG_SHELL=${bash_shell}
    fi

    local default_makeflags="`grep ^default_makeflags= ${topdir}/config/${tool}.conf | cut -d '\"' -f 2 | sed -e 's: all-: install-:'`"
    dryrun "make install ${make_flags} ${default_makeflags} -i -k -w -C ${builddir} 2>&1 | tee ${builddir}/install.log"
    if test $? != "0"; then
	warning "Make install failed!"
	return 1
    fi

    if test x"${tool}" = x"gcc"; then
	local libs="`find ${builddir} -name \*.so\* -o -name \*.a`"
	if test ! -e ${sysroots}/usr/lib; then
	    dryrun "mkdir -p ${sysroots}/usr/lib/"
	fi
	dryrun "rsync -av ${libs} ${sysroots}/usr/lib/"
    fi

    if test "`echo ${tool} | grep -c glibc`" -gt 0 -a "`echo ${target} | grep -c aarch64`" -gt 0; then
	local dynamic_linker
	dynamic_linker="$(find_dynamic_linker "$sysroots")"
	local dynamic_linker_name="`basename ${dynamic_linker}`"

	# aarch64 is 64 bit, so doesn't populate sysroot/lib, which unfortunately other
	# things look for shared libraries in.
	dryrun "rsync -a ${sysroots}/lib/ ${sysroots}/lib64/"
	dryrun "rm -rf ${sysroots}/lib"
	dryrun "ln -sfnT ${sysroots}/lib64 ${sysroots}/lib"

	#dryrun "(mv ${sysroots}/lib/ld-linux-aarch64.so.1 ${sysroots}/lib/ld-linux-aarch64.so.1.symlink)"
	dryrun "(rm -f ${sysroots}/lib/ld-linux-aarch64.so.1)"
	dryrun "(cd ${sysroots}/lib64; ln -sfnT ${dynamic_linker_name} ld-linux-aarch64.so.1)"
    fi


    # FIXME: this is a seriously ugly hack required for building Canadian Crosses.
    # Basically the gcc/auto-host.h produced when configuring GCC stage2 has a
    # conflict as sys/types.h defines a typedef for caddr_t, and autoheader screws
    # up, and then tries to redefine caddr_t yet again. We modify the installed
    # types.h instead of the one in the source tree to be a tiny bit less ugly.
    if test x"${tool}" = x"eglibc" -a `echo ${host} | grep -c mingw` -eq 1; then
	sed -i -e '/typedef __caddr_t caddr_t/d' ${sysroots}/usr/include/sys/types.h
    fi

    return 0
}

# Run the testsuite for the component. By default, this runs the testsuite
# using the freshly built executables in the build tree. It' also possible
# to run the testsuite on installed tools, so we can test out binary releases.
# For binutils, use check-DEJAGNU. 
# For GCC, use check-gcc-c, check-gcc-c++, or check-gcc-fortran
# GMP uses check-mini-gmp, MPC and MPFR appear to only test with the freshly built
# components.
#
# $1 - The component to test
make_check_installed()
{
    trace "$*"

    local tool="`get_toolname $1`"
    if test x"${builddir}" = x; then
	local builddir="`get_builddir $1 ${2:+$2}`"
    fi
    notice "Making check in ${builddir}"

    # TODO:
    # extract binary tarball
    # If build tree exists, then 'make check' there.
    # if no build tree, untar the matching source release, configure it, and
    # then run 'make check'.

    local tests=""
    case $1 in
	binutils*)
	    # these 
	    local builddir="`get_builddir ${binutils_version} ${2:+$2}`"
	    dryrun "make -C ${builddir}/as check-DEJAGNU RUNTESTFLAGS=${runtest_flags} ${make_flags} -w -i -k 2>&1 | tee ${builddir}/check-binutils.log"
	    dryrun "make -C ${builddir}/ld check-DEJAGNU RUNTESTFLAGS=${runtest_flags} ${make_flags} -w -i -k 2>&1 | tee -a ${builddir}/check-binutils.log"
	    ;;
	gcc*)
	    local builddir="`get_builddir ${gcc_version} ${2:+$2}`"
	    for i in "c c++"; do
		dryrun "make -C ${builddir} check-gcc=$i RUNTESTFLAGS=${runtest_flags} ${make_flags} -w -i -k 2>&1 | tee -a ${builddir}/check-$i.log"
	    done
	    ;;
	*libc*)
	    ;;
	newlib*)
	    ;;
	gdb*)
	    ;;
	*)
	    ;;
    esac

    return 0
}

# Run the testsuite for the component. By default, this runs the testsuite
# using the freshly built executables in the build tree. It' also possible
# $1 - The component to test
# $2 - If set to anything, installed tools are used'
make_check()
{
    trace "$*"

    local tool="`get_toolname $1`"
    local builddir="`get_builddir $1 ${2:+$2}`"

    # Some tests cause problems, so don't run them all unless
    # --enable alltests is specified at runtime.
    local ignore="dejagnu gmp mpc mpfr gdb"
    for i in ${ignore}; do
	if test x"${tool}" = x$i -a x"${alltests}" != xyes; then
	    return 0
	fi
    done
    notice "Making check in ${builddir}"

#    if test x"$2" != x; then
#	make_check_installed
#	return 0
#    fi

    # Use pipes instead of /tmp for temporary files.
    if test x"${append_cflags}" != x; then
	local make_flags="${make_flags} CFLAGS_FOR_BUILD=\"${append_cflags} -pipe\" CXXFLAGS_FOR_BUILD=\"-pipe\""
    else
	local make_flags="${make_flags} CFLAGS_FOR_BUILD=-\"pipe CXXFLAGS_FOR_BUILD=-pipe\""
    fi

    if test x"${append_ldflags}" != x; then
	local make_flags="${make_flags} LDFLAGS_FOR_BUILD=\"${append_ldflags}\""
    fi

    if test x"${parallel}" = x"yes"; then
	local make_flags
	case "$target" in
	    "$build"|*-elf*) make_flags="$make_flags -j $cpus" ;;
	    # Double parallelization when running tests on remote boards
	    # to avoid host idling when waiting for the board.
	    *) make_flags="$make_flags -j $((2*$cpus))" ;;
	esac
    fi

    # load the config file for Linaro build farms
    if test x"${DEJAGNU}" = x; then
	export DEJAGNU=${topdir}/config/linaro.exp
    fi

    # Run tests
    local checklog="${builddir}/check-${tool}.log"
    if test x"${build}" = x"${target}"; then
	dryrun "make check RUNTESTFLAGS=\"${runtest_flags}\" ${make_flags} -w -i -k -C ${builddir} 2>&1 | tee ${checklog}"
    else
	local exec_tests
	exec_tests=false
	case "$tool" in
	    gcc) exec_tests=true ;;
	    binutils)
		if [ x"$2" = x"gdb" ]; then
		    exec_tests=true
		fi
		;;
	esac

	local -a schroot_boards
	local schroot_port schroot_port_opt schroot_shared_dir_opt
	if $exec_tests && [ x"$schroot_test" = x"yes" ]; then
	    # Start schroot sessions on target boards that support it
	    schroot_port="$(print_schroot_port)"
	    local schroot_sysroot="$(make_target_sysroot "${local_builds}/destdir/${host}/bin/${target}-gcc --sysroot=${sysroots}")"
	    schroot_boards=($(start_schroot_sessions "$target" "$schroot_port" "$schroot_sysroot" "$builddir"))
	    rm -rf "$schroot_sysroot"
	    schroot_port_opt="SCHROOT_PORT=$schroot_port"
	    schroot_shared_dir_opt="SCHROOT_SHARED_DIR=$builddir"
	fi

	if test x"${tool}" = x"binutils"; then
	    if test x"$2" = x"gdb"; then		
		dryrun "make check-gdb PREFIX_UNDER_TEST=\"${local_builds}/destdir/${host}/bin/${target}-\" FLAGS_UNDER_TEST=\"--sysroot=${sysroots}\" RUNTESTFLAGS=\"${runtest_flags}\" $schroot_port_opt $schroot_shared_dir_opt ${make_flags} -w -i -k -C ${builddir} 2>&1 | tee ${checklog}"
	    else
		dryrun "make check-binutils PREFIX_UNDER_TEST=\"${local_builds}/destdir/${host}/bin/${target}-\" FLAGS_UNDER_TEST=\"--sysroot=${sysroots}\" RUNTESTFLAGS=\"${runtest_flags}\" ${make_flags} -w -i -k -C ${builddir} 2>&1 | tee ${checklog}"
	    fi
	else
	    dryrun "make check PREFIX_UNDER_TEST=\"${local_builds}/destdir/${host}/bin/${target}-\" FLAGS_UNDER_TEST=\"--sysroot=${sysroots}\" RUNTESTFLAGS=\"${runtest_flags}\" $schroot_port_opt $schroot_shared_dir_opt ${make_flags} -w -i -k -C ${builddir} 2>&1 | tee ${checklog}"
	fi

	# Stop schroot sessions
	stop_schroot_sessions "$schroot_port" "${schroot_boards[@]}"
    fi

    return 0
}

make_clean()
{
    trace "$*"

    builddir="`get_builddir $1 ${2:+$2}`"
    notice "Making clean in ${builddir}"

    if test x"$2" = "dist"; then
	dryrun "make distclean ${make_flags} -w -i -k -C ${builddir}"
    else
	dryrun "make clean ${make_flags} -w -i -k -C ${builddir}"
    fi
    if test $? != "0"; then
	warning "Make clean failed!"
	#return 1
    fi

    return 0
}

make_docs()
{
    trace "$*"

    local builddir="`get_builddir $1 ${2:+$2}`"

    notice "Making docs in ${builddir}"

    case $1 in
	*binutils*)
	    # the diststuff target isn't supported by all the subdirectories,
	    # so we build both all targets and ignore the error.
	    dryrun "make SHELL=${bash_shell} ${make_flags} -w -C ${builddir}/bfd diststuff install-man install-html install-info 2>&1 | tee -a ${builddir}/makedoc.log"
	    dryrun "make SHELL=${bash_shell} ${make_flags} -w -C ${builddir}/ld diststuff install-man install-html install-info 2>&1 | tee -a ${builddir}/makedoc.log"
	    dryrun "make SHELL=${bash_shell} ${make_flags} -w -C ${builddir}/gas diststuff install-man install-html install-info 2>&1 | tee -a ${builddir}/makedoc.log"
	    dryrun "make SHELL=${bash_shell} ${make_flags} -w -C ${builddir}/gprof diststuff install-man install-html install-info 2>&1 | tee -a ${builddir}/makedoc.log"
	    dryrun "make SHELL=${bash_shell} ${make_flags} -w -C ${builddir} install-html install-info 2>&1 | tee -a ${builddir}/makedoc.log"
	    return $?
	    ;;
	*gdb*)
	    dryrun "make SHELL=${bash_shell} ${make_flags} -i -k -w -C ${builddir}/gdb diststuff install-html install-info 2>&1 | tee -a ${builddir}/makedoc.log"
	    return $?
	    ;;
	*gcc*)
	    #dryrun "make SHELL=${bash_shell} ${make_flags} -w -C ${builddir} doc html info man 2>&1 | tee -a ${builddir}/makedoc.log"
	    dryrun "make SHELL=${bash_shell} ${make_flags} -i -k -w -C ${builddir} install-html install-info 2>&1 | tee -a ${builddir}/makedoc.log"
	    return $?
	    ;;
	*linux*|*dejagnu*|*gmp*|*mpc*|*mpfr*|*newlib*)
	    # the regular make install handles all the docs.
	    ;;
	*libc*) # including eglibc
	    #dryrun "make SHELL=${bash_shell} ${make_flags} -w -C ${builddir} info dvi pdf html 2>&1 | tee -a ${builddir}/makedoc.log"
	    dryrun "make SHELL=${bash_shell} ${make_flags} -w -C ${builddir} info html 2>&1 | tee -a ${builddir}/makedoc.log"
	    return $?
	    ;;
	*)
	    dryrun "make SHELL=${bash_shell} ${make_flags} -w -C ${builddir} info man 2>&1 | tee -a ${builddir}/makedoc.log"
	    return $?
	    ;;
    esac

    return 0
}

# See if we can link a simple executable
hello_world()
{
    trace "$*"

    if test ! -e /tmp/hello.cpp; then
    # Create the usual Hello World! test case
    cat <<EOF > /tmp/hello.cpp
#include <iostream>
int
main(int argc, char *argv[])
{
    std::cout << "Hello World!" << std::endl; 
}
EOF
    fi
    
    # See if a test case compiles to a fully linked executable. Since
    # our sysroot isn't installed in it's final destination, pass in
    # the path to the freshly built sysroot.
    if test x"${build}" != x"${target}"; then
	dryrun "${target}-g++ --sysroot=${sysroots} -o /tmp/hi /tmp/hello.cpp"
	if test -e /tmp/hi; then
	    rm -f /tmp/hi
	else
	    return 1
	fi
    fi

    return 0
}

# Print path to GCC's shared libraries
# $1 - compiler and its flags
print_gcc_library_path()
{
    local compiler="$1"
    lib_path="$($compiler -print-file-name=libgcc_s.so)"
    dirname "$lib_path"
}

# Make a single-use target sysroot with all shared libraries for testing.
# NOTE: It is responsibility of the caller to "rm -rf" the sysroot.
# $1 - compiler (and any compiler flags) to query multilib information
make_target_sysroot()
{
    trace "$*"

    local sysroot
    sysroot=/tmp/sysroot.$$
    rsync -a $sysroots/ $sysroot/

    if test "`echo ${target} | grep -c aarch64`" -gt 0; then
	# Remove symlink lib64 -> lib to make sysroot debian-compatible.
	rm $sysroot/lib
    fi

    local gcc_lib_path
    gcc_lib_path="$(print_gcc_library_path "$@")"

    local sysroot_lib_dir
    sysroot_lib_dir="$(find_dynamic_linker "$sysroot")"
    sysroot_lib_dir="$(dirname $sysroot_lib_dir)"

    rsync -a $gcc_lib_path/ $sysroot_lib_dir/

    echo $sysroot
}
