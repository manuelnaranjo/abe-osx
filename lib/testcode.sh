#!/bin/bash

# Build other comonly used projects as an additional test of the toolchain

testcode()
{
    # force downloading the md5sum file, as it changes frequently
    rm -f ${local_snapshots}/testcode/md5sums
    fetch_http testcode/md5sums

    if test -f ${local_snapshots}/testcode/md5sums; then
     	files="`cat ${local_snapshots}/testcode/md5sums | cut -d ' ' -f3`"
     	for i in ${files}; do
     	    build testcode/$i
	    if test $? -gt 0; then
		error "Couldn't build testcode/$i!"
		return 1
	    fi
     	done
    fi
   
}

