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

# This performs all the steps to build a full cross toolchain
build_all()
{
    trace "$*"
    
    # Turn off dependency checking, as everything is handled here
    nodepends=yes
    
    local infrastructure="`grep ^depends ${topdir}/config/infrastructure.conf | tr -d '"' | sed -e 's:^depends=::'`"

    # Specify the components, in order to get a full toolchain build
    if test x"${target}" != x"${build}"; then
        # Build a cross compiler
	if test "`echo ${host} | grep -c mingw`" -gt 0; then
	    # As Mingw32 requires a cross compiler to be already built, so we don't need
	    # to rebuilt the sysroot.
            local builds="${infrastructure} binutils libc stage2 gdb"
	else
            local builds="${infrastructure} binutils stage1 libc stage2 gdb"
	fi
	if test "`echo ${target} | grep -c -- -linux-`" -eq 1; then
	    local builds="${builds} gdbserver"
	fi
        notice "Buildall: Building \"${builds}\" for cross target ${target}."
    else
        local builds="${infrastructure} binutils stage2 libc gdb" # native build
        notice "Buildall: Building \"${builds}\" for native target ${target}."
    fi
    
    # cross builds need to build a minimal C compiler, which after compiling
    # the C library, can then be reconfigured to be fully functional.

    local build_all_ret=

    # Checkout all the sources
    checkout_all ${builds}
    if test $? -ne 0; then
        error "checkout_all failed"
        return 1;
    fi

    if test x"${manifest}" = x"create"; then
	notice "Exiting after creating"
	local exitflag=true
    fi
    manifest="`manifest`"
    if test x"${exitflag}" = xtrue; then
	exit 0
    fi

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
            # Build stage 1 of GCC, which is a limited C compiler used to compile
            # the C library.
            libc)
                build ${clibrary}
                build_all_ret=$?
                ;;
            stage1)
                build gcc stage1
                build_all_ret=$?
                # Don't create the sysroot if the clibrary build didn't succeed.
                if test ${build_all_ret} -lt 1; then
                    # If we don't install the sysroot, link to the one we built so
                    # we can use the GCC we just built.
		    if test x"${dryrun}" != xyes; then
			local sysroot="`${target}-gcc -print-sysroot`"
			if test ! -d ${sysroot}; then
			    dryrun "ln -sfnT ${abe_top}/sysroots/${target} ${sysroot}"
			fi
		    fi
                fi
                ;; 
            # Build stage 2 of GCC, which is the actual and fully functional compiler
            stage2)
		# FIXME: this is a seriously ugly hack required for building Canadian Crosses.
		# Basically the gcc/auto-host.h produced when configuring GCC stage2 has a
		# conflict as sys/types.h defines a typedef for caddr_t, and autoheader screws
		# up, and then tries to redefine caddr_t yet again. We modify the installed
		# types.h instead of the one in the source tree to be a tiny bit less ugly.
		# After libgcc is built with the modified file, it needs to be changed back.
		if test  `echo ${host} | grep -c mingw` -eq 1; then
		    sed -i -e 's/typedef __caddr_t caddr_t/\/\/ FIXME: typedef __caddr_t caddr_t/' ${sysroots}/usr/include/sys/types.h
		fi

                build gcc stage2
                build_all_ret=$?
		# Reverse the ugly hack
		if test `echo ${host} | grep -c mingw` -eq 1; then
		    sed -i -e 's/.*FIXME: //' ${sysroots}/usr/include/sys/types.h
		fi
                ;;
            *)
		build $i
                build_all_ret=$?
                ;;
        esac
        #if test $? -gt 0; then
        if test ${build_all_ret} -gt 0; then
            error "Failed building $i."
            return 1
        fi
    done

    # Notify that the build completed successfully
    build_success

    # If we're building a full toolchain the binutils tests need to be built
    # with the stage 2 compiler, and therefore we shouldn't run unit-test
    # until the full toolchain is built.  Therefore we test all toolchain
    # packages after the full toolchain is built. 
    if test x"${runtests}" != x; then
	notice "Testing components ${runtests}..."
	buildingall=no
	local check_ret=0
	local check_failed=

	is_package_in_runtests "${runtests}" binutils
	if test $? -eq 0; then
	    make_check binutils
	    if test $? -ne 0; then
		check_ret=1
		check_failed="${check_failed} binutils"
	    fi
	fi

	is_package_in_runtests "${runtests}" gcc
	if test $? -eq 0; then
	    make_check gcc stage2
	    if test $? -ne 0; then
		check_ret=1
		check_failed="${check_failed} gcc-stage2"
	    fi
	fi

	is_package_in_runtests "${runtests}" gdb
	if test $? -eq 0; then
	    make_check gdb
	    if test $? -ne 0; then
		check_ret=1
		check_failed="${check_failed} gdb"
	    fi
	fi

	# Only perform unit tests on [e]glibc when we're building native.
        if test x"${target}" = x"${build}"; then
	    # TODO: Get glibc make check working 'native'
	    is_package_in_runtests "${runtests}" glibc
	    if test $? -eq 0; then
		#make_check ${glibc_version}
		#if test $? -ne 0; then
		#check_ret=1
	        #check_failed="${check_failed} glibc"
		#fi
		notice "make check on native glibc is not yet implemented."
	    fi

	    is_package_in_runtests "${runtests}" eglibc
	    if test $? -eq 0; then
		#make_check ${eglibc_version}
		#if test $? -ne 0; then
		#check_ret=1
	        #check_failed="${check_failed} eglibc"
		#fi
		notice "make check on native eglibc is not yet implemented."
	    fi
	fi

	if test ${check_ret} -ne 0; then
	    error "Failed checking of ${check_failed}."
	    return 1
	fi
    fi

    # Notify that the test run completed successfully
    test_success

    # If any unit-tests have been run, then we should send a message to gerrit.
    # TODO: Authentication from abe to jenkins does not yet work.
    if test x"${gerrit_trigger}" = xyes -a x"${runtests}" != x; then
	local sumsfile="/tmp/sums$$.txt"
	local sums="`find ${local_builds}/${host}/${target} -name \*.sum`"
	for i in ${sums}; do
	    local lineno="`grep -n -- "Summary" $i | grep -o "[0-9]*"`"
	    local lineno="`expr ${lineno} - 2`"
	    sed -e "1,${lineno}d" $i >> ${sumsfile}
	    local status="`grep -c unexpected $i`"
	    if test ${status} -gt 0; then
		local hits="yes"
	    fi
	done
	if test x"${hits}" = xyes; then
	    gerrit_build_status ${gcc_version} 3 ${sumsfile}
	else
	    gerrit_build_status ${gcc_version} 2
	fi
    fi
    rm -f ${sumsfile}

    if test x"${tarsrc}" = x"yes"; then
        if test "`echo ${with_packages} | grep -c toolchain`" -gt 0; then
            release_binutils_src
            release_gcc_src
        fi
        if test "`echo ${with_packages} | grep -c gdb`" -gt 0; then
            release_gdb_src
        fi
    fi

    if test x"${tarbin}" = x"yes" -o x"${rpmbin}" = x"yes"; then
        # Delete any previous release files
        # First delete the symbolic links first, so we don't delete the
        # actual files
        dryrun "rm -fr ${local_builds}/linaro.*/*-tmp ${local_builds}/linaro.*/runtime*"
        dryrun "rm -f ${local_builds}/linaro.*/*"
        # delete temp files from making the release
        dryrun "rm -fr ${local_builds}/linaro.*"

        if test x"${clibrary}" != x"newlib" -a x"${tarbin}" = x"yes"; then
            binary_runtime
        fi
        binary_toolchain

	if test x"${tarbin}" = x"yes"; then
	    binary_sysroot
        fi
