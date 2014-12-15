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

usage()
{
    # Format this section with 75 columns.
    cat << EOF
  ${cbuild2} [''| [--timeout <value>]
             [[--build [<package> --stage {1|2}]|all]
              |[--checkout <package>|all]]
             [--ccache] [--check] [--enable {bootstrap|gerrit}]
             [--disable {install|update|make_docs|building}] [--dryrun] [--dump]
             [--fetch <url>] [--force] [--host <host_triple>] [--help]
             [--list] [--march <march>] [--manifest <manifest_file>]
             [--parallel] [--release] [--set {libc}={glibc|eglibc|newlib}]
             [--set {languages}={c|c++|fortran|go|lto|objc|java|ada}]
             [--set {cflags|ldflags|runtestflgs|makeflags}=XXX]
             [--set {package}={toolchain|gdb|sysroot}]
             [--snapshots <url>] [--target <target_triple>] [--usage]
             [--interactive]
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

  --build {<package>|all}

                <package>
                        To build a package version that corresponds to an
                        identifier in sources.conf do --build <sources.conf
                        identifier>, e.g., --build gcc.git.

                        To build a package version that corresponds to a
                        snapshot archive do --build <snapshot fragment>,
                        e.g., --build gcc-linaro-4.7-2014.01.

                        NOTE: to build GCC stage1 or stage2 use the --stage
                        flag, as described below, along with --build gcc,
                        e.g. --build gcc --stage 2.

                all
                        Build the entire toolchain and populate the
                        sysroot.

  --ccache	Use ccache when building packages.

  --check
		Run make check on packages.  For cross builds this will run
		the tests on native hardware.

  --checkout <package>[~branch][@revision]|all

               <package>[~branch][@revision]
                       This will checkout the package designated by the
                       <package> source.conf identifier with an optional
                       branch and/or revision designation.

               all
                       This will checkout all of the sources for a
                       complete build as specified by the config/ .conf
                       files.

  --disable {install}

		install
                        Disable the make install stage of packages, which
                        is enabled by default.

		update
			Don't update source repositories before building.

                make_docs
                        Don't make the toolchain package documentation.

                building
                        Don't build anything. This is only useful when
                        using --tarbin, --tarsrc, --tarballs.
                        This is a debugging aid for developers, as it
                        assumes everything built correctly...
                        
  --dryrun	Run as much of ${cbuild2} as possible without doing any
		actual configuration, building, or installing.

  --dump	Dump configuration file information for this build.

  --enable {bootstrap}

                bootstrap
                        Enable gcc bootstrapping, which is disabled by
                        default.

                gerrit
                        Enable posting comments to Gerrit on the build
                        progress.

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

  --march <march>

                Specify <march> to be the default target architecture for a
                specific toolchain, overriding the default.  Example:

                    --target arm-linux-gnueabihf --march armv8-a

		Note: There is no cross-checking to make sure that the passed
		--target value is compatible with the passed --march value.

  --manifest <manifest_file>

  		Source the <manifest_file> to override the default
		configuration. This is used to reproduce an identical
		toolchain build from manifest files generated by a previous
		build.

  --parallel	Set the make flags for parallel builds.

  --prefix	Set an alternate value for the prefix used to configure.

  --release <name>
		The build system will package the resulting toolchain as a
		release with the 'name' prefix.

  --set		{libc}={glibc|eglibc|newlib}

		The default value is stored in lib/global.sh.  This
		setting overrides the default.  Specifying a libc
		other than newlib on baremetal targets is an error.

  --set		{cflags|ldflags|runtestflags|makeflags}=XXX
                This overrides the default values used for CFLAGS,
                LDFLAGS, RUNTESTFLAGS, and MAKEFLAGS.

  --set		{package}={toolchain|gdb|sysroot}
                This limits the default set of packages to the specified set.
                This only applies to the --tarbin, --tarsrc, and --tarballs
                command lines options, and are primarily to be only used by
                developers.

  --set		{labguages}={c|c++|fortran|go|lto|objc|java|ada}
                This changes the default set of GCC front ends that get built.
                The default set for most platforms is c, c++, go, fortran,
                and lto.

  --snapshots	/path/to/alternative/local_snapshots/directory
  		Use an alternative path to a local snapshots directory. 

  --stage {1|2}
                If --build <*gcc*> is passed, then --stage {1|2} will cause
                stage1 or stage2 of gcc to be built.  If --build <*gcc*> is
                not passed then --stage {1|2} does nothing.

  --tarball
  		Build source and binary tarballs after a successful build.

  --tarsrc
  		Build source tarballs after a successful build.

  --tarbin
  		Build binary tarballs after a successful build.

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

  --timeout <timeout_value>

                Use <timeout_value> as the timeout value for wget when
                fetching snapshot packages.

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

    ${cbuild2} --target arm-none-linux-gnueabihf --build all

  Build a Linux cross toolchain with glibc as the clibrary:

    ${cbuild2} --target arm-none-linux-gnueabihf --set libc=glibc --build all

  Build a bare metal toolchain:

    ${cbuild2} --target aarch64-none-elf --build all

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

if test "`echo $* | grep -c -- -help`" -gt 0; then
    help
    exit 0
fi

# load the configure file produced by configure
if test -e "${PWD}/host.conf"; then
    . "${PWD}/host.conf"
else
    echo "ERROR: no host.conf file!  Did you run configure?" 1>&2
    exit 1
fi

# load commonly used functions
cbuild="`which $0`"
topdir="${cbuild_path}"
cbuild2="`basename $0`"

. "${topdir}/lib/common.sh" || exit 1

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
	arm*-eabi|aarch64*-*elf|*-mingw32)
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
    local package="`echo $1 | cut -d '=' -f 1`"
    local setting="`echo $* | cut -d '=' -f 2-3`"

    case ${package} in
	languages|la*)
	    with_languages="${setting}"
	    notice "Setting list of languages to build to ${setting}"
	    return 0
	    ;;
	packages|pa*)
	    with_packages="${setting}"
	    notice "Setting list of packages to build to ${setting}"
	    return 0
	    ;;
	runtestflags|ru*)
	    override_runtestflags="${setting}"
	    notice "Overriding ${setting} to RUNTESTFLAGS"
	    return 0
	    ;;
	makeflags|ma*)
