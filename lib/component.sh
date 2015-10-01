#!/bin/bash
# 
#   Copyright (C) 2015 Linaro, Inc
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

declare -ag toolchain

# This file attempts to turn an associative array into a semblance of a
# data structure. Note that this will only work with the bash shell.
#
# The default fields are calculated at runtime
# TOOL
# URL
# REVISION
# SRCDIR
# BUILDDIR
# FILESPEC
# These values are extracted from the config/[component].conf files
# BRANCH
# MAKEFLAGS
# STATICLINK
# CONFIGURE
# RUNTESTFLAGS

# Initialize the associative array
# parameters:
#	$ - Any parameter without a '=' sign becomes the name of the the array.
#	    
component_init ()
{
    trace "$*"

    local component="$1"
    local index=
    for index in $*; do
	if test "`echo ${index} | grep -c '='`" -gt 0; then
	    name="`echo ${index} | cut -d '=' -f 1`"
	    value="`echo ${index} | sed -e 's:^[a-zA-Z]*=::' | tr '%' ' '`"
	    eval ${component}[${name}]="${value}"
	    if test $? -gt 0; then
		return 1
	    fi
	else
	    component="`echo ${index} | sed -e 's:-[0-9a-z\.\-]*::'`"
	    declare -Ag ${component}
	    eval ${component}[TOOL]="${component}"
	    if test $? -gt 0; then
		return 1
	    fi
	fi
	name=
	value=
    done

    toolchain=(${toolchain[@]} ${component})

    return 0
}

# Accessor functions for the data structure to set "private" data. This is a crude
# approximation of an object oriented API for this data structure. Each of the setters
# takes two arguments, which are:
#
# $1 - The name of the data structure, which is based on the toolname, ie... gcc, gdb, etc...
# $2 - The value to assign the data field.
#
# Returns 0 on success, 1 on error
#
set_component_url ()
{
#    trace "$*"

    local component="`echo $1 | sed -e 's:-[0-9a-z\.\-]*::' -e 's:\.git.*::'`"
    declare -p ${component} 2>&1 > /dev/null
    if test $? -gt 0; then
	echo "WARNING: ${component} does not exist!"
	return 1
    else
	eval ${component}[URL]="$2"
    fi

    return 0
}

set_component_revision ()
{
#    trace "$*"

    local component="`echo $1 | sed -e 's:-[0-9a-z\.\-]*::' -e 's:\.git.*::'`"
    declare -p ${component} 2>&1 > /dev/null
    if test $? -gt 0; then
	echo "WARNING: ${component} does not exist!"
	return 1
    else
	eval ${component}[REVISION]="$2"
    fi

    return 0
}

set_component_srcdir ()
{
#    trace "$*"

    local component="`echo $1 | sed -e 's:-[0-9a-z\.\-]*::' -e 's:\.git.*::'`"
    declare -p ${component} 2>&1 > /dev/null
    if test $? -gt 0; then
	echo "WARNING: ${component} does not exist!"
	return 1
    else
	eval ${component}[SRCDIR]="$2"
    fi

    return 0
}

set_component_builddir ()
{
#    trace "$*"

    local component="`echo $1 | sed -e 's:-[0-9a-z\.\-]*::' -e 's:\.git.*::'`"
    declare -p ${component} 2>&1 > /dev/null
    if test $? -gt 0; then
	echo "WARNING: ${component} does not exist!"
	return 1
    else
	eval ${component}[BUILDDIR]="$2"
    fi

    return 0
}

set_component_filespec ()
{
#    trace "$*"

    local component="`echo $1 | sed -e 's:-[0-9a-z\.\-]*::' -e 's:\.git.*::'`"
    declare -p ${component} 2>&1 > /dev/null
    if test $? -gt 0; then
	echo "WARNING: ${component} does not exist!"
	return 1
    else
	eval ${component}[FILESPEC]="$2"
    fi

    return 0
}