#        if test "`echo ${with_packages} | grep -c gdb`" -gt 0; then
#            binary_gdb
#        fi
        notice "Packaging took ${SECONDS} seconds"
    fi
    
    return 0
}

build()
{
    trace "$*"

    local component="`echo $1 | sed -e 's:\.git.*::' -e 's:-[0-9a-z\.\-]*::'`"
 
    if test "`echo $2 | grep -c gdb`" -gt 0; then
	local component="$2"
    fi
    local url="`get_component_url ${component}`"
    local srcdir="`get_component_srcdir ${component}`"
    local builddir="`get_component_builddir ${component}`${2:+-$2}"
    local version="`basename ${srcdir}`"

    local stamp=
    stamp="`get_stamp_name build ${version} ${2:+$2}`"

    # The stamp is in the buildir's parent directory.
    local stampdir="`dirname ${builddir}`"

    notice "Building ${component} ${2:+$2}"
    
    # If this is a native build, we always checkout/fetch.  If it is a 
    # cross-build we only checkout/fetch if this is stage1
    if test x"${target}" = x"${build}" \
        -o x"${target}" != x"${build}" -a x"$2" != x"stage2"; then
	# Don't attempt to get sources if updating is disabled. If checkout_all()
	# has been called, (build_all() does), then there is no need to keep
	# updating.
	if test x"${supdate}" = xyes; then
            component_is_tar ${component}
            if test $? -gt 0; then
-		# Don't update the compiler sources between stage1 and stage2 builds if this
		# is a cross build.
		notice "Checking out ${component} ${2:+$2}"
		checkout ${component}
		if test $? -gt 0; then
                    warning "Sources not updated, network error!"
		fi
            else
		# Don't update the compiler sources between stage1 and stage2 builds if this
		# is a cross build.
		fetch ${component}
		if test $? -gt 0; then
                    error "Couldn't fetch tarball ${component}"
                    return 1
		fi
		extract ${component}
		if test $? -gt 0; then
                    error "Couldn't extract tarball ${component}"
                    return 1
		fi
            fi
	fi
    fi

    # We don't need to build if the srcdir has not changed!  We check the
    # build stamp against the timestamp of the srcdir.
    local ret=
    check_stamp "${stampdir}" ${stamp} ${srcdir} build ${force}
    ret=$?
    if test $ret -eq 0; then
	return 0
    elif test $ret -eq 255; then
        # Don't proceed if the srcdir isn't present.  What's the point?
        warning "no source dir for the stamp!"
        return 1
   fi

    if test x"${building}" != xno; then
	notice "Configuring ${component} ${2:+$2}"
	configure_build ${component} ${2:+$2}
	if test $? -gt 0; then
            error "Configure of $1 failed!"
            return $?
	fi
	
	# Clean the build directories when forced
	if test x"${force}" = xyes; then
            make_clean ${component} ${2:+$2}
            if test $? -gt 0; then
		return 1
            fi
	fi
	
	# Finally compile and install the libaries
	make_all ${component} ${2:+$2}
	if test $? -gt 0; then
            return 1
	fi
	
	# Build the documentation, unless it has been disabled at the command line.
	if test x"${make_docs}" = xyes; then
            make_docs ${component} ${2:+$2}
            if test $? -gt 0; then
		return 1
            fi
	else
            notice "Skipping make docs as requested (check host.conf)."
	fi
	
	# Install, unless it has been disabled at the command line.
	if test x"${install}" = xyes; then
            make_install ${component} ${2:+$2}
            if test $? -gt 0; then
		return 1
            fi
	else
            notice "Skipping make install as requested (check host.conf)."
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
	
	local tag="`create_release_tag ${component}`"
	notice "Done building ${tag}${2:+ $2}, took ${SECONDS} seconds"
	
	# For cross testing, we need to build a C library with our freshly built
	# compiler, so any tests that get executed on the target can be fully linked.
    fi

    # Only execute make_check in build() if build_all() isn't being invoked for
    # this run of abe.sh.  This is because build_all() will invoke make_check()
    # in sequence after all builds are executed if it's been directed to run
    # unit-tests.
    # TODO: eliminate buildingall as a global and make it a local check passed
    # via a parameter to build().
    if test x"${buildingall}" = xno; then

	# Skip make_check if it isn't designated to be executed in ${runtests}
	is_package_in_runtests "${runtests}" ${component}
	if test $? -eq 0 -a x"$2" != x"stage1" -a x"$2" != x"gdbserver"; then
	    # We don't run make check on gcc stage1 or on gdbserver because
	    # it's unnecessary.
	    notice "Starting test run for ${tag}${2:+ $2}"
	    make_check ${gitinfo}${2:+ $2}
	    if test $? -gt 0; then
	        return 1
	    fi
	else
	    notice "make check skipped for ${tag}${2:+ $2}"
	fi
    fi

    return 0
}

