#!/bin/sh

#
# This does a checkout from a source code repository
#

# svn+ssh://rsavoye@gcc.gnu.org/svn/gcc/branches/linaro/gcc-4_8-branch
# eglibc ssh://robert.savoye@git.linaro.org/srv/git.linaro.org/git/toolchain/eglibc.git
# newlib-linaro ssh://robert.savoye@git.linaro.org/srv/git.linaro.org/git/toolchain/newlib.git

# It's optional to use git-bzr-ng or git-svn to work on the remote sources,
# but we also want to work with the native source code control system.
usegit=no

# This gets the source tree from a remote host
# $1 - The URL used for getting the sources
checkout()
{
    if test x"$1" = x; then
	error "No URL given!"
	return 1
    fi

    dir="`normalize_path $1`"
    if test `echo $1 | grep -c "\.git/"`; then
	branch="`basename $1`"
    else
	branch="master"
    fi

    notice "Checking out sources for $1"

    case $1 in
	bzr*|lp*)
	    if test x"${force}" =  xyes; then
		#rm -fr ${local_snapshots}/${dir}
		echo "Removing existing sources for ${local_snapshots}/${dir}"
	    fi
	    if test x"${usegit}" =  xyes; then
		out="`git-bzr clone $1 ${local_snapshots}/${dir}`"
	    else
		if test -e ${local_snapshots}/${dir}/.bzr; then
		    out="`(cd ${local_snapshots}/${dir} && bzr pull)`"
		else
		    out="`bzr branch $1 ${local_snapshots}/${dir}`"
		fi
	    fi
	    ;;
	svn*|http*)
	    trunk="`echo $1 |grep -c trunk`"
	    if test ${trunk} -gt 0; then
		dir="`dirname $1`"
		dir="`basename ${dir}`/trunk"
	    fi
	    if test x"${force}" =  xyes; then
		#rm -fr ${local_snapshots}/${dir}
		echo "Removing existing sources for ${local_snapshots}/${dir}"
	    fi
	    if test x"${usegit}" =  xyes; then
		out="`git svn clone $1 ${local_snapshots}/${dir}`"
	    else
		if test -e ${local_snapshots}/${dir}/.svn; then
		    (cd ${local_snapshots}/${dir} && svn update)
		    # Extract the revision number from the update message
		    revision="`echo ${out} | sed -e 's:.*At revision ::' -e 's:\.::'`"
		else
		    svn checkout $1 ${local_snapshots}/${dir}
		fi
	    fi
	    ;;
	git*)
	    if test x"${force}" =  xyes; then
		#rm -fr ${local_snapshots}/${dir}
		echo "Removing existing sources for ${local_snapshots}/${dir}"
	    fi
	    if test -e ${local_snapshots}/${dir}/.git; then
		out="`(cd ${local_snapshots}/${dir} && git checkout ${branch} && git pull)`"
	    else
		out="`git clone $1 ${local_snapshots}/${dir}`"
	    fi
	    ;;
	*)
	    ;;
    esac

    if test $? -gt 1; then
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
	repo="origin"
    fi

    # bzr uses slashes in it's path names, so convert them so we
    # can use the for accessing the source directory.
    url="`echo $1 | sed -e 's:/:_:'`"
    dir="`basename ${url} |sed -e 's/^.*://'`"

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
	    trunk="`echo $1 |grep -c trunk`"
	    if test ${trunk} -gt 0; then
		dir="`dirname $1`"
		dir="`basename ${dir}`/trunk"
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
	git*)
	    if test x"$3" = x; then
		warning "No branch given, so using master or trunk"
		branch="master"
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
    url="`echo $1 | sed -e 's:/:_:'`"
    dir="`basename ${url} |sed -e 's/^.*://'`"

    # We use git for our copy by importing from the other systems
    case $1 in
	bzr*|lp*)
	    if test x"${usegit}" =  xyes; then
		#out="`git-bzr push $1 ${local_snapshots}/${dir}`"
		echo "FIXME: shouldn't be here!"
	    else
		if test x"$2" = x; then
		    warning "No file given, so commiting all"
		    files=""
		else
		    files="$2"
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
	    trunk="`echo $1 |grep -c trunk`"
	    if test ${trunk} -gt 0; then
		dir="`dirname $1`"
		dir="`basename ${dir}`/trunk"
	    fi
	    if test x"$2" = x; then
		warning "No file given, so commiting all"
		files=""
	    else
		files="$2"
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
	git*)
	    if test x"$2" = x; then
		warning "No files given, so commiting all"
		files="-a"
	    else
		files="$2"
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


