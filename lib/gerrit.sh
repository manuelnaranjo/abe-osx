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

    local srcdir=$1
    extract_gerrit_host ${srcdir}
    extract_gerrit_port ${srcdir}
    extract_gerrit_project ${srcdir}
    extract_gerrit_username ${srcdir}

    # These only come from Gerrit triggers
    gerrit_branch="${GERRIT_TOPIC}"
    gerrit_revision="${GERRIT_PATCHSET_REVISION}"
    gerrit_change_subject="${GERRIT_CHANGE_SUBJECT}"
    gerrit_change_id="${GERRIT_CHANGE_ID}"
    gerrit_change_number="${GERRIT_CHANGE_NUMBER}"
    gerrit_event_type="${GERRIT_EVENT_TYPE}"
    jenkins_job_name="${JOB_NAME}"
    jenkins_job_url="${JOB_URL}"

    # Query the Gerrit server
    gerrit_query gcc
}

extract_gerrit_host()
{
    if test x"${GERRIT_HOST}" != x; then
	gerrit_host="${GERRIT_HOST}"
    else
	local srcdir=$1
	
	if test -e ${srcdir}/.gitreview; then
	    local review=${srcdir}/.gitreview
	else
	    if test -e ${HOME}/.gitreview; then
		local review=${HOME}/.gitreview
	    else
		Error "No ${srcdir}/.gitreview file!"
		return 1
	    fi
	fi
	
	gerrit_host="`grep host= ${review} | cut -d '=' -f 2`"
    fi
    
    return 0
}

extract_gerrit_project()
{
    if test x"${GERRIT_PROJECT}" != x; then
	gerrit_project="${GERRIT_PROJECT}"
    else
	local srcdir=$1
	
	if test -e ${srcdir}/.gitreview; then
	    local review=${srcdir}/.gitreview
	else
	    if test -e ${HOME}/.gitreview; then
		local review=${HOME}/.gitreview
	    else
		error "No ${srcdir}/.gitreview file!"
		return 1
	    fi
	fi
	
	gerrit_project="`grep "project=" ${review} | cut -d '=' -f 2`"
    fi

    return 0
}

extract_gerrit_port()
{
    if test x"${GERRIT_PORT}" != x; then
	gerrit_port="${GERRIT_PORT}"
    else
	local srcdir=$1
	
	if test -e ${srcdir}/.gitreview; then
	    local review=${srcdir}/.gitreview
	else
	    if test -e ${HOME}/.gitreview; then
		local review=${HOME}/.gitreview
	    else
		error "No ${srcdir}/.gitreview file!"
		return 1
	    fi
	fi
	
	gerrit_port="`grep "port=" ${review} | cut -d '=' -f 2`"
    fi

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
    if test x"${gerrit_username}" != x; then
	gerrit_username="${GERRIT_CHANGE_OWNER_EMAIL}"
    fi

    gerrit_branch="${GERRIT_TOPIC}"
    gerrit_revision="${GERRIT_PATCHSET_REVISION}"

}

