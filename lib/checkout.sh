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

#
# This does a checkout from a source code repository
#

# It's optional to use git-bzr-ng or git-svn to work on the remote sources,
# but we also want to work with the native source code control system.
usegit=no

# This is used by abe.sh --checkout all but not by --build
checkout_infrastructure()
{
    trace "$*"

    if test x"${supdate}" = xno; then
	warning "checkout_infrastructure called with --disable update. Checkout of infrastructure files will be skipped."
	return 0
    fi

    source_config infrastructure

    if test x"${depends}" = x; then
	error "No dependencies listed for infrastructure libraries!"
	return 1
    fi

    # This shouldn't happen, but it's nice for regression verification.
    if test ! -e ${local_snapshots}/md5sums; then
	error "Missing ${local_snapshots}/md5sums file needed for infrastructure libraries."
	return 1
    fi

    # We have to grep each dependency separately to preserve the order, as
    # some libraries depend on other libraries being bult first. Egrep
    # unfortunately sorts the files, which screws up the order.
    local files="`grep ^latest= ${topdir}/config/dejagnu.conf | cut -d '\"' -f 2`"

    local version=
    for i in ${depends}; do
	case $i in
	    linux) version=${linux_version} ;;
	    mpfr) version=${mpfr_version} ;;
	    mpc) version=${mpc_version} ;;
	    gmp) version=${gmp_version} ;;
	    dejagnu) version=${dejagnu_version} ;;
	    *)
		error "config/infrastructure.conf contains an unknown dependency: $i"
		return 1
		;;
	esac

	# If the user didn't set it, check the <component>.conf files for
	# 'latest'.
	if test "${version:+set}" != "set"; then
	    version="`grep ^latest= ${topdir}/config/${i}.conf | cut -d '\"' -f 2`"
	    # Sometimes config/${i}.conf uses <component>-version and sometimes
	    # it just uses 'version'.  Regardless, searching the md5sums file requires
	    # that we include the component name.
	    version=${i}-${version#${i}-}
	fi

	if test "${version:+found}" != "found"; then
	    error "Can't find a version for component \"$i\" in ${i}.conf"
	    return 1
	fi

	# Hopefully we only download the exact match for each one.  Depending
	# how vague the user is it might download multiple tarballs.
	files="${files} `grep /${version} ${local_snapshots}/md5sums | cut -d ' ' -f3 | uniq`"
	unset version
    done

    if test `echo ${host} | grep -c mingw` -eq 1 -a x"${tarbin}" = xyes; then
	files="${files} installjammer-1.2.15.tar.gz"
    fi

    for i in ${files}; do
	local name="`echo $i | sed -e 's:\.tar\..*::' -e 's:infrastructure/::'  -e 's:testcode/::'`"
        local gitinfo=
	gitinfo="`get_source ${name}`"
	if test -z "${gitinfo}"; then
	    error "No matching source found for \"${name}\"."
	    return 1
	fi

	# Some infrastructure packages (like dejagnu) come from a git repo.
	local service=
	service="`get_git_service ${gitinfo}`" || return 1
	if test x"${service}" != x; then
	    local checkout_ret=
	    checkout ${gitinfo}
	    checkout_ret=$?
	    if test ${checkout_ret} -gt 0; then
		error "Failed checkout out of ${name}."
		return 1
	    fi
	else
	    fetch ${gitinfo}
	    if test $? -gt 0; then
		error "Couldn't fetch tarball ${gitinfo}"
		return 1
	    fi
	    extract ${gitinfo}
	    if test $? -gt 0; then
		error "Couldn't extract tarball ${gitinfo}"
		return 1
	    fi
	fi
    done

    return 0
}

