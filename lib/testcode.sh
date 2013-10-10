#!/bin/bash

# Build other comonly used projects as an additional test of the toolchain

testcode()
{
    rm -f ${local_snapshots}/testcode/ChangeLog
    fetch_http testcode/ChangeLog

    if test -f ${local_snapshots}/md5sums; then
     	files="`grep testcode ${local_snapshots}/md5sums | cut -d ' ' -f3`"
     	for i in ${files}; do
     	    build $i
	    if test $? -gt 0; then
		error "Couldn't build $i!"
		return 1
	    fi
     	done
    fi
   
}

