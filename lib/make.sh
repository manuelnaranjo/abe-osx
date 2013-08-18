#!/bin/sh

#
#
#

# This performs all the steps to build a full cross toolchain
build_all()
{
    # Turn off dependency checking, as everything is handled here
    nodepends=yes

    # Specify the components, in order to get a full toolchain build
    if test x"${build}" != x"${target}"; then
	builds="infrastructure binutils stage1 libc stage2"
    else
	builds="infrastructure binutils stage2 libc" # native build
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

    # cross builds need to build a minimal C compiler, which after compiling
    # the C library, can then be reconfigured to be fully functional.

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
		;;
	    # Build stage 1 of GCC, which is a limited C compiler used to compile
	    # the C library.
	    libc)
		build eglibc-${eglibc_version}
		if test $? -gt 0; then
		    error "Couldn't build eglibc!"
		    return 1
		fi
		;;
	    stage1)
		build gcc-${gcc_version} stage1
		;; 
	    # Build stage 2 of GCC, which is the actual and fully functional compiler
	    stage2)
		build ${gcc_version} stage2
		;;
	    # Build anything not GCC or infrastructure
	    *)
		build binutils-${binutils_version}
		;;
	esac
	if test $? -gt 0; then
	    error "Couldn't build $i"
	    return 1
	fi
    done

    return 0
}

build()
{
    # Start by fetching the tarball to build, and extract it, or it a URL is
    # supplied, checkout the sources.
    if test `echo $1 | egrep -c "^bzr|^svn|^git|^lp"` -gt 0; then	
	tool="`basename $1 | sed -e 's:\..*::'`"
	name="`basename $1`"
    else
	tool="`echo $1 | sed -e 's:-[0-9].*::'`"
	name="`echo $1 | sed -e 's:\.tar\..*::'`"
    fi

    # if it's already instaled, we don't need to build it unless we force the build
    # if test x"${force}" != xyes; then
    # 	installed ${tool}
    # 	if test $? -eq 0; then
    # 	    notice "${tool} already installed, so not building"
    # 	    return 0
    # 	fi
    # fi

    # If the sources can't be found, there is no reason to continue.
    source_config ${tool}
    # if test $? -gt 0; then
    # 	return 1
    # fi
    get_source $1
    notice "Building ${url}"

    # if test $? -gt 0; then
    # 	return 1
    # fi
    # Get the list of other components that need to be built first.
    if test x"${nodepends}" = xno; then
	dependencies ${tool}
	if test $? -eq 0; then
	    for i in ${components}; do
		installed $i
	        # Build and install the component if it's not installed already
		if test $? -gt 0 -o x"${force}" = xyes; then
		    # preserve the current shell environment to avoid contamination
		    rm -f $1.env
		    set 2>&1 | grep "^[a-z_A-Z-]*=" > $1.env
		    build $i
		    . $1.env
		fi
	    done
	fi
    fi
    
    if test `echo ${url} | egrep -c "^bzr|^svn|^git|^lp"` -gt 0; then	
	checkout ${url}
    else
	fetch ${url}
	extract ${url}
    fi

    # This command is only used to install the Linux kernel headers, which are
    # later used to compile eglibc.
    tool="`echo $1 | cut -d '-' -f 1`"
    if test x"${tool}" = x"linux"; then
	srcdir="`echo $1 | sed -e 's:\.tar\..*::'`"
	make -C ${local_snapshots}/infrastructure/${srcdir} headers_install ARCH=arm INSTALL_HDR_PATH=${sysroots}/usr
	return 0
    fi

    # Then configure as a seperate step, so if something goes wrong, we
    # at least have the sources
    # unset these two variables to avoid problems later
    # default_configure_flags=
    #export PATH="${PWD}/${hostname}/${build}/depends/bin:$PATH"
    #export LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:${local_builds}/depends/lib:${local_builds}/depends/sysroot/usr/lib"
    notice "Configuring ${url}..."
    if test x"$2" != x; then
	configure_build ${url} $2
    else
	configure_build ${url}
    fi

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
    
    make_install ${url}
    if test $? -gt 0; then
	return 1
    fi
    notice "Done building ${url} $1..."
    
# For cross testing, we need to build a C library with our freshly built
# compiler, so any tests that get executed on the target can be fully linked.
#    make_check ${name}
#    if test $? -gt 0; then
#	return 1
#    fi

    return 0
}

make_all()
{
    builddir="`get_builddir $1`"
    notice "Making all in ${builddir}"

    export CONFIG_SHELL=${bash_shell}
    make SHELL=${bash_shell} ${make_flags} -w -C ${builddir} 2>&1 | tee ${builddir}/make.log
    if test $? -gt 0; then
	warning "Make had failures!"
	return 1
    fi

    return 0
}

make_install()
{
    builddir="`get_builddir $1`"
    notice "Making install in ${builddir}"

    if test x"${tool}" = x"eglibc"; then
	make_flags=" install_root=${sysroots} ${make_flags}"
    fi

    export CONFIG_SHELL=${bash_shell}
    make install SHELL=${bash_shell} ${make_flags} -w -C ${builddir} 2>&1 | tee ${builddir}/install.log
    if test $? != "0"; then
	warning "Make failed!"
	return 1
    fi

    return 0
}

make_check()
{
    builddir="`get_builddir $1`"
    notice "Making check in ${builddir}"

    make check RUNTESTFLAGS="${runtest_flags} -a" ${make_flags} -w -i -k -C ${builddir} 2>&1 | tee ${builddir}/check.log
    if test $? -gt 0; then
	warning "Make check had failures!"
	return 1
    fi

    return 0
}

make_clean()
{
    builddir="`get_builddir $1`"
    notice "Making clean in ${builddir}"

    if test x"$2" = "dist"; then
	make distclean ${make_flags} -w -i -k -C ${builddir}
    else
	make clean ${make_flags} -w -i -k -C ${builddir}
    fi
    if test $? != "0"; then
	warning "Make failed!"
	return 1
    fi

    return 0
}

# See if we can link a simple executable
hello_world()
{

    # Create the usual Hello World! test case
    cat <<EOF >hello.cpp
#include <iostream>
int
main(int argc, char *argv[])
{
    std::cout << "Hello World!" << std::endl; 
}
EOF


    # See if it compiles to a fully linked executable
    ${target}-gcc -static -o hi hello.c

}
