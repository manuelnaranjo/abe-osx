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
  test-backport.sh [--help]
        [-f| --fileserver     [remote file server]
        [-t] --target triplet [config triplet]
        [-s] --snapshots      [path to snapshots directory]
	[-r] --revisions      [revision1,revision2]
        [-g] --gitref         [git reference directory]
	[-b] --branch         [GCC git branch]
        [-w] --workspace [alternate workspace]

For example:

test-backport.sh --fileserver fileserver.linaro.org --target arm-none-eabi --gitref /linaro/shared/snapshots --snapshots ~/workspace/snapshots --branch gcc.git~linaro-4.9-branch

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
which_dir="`which $0`"
topdir="`dirname ${which_dir}`"
. "${topdir}/lib/common.sh" || exit 1

# since host.conf isn't loaded, get the build architecture
build="`${topdir}/config.guess`"

# Configure Abe itself. Force the use of bash instead of the Ubuntu
# default of dash as some configure scripts go into an infinite loop with
# dash. Not good...
# In addition, we may have overridden CONFIG_SHELL to use a schroot
# before, and need to reset it now that we are in the schroot.
export CONFIG_SHELL="/bin/bash"
if test x"${debug}" = x"true"; then
    export CONFIG_SHELL="/bin/bash -x"
fi

if test x"${abe_dir}" = x; then
    abe_dir=${topdir}
fi

# Non matrix builds use node_selector, but matrix builds use NODE_NAME
if test x"${node_selector}" != x; then
    node="`echo ${node_selector} | tr '-' '_'`"
    job=${JOB_NAME}
else
    node="`echo ${NODE_NAME} | tr '-' '_'`"
    job="`echo ${JOB_NAME}  | cut -d '/' -f 1`"
fi

basedir="/work/logs"
repo="gcc.git"
fileserver="abe.tcwglab.linaro.org"
branch="linaro-4.9-branch"
user_workspace=${WORKSPACE:-${HOME}/workspace/TestBackport}
user_snapshots="${user_workspace}/snapshots"
snapshots_ref="${user_snapshots}"
revision_str=""
user_options=""

# These are needed by the functions in the ABE library.
local_snapshots=${user_snapshots}
sources_conf=${topdir}/config/sources.conf
NEWWORKDIR=/usr/local/bin/git-new-workdir

OPTS="`getopt -o s:r:f:w:o:t:b:g:c:h -l target:,fileserver:,help,snapshots:,branch:,gitref:,repo:,workspace:,revisions:,options,check -- "$@"`"
while test $# -gt 0; do
    case $1 in
        -s|--snapshots) user_snapshots=$2; shift ;;
        -f|--fileserver) fileserver=$2; shift ;;
	-r|--revisions) revision_str=$2; shift ;;
        -g|--gitref) git_reference_dir=$2; shift ;;
	-b|--branch) branch=$2; shift ;;
        -w|--workspace) user_workspace=$2; shift ;;
        -o|--options) user_options=$2; shift ;;
	-t|--target) target=$2; shift ;;
	-c|--check) check=$2; shift ;;
        -h|--help) usage ;;
	*) ;;
	--) break ;;
    esac
    shift
done

# If triggered by Gerrit, use the REST API. This assumes the lava-bot account
# is supported by Gerrit, and the public SSH key is available. 
if test x"${GERRIT_CHANGE_ID}" != x; then
    eval `gerrit_info $HOME`
    gerrit_trigger=yes
    #gerrit_query_status gcc
    
    eval "`gerrit_query_patchset ${GERRIT_CHANGE_ID}`"

    # Check out the revision made before this patch gets merged in
    checkout "`get_URL gcc.git@${records['parents']}`"

    gerrit_cherry_pick ${gerrit['REFSPEC']}
else
    gerrit_trigger=no
fi

echo "NOTE: No builds currently done in this branch, its for testing only!"

# The two revisions are specified on the command line
if test x"${revision_str}" != x; then
    GIT_COMMIT="`echo ${revision_str} | cut -d ',' -f 1`"
    GIT_PREVIOUS_COMMIT="`echo ${revision_str} | cut -d ',' -f 2`"
