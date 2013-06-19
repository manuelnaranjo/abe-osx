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
merge_branches()
{
    notice "Merging revision from trunk: $1"

#    cp -r 4.8-branch merge-$1

    if test ! -e merge.patch; then
	conflicts="`svn merge --accept postpone -c $1 /linaro/src/gnu/gcc/trunk`"
    else
	notice "Looking for merge conflicts..."
	conflicts="`svn status | grep "^C"`"
	conflicts="`echo ${conflicts} | cut -d ' ' -f 2`"
    fi

    if test x"${conflicts}" != x; then
	notice "Conflicts: ${conflicts}"

	year="`date +%Y`"
	month="`date +%m`"
	day="`date +%d`"

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
		echo "${year}-${month}-${day}  ${fullname}  <${email}>" > merge.patch
		echo "" >> merge.patch
		echo "	Backport from trunk r$1" >> merge.patch
		echo -n "	" >> merge.patch
		svn diff -c $1 /linaro/src/gnu/gcc/trunk/$i 2>&1 | grep "^\+" | sed -e 's:^\+::' | grep -v "revision" >> merge.patch
		rm -f $i.linaro.orig
		mv $i.linaro $i.linaro.orig
		cat merge.patch > $i.linaro
		cat $i.linaro.orig >> $i.linaro
		rm -f $i.linaro.orig $i.merge-right.r* $i.merge-left.r* $i.working 
		# We can now revert the ChangeLog that was conflicted, as the entry
		# is in the proper ChangeLong.linaro file.
		svn revert $i
	    else
		problems=" ${problems} $i"
	    fi
	done
	
	if test x"${problems}" != x; then
	    error "Unresolved conflicts: ${problems}"
	fi
    fi
    
}

# $1 - revision in trunk
merge_patch()
{
    echo $1

    svn diff -c $1 > $i.patch
}