# This is similar to make_all except it _just_ gathers sources trees and does
# nothing else.
checkout_all()
{
    local packages=
    packages="binutils libc gcc gdb"

    # See if specific component versions were specified at runtime
    if test x"${gcc_version}" = x; then
	gcc_version="`grep ^latest= ${topdir}/config/gcc.conf | cut -d '\"' -f 2`"
    fi
    if test x"${binutils_version}" = x; then
	binutils_version="`grep ^latest= ${topdir}/config/binutils.conf | cut -d '\"' -f 2`"
    fi
    if test x"${eglibc_version}" = x; then
	eglibc_version="`grep ^latest= ${topdir}/config/eglibc.conf | cut -d '\"' -f 2`"
    fi
    if test x"${newlib_version}" = x; then
	newlib_version="`grep ^latest= ${topdir}/config/newlib.conf | cut -d '\"' -f 2`"
    fi
    if test x"${glibc_version}" = x; then
	glibc_version="`grep ^latest= ${topdir}/config/glibc.conf | cut -d '\"' -f 2`"
    fi
    if test x"${gdb_version}" = x; then
	gdb_version="`grep ^latest= ${topdir}/config/gdb.conf | cut -d '\"' -f 2`"
    fi

    checkout_infrastructure
    if test $? -gt 0; then
	return 1
    fi

    for i in ${packages}; do
	local package=
	case $i in
	    gdb)
		package=${gdb_version}
		;;
	    binutils)
		package=${binutils_version}
		;;
	    gcc)
		package=${gcc_version}
		;;
	    libc)
		if test x"${clibrary}" = x"eglibc"; then
		    package=${eglibc_version}
		elif  test x"${clibrary}" = x"glibc"; then
		    package=${glibc_version}
		elif test x"${clibrary}" = x"newlib"; then
		    package=${newlib_version}
		else
		    error "\${clibrary}=${clibrary} not supported."
		    return 1
		fi
		;;
	    *)
		;;
	esac

    	local gitinfo="`get_source ${package}`"
	if test -z "${gitinfo}"; then
	    error "No matching source found for \"${name}\"."
	    return 1
	fi

	# If it doesn't have a service it's probably a tarball that we need to
	# fetch, especially likely if passed in on the command line.
	local service=
	service="`get_git_service ${gitinfo}`"
	if test x"${service}" != x; then
	    local checkout_ret=
	    checkout ${gitinfo}
	    checkout_ret=$?
	    if test ${checkout_ret} -gt 0; then
		error "Failed checkout out of ${name}."
		return 1
	    fi
	else
	    fetch ${gitinfo}
	    if test $? -gt 0; then
		error "Couldn't fetch tarball ${gitinfo}"
		return 1
	    fi
	    extract ${gitinfo}
	    if test $? -gt 0; then
		error "Couldn't extract tarball ${gitinfo}"
		return 1
	    fi
	fi
    done
    
    notice "Checkout all took ${SECONDS} seconds"

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

    if test x"$1" = x; then
	error "No URL given!"
	return 1
    fi

    local service=
    service="`get_git_service $1`" || return 1
    if test x"${service}" = x ; then
	error "Unable to parse service from '$1'. You have either a bad URL, or an identifier that should be passed to get_URL."
	return 1
    fi

    local repo=
    repo="`get_git_repo $1`" || return 1

    #None of the following should be able to fail with the code as it is
    #written today (and failures are therefore untestable) but propagate
    #errors anyway, in case that situation changes.
    local tool=
    tool="`get_toolname $1`" || return 1
    local url=
    url="`get_git_url $1`" || return 1
    local branch=
    branch="`get_git_branch $1`" || return 1
    local revision=
    revision="`get_git_revision $1`" || return 1
    local srcdir=
    srcdir="`get_srcdir $1`" || return 1

    case $1 in
	svn*)
	    local trunk="`echo $1 |grep -c trunk`"
	    if test ${trunk} -gt 0; then
		local dir="`dirname $1`"
		local dir="`basename ${dir}`/trunk"
	    fi
	    if test x"${force}" =  xyes; then
		#rm -fr ${local_snapshots}/${dir}
		echo "Removing existing sources for ${srcdir}"
	    fi
	    if test x"${usegit}" =  xyes; then
		local out="`git svn clone $1 ${srcdir}`"
	    else
		if test -e ${srcdir}/.svn; then
		    (cd ${srcdir} && svn update)
		    # Extract the revision number from the update message
		    local revision="`echo ${out} | sed -e 's:.*At revision ::' -e 's:\.::'`"
		else
		    svn checkout $1 ${srcdir}
                    if test $? -gt 0; then
                        error "Failed to check out $1 to ${srcdir}"
                        return 1
                    fi
		fi
	    fi
	    ;;
	git*|http*|ssh*)
            #FIXME: We deliberately ignored error returns from get_git_url,
            #       because any path with an '@' in will result in errors.
            #       Jenkins is wont to create such paths.
            local repodir="`get_git_url ssh://${srcdir} | sed 's#^ssh://##'`"

	    if test x"${revision}" != x"" -a x"${branch}" != x""; then
		warning "You've specified both a branch \"${branch}\" and a commit \"${revision}\"."
		warning "Git considers a commit as implicitly on a branch.\nOnly the commit will be used."
	    fi

	    # If the master branch doesn't exist, clone it. If it exists,
	    # update the sources.
	    if test ! -d ${repodir}; then
		local git_reference_opt
		if [ x"$git_reference_dir" != x"" -a \
		    -d "$git_reference_dir/$(basename $repodir)" ]; then
		    local git_reference_opt="--reference $git_reference_dir/$(basename $repodir)"
		fi
		notice "Cloning $1 in ${srcdir}"
		dryrun "git_robust clone $git_reference_opt ${url} ${repodir}"
		if test $? -gt 0; then
		    error "Failed to clone master branch from ${url} to ${repodir}"
		    return 1
		fi
	    fi

	    if test ! -d ${srcdir}; then
		# By definition a git commit resides on a branch.  Therefore specifying a
		# branch AND a commit is redundant and potentially contradictory.  For this
		# reason we only consider the commit if both are present.
		if test x"${revision}" != x""; then
		    notice "Checking out revision for ${tool} in ${srcdir}"
		    if test x${dryrun} != xyes; then
			local cmd="${NEWWORKDIR} ${local_snapshots}/${repo} ${srcdir} ${revision}"
			flock ${local_builds}/git$$.lock --command "${cmd}"
			if test $? -gt 0; then
			    error "Revision ${revision} likely doesn't exist in git repo ${repo}!"
				return 1
			fi
		    fi
		    # git checkout of a commit leaves the head in detached state so we need to
		    # give the current checkout a name.  Use -B so that it's only created if
		    # it doesn't exist already.
		    dryrun "(cd ${srcdir} && git checkout -B local_${revision})"
	        else
		    notice "Checking out branch ${branch} for ${tool} in ${srcdir}"
		    if test x${dryrun} != xyes; then
			local cmd="${NEWWORKDIR} ${local_snapshots}/${repo} ${srcdir} ${branch}"
			flock ${local_builds}/git$$.lock --command "${cmd}"
			if test $? -gt 0; then
			    error "Branch ${branch} likely doesn't exist in git repo ${repo}!"
			    return 1
			fi
		    fi
		fi
		# dryrun "git_robust clone --local ${local_snapshots}/${repo} ${srcdir}"
		# dryrun "(cd ${srcdir} && git checkout -B ${branch})"
	    elif test x"${supdate}" = xyes; then
		# Some packages allow the build to modify the source directory and
		# that might screw up abe's state so we restore a pristine branch.
		notice "Updating sources for ${tool} in ${srcdir}"
		dryrun "(cd ${repodir} && git stash --all)"
		dryrun "(cd ${repodir} && git reset --hard)"
		dryrun "(cd ${repodir} && git_robust pull)"
		# Update branch directory (which maybe the same as repo
		# directory)
		dryrun "(cd ${srcdir} && git stash --all)"
		dryrun "(cd ${srcdir} && git reset --hard)"
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
	    ;;
	*)
	    ;;
    esac

    if test $? -gt 0; then
	error "Couldn't checkout $1 !"
	return 1
    fi

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
	bzr*|lp*)
	    if test x"${usegit}" =  xyes; then
		#out="`git-bzr push $1 ${local_snapshots}/${dir}`"
		echo "FIXME: shouldn't be here!"
	    else
		if test -e ${local_snapshots}/${dir}/.bzr; then
		    #out="`(cd ${local_snapshots}/${dir} && bzr push)`"
		    notice "Pushing ${dir} upstream..."
		    notice "bzr push ${url}"
		else
		    error "${local_snapshots}/${dir} doesn't exist!"
		    return 1
		fi
	    fi
	    ;;
	svn*)
	    local trunk="`echo $1 |grep -c trunk`"
	    if test ${trunk} -gt 0; then
		local dir="`dirname $1`"
		local dir="`basename ${dir}`/trunk"
	    fi
	    if test x"${usegit}" =  xyes; then
		#out="`git svn push $1 ${local_snapshots}/${dir}`"
		echo "FIXME: shouldn't be here!"
	    else
		if test -e ${local_snapshots}/${dir}/.svn; then
		    #out="`(cd ${local_snapshots}/${dir} && svn commit`"
		    notice "Pushing ${dir} upstream"
		    notice "svn commit ${url}"
		else
		    error "${local_snapshots}/${dir} doesn't exist!"
		    return 1
		fi
	    fi
	    ;;
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
	bzr*|lp*)
	    if test x"${usegit}" =  xyes; then
		#out="`git-bzr push $1 ${local_snapshots}/${dir}`"
		echo "FIXME: shouldn't be here!"
	    else
		if test x"$2" = x; then
		    warning "No file given, so commiting all"
		    local files=""
		else
		    local files="$2"
		fi
		if test -e ${local_snapshots}/${dir}/.bzr; then
		    #out="`(cd ${local_snapshots}/${dir} && bzr commit --file ${local_snapshots}/${dir}/commitmsg.txt ${files}`"
		    notice "Committing ${dir} to local repository..."
		    notice "bzr commit -m \"`cat ${local_snapshots}/${dir}/commitmsg.txt`\" ${files}"
		else
		    error "${local_snapshots}/${dir} doesn't exist!"
		    return 1
		fi
	    fi
	    ;;
	svn*)
	    local trunk="`echo $1 |grep -c trunk`"
	    if test ${trunk} -gt 0; then
		local dir="`dirname $1`"
		local dir="`basename ${dir}`/trunk"
	    fi
	    if test x"$2" = x; then
		warning "No file given, so commiting all"
		local files=""
	    else
		local files="$2"
	    fi
	    if test x"${usegit}" =  xyes; then
		#out="`git svn push $1 ${local_snapshots}/${dir}`"
		echo "FIXME: shouldn't be here!"
	    else
		if test -e ${local_snapshots}/${dir}/.svn; then
		    #out="`(cd ${local_snapshots}/${dir} && svn commit --file ${local_snapshots}/${dir}/commitmsg.txt ${files}`"
		    notice "Committing ${files} to remote repository"
		    notice "svn commit -m  \"`cat ${local_snapshots}/${dir}/commitmsg.txt`\" ${files}"
		else
		    error "${local_snapshots}/${dir} doesn't exist!"
		    return 1
		fi
	    fi
	    ;;
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

    local dir="`normalize_path $1`"
    local version="`basename $1`"
    local branch="`echo $1 | cut -d '/' -f 2`"

    local srcdir="`get_srcdir $1`"
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

