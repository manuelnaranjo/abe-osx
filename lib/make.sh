#!/bin/sh

#
#
#

build()
{
    # Start by fetching the tarball to build, and extract it, or it a URL is
    # supplied, checkout the sources.
    if test `echo $1 | egrep -c "^bzr|^svn|^git"` -gt 0; then	
	checkout $1
	tool="`basename $1 | sed -e 's:\..*::'`"
	name="`basename $1`"
    else
	fetch $1
	md5file="`grep ${file} ${local_snapshots}/md5sums | cut -d ' ' -f 3`"
	if test x"{$file}" != x; then
	    getfile="${md5file}"
	fi
	extract ${md5file}
	tool="`echo $1 | sed -e 's:-[0-9].*::'`"
	name="`echo $1 | sed -e 's:\.tar\..*::'`"
    fi

    # Then configure as a separate step, so if something goes wrong, we
    # at least have the sources
    # unset these two variables to avoid problems later
    # default_configure_flags=
    #export PATH="${PWD}/${hostname}/${build}/depends/bin:$PATH"
    export LD_LIBRARY_PATH="${PWD}/${hostname}/${build}/depends/lib"
    if test -e "$(dirname "$0")/config/${tool}.conf"; then
	. "$(dirname "$0")/config/${tool}.conf"
    fi
    notice "Configuring ${name}..."
    configure_build ${name} ${default_configure_flags}
    if test $? != "0"; then
	error "Configure of ${name} failed!"
	return $?
    fi

# CFLAGS=-B${PWD}/${hostname}/${build}/depends

    # Finally compile and install the libaries
    make_all ${name}
    if test $? -gt 0; then
	return 1
    fi
    make_install ${name}
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
    node="`normalize_path $1`"
    if test x"${target}" = x; then
	target=${build}
    fi
    if test `echo $1 | grep -c eglibc` -gt 0; then
	builddir="echo ${cbuild_top}/${hostname}/${target}/${node}"
    else
	builddir="${PWD}/${hostname}/${target}/${node}"
    fi

    notice "Making all in ${builddir}"

    export CONFIG_SHELL=${bash_shell}
    make SHELL=${bash_shell} ${make_flags} -w -i -k -C ${builddir} 2>&1 | tee ${builddir}/make.log
    if test $? -gt 0; then
	warning "Make had failures!"
	return 1
    fi

    return 0
}

make_install()
{
    if test x"${target}" = x; then
	target=${build}
    fi
    node="`normalize_path $1`"
    builddir="${PWD}/${hostname}/${target}/${node}"
    notice "Making install in ${builddir}"

    make install  ${make_flags} -w -i -k -C ${builddir} 2>&1 | tee ${builddir}/install.log
    if test $? != "0"; then
	warning "Make failed!"
	return 1
    fi

    return 0
}

make_check()
{
    if test x"${target}" = x; then
	target=${build}
    fi
    notice "Making check in ${builddir}"

    make check RUNTESTFLAGS="${runtest_flags} -a" ${make_flags} -w -i -k -C ${builddir} 2>&1 | tee ${builddir}/check.log
    if test $? -gt 0; then
	warning "Make check had failures!"
	return 1
    fi

    return 0
}