#!/bin/bash
# 
#   Copyright (C) 2013, 2014 Linaro, Inc
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

# Improve debug logs
PRGNAME=`basename $0`
PS4='+ $PRGNAME: ${FUNCNAME+"$FUNCNAME : "}$LINENO: '

usage()
{
    # Format this section with 75 columns.
    cat << EOF
  jenkins.sh [--help] [-s snapshot dir] [g git reference dir] [abe path] [w workspace]
EOF
    return 0
}

if test $# -lt 1; then
    echo "ERROR: No options for build!"
    usage
#    exit
fi

# Directory of ABE source files
abe_dir="$(cd $(dirname $0); pwd)"

# This is where all the builds go
if test x"${WORKSPACE}" = x; then
    WORKSPACE="`pwd`"
fi
user_workspace="${WORKSPACE}"

# The files in this directory are shared across all platforms 
shared="${HOME}/workspace/shared"

# This is an optional directory for the reference copy of the git repositories.
git_reference="${HOME}/snapshots-ref"

# GCC branch to build
gcc_branch="latest"

# set default values for options to make life easier
user_snapshots="${user_workspace}/snapshots"

# Server to wget snapshots from.
fileserver="ex40-01.tcwglab.linaro.org/snapshots-ref"

# Server to store results on.
logserver=""

# Template of logs' directory name
logname='${job}${BUILD_NUMBER}-${branch}/${arch}.${target}'

# Compiler languages to build
languages=default

# Whether attempt bootstrap
try_bootstrap=false

# The release version string, usually a date
releasestr=

# This is a string of optional extra arguments to pass to abe at runtime
user_options=""

# Return status
status=0

# Whether to exclude some component from 'make check'
excludecheck=

# Whether to rebuild the toolchain even if logs are already present.
# Note that the check is done on logserver/logname pair, so logname should not
# be relying on variables that this script sets for match to succeed.
# In practice, --norebuild option should be accompanied by something like
# --logname gcc-<sha1>
rebuild=true

OPTS="`getopt -o s:g:c:w:o:f:l:rt:b:h -l gcc-branch:,snapshots:,gitrepo:,abe:,workspace:,options:,fileserver:,logserver:,logname:,languages:,runtests,target:,bootstrap,help,excludecheck:,norebuild -- "$@"`"
while test $# -gt 0; do
    case $1 in
	--gcc-branch) gcc_branch=$2; shift ;;
        -s|--snapshots) user_snapshots=$2; shift ;;
        -g|--gitrepo) git_reference=$2; shift ;;
        -c|--abe) abe_dir=$2; shift ;;
	-t|--target) target=$2; shift ;;
        -w|--workspace) user_workspace=$2; shift ;;
        -o|--options) user_options=$2; shift ;;
        -f|--fileserver) fileserver=$2; shift ;;
        --logserver) logserver=$2; shift ;;
        --logname) logname=$2; shift ;;
        -l|--languages) languages=$2; shift ;;
        -r|--runtests) runtests="true" ;;
        -b|--bootstrap) try_bootstrap="true" ;;
	--excludecheck) excludecheck=$2; shift ;;
	--norebuild) rebuild=false ;;
	-h|--help) usage ;;
    esac
    shift
done

# Non matrix builds use node_selector, but matrix builds use NODE_NAME
if test x"${node_selector}" != x; then
    node="`echo ${node_selector} | tr '-' '_'`"
    job=${JOB_NAME}
else
    node="`echo ${NODE_NAME} | tr '-' '_'`"
    job="`echo ${JOB_NAME}  | cut -d '/' -f 1`"
fi

# Get the version of GCC we're supposed to build
change=""
if test x"${gcc_branch}" = x""; then
    echo "ERROR: Empty value passed to --gcc-branch."
    echo "Maybe you meant to pass '--gcc-branch latest' ?"
    exit 1
else
    if test x"${gcc_branch}" != x"latest"; then
	change="${change} gcc=${gcc_branch}"
    fi
    branch="`echo ${gcc_branch} | cut -d '~' -f 2 | sed -e 's:\.tar\.xz::'`"
fi

arch="`uname -m`"

# Now that all variables from $logname template are known, calculate log dir.
eval dir="$logname"

# Split $logserver into "server:path".
basedir="${logserver#*:}"
logserver="${logserver%:*}"

