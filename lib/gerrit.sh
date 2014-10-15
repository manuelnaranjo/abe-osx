#!/bin/sh
# 
#   Copyright (C) 2014 Linaro, Inc
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
    # ssh -p 29418 robert.savoye@git.linaro.org gerrit review --project toolchain/cbuild2 --code-review 0 -m "foobar" a87c53e83236364fe9bc7d5ffdbf3c307c64707d
    # --code-review N            : score for Code-Review
    #                           -2 Do not submit
    #                           -1 I would prefer that you didn't submit this
    #                            0 No score
    #                           +1 Looks good to me, but someone else must approve
    #                           +2 Looks good to me, approved
    # ssh -p 29418 robert.savoye@git.linaro.org gerrit review --project toolchain/cbuild2 --code-review "+2" -m "foobar" 55957eaff3d80d854062544dea6fc0eedcbf9247 --submit

    # local revision="@`cd ${srcdir} && git log --oneline | head -1 | cut -d ' ' -f 1`"

# These extract_gerrit_* functions get needed information from a .gitreview file.
extract_gerrit_host()
{
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
    
    gerrit_host="`grep host= ${review} | cut -d '=' -f 2`"
    echo ${gerrit_host}
}

extract_gerrit_project()
{
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
    echo ${gerrit_project}
}

extract_gerrit_username()
{
    local srcdir=$1
    if test -e ${srcdir}/.gitreview; then
	local review=${srcdir}/.gitreview
	gerrit_username="`grep "username=" ${review} | cut -d '=' -f 2`"
    fi
    if test x"${gerrit_username}" = x; then
	if test -e ${HOME}/.gitreview; then
	    local review=${HOME}/.gitreview
	    gerrit_username="`grep "username=" ${review} | cut -d '=' -f 2`"
	else
	    error "No ${srcdir}/.gitreview file!"
	    return 1
	fi
    fi
    
    echo ${gerrit_username}
}

extract_gerrit_port()
{
    local srcdir=$1
    if test -e ${srcdir}/.gitreview; then
	local review=${srcdir}/.gitreview
	gerrit_port="`grep "port=" ${review} | cut -d '=' -f 2`"
    fi
    if test x"${gerrit_port}" = x; then
	if test -e ${HOME}/.gitreview; then
	    local review=${HOME}/.gitreview
	    gerrit_port="`grep "port=" ${review} | cut -d '=' -f 2`"
	else
	    error "No ${srcdir}/.gitreview file!"
	    return 1
	fi
    fi
    
    echo ${gerrit_port}
}

add_gerrit_comment ()
{
    local revision=$1
    ssh -p 29418 review.linaro.org gerrit review --code-review 0 --message "\"%s"\" %s' % (message, ${revision})'

}

notify_committer ()
{
    local manifest=$1

    # The email address of the requester is only added by Jenkins, so this will fail
    # for a manual build.
    local userid="`grep 'email=' ${manifest} | cut -d '=' -f 2`"
    local revision="`grep 'gcc_revision=' ${manifest} | cut -d '=' -f 2`"

    cat <<EOF > /tmp/notify$.txt
Hello ${userid})
Your patch set ${revision} has triggered automated testing.'
Please do not merge this commit until after I have reviewed the results with you.'
EOF

    add_gerrit_comment /tmp/notify$.txt
}

publish_results ()
{
    local manifest=$1
    local build_url="`grep 'build_url=' ${manifest} | cut -d '=' -f 2`"

#    test_results = os.environ['BUILD_URL'] + 'console'
#    result_message_list.append('* TEST RESULTS: %s' % test_results)
#    result_message = '\n'.join(result_message_list)
#    if result is None:
#        add_gerrit_comment(result_message, 0)
#    elif result:
#        add_gerrit_comment(result_message, +1)
#    else:
#        add_gerrit_comment(result_message, -1)
}
