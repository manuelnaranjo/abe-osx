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
	local builds="infrastructure binutils stage1 libc stage2"
    else
	local builds="infrastructure binutils stage2" # native build
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

    # cross builds need to build a minimal C compiler, which after compiling
    # the C library, can then be reconfigured to be fully functional.

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
		;;
	    # Build stage 1 of GCC, which is a limited C compiler used to compile
	    # the C library.
	    libc)
		if test x"${clibrary}" = x"eglibc"; then
		    build ${eglibc_version}
		else
		    build ${newlib_version}
		fi
		if test $? -gt 0; then
		    error "Couldn't build ${clibrary}!"
		    return 1
		fi
		;;
	    stage1)
		build ${gcc_version} stage1
		;; 
	    # Build stage 2 of GCC, which is the actual and fully functional compiler
	    stage2)
		build ${gcc_version} stage2
		;;
	    # Build anything not GCC or infrastructure
	    *)
		build ${binutils_version}
		;;
	esac
	if test $? -gt 0; then
	    error "Couldn't build all!"
	    return 1
	fi
    done

    notice "Build took ${SECONDS} seconds"
    
    if test x"${tarballs}" = x"yes"; then
	gcc_src_tarball

	manifest ${gcc_version}
	binary_tarball 
    fi

    return 0
}

build()
{
    trace "$*"

    # Start by fetching the tarball to build, and extract it, or it a URL is
    # supplied, checkout the sources.
    if test `echo $1 | egrep -c "^bzr|^svn|^git|^lp"` -gt 0; then	
	local tool="`basename $1 | sed -e 's:\..*::' | cut -d '/' -f 1`"
	local file="`basename $1`"
    else
	if test `echo $1 | egrep -c "\.git"` -gt 0; then	
	    local tool="`dirname $1 | sed -e 's:\..*::' | cut -d '/' -f 1`"
	    local file="`dirname $1`"
	else
	    local tool="`echo $1 | sed -e 's:-[0-9].*::'`"
	    local file="`echo $1 | sed -e 's:\.tar\..*::'`"
	fi
    fi

    # if it's already installed, we don't need to build it unless we force the
    # build. GCC gets built and installed twice, so we don't check for that
    # component.
#    if test x"${force}" != xyes -a x"${tool}" != x"gcc"; then
#     	#built ${name}
#     	installed ${tool}
#     	if test $? -eq 0; then
#     	    notice "${tool} already installed, so not building"
#     	    return 0
#    	fi
#    fi

    source_config ${tool}
    # if test $? -gt 0; then
    # 	return 1
    # fi
    if test `echo $1 | egrep -c "\.gz|\.bz2|\.xz"` -gt 0; then	
	local url=$1
    else
	local url="`get_source $1 | cut -d ' ' -f 1`"
    fi
    # If the tarball hasn't changed, then don't fetch anything
    if test ${local_builds}/${host}/${target}/stamp-build-${file} -nt ${local_snapshots}/${url} -a x"${force}" = xno; then
     	fixme "stamp-build-${file} is newer than ${url}, so not building ${file}"
	return 0
    else
     	fixme "stamp-build-${file} is not newer than ${url}, so building ${file}"
    fi    
    
    notice "Building ${url}"

    # if test $? -gt 0; then
    # 	return 1
    # fi
    # Get the list of other components that need to be built first.
    # if test x"${nodepends}" = xno; then
    # 	local components="`dependencies ${tool}`"
    # 	for i in ${components}; do
    # 	    installed $i
    # 	        # Build and install the component if it's not installed already
    # 	    if test $? -gt 0 -o x"${force}" = xyes; then
    # 		    # preserve the current shell environment to avoid contamination
    # 		rm -f $1.env
    # 		set 2>&1 | grep "^[a-z_A-Z-]*=" > $1.env
    # 		build $i
    # 		. $1.env
    # 		rm -f $1.env
    # 	    fi
    # 	done
    # fi
    
    if test `echo ${url} | egrep -c "^bzr|^svn|^git|^lp"` -gt 0; then	
	# Don't checkout
	if test x"$2" != x"stage2"; then
	    checkout ${url}
	fi
    else
	if test x"$2" != x"stage2"; then
	    fetch ${url}
	    extract ${url}
	fi
    fi

    notice "Configuring ${url}..."
    configure_build ${url} $2
    if test $? -gt 0; then
	error "Configure of ${url} failed!"
	return $?
    fi
    
    # Clean the build directories when forced
    if test x"${force}" = xyes; then
	make_clean ${url}
	if test $? -gt 0; then
	    return 1
	fi
    fi
    
    # Finally compile and install the libaries
    make_all ${url}
    if test $? -gt 0; then
	return 1
    fi

#    if test x"${install}" = x"yes"; then    
	make_install ${url}
	if test $? -gt 0; then
	    return 1
	fi
#    else
#	notice "make installed disabled by user action."
#	return 0
#    fi

    # See if we can compile and link a simple test case.
    if test x"$2" = x"stage2" -a x"${clibrary}" != x"newlib"; then
	hello_world
	if test $? -gt 0; then
	    error "Hello World test failed for ${url}..."
	#return 1
	else
	    notice "Hello World test succeeded for ${url}..."
	fi
    fi

    touch ${local_builds}/${host}/${target}/stamp-build-${file}     
    notice "Done building ${url} $1..."

    # For cross testing, we need to build a C library with our freshly built
    # compiler, so any tests that get executed on the target can be fully linked.
    if test x"${runtests}" = xyes; then
	if test x"$2" != x"stage1"; then
	    notice "Starting test run for ${url}"
	    make_check ${url}
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

    builddir="`get_builddir $1`"
    notice "Making all in ${builddir}"

    if test x"${use_ccache}" = xyes -a x"${build}" = x"${host}"; then
     	make_flags="${make_flags} CC='ccache gcc' CXX='ccache g++'"
    fi

    if test x"${CONFIG_SHELL}" = x; then
	export CONFIG_SHELL=${bash_shell}
    fi
    dryrun "make SHELL=${bash_shell} ${make_flags} -w -C ${builddir} $2 2>&1 | tee ${builddir}/make.log"
    if test $? -gt 0; then
	warning "Make had failures!"
	return 1
    fi

    return 0
}