fi

if test x"${target}" != x"native" -a x"${target}" != x; then
    platform="--target ${target}"
    targetname=${target}
    check="--check ${check:-all}"
else
    # For native builds, we need to know the effective target name to
    # be able to find the results
    targetname=${build}
    # For native builds, we don't check gdb because it is too slow
    check="--check all --excludecheck gdb"
fi

if test "`echo ${branch} | grep -c gcc.git`" -gt 0; then
    branch="`echo ${branch} | sed -e 's:gcc.git~::'`"
fi

if test x"${git_reference_dir}" != x; then
    srcdir="${git_reference_dir}/${branch}"
    snapshots_ref="${git_reference_dir}"
else
    git_reference_dir="${user_snapshots}"
    snapshots_ref="${user_snapshots}"
    srcdir="${user_snapshots}/gcc.git~${branch}"
fi

# Create a build directory
if test -d ${user_workspace}/_build; then
    rm -fr ${user_workspace}/_build
fi
mkdir -p ${user_workspace}/_build
local_builds="${user_workspace}/_build/builds/${build}/${targetname}"

# Use the newly created build directory
pushd ${user_workspace}/_build

$CONFIG_SHELL ${abe_dir}/configure --enable-schroot-test --with-local-snapshots=${user_snapshots} --with-git-reference-dir=${snapshots_ref}

# If Gerrit is specifing the two git revisions, don't try to extract them.
if test x"${gerrit_trigger}" != xyes; then
    if test ! -d ${snapshots_ref}/gcc.git; then
	git clone http://git.linaro.org/git/toolchain/gcc.git ${snapshots_ref}/gcc.git
    fi
    
    # Due to update cycles, sometimes the branch isn't in the repository yet.
    exists="`cd ${git_reference_dir}/${repo} && git branch -a | grep -c "${branch}"`"
    if test "${exists}" -eq 0; then
	pushd ${git_reference_dir}/${repo} && git fetch
	popd
    fi
    
    # rm -fr ${srcdir}
    if test ! -e  ${srcdir}; then
	git-new-workdir ${git_reference_dir}/${repo} ${srcdir} ${branch} || exit 1
	# Make sure we are at the top of ${branch}
	pushd ${srcdir}
	# If in 'detached HEAD' state, don't try to update to the top of the branch
	detached=`git branch | grep detached`
	if test x"${detached}" = x; then
	    git checkout -B ${branch} origin/${branch} || exit 1
	fi
	popd
    fi

    # Get the last two revisions
    declare -a revisions=(`cd ${srcdir} && git log -n 2 | grep ^commit | cut -d ' ' -f 2`)
    update="--disable update"
else
    update="--disable update"
    echo "FIXME: ${records['parents']}"
    echo "FIXME: ${records['revision']}"
    declare -a revisions=(${records['parents']} ${records['revision']})
fi
# Force GCC to not build the docs
export BUILD_INFO=""

# Don't try to add comments to Gerrit if run manually
if test x"${gerrit_trigger}" != x; then
    gerritopt="--enable gerrit"
else
    gerritopt=""
fi

resultsdir="/tmp/${node}/abe$$/${target}@"

