#!/bin/sh
# 
#   Copyright (C) 2014,2015 Linaro, Inc
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

# These functions are roughly based on the python script the LAVA team uses. That script
# is available at:
# https://git.linaro.org/lava-team/lava-ci.git/blob_plain/HEAD:/lava-project-ci.py

# https://review.openstack.org/Documentation/cmd-index.html

    # ssh -p 29418 robert.savoye@git.linaro.org gerrit version
    # this uses the git commit SHA-1
    # ssh -p 29418 robert.savoye@git.linaro.org gerrit review --code-review 0 -m "foo" a87c53e83236364fe9bc7d5ffdbf3c307c64707d
    # ssh -p 29418 robert.savoye@git.linaro.org gerrit review --project toolchain/abe --code-review 0 -m "foobar" a87c53e83236364fe9bc7d5ffdbf3c307c64707d
    # ssh -p 29418 robert.savoye@git.linaro.org gerrit query --current-patch-set gcc status:open limit:1 --format JSON

# The number used for code reviews looks like this, it's passed as a string to
# these functions:
#   -2 Do not submit
#   -1 I would prefer that you didn't submit this
#   0 No score
#   +1 Looks good to me, but someone else must approve
#   +2 Looks good to me, approved


# ssh -p 29418 robert.savoye@git.linaro.org gerrit review --project toolchain/abe --code-review "+2" -m "foobar" 55957eaff3d80d854062544dea6fc0eedcbf9247 --submit

    # local revision="@`cd ${srcdir} && git log --oneline | head -1 | cut -d ' ' -f 1`"

# These extract_gerrit_* functions get needed information from a .gitreview file.

# Extract info we need. For a Gerrit triggered build, info is in
# environment variables. Otherwise we scrap a gitreview file for
# the requireed information.
gerrit_info()
{
    trace "$*"

    declare -A gerrit=()

    # Some commonly used Gerrit data we can extract from the gitreview file, if it exists.
    local srcdir=$1 
    gerrit['REVIEW_HOST']="`extract_gerrit_host ${srcdir}`"
    gerrit['REVIEW_HOST']="${REVIEW_HOST:-review.linaro.org}"
    gerrit['PORT']="`extract_gerrit_port ${srcdir}`"
    gerrit['PORT']="${gerrit['PORT']:-29418}"
    gerrit['PROJECT']="`extract_gerrit_project ${srcdir}`"
    gerrit['PROJECT']="${gerrit['PROJECT']:-toolchain/gcc}"
    gerrit['USERNAME']="`extract_gerrit_username ${srcdir}`"
    gerrit['USERNAME']="${gerrit['USERNAME']:-lava-bot}"
    gerrit['SSHKEY']="~/.ssh/${gerrit['USERNAME']}_rsa"

    # These only come from a Gerrit trigger
    gerrit['TOPIC']="${GERRIT_TOPIC:-~linaro-4.9-branch}"
    gerrit['BRANCH']="${GERRIT_BRANCH:-~linaro-4.9-branch}"
    gerrit['REVISION']="${GERRIT_PATCHSET_REVISION}"
    gerrit['CHANGE_SUBJECT']="${GERRIT_CHANGE_SUBJECT}"
    gerrit['CHANGE_ID']="${GERRIT_CHANGE_ID}"
    gerrit['CHANGE_NUMBER']="${GERRIT_CHANGE_NUMBER:-1}"
    gerrit['EVENT_TYPE']="${GERRIT_EVENT_TYPE}"
    gerrit['REFSPEC']="${GERRIT_REFSPEC}"
    gerrit['JOB_NAME']="${JOB_NAME}"
    gerrit['JOB_URL']="${JOB_URL}"

    declare -px gerrit
    return 0
}

extract_gerrit_host()
{
    if test x"${GERRIT_HOST}" != x; then
	local gerrit_host="${GERRIT_HOST}"
    else
	local srcdir=$1
	
	if test -e ${srcdir}/.gitreview; then
	    local review=${srcdir}/.gitreview
	else
	    if test -e ${HOME}/.gitreview; then
		local review=${HOME}/.gitreview
	    else
		warning "No ${srcdir}/.gitreview file!"
		return 1
	    fi
	fi
	
	local gerrit_host="`grep host= ${review} | cut -d '=' -f 2`"
    fi
    
    echo "${gerrit_host}"
    return 0
}

