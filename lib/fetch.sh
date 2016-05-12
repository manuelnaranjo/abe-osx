#!/bin/bash
# 
#   Copyright (C) 2013, 2014, 2015, 2016 Linaro, Inc
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

# Fetch a file from a remote machine.  All decision logic should be in this
# function, not in the fetch_<protocol> functions to avoid redundancy.
fetch()
{
    trace "$*"

    if test x"$1" = x; then
	error "No file name specified to fetch!"
	return 1
    fi

    local component=$1
    local getfile="`get_component_filespec ${component}`"
    local url="`get_component_url ${component}`"

    # This provides the infrastructure/ directory if ${getfile} contains it.
#    if test "`echo ${url} | grep -c infrastructure`" -gt 0; then
#	local dir="/infrastructure"
#    else
	local dir=""
#    fi

    # Forcing trumps ${supdate} and always results in sources being updated.
    if test x"${force}" != xyes; then
	if test x"${supdate}" = xno; then
	    if test -e "${local_snapshots}${dir}/${getfile}"; then
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
    if test -e "${git_reference_dir}${dir}/${getfile}" -a x"${force}" != xyes; then
	# This will always fetch if the version in the reference dir is newer.
	local protocol=reference
    else
	# Otherwise attempt to fetch remotely.
	local protocol=http
    fi

    # download from the file server or copy the file from the reference dir
    fetch_${protocol} ${component}
    if test $? -gt 0; then
	return 1
    fi

    # Fetch only supports fetching files which have an entry in the md5sums file.
    # An unlisted file should never get this far anyway.
    dryrun "check_md5sum ${component}"
    if test $? -gt 0; then
	  error "md5sums don't match!"
      if test x"${force}" != xyes; then
	    return 1
      fi
    fi

    notice "md5sums matched"
    return 0
}

# decompress and untar a fetched tarball
extract()
{
    trace "$*"

    local extractor=
    local taropt=
    local component=$1

    local url="`get_component_url ${component}`"
#    if test "`echo ${url} | grep -c infrastructure`" -gt 0; then
#	local dir="/infrastructure/"
#    else
	local dir=""
#    fi
    local file="`get_component_filespec ${component}`"
    local srcdir="`get_component_srcdir ${component}`"
    local version="`basename ${srcdir}`"

    local stamp=
    stamp="`get_stamp_name extract ${version}`"

    # Extract stamps go into srcdir
    local stampdir="${local_snapshots}${dir}"

    # Name of the downloaded tarball.
    local tarball="${local_snapshots}${dir}/${file}"

    # Initialize component data structures
    local builddir="`get_component_builddir ${component}`"

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

    local taropts="${taropt}xf"
    notice "Extracting from ${tarball}."
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
    	    dir2="${srcdir}/${dir2}"
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
    trace "$*"

    local component=$1
    local getfile="`get_component_filespec ${component}`"
    if test x"${getfile}" = x; then
	error "No filespec specified for ${component} !"
	return 1
    fi
    local url="`get_component_url ${component}`/${getfile}"

    if test x"${url}" = x; then
	error "No URL specified for ${component} !"
	return 1
    fi

    # This provides the infrastructure/ directory if ${getfile} contains it.
#    if test "`echo ${url} | grep -c infrastructure`" -gt 0; then
#	local dir="/infrastructure"
#    else
	local dir=""
#    fi
    if test ! -d ${local_snapshots}${dir}; then
	mkdir -p ${local_snapshots}${dir}
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
    dryrun "${wget_bin} ${wget_quiet:+-q} --timeout=${wget_timeout}${wget_progress_style:+ --progress=${wget_progress_style}} --tries=2 --directory-prefix=${local_snapshots}/${dir} ${url} ${overwrite_or_timestamp}"
    if test $? -gt 0; then
       error "${url} doesn't exist on the remote machine !"
       return 1
    fi
    if test x"${dryrun}" != xyes -a ! -s ${local_snapshots}${dir}/${getfile}; then
       warning "downloaded file ${getfile} has zero data!"
       return 1
    fi
    dryrun "${wget_bin} ${wget_quiet:+-q} --timeout=${wget_timeout}${wget_progress_style:+ --progress=${wget_progress_style}} --tries=2 --directory-prefix=${local_snapshots}/${dir} ${url}.asc ${overwrite_or_timestamp}"
    if test x"${dryrun}" != xyes -a ! -s ${local_snapshots}${dir}/${getfile}.asc; then
       warning "downloaded file ${getfile}.asc has zero data!"
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
    trace "$*"

    local getfile=$1
    local url="`get_component_url ${getfile}`"

    # Prevent error with empty variable-expansion.
    if test x"${getfile}" = x""; then
	error "fetch_reference() must be called with a parameter designating the file to fetch."
	return 1
    fi

    # This provides the infrastructure/ directory if ${getfile} contains it.
#    if test "`echo ${url} | grep -c infrastructure`" -gt 0; then
#	local dir="/infrastructure/"
#    else
	local dir=""
#    fi
    if test x"${dir}" = x"./"; then
	local dir=""
    else
	if test ! -d ${local_snapshots}/${dir}; then
	    mkdir -p ${local_snapshots}/${dir}
	fi
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
    dryrun "cp${update_on_change:+ ${update_on_change}} ${git_reference_dir}${dir}/${getfile}*.tar.* ${local_snapshots}${dir}/"
    if test $? -gt 0; then
	error "Copying ${getfile} from reference dir to ${local_snapshots}${dir} failed."
	return 1
    fi
    return 0
}

# This is a single purpose function which will report whether the input getfile
# in $1 has an entry in the md5sum file and whether that entry's md5sum matches
# the actual file's downloaded md5sum.
check_md5sum()
{
    trace "$*"

    local tool="`basename $1`"

    local file="`get_component_filespec ${tool}`.asc"
    local url="`get_component_url ${tool}`"

#    if test "`echo ${url} | grep -c infrastructure`" -gt 0; then
#	local dir="/infrastructure/"
#    else
	local dir=""
#    fi

    if test ! -e "${local_snapshots}${dir}/${file}"; then
        error "No md5sum file for ${tool}!"
        return 1
    fi

    # Ask md5sum to verify the md5sum of the downloaded file against the hash in
    # the index.  md5sum must be executed from the snapshots directory.
    pushd ${local_snapshots}${dir} &>/dev/null
    dryrun "md5sum --status --check ${file}"
    md5sum_ret=$?
    popd &>/dev/null

    return $md5sum_ret
}