make_all()
{
    trace "$*"

    local component="`echo $1 | sed -e 's:\.git.*::' -e 's:-[0-9a-z\.\-]*::'`"

    # Linux isn't a build project, we only need the headers via the existing
    # Makefile, so there is nothing to compile.
    if test x"${component}" = x"linux"; then
        return 0
    fi

    local builddir="`get_component_builddir ${component}`${2:+-$2}"
    notice "Making all in ${builddir}"

    if test x"${parallel}" = x"yes" -a "`echo ${component} | grep -c glibc`" -eq 0; then
	local make_flags="${make_flags} -j ${cpus}"
    fi

    # Enable an errata fix for aarch64 that effects the linker
    if test "`echo ${component} | grep -c glibc`" -gt 0 -a `echo ${target} | grep -c aarch64` -gt 0; then
	local make_flags="${make_flags} LDFLAGS=\"-Wl,--fix-cortex-a53-843419\" "
    fi

    if test "`echo ${target} | grep -c aarch64`" -gt 0; then
	local make_flags="${make_flags} LDFLAGS_FOR_TARGET=\"-Wl,-fix-cortex-a53-843419\" "
    fi

    # Use pipes instead of /tmp for temporary files.
    if test x"${override_cflags}" != x -a x"${component}" != x"eglibc"; then
	local make_flags="${make_flags} CFLAGS_FOR_BUILD=\"-pipe -g -O2\" CFLAGS=\"${override_cflags}\" CXXFLAGS=\"${override_cflags}\" CXXFLAGS_FOR_BUILD=\"-pipe -g -O2\""
    else
	local make_flags="${make_flags} CFLAGS_FOR_BUILD=\"-pipe -g -O2\" CXXFLAGS_FOR_BUILD=\"-pipe -g -O2\""
    fi

    if test x"${override_ldflags}" != x; then
        local make_flags="${make_flags} LDFLAGS=\"${override_ldflags}\""
    fi

    if test x"${use_ccache}" = xyes -a x"${build}" = x"${host}"; then
        local make_flags="${make_flags} CC='ccache gcc' CXX='ccache g++'"
    fi 

    # All tarballs are statically linked
    local make_flags="${make_flags} LDFLAGS_FOR_BUILD=\"-static-libgcc\" -C ${builddir}"

    # Some components require extra flags to make: we put them at the
    # end so that config files can override
    local default_makeflags="`get_component_makeflags ${component}`"

#    if test x"$2" = x"gdbserver"; then
#       default_makeflags="CFLAGS=--sysroot=${sysroots}"
#    fi

    if test x"${default_makeflags}" !=  x; then
        local make_flags="${make_flags} ${default_makeflags}"
    fi

    if test x"${CONFIG_SHELL}" = x; then
        export CONFIG_SHELL=${bash_shell}
    fi

    if test x"${make_docs}" != xyes; then
        local make_flags="${make_flags} BUILD_INFO=\"\" MAKEINFO=echo"
    fi
    local makeret=
    # GDB and Binutils share the same top level files, so we have to explicitly build
    # one or the other, or we get duplicates.
    local logfile="${builddir}/make-${component}${2:+-$2}.log"
    dryrun "make SHELL=${bash_shell} -w -C ${builddir} ${make_flags} 2>&1 | tee ${logfile}"
    local makeret=$?
    
#    local errors="`dryrun \"egrep '[Ff]atal error:|configure: error:|Error' ${logfile}\"`"
#    if test x"${errors}" != x -a ${makeret} -gt 0; then
#       if test "`echo ${errors} | egrep -c "ignored"`" -eq 0; then
#           error "Couldn't build ${tool}: ${errors}"
#           exit 1
#       fi
#    fi

    # Make sure the make.log file is in place before grepping or the -gt
    # statement is ill formed.  There is not make.log in a dryrun.
#    if test -e "${builddir}/make-${tool}.log"; then
#       if test `grep -c "configure-target-libgcc.*ERROR" ${logfile}` -gt 0; then
#           error "libgcc wouldn't compile! Usually this means you don't have a sysroot installed!"
#       fi
#    fi
    if test ${makeret} -gt 0; then
        warning "Make had failures!"
        return 1
    fi

    return 0
}

