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

    # start by grabbing the md5sum file. We delete the current one as we
    # always want a fresh md5sums file, as it changes every day, so older
    # versions go out of doubt.
    rm -f ${local_snapshots}/md5sums
    fetch_http md5sums
    
    # We can grab the full file name by searching for it in the md5sums file.
    # This is better than guessing, which we do anyway if for some reason the
    # file isn't listed in the md5sums file.
    
    #get_source $1
    md5file="`grep ${file} ${local_snapshots}/md5sums | cut -d ' ' -f 3`"
    if test x"${md5file}" = x; then
	error "${file} not in md5sum!"
	return 1
    fi
    if test x"${file}" != x; then
	getfile="${md5file}"
    else
	getfile=${file}.tar.xz
    fi

    # FIXME: Stash the md5sum for this tarball in the build directory. Compare
    # the current one we just got with the stored one to determine if we should
    # download it.
    if test x"$2" = x; then
#	notice "Using default fetching protocol 'http'"
	protocol=http
    else
	protocol=$2
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
	notice "Downloading ${getfile} to ${local_snapshots}"
	if test x"${wget_bin}" != x; then
	    ${wget_bin} --continue --directory-prefix=${local_snapshots}/${dir} \
		${remote_snapshots}/${getfile}
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
	builddir="`get_builddir $1`"
	rm -f ${builddir}/md5sum
	echo "${newsum} > ${builddir}/md5sum"
	return 0
    else
	error "md5sums don't match!"
	if test x"${force}" = x"yes"; then
	    return 0
	else
	    return 1
	fi
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

    file="`grep $1 ${local_snapshots}/md5sums | egrep -v  "\.asc|\.txt" | cut -d ' ' -f 3`"
    
    # Figure out how to decompress a tarball
    case "${file}" in
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

    if test -d `echo ${local_snapshots}/${file} | sed -e 's:.tar.*::'` -a x"${clobber}" != xyes; then
	notice "${local_snapshots}/${file} is already extracted!"
	return 0
    else
	taropts="${taropt}xvf"
	tar ${taropts} ${local_snapshots}/${file} -C ${local_snapshots}/${dir}
    fi

    # FIXME: this is hopefully is temporary hack for tarballs where the directory
    # name versions doesn't match the tarball version. This means it's missing the
    # -linaro-VERSION.YYYY.MM part.
    dir="`echo ${file} | sed -e 's:.tar\..*::'`"
    if test ! -d ${local_snapshots}/${dir}; then
	dir2="`echo ${dir} | sed -e 's:-linaro::' -e 's:-20[0-9][0-9].*::'`"
	if test -d ${local_snapshots}/${dir2}; then
	    warning "Making a symbolic link for nonstandard directory name!"
	    ln -s ${local_snapshots}/${dir2} ${local_snapshots}/${dir}
	else
	    error "${dir} doesn't seem to exist!"
	fi
    fi

    return 0
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
