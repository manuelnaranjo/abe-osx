#!/bin/sh
# 
#   Copyright (C) 2013, 2014 Linaro, Inc
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
# 

# Fetch a file from a remote machine
fetch()
{
#    trace "$*"

    if test x"$1" = x; then
	error "No file name specified to fetch!"
	return 1
    else
	local file="`basename $1`"
    fi

    # The md5sums file is a special case as it's used to find all
    # the other names of the tarballs for remote downloading.
    if test x"$1" = x"md5sums"; then
	# Move the existing file to force a fresh copy to be downloaded.
	# Otherwise this file can get stale, and new tarballs not found.
	if test -f ${local_snapshots}/md5sums; then
	    mv -f ${local_snapshots}/md5sums ${local_snapshots}/md5sums.bak
	fi
	fetch_http md5sums
	if test ! -s ${local_snapshots}/md5sums; then
	    cp -f ${local_snapshots}/md5sums.bak ${local_snapshots}/md5sums
	fi
	return $?
    fi

    # This will be ${local_snapshots} or ${local_snapshots}/infrastructure.
    local srcdir=
    srcdir="`get_srcdir $1`"

    local stamp=
    stamp="`get_stamp_name fetch $1`"

    # Fetch stamps go into srcdir's parent directory.
    local stampdir="`dirname ${srcdir}`"

    # We can grab the full file name by searching for it in the md5sums file.
    # This is better than guessing, which we do anyway if for some reason the
    # file isn't listed in the md5sums file.  This might be prepended with the
    # 'infrastructure/' directory name if it's an infrastructure file.
    local md5file="`grep ${file} ${local_snapshots}/md5sums | cut -d ' ' -f 3`"
    if test x"${md5file}" = x; then
	error "${file} not in md5sum!"
	return 1
    fi

    if test -e "${local_snapshots}/${md5file}"; then 
	local ret=
    	# If the tarball hasn't changed, then don't fetch anything
	check_stamp "${stampdir}" ${stamp} ${local_snapshots}/${md5file} fetch ${force}
	ret=$?
	if test $ret -eq 0; then
	    return 0 
	elif test $ret -eq 255; then
	    # The compare file ${local_snapshots}/${md5file} is not there.
	    return 1
	fi
    else
	notice "${local_snapshots}/${md5file} does not exist.  Downloading."
    fi

    # FIXME: Stash the md5sum for this tarball in the build directory. Compare
    # the current one we just got with the stored one to determine if we should
    # download it.
    if test x"$2" = x; then
	local protocol=http
    else
	local protocol=$2
    fi

    local getfile="${md5file}"
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

    dryrun "check_md5sum ${getfile}"
#    if test $? -gt 0; then
#	return 1
#    fi

    create_stamp "${stampdir}" "${stamp}"

    return 0
}

fetch_http()
{
#    trace "$*"

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
	    dryrun "${wget_bin} ${wget_quiet:+-q} --timeout=${wget_timeout}${wget_progress_style:+ --progress=${wget_progress_style}} --tries=2 --directory-prefix=${local_snapshots}/${dir} ${remote_snapshots}/${getfile}"
	    if test x"${dryrun}" != xyes -a ! -s ${local_snapshots}/${getfile}; then
		warning "downloaded file ${getfile} has zero data!"
		return 1
	    fi
	fi
    else
	# We don't want this message for md5sums, since it's so often
	# downloaded.
	if test x"${getfile}" != x"md5sums"; then
	    notice "${getfile} already exists in ${local_snapshots}"
	fi
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
#    trace "$*"

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
#    trace "$*"

    local extractor=
    local taropt=

    if test `echo $1 | egrep -c "\.gz|\.bz2|\.xz"` -eq 0; then	
	local file="`grep $1 ${local_snapshots}/md5sums | egrep -v  "\.asc|\.txt" | cut -d ' ' -f 3 | cut -d '/' -f 2`"
    else
	local file="`echo $1 | cut -d '/' -f 2`"
    fi

    local srcdir=
    srcdir="`get_srcdir $1`"

    local stamp=
    stamp="`get_stamp_name extract $1`"

    # Extract stamps go into srcdir
    local stampdir="`dirname ${srcdir}`"

    # Name of the downloaded tarball.
    local tarball="`dirname ${srcdir}`/${file}"

    local ret=
    # If the tarball hasn't changed, then we don't need to extract anything.
    check_stamp "${stampdir}" ${stamp} ${tarball} extract ${force}
    ret=$?
    if test $ret -eq 0; then
	return 0 
    elif test $ret -eq 255; then
	# the ${tarball} isn't present.
	return 1
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

    if test -d ${srcdir} -a x"${force}" = xno; then
	notice "${srcdir} already exists. Removing to extract newer version!"
	dryrun "rm -rf ${srcdir}"
    fi

    local taropts="${taropt}xf"
    notice "Extracting ${srcdir} from ${tarball}."
    dryrun "tar ${taropts} ${tarball} -C `dirname ${srcdir}`"

    # FIXME: this is hopefully a temporary hack for tarballs where the
    # directory name versions doesn't match the tarball version. This means
    # it's missing the -linaro-VERSION.YYYY.MM part.
    local name="`echo ${file} | sed -e 's:.tar\..*::'`"

    # dryrun has to skip this step otherwise execution will always drop into
    # this leg.
    if test x"${dryrun}" != xyes -a ! -d ${srcdir}; then
	local dir2="`echo ${name} | sed -e 's:-linaro::' -e 's:-201[0-9\.\-]*::'`"
	if test ! -d ${srcdir}; then
	    dir2="`dirname ${srcdir}`/${dir2}"
	    warning "${tarball} didn't extract to ${srcdir} as expected!"
	    notice "Making a symbolic link from ${dir2} to ${srcdir}!"
	    dryrun "ln -sf ${dir2} ${srcdir}"
	else
	    error "${srcdir} already exists!"
	    return 1
	fi
    fi

    create_stamp "${stampdir}" "${stamp}"
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