# Print path to dynamic linker in sysroot
# $1 -- sysroot path
# $2 -- whether dynamic linker is expected to exist
find_dynamic_linker()
{
    local sysroots="$1"
    local strict="$2"
    local dynamic_linker c_library_version

    # Programmatically determine the embedded glibc version number for
    # this version of the clibrary.
    if test -x "${sysroots}/usr/bin/ldd"; then
	c_library_version="`${sysroots}/usr/bin/ldd --version | head -n 1 | sed -e "s/.* //"`"
	dynamic_linker="`find ${sysroots} -type f -name ld-${c_library_version}.so`"
    fi
    if $strict && [ -z "$dynamic_linker" ]; then
        error "Couldn't find dynamic linker ld-${c_library_version}.so in ${sysroots}"
        exit 1
    fi
    echo "$dynamic_linker"
}

make_install()
{
    trace "$*"

    local component="`echo $1 | sed -e 's:\.git.*::' -e 's:-[0-9a-z\.\-]*::'`"

    if test x"${parallel}" = x"yes" -a "`echo ${component} | grep -c glibc`" -eq 0; then
        local make_flags="${make_flags} -j $((2*${cpus}))"
    fi

    if test x"${component}" = x"linux"; then
        local srcdir="`get_component_srcdir ${component}` ${2:+$2}"
        if test `echo ${target} | grep -c aarch64` -gt 0; then
            dryrun "make ${make_opts} -C ${srcdir} headers_install ARCH=arm64 INSTALL_HDR_PATH=${sysroots}/usr"
        elif test `echo ${target} | grep -c i.86` -gt 0; then
            dryrun "make ${make_opts} -C ${srcdir} headers_install ARCH=i386 INSTALL_HDR_PATH=${sysroots}/usr"
        elif test `echo ${target} | grep -c x86_64` -gt 0; then
            dryrun "make ${make_opts} -C ${srcdir} headers_install ARCH=x86_64 INSTALL_HDR_PATH=${sysroots}/usr"
        elif test `echo ${target} | grep -c arm` -gt 0; then
            dryrun "make ${make_opts} -C ${srcdir} headers_install ARCH=arm INSTALL_HDR_PATH=${sysroots}/usr"
        else
            warning "Unknown arch for make headers_install!"
            return 1
        fi
        if test $? != "0"; then
            warning "Make headers_install failed!"
            return 1
        fi
        return 0
    fi


    # Use LSB to produce more portable binary releases.
    if test x"${LSBCC}" != x -a x"${LSBCXX}" != x -a x"${tarbin}" = x"yes"; then
	case ${component} in
	    binutils|gdb|gcc)
		export LSB_SHAREDLIBPATH=${builddir}
		local make_flags="${make_flags} CC=${LSBCC} CXX=${LSBCXX}"
		;;
	    *)
		;;
	esac
    fi

    local builddir="`get_component_builddir ${component}`${2:+-$2}"
    notice "Making install in ${builddir}"

    if test "`echo ${component} | grep -c glibc`" -gt 0; then
        local make_flags=" install_root=${sysroots} ${make_flags} LDFLAGS=-static-libgcc PARALLELMFLAGS=\"-j ${cpus}\""
    fi

    if test x"${override_ldflags}" != x; then
        local make_flags="${make_flags} LDFLAGS=\"${override_ldflags}\""
    fi

    # NOTE: $make_flags is dropped, as newlib's 'make install' doesn't
    # like parallel jobs. We also change tooldir, so the headers and libraries
    # get install in the right place in our non-multilib'd sysroot.
    if test x"${component}" = x"newlib"; then
        # as newlib supports multilibs, we force the install directory to build
        # a single sysroot for now. FIXME: we should not disable multilibs!
        local make_flags=" tooldir=${sysroots}/usr/"
        if test x"$2" = x"libgloss"; then
            local make_flags="${make_flags}"
        fi
    fi

    if test x"${make_docs}" != xyes; then
	export BUILD_INFO=""
    fi

    # Don't stop on CONFIG_SHELL if it's set in the environment.
    if test x"${CONFIG_SHELL}" = x; then
        export CONFIG_SHELL=${bash_shell}
    fi

    local default_makeflags= #"`get_component_makeflags ${component}`"
    if test x"${component}" = x"gdb" ; then
	local log="`dirname ${builddir}`/install.log"
	if test x"$2" != x"gdbserver" ; then
            dryrun "make install-gdb ${make_flags} ${default_makeflags} -i -k -w -C ${builddir} 2>&1 | tee ${log}"
        else
            dryrun "make install ${make_flags} -i -k -w -C ${builddir} 2>&1 | tee ${log}"
        fi
    else
	dryrun "make install ${make_flags} ${default_makeflags} -i -k -w -C ${builddir} 2>&1 | tee ${log}"
    fi
    if test $? != "0"; then
        warning "Make install failed!"
        return 1
    fi

    if test x"${component}" = x"gcc"; then
	dryrun "copy_gcc_libs_to_sysroot \"${local_builds}/destdir/${host}/bin/${target}-gcc --sysroot=${sysroots}\""
	if test  `echo ${host} | grep -c mingw` -eq 1 -a -e /usr/${host}/lib/libwinpthread-1.dll; then
	    local builddir="`get_component_builddir ${gcc_version}`-stage2"
	    cp /usr/${host}/lib/libwinpthread-1.dll ${builddir}/gcc
	fi
    fi

    return 0
}

