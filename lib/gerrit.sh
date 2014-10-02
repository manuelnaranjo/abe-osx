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

add_gerrit_comment ()
{
    local manifest=$1
    local revision="`grep 'gcc_revision=' ${manifest} | cut -d '=' -f 2`"

    ssh review.linaro.org gerrit review --code-review %s -m "\"%s"\" %s' % (gerrit_server, review, message, ${revision})'

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
