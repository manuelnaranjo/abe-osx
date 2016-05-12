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

# FIXME: this is a hack while in development. These need to be configurable
trunk_top=/linaro/src/gnu/gcc/trunk
merge_top=/linaro/src/linaro/merges
bzr_top=/linaro/src/linaro/merges/bzr-branches

# $1 - The version number to diff
merge_diff()
{
    # cleanup leftover files
    notice "Making a diff from merge-r$1"
    rm -f ${bzr_top}/merge-$1.diff.txt
    diff -ruNp -x '*.patch' -x '*.rej' -x '*.orig' -x '*.edited' -x '*diff.txt' -x '*.log' -x 'x' -x '*merge-left*' -x '*merge-right*' -x "*.working" -x '*/.gitignore' 4.8-branch ${merge_top}/merge-r$1 > ${bzr_top}/merge-r$1.diff.txt
    
    # revert the bzr source tree so we get a clean patch
    notice "Reverting previous changes"
    (cd ${bzr_top}/merge-r$1 && bzr revert)

    notice "Patching ${bzr_top}/merge-r$1"
    patch --force --directory ${bzr_top}/merge-r$1 -p1 < ${bzr_top}/merge-r$1.diff.txt

    add="`grep '^A' ${merge_top}/merge-r$1/merge.log | cut -d ' ' -f 5`"
    for i in ${add}; do
	notice "Adding $i to ${merge_top}/merge-r$1"
	cp ${merge_top}/merge-r$1/$i ${bzr_top}/merge-r$1/$i
	bzr add ${bzr_top}/merge-r$1/$i
    done
}

# $1 - The version number to merge
merge_prep()
{
    if test ! -e ${merge_top}/merge-r$1; then
	notice "Cloning source tree into branch merge-r$1"
	cp -r ${merge_top}/4.8-branch ${merge_top}/merge-r$1
    fi
   
#    bzr branch lp:gcc-linaro/4.8 merge-$1
}

