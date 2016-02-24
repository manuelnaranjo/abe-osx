#!/bin/sh
# 
#   Copyright (C) 2013, 2014, 2015 Linaro, Inc
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

# These store all the data used for this test run that can be overwritten by
# command line options.

# Start by assuming it's a native build
build="${build}"
host="${host:-${build}}"
target="${host}"

date="`date "+%Y.%m.%d"`"
gcc="`which gcc`"
host_gcc_version="`${gcc} -v 2>&1 | tail -1`"
binutils="default"
# This is the default clibrary and can be overridden on the command line.
clibrary="glibc"
snapshots="default"
configfile="default"
dbuser="default"
dbpasswd="default"

# Don't set this unless you need to modify it.
override_arch=
override_cpu=
override_tune=

manifest_version=1.0

# The prefix for installing the toolchain
prefix=

# The default timeout.  If you're on a wireless network this
# might not be sufficient and can be overridden at the command
# line.
wget_timeout=10
wget_quiet=
# Try something like "dot:mega"
wget_progress_style=

# This doesn't do any real work, just prints the configure options and make commands
dryrun=no

#
launchpad_id=
svn_id=

# config values for the build machine
libc_version=
kernel=${kernel:+${kernel}}
build_arch=${build_arch:+${build_arch}}
hostname=${hostname:+${hostname}}
distribution=${distribution:+${distribution}}

# These are options flags to pass to make, usually just -j N as set by --parallel
make_flags=

# These can be changed by environment variables
if test x"${SNAPSHOTS_URL}" != x -o x"${ABE_SNAPSHOTS}" != x; then
    snapshots="${SNAPSHOTS_URL}"
fi
if test x"${ABE_DBUSER}" != x; then
    dbuser="${ABE_DBUSER}"
fi
if test x"${ABE_DBPASSWD}" != x; then
    dbpasswd="${ABE_DBPASSWD}"
fi

clobber=no
force=no
interactive=no
nodepends=no
verbose=1
network=""

# Don't modify this in this file unless you're adding to it.  This is the list
# of packages that have make check run against them.  It will be queried for
# content when the users passes --check <package> or --excludecheck <package>.
all_unit_tests="glibc gcc gdb binutils"

# Packages to run make check (unit-test) on.  This variable is composed from
# all --check <package> and --excludecheck <package> switches.  Don't modify
# this parameter manually.
runtests=

ccache=no
#gerrit=no

release=""
with_packages="toolchain,sysroot,gdb"
building=yes

override_linker=
override_cflags=
override_ldflags=
override_runtestflags=

if test x"${BUILD_NUMBER}" = x; then
    export BUILD_NUMBER=${RANDOM}
fi

gerrit_host="review.linaro.org"
gerrit_port="29418"
gerrit_username=""
gerrit_project=""
gerrit_branch=""
gerrit_revision=""
gerrit_change_subject=""
gerrit_change_id=""
gerrit_change_number=""
gerrit_event_type=""
jenkins_job_name=""
jenkins_job_url=""
sources_conf="${sources_conf:-${abe_path}/config/sources.conf}"

# source a user specific config file for commonly used configure options.
# These overide any of the above values.
if test -e ~/.aberc; then
    . ~/.aberc
fi

