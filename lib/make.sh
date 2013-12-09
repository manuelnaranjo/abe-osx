#!/bin/sh

#
#
#

# This performs all the steps to build a full cross toolchain
build_all()
{
    trace "$*"

    # Turn off dependency checking, as everything is handled here
    nodepends=yes

    # Specify the components, in order to get a full toolchain build
    if test x"${target}" != x"${build}"; then
	local builds="infrastructure binutils stage1 libc stage2 gdb"
    else
	local builds="infrastructure binutils stage2 gdb" # native build
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
    fi
    if test x"${glibc_version}" = x; then
	glibc_version="`grep ^latest= ${topdir}/config/glibc.conf | cut -d '\"' -f 2`"
    fi


    if test x"${gdb_version}" = x; then
	gdb_version="`grep ^latest= ${topdir}/config/gdb.conf | cut -d '\"' -f 2`"
    fi

    # cross builds need to build a minimal C compiler, which after compiling
    # the C library, can then be reconfigured to be fully functional.

    local build_all_ret=
    # build each component
    for i in ${builds}; do
	notice "Building all, current component $i"
	# # If an interactive build, stop betweeen each step so we can
	# # check the build and config options.
	# if test x"${interactive}" = x"yes"; then
	#     echo "Hit any key to continue..."
	#     read answer		
	# fi
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
		else
		    error "\${clibrary}=${clibrary} not supported."
		    return 1
		fi
		build_all_ret=$?
		;;
	    stage1)
		build ${gcc_version} stage1
		build_all_ret=$?
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

    notice "Build took ${SECONDS} seconds"
    
    if test x"${tarsrc}" = x"yes"; then
        release_binutils_src 
        release_gdb_src
        release_gcc_src
    fi

    if test x"${tarbin}" = x"yes"; then
        binary_sysroot
        binary_gdb
        binary_toolchain

	if test x"${clibrary}" != x"newlib"; then
	    binary_runtime
	fi
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

    local srcdir=
    srcdir="`get_srcdir ${gitinfo}`"

    local stamp=
    stamp="`get_stamp_name build ${gitinfo} ${2:+$2}`"

    local builddir="`get_builddir ${gitinfo} $2`"

    # The stamp is in the buildir's parent directory.
    local stampdir="`dirname ${builddir}`"

    check_stamp "${stampdir}" ${stamp} ${srcdir} build ${force}
    if test $? -eq 0; then
	return 0 
    fi

    notice "Building ${tag}${2:+ $2}"
    
    if test `echo ${gitinfo} | egrep -c "^bzr|^svn|^git|^lp|^http|^git|\.git"` -gt 0; then	
	# Don't checkout for stage2 gcc, otherwise it'll do an unnecessary pull.
	    notice "Checking out ${tag}${2:+ $2}"
	    checkout ${gitinfo}
	    if test $? -gt 0; then
		warning "Sources not updated, network error!"
	    fi
	#fi
    else
	if test x"$2" != x"stage2"; then
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

    # Build the documentation.
    make_docs ${gitinfo} $2
    if test $? -gt 0; then
	return 1
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
	    #return 1
	else
	    notice "Hello World test succeeded for ${gitinfo}..."
	fi
    fi

    create_stamp "${stampdir}" "${stamp}"

    notice "Done building ${tag}${2:+ $2}"

    # For cross testing, we need to build a C library with our freshly built
    # compiler, so any tests that get executed on the target can be fully linked.
    if test x"${runtests}" = xyes; then
	if test x"$2" != x"stage1"; then
	    notice "Starting test run for ${tag}${2:+ $2}"
	    dryrun "make_check ${gitinfo} stage2"
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

    local tool="`get_git_tool $1`"

    # Linux isn't a build project, we only need the headers via the existing
    # Makefile, so there is nothing to compile.
    if test x"${tool}" = x"linux"; then
	return 0
    fi

    # FIXME: This should be a URL 
    local builddir="`get_builddir $1 $2`"
    notice "Making all in ${builddir}"

    # FIXME: see if the users wants multiple make jobs, which we ignore for
    # native ARM or AARCH64 as the hardware can't handle the load, and usually
    # don't have enough memory either.
    if test x"${parallel}" = x"yes" -a `echo ${build} | egrep -c "arm|aarch64"` -eq 0; then
     	local make_flags="${make_flags} -j ${cpus}"
    fi
    if test x"${use_ccache}" = xyes -a x"${build}" = x"${host}"; then
     	local make_flags="${make_flags} CC='ccache gcc' CXX='ccache g++'"
    fi
 
    if test x"${CONFIG_SHELL}" = x; then
	export CONFIG_SHELL=${bash_shell}
    fi

    # Binutils runs configure when 'make' is first run. We can't define
    # LDFLAGS here, as it breaks configure. So we forcibly configure
    # everything first, then build it to avoid problems.
    # FIXME: use the static_link value from the config file
    if test `echo ${tool} | egrep -c binutils` -gt 0; then
	local makeret=
	dryrun "make SHELL=${bash_shell} configure-host ${make_flags} -w -C ${builddir} 2>&1 | tee -a ${builddir}/configure.log"
     	local make_flags="${make_flags} LDFLAGS='-all-static -static -lstdc++'"
	local makeret=$?
    fi
    if test `echo ${tool} | egrep -c gcc` -gt 0; then
     	local make_flags="${make_flags} LDFLAGS='-static -lstdc++'"	
    fi

    local makeret=
    dryrun "make SHELL=${bash_shell} ${make_flags} -w -C ${builddir} 2>&1 | tee ${builddir}/make.log"
    local makeret=$?

    # Make sure the make.log file is in place before grepping or the -gt
    # statement is ill formed.  There is not make.log in a dryrun.
    if test -e "${builddir}/make.log"; then
       if test `grep -c "configure-target-libgcc.*ERROR" ${builddir}/make.log` -gt 0; then
           error "libgcc wouldn't compile! Usually this means you don't have a sysroot installed!"
       fi
    fi
    if test ${makeret} -gt 0; then
	warning "Make had failures!"
	return 1
    fi

    return 0
}

