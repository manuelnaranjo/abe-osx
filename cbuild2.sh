#!/bin/bash

# load commonly used functions
cbuild="`which $0`"
topdir="`dirname ${cbuild}`"
cbuild2="`basename $0`"

. "${topdir}/lib/common.sh" || exit 1

# load the configure file produced by configure
if test -e "${PWD}/host.conf"; then
    . "${PWD}/host.conf"
else
    warning "no host.conf file!  Did you run configure?"
fi

# this is used to launch builds of dependant components
command_line_arguments=$*

#
# These functions actually do something
#

# Determine whether the clibrary setting passed as $1 is compatible with the
# designated target.
crosscheck_clibrary_target()
{
    local test_clibrary=$1
    local test_target=$2
    case ${test_target} in
       arm*-eabi|aarch64*-*-elf|i686*-mingw32|x86_64*-mingw32)
           # Bare metal targets only support newlib.
           if test x"${test_clibrary}" != x"newlib"; then
               error "${test_target} is only compatible with newlib."
               return 1
           fi
           ;;
       *)
           # No specified target, or non-baremetal targets.
           ;;
    esac
    return 0
}

set_package()
{
    saveIFS=${IFS}
    IFS='='
    local in=($1)
    IFS=${saveIFS}
    local package=${in[0]}
    local setting=${in[1]}

    case ${package} in
	libc)
	    # Range check user input against supported C libraries.
	    case ${setting} in
		glibc|eglibc|newlib)    

		    # Verify that the user specified libc is compatible with
		    # the user specified target.
		    crosscheck_clibrary_target ${setting} ${target}
		    if test $? -gt 0; then
			return 1
		    fi

		    clibrary="${setting}"
		    notice "Using '${setting}' as the C library as directed by \"--set libc=${setting}\"."
		    return 0
		    ;;
		*)
		    error "'${setting}' is an unsupported libc option."
		    ;;
	    esac
	    ;;
	*)
	    error "'${package}' is not a supported package for --set."
	    ;;
    esac

    return 1
}


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
	    infrastructure="`grep infrastructure ${local_snapshots}/md5sums | cut -d ' ' -f 3 | cut -d '/' -f 2`"
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
    echo "C library is:      ${clibrary}"

    # These variables have default values which we don't care about
    echo "Binutils is:       ${binutils}"
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
    # Format this section with 75 columns.
    cat << EOF
  ${cbuild2} [''|
	     [--build [<package>|all|''] [--ccache] [--check]
             [--disable={bootstrap|tarball|install}] [--dryrun] [--dump]
	     [--fetch <url>] [--force] [--host <host_triple>] [--help]
	     [--list] [--manifest <manifest_file>] [--parallel] [--release]
	     [--set {libc}={glibc|eglibc|newlib}] [--snapshots <url>]
	     [--target <target_triple>] [--usage] [--interactive]
   	     [{binutils|gcc|gmp|mpft|mpc|eglibc|glibc|newlib}
		=<id|snapshot|url>]]

EOF
    return 0
}