# $1 - The component to test
# $2 - If set to anything, installed tools are used'
make_check()
{
    trace "$*"

    local component="`echo $1 | sed -e 's:\.git.*::' -e 's:-[0-9a-z\.\-]*::'`"
    local builddir="`get_component_builddir ${component}`${2:+-$2}"

    # Some tests cause problems, so don't run them all unless
    # --enable alltests is specified at runtime.
    local ignore="dejagnu gmp mpc mpfr make eglibc linux gdbserver"
    for i in ${ignore}; do
        if test x"${component}" = x$i -a x"${alltests}" != xyes; then
            return 0
        fi
    done
    notice "Making check in ${builddir}"

    # Use pipes instead of /tmp for temporary files.
    if test x"${override_cflags}" != x -a x"$2" != x"stage2"; then
        local make_flags="${make_flags} CFLAGS_FOR_BUILD=\"${override_cflags}\" CXXFLAGS_FOR_BUILD=\"${override_cflags}\""
    else
        local make_flags="${make_flags} CFLAGS_FOR_BUILD=-\"-pipe\" CXXFLAGS_FOR_BUILD=\"-pipe\""
    fi

    if test x"${override_ldflags}" != x; then
        local make_flags="${make_flags} LDFLAGS_FOR_BUILD=\"${override_ldflags}\""
    fi

    local runtestflags="`get_component_runtestflags ${component}`"
    if test x"${runtestflags}" != x; then
        local make_flags="${make_flags} RUNTESTFLAGS=\"${runtestflags}\""
    fi
    if test x"${override_runtestflags}" != x; then
        local make_flags="${make_flags} RUNTESTFLAGS=\"${override_runtestflags}\""
    fi

    if test x"${parallel}" = x"yes"; then
	local make_flags
	case "${target}" in
	    "$build"|*"-elf"*) make_flags="${make_flags} -j ${cpus}" ;;
	    # Double parallelization when running tests on remote boards
	    # to avoid host idling when waiting for the board.
	    *) make_flags="${make_flags} -j $((2*${cpus}))" ;;
	esac
    fi

    # load the config file for Linaro build farms
    export DEJAGNU=${topdir}/config/linaro.exp

    # Run tests
    local checklog="${builddir}/check-${component}.log"
    if test x"${build}" = x"${target}"; then
	# Overwrite ${checklog} in order to provide a clean log file
	# if make check has been run more than once on a build tree.
	dryrun "make check RUNTESTFLAGS=\"${runtest_flags} --xml=${component}.xml \" ${make_flags} -w -i -k -C ${builddir} 2>&1 | tee ${checklog}"
	if test $? -gt 0; then
	    error "make check -C ${builddir} failed."
	    return 1
	fi
    else
	local exec_tests
	exec_tests=false
	case "$component" in
	    gcc) exec_tests=true ;;
	    # Support testing remote gdb for the merged binutils-gdb.git
	    # repository where the branch doesn't indicate the tool.
	    # Fixme: This doesn't seem to be working.
	    binutils)
		if [ x"$2" = x"gdb" ]; then
		    exec_tests=true
		fi
		;;
	    # Support testing remote gdb for the merged binutils-gdb.git
	    # where the branch name DOES indicate the tool.
	    gdb)
		exec_tests=true
		;;
	esac

	# Declare schroot_make_opts.  Its value will be set in
	# start_schroot_sessions depending on features that target board[s]
	# support.
	eval "schroot_make_opts="

	# Export SCHROOT_TEST so that we can choose correct boards
	# in config/linaro.exp
	export SCHROOT_TEST="$schroot_test"

	if $exec_tests && [ x"$schroot_test" = x"yes" ]; then
	    # Start schroot sessions on target boards that support it
	    start_schroot_sessions "${target}" "${sysroots}" "${builddir}"
	    if test $? -ne 0; then
		return 1
	    fi
	fi

	case ${component} in
	    binutils)
		local dirs="/binutils /ld /gas"
		local check_targets="check-DEJAGNU"
		;;
	    gdb)
		local dirs="/"
		local check_targets="check-gdb"
		;;
	    *)
		local dirs="/"
		local check_targets="check"
		;;
	esac
	if test x"${component}" = x"gcc" -a x"${clibrary}" != "newlib"; then
            touch ${sysroots}/etc/ld.so.cache
            chmod 700 ${sysroots}/etc/ld.so.cache
	fi

	# Remove existing logs so that rerunning make check results
	# in a clean log.
	if test -e ${checklog}; then
	    # This might or might not be called, depending on whether make_clean
	    # is called before make_check.  None-the-less it's better to be safe.
	    notice "Removing existing check-${component}.log: ${checklog}"
	    rm ${checklog}
	fi

	for i in ${dirs}; do
	    # Always append "tee -a" to the log when building components individually
            dryrun "make ${check_targets} SYSROOT_UNDER_TEST=${sysroots} FLAGS_UNDER_TEST=\"\" PREFIX_UNDER_TEST=\"${local_builds}/destdir/${host}/bin/${target}-\" RUNTESTFLAGS=\"${runtest_flags}\" ${schroot_make_opts} ${make_flags} -w -i -k -C ${builddir}$i 2>&1 | tee -a ${checklog}"
	    if test $? -gt 0; then
		error "make ${check_targets} -C ${builddir}$i failed."
		return 1
	    fi
	done

	# Stop schroot sessions
	stop_schroot_sessions
	unset SCHROOT_TEST
       
        if test x"${component}" = x"gcc"; then
            rm -rf ${sysroots}/etc/ld.so.cache
	fi
    fi

    return 0
}