make_install()
{
    trace "$*"

    # see if the users wants multiple make jobs, which we ignore for native
    # ARM or AARCH64 as the hardware can't handle the load.
    if test x"${parallel}" = x"yes" -a `echo ${build} | egrep -c "arm|aarch64"` -eq 0; then
     	local make_flags="${make_flags} -j ${cpus}"
    fi

    local tool="`get_git_tool $1`"
    if test x"${tool}" = x"linux"; then
     	local srcdir="`get_srcdir $1`"
	if test `echo ${target} | grep -c aarch64` -gt 0; then
	    dryrun "make ${make_opts} -C ${srcdir} headers_install ARCH=arm64 INSTALL_HDR_PATH=${sysroots}/usr"
	else
	    dryrun "make ${make_opts} -C ${srcdir} headers_install ARCH=arm INSTALL_HDR_PATH=${sysroots}/usr"
	fi
	return 0
    fi

    local builddir="`get_builddir $1 $2`"
    notice "Making install in ${builddir}"

    if test "`echo ${tool} | grep -c glibc`" -gt 0; then
	local make_flags=" install_root=${sysroots} ${make_flags}"
    fi

    # NOTE: $make_flags is dropped, as newlib's 'make install' doesn't
    # like parallel jobs. We also change tooldir, so the headers and libraries
    # get install in the right place in our non-multilib'd sysroot.
    if test x"${tool}" = x"newlib"; then
        # as newlib supports multilibs, we force the install directory to build
        # a single sysroot for now. FIXME: we should not disable multilibs!
	local make_flags=" tooldir=${sysroots}/usr/"
    fi

    # Don't stop on CONFIG_SHELL if it's set in the environment.
    if test x"${CONFIG_SHELL}" = x; then
	export CONFIG_SHELL=${bash_shell}
    fi

    if test x"${tool}" = x"binutils"; then
	# FIXME: binutils in the 2.23 linaro branch causes 'make install'
	# due to an info file problem, so we ignore the error so the build
	# will continue.
	dryrun "make install ${make_flags} -i -k -w -C ${builddir} 2>&1 | tee ${builddir}/install.log"
    else
	dryrun "make install ${make_flags} -w -C ${builddir} 2>&1 | tee ${builddir}/install.log"
    fi

    if test $? != "0"; then
	warning "Make install failed!"
	return 1
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
	local builddir="`get_builddir $1 $2`"
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
	    local builddir="`get_builddir ${binutils_version}`"
	    dryrun "make -C ${builddir}/as check-DEJAGNU RUNTESTFLAGS=${runtest_flags} ${make_flags} -w -i -k 2>&1 | tee ${builddir}/check-binutils.log"
	    dryrun "make -C ${builddir}/ld check-DEJAGNU RUNTESTFLAGS=${runtest_flags} ${make_flags} -w -i -k 2>&1 | tee -a ${builddir}/check-binutils.log"
	    ;;
	gcc*)
	    local builddir="`get_builddir ${gcc_version} $2`"
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
    local builddir="`get_builddir $1 $2`"

    notice "Making check in ${builddir}"