make_install()
{
    trace "$*"

    local tool="`get_toolname $1`"
    if test x"${tool}" = x"linux"; then
     	local srcdir="`echo $1 | sed -e 's:\.tar\..*::'`"
	if test `echo ${target} | grep -c aarch64` -gt 0; then
	    dryrun "make ${make_opts} -C ${local_snapshots}/${srcdir} headers_install ARCH=arm64 INSTALL_HDR_PATH=${sysroots}/usr"
	else
	    dryrun "make ${make_opts} -C ${local_snapshots}/${srcdir} headers_install ARCH=arm INSTALL_HDR_PATH=${sysroots}/usr"
	fi
	return 0
    fi

    local builddir="`get_builddir $1`"
    notice "Making install in ${builddir}"

    if test x"${tool}" = x"eglibc"; then
	make_flags=" install_root=${sysroots} ${make_flags}"
    fi

    # NOTE: $make_flags is dropped, as newlib's 'make install' doesn't
    # like parallel jobs. We also change tooldir, so the headers and libraries
    # get install in the right place in our non-multilib'd sysroot.
    if test x"${tool}" = x"newlib"; then
        # as newlib supports multilibs, we force the install directory to build
        # a single sysroot for now. FIXME: we should not disable multilibs!
	make_flags=" tooldir=${sysroots}/usr/"
    fi

    # Don't stop on CONFIG_SHELL if it's set in the environment.
    if test x"${CONFIG_SHELL}" = x; then
	export CONFIG_SHELL=${bash_shell}
    fi
    dryrun "make install ${make_flags} $2 -w -C ${builddir}"

    if test $? != "0"; then
	warning "Make install failed!"
	return 1
    fi

    return 0
}

make_check()
{
    trace "$*"

    if test x"${builddir}" = x; then
	builddir="`get_builddir $1`"
    fi
    notice "Making check in ${builddir}"

#    dryrun "make check RUNTESTFLAGS="${runtest_flags} -a" ${make_flags} -w -i -k -C ${builddir} 2>&1 | tee ${builddir}/check.log"
    dryrun "make check RUNTESTFLAGS=${runtest_flags} ${make_flags} -w -i -k -C ${builddir} 2>&1 | tee ${builddir}/check.log"
    if test $? -gt 0; then
	warning "Make check had failures!"
	return 1
    fi

    return 0
}

make_clean()
{
    trace "$*"

    builddir="`get_builddir $1`"
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

# See if we can link a simple executable
hello_world()
{

    # Create the usual Hello World! test case
    cat <<EOF > hello.cpp
#include <iostream>
int
main(int argc, char *argv[])
{
    std::cout << "Hello World!" << std::endl; 
}
EOF

    # See if a test case compiles to a fully linked executable. Since
    # our sysroot isn't installed in it's final destination, pass in
    # the path to the freshly built sysroot.
    dryrun ${target}-g++ -static --sysroot=${sysroot}/${host} -o hi hello.cpp
}