# Check status of logs on $logserver and rebuild if appropriate.
[ x"$logserver" != x"" ] && ssh $logserver mkdir -p $(dirname $basedir/$dir)
# Loop and wait until we successfully grabbed the lock.  The while condition is,
# effectively, "while true;" with a provision to skip if $logserver is not set.
while [ x"$logserver" != x"" ]; do
    # Non-blocking read lock, and check whether logs already exist.
    log_status=$(ssh $logserver flock -ns $basedir/$dir.lock -c \
	"\"if [ -e $basedir/$dir ]; then exit 0; else exit 2; fi\""; echo $?)

    case $log_status in
	0)
	    echo "Logs are already present in $logserver:$basedir/$dir"
	    if ! $rebuild; then
		exit 0
	    fi
	    echo "But we are asked to rebuild them anyway"
	    ;;
	1)
	    echo "Can't obtain read lock; waiting for another build to finish"
	    sleep 60
	    continue
	    ;;
	2)
	    echo "Logs don't exist in $basedir/$dir, trying to rebuild"
	    ;;
	*)
	    echo "ERROR: Unexpected status of logs: $log_status"
	    exit 1
	    ;;
    esac

    # Acquire the lock for the duration of the build.  The lock is released
    # in the "trap" cleanup below on signal or normal exit.
    # Note that the ssh command will be running in the background for the
    # duration of the build (spot "&" at its end).  Ssh command will exit
    # when lock file is deleted by the "trap" cleanup.
    # We place a unique marker into the lock file to check on our side who
    # has the lock, since we can't inspect return value of the ssh command.
    #
    # Note on '-tt': We forcefully allocate pseudo-tty for the flock command
    # so that flock dies (through SIGHUP) and releases the lock when this
    # script is cancelled or terminated for whatever reason.  Without SIGHUP
    # reaching flock we risk situations when a lock will hang forever preventing
    # any subsequent builds to progress.  There are a couple of options as to
    # exactly how enable delivery of SIGHUP (e.g., set +m), and 'ssh -tt' seems
    # like the simplest one.
    ssh -tt $logserver flock -nx $basedir/$dir.lock -c \
	"\"echo $(hostname)-$$-$BUILD_URL > $basedir/$dir.lock; while [ -e $basedir/$dir.lock ]; do sleep 10; done\"" &
    pid=$!
    # This is borderline fragile, since we are giving the above ssh command
    # a fixed period of time (10sec) to connect to $logserver and populate
    # $basedir/$dir.lock.  In practice, $logserver is a fast-ish machine,
    # which serves connections quickly.  In the worst-case scenario, we will
    # just retry a couple of times in this loop.
    sleep 10

    if [ x"$(ssh $logserver cat $basedir/$dir.lock)" \
	= x"$(hostname)-$$-$BUILD_URL" ]; then
	trap "ssh $logserver rm -f $basedir/$dir.lock" 0 1 2 3 5 9 13 15
	# Hurray!  Break from the loop and go ahead with the build!
	break
    fi

    kill $pid || true
done

# Test the config parameters from the Jenkins Build Now page

# See if we're supposed to build a source tarball
if test x"${tarsrc}" = xtrue -o "`echo $user_options | grep -c -- --tarsrc`" -gt 0; then
    tars="--tarsrc"
fi

# See if we're supposed to build a binary tarball
if test x"${tarbin}" = xtrue -o "`echo $user_options | grep -c -- --tarbin`" -gt 0; then
    tars="${tars} --tarbin "
fi

# Set the release string if specefied
if ! test x"${release}" = xsnapshot -o x"${release}"; then
    releasestr="--release ${release}"
fi
if test "`echo $user_options | grep -c -- --release`" -gt 0; then
    release="`echo  $user_options | grep -o -- "--release [a-zA-Z0-9]* " | cut -d ' ' -f 2`"
    releasestr="--release ${release}"
fi

# Get the versions of dependant components to use
if test x"${gmp_snapshot}" != x"latest" -a x"${gmp_snapshot}" != x; then
    change="${change} gmp=${gmp_snapshot}"
fi
if test x"${mpc_snapshot}" != x"latest" -a x"${mpc_snapshot}" != x; then
    change="${change} mpc=${mpc_snapshot}"
fi
if test x"${mpfr_snapshot}" != x"latest" -a x"${mpfr_snapshot}" != x; then
    change="${change} mpfr=${mpfr_snapshot}"
fi

if test x"${binutils_snapshot}" != x"latest" -a x"${binutils_snapshot}" != x; then
    change="${change} binutils=${binutils_snapshot}"
fi
if test x"${linux_snapshot}" != x"latest" -a x"${linux_snapshot}" != x; then
    change="${change} linux-${linux_snapshot}"
fi

# if runtests is true, then run make check after the build completes
if test x"${runtests}" = xtrue; then
    check="--check all"
    check="${check}${excludecheck:+ --excludecheck ${excludecheck}}"
fi

if test x"${target}" != x"native" -a x"${target}" != x; then
    platform="--target ${target}"