add_gerrit_comment ()
{
    trace "$*"

    local message="`cat $1`"
    local revision="$2"
    local code="${3:-0}"

#    ssh -p ${gerrit_port} ${gerrit_username}@${gerrit_host} gerrit review --code-review ${code} --message \"${message}\" ${revision}
    ssh -p 29418 lava-bot@${gerrit_host} gerrit review --code-review ${code} --message \"${message}\" ${revision}
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
    notice "ssh -p ${gerrit_port} ${gerrit_host} gerrit review --code-review ${code}  --message \"${message}\" --submit ${revision}"

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
    local revision="`get_git_revision ${srcdir}`"
    local msgfile="/tmp/test-results-$$.txt"
    local code="0"

    # Initialize setting for gerrit if not done so already
    if test x"${gerrit_username}" = x; then
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
gerrit_query()
{
    local tool=$1
    local status=${2:-status:open}

    # ssh -p 29418 robert.savoye@git.linaro.org gerrit query --current-patch-set ${tool} status:open limit:1 --format JSON
    gerrit_username="`echo ${GERRIT_CHANGE_OWNER_EMAIL} | cut -d '@' -f 1`"
    ssh -q -x -p ${gerrit_port} lava-bot@${gerrit_host} gerrit query --current-patch-set ${tool} ${status} --format JSON > /tmp/query$$.txt
#    ssh -q -x -p ${gerrit_port} ${gerrit_username}@${gerrit_host} gerrit query --current-patch-set ${tool} ${status} --format JSON > /tmp/query$$.txt
    local i=0
    declare -a records
    while read line
    do
	records[$i]="echo ${line} | tr -d '\n'"
	local i=`expr $i + 1`
    done < /tmp/query$$.txt
    rm -f /tmp/query$$.txt

    local record="`gerrit_get_record 73e60b77b497f699d8a2a818e2ecaa7ca57e5d1d "${records}"`"

    local revision="`gerrit_extract_keyword "revision" "${records[33]}"`"

    return 0;
}

gerrit_fetch_patch()
{
    # FIXME: These three variables are here only for debugging. They're supplied by Gerrit
    GERRIT_PROJECT=toolchain/gcc
    GERRIT_REFSPEC=refs/changes/82/5282/1
    GERRIT_TOPIC=Michael-4.9-backport-219656-219657-219659-219661-219679
#    local srcdir="`get_srcdir ${gcc_version}`"
    local srcdir="`get_srcdir gcc.git~linaro-4.9-branch`"
#    local srcdir="`get_srcdir gcc.git~${GERRIT_TOPIC}`"

    rm -f /tmp/gerrit$$.patch
    (cd ${srcdir} && git fetch ssh://robert.savoye@${gerrit_host}:29418/${GERRIT_PROJECT} ${GERRIT_REFSPEC} && git format-patch -1 --stdout FETCH_HEAD > /tmp/gerrit$$.patch)
}

gerrit_apply_patch()
{
    local patch=$1
    local topdir=$2

    patch --directory=${topdir} --strip 2--forward --input=${patch} --reverse
}

# This function cherry picks a patch from Gerrit, and applies it to the current branch.
# it requires the array from returned from gerrit_query_patchset().
gerrit_cherry_pick()
{
    trace "$*"

    eval "$1"

    # FIXME: These four variables are here only for debugging. They're supplied by Gerrit
#    GERRIT_TOPIC=Michael-4.9-backport-219656-219657-219659-219661-219679
#    GERRIT_CHANGE_ID="I39b6f9298b792755db08cb609a1a446b5e83603b"

    GERRIT_PROJECT=${records['project']}
    GERRIT_REFSPEC=${records['ref']}
    local srcdir="`get_srcdir gcc.git@${records['parents']}`"
#    local srcdir="`get_srcdir gcc.git`"
    checkout "`get_URL gcc.git@${records['parents']}`"

    (cd ${srcdir} && git fetch ssh://lava-bot@${gerrit_host}:29418/${GERRIT_PROJECT} ${GERRIT_REFSPEC} && git cherry-pick FETCH_HEAD)
}

# Example query message result:
#
# declare -A records='([currentPatchSet]=" 1" [sizeInsertions]=" 779" [value]=" 2"
# [url]=" https://review.linaro.org/5282" [number]=" 5282" [ref]=" refs/changes/82/5282/1" [branch]=" linaro-4.9-branch" [commitMessage]=" Backport r219656, r219657, r219659, r219661, and r219679 from trunk." [status]=" NEW" [Change-Id]=" I39b6f9298b792755db08cb609a1a446b5e83603b" [revision]=" 6a645e59867c728c4b3bb897488faa00505725c4" [username]=" christophe.lyon" [email]=" christophe.lyon@linaro.org" [subject]=" Backport r219656, r219657, r219659, r219661, and r219679 from trunk." [isDraft]=" false" ["change I39b6f9298b792755db08cb609a1a446b5e83603b"]="change I39b6f9298b792755db08cb609a1a446b5e83603b" [approvals]=" Code-Review" [author]=" Michael Collison" [runTimeMilliseconds]=" 8" [project]=" toolchain/gcc" [sortKey]=" 00341e22000014a2" [description]=" Code-Review" [uploader]=" Michael Collison" [id]=" I39b6f9298b792755db08cb609a1a446b5e83603b" [sizeDeletions]=" -6" [parents]="2c4f089828371d3f89c5c8505e4450c629f4ca5b" [createdOn]=" 2015-03-30 01:39:17 UTC" [lastUpdated]=" 2015-03-30 22:26:37 UTC" [topic]=" Michael-4.9-backport-219656-219657-219659-219661-219679" [grantedOn]=" 2015-03-30 09:04:37 UTC" [type]=" stats" [open]=" true" [rowCount]=" 1" [owner]=" Michael Collison" [by]=" Christophe Lyon" )'
gerrit_query_patchset()
{
    trace "$*"
    local changeid=${GERRIT_CHANGE_ID:-$1}

    # The the data for this patchset from Gerrit
    ssh -q -x -p ${gerrit_port} -i ~/.ssh/lava-bot_rsa lava-bot@${gerrit_host} gerrit query --format=text ${changeid} --current-patch-set > /tmp/query$$.txt
    declare -A records
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

    declare -ptu records
    return 0
}
