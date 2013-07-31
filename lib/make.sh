#!/bin/sh

#
#
#

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
		if test $? -gt 0; then
		    echo "BUILD: $i"
		# preserve the current shell environment to avoid contamination
		    rm -f $1.env
		    set 2>&1 | grep "^[a-z_A-Z-]*=" > $1.env
		    build $i
		#${topdir}/cbuild2.sh --dostep build $i
		# restore the current shell environment that was saved.
		    . $1.env
		# if test $? -gt 0; then
		# fi
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

#make headers_install INSTALL_HDR_PATH=/linaro/build/x86_64-linux-gnu/cbuild2/linaro.welcomehome.org/x86_64-unknown-linux-gnu/depends/sysroot/

    # Then configure as a separate step, so if something goes wrong, we
    # at least have the sources
    # unset these two variables to avoid problems later
    # default_configure_flags=
    #export PATH="${PWD}/${hostname}/${build}/depends/bin:$PATH"
    #export LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:${local_builds}/depends/lib:${local_builds}/depends/sysroot/usr/lib"
    notice "Configuring ${url}..."
    configure_build ${url}
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

    make install  ${make_flags} -w -C ${builddir} 2>&1 | tee ${builddir}/install.log
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