i=0
while test $i -lt ${#revisions[@]}; do
    # Don't build if a previous build of this revision exists
    dir="${basedir}/gcc-linaro/${branch}/${job}${BUILD_NUMBER}/${build}.${target}/${revisions[$i]}"
    exists="`ssh ${fileserver} "if test -d ${dir}; then echo YES; else echo NO; fi"`"
    if test x"${exists}" = x"YES"; then
	echo "${dir} already exists"
	i="`expr $i + 1`"
	continue
    fi

    bash -x ${topdir}/abe.sh ${gerrit_opt} ${update} ${platform} gcc=gcc.git@${revisions[$i]} --build all --disable make_docs ${check} ${user_options}
    if test $? -gt 0; then
	echo "ERROR: Abe failed!"
	exit 1
    fi

    # Don't update any sources for the other revision.
    if test x"${update}" = x; then
	update="--disable update"
    fi

    # Compress .sum and .log files
    sums="`find ${local_builds} -name \*.sum`"
    logs="`find ${local_builds} -name \*.log | egrep -v 'config.log|check-.*.log|install.log'`"
    xz ${sums} ${logs}

    # FIXME: The way this is currently implemented only handles GCC backports. If binutils
    # backports are desired, this will have to be implented here.
    sums="`find ${local_builds}/binutils-* -name \*.sum.xz`"
    sums="${sums} `find ${local_builds}/gcc.git@${revisions[$i]}-stage2 -name \*.sum.xz`"
    # Copy only the log files we want
    logs="`find ${local_builds}/binutils-* -name \*.log.xz | egrep -v 'config.log|check-.*.log|install.log'`"
    logs="${logs} `find ${local_builds}/gcc.git@${revisions[$i]}-stage2 -name \*.log.xz | egrep -v 'config.log|check-.*.log|install.log'`"

    manifest="`find ${local_builds} -name gcc.git@${revisions[$i]}\*manifest.txt`"

    #	xz ${resultsdir}${revisions[$i]}/*.sum ${resultsdir}${revisions[$i]}/*.log
    echo "Copying test results files to ${fileserver}:${dir}/ which will take some time..."
    ssh ${fileserver} mkdir -p ${dir}
    scp -C ${manifest} ${sums} ${logs} ${fileserver}:${dir}/
    # rm -fr ${resultsdir}${revisions[$i]}

    i="`expr $i + 1`"
done

ret=0

# Test results and logs have been copied to this fileserver, so the validation is
# done remotely.
if test x"${fileserver}" != x; then
    # Diff the two directories
    tmp="/tmp/${node}/abe$$"
    ssh ${fileserver} mkdir -p ${tmp}
    # report.sh does not support .sum.xz for the moment
    #scp -r ${topdir}/scripts/report.sh ${fileserver}:${tmp}
    # For comparison with the perl script:
    scp ${topdir}/scripts/compare_tests ${fileserver}:${tmp}
    scp ${topdir}/scripts/compare_dg_tests.pl ${fileserver}:${tmp}
    scp ${topdir}/scripts/unstable-tests.txt ${fileserver}:${tmp}
    toplevel="`dirname ${dir}`"
    dir1="${toplevel}/${revisions[0]}"
    dir2="${toplevel}/${revisions[1]}"
#    for i in gcc g++ gfortran libstdc++ ld gas binutils libgomp libitm; do
#	ssh ${fileserver} "${tmp}/report.sh ${toplevel} ${i}.sum > ${toplevel}/diff-${i}.txt"
#	if test $? -gt 0; then
#	    ret=1
#	fi
#	ssh ${fileserver} cat ${toplevel}/diff-${i}.txt
#    done
    ssh ${fileserver} "${tmp}/compare_tests -target ${target} ${dir2} ${dir1} > ${toplevel}/diff.txt"
    if test $? -ne 0; then
	ret=1
    fi
    ssh ${fileserver} cat ${toplevel}/diff.txt

    rm -fr ${tmp}

    echo "### Compared REFERENCE:"
    man="`find ${local_builds} -name gcc.git@${revisions[1]}\*manifest.txt`"
    cat ${man}

    echo "### with NEW COMMIT:"
    man="`find ${local_builds} -name gcc.git@${revisions[0]}\*manifest.txt`"
    cat ${man}

    wwwpath="`echo ${toplevel} | sed -e 's:/work::' -e 's:/space::'`"
    echo "Full build logs: http://${fileserver}${wwwpath}/"
fi

# Check out the revision made before this patch gets merged in
rm -fr ${local_snapshots}/gcc.git@${records['revision']}
cd "`get_srcdir gcc.git@${records['parents']}`"
git reset HEAD^
git co master
git branch -d local_gcc.git@${records['parents']}

exit ${ret}
