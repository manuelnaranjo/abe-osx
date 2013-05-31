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

    # Get the list of files from the md5sums list
    files="`cat ${local_snapshots}/infrastructure/md5sums | cut -d ' ' -f 3`"
    if test -e "$(dirname "$0")/config/infrastructure.conf"; then
	. "$(dirname "$0")/config/infrastructure.conf"
    fi

    if test x"${depends}" = x; then
	error "No dependencies listed for inrastructure libraries!"
	return 1
    fi
    
    greparg="`echo ${depends} | tr ' ' '|'`"
    files="`egrep " (ppl|isl|mpc|gmp|mpfr)" /linaro/src/linaro/cbuild/snapshots/infrastructure/md5sums | cut -d ' ' -f3`"

    # first fetch and extract all the tarballs listed in the md5sums file
    for i in ${files}; do
	fetch_http infrastructure/$i
	extract infrastructure/$ig
	name="`echo $i | sed -e 's:\.tar\..*::'`"
	# get any configure flags specific to this program, which are
	# usually dependant libaries we've already built.
	tool="`echo $i | sed -e 's:-[0-9].*::'`"
	if test -e "$(dirname "$0")/config/${tool}.conf"; then
	    . "$(dirname "$0")/config/${tool}.conf"
	fi
	configure infrastructure/${name} --disable-shared --enable-static --prefix=${PWD}/${hostname}/${build}/depends ${default_configure_flags}
	# unset these two variables to avoid problems later
	default_configure_flags=
	depends=
	make_all infrastructure/${name}
	make_install infrastructure/${name}
    done
}

