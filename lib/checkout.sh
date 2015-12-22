#!/bin/bash
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

#
# This does a checkout from a source code repository
#

# It's optional to use git-bzr-ng or git-svn to work on the remote sources,
# but we also want to work with the native source code control system.
usegit=no

# This is similar to make_all except it _just_ gathers sources trees and does
# nothing else.
checkout_all()
{
    trace "$*"

    local packages="$*"

    for i in ${packages}; do
	local package=$i
	if test x"$i" = x"libc"; then
	    package="${clibrary}"
	fi
	if test x"${package}" = x"stage1" -o x"${package}" = x"stage2"; then
	    package="gcc"
	fi
	collect_data ${package}

	local filespec="`get_component_filespec ${package}`"
	if test "`component_is_tar ${package}`" = no; then
 	    local checkout_ret=
	    checkout ${package}
	    checkout_ret=$?
	    if test ${checkout_ret} -gt 0; then
		error "Failed checkout out of ${name}."
		return 1
	    fi
	else
	    fetch ${package}
	    if test $? -gt 0; then
		error "Couldn't fetch tarball ${package}"
		return 1
	    fi
	    extract ${package}
	    if test $? -gt 0; then
		error "Couldn't extract tarball ${package}"
		return 1
	    fi
	fi

	if test $? -gt 0; then
	    error "Failed checkout out of ${package}."
	    return 1
	fi
    done
    
    if test `echo ${host} | grep -c mingw` -eq 1; then
	# GDB now needs expat for XML support.
	mkdir -p ${local_builds}/destdir/${host}/bin/
	collect_data expat
	fetch expat
	extract expat
	rsync -ar ${local_snapshots}/expat-2.1.0-1/include ${local_builds}/destdir/${host}/usr/
	rsync -ar ${local_snapshots}/expat-2.1.0-1/lib ${local_builds}/destdir/${host}/usr/
	# GDB now has python support, for mingw we have to download a
	# pre-built win2 binary that works with mingw32.
	collect_data python
	fetch python
	extract python
	# The mingw package of python contains a script used by GDB to
	# configure itself, this is used to specify that path so we don't
	# have to modify the GDB configure script.
	export PYTHON_MINGW=${local_snapshots}/python-2.7.4-mingw32
	# The Python DLLS need to be in the bin dir where the executables are.
	rsync -ar ${PYTHON_MINGW}/pylib ${local_builds}/destdir/${host}/bin/
	rsync -ar ${PYTHON_MINGW}/dll ${local_builds}/destdir/${host}/bin/
	rsync -ar ${PYTHON_MINGW}/libpython2.7.dll ${local_builds}/destdir/${host}/bin/
	# Future make check support of python GDB in mingw32 will require these
	# exports.  Export them now for future reference.
	export PYTHONHOME=${local_builds}/destdir/${host}/bin/dll
	warning "You must set PYTHONHOME in your environment to ${PYTHONHOME}"
	export PYTHONPATH=${local_builds}/destdir/${host}/bin/pylib
	warning "You must set PYTHONPATH in your environment to ${PYTHONPATH}"
    fi

    # Reset to the stored value
    if test `echo ${host} | grep -c mingw` -eq 1 -a x"${tarbin}" = xyes; then
	files="${files} installjammer-1.2.15.tar.gz"
    fi

    notice "Checkout all took ${SECONDS} seconds"

    # Set this to no, since all the sources are now checked out
    supdate=no

    return 0
}

# Try hard to get git command succeed.  Retry up to 10 times.
# $@ - arguments passed directly to "git".
git_robust()
{
    local try=1
    local cmd="git $@"

    while [ "$try" -lt "10" ]; do
	try="$(($try+1))"
	flock ${local_builds}/git$$.lock --command "${cmd}" && break
    done
}

# This gets the source tree from a remote host
# $1 - This should be a service:// qualified URL.  If you just
#       have a git identifier call get_URL first.
checkout()
{
    trace "$*"

    local component="$1"

    # gdbserver is already checked out in the GDB source tree.
    if test x"${component}" = x"gdbserver}"; then
	return 0
    fi

    # None of the following should be able to fail with the code as it is
    # written today (and failures are therefore untestable) but propagate
    # errors anyway, in case that situation changes.
    local url="`get_component_url ${component}`" || return 1
    local branch="`get_component_branch ${component}`" || return 1
    local revision="`get_component_revision ${component}`" || return 1
    local srcdir="`get_component_srcdir ${component}`" || return 1
    local repo="`get_component_filespec ${component}`" || return 1
    local protocol="`echo ${url} | cut -d ':' -f 1`"    

    case ${protocol} in
	git*|http*|ssh*)
            local repodir="${url}/${repo}"
