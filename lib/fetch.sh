#!/bin/sh
# 
#   Copyright (C) 2013-2015 Linaro, Inc
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

# The fetch_md5sums() function is special because the md5sums file is used by
# ABE for knowing where to fetch other files, i.e. it's used by fetch(). This
# function should only be called once at the start of every ABE run.  This
# function does not respect supdate=no.  It is harmless to download new versions
# of md5sums.
fetch_md5sums()
{
    if test "${git_reference_dir:+set}" = "set" -a -e "${git_reference_dir}/md5sums"; then
	# The user specified that they want to fetch from the reference dir.  This
	# will always fetch if the version in the reference dir is newer.
	fetch_reference md5sums
    else
	# The fetch_http function will always attempt to fetch the remote file
	# if the version on the server is newer than the local version.
	fetch_http md5sums
    fi

    # If the fetch_*() fails we might have a previous version of md5sums in
    # ${local_snapshots}.  Use that, otherwise we have no choice but to fail.
    if test ! -s ${local_snapshots}/md5sums; then
	return 1
    fi
    return 0
}

# Fetch a file from a remote machine.  All decision logic should be in this
# function, not in the fetch_<protocol> functions to avoid redundancy.
fetch()
{
#    trace "$*"
    if test x"$1" = x; then
	error "No file name specified to fetch!"
	return 1
    fi

    # Peel off 'infrastructure/'
    local file="`basename $1`"

    # The md5sums file should have been downloaded before fetch() was
    # ever called.
    if test ! -e "${local_snapshots}/md5sums"; then
	error "${local_snapshots}/md5sums is missing."
	return 1
    fi

    # We can grab the full file name by searching for it in the md5sums file.
    # Match on the first hit.  This might be prepended with the
    # 'infrastructure/' directory name if it's an infrastructure file.
    local getfile="$(grep ${file} -m 1 ${local_snapshots}/md5sums | cut -d ' ' -f 3)"
    if test x"${getfile}" = x; then
	error "${file} not in md5sum!"
	return 1
    fi

    # Forcing trumps ${supdate} and always results in sources being updated.
    if test x"${force}" != xyes; then
	if test x"${supdate}" = xno; then
	    if test -e "${local_snapshots}/${getfile}"; then
		notice "${getfile} already exists and updating has been disabled."
		return 0
	    fi
	    error "${getfile} doesn't exist and updating has been disabled."
	    return 1
	fi
	# else we'll update the file if the version in the reference dir or on
	# the server is newer than the local copy (if it exists).
    fi

    # If the user has specified a git_reference_dir, then we'll use it if the
    # file exists in the reference dir.
    if test -e "${git_reference_dir}/${getfile}" -a x"${force}" != xyes; then
	# This will always fetch if the version in the reference dir is newer.
	local protocol=reference
    else
	# Otherwise attempt to fetch remotely.
	local protocol=http
    fi

    # download from the file server or copy the file from the reference dir
    fetch_${protocol} ${getfile}
    if test $? -gt 0; then
	return 1
    fi

    # Fetch only supports fetching files which have an entry in the md5sums file.
    # An unlisted file should never get this far anyway.
    dryrun "check_md5sum ${getfile}"
    if test $? -gt 0 -a x"${force}" != xyes; then
	error "md5sums don't match!"
	return 1
    fi

    notice "md5sums matched"
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

# ---------------------------- private functions ------------------------------
# These functions are helper functions for fetch().  These are purpose specific
# functions and there should be little to no decision logic in these functions.
# Call these functions outside of fetch() with extreme caution.

# This function trusts that we know that we want to fetch a file from the
# server.  Unless $force=yes, wget will only download a copy if the version
# on the server is newer than the destination file.
fetch_http()
{
#    trace "$*"

    local getfile=$1

    # This provides the infrastructure/ directory if ${getfile} contains it.
    local dir="`dirname $1`/"
    if test x"${dir}" = x"./"; then
	local dir=""
    else
	if test ! -d ${local_snapshots}/${dir}; then
	    mkdir -p ${local_snapshots}/${dir}
	fi
    fi

    # You MUST have " " around ${wget_bin} or test ! -x will
    # 'succeed' if ${wget_bin} is an empty string.
    if test ! -x "${wget_bin}"; then
	error "wget executable not available (or not executable)."
	return 1
    fi

    # Force will cause us to overwrite the version in local_snapshots unconditionally.
    local overwrite_or_timestamp=
    if test x${force} = xyes; then
	# This is the only way to explicitly overwrite the destination file
	# with wget.
	overwrite_or_timestamp="-O ${local_snapshots}/${getfile}"
        notice "Downloading ${getfile} to ${local_snapshots} unconditionally."
    else
	# We only every download if the version on the server is newer than
	# the local version.
	overwrite_or_timestamp="-N"
        notice "Downloading ${getfile} to ${local_snapshots} if version on server is newer than local version."
    fi

    # NOTE: the timeout is short, and we only try twice to access the
    # remote host. This is to improve performance when offline, or
    # the remote host is offline.
    dryrun "${wget_bin} ${wget_quiet:+-q} --timeout=${wget_timeout}${wget_progress_style:+ --progress=${wget_progress_style}} --tries=2 --directory-prefix=${local_snapshots}/${dir} http://${fileserver}/${remote_snapshots}/${getfile} ${overwrite_or_timestamp}"
    if test x"${dryrun}" != xyes -a ! -s ${local_snapshots}/${getfile}; then
       warning "downloaded file ${getfile} has zero data!"
       return 1
    fi

    return 0
}

# This function trusts that we know that we want to copy a file from the
# reference snapshots.  It only copies the file if the reference dir file is
# newer than the destination file (or if the destination file doesn't exist).
# If ${force}=yes then it will overwrite any existing file in local_snapshots
# whether it is newer or not.
fetch_reference()
{
#    trace "$*"
    local getfile=$1

    # Prevent error with empty variable-expansion.
    if test x"${getfile}" = x""; then
	error "fetch_reference() must be called with a parameter designating the file to fetch."
	return 1
    fi

    # Force will cause an overwrite.
    if test x"${force}" != xyes; then
	local update_on_change="-u"
	notice "Copying ${getfile} from reference dir to ${local_snapshots} if reference copy is newer or ${getfile} doesn't exist."
    else
	notice "Copying ${getfile} from reference dir to ${local_snapshots} unconditionally."
    fi

    # Only copy if the source file in the reference dir is newer than
    # that file in the local_snapshots directory (if it exists).
    dryrun "cp${update_on_change:+ ${update_on_change}} ${git_reference_dir}/${getfile} ${local_snapshots}/${getfile}"
    if test $? -gt 0; then
	error "Copying ${getfile} from reference dir to ${local_snapshots} failed."
	return 1
    fi
    return 0
}

# This is a single purpose function which will report whether the input getfile
# in $1 has an entry in the md5sum file and whether that entry's md5sum matches
# the actual file's downloaded md5sum.
check_md5sum()
{
#    trace "$*"

    # ${local_snapshots}/md5sums is a pre-requisite.
    if test ! -e ${local_snapshots}/md5sums; then
        error "${local_snapshots}/md5sums is missing."
        return 1
    fi

    local entry=
    entry=$(grep "${1}" ${local_snapshots}/md5sums)
    if test x"${entry}" = x; then
        error "No md5sum entry for $1!"
        return 1
    fi

    # Ask md5sum to verify the md5sum of the downloaded file against the hash in
    # the index.  md5sum must be executed from the snapshots directory.
    pushd ${local_snapshots} &>/dev/null
    dryrun "echo \"${entry}\" | md5sum --status --check -"
    md5sum_ret=$?
    popd &>/dev/null

    return $md5sum_ret
}
