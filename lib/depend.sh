#!/bin/sh

#
# Build the dependencies needed to build the toolchain
#

depend()
{
    warning "unimplemented"

    echo "FIXME depend(): ${depends}"
}

# These are the latest copies of the infrastructure files required to
# fully build GCC in all it's glory. While it is possible to pass
# --disable-* options at configure time to GCC, these are use for
# good reason, so we download, build and install them.
infrastructure()
{
    fetch_http infrastructure/md5sums
    fetch_http infrastructure/ChangeLog

    # Get the list of files from the md5sums list
    files="`cat ${local_snapshots}/infrastructure/md5sums | cut -d ' ' -f 3`"
    if test -e "$(dirname "$0")/config/infrastructure.conf"; then
	. "$(dirname "$0")/config/infrastructure.conf"
    fi

    if test x"${depends}" = x; then
	error "No dependencies listed for infrastructure libraries!"
	return 1
    fi
    
    # We have to grep each dependency separetly to preserve the order, as
    # some libraries depend on other libraries being bult first. Egrep
    # unfortunately sorts the files, which screws up the order.
    files=
    for i in ${depends}; do
     	files="${files} `grep $i ${local_snapshots}/infrastructure/md5sums | cut -d ' ' -f3`"
    done
    
    # first fetch and extract all the tarballs listed in the md5sums file
    for i in ${files}; do
	fetch_http infrastructure/$i
	extract infrastructure/$i
	name="`echo $i | sed -e 's:\.tar\..*::'`"
	# get any configure flags specific to this program, which are
	# usually dependant libaries we've already built.
	tool="`echo $i | sed -e 's:-[0-9].*::'`"
	if test -e "$(dirname "$0")/config/${tool}.conf"; then
	    . "$(dirname "$0")/config/${tool}.conf"
	fi
	notice "Configuring infrastructure/${name}..."
	configure infrastructure/${name} --disable-shared --enable-static --prefix=${PWD}/${hostname}/${build}/depends ${default_configure_flags}
	if test $? != "0"; then
	    warning "Configure of ${name} failed!"
	fi
	# unset these two variables to avoid problems later
	default_configure_flags=
	depends=
	make_all infrastructure/${name}
	if test $? = "0"; then
	    make_install infrastructure/${name}
	    if test $? != "0"; then
		warning "Make install of ${name} failed!"
	    fi
	fi
    done
}

