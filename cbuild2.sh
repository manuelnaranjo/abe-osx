#!/bin/bash

# load commonly used functions
cbuild="`which $0`"
topdir="`dirname ${cbuild}`"

. "${topdir}/lib/common.sh" || exit 1

# load the configure file produced by configure
if test -e "${PWD}/host.conf"; then
    . "${PWD}/host.conf"
else
    warning "no host.conf file!"
fi

# this is used to launch builds of dependant components
command_line_arguments=$*

#
# These functions actually do something
#

# This gets a list from a remote server of the available tarballs. We use HTTP
# instead of SSH so it's more accessible to those behind nasty firewalls.
# base - already checkout out source trees
# snapshots - tarballs of various source snapshots
# prebuilt - prebuilt executables
get_list()
{
    echo "Get version list for $1..."

    # http://cbuild.validation.linaro.org/snapshots
    case $1 in
	testcode|t*)
	    testcode="`grep testcode ${local_snapshots}/testcode/md5sums | cut -d ' ' -f 3 | cut -d '/' -f 2`"
	    echo "${testcode}"
	    ;;
	snapshots|s*)
	    snapshots="`egrep -v "\.asc|\.diff|\.txt|xdelta|base|infrastructure|testcode" ${local_snapshots}/md5sums | cut -d ' ' -f 3`"
	    echo "${snapshots}"
	    ;;
	infrastructure|i*)
	    infrastructure="`grep infrastructure ${local_snapshots}/infrastructure/md5sums | cut -d ' ' -f 3 | cut -d '/' -f 2`"
	    echo "${infrastructure}"
	    ;;
    esac
	    return 0
}

# Get some info on the build system
# $1 - If specified, it's the hostname of the remote system
get_build_machine_info()
{
    if test x"$1" = x; then
	cpus="`getconf _NPROCESSORS_ONLN`"
	libc="`getconf GNU_LIBC_VERSION`"
	kernel="`uname -r`"
	build_arch="`uname -p`"
	hostname="`uname -n`"
	distribution="`lsb_release -sc`"
    else
	# FIXME: this assumes the user has their ssh keys setup to the point
	# where the don't need a password but is secure.
	echo "Getting config info from $1"
	cpus="`ssh $1 getconf _NPROCESSORS_ONLN`"
	libc="`ssh $1 getconf GNU_LIBC_VERSION`"
	kernel="`ssh $1 uname -r`"
	build_arch="`ssh $1 uname -p`"
	hostname="`ssh $1 uname -n`"
	distribution="`ssh $1 lsb_release -sc`"	
    fi
}

dispatch()
{
    echo "Dispatching LAVA build on $1..."
}

# Takes no arguments. Dumps all the important config data
dump()
{
    # These variables are always determined dynamically at run time
    echo "Target is:         ${target}"
    echo "GCC is:            ${gcc}"
    echo "GCC version:       ${gcc_version}"
    echo "Sysroot is:        ${sysroots}"

    # These variables have default values which we don't care about
    echo "Binutils is:       ${binutils}"
    echo "Libc is:           ${libc}"
    echo "Config file is:    ${configfile}"
    echo "Snapshot URL is:   ${local_snapshots}"
    echo "DB User name is:   ${dbuser}"
    echo "DB Password is:    ${dbpasswd}"

    echo "Build # cpus is:   ${cpus}"
    echo "Kernel:            ${kernel}"
    echo "Build Arch:        ${build_arch}"
    echo "Hostname:          ${hostname}"
    echo "Distribution:      ${distribution}"
}

usage()
{
    echo "Usage: $0 "
    echo "  --build (architecture for the build machine, default native)"
    echo "  --target (architecture for the target machine, default native)"
    echo "  --snapshots XXX (URL of remote host or local directory)"
    echo "  --list {base,prebuilt,snapshots} (list possible values for component versions)"
    echo "  --set {gcc,binutils,libc,latest}=XXX (change config file setting)"
    echo "  --config XXX (alternate config file)"
    echo "  --clean (clean a previous build, default is to start where it left off)"
    echo "  --dispatch (run on LAVA build farm, probably remote)"
    echo "  --sysroot XXX (specify path to alternate sysroot)"
    echo "  --db-user XXX (specify MySQL user"
    echo "  --db-passwd XXX (specify MySQL password)"
    echo "  --dump (dump the values in the config file)"
    echo "  --dostep XXX (fetch,extract,configure,build,checkout,package)"
    echo "  --release XXX (make a release tarball)"
    echo "  --clobber (force files to be downloaded even when they exist)"
    echo "  --force (force make errors to be ignored, answer yes for any prompts)"
    echo "  --parallel (do parallel builds, one per cpu core)"
    echo "  --merge XXX (merge a commit from trunk)"
    echo "  --check (run make check after the build completes)"
    exit 1
}

export PATH="${local_builds}/destdir/${build}/bin:$PATH"
#export LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:${local_builds}/destdir/${build}/lib"

# Get the md5sums file, which is used later to get the URL for remote files
fetch md5sums
#fetch_rsync ${remote_snapshots}/md5sums