#	    override_makeflags="${setting}"
	    set make_flags="${make_flags} ${setting}"
	    notice "Overriding ${setting} to MAKEFLAGS"
	    return 0
	    ;;
	ldflags|ld*)
	    override_ldflags="${setting}"
	    notice "Overriding ${setting} to LDFLAGS"
	    return 0
	    ;;
	cflags|cf*)
	    override_cflags="${setting}"
	    notice "Overriding ${setting} to CFLAGS"
	    return 0
	    ;;
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

build_failure()
{
    local time="`expr ${SECONDS} / 60`"
    error "Build process failed after ${time} minutes"
    
    if test x"${gerrit}" = xyes; then
	gerrit_build_status ${gcc_version} 1
    fi
    exit 1
}

build_success()
{
    local time="`expr ${SECONDS} / 60`"
    notice "Build process succeeded after ${time} minutes"
    
    if test x"${gerrit}" = xyes; then
	gerrit_build_status ${gcc_version} 0
    fi

    return 0
}

test_success()
{
    local time="`expr ${SECONDS} / 60`"
    notice "Test run completed after ${time} minutes"
    
    if test x"${gerrit}" = xyes; then
	gerrit_build_status ${gcc_version} 6
    fi

    return 0
}

# Switches that require a following directive need to make sure they don't
# parse the -- of the following switch.
check_directive()
{
    switch="$1"
    long="$2"
    short="$3"
    directive="$4"

    if test `echo ${switch} | grep -c "\-${short}.*=" ` -gt 0; then
	error "A '=' is invalid after --${long}.  A space is expected between the switch and the directive."
    elif test x"$directive" = x; then
	error "--${long} requires a directive.  See --usage for details.' "
	build_failure
    elif test `echo ${directive} | egrep -c "^\-+"` -gt 0; then
	error "--${long} requires a directive.  ${cbuild2} found the next -- switch.  See --usage for details.' "
    else
	return 0
    fi
    build_failure
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

    echo "Bootstrap          ${bootstrap}"
    echo "Gerrit             ${gerrit}"
    echo "Install            ${install}"
    echo "Source Update      ${supdate}"
    echo "Make Documentation ${make_docs}"

    if test x"${default_march}" != x; then
	echo "Default march      ${default_march}"
    fi
}

export PATH="${local_builds}/destdir/${build}/bin:$PATH"