help()
{
    # Format this section with 75 columns.
    cat << EOF
NAME

  ${cbuild2} - the Linaro Toolchain Build Framework.

SYNOPSIS

EOF
    usage
    cat << EOF
KEY

  [--foo]	  Optional switch
  [<foo>]	  Optional user specified field 
  <foo>		  Non-optional user specified field.
  {foo|bar|bat}   Non-optional choice field.
  [{foo|bar|bat}] Optional choice field.
  [foo]		  Optional field 
  ['']		  Optional Empty field 

DESCRIPTION

  ${cbuild2} is a toolchain build framework. The primary purpose of
  ${cbuild2} is to unify the method used to build cross, native, and
  Canadian-cross GNU toolchains.

PRECONDITIONS

  Autoconf (configure) must be run in order to construct the build
  directory and host.conf file before it is valid to run ${cbuild2}.

OPTIONS

  ''		Specifying no options will display synopsis information.

  --build [<package>|all|'']

		<package>
			Build the specific package as specified by the
			configuration files.  This option is really only
			useful if you've done a previous entire toolchain
			build.

		all
			Build the entire toolchain.
		''
			If there are not options build the entire toolchain.
  --check
		Run make check on packages.  For cross builds this will run
		the tests on native hardware.

  --ccache	Use ccache when building packages.

  --disable	{boostrap|tarball|install}

  		bootstrap
			Foo
		tarball
			Regardless of the default setting, disable the
			building of tarballs.
		install
			Foo

  --dryrun	Run as much of ${cbuild2} as possible without doing any
		actual configuration, building, or installing.

  --dump	Dump configuration file information for this build.

  --fetch <url>

  		Fetch the specified URL into the snapshots directory.

  --force	Force download packages and force rebuild packages.

  --help|-h	Display this usage information.

  --host <host_triple>

		Set the host triple.   This represents the machine where
		the packages being built will run.  For a cross toolchain
		build this would represent where the compiler is run.

  --infrastructure Download and install the infrastructure libraries.

  --interactive Interactively select packages from the snapshots file.

  --list	List the available snapshots or configured repositories.

  --manifest <manifest_file>

  		Source the <manifest_file> to override the default
		configuration. This is used to reproduce an identical
		toolchain build from manifest files generated by a previous
		build.

  --parallel	Set the make flags for parallel builds.

  --release
		The build system will package the resulting toolchain as a
		release.

  --set		{libc}={glibc|eglibc|newlib}

		The default value is stored in lib/global.sh.  This
		setting overrides the default.  Specifying a libc
		other than newlib on baremetal targets is an error.

  --snapshots	<url>
  		Use an alternate snapshots file as specified by <url>.

  --tarball
  		Build tarballs after a successful build.

  --target	[<target_triple>|'']

		This sets the target triple.  The GNU target triple
		represents where the binaries built by the toolchain will
		execute.

		''
			Build the toolchain native to the hardware that
			${cbuild2} is running on.
                 
		<target_triple>

			x86_64-none-linux-gnu
			arm-none-linux-gnueabi
			arm-none-linux-gnueabihf
			armeb-none-linux-gnueabihf
			aarch64-none-linux-gnu
			aarch64-none-elf
			aarch64_be-none-elf
			aarch64_be-none-linux-gnu

			If <target_triple> is not the same as the hardware
			that ${cbuild2} is running on then build the
			toolchain as a cross toolchain.

  --usage	Display synopsis information.

   [{binutils|gcc|gmp|mpft|mpc|eglibc|glibc|newlib}=<id|snapshot|url>]

		This option specifies a particular version of a package
		that might differ from the default version in the
		package config files.

		For a specific package use a version tag that matches a
		setting in a sources.conf file, a snapshots identifier,
		or a direct repository URL.

		Examples:

			# Matches an identifier in sources.conf:
			glibc=glibc.git

			# Matches a tar snapshot in md5sums:
			glibc=eglibc-linaro-2.17-2013.07

			# Direct URL:
			glibc=git://sourceware.org/git/glibc.git

EXAMPLES

  Build a Linux cross toolchain:

    ${cbuild2} --target=arm-none-linux-gnueabihf --build all

  Build a Linux cross toolchain with glibc as the clibrary:

    ${cbuild2} --target=arm-none-linux-gnueabihf --set libc=glibc --build all

  Build a bare metal toolchain:

    ${cbuild2} --target=aarch64-none-elf --build all

PRECONDITION FILES

  ~/.cbuildrc		${cbuild2} user specific configuration file

  host.conf		Generated by configure from host.conf.in.

CBUILD GENERATED FILES AND DIRECTORIES

  builds/		All builds are stored here.

  snapshots/		Package sources are stored here.

  snapshots/infrastructure Infrastructure (non-distributed) sources are stored
			here.

  snapshots/md5sums	The snapshots file of maintained package tarballs.

AUTHOR
  Rob Savoye <rob.savoye@linaro.org>
  Ryan S. Arnold <ryan.arnold@linaro.org>

EOF
    return 0
}