extract_gerrit_project()
{
    if test x"${GERRIT_PROJECT}" != x; then
	local gerrit_project="${GERRIT_PROJECT}"
    else
	local srcdir=$1
	
	if test -e ${srcdir}/.gitreview; then
	    local review=${srcdir}/.gitreview
	else
	    if test -e ${HOME}/.gitreview; then
		local review=${HOME}/.gitreview
	    else
		warning "No ${srcdir}/.gitreview file!"
		return 1
	    fi
	fi
	
	local gerrit_project="`grep "project=" ${review} | cut -d '=' -f 2`"
    fi

    echo "${gerrit_project}"
    return 0
}

extract_gerrit_port()
{
    if test x"${GERRIT_PORT}" != x; then
	local gerrit_port="${GERRIT_PORT}"
    else
	local srcdir=$1
	
	if test -e ${srcdir}/.gitreview; then
	    local review=${srcdir}/.gitreview
	else
	    if test -e ${HOME}/.gitreview; then
		local review=${HOME}/.gitreview
	    else
		warning "No ${srcdir}/.gitreview file!"
		return 1
	    fi
	fi
	
	local gerrit_port="`grep "port=" ${review} | cut -d '=' -f 2`"
    fi

    echo "${gerrit_port}"
    return 0
}

extract_gerrit_username()
{
    local srcdir=$1
    
    if test x"${BUILD_USER_ID}" = x; then
	if test -e ${srcdir}/.gitreview; then
	    local review=${srcdir}/.gitreview
	    gerrit_username="`grep "username=" ${review} | cut -d '=' -f 2`"
	fi
	if test x"${gerrit_username}" = x; then
	    if test -e ${HOME}/.gitreview; then
		local review=${HOME}/.gitreview
		gerrit_username="`grep "username=" ${review} | cut -d '=' -f 2`"
	    else
		warning "No ${srcdir}/.gitreview file!"
	    fi
	fi
#    else
#	gerrit_username="${BUILD_USER_ID}"
    fi
    if test x"${gerrit_username}" = x; then
#	gerrit_username="${GERRIT_CHANGE_OWNER_EMAIL}"
	gerrit_username="lava-bot"
    fi

    if test x"${BUILD_CAUSE}" = x"SCMTRIGGER"; then
	gerrit_username=lava-bot
    fi

    echo ${gerrit_username}
    return 0
}

add_gerrit_comment ()
{
    trace "$*"

    local message="`cat $1`"
    local revision="$2"
    local code="${3:-0}"
    
    # Doc on this command at:
    # https://gerrit-documentation.storage.googleapis.com/Documentation/2.11/cmd-review.html
    ssh -i ~/.ssh/${gerrit['USERNAME']}_rsa -p ${gerrit['PORT']} ${gerrit['USERNAME']}@${gerrit['REVIEW_HOST']} gerrit review --code-review ${code} --message \"${message}\" ${revision}
    if test $? -gt 0; then
	return 1
    fi

    return 0
}

submit_gerrit()
{
    trace "$*"
    
    local message="`cat $1`"
    local code="${2:-0}"
    local revision="${3:-}"
    notice "ssh -p ${gerrit['PORT']} ${gerrit['REVIEW_HOST']} gerrit review --code-review ${code}  --message \"${message}\" --submit ${revision}"

    return 0
}

# $1 - the version of the toolname
# $2 - the build status, 0 success, 1 failure, 2 no regressions, 3 regressions
# $3 - the file of test results, if any
gerrit_build_status()
{
    trace "$*"
    
    local srcdir="`get_srcdir $1`"
    local status="$2"
    local resultsfile="${3:-}"
    local revision="`get_git_revision ${srcdir}`" || return 1
    local msgfile="/tmp/test-results-$$.txt"
    local code="0"

    # Initialize setting for gerrit if not done so already
    if test x"${gerrit['USERNAME']}" = x; then
	gerrit_info ${srcdir}
    fi

    declare -a statusmsg=("Build was Successful" "Build Failed!" "No Test Failures" "Found Test Failures" "No Regressions found" "Found regressions" "Test run completed")

    cat<<EOF > ${msgfile}
Your patch is being reviewed. The build step has completed with a status of: ${statusmsg[${status}]} Build at: ${jenkins_job_url}"

EOF

#http://abe.validation.linaro.org/logs/gcc-linaro-5.0.0/

    add_gerrit_comment ${msgfile} ${revision} ${code}
    if test $? -gt 0; then
	error "Couldn't add Gerrit comment!"
	rm -f  ${msgfile}
	return 1
    fi

    if test x"${resultsfile}" != x; then
	cat ${resultsfile} >> ${msgfile}
    fi

    rm -f  ${msgfile}
    return 0
}