#	    local revision= `echo ${gcc_version} | grep -o "[~@][0-9a-z]*\$" | tr -d '~@'`"
	    if test x"${revision}" != x"" -a x"${branch}" != x""; then
		warning "You've specified both a branch \"${branch}\" and a commit \"${revision}\"."
		warning "Git considers a commit as implicitly on a branch.\nOnly the commit will be used."
	    fi

	    # If the master branch doesn't exist, clone it. If it exists,
	    # update the sources.
	    if test ! -d ${local_snapshots}/${repo}; then
		local git_reference_opt=
		if test -d "${git_reference_dir}/${repo}"; then
		    local git_reference_opt="--reference ${git_reference_dir}/${repo}"
		fi
		notice "Cloning $1 in ${srcdir}"
		dryrun "git_robust clone ${git_reference_opt} ${repodir} ${local_snapshots}/${repo}"
		if test $? -gt 0; then
		    error "Failed to clone master branch from ${url} to ${srcdir}"
		    rm -f ${local_builds}/git$$.lock
		    return 1
		fi
	    fi

	    if test ! -d ${srcdir}; then
		# By definition a git commit resides on a branch.  Therefore specifying a
		# branch AND a commit is redundant and potentially contradictory.  For this
		# reason we only consider the commit if both are present.
		if test x"${revision}" != x""; then
		    notice "Checking out revision for ${component} in ${srcdir}"
		    if test x${dryrun} != xyes; then
			local cmd="${NEWWORKDIR} ${local_snapshots}/${repo} ${srcdir} ${revision}"
			flock ${local_builds}/git$$.lock --command "${cmd}"
			if test $? -gt 0; then
			    error "Revision ${revision} likely doesn't exist in git repo ${repo}!"
			     rm -f ${local_builds}/git$$.lock
			     return 1
			fi
		    fi
		    # git checkout of a commit leaves the head in detached state so we need to
		    # give the current checkout a name.  Use -B so that it's only created if
		    # it doesn't exist already.
		    dryrun "(cd ${srcdir} && git checkout -B local_${revision})"
	        else
		    notice "Checking out branch ${branch} for ${component} in ${srcdir}"
		    if test x${dryrun} != xyes; then
			local cmd="${NEWWORKDIR} ${local_snapshots}/${repo} ${srcdir} ${branch}"
			flock ${local_builds}/git$$.lock --command "${cmd}"
			if test $? -gt 0; then
			    error "Branch ${branch} likely doesn't exist in git repo ${repo}!"
			    rm -f ${local_builds}/git$$.lock
			    return 1
			fi
		    fi
		fi
		# dryrun "git_robust clone --local ${local_snapshots}/${repo} ${srcdir}"
		# dryrun "(cd ${srcdir} && git checkout -B ${branch})"
	    elif test x"${supdate}" = xyes; then
		# Some packages allow the build to modify the source directory and
		# that might screw up abe's state so we restore a pristine branch.
		notice "Updating sources for ${component} in ${srcdir}"
		local current_branch="`cd ${srcdir} && git branch`"
		if test "`echo ${current_branch} | grep -c local_`" -eq 0; then
		    dryrun "(cd ${srcdir} && git stash --all)"
		    dryrun "(cd ${srcdir} && git reset --hard)"
		    dryrun "(cd ${srcdir} && git_robust pull)"
		    # This is required due to the following scenario:  A git
		    # reference dir is populated with a git clone on day X.  On day
		    # Y a developer removes a branch and then replaces the same
		    # branch with a new branch of the same name.  On day Z ABE is
		    # executed against the reference dir copy and the git pull fails
		    # due to error: 'refs/remotes/origin/<branch>' exists; cannot
		    # create 'refs/remotes/origin/<branch>'.  You have to remove the
		    # stale branches before pulling the new ones.
		    dryrun "(cd ${srcdir} && git remote prune origin)"
		    
		    dryrun "(cd ${srcdir} && git_robust pull)"
		    # Update branch directory (which maybe the same as repo
		    # directory)
		    dryrun "(cd ${srcdir} && git stash --all)"
		    dryrun "(cd ${srcdir} && git reset --hard)"
		fi
		if test x"${revision}" != x""; then
		    # No need to pull.  A commit is a single moment in time
		    # and doesn't change.
		    dryrun "(cd ${srcdir} && git_robust checkout -B local_${revision})"
		else
		    # Make sure we are on the correct branch.
		    # This is a no-op if $branch is empty and it
		    # just gets master.
		    dryrun "(cd ${srcdir} && git_robust checkout -B ${branch} origin/${branch})"
		    dryrun "(cd ${srcdir} && git_robust pull)"
		fi
	    fi

	    local newrev="`pushd ${srcdir} 2>&1 > /dev/null && git log --format=format:%H -n 1 ; popd 2>&1 > /dev/null`"
	    if test x"${revision}" != x"${newrev}" -a x"${revision}" != x; then
		error "SHA1s don't match for ${component}!, now is ${newrev}, was ${revision}"
		return 1
	    fi
	    set_component_revision ${component} ${newrev}
	    ;;
	*)
	    ;;
    esac

    if test $? -gt 0; then
	error "Couldn't checkout $1 !"
	rm -f ${local_builds}/git$$.lock
	return 1
    fi

    if test -e ${srcdir}/contrib/gcc_update; then
        # Touch GCC's auto-generated files to avoid non-deterministic
        # build behavior.
        dryrun "(cd ${srcdir} && ./contrib/gcc_update --touch)"
    fi

    rm -f ${local_builds}/git$$.lock
    return 0
}