fi

if test x"${libc}" != x; then
    # ELF based targets are bare metal only
    case ${target} in
	arm*-none-*)
	    change="${change} --set libc=newlib"
	    ;;
	*)
	    change="${change} --set libc=${libc}"
	    ;;
    esac
fi

# This is the top level directory where builds go.
if test x"${user_workspace}" = x; then
    user_workspace="${WORKSPACE}"
fi

# Create a build directory
if test -d ${user_workspace}/_build; then
    rm -fr ${user_workspace}/_build
fi
mkdir -p ${user_workspace}/_build

# Use the newly created build directory
pushd ${user_workspace}/_build

# Configure Abe itself. Force the use of bash instead of the Ubuntu
# default of dash as some configure scripts go into an infinite loop with
# dash. Not good...
export CONFIG_SHELL="/bin/bash"
if test x"${debug}" = x"true"; then
    export CONFIG_SHELL="/bin/bash -x"
fi

$CONFIG_SHELL ${abe_dir}/configure --with-local-snapshots=${user_snapshots} --with-git-reference-dir=${git_reference} --with-languages=${languages} --enable-schroot-test --with-fileserver=${fileserver}

# Double parallelism for tcwg-ex40-* machines to compensate for really-remote
# target execution.  GCC testsuites will run with -j 32.
case "$(hostname)" in
    "tcwg-ex40-"*) sed -i -e "s/cpus=8/cpus=16/" host.conf ;;
esac

# load commonly used varibles set by configure
if test -e "${PWD}/host.conf"; then
    . "${PWD}/host.conf"
fi

# This is the top level directory for the abe sources.
#abe_dir="${abe_path}"

# Delete the previous test result files to avoid problems.
find ${user_workspace} -name \*.sum -exec rm {} \;  2>&1 > /dev/null

if test x"${try_bootstrap}" = xtrue; then
    # Attempt to bootstrap GCC is build and target are compatible
    build1="$(grep "^build=" host.conf | sed -e "s/build=\(.*\)-\(.*\)-\(.*\)-\(.*\)/\1-\3-\4/")"
    target1="$(echo ${target} | sed -e "s/\(.*\)-\(.*\)-\(.*\)-\(.*\)/\1-\3-\4/")"
    if test x"${build1}" = x"${target1}" -o x"${platform}" = x""; then
	try_bootstrap="--enable bootstrap"
    else
	try_bootstrap="--disable bootstrap"
    fi
else
    try_bootstrap=""
fi

# Checkout all sources now to avoid grabbing lock for 1-2h while building and
# testing runs.  We configure ABE to use reference snapshots, which are shared
# across all builds and are updated by an external process.  The lock protects
# us from looking into an inconsistent state of reference snapshots.
(
    flock -s 9
    $CONFIG_SHELL ${abe_dir}/abe.sh ${platform} ${change} --checkout all
) 9>${git_reference}.lock

# Also fetch changes from gerrit
(cd $user_snapshots/gcc.git; git fetch origin '+refs/changes/*:refs/remotes/gerrit/changes/*')

# Now we build the cross compiler, for a native compiler this becomes
# the stage2 bootstrap build.
$CONFIG_SHELL ${abe_dir}/abe.sh --disable update ${check} ${tars} ${releasestr} ${platform} ${change} ${try_bootstrap} --timeout 100 --build all --disable make_docs > build.out 2> >(tee build.err >&2)

# If abe returned an error, make jenkins see this as a build failure
if test $? -gt 0; then
    echo "================= TAIL OF LOG: BEGIN ================="
    tail -n 50 build.out
    echo "================= TAIL OF LOG: FINISH ================="
    exit 1
fi

# Create the BUILD-INFO file for Jenkins.
cat << EOF > ${user_workspace}/BUILD-INFO.txt
Format-Version: 0.5

Files-Pattern: *
License-Type: open
EOF

if test x"${tars}" = x; then
    # date="`${gcc} --version | head -1 | cut -d ' ' -f 4 | tr -d ')'`"
    date="`date +%Y%m%d`"
else
    date=${release}
fi

# Setup the remote directory for tcwgweb
xgcc="`find ${user_workspace} -name xgcc`"

# If we can't find GCC, our build failed, so don't continue
if test x"${xgcc}" = x; then
    exit 1
fi

# This is the remote directory for tcwgweb where all test results and log
# files get copied too.

# These fields are enabled by the buikd-user-vars plugin.
if test x"${BUILD_USER_FIRST_NAME}" != x; then
    requestor="-${BUILD_USER_FIRST_NAME}"
fi
if test x"${BUILD_USER_LAST_NAME}" != x; then
    requestor="${requestor}.${BUILD_USER_LAST_NAME}"
