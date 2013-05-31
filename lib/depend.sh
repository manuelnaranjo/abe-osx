#!/bin/sh

#
# Build the dependencies needed to build the toolchain
#

infrastructure()
{
    fetch_http infrastructure/md5sums

    # Get the list of files from the md5sums list
    files="`cat ${local_snapshots}/infrastructure/md5sums | cut -d ' ' -f 3`"

    # first fetch and extract all the tarballs listed in the md5sums file
    for i in ${files}; do
	fetch_http infrastructure/$i
	extract infrastructure/$i
	name="`echo $i | sed -e 's:\.tar\..*::'`"
    done

    # Then configure as a separate step, so if something goes wrong, we
    # at least have the sources
    for i in ${files}; do
	name="`echo $i | sed -e 's:\.tar\..*::'`"
	configure infrastructure/${name} --disable-shared --enable-static --prefix=${PWD}/${hostname}/${build}/depends
    done

    # Finally compile and install the libaries
    for i in ${files}; do
	name="`echo $i | sed -e 's:\.tar\..*::'`"
	build infrastructure/${name}
	install infrastructure/${name}
    done
}