make_clean()
{
    trace "$*"

    builddir="`get_component_builddir $1 ${2:+$2}`"
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

    local component="`echo $1 | sed -e 's:\.git.*::' -e 's:-[0-9a-z\.\-]*::'`"
    local builddir="`get_component_builddir ${component}`${2:+-$2}"

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
        *gdbserver)
            return 0
            ;;
        *gdb)
            dryrun "make SHELL=${bash_shell} ${make_flags} -i -k -w -C ${builddir}/gdb diststuff install-html install-info 2>&1 | tee -a ${builddir}/makedoc.log"
            return $?
            ;;
        *gcc*)
            #dryrun "make SHELL=${bash_shell} ${make_flags} -w -C ${builddir} doc html info man 2>&1 | tee -a ${builddir}/makedoc.log"
            dryrun "make SHELL=${bash_shell} ${make_flags} -i -k -w -C ${builddir} install-html install-info 2>&1 | tee -a ${builddir}/makedoc.log"
            return $?
            ;;
        *linux*|*dejagnu*|*gmp*|*mpc*|*mpfr*|*newlib*|*make*)
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

# TODO: Should copy_gcc_libs_to_sysroot() use the input parameter in $1?
# $1 - compiler (and any compiler flags) to query multilib information
copy_gcc_libs_to_sysroot()
{
    local libgcc
    local ldso
    local gcc_lib_path
    local sysroot_lib_dir

    ldso="$(find_dynamic_linker "${sysroots}" false)"
    if ! test -z "${ldso}"; then
	libgcc="libgcc_s.so"
    else
	libgcc="libgcc.a"
    fi

    # Make sure the compiler built before trying to use it
    if test ! -e ${local_builds}/destdir/${host}/bin/${target}-gcc; then
	error "${target}-gcc doesn't exist!"
	return 1
    fi
    libgcc="`${local_builds}/destdir/${host}/bin/${target}-gcc -print-file-name=${libgcc}`"
    if test x"${libgcc}" = xlibgcc.so -o x"${libgcc}" = xlibgcc_s.so; then
	error "GCC doesn't exist!"
	return 1
    fi
    gcc_lib_path="$(dirname "${libgcc}")"
    if ! test -z "${ldso}"; then
	sysroot_lib_dir="$(dirname ${ldso})"
    else
	sysroot_lib_dir="${sysroots}/usr/lib"
    fi

    rsync -a ${gcc_lib_path}/ ${sysroot_lib_dir}/
}