# do_ switches are commands that should be executed after processing all
# other switches.
do_dump=
do_checkout=
do_build=
do_build_stage=stage2

# Process the multiple command line arguments
while test $# -gt 0; do
    # Get a URL for the source code for this toolchain component. The
    # URL can be either for a source tarball, or a checkout via svn, bzr,
    # or git
    case "$1" in
	--bu*|-bu*)			# build
	    check_directive $1 build bu $2
   
	    # Save and process this after all other elements have been processed.
	    do_build="$2"

	    # Shift off the 'all' or the package identifier.
	    shift
	    ;;
	--check|-check)
	    runtests=yes
	    ;;
	--checkout*|-checkout*)
	    check_directive $1 checkout "checkout" $2
	    # Save and process this after all other elements have been processed.
	    do_checkout="$2"

	    # Shift off the 'all' or the package identifier.
	    shift
	    ;;
	--march*|-march*)
	    check_directive $1 march "march" $2
	    default_march=$2
	    shift
	    ;;
	--host|-h*)
	    host=$2
	    shift
	    ;;
	--manifest*|-m*)
	    check_directive $1 manifest "m" $2
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
	--pr*|--prefix*)
	    check_directive $1 prefix "pr" $2
	    prefix=$2
	    shift
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
	--dry*|-dry*)
            dryrun=yes
            ;;
	--dump)
	    do_dump=yes
            #dump ${url}
	    #shift
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
	    parallel=yes
            ;;
	--rel*|-rel*)
	    check_directive $1 release "rel" $2
            release=$2
	    shift
            ;;
	--set*|-set*)
	    check_directive $1 set "set" $2

	    # Test if --target follows the --set command put --set and it's
	    # directive on to the back of the inputs.  This is because clibrary
	    # validity depends on the target.
	    if test "`echo $@ | grep -c "\-targ.*"`" -gt 0; then
		# Push $1 and $2 onto the back of the inputs for later processing.
		set -- $@ $1 $2
		# Shift off them off the front.
		shift 2;
		continue;
	    fi

	    set_package $2
	    if test $? -gt 0; then
		# The failure particular reason is output within the
		# set_package function.
		build_failure
	    fi
	    shift
	    ;;
	--snap*|-snap*)
	    check_directive $1 snapshots snap $2
            local_snapshots=$2
	    shift
            ;;
	--sta*|-sta*)
	    check_directive $1 stage sta $2
	    if test x"$2" != x"2" -a x"$2" != x"1"; then
		error "--stage requires a 2 or 1 directive."
		build_failure
	    fi
	    do_build_stage="stage$2"
	    shift
	    ;;
	--tarball*|-tarba*)
	    tarsrc=yes
	    tarbin=yes
	    ;;
	--tarbin*|-tarbi*)
	    tarbin=yes
	    ;;
	--tarsrc*|-tars*)
	    tarsrc=yes
	    ;;
	--targ*|-targ*)			# target
	    check_directive $1 target targ $2

	    target=$2
	    sysroots=${sysroots}/${target}

	    # Certain targets only make sense using newlib as the default
	    # clibrary. Override the normal default in lib/global.sh. The
	    # user might try to override this with --set libc={glibc|eglibc}
	    # or {glibc|eglibc}=<foo> but that will be caught elsewhere.
	    case ${target} in
		arm*-eabi*|arm*-elf|aarch64*-*elf|*-mingw32)
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
       --time*|-time*)
	    check_directive $1 timeout "time" $2
	    if test $2 -lt 11; then
		wget_timeout=$2
	    else
		# FIXME: Range check for non-numerical values.
		wget_timeout=10
	    fi
            shift
            ;;
	# These steps are disabled by default but are sometimes useful.
	--enable*|--disable*)
	    case "$1" in
		--enable*)
		    check_directive $1 "enable" "enable" $2
		    value="yes"
		    ;;
		--disable*)
		    check_directive $1 "disable" "disable" $2
		    value="no"
		    ;;
		*)
		    error "Internal failure.  Should never happen."
		    build_failure
		    ;;
	    esac

	    case $2 in
		bootstrap)
		    bootstrap="${value}"
		    ;;
		gerrit)
		    gerrit="${value}"
		    # Initialize settings for gerrit
		    gerrit_info $HOME
		    if test x"${gerrit_branch}" != x; then
			gcc_version="gcc.git~${gerrit_branch}@${gerrit_revision}"
		    fi
		    ;;
		alltests)
		    alltests="${value}"
		    ;;
		install)
		    install="${value}"
		    ;;
		building)
		    building="${value}"
		    ;;
		parallel)
		    parallel="$value"
		    ;;
		schroot_test)
		    schroot_test="${value}"
		    ;;
		update)
		    supdate="${value}"
		    ;;

		make_docs)
		    make_docs="${value}"
		    ;;
		*)
		    error "$2 not recognized as a valid $1 directive."
		    build_failure
		    ;;
	    esac
	    shift
	    ;;
	--merge*)
	    check_directive $1 merge merge $2
	    merge_branch $2
	    shift
	    ;;
	--merge-diff*)
	    check_directive $1 "merge-diff" "merge-diff" $2
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
			gcc_version="${value}"
			;;
		    gm*|gmp)
			gmp_version="${value}"
			;;
		    gd*|gdb)
			gdb_version="${value}"
			;;
		    mpf*|mpfr)
			mpfr_version="${value}"
			;;
		    mpc)
			mpc_version="${value}"
			;;
		    eglibc|glibc|newlib)
			# Test if --target follows one of these clibrary set
			# commands.  If so, put $1 onto the back of the inputs.
			# This is because clibrary validity depends on the target.
			if test "`echo $@ | grep -c "\-targ.*"`" -gt 0; then
			    # Push $1 onto the back of the inputs for later processing.
			    set -- $@ $1
			    # Shift it off the front.
			    shift
			    continue;
			fi

			# Only allow valid combinations of target and clibrary.
			crosscheck_clibrary_target ${name} ${target}
			if test $? -gt 0; then
			    build_failure
			fi
			# Continue to process individually.
			case ${name} in
			    eglibc)
				clibrary="eglibc"
				eglibc_version="${value}"
				;;
			    glibc)
				clibrary="glibc"
				glibc_version="${value}"
				;;
			    n*|newlib)
				clibrary="newlib"
				newlib_version="${value}"
				;;
			    *)
				;;
			esac
			;;
		    *)
			;;
		esac
	    else
		error "$1: Command not recognized."
		build_failure
	    fi
            ;;
    esac
    if test $# -gt 0; then
	shift
    fi