set_component_branch ()
{
#    trace "$*"

    local component="`echo $1 | sed -e 's:-[0-9a-z\.\-]*::' -e 's:\.git.*::'`"
    declare -p ${component} 2>&1 > /dev/null
    if test $? -gt 0; then
	echo "WARNING: ${component} does not exist!"
	return 1
    else
	eval ${component}[BRANCH]="$2"
    fi

    return 0
}

# BRANCH is parsed from the config file for each component, but can be redefined
# on the command line at runtime.
# BRANCH
# These next few fields are also from the config file for each component, but as
# defaults, they aren't changed from the command line, so don't have set_component_*
# functions.
#
# MAKEFLAGS
# STATICLINK
# CONFIGURE
# RUNTESTFLAGS

# Accessor functions for the data structure to get "private" data. This is a crude
# approximation of an object oriented API for this data structure. All of the getters
# take only one argument, which is the toolname, ie... gcc, gdb, etc...
#
# $1 - The name of the data structure, which is based on the toolname, ie... gcc, gdb, etc...
#
# Returns 0 on success, 1 on error, and the value is returned as a string.
#
get_component_url ()
{
#    trace "$*"

    local component="`echo $1 | sed -e 's:-[0-9a-z\.\-]*::' -e 's:\.git.*::'`"
    if test "${component:+set}" != "set"; then
	echo "WARNING: ${component} does not exist!"
	return 1
    else
	eval "echo \${${component}[URL]}"
    fi

    return 0
}

get_component_revision ()
{
#    trace "$*"

    local component="`echo $1 | sed -e 's:-[0-9a-z\.\-]*::' -e 's:\.git.*::'`"
    if test "${component:+set}" != "set"; then
	echo "WARNING: ${component} does not exist!"
	return 1
    else
	eval "echo \${${component}[REVISION]}"
    fi

    return 0
}

get_component_srcdir ()
{
#    trace "$*"

    local component="`echo $1 | sed -e 's:-[0-9a-z\.\-]*::' -e 's:\.git.*::'`"
    if test "${component:+set}" != "set"; then
	echo "WARNING: ${component} does not exist!"
	return 1
    else
	eval "echo \${${component}[SRCDIR]}"
    fi

    return 0
}

get_component_builddir ()
{
#    trace "$*"

    local component="`echo $1 | sed -e 's:-[0-9a-z\.\-]*::' -e 's:\.git.*::'`"
    if test "${component:+set}" != "set"; then
	echo "WARNING: ${component} does not exist!"
	return 1
    else
	eval "echo \${${component}[BUILDDIR]}"
    fi

    return 0
}

get_component_filespec ()
{
#    trace "$*"

    local component="`echo $1 | sed -e 's:-[0-9a-z\.\-]*::' -e 's:\.git.*::'`"
    if test "${component:+set}" != "set"; then
	echo "WARNING: ${component} does not exist!"
	return 1
    else
	eval "echo \${${component}[FILESPEC]}"
    fi

    return 0
}

get_component_branch ()
{
#    trace "$*"

    local component="`echo $1 | sed -e 's:-[0-9a-z\.\-]*::' -e 's:\.git.*::'`"
    if test "${component:+set}" != "set"; then
	echo "WARNING: ${component} does not exist!"
	return 1
    else
	eval "echo \${${component}[BRANCH]}"
    fi

    return 0
}

get_component_makeflags ()
{
#    trace "$*"

    local component="`echo $1 | sed -e 's:-[0-9a-z\.\-]*::' -e 's:\.git.*::'`"
    if test "${component:+set}" != "set"; then
	echo "WARNING: ${component} does not exist!"
	return 1
    else
	eval "echo \${${component}[MAKEFLAGS]}"
    fi

    return 0
}

get_component_configure ()
{
#    trace "$*"

    local component="`echo $1 | sed -e 's:-[0-9a-z\.\-]*::' -e 's:\.git.*::'`"
    if test "${component:+set}" != "set"; then
	echo "WARNING: ${component} does not exist!"
	return 1
    else
	eval "echo \${${component}[CONFIGURE]}"
    fi

    return 0
}