#
#
#
import_manifest()
{
    trace "$*"

    manifest=$1
    if test -f ${manifest} ; then
	local components="`grep "Component data for " ${manifest} | cut -d ' ' -f 5`"

	clibrary="`grep "clibrary=" ${manifest} | cut -d '=' -f 2`"
	local ltarget="`grep target= ${manifest}  | cut -d '=' -f 2`"
	if test x"${ltarget}" != x; then
	    target=${ltarget}
	fi
	if test "`echo ${sysroots} | grep -c ${target}`" -eq 0; then
	    sysroots=${sysroots}/${target}
	fi

	local manifest_format="`grep "manifest_format" ${manifest} | cut -d '=' -f 2`"
	if test ${manifest_version} != ${manifest_format}; then
	    warning "Imported manifest isn't the current supported format!"
	fi
	local variables=
	local i=0
	for i in ${components}; do
	    local url="`grep "${i}_url" ${manifest} | cut -d '=' -f 2`"
	    local branch="`grep "${i}_branch" ${manifest} | cut -d '=' -f 2`"
	    local filespec="`grep "${i}_filespec" ${manifest} | cut -d '=' -f 2`"
	    local static="`grep "${i}_staticlink" ${manifest} | cut -d '=' -f 2`"
	    # Any embedded spaces in the value have to be converted to a '%'
	    # character. for component_init().
	    local makeflags="`grep "${i}_makeflags" ${manifest} | cut -d '=' -f 2-20 | tr ' ' '%'`"
	    eval "makeflags=${makeflags}"
	    local configure="`grep "${i}_configure" ${manifest} | cut -d '=' -f 2-20 | tr ' ' '%'| tr -d '\"'`"
	    eval "configure=${configure}"
	    local revision="`grep "${i}_revision" ${manifest} | cut -d '=' -f 2`"
	    if test "`echo ${filespec} | grep -c \.tar\.`" -gt 0; then
		local version="`echo ${filespec} | sed -e 's:\.tar\..*$::'`"
		local dir=${version}
	    else
		local fixbranch="`echo ${branch} | tr '/@' '_'`"
		local dir=${i}.git~${fixbranch}${revision:+_rev_${revision}}
	    fi
	    local srcdir="${local_snapshots}/${dir}"
	    local builddir="${local_builds}/${host}/${target}/${dir}"
	    case "${i}" in
		gdb|binutils)
		    local dir="`echo ${dir} | sed -e 's:^.*\.git:binutils-gdb.git:'`"
		    local srcdir=${local_snapshots}/${dir}
		    local builddir="${local_builds}/${host}/${target}/${dir}"
		    ;;
		gdbserver)
		    local dir="`echo ${dir} | sed -e 's:^.*\.git:binutils-gdb.git:'`"
		    local srcdir=${local_snapshots}/${dir}/gdb/gdbserver
 		    local builddir="${local_builds}/${host}/${target}/${dir}-gdbserver"
		    ;;
		*glibc)		    
		    # Glibc builds will fail if there is an @ in the path. This is
		    # unfortunately, as @ is used to deliminate the revision string.
		    local srcdir="${local_snapshots}/${dir}"
		    local builddir="`echo ${local_builds}/${host}/${target}/${dir} | tr '@' '_'`"
		    ;;
		gcc)
		    local configure=
		    local stage1_flags="`grep gcc_stage1_flags= ${manifest} | cut -d '=' -f 2-20 | tr ' ' '%' | tr -d '\"'`"
		    eval "stage1_flags=${stage1_flags}"
		    local stage2_flags="`grep gcc_stage2_flags= ${manifest} | cut -d '=' -f 2-20 | tr ' ' '%' | tr -d '\"'`"
		    eval "stage2_flags=${stage2_flags}"
		    ;;
		*)
		    ;;
	    esac

	    component_init $i ${branch:+BRANCH=${branch}} ${revision:+REVISION=${revision}} ${url:+URL=${url}} ${filespec:+FILESPEC=${filespec}} ${srcdir:+SRCDIR=${srcdir}} ${builddir:+BUILDDIR=${builddir}} ${stage1_flags:+STAGE1=\"${stage1_flags}\"} ${stage2_flags:+STAGE2=\"${stage2_flags}\"} ${configure:+CONFIGURE=\"${configure}\"} ${makeflags:+MAKEFLAGS=\"${makeflags}\"} ${static:+STATICLINK=${static}}
	    unset stage1_flags
	    unset stage2_flags
	    unset url
	    unset branch
	    unset filespec
	    unset static
	    unset makeflags
	    unset configure
	done
    else
	error "Manifest file '${file}' not found"
	build_failure
	return 1
    fi
   
    return 0
}
