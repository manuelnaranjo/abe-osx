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

# $1 - The version number to merge
merge_prep()
{
    echo "FIXME: $1"

    #  svn checkout svn+ssh://${gccsvn_id}@gcc.gnu.org/svn/gcc/branches/linaro/gcc-$1-branch $1-branch

    #  svn checkout svn+ssh://${gccsvn_id}@gcc.gnu.org/svn/gcc/branches/gcc-$1-branch $1-branch

    # bzr branch lp:gcc-linaro/4.8 4.8-2013.06-branch-merge

}

# $1 - revision in trunk
# $2 - branch to get revision from
#
merge_branch()
{
    notice "Merging revision from trunk: $1"

    if test `basename merge-$1` != "merge-$1"; then	
	if test ! -e merge-$1; then
	    notice "Cloning source tree for merge-$1"
	    cp -r 4.8-branch merge-$1
	    cd merge-$1
	fi
    fi

    if test ! -e merge.log; then
	#conflicts="`svn merge --accept postpone -c $1 /linaro/src/gnu/gcc/trunk`"
	svn merge --accept postpone -c $1 /linaro/src/gnu/gcc/trunk 2>&1 | tee merge.log
    fi

    notice "Looking for merge conflicts..."
    #conflicts="`svn status | grep "^C"`"
    conflicts="`grep "^C" merge.log`"
    conflicts="`echo ${conflicts} | cut -d ' ' -f 2`"
    
    if test x"${conflicts}" != x; then
	notice "Conflicts: ${conflicts}"

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
	rm -f merge.patch
	touch merge.patch
	for i in "${conflicts}"; do
	    # We don't want to edit the ChangeLog, merges go in ChangeLog.linaro.
	    # Start by making a new ChangeLog entry for this merge, and append
	    # the entry from trunk for the commit, followed by the rest of the
	    # ChangeLog.linaro file.
	    if test `echo $i | grep -c ChangeLog` -eq 1; then
		echo "${year}-${month}-${day}  ${fullname}  <${email}>" > header.patch
		echo "" >> header.patch
		# some of these echoes have embedded TABs
		echo "	Backport from trunk r$1" >> header.patch

		# We can't do a normal patch operation, as it always has problems. So
		# munge the raw patch to the text equivalent, where we manually add
		# it to the top of the ChangeLog.linaro file.
		if test ! -e diff.txt; then
		    svn diff -c $1 /linaro/src/gnu/gcc/trunk/$i 2>&1 > diff.txt
		fi
		grep "^\+" diff.txt | sed -e 's:^\+::' | grep -v "revision" 2>&1 > body.patch
		# So this mess is because if the last commit is by he same person as
		# the previous one, it puts it at the end of the merge patch, instead
		# of under the backport
		author="`grep -n ".*<.*@.*>" body.patch | cut -d ':' -f 1 | tail -1`"
		if test ${author} -gt 1; then
		    author="`tail -2 body.patch`"
		    lines="`wc -l body.patch | cut -d ' ' -f 1`"
		    keep="`expr ${lines} - 2`"
		    cat header.patch  > merge.patch
		    echo "	${author}" >> merge.patch
		    sed -e "${keep},${lines}d" body.patch >> merge.patch
		    head -n ${keep} body.patch >> merge.patch
		else
		    cat header.patch  > merge.patch
		    echo -n "	"    >> merge.patch
		    cat body.patch   >> merge.patch
		fi
		mv $i.linaro $i.linaro.orig
		cat merge.patch > $i.linaro
		cat $i.linaro.orig >> $i.linaro
		rm -f $i.linaro.orig $i.merge-right.r* $i.merge-left.r* $i.working 
		# We can now revert the ChangeLog that was conflicted, as the entry
		# is in the proper ChangeLong.linaro file.
		svn revert $i
		#rm -f $i.linaro.orig header.patch body.patch diff.txt merge.patch
	    else
		problems=" ${problems} $i"
	    fi
	done
	
	if test x"${problems}" != x; then
	    error "Unresolved conflicts: ${problems}"
	else
	    notice "No conflicts left to resolve"
	fi
    else
	notice "No unresolved conflicts"
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