get_component_staticlink ()
{
#    trace "$*"

    local component="`echo $1 | sed -e 's:-[0-9a-z\.\-]*::' -e 's:\.git.*::'`"
    if test "${component:+set}" != "set"; then
	echo "WARNING: ${component} does not exist!"
	return 1
    else
	eval "echo \${${component}[STATICLINK]}"
    fi

    return 0
}

get_component_runtestflags ()
{
#    trace "$*"

    local component="`echo $1 | sed -e 's:-[0-9a-z\.\-]*::' -e 's:\.git.*::'`"
    if test "${component:+set}" != "set"; then
	echo "WARNING: ${component} does not exist!"
	return 1
    else
	eval "echo \${${component}[RUNTESTFLAGS]}"
    fi

    return 0
}

component_is_tar ()
{
    trace "$*"

    local component="`echo $1 | sed -e 's:-[0-9a-z\.\-]*::' -e 's:\.git.*::'`"
    if test "${component:+set}" != "set"; then
	echo "WARNING: ${component} does not exist!"
	return 1
    else
	if test "`get_component_filespec ${component} | grep -c \.tar\.`" -gt 0; then
	    echo "yes"
	    return 0
	else
	    echo "no"
	    return 1
	fi
    fi
}

get_component_subdir ()
{
    trace "$*"

    local component="`echo $1 | sed -e 's:-[0-9a-z\.\-]*::' -e 's:\.git.*::'`"
    if test "${component:+set}" != "set"; then
	echo "WARNING: ${component} does not exist!"
	return 1
    else
	if test "`get_component_filespec ${component} | grep -c \.tar\.`" -gt 0; then
	    echo "yes"
	    return 0
	fi
    fi
}

# declare -p does print the same data from the array, but this is an easier to
# read version of the same data.
component_dump()
{
    trace "$*"

    local flag="`set -o | grep xtrace| tr -s ' ' | tr -d '\t' | cut -d ' ' -f 2`"
    set +x

    local component="`echo $1 | sed -e 's:-[0-9a-z\.\-]*::' -e 's:\.git.*::'`"
    if test "${component:+set}" != "set"; then
	echo "WARNING: ${component} does not exist!"
	return 1
    fi

    local data="`declare -p ${component} | sed -e 's:^.*(::' -e 's:).*$::'`"
    
    echo "Data dump of component \"${component}\""
    for i in ${data}; do
	echo "	$i"
    done

    if test x"${flag}" = x"on"; then
        set -x
    fi

    return 0
}

