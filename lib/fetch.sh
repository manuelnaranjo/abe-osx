#!/bin/sh

# Fetch a file from a remote machine
fetch()
{
    trace "$*"

    if test x"$1" = x; then
	error "No file name specified to fetch!"
	return 1
    else
	local file="`basename $1`"
    fi

    local dir="`dirname $1`/"
    if test x"${dir}" = x"./"; then
	local dir=""
    fi

    # first, see if there is a working network connection, because
    # without one, downloading files won't work.
    # ping -c 1 cbuild.validation.linaro.org
    # if test $? -eq 0; then
    # 	network=yes
    # else
    # 	warning "No network connection! Downloading files disabled."
    # 	network=no
    # 	return 1
    # fi

    # The md5sums file is handled differently, as it's used to find all
    # the other names of the tarballs for remote downloading.
    if test x"$1" = x"md5sums"; then
	# Move the existing file to force a fresh copy to be downloaded.
	# Otherwise this file can get stale, and new tarballs not found.
	if test -f ${local_snapshots}/md5sums; then
	    cp -f ${local_snapshots}/md5sums ${local_snapshots}/md5sums.bak
	fi
	fetch_http md5sums
	if test ! -s ${local_snapshots}/md5sums; then
	    cp -f ${local_snapshots}/md5sums.bak ${local_snapshots}/md5sums
	fi
	return $?
    fi

    # We can grab the full file name by searching for it in the md5sums file.
    # This is better than guessing, which we do anyway if for some reason the
    # file isn't listed in the md5sums file.
    local md5file="`grep ${file} ${local_snapshots}/md5sums | cut -d ' ' -f 3`"
    if test x"${md5file}" = x; then
	error "${file} not in md5sum!"
	return 1
    fi
    if test x"${file}" != x; then
	local getfile="${md5file}"
    else
	local getfile=${dir}${file}.tar.xz
    fi

    # If the tarball hasn't changed, then don't fetch anything
    if test -e ${local_snapshots}/${md5file} -a ${local_builds}/stamp-fetch-${file} -nt ${local_snapshots}/${md5file} -a x"${force}" = xno; then
     	fixme "stamp-fetch-${file} is newer than ${md5file}, so not fetching ${md5file}"
	return 0
    else
     	fixme "stamp-fetch-${file} is not newer than ${md5file}, so fetching ${md5file}"
    fi
    
    # FIXME: Stash the md5sum for this tarball in the build directory. Compare
    # the current one we just got with the stored one to determine if we should
    # download it.
    if test x"$2" = x; then
#	notice "Using default fetching protocol 'http'"
	local protocol=http
    else
	local protocol=$2
    fi

    # download the file
    fetch_${protocol} ${getfile}
    if test $? -gt 0; then
	warning "couldn't fetch $1, trying xdelta3 instead"
	local getfile=${file}.tar.xdelta3.xz
	fetch_${protocol} ${file}
	if test $? -gt 0; then
	    warning "couldn't fetch ${getfile}, trying .bz2 instead"
	    local getfile=${file}.tar.bz2
	    fetch_${protocol} ${getfile}
	    if test $? -gt 0; then
		error "couldn't fetch ${getfile}"
		return 1
	    fi
	fi
	return 1
    fi

    check_md5sum ${getfile}
    if test $? -gt 0; then
	return 1
    fi

    touch ${local_builds}/stamp-fetch-${file}

    return 0
}

