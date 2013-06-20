#!/bin/sh

error()
{
    echo "ERROR: $1"
}

warning()
{
    echo "WARNING: $1"
}

notice()
{
    echo "NOTE: $1"
}

# FIXME: this is a hack while in development
trunk_top=/linaro/src/gnu/gcc/trunk
merge_top=/linaro/src/linaro/gcc
bzr_top=/linaro/src/linaro/gcc/gcc-linaro-merges

# $1 - The version number to diff
merge_diff()
{
    # cleanup leftover files
    rm -f ${bzr_top}/merge-$1.diff.txt
    # find  -name \*.merge-right.\* -o -name \*.merge-left.\* -o -name \*.working -o -name \*.rej -exec rm -f {} \;
    diff -ruNp -x '*.patch' -x '*.svn' -x '*~' -x '*.bzr' -x '*.rej' -x '*.orig' -x '*.edited' -x '*diff.txt' -x '*.log' -x 'x' -x '*merge-left*' -x '*merge-right*' -x "*.working" -x '*/.gitignore' 4.8-branch ${merge_top}/merge-$1 > ${bzr_top}/merge-$1.diff.txt
    
    patch --directory ${bzr_top}/merge-r$1 -p1 < ${bzr_top}/merge-$1.diff.txt

    add="`grep '^A' ${merge_top}/merge-$1/merge.log | cut -d ' ' -f 5`"
    for i in ${add}; do
	notice "Adding $i to ${merge_top}/merge-r$1"
	cp ${merge_top}/merge-$1/$i ${merge_top}/merge-r$1/$i
	bzr add ${merge_top}/merge-r$1/$i
    done
}

# $1 - The version number to merge
merge_prep()
{
    if test ! -e $i-branch; then
	svn checkout svn+ssh://${svn_id}@gcc.gnu.org/svn/gcc/branches/linaro/gcc-$i-branch $1-branch
    fi

    #  svn checkout svn+ssh://${gccsvn_id}@gcc.gnu.org/svn/gcc/branches/gcc-$1-branch $1-branch

    bzr branch lp:gcc-linaro/4.8 merge-$1
}

# $1 - revision in trunk
# $2 - branch to get revision from
#
merge_branch()
{
    notice "Merging revision from trunk: $1"

    if test `basename merge-$1` != "merge-$1"; then	
    # 	if test ! -e merge-$1; then
    # 	    notice "Cloning source tree for merge-$1"
    # 	    cp -r 4.8-branch merge-$1
     	cd merge-$1
    # 	fi
    fi

    if test ! -e ${merge_top}/merge-$1/merge.log; then
	#conflicts="`svn merge --accept postpone -c $1 /linaro/src/gnu/gcc/trunk`"
	svn merge --accept postpone -c $1 ${trunk_top} 2>&1 | tee ${merge_top}/merge-$1/merge.log
    fi

    notice "Looking for merge conflicts..."
    #conflicts="`svn status | grep "^C"`"
    conflicts="`grep "^C" ${merge_top}/merge-$1/merge.log | sed -e 's:^C *: :' | tr -d '\n'`"
    notice "Conflicts: ${conflicts}"	
    
    for i in ${conflicts}; do
	notice "Resolving conflict: $i"	
	year="`date +%Y`"
	month="`date +%m`"
	day="`date +%d`"
	
	# If no email address is in ~/.cbuildrc, create one
	if test x"${email}" = x; then
	    email="${LOGNAME}@`hostname`"
	fi
	fullname="`grep ^${LOGNAME} /etc/passwd | cut -d ':' -f 5 | sed -e 's:,*::g'`"
        # reset the list
	problems=""
	
        # Delete the old 
	rm -f ${merge_top}/merge-$1/merge.patch
	touch ${merge_top}/merge-$1/merge.patch
	    # We don't want to edit the ChangeLog, merges go in ChangeLog.linaro.
	    # Start by making a new ChangeLog entry for this merge, and append
	    # the entry from trunk for the commit, followed by the rest of the
	    # ChangeLog.linaro file.
	if test `echo $i | grep -c ChangeLog` -eq 1; then
	    echo "${year}-${month}-${day}  ${fullname}  <${email}>" > ${merge_top}/merge-$1/header.patch
	    echo "" >> ${merge_top}/merge-$1/header.patch
	    # some of these echoes have embedded TABs
	    echo "	Backport from trunk r$1" >> ${merge_top}/merge-$1/header.patch
	    
	    # We can't do a normal patch operation, as it always has problems. So
	    # munge the raw patch to the text equivalent, where we manually add
	    # it to the top of the ChangeLog.linaro file.
	    if test ! -e ${merge_top}/merge-$1/diff.txt; then
		svn diff -c $1 ${trunk_top}/trunk/$i 2>&1 > ${merge_top}/merge-$1/diff.txt
	    fi
	    grep "^\+" ${merge_top}/merge-$1/diff.txt | sed -e 's:^\+::' | grep -v "revision" 2>&1 > ${merge_top}/merge-$1/body.patch
	    # So this mess is because if the last commit is by he same person as
	    # the previous one, it puts it at the end of the mergke patch, instead
	    # of under the backport
	    author="`grep -n ".*<.*@.*>" ${merge_top}/merge-$1/body.patch | cut -d ':' -f 1 | tail -1`"
	    if test ${author} -gt 1; then
		author="`tail -2 ${merge_top}/merge-$1/body.patch`"
		lines="`wc -l ${merge_top}/merge-$1/body.patch | cut -d ' ' -f 1`"
		keep="`expr ${lines} - 2`"
		cat ${merge_top}/merge-$1/header.patch  > ${merge_top}/merge-$1/merge.patch
		echo "	${author}" >> ${merge_top}/merge-$1/merge.patch
		sed -e "${keep},${lines}d" ${merge_top}/merge-$1/body.patch >> ${merge_top}/merge-$1/merge.patch
		head -n ${keep} ${merge_top}/merge-$1/body.patch >> ${merge_top}/merge-$1/merge.patch
	    else
		cat ${merge_top}/merge-$1/header.patch  > ${merge_top}/merge-$1/merge.patch
		echo -n "	"    >> ${merge_top}/merge-$1/merge.patch
		cat ${merge_top}/merge-$1/body.patch   >> ${merge_top}/merge-$1/merge.patch
	    fi
	    mv ${merge_top}/merge-$1/$i.linaro ${merge_top}/merge-$1/$i.linaro.orig
	    cat ${merge_top}/merge-$1/merge.patch > ${merge_top}/merge-$1/$i.linaro
	    cat ${merge_top}/merge-$1/$i.linaro.orig >> ${merge_top}/merge-$1/$i.linaro
	    find ${merge_top}/merge-$1 -name \*.merge-right.\* -o -name \*.merge-left.\* -o -name \*.working -o -name \*.rej -exec rm -f {} \;
	    rm -f ${merge_top}/merge-$1/*.patch ${merge_top}/merge-$1/diff.txt
	    # We can now revert the ChangeLog that was conflicted, as the entry
	    # is in the proper ChangeLong.linaro file.
	    (cd  ${merge_top}/merge-$1 && svn revert $i)
	else
	    problems=" ${problems} $i"
	fi
    done
    
    if test x"${problems}" != x; then
	error "Unresolved conflicts: ${problems}"
    else
	notice "No conflicts left to resolve"
    fi
    
#    if test `basename merge-$1` = "merge-$1"; then
#	cd ..
#    fi
}

# $1 - revision in trunk
merge_patch()
{
    echo $1

    svn diff -c $1 > $i.patch
}

