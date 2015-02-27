#!/bin/bash
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

# To run, this script takes arguments in the same format as abe.sh. The two
# arguments it needs are the target architecture to build, and the gcc backport
# branch name. Example:
# $PATH/test-backport.sh --target arm-linux-gnueabihf gcc.git~4.9-backport-209419
usage()
{
    # Format this section with 75 columns.
    cat << EOF
  test-backport.sh [--help] [f|--fileserver remote file server] --target triplet branch
EOF
    exit 0
}

# Improve debug logs
PRGNAME=`basename $0`
PS4='+ $PRGNAME: ${FUNCNAME+"$FUNCNAME : "}$LINENO: '

if test $# -lt 2; then
    echo "ERROR: No branch to build!"
    usage
    exit 1
fi

# load commonly used functions
if test -e "${PWD}/host.conf"; then
    . "${PWD}/host.conf"
else
    echo "Error: this script needs to be run from a configured Abe tree!" 1>&2
    exit 1
fi
abe="`which $0`"
abe_path="`dirname ${abe}`"
topdir="${abe_path}"
abe="`basename $0`"
node="`hostname | cut -d '.' -f 1`"

basedir="/work/logs"
repo="gcc.git"
fileserver="abe.tcwglab.linaro.org"
branch=""

OPTS="`getopt -o s:r:f:w:o:t:g:h -l target:,fileserver:,help,snapshots:,repo:,workspace:,options -- "$@"`"
while test $# -gt 0; do
    case $1 in
        -s|--snapshots) local_snapshots=$2 ;;
        -f|--fileserver) fileserver=$2 ;;
	-r|--repo) repo=$2 ;;
        -w|--workspace) user_workspace=$2 ;;
        -o|--options) user_options=$2 ;;
	-t|--target) target=$2 ;;
        -h|--help) usage ;;
	*) branch=$1;;
	--) break ;;
    esac
    shift
done

if test "`echo ${branch} | grep -c gcc.git`" -gt 0; then
    branch="`echo ${branch} | sed -e 's:gcc.git~::'`"
fi

if test x"${git_reference_dir}" != x; then
    srcdir="${git_reference_dir}/${branch}"
else
    git_reference_dir="${local_snapshots}"
    srcdir="${local_snapshots}/gcc.git~${branch}"
fi

# Due to update cycles, sometimes the branch isn't in the repository yet.
exists="`cd ${git_reference_dir}/${repo} && git branch -a | grep -c "${branch}"`"
if test "${exists}" -eq 0; then
    pushd ${git_reference_dir}/${repo} && git fetch
    popd
fi

rm -fr ${srcdir}
git-new-workdir ${git_reference_dir}/${repo} ${srcdir} ${branch} || exit 1
# Make sure we are at the top of ${branch}
pushd ${srcdir}
# If in 'detached HEAD' state, don't try to update to the top of the branch
detached=`git branch | grep detached`
if test x"${detached}" = x; then
    git rebase || exit 1
fi
popd

# Get the last two revisions
declare -a revisions=(`cd ${srcdir} && git log -n 2 | grep ^commit | cut -d ' ' -f 2`)

# Force GCC to not build the docs
export BUILD_INFO=""

# Don't try to add comments to Gerrit if run manually
if test x"${GERRIT_PATCHSET_REVISION}" != x; then
    gerrit="--enable gerrit"
else
    gerrit=""
fi

# Checkout all the sources
#bash -x ${topdir}/abe.sh --checkout all

resultsdir="/tmp/${node}/abe$$/${target}@"
files="`find ${local_builds}/${build}/${target}/ -maxdepth 1 -type d | egrep 'stage2|binutils'`"

i=0
while test $i -lt ${#revisions[@]}; do
    job="Backport"
    dir="${basedir}/gcc-linaro/${branch}/${job}${BUILD_NUMBER}/${build}.${target}/${revisions[$i]}"

    # Don't build if a previous build of this revision exists
    exists="`ssh ${fileserver} "if test -d ${dir}; then echo YES; else echo NO; fi"`"
    if test x"${exists}" = x"YES"; then
	echo "${dir} already exists"
	i="`expr $i + 1`"
	continue
    fi

    bash ${topdir}/abe.sh ${gerrit} --disable update --check --target ${target} gcc=gcc.git@${revisions[$i]} --build all --disable make_docs
    if test $? -gt 0; then
	echo "ERROR: Abe failed!"
	exit 1
   fi

    # FIXME: The way this is currently implemented only handles GCC backports. If binutils
    # backports are desired, this will have to be implented here.
    sums="`find ${local_builds}/${build}/${target}/binutils-* -name \*.sum -o -name \*.sum.xz`"
    sums="${sums} `find ${local_builds}/${build}/${target}/gcc.git@${revisions[$i]}-stage2 -name \*.sum -o -name \*.sum.xz`"
    # Copy only the log files we want
    logs="`find ${local_builds}/${build}/${target}/binutils-* -name \*.log -o -name \*.log.xz | egrep -v 'config.log|check-.*.log|install.log'`"
    logs="${logs} `find ${local_builds}/${build}/${target}/gcc.git@${revisions[$i]}-stage2 -name \*.log -o -name \*.log.xz | egrep -v 'config.log|check-.*.log|install.log'`"
    
    manifest="`find ${local_builds}/${build}/${target} -name manifest.txt`"

    #	xz ${resultsdir}${revisions[$i]}/*.sum ${resultsdir}${revisions[$i]}/*.log
    echo "Copying test results files to ${fileserver}:${dir}/ which will take some time..."
    ssh ${fileserver} mkdir -p ${dir}
    scp -C ${manifest} ${sums} ${logs} ${fileserver}:${dir}/
    #	rm -fr ${resultsdir}${revisions[$i]}

    i="`expr $i + 1`"
done

ret=0

# Test results and logs have been copied to this fileserver, so the validation is
# done remotely.
if test x"${fileserver}" != x; then
    # Diff the two directories
    tmp="/tmp/${node}/abe$$"
    ssh ${fileserver} mkdir -p ${tmp}
    scp -r ${topdir}/scripts/report.sh ${fileserver}:${tmp}
    toplevel="`dirname ${dir}`"
    dir1="${toplevel}/${revisions[0]}"
    dir2="${toplevel}/${revisions[1]}"
    for i in gcc g++ gfortran libstdc++ ld gas binutils libgomp libitm; do
	out="`ssh ${fileserver} ${tmp}/report.sh ${toplevel} ${i}.sum`"
	echo "${out}"
	if test $? -gt 0; then
	    ret=1
	fi
    done
    rm -fr ${tmp}
fi

exit ${ret}