fetch_http()
{
    trace "$*"

    local getfile=$1
    local dir="`dirname $1`/"
    if test x"${dir}" = x"./"; then
	local dir=""
    else
	if test ! -d ${local_snapshots}/${dir}; then
	    mkdir -p ${local_snapshots}/${dir}
	fi
    fi

    if test ! -e ${local_snapshots}/${getfile} -o x"${force}" = xyes; then
	notice "Downloading ${getfile} to ${local_snapshots}"
	if test x"${wget_bin}" != x; then
	    # --continue --progress=bar
	    # NOTE: the timeout is short, and we only try twice to access the
	    # remote host. This is to improve performance when offline, or
	    # the remote host is offline.
	    dryrun "${wget_bin} ${wget_quiet:+-q} --timeout=1 --tries=2 --directory-prefix=${local_snapshots}/${dir} ${remote_snapshots}/${getfile}"
	    if test ! -s ${local_snapshots}/${getfile}; then
		warning "downloaded file ${getfile} has zero data!"
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
    local getfile="`basename $1`"

    dryrun "${rsync_bin} $1 ${local_snapshots}"
    if test ! -e ${local_snapshots}/${getfile}; then
	warning "${getfile} didn't download via rsync!"
	return 1
    fi
    
    return 0
}

check_md5sum()
{
    trace "$*"

    if test ! -e ${local_snapshots}/md5sums; then
	fetch_http md5sums
	if test $? -gt 0; then
	    error "couldn't fetch md5sums"
	    return 1
	fi
    fi

    local dir="`dirname $1`/"
    if test x"${dir}" = x"."; then
	local dir=""
    fi

    # Drop the file name from .tar to the end to keep grep happy
    local getfile=`echo ${1}`

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
	local builddir="`get_builddir $1`"
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

    return 0
}

# decompress and untar a fetched tarball
extract()
{
    trace "$*"

    local extractor=
    local taropt=

    local dir="`dirname $1`/"
    if test x"${dir}" = x"./"; then
	local dir=""
    fi

    if test `echo $1 | egrep -c "\.gz|\.bz2|\.xz"` -eq 0; then	
	local file="`grep $1 ${local_snapshots}/md5sums | egrep -v  "\.asc|\.txt" | cut -d ' ' -f 3 | cut -d '/' -f 2`"
    else
	local file="`echo $1 | cut -d '/' -f 2`"
    fi

#    if test ! -d ${local_snapshots}/${dir}; then
#	mkdir -fp ${local_snapshots}/${dir}
#    fi

    # If the tarball hasn't changed, then don't fetch anything
    if test ${local_builds}/${dir}stamp-extract-${file} -nt ${local_snapshots}/${dir}${file} -a x"${force}" = xno; then
     	fixme "${dir}stamp-extract-${file} is newer than ${file}, so not extracting ${file}"
	return 0
    else
     	fixme "${dir}stamp-extract-${file} is not newer than ${file}, so extracting ${file}"
    fi    
    
    # Figure out how to decompress a tarball
    case "${file}" in
	*.xz)
	    local extractor="xz -d "
	    local taropt="J"
	    ;;
	*.bz*)
	    local extractor="bzip2 -d "
	    local taropt="j"
	    ;;
	*.gz)
	    local extractor="gunzip "
	    local taropt="x"
	    ;;
	*) ;;
    esac

    # FIXME: this is hopefully is temporary hack for tarballs where the directory
    # name versions doesn't match the tarball version. This means it's missing the
    # -linaro-VERSION.YYYY.MM part.
    local name="`echo ${file} | sed -e 's:.tar\..*::'`"
    if test ! -d ${local_snapshots}/${dir}${name}; then
	local dir2="`echo ${name} | sed -e 's:-linaro::' -e 's:-201[0-9\.\-]*::'`"
	if test ! -d ${local_snapshots}/${name}; then
	    warning "Making a symbolic link for nonstandard directory name!"
	    ln -sf ${local_snapshots}/${dir2} ${local_snapshots}/${name}
	else
	    error "${dir} doesn't seem to exist!"
	    return 1
	fi
    fi

    if test -d `echo ${local_snapshots}/${dir}${file} | sed -e 's:.tar.*::'` -a x"${force}" = xno; then
	notice "${local_snapshots}/${file} is already extracted!"
	return 0
    else
	local taropts="${taropt}xf"
	tar ${taropts} ${local_snapshots}/${dir}${file} -C ${local_snapshots}/${dir}
    fi

    touch ${local_builds}/stamp-extract-${file} 

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