# $1 - revision in trunk
# $2 - branch to get revision from
#
merge_branch()
{
    # make sure the branch exists
    merge_prep $1

    notice "Merging revision from trunk: $1"

    if test ! -e ${merge_top}/merge-r$1/merge.log; then
	(cd ${merge_top}/merge-r$1 && git merge --accept postpone -c $1 ${trunk_top} 2>&1 | tee ${merge_top}/merge-r$1/merge.log)
    fi

    notice "Looking for merge conflicts..."
    conflicts="`grep "^C" ${merge_top}/merge-r$1/merge.log | sed -e 's:^C *: :' | tr -d '\n'`"
    notice "Conflicts: ${conflicts}"	
    
    for i in ${conflicts}; do
	notice "Resolving conflict: $i"	
	year="`date +%Y`"
	month="`date +%m`"
	day="`date +%d`"
	
	# If no email address is in ~/.aberc, create one
	if test x"${email}" = x; then
	    email="${LOGNAME}@`hostname`"
	fi
	if test x"${fullname}" = x; then
	    fullname="`grep ^${LOGNAME} /etc/passwd | cut -d ':' -f 5 | sed -e 's:,*::g'`"
	fi
        # reset the list
	problems=""
	
        # Delete the old files
	rm -f ${merge_top}/merge-r$1/problems.txt
	rm -f ${merge_top}/merge-r$1/merge.patch
	# We don't want to edit the ChangeLog, merges go in ChangeLog.linaro.
	# Start by making a new ChangeLog entry for this merge, and append
	# the entry from trunk for the commit, followed by the rest of the
	 # ChangeLog.linaro file.
	if test `echo $i | grep -c ChangeLog` -eq 1; then
	    echo "${year}-${month}-${day}  ${fullname}  <${email}>" > ${merge_top}/merge-r$1/header.patch
	    echo "" >> ${merge_top}/merge-r$1/header.patch
	    # some of these echoes have embedded TABs
	    echo "	Backport from trunk $1" >> ${merge_top}/merge-r$1/header.patch
	    
	    # We can't do a normal patch operation, as it always has problems. So
	    # munge the raw patch to the text equivalent, where we manually add
	    # it to the top of the ChangeLog.linaro file.
	    if test ! -e ${merge_top}/merge-r$1/diff.txt; then
		git diff -c $1 ${trunk_top}/$i 2>&1 > ${merge_top}/merge-r$1/diff.txt
	    fi
	    grep "^\+" ${merge_top}/merge-r$1/diff.txt | sed -e 's:^\+::' | grep -v "revision" 2>&1 > ${merge_top}/merge-r$1/body.patch
	    # So this mess is because if the last commit is by he same person as
	    # the previous one, it puts it at the end of the mergke patch, instead
	    # of under the backport
	    author="`grep -n ".*<.*@.*>" ${merge_top}/merge-r$1/body.patch | cut -d ':' -f 1 | tail -1`"
	    if test x"${author}" = x; then
		author=0
	    fi
	    if test ${author} -gt 1; then
		author="`tail -2 ${merge_top}/merge-r$1/body.patch`"
		lines="`wc -l ${merge_top}/merge-r$1/body.patch | cut -d ' ' -f 1`"
		keep="`expr ${lines} - 2`"
		cat ${merge_top}/merge-r$1/header.patch  > ${merge_top}/merge-r$1/merge.patch
		echo "	${author}" >> ${merge_top}/merge-r$1/merge.patch
		sed -e "${keep},${lines}d" ${merge_top}/merge-r$1/body.patch >> ${merge_top}/merge-r$1/merge.patch
		head -n ${keep} ${merge_top}/merge-r$1/body.patch >> ${merge_top}/merge-r$1/merge.patch
	    else
		cat ${merge_top}/merge-r$1/header.patch  > ${merge_top}/merge-r$1/merge.patch
		echo -n "	"    >> ${merge_top}/merge-r$1/merge.patch
		cat ${merge_top}/merge-r$1/body.patch   >> ${merge_top}/merge-r$1/merge.patch
	    fi
	    mv ${merge_top}/merge-r$1/$i.linaro ${merge_top}/merge-r$1/$i.linaro.orig
	    cat ${merge_top}/merge-r$1/merge.patch > ${merge_top}/merge-r$1/$i.linaro
	    cat ${merge_top}/merge-r$1/$i.linaro.orig >> ${merge_top}/merge-r$1/$i.linaro
	    # cleanup generated files
	    rm -f `find ${merge_top}/merge-r$1 -name \*.merge-right.\* -o -name \*.merge-left.\* -o -name \*.working -o -name \*.rej -o -name \*.orig`
	    rm -f ${merge_top}/merge-r$1/*.patch ${merge_top}/merge-r$1/diff.txt
	    # We can now revert the ChangeLog that was conflicted, as the entry
	    # is in the proper ChangeLong.linaro file.
	    (cd  ${merge_top}/merge-r$1 && git revert $i)
	else
	    problems=" ${problems} $i"
	    echo "${merge_top}/merge-r$1/$i" >> ${merge_top}/merge-r$1/problems.txt
	fi
    done
    
    if test x"${problems}" != x; then
	error "Unresolved conflicts: ${problems}"
    else
	notice "No conflicts left to resolve"
    fi    
}

# $1 - the revision to commit
merge_bzr_commit()
{
    notice "Commiting changes for revision $1"
    (cd ${bzr_top}/merge-r$1 && bzr commit -m "Backport from trunk r$1")

    notice "Pushing changes for revision $1 to lunchpad"
    (cd ${bzr_top}/merge-r$1 && bzr push lp:~${launchpad_id}/gcc-linaro/4.8-merge-$1)
}
    
# $1 - revision in trunk
merge_patch()
{
    echo $1

    git diff -c $1 > $i.patch
}