done

# if test x"${tarbin}" = x"yes" -o x"${tarsrc}" = x"yes"; then
#     warning "No testsuite will be run when building tarballs!"
#     runtests=no
# fi

timeout_save=${wget_timeout}
wget_timeout=10
# Get the md5sums file, which is used later to get the URL for remote files
fetch md5sums
wget_timeout=${timeout_save}

if test ! -z ${do_dump}; then
    dump
fi

if test ! -z ${do_checkout}; then
    if test x"${do_checkout}" != x"all"; then
	url="`get_source ${do_checkout}`"
	if test $? -gt 0; then
	    error "Couldn't find the source for ${do_checkout}"
	    build_failure
	fi

	checkout ${url}
	if test $? -gt 0; then
	    error "--checkout ${url} failed."
	    build_failure
	fi
    else
	checkout_all
	if test $? -gt 0; then
	    error "--checkout all failed."
	    build_failure
	fi
    fi
fi

if test ! -z ${do_build}; then
    if test x"${do_build}" != x"all"; then
	gitinfo="`get_source ${do_build}`"
	if test x"${gitinfo}" = x; then
	    error "Couldn't find the source for ${do_build}"
	    build_failure
	else
	    build_param=
	    # If we're just building gcc then we need to pick a 'stage'.
	    # The user might have specified a stage so we use that if
	    # it's set.
	    if test `echo ${do_build} | grep -c "gcc"` -gt 0; then
		build_param=${do_build_stage}
	    fi
	    build ${gitinfo}${build_param:+ ${build_param}}
	    if test $? -gt 0; then
		error "Building ${gitinfo} failed."
		build_failure
	    fi
	fi
    else
	buildingall=yes
	build_all
	if test $? -gt 0; then
	    error "Build all failed."
	    build_failure
	fi
    fi	 
fi

time="`expr ${SECONDS} / 60`"
if test ! -z ${do_build}; then
    notice "Complete build process took ${time} minutes"
elif test ! -z ${do_checkout}; then
    notice "Complete checkout process took ${time} minutes"
fi
exit 0
