#!/bin/sh

#
#
#

build()
{
    builddir="${PWD}/${hostname}/${target}/$1"
    notice "Makeing all in ${builddir}"

    make all -i -k -C ${builddir} 2>&1 | tee ${builddir}/make.log
    if test $? -gt 0; then
	warning "Make failed!"
    fi
}

install()
{
    builddir="${PWD}/${hostname}/${target}/$1"
    notice "Makeing install in ${builddir}"

    make install -i -k -C ${builddir} 2>&1 | tee ${builddir}/install.log
    if test $? -gt 0; then
	warning "Make failed!"
    fi
}