# Process the multiple command line arguments
while test $# -gt 0; do
    # Get a URL for the source code for this toolchain component. The
    # URL can be either for a source tarball, or a checkout via svn, bzr,
    # or git
    case "$1" in
	--bu*)			# build
	    if test x"$2" != x"all"; then
		version="`echo $2 | sed -e 's#[a-zA-Z\+/:@.]*-##' -e 's:\.tar.*::'`"
		tool=`get_toolname $2`
		get_source $2
		if test $? -gt 0; then
		    error "Couldn't find the source for $2"
		    exit 1
		else
		    build ${url}
		fi
	    else
		build_all
	    fi	    
	    shift
	    ;;
	--check|-ch*)
	    runtests=yes
	    ;;
	--host|-h*)
	    host=$2
	    shift
	    ;;
	--srcdir|-sr*)
	    notice "fixme:"
	    ;;
	--manifest|-m*)
	    # source a manifest file if there is one
	    if test -f $2 ; then
		. $2
	    fi
	    echo $gcc_version
	    ;;
       # download and install the infrastructure libraries GCC depends on
	--inf*|infrastructure)
	    infrastructure
	    ;;
	--sy*)			# sysroot
            set_sysroot ${url}
	    shift
            ;;
	--ccache|-cc*)
            use_ccache=yes
            ;;
	--clean|-cl*)
            clean_build ${url}
	    shift
            ;;
	--config)
            set_config ${url}
	    shift
            ;;
	--db-user)
            set_dbuser ${url}
	    shift
            ;;
	--db-passwd)
            set_dbpasswd ${url}
	    shift
            ;;
	--dispatch)
            dispatch ${url}
	    shift
            ;;
	--dryrun)
            dryrun=yes
            ;;
	--dump)
            dump ${url}
	    shift
            ;;
	--fetch|-d)
            fetch ${url}
	    shift
            ;;
	--force|-f)
	    force=yes
	    ;;
	--interactive|-i)
	    interactive=yes
	    ;;
	--list|-l)
            get_list $2
	    shift
            ;;
	--nodepends|-n)		# nodepends
	    nodepends=yes
	    ;;
	--parallel|-par*)			# parallel
            make_flags="-j ${cpus}"
            ;;
	--release|-r*)
            release=$3
	    shift
            ;;
	--snapshots|-s)
            set_snapshots ${url}
	    shift
            ;;
	--target|-ta*)			# target
            target=$2
	    sysroots=${sysroots}/${target}
	    shift
            ;;
	--testcode|te*)
	    testcode
	    ;;
	# Disable steps in the complete process of building a toolchain. All of
	# these are enabled by default, but not always desired.
	--disable)
	    case $2 in
		boostrap|b*)
		    bootstrap=no
		    ;;
		check|c*)
		    makecheck=yes
		    ;;
		tarball|t*)
		    tarballs=yes
		    ;;
		install|i*)
		    install=no
		    ;;
	    esac
	    shift
	    ;;
	# Execute only one step of the entire process. This is primarily
	# used for debugging.
	--dostep)
	    # Get a URL for the source code for this toolchain component. The
	    # URL can be either for a source tarball, or a checkout via svn, bzr,
	    # or git
	    case $2 in
		package|pac*)
		    binary_tarball $3
		    exit 1
		    ;;
	    esac

	    get_source $3
	    if test $? -gt 0; then
		error "Couldn't find the source for $3"
		exit 1
	    fi

            case $2 in
		# this executes the entire process, but ignores any of
		# the dependencies in the config file
		depends)
		    dependencies ${url}
		    ;;
		build|b*)
		    nodepends=yes
		    build ${url}
		    ;;
		clean|cl*)
		    make_clean ${url}
		    ;;
		# Download a tarball from a remote host
		fetch|f*)
		    fetch ${url} 
		    ;;
		# Extract the tarball
		extract|e*)
		    extract ${url}
		    ;;
		# Commit changes
		commit|com*)
		    commit ${url} $4
		    shift
		    ;;
		# Configure the extracted source tree
		configure|con*)
		    configure_build ${url}
		    ;;
		# Checkout sources from a repository
		checkout|ch*)
		    checkout ${url}
		    ;;
		install|i*)
		    make_install ${url}
		    ;;
		make|ma*)
		    make_all ${url}
		    ;;
		# Push commits up to the repository, not used for svn as
		# svn pushes changes when commiting
		push|p*)
		    push ${url}
		    ;;
		release|r*)
		    release ${url}
		    ;;
		tag|ta**)
		    tag ${url} $4
		    shift
		    ;;
		test|t*)
		    make_check ${url}
		    ;;
		*)
		    ;;
            esac
	    shift
            ;;
	--merge)
	    merge_branch $2
	    shift
	    ;;
	--merge-diff)
	    merge_diff $2
	    shift
	    ;;
	--clobber)
            clobber=yes
            ;;
	--help)
            usage
            ;;
	*)
	    if test `echo $1 | grep -c =` -gt 0; then
		name="`echo $1 | cut -d '=' -f 1`"
		value="`echo $1 | cut -d '=' -f 2`"
		case ${name} in
		    b*|binutils)
			binutils_version="`echo ${value} | sed -e 's:binutils-::'`"
			;;
		    gc*|gcc)
			gcc_version="`echo ${value} | sed -e 's:gcc-::'`"
			;;
		    gm*|gmp)
			gmp_version="`echo ${value} | sed -e 's:gmp-::'`"
			;;
		    mpf*|mpfr)
			mpfr_version="`echo ${value} | sed -e 's:mpfr-::'`"
			;;
		    mpc)
			mpc_version="`echo ${value} | sed -e 's:mpc-::'`"
			;;
		    eglibc)
			eglibc_version="`echo ${value} | sed -e 's:eglibc-::'`"
			;;
		    glibc)
			glibc_version="`echo ${value} | sed -e 's:glibc-::'`"
			;;
		    n*|newlib)
			newlib_version="`echo ${value} | sed -e 's:newlib-::'`"
			;;
		    *)
			;;
		esac
	    fi
            ;;
    esac
    if test $# -gt 0; then
	shift
    fi
done

notice "Build took ${SECONDS} seconds"