#    if test x"$2" != x; then
#	make_check_installed
#	return 0
#    fi

    # see if the users wants multiple make jobs, which we ignore for native
    # ARM or AARCH64 as the hardware can't handle the load.
    if test x"${parallel}" = x"yes" -a "`echo ${build} | egrep -c 'arm|aarch64'`" -eq 0; then
     	make_flags="${make_flags} -j ${cpus}"
    fi

    # load the config file for Linaro build farms
    if test x"${DEJAGNU}" = x; then
	export DEJAGNU=${topdir}/config/linaro.exp
    fi

    dryrun "make check RUNTESTFLAGS=${runtest_flags} ${make_flags} -w -i -k -C ${builddir} 2>&1 | tee ${builddir}/check.log"
    
    return 0
}

make_clean()
{
    trace "$*"

    builddir="`get_builddir $1 $2`"
    notice "Making clean in ${builddir}"

    if test x"$2" = "dist"; then
	make distclean ${make_flags} -w -i -k -C ${builddir}
    else
	make clean ${make_flags} -w -i -k -C ${builddir}
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

    local builddir="`get_builddir $1 $2`"

    notice "Making docs in ${builddir}"

    case $1 in
	*binutils*)
	    # the diststuff target isn't supported by all the subdirectories,
	    # so we build both all targets and ignore the error.
	    dryrun "make SHELL=${bash_shell} ${make_flags} -i -k -w -C ${builddir}/bfd diststuff install-man install-html install-info 2>&1 | tee -a ${builddir}/make.log"
	    dryrun "make SHELL=${bash_shell} ${make_flags} -i -k -w -C ${builddir}/ld diststuff install-man install-html install-info 2>&1 | tee -a ${builddir}/make.log"
	    dryrun "make SHELL=${bash_shell} ${make_flags} -i -k -w -C ${builddir}/gas diststuff install-man install-html install-info 2>&1 | tee -a ${builddir}/make.log"
	    dryrun "make SHELL=${bash_shell} ${make_flags} -i -k -w -C ${builddir}/gprof diststuff install-man install-html install-info 2>&1 | tee -a ${builddir}/make.log"
	    dryrun "make SHELL=${bash_shell} ${make_flags} -i -k -w -C ${builddir} install-html install-info 2>&1 | tee -a ${builddir}/make.log"
	    return $?
	    ;;
	*gdb*)
	    dryrun "make SHELL=${bash_shell} ${make_flags} -i -k -w -C ${builddir}/gdb diststuff install-html install-info 2>&1 | tee -a ${builddir}/make.log"
	    return $?
	    ;;
	*gcc*)
	    #dryrun "make SHELL=${bash_shell} ${make_flags} -w -C ${builddir} doc html info man 2>&1 | tee -a ${builddir}/make.log"
	    dryrun "make SHELL=${bash_shell} ${make_flags} -i -k -w -C ${builddir} install-html install-info 2>&1 | tee -a ${builddir}/make.log"
	    return $?
	    ;;
	*linux*)
	    # no docs to install for this component
	    ;;
	*libc*) # including eglibc
	    #dryrun "make SHELL=${bash_shell} ${make_flags} -w -C ${builddir} info dvi pdf html 2>&1 | tee -a ${builddir}/make.log"
	    dryrun "make SHELL=${bash_shell} ${make_flags} -w -C ${builddir} info html 2>&1 | tee -a ${builddir}/make.log"
	    return $?
	    ;;
	*)
	    dryrun "make SHELL=${bash_shell} ${make_flags} -w -C ${builddir} info man 2>&1 | tee -a ${builddir}/make.log"
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

