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
	notice "Using default fetching protocol 'http'"
	protocol=http
    else
	protocol=$2
    fi
 
    # start by grabbing the md5sum file. We delete the current one as we
    # always want a fresh md5sums file, as it changes every day, so older
    # versions go out of doubt.
    rm -f ${local_snapshots}/md5sums
    fetch_http md5sums
    
    # We can grab the full file name by searching for it in the md5sums file.
    # This is better than guessing, which we do anyway if for some reason the
    # file isn't listed in the md5sums file.
    md5file="`grep ${file} ${local_snapshots}/md5sums | cut -d ' ' -f 3`"
    if test x"{$file}" != x; then
	getfile="${md5file}"
    else
	getfile=${file}.tar.xz
    fi

    # download the file
    fetch_${protocol} ${getfile}
    if test $? -gt 0; then
	warning "couldn't fetch $1, trying xdelta3 instead"
	getfile=${file}.tar.xdelta3.xz
	fetch_${protocol} ${file}
	if test $? -gt 0; then
	    warning "couldn't fetch ${getfile}, trying .bz2 instead"
	    getfile=${file}.tar.bz2
	    fetch_${protocol} ${getfile}
	    if test $? -gt 0; then
		error "couldn't fetch ${getfile}"
		return 1
	    fi
	fi
	return 1
    fi

    notice "Fetched ${getfile} via ${protocol}"

    check_md5sum ${getfile}
    if test $? -gt 0; then
	return 1
    fi
    return 0
}

fetch_http()
{
    getfile=$1
    dir="`dirname $1`"
    if test x"${dir}" = x"."; then
	dir=""
    else
	if test ! -d ${local_snapshots}/${dir}; then
	    mkdir -p ${local_snapshots}/${dir}
	fi
    fi

    if test ! -e ${local_snapshots}/${getfile} -o x"${clobber}" = xyes; then
	if test x"${wget_bin}" != x; then
	    ${wget_bin} --continue --progress=bar --directory-prefix=${local_snapshots}/${dir} \
		${remote_snapshots}/${getfile} 2> /dev/null
	    if test ! -e ${local_snapshots}/${getfile}; then
		# warning "${getfile} didn't download via http!"
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
    if test ! -e ${local_snapshots}/md5sums; then
	fetch_http md5sums
	if test $? -gt 0; then
	    error "couldn't fetch md5sums"
	    return 1
	fi
    fi

    # Drop the file name from .tar to the end to keep grep happy
    getfile=`echo ${1}`

    newsum="`md5sum ${local_snapshots}/$1 | cut -d ' ' -f 1`"
    oldsum="`grep ${getfile} ${local_snapshots}/md5sums | cut -d ' ' -f 1`"
    # if there isn't an entry in the md5sum file, we're probably downloading
    # something else that's less critical.
    if test x"${oldsum}" = x; then
	warning "No md5sum entry for $1!"
	return 0
    fi

    if test x"${oldsum}" = x"${newsum}"; then
	notice "md5sums matched"
	return 0
    else
	error "md5sums don't match!"
	return 1
    fi
}

# decompress and untar a fetched tarball
extract()
{
    extractor=
    taropt=
    echo "Uncompressing and untarring $1 into $2..."

    dir="`dirname $1`"
    if test x"${dir}" = x"."; then
	dir=""
    fi

    # Figure out how to decompress a tarball
    case "$1" in
	*.xz)
	    echo "XZ File"
	    extractor="xz -d "
	    taropt="J"
	    ;;
	*.bz*)
	    echo "bzip2 file"
	    extractor="bzip2 -d "
	    taropt="j"
	    ;;
	*.gz)
	    echo "Gzip file"
	    extractor="gunzip "
	    taropt="x"
	    ;;
	*) ;;
    esac

    if test -d `echo ${local_snapshots}/$1 | sed -e 's:.tar.*::'` -a x"${clobber}" != xyes; then
	notice "$1 already is extracted!"
	return 0
    fi
    taropts="${taropt}xvf"
    out="`tar ${taropts} ${local_snapshots}/$1 -C ${local_snapshots}/${dir}`"
}

# $1 - The dccs system to use
# $2 - The parent directory for the sources
# $3 - The URL to fetch from
# $4 - The branch to fetch
checkout_source()
{
    dir="$2"
    url="$3"
    
    if test x"$4" x= x; then
	branch=""
    else
	branch="$4"
    fi

    case $1 in 
	git)
	    dccs="git clone "
	    ;;
	svn)
	    dccs="svn checkout "
	    ;;
	bzr)
	    dccs="bzr branch "
	    ;;
	*) ;;
    esac

    (cd $2 && ${dccs} ${url} ${branch})
}

# This updates an existing checked out source tree 
update_source()
{
    # Figure out which DCCS it uses
    dccs=
    if test -f .git; then
	dccs="git pull"
    fi
    if test -f .bzr; then
	dccs="bzr pull"
    fi
    if test -f .svn; then
	dccs="svn update"
    fi
    if test x"${dccs}" != x; then
	echo "Update sources with: ${dccs}"
    else
	echo "ERROR: can't determine DCCS!"
	return
    fi

    # update the source
    (cd $1 && ${dccs})
}