# $1 - the key word to look for
# $2 - The query return string in JSON format to seaarch through
gerrit_extract_keyword()
{
    local keyword="$1"
    local query="$2"

    local answer="`echo ${query} | grep -o ${keyword}\\":\\"[A-Za-z0-9\ ]*\\" | tr -d '\\"' | cut -d ':' -f 2`"

    echo ${answer}
    return 0
}

# $1 the array of records
gerrit_get_record()
{
    local pattern="$1"
    local records="$2"
    local count="${#records[*]}"
    for i in `seq 0 34`; do
	if test `echo ${records[$i]} | grep -c ${pattern}` -gt 0; then
	    echo "${records[$i]}"
	    return 0
	fi
    done
}

# $1 - the toolchain component to query
# $2 - the status to query, default to all open patches
gerrit_query_status()
{
    local tool=$1
    eval "$2"
    local status=${3:-status:open}

#    local username="`echo ${GERRIT_CHANGE_OWNER_EMAIL} | cut -d '@' -f 1`"
    ssh -q -x -p ${gerrit['PORT']} ${gerrit['USERNAME']}@${gerrit['REVIEW_HOST']} gerrit query --current-patch-set ${tool} ${status} --format JSON > /tmp/query$$.txt
    local i=0
    declare -a query=()
    while read line
    do
	local value="${line}"
	query[$i]="${value}"
	i="`expr $i + 1`"
    done < /tmp/query$$.txt
    rm -f /tmp/query$$.txt

    declare -p query
    return 0;
}

gerrit_fetch_patch()
{
    # Without being triggered by Gerrit, environment varibles we use won't exist.
    if test x"${gerrit_trigger}" != xyes; then
	warning "Gerrit support not specified, will try anyway"
    fi

    local srcdir="`get_srcdir gcc.git~${gerrit['BRANCH']}`"

    rm -f /tmp/gerrit$$.patch
    (cd ${srcdir} && git fetch ssh://gerrit['USERNAME']@${gerrit['REVIEW_HOST']}:${gerrit['PORT']}/${gerrit['PROJECT']} ${gerrit['REFSPEC']} && git format-patch -1 --stdout FETCH_HEAD > /tmp/gerrit$$.patch)

#    (cd ${srcdir} && git fetch ssh://lava-bot@${gerrit_host}:29418/${GERRIT_PROJECT} ${GERRIT_REFSPEC} && git format-patch -1 --stdout FETCH_HEAD > /tmp/gerrit$$.patch)

    echo "/tmp/gerrit$$.patch"
    return 0
}

gerrit_apply_patch()
{
    trace "$*"

    # Without being triggered by Gerrit, environment varibles we use won't exist.
    if test x"${gerrit_trigger}" != xyes; then
	warning "Gerrit support not specified, will try anyway"
    fi

    local patch=$1
    local topdir=$2
    if test -f ${patch} -a -d ${topdir}; then
	patch --directory=${topdir} --strip 2--forward --input=${patch} --reverse
    else
	return 1
    fi

    return 0
}

# This function cherry picks a patch from Gerrit, and applies it to the current branch.
# it requires the array from returned from gerrit_query_patchset().
# $1 - The Change_ID from Gerrit for this patch
gerrit_cherry_pick()
{
    trace "$*"

    # Without being triggered by Gerrit, environment varibles we use won't exist.
    if test x"${gerrit_trigger}" != xyes; then
	warning "Gerrit support not specified, will try anyway"
    fi

    local refspec=${gerrit['REFSPEC']:+$1}

    checkout "`get_URL gcc.git@${records['parents']}`"

    local srcdir="${local_snapshots}/gcc.git@${records['parents']}"
    local destdir=${local_snapshots}/gcc.git@${records['revision']}
    mkdir -p ${destdir}
    cp -rdnp ${srcdir}/* ${srcdir}/.git ${destdir}/

    # This cherry picks the commit into the copy of the parent branch. In the parent branch
    # we're already in a local branch.
    (cd ${destdir} && git fetch ssh://${gerrit['USERNAME']}@${gerrit['REVIEW_HOST']}:${gerrit['PORT']}/${gerrit['PROJECT']} ${refspec} && git cherry-pick FETCH_HEAD)

    (cd ${srcdir} && git reset HEAD^)
    (cd ${srcdir} && git co master)
    (cd ${srcdir} && git branch -d local_@${records['parents']})

    return $?
}

# Example query message result:
#
# declare -A records='([currentPatchSet]=" 1" [sizeInsertions]=" 779" [value]=" 2"
# [url]=" https://review.linaro.org/5282" [number]=" 5282" [ref]=" refs/changes/82/5282/1" [branch]=" linaro-4.9-branch" [commitMessage]=" Backport r219656, r219657, r219659, r219661, and r219679 from trunk." [status]=" NEW" [Change-Id]=" I39b6f9298b792755db08cb609a1a446b5e83603b" [revision]=" 6a645e59867c728c4b3bb897488faa00505725c4" [username]=" christophe.lyon" [email]=" christophe.lyon@linaro.org" [subject]=" Backport r219656, r219657, r219659, r219661, and r219679 from trunk." [isDraft]=" false" ["change I39b6f9298b792755db08cb609a1a446b5e83603b"]="change I39b6f9298b792755db08cb609a1a446b5e83603b" [approvals]=" Code-Review" [author]=" Michael Collison" [runTimeMilliseconds]=" 8" [project]=" toolchain/gcc" [sortKey]=" 00341e22000014a2" [description]=" Code-Review" [uploader]=" Michael Collison" [id]=" I39b6f9298b792755db08cb609a1a446b5e83603b" [sizeDeletions]=" -6" [parents]="2c4f089828371d3f89c5c8505e4450c629f4ca5b" [createdOn]=" 2015-03-30 01:39:17 UTC" [lastUpdated]=" 2015-03-30 22:26:37 UTC" [topic]=" Michael-4.9-backport-219656-219657-219659-219661-219679" [grantedOn]=" 2015-03-30 09:04:37 UTC" [type]=" stats" [open]=" true" [rowCount]=" 1" [owner]=" Michael Collison" [by]=" Christophe Lyon" )'

# GERRIT_BRANCH	linaro-4.9-branch
# GERRIT_CHANGE_ID	I39b6f9298b792755db08cb609a1a446b5e83603b
# GERRIT_TOPIC	Michael-4.9-backport-219656-219657-219659-219661-219679
gerrit_query_patchset()
{
    trace "$*"

    # Without being triggered by Gerrit, environment varibles we use wont exist.
    if test x"${gerrit['CHANGE_ID']}" = x; then 
	warning "Gerrit support not specified, will try anyway, but wont return correct results"
    fi

    local changeid="$1"

    # get the data for this patchset from Gerrit using the REST API
    rm -f /tmp/query$$.txt
    # sudo ssh -i ~buildslave/.ssh/lava-bot_rsa -x -p 29418 lava-bot@review.linaro.org gerrit query --current-patch-set gcc status:open --format JSON
    ssh -i ~/.ssh/${gerrit['USERNAME']}_rsa -q -x -p ${gerrit['PORT']} ${gerrit['USERNAME']}@${gerrit['REVIEW_HOST']} gerrit query --format=text ${changeid} --current-patch-set > /tmp/query$$.txt
    declare -A records=()
    while read line
    do
	local key="`echo ${line} | tr -d '}{' | cut -d ':' -f 1`"
	if test x"${key}" = x; then
	    continue
	fi
	local value="`echo ${line} | tr -d '][ ' | cut -d ':' -f 2-10`"
	if test x"${value}" = x; then
	    read line
	    local value="`echo ${line} | tr -d '][ ' | cut -d ':' -f 2-10`"
	fi
	records[${key}]="${value}"
    done < /tmp/query$$.txt
    rm -f /tmp/query$$.txt

    declare -px records
    return 0
}