collect_data ()
{
    trace "$*"

    local component="`echo $1 | sed -e 's:\.git.*::' -e 's:-[0-9a-z\.\-]*::'`"

    # ABE's data is extracted differently tan the rest.
    if test x"${component}" = x"abe"; then
	pushd ${abe_path}
	local revision="`git log --format=format:%H -n 1`"
	local branch="`git branch | grep "^\*" | cut -d ' ' -f 2`"
	if test "`echo ${branch} | grep -c detached`" -gt -0; then
	    local branch=
	fi
	local url="`git config --get remote.origin.url`"
	local date="`git log -n 1 --format=%aD | tr ' ' '%'`"
	local filespec="abe.git"
	popd
	component_init ${component} TOOL=${component} ${branch:+BRANCH=${branch}} ${revision:+REVISION=${revision}} ${url:+URL=${url}} ${filespec:+FILESPEC=${filespec}} ${data:+DATE=${date}}
 	return 0
    fi

    local conf="`find ${local_builds}/${host}/${target} -name ${component}.conf`"
    if test x"${conf}" != x; then
	test ${topdir}/config/${component}.conf -nt ${conf}
	if test $? -gt 0; then
	    . "${topdir}/config/${component}.conf"
	else
	    notice "Local ${component}.conf overriding defaults"
	    . "${conf}"
	fi
    else
	. "${topdir}/config/${component}.conf"
    fi

    local version="${component}_version"
    local tool="${!version}"
    if test x"${tool}" = x; then
	eval ${component}_version="${latest}"
    fi    
    eval "local latest=\${${component}_version}"
    if test "`echo ${latest} | grep -c ${component}`" -eq 0; then
	latest="${component}-${latest}"
    fi
    if test `echo ${latest} | grep -c "\.tar"` -gt 0; then
	if test "`echo ${latest} | grep -c 'http*://.*\.tar\.'`" -eq 0; then
	    local url="`grep "^${component} " ${sources_conf} | tr -s ' ' | cut -d ' ' -f 2`"
	    local filespec="${latest}"
	else
	    local url="`dirname ${latest}`"
	    local filespec="`basename ${latest}`"
	fi

	if test "`echo ${url} | grep -c infrastructure`" -gt 0; then
	    local dir="/infrastructure"
	else
	    local dir=""
	fi
#	local filespec="${component}-${latest}"
	local dir="`echo ${dir}/${filespec} | sed -e 's:\.tar.*::'`"
    else
	local gitinfo="${!version}"
	local branch="`get_git_branch ${latest}`"
	local revision="`get_git_revision ${latest}`"
	local search=
	case ${component} in
	    binutils*|gdb*) search="binutils-gdb.git" ;;
	    *) search="${component}.git" ;;
	esac
	local url="`grep ^${search} ${sources_conf} | tr -s ' ' | cut -d ' ' -f 2`"
	if test x"{$url}" = x; then
	    warning "${component} Not found in  ${sources_conf}"
	    return 1
	fi
	local filespec="`basename ${url}`"
	local url="`dirname ${url}`"
	local fixbranch="`echo ${branch} | tr '/' '~'`"
	local dir=${search}${branch:+~${fixbranch}}${revision:+@${revision}}
    fi

    # configured and built as a separate way.
    local builddir="${local_builds}/${host}/${target}/${dir}"
    case "${component}" in
	gdbserver)
	    local srcdir=${local_snapshots}/${dir}/gdb/gdbserver
	    local builddir="${builddir}-gdbserver"
	    ;;
	*)
	    local srcdir="${local_snapshots}/${dir}"
	    ;;
    esac

    # Extract a few other data variables from the conf file and store them so
    # the conf file only needs to be sourced once.
    local confvars="${static_link:+STATICLINK=${static_link}}"
    confvars="${confvars} ${default_makeflags:+MAKEFLAGS=\"`echo ${default_makeflags} | tr ' ' '%'`\"}"
    confvars="${confvars} ${default_configure_flags:+CONFIGURE=\"`echo ${default_configure_flags} | tr ' ' '%'`\"}"
    if test x"${component}" = "xgcc"; then
	confvars="${confvars} ${default_configure_flags:+STAGE1=\"`echo ${stage1_flags} | tr ' ' '%'`\"}"
	confvars="${confvars} ${default_configure_flags:+STAGE2=\"`echo ${stage1_flags} | tr ' ' '%'`\"}"
    fi
    confvars="${confvars} ${runtest_flags:+RUNTESTFLAGS=\"`echo ${runtest_flags} | tr ' ' '%'`\"}"
    # Gdbserver is built differently, as it's a sub directory within GDB, but has to be
    fixme "TOOL=${component} ${branch:+BRANCH=${branch}} ${revision:+REVISION=${revision}} ${srcdir:+SRCDIR=${srcdir}} ${builddir:+BUILDDIR=${builddir}} ${filespec:+FILESPEC=${filespec}} ${url:+URL=${url}} ${confvars}"
    component_init ${component} TOOL=${component} ${branch:+BRANCH=${branch}} ${revision:+REVISION=${revision}} ${srcdir:+SRCDIR=${srcdir}} ${builddir:+BUILDDIR=${builddir}} ${filespec:+FILESPEC=${filespec}} ${url:+URL=${url}} ${confvars}

    default_makeflags=
    default_configure_flags=
    runtest_flags=

    return 0
}