# If there are no command options output the usage message.
if test $# -lt 1; then
    echo "Usage:"
    usage
    echo "Run \"${cbuild2} --help\" for detailed usage information."
    exit 1
fi

export PATH="${local_builds}/destdir/${build}/bin:$PATH"

# Get the md5sums file, which is used later to get the URL for remote files
fetch md5sums

# Process the multiple command line arguments
while test $# -gt 0; do
    # Get a URL for the source code for this toolchain component. The
    # URL can be either for a source tarball, or a checkout via svn, bzr,
    # or git
    case "$1" in
	--bu*|-bu*)			# build
            if test `echo $1 | grep -c "\-bu.*=" ` -gt 0; then
                error "A '=' is invalid after --build.  A space is expected."
                exit 1;
            fi
	    if test x"$2" != x"all"; then
		version="`echo $2 | sed -e 's#[a-zA-Z\+/:@.]*-##' -e 's:\.tar.*::'`"
		tool=`get_toolname $2`
		url="`get_source $2`"
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
	--dry*|-dry*)
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
            release=$2
	    shift
            ;;
	--set)
	    set_package $2
	    if test $? -gt 0; then
		exit 1
	    fi
	    shift
	    ;;
	--snapshots|-s)
            set_snapshots ${url}
	    shift
            ;;
	--tarball*|-tarb*)
	    tarballs=yes
	    ;;
	--targ*|-targ*)			# target
	    if test `echo $1 | grep -c "\-ta.*=" ` -gt 0; then
		error "A '=' is invalid after --target.  A space is expected."
		exit 1;
	    fi
	    target=$2
	    sysroots=${sysroots}/${target}

	    # Certain targets only make sense using newlib as the default
	    # clibrary. Override the normal default in lib/global.sh. The
	    # user might try to override this with --set libc={glibc|eglibc}
	    # or {glibc|eglibc}=<foo> but that will be caught elsewhere.
	    case ${target} in
		arm*-eabi|aarch64*-*-elf|i686*-mingw32|x86_64*-mingw32)
		    clibrary="newlib"
		    ;;
		 *)
		    ;;
	    esac
	    shift
            ;;
	--testcode|te*)
	    testcode
	    ;;
	# Disable steps in the complete process of building a toolchain. All of
	# these are enabled by default, but not always desired.
	--disable)
	    case $2 in
		bootstrap|b*)
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
	    
	    url="`get_source $3`"
	    if test $? -gt 0; then
		error "Couldn't find the source for $3"
		exit 1
	    fi

            case $2 in
		depends)
		    dependencies ${url}
		    ;;
		# this executes the entire process, but ignores any of
		# the dependencies in the config file
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
		    release=$4
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
	--help|-h|--h)
	    help 
	    exit 0
	     ;;
	--usage)
	    echo "Usage:"
	    usage
	    echo "Run \"${cbuild2} --help\" for detailed usage information."
	    exit 0
	      ;;
	*)
	    if test `echo $1 | grep -c =` -gt 0; then
		name="`echo $1 | cut -d '=' -f 1`"
		value="`echo $1 | cut -d '=' -f 2`"
		case ${name} in
		    b*|binutils)
			binutils_version="`echo ${value}`"
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
		    eglibc|glibc|newlib)
			# Only allow valid combinations of target and clibrary.
			crosscheck_clibrary_target ${name} ${target}
			if test $? -gt 0; then
			    exit 1
			fi
			# Continue to process individually.
			;;&
		    eglibc)
			clibrary="eglibc"
			eglibc_version="`echo ${value} | sed -e 's:eglibc-::'`"
			;;
		    glibc)
			clibrary="glibc"
			glibc_version="`echo ${value} | sed -e 's:glibc-::'`"
			;;
		    n*|newlib)
			clibrary="newlib"
			newlib_version="`echo ${value} | sed -e 's:newlib-::'`"
			;;
		    *)
			;;
		esac
	    else
		error "$1: Command not recognized."
		exit 1
	    fi
            ;;
    esac
    if test $# -gt 0; then
	shift
    fi
done

time="`expr ${SECONDS} / 60`"
notice "Complete build process took ${time} minutes"

