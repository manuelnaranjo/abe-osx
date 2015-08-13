#!/bin/bash
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

# Given a git url or a tarball name, this function will return a stamp name.
#
# $1: Stamp type: configure, build, extract, fetch.
# $2: File URL or tarball name.
# $3: Special suffix, e.g., "stage1" or "stage2"
#
get_stamp_name()
{
    local stamptype=$1
    local git_or_tar=$2
    local suffix=$3

    local validstamp="`echo ${stamptype} | egrep -c "^configure$|^build$|^extract$|^fetch$"`" 
    if test ${validstamp} -lt 1; then
	error "Invalid stamp type selected."
	return 1
    fi

    local name_fragment=
    if test "`echo "${git_or_tar}" | grep -c "\.tar"`" -gt 0; then
	# Strip the .tar.* from the archive file to get the stamp name.
	name_fragment="`echo "${git_or_tar}" | sed -e 's:\.tar.*::'`"
	# Strip any preceding directory information,
	# e.g., infrastructure/gmp-2.1.2.tar.xz -> gmp-2.1.2
	name_fragment="`basename ${name_fragment}`"
    else
	name_fragment="`get_git_tag ${git_or_tar}`" || return 1
	if test x"${name_fragment}" = x; then
	    error "Couldn't determine stamp name."
	    return 1
	fi
    fi

    #local stamp_name="stamp-${stamptype}-${name_fragment}${suffix:+-${suffix}}"
    local stamp_name="${name_fragment}${suffix:+-${suffix}}-${stamptype}.stamp"
    echo "${stamp_name}"
    return 0
}

# $1 Stamp Location
# $2 Stamp Name
#
create_stamp()
{
    local stamp_loc=$1
    local stamp_name=$2
    local ret=

    # Strip trailing slashes from the location directory.
    stamp_loc="`echo ${stamp_loc} | sed 's#/*$##'`"

    if test ! -d "${stamp_loc}"; then
	notice "'${stamp_loc}' doesn't exist, creating it."
	dryrun "mkdir -p \"${stamp_loc}\""
    fi

    local full_stamp_path=
    full_stamp_path="${stamp_loc}/${stamp_name}"

    dryrun "touch \"${full_stamp_path}\""
    ret=$?
    notice "Creating stamp ${full_stamp_path} (`stat -c %Y ${full_stamp_path}`)"
    return ${ret}
}

#
# $1 Stamp Location
# $2 Stamp Name
# $3 File to compare stamp against
# $4 Force
#
#   If stamp file is newer than the compare file return 0
#   If stamp file is NOT newer than the compare file return 1
#   If stamp file does not exist return 1
#
# Return Value:
#
#   1 - If the test_stamp function returns 1 then regenerate the stamp
#       after processing.
#
#   0 - Otherwise the test_stamp function returns 0 which means that
#       you should not proceed with processing.
#
#   255 - There is an error condition during stamp generation.  This is
#         a bug in abe or the filesystem.
#
check_stamp()
{
    local stamp_loc=$1
    local stamp_name=$2
    local compare_file=$3
    local stamp_type=$4
    local local_force=$5

    if test ! -e "${compare_file}" -a x"${dryrun}" != xyes; then
	fixme "Compare file '${compare_file}' does not exist."
	return 255
    fi

    # Strip trailing slashes from the location directory.
    stamp_loc="`echo ${stamp_loc} | sed 's#/*$##'`"

    # stamp_type is only used for an informational message and we want to make
    # the resultant message grammatically correct.
    if test x"${stamp_type}" = x"configure"; then
       stamp_type="configur"
    fi

    if test x"${dryrun}" = xyes; then
	notice "--dryrun is being used${stamp_type:+, ${stamp_type}ing..}."
	return 1
    fi

    notice "Checking for ${stamp_loc}/${stamp_name}"
    if test ${compare_file} -nt ${stamp_loc}/${stamp_name} -o x"${local_force}" = xyes; then
        if test ! -e "${stamp_loc}/${stamp_name}"; then
	    notice "${stamp_loc}/${stamp_name} does not yet exist${stamp_type:+, ${stamp_type}ing..}."
	elif test x"${local_force}" = xyes; then
	    notice "--force is being used${stamp_type:+, ${stamp_type}ing..}."
	else
	    notice "${compare_file} (`stat -c %Y ${compare_file}`) is newer than ${stamp_loc}/${stamp_name} (`stat -c %Y ${stamp_loc}/${stamp_name}`)${stamp_type:+, ${stamp_type}ing..}."
	fi
	return 1
    else
     	notice "${stamp_loc}/${stamp_name} (`stat -c %Y ${stamp_loc}/${stamp_name}`) is newer than ${compare_file} (`stat -c %Y ${compare_file}`).  Nothing to be done."
    fi    
    return 0
}
