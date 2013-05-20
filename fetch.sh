#!/bin/sh

# Fetch a file from a remote machine
fetch()
{
    if test x"$1" = x; then
	error "No file name specified to fetch!"
	return 1
    else
	file=$1
    fi
    if test x"$2" = x; then
	warning "No fetching protocol specified!"
	protocol=http
    else
	protocol=$2
    fi
 
    getfile=${file}.tar.xz
    fetch_${protocol} ${getfile}
    if test $? -gt 0; then
	error "couldn't fetch $1, trying xdelta3 instead"
	getfile=${file}.tar.xdelta3.xz
	fetch_${protocol} ${file}
	if test $? -gt 0; then
	    error "couldn't fetch $1"
	    getfile=${file}.tar.bz2
	    fetch_${protocol} ${getfile}
	    if test $? -gt 0; then
		error "couldn't fetch $1"
		return 1
	    fi
	fi
	return 1
    fi

    notice "Fetched ${getfile} via ${protocol}"

    check_md5sum ${file}
    if test $? -gt 0; then
	return 1
    fi
    return 0
}

fetch_http()
{
    getfile=$1

    if test ! -e ${local_snapshots}/${getfile} -o x"${clobber}" = xyes; then
	if test x"${wget_bin}" != x; then
	    ${wget_bin} --continue --progress=bar --directory-prefix=${local_snapshots} \
		${remote_snapshots}/${getfile}
	    if test ! -e ${local_snapshots}/${getfile}; then
		warning "${getfile} didn't download via http!"
		return 1
	    fi
	fi
    else
	notice "${getfile} already exists in ${local_snapshots}"
    fi
    return 0
}

fetch_scp()
{
    error "unimplemented"
}

fetch_rsync()
{
    error "unimplemented"
}

check_md5sum()
{
    fetch_http md5sums
    if test $? -gt 0; then
	error "couldn't fetch md5sums"
	return 1
    fi

    # Drop the file name from .tar to the end to keep grep happy
    getfile=`echo ${1} | sed -e 's:.tar.*::'`

    newsum="`md5sum ${local_snapshots}/$1`"
    oldsum="`grep ${getfile} ${local_snapshots}/md5sums`"
    if test x"${oldsum}" = x; then
	error "No md5sum entry for $1!"
	return 1
    fi

    if test x"${oldsum}" = x"${newsum}"; then
	notice "md5sums matched"
	return 0
    else
	error "md5sums don't match!"
	return 1
    fi
}