# This pushes a source tree up to a remote host. For bzr and git, any changes
# that should be uploaded to the remote source repository need to be commit()'d
# first. For svn and cvs, this push does a commit instead.
# $1 - The URL to push to, same as used for checkout
# $2 - The optional host to push to
# $3 - The optional branch to push to
push ()
{
    if test x"$1" = x; then
	error "No URL given!"
	return 1
    fi
    if test x"$2" = x; then
	warning "No host given, so using origin"
	local repo="origin"
    fi

    # bzr uses slashes in it's path names, so convert them so we
    # can use the for accessing the source directory.
    local url="`echo $1 | sed -e 's:/:_:'`"
    local dir="`basename ${url} |sed -e 's/^.*://'`"

    # We use git for our copy by importing from the other systems
    case $1 in
	git*|ssh*)
	    if test x"$3" = x; then
		warning "No branch given, so using master or trunk"
		local branch="master"
	    fi
	    if test -e ${local_snapshots}/${dir}/.git; then
		#out="`(cd ${local_snapshots}/${dir} && git push ${repo} ${branch}`"
		notice "Pushing ${dir} upstream"
		notice "git push ${repo} ${branch}"
	    else
		error "${local_snapshots}/${dir} doesn't exist!"
		return 1
	    fi
	    ;;
	*)
	    ;;
    esac

    return 0
}

# This commits a change to a source tree. For bzr and git, this only
# modifies the local source tree, and push() must be executed to actually
# upload the changes to the remote source tree. For svn and cvs, the
# commit modifies the remote sources at the same time.
# $1 - The URL used for checkout()
# $2 - the file or directory to commit
commit ()
{
    # bzr uses slashes in it's path names, so convert them so we
    # can use the for accessing the source directory.
    local url="`echo $1 | sed -e 's:/:_:'`"
    local dir="`basename ${url} |sed -e 's/^.*://'`"

    # We use git for our copy by importing from the other systems
    case $1 in
	git*|ssh*)
	    if test x"$2" = x; then
		warning "No files given, so commiting all"
		local files="-a"
	    else
		local files="$2"
	    fi
	    if test -e ${local_snapshots}/${dir}/.git; then
		#out="`(cd ${local_snapshots}/${dir} && git commit --file ${local_snapshots}/${dir}/commitmsg.txt ${files}`"
		notice "Committing ${files} to local repository..."
		notice "git commit -m \"`cat ${local_snapshots}/${dir}/commitmsg.txt`\" ${files}"
   	    else
		error "${local_snapshots}/${dir} doesn't exist!"
		return 1
	    fi
	    ;;
	*)
	    ;;
    esac

    return 0
}

# Create a new tag in a repository
# $1 - The URL used for checkout()
# $2 - the tag name
tag()
{
    error "unimplemented"
}

# Change the active branch.
# FIXME: for now, this only supports git.
#
# $1 - The toolchain component to use, which looks like this:
# gcc.git/linaro-4.8-branch@123456
# Which breaks down as gcc.git is the component name. Anything after a slash
# is the branch. Anything after a '@' is a GIT commit hash ID.
change_branch()
{
    trace "$*"

    local version="`basename $1`"
    local branch="`echo $1 | cut -d '/' -f 2`"

    local srcdir="`get_component_srcdir $1`"
    if test "`echo $1 | grep -c '@'`" -gt 0; then
	local revision="`echo $1 | cut -d '@' -f 2`"
    else
	local revision=""
    fi

    if test ! -d ${srcdir}/${branch}; then
	local cmd="${NEWWORKDIR} ${local_snapshots}/${version} ${local_snapshots}/${version}-${branch} ${branch}"
	dryrun "flock ${local_builds}/git$$.lock --command ${cmd}"
    else
	if test x"${supdate}" = xyes; then
	    if test x"${branch}" = x; then
		dryrun "(cd ${local_snapshots}/${version} && git_robust pull origin master)"
	    else
		dryrun "(cd ${local_snapshots}/${version}-${branch} && git_robust pull origin ${branch})"
	    fi
	fi
    fi
    
    return 0
}

