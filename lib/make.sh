#!/bin/sh

#
#
#

# This performs all the steps to build a full cross toolchain
build_cross()
{
    
    builds="infrastructure stage1 eglibc stage2" # libstdc
    for i in ${builds}; do
	case $i in
	    infrastructure)
		infrastructure
		;;
	    # Build stage 1 of GCC, which is a limited C compiler used to compile
	    # the C library.
	    stage1)
		latest_version="`grep ^latest= ${topdir}/config/gcc.conf | cut -d '\"' -f 2`"
		build ${latest_version} stage1
		;; 
	    # Build stage 2 of GCC, which is the actual and fully functional compiler
	    stage2)
		latest_version="`grep ^latest= ${topdir}/config/gcc.conf | cut -d '\"' -f 2`"
		build ${latest_version} stage2
		;;
	    # Build anything not GCC or infrastructure
	    *)
		latest_version="`grep ^latest= ${topdir}/config/$i.conf | cut -d '\"' -f 2`"
		build ${latest_version}
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
	( cd ${local_snapshots}/${srcdir} && make headers_install ARCH=arm INSTALL_HDR_PATH=${local_builds}/sysroot/usr)
	return 0
    fi
#make headers_install INSTALL_HDR_PATH=/linaro/build/x86_64-linux-gnu/cbuild2/linaro.welcomehome.org/x86_64-unknown-linux-gnu/depends/sysroot/

    # Then configure as a separate step, so if something goes wrong, we
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