fi

echo "Build by ${requestor} on ${NODE_NAME} for branch ${branch}"

manifest="`find ${user_workspace} -name \*manifest.txt`"
if test x"${manifest}" != x; then
    echo "node=${node}" >> ${manifest}
    echo "requestor=${requestor}" >> ${manifest}
    revision="`grep 'gcc_revision=' ${manifest} | cut -d '=' -f 2 | tr -s ' '`"
    if test x"${revision}" != x; then
	revision="-${revision}"
    fi
    if test x"${BUILD_USER_ID}" != x; then
	echo "email=${BUILD_USER_ID}" >> ${manifest}
    fi
    echo "build_url=${BUILD_URL}" >> ${manifest}
else
    echo "ERROR: No manifest file, build probably failed!"
fi

# This becomes the path on the remote file server    
if test x"${logserver}" != x""; then
    # Re-eval $dir as we now have full range of variables available.
    eval dir="$logname"
    ssh ${logserver} mkdir -p ${basedir}/${dir}
    if test x"${manifest}" != x; then
	scp ${manifest} ${logserver}:${basedir}/${dir}/
    fi

# If 'make check' works, we get .sum files with the results. These we
# convert to JUNIT format, which is what Jenkins wants it's results
# in. We then cat them to the console, as that seems to be the only
# way to get the results into Jenkins.
#if test x"${sums}" != x; then
#    for i in ${sums}; do
#	name="`basename $i`"
#	${abe_dir}/sum2junit.sh $i $user_workspace/${name}.junit
#	cp $i ${user_workspace}/results/${dir}
#    done
#    junits="`find ${user_workspace} -name *.junit`"
#    if test x"${junits}" = x; then
#	echo "Bummer, no junit files yet..."
#    fi
#else
#    echo "Bummer, no test results yet..."
#fi
#touch $user_workspace/*.junit
fi

# Find all the test result files.
sums="`find ${user_workspace} -name \*.sum`"

# Canadian Crosses are a win32 hosted cross toolchain built on a Linux
# machine.
if test x"${canadian}" = x"true"; then
    $CONFIG_SHELL ${abe_dir}/abe.sh --disable update --nodepends ${change} ${platform} --build all
    distro="`lsb_release -sc`"
    # Ubuntu Lucid uses an older version of Mingw32
    if test x"${distro}" = x"lucid"; then
	$CONFIG_SHELL ${abe_dir}/abe.sh --disable update --nodepends ${change} ${tars} --host=i586-mingw32msvc ${platform} --build all
    else
	$CONFIG_SHELL ${abe_dir}/abe.sh --disable update --nodepends ${change} ${tars} --host=i686-w64-mingw32 ${platform} --build all
    fi
fi

# This setups all the files needed by tcwgweb
if test x"${logserver}" != x"" && test x"${sums}" != x -o x"${runtests}" != x"true"; then
    logs_dir=$(mktemp -d)

    if test x"${sums}" != x; then
	test_logs=""
	for s in ${sums}; do
	    test_logs="$test_logs ${s%.sum}.log"
	done

	cp ${sums} ${test_logs} ${logs_dir}/ || status=1
	
	# Copy over the logs from make check, which we need to find testcase errors.
	checks="`find ${user_workspace} -name check\*.log`"
	cp ${checks} ${logs_dir}/ || status=1
    fi

    # Copy over the build logs
    logs="`find ${user_workspace} -name make\*.log`"
    cp ${logs} ${logs_dir}/ || status=1

    # Copy stdout and stderr output from abe.
    cp build.out build.err ${logs_dir}/ || status=1

    xz ${logs_dir}/* || status=1
    scp ${logs_dir}/* ${logserver}:${basedir}/${dir}/ || status=1
    rm -rf ${logs_dir} || status=1

    echo "Uploaded test results and build logs to ${logserver}:${basedir}/${dir}/ with status: $status"

    if test x"${tarsrc}" = xtrue -a x"${release}" != x; then
	allfiles="`ls ${user_snapshots}/*${release}*.xz`"
	srcfiles="`echo ${allfiles} | egrep -v "arm|aarch"`"
	scp ${srcfiles} ${logserver}:/home/abe/var/snapshots/ || status=1
	rm -f ${srcfiles} || status=1
    fi

    if test x"${tarbin}" = xtrue -a x"${release}" != x; then
	allfiles="`ls ${user_snapshots}/*${release}*.xz`"
	binfiles="`echo ${allfiles} | egrep "arm|aarch"`"
	scp ${binfiles} ${logserver}:/work/space/binaries/ || status=1
	rm -f ${binfiles} || status=1
    fi

fi

exit $status
