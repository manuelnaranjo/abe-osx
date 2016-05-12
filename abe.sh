#!/bin/bash
# 
#   Copyright (C) 2013, 2014, 2015, 2016 Linaro, Inc
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
  ${abe} [''| [--build {<package> [--stage {1|2}]|all}]
             [--ccache] [--check [{all|glibc|gcc|gdb|binutils}]]
             [--checkout {<package>[~branch][@revision]|all}]
             [--disable {install|update|make_docs|building}] [--dryrun]
             [--dump] [--enable {bootstrap|gerrit}]
             [--excludecheck {all|glibc|gcc|gdb|binutils}]
             [--extraconfig <tool>=<path>]
             [--fetch <url>] [--force] [--help] [--host <host_triple>]
             [--infrastructure] [--interactive]
             [--manifest <manifest_file>]
             [--space <space needed>]
             [--parallel] [--prefix] [--release <release_version_string>]
             [--set {arch|cpu|tune}=XXX]
             [--set {cflags|ldflags|runtestflags|makeflags}=XXX]
             [--set {languages}={c|c++|fortran|go|lto|objc|java|ada}]
             [--set {libc}={glibc|eglibc|newlib}]
             [--set {linker}={ld|gold}]
             [--set {package}={toolchain|gdb|sysroot}]
             [--snapshots <path>] [--tarball] [--tarbin] [--tarsrc] [--rpm]
             [--target {<target_triple>|''}] [--timeout <timeout_value>]
             [--usage]
             [{binutils|dejagnu|gcc|gmp|mpfr|mpc|eglibc|glibc|newlib}
               =<id|snapshot|url>]]

EOF
    return 0
}

help()
{
    # Format this section with 75 columns.
    cat << EOF
NAME

  ${abe} - the Linaro Toolchain Build Framework.

SYNOPSIS

EOF
    usage
    cat << EOF
KEY

  [--foo]         Optional switch
  [<foo>]         Optional user specified field
  <foo>           Non-optional user specified field
  {foo|bar|bat}   Non-optional choice field
  [{foo|bar|bat}] Optional choice field
  [foo]           Optional field
  ['']            Optional Empty field
  <>              Indicates when no directive is specified

DESCRIPTION

  ${abe} is a toolchain build framework. The primary purpose of
  ${abe} is to unify the method used to build cross, native, and
  Canadian-cross GNU toolchains.

PRECONDITIONS

  Autoconf (configure) must be run in order to construct the build
  directory and host.conf file before it is valid to run ${abe}.

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

  --check [{all|glibc|gcc|gdb|binutils}]

                For cross builds this will run package unit-tests on native
                hardware

                glibc|gcc|gdb|binutils
                        Run make check on the specified package only.
                all
                        Run make check on all supported packages.
                <>
                        If there is no directive it's the same as 'all' and
                        make check will be run on all supported packages.

  --checkout {<package>[~branch][@revision]|all}

               <package>[~branch][@revision]
                       This will checkout the package designated by the
                       <package> source.conf identifier with an optional
                       branch and/or revision designation.

               all
                       This will checkout all of the sources for a
                       complete build as specified by the config/ .conf
                       files.

  --disable {install|update|make_docs|building}

		install
                        Disable the make install stage of packages, which
                        is enabled by default.

		update
			Don't update source repositories before building.

                make_docs
                        Don't make the toolchain package documentation.

                building
                        Don't build anything. This is only useful when
                        using --tarbin, --tarsrc, or --tarball.
                        This is a debugging aid for developers, as it
                        assumes everything built correctly...
                        
  --dryrun	Run as much of ${abe} as possible without doing any
		actual configuration, building, or installing.

  --dump	Dump configuration file information for this build.

  --enable {bootstrap|gerrit}

                bootstrap
                        Enable gcc bootstrapping, which is disabled by
                        default.

                gerrit
                        Enable posting comments to Gerrit on the build
                        progress.

  --excludecheck {all|glibc|gcc|gdb|binutils}

                {glibc|gcc|gdb|binutils}
                        When used with --check this will remove the
                        specified package from having its unit-tests
                        executed during make check.  When used without
                        --check this will do nothing.

                all
                        When 'all' is specified no unit tests will be run
                        regardless of what was specified with --check.

                <>
                        --excludecheck requires an input directive.
                        Calling --excludecheck without a directive is an
                        error that will cause ${abe} to abort.

                Note: This may be called several times and all valid
                packages will be removed from the list of packages to have
                unit-test executed against, e.g., the following will only
                leave glibc and gcc to have unit-tests executed:

                --check all --excludecheck gdb --excludecheck binutils

                Note: All --excludecheck packages are processed after all
                --check packages, e.g., the following will NOT check gdb:

                --check gdb --excludecheck gdb --check gdb

  --extraconfig <tool>=<path>
                Use an additional configuration file for tool.

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

  --manifest <manifest_file>

  		Source the <manifest_file> to override the default
		configuration. This is used to reproduce an identical
		toolchain build from manifest files generated by a previous
		build. 

  --space <space_needed>

		Specify how much space (in KB) to check for in the build
		area.
		Defaults to enough space to bootstrap full toolchain.
		Set to 0 to skip the space check.

  --parallel	Set the make flags for parallel builds.

  --prefix	Set an alternate value for the prefix used to configure.

  --release <release_version_string>

                The build system will package the resulting toolchain as a
                release with the <release_version_string> embedded, e.g., if
                <release_version_string> is "2014.10-1" the GCC 4.9 tarball
                that is released will be named:

                    gcc-linaro-4.9-2014.10-1.tar.xz

  --set		{arch|cpu|tune}=XXX

		This overrides the default values used for the configure
		options --with-arch, --with-cpu, and --with-tune.

		For most targets, specifying --set cpu is equivalent to
		specifying both --set arch and --set tune, and hence those
		options should not be used with --set cpu.

		Note: There is no cross-checking to make sure that the passed
		--target value is compatible with the passed arch, cpu, or
		tune value.

  --set		{cflags|ldflags|runtestflags|makeflags}=XXX
                This overrides the default values used for CFLAGS,
                LDFLAGS, RUNTESTFLAGS, and MAKEFLAGS.

  --set		{languages}={c|c++|fortran|go|lto|objc|java|ada}
                This changes the default set of GCC front ends that get built.
                The default set for most platforms is c, c++, go, fortran,
                and lto.

  --set		{libc}={glibc|eglibc|newlib}

		The default value is stored in lib/global.sh.  This
		setting overrides the default.  Specifying a libc
		other than newlib on baremetal targets is an error.

  --set		{linker}={ld|gold}

                The default is to build the older GNU linker. This option
                changes the linker to Gold, which is required for some C++
                projects, including Andriod and Chromium.
 
  --set		{package}={toolchain|gdb|sysroot}
                This limits the default set of packages to the specified set.
                This only applies to the --tarbin, --tarsrc, and --tarballs
                command lines options, and are primarily to be only used by
                developers.

  --snapshots <path>
  		Use an alternative path to a local snapshots directory. 

  --stage {1|2}
                If --build <*gcc*> is passed, then --stage {1|2} will cause
                stage1 or stage2 of gcc to be built.  If --build <*gcc*> is
                not passed then --stage {1|2} does nothing.

  --tarball
  		Build source and binary tarballs after a successful build.

  --tarbin
  		Build binary tarballs after a successful build.

  --tarsrc
  		Build source tarballs after a successful build.

  --rpm
		Build binary RPM package after a successful build.

  --target	{<target_triple>|''}

		This sets the target triple.  The GNU target triple
		represents where the binaries built by the toolchain will
		execute.

		''
			Build the toolchain native to the hardware that
			${abe} is running on.
                 
		<target_triple>

			x86_64-linux-gnu
			arm-linux-gnueabi
			arm-linux-gnueabihf
			arm-none-eabi
			armeb-none-eabi
			armeb-linux-gnueabihf
			aarch64-linux-gnu
			aarch64-none-elf
			aarch64_be-none-elf
			aarch64_be-linux-gnu

			If <target_triple> is not the same as the hardware
			that ${abe} is running on then build the
			toolchain as a cross toolchain.

  --timeout <timeout_value>

                Use <timeout_value> as the timeout value for wget when
                fetching snapshot packages.

  --usage	Display synopsis information.

   [{binutils|dejagnu|gcc|gmp|mpfr|mpc|eglibc|glibc|newlib}=<id|snapshot|url>]

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

    ${abe} --target arm-linux-gnueabihf --build all

  Build a Linux cross toolchain with glibc as the clibrary:

    ${abe} --target arm-linux-gnueabihf --set libc=glibc --build all

  Build a bare metal toolchain:

    ${abe} --target aarch64-none-elf --build all

PRECONDITION FILES

  ~/.aberc		${abe} user specific configuration file

  host.conf		Generated by configure from host.conf.in.

ABE GENERATED FILES AND DIRECTORIES

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
    echo "Run \"${abe} --help\" for detailed usage information."
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
abe="`which $0`"
topdir="${abe_path}"
abe="`basename $0`"

. "${topdir}/lib/common.sh" || exit 1

# this is used to launch builds of dependant components
command_line_arguments=$*

# Initialize an entry in the data array for components
collect_data abe

#
# These functions actually do something
#

# Determine whether the clibrary setting passed as $1 is compatible with the
# designated target.
crosscheck_clibrary_target()
{
    local test_clibrary="$1"
    local test_target="$2"
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


# Returns '0' if $package ($1) is in the list of all_unit_tests.  Returns '1'
# if not found.
crosscheck_unit_test()
{
    local package="$1"

    # 'all' is an acceptable equivalent to the full string of packages.
    if test x"${package}" = x"all"; then
	return 0
    fi

    # We have to search for exact matches.  We don't want to match on 'gd' or
    # 'g', but rather 'gdb' and 'gcc' or the results will be unpredictable.
    for i in ${all_unit_tests}; do
        if test x"$i" = x"${package}"; then
            return 0
	fi
    done

    return 1
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
	linker|lin*)
	    override_linker="${setting}"
	    notice "Overriding the default linker to ${setting}"
	    return 0
	    ;;
	cflags|cf*)
	    override_cflags="${setting}"
	    notice "Overriding ${setting} to CFLAGS"
	    return 0
	    ;;
	libc|lib*)
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
	arch)
	    override_arch="${setting}"
	    notice "Overriding default --with-arch to ${setting}"
	    return 0
	    ;;
	cpu)
	    override_cpu="${setting}"
	    notice "Overriding default --with-cpu to ${setting}"
	    return 0
	    ;;
	tune)
	    override_tune="${setting}"
	    notice "Overriding default --with-tune to ${setting}"
	    return 0
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
    local switch="$1"
    local long="$2"
    local short="$3"
    local directive="$4"

    if test `echo ${switch} | grep -c "\-${short}.*=" ` -gt 0; then
	error "A '=' is invalid after --${long}.  A space is expected between the switch and the directive."
    elif test x"$directive" = x; then
	error "--${long} requires a directive.  See --usage for details.' "
    elif test `echo ${directive} | egrep -c "^\-+"` -gt 0; then
	error "--${long} requires a directive.  ${abe} found the next -- switch.  See --usage for details.' "
    else
	return 0
    fi
    build_failure
}

# Some switches allow an optional following directive. We need to make sure
# they don't parse the -- of the following switch.  If there isnt a following
# directive this function will echo the default ($5).  This function can't
# distinguish whether --foo--bar is valid, so it will return 1 in this case
# and consume the --bar as part of --foo.
#
# Return Value(s):
#	stdout - caller provided directive or default
#	0 - if $directive is provided by caller
#	1 - if $directive is not provided by caller
#	exit - Execution will abort if the input is invalid.
check_optional_directive()
{
    local switch="$1"
    local long="$2"
    local short="$3"
    local directive="$4"
    local default="$5"

    if test `echo ${switch} | grep -c "\-${short}.*=" ` -gt 0; then
	error "A '=' is invalid after --${long}.  A space is expected between the switch and the directive."
	build_failure
    elif test x"$directive" = x; then
	notice "There is no directive accompanying this switch.  Using --$long $default."
	directive="$default"
	echo "$directive"
	return 1
    elif test `echo ${directive} | egrep -c "^\-+"` -gt 0; then
	notice "There is no directive accompanying this switch.  Using --$long $default."
	directive="$default"
	echo "$directive"
	return 1
    fi
    echo "$directive"
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

    if test x"${release}" != x; then
        echo "Release Name       ${release}"
    fi

    if test x"${do_makecheck}" = x"all"; then
        echo "check              ${do_makecheck} {$all_unit_tests}"
    elif test ! -z "${do_makecheck}"; then
        echo "check              ${do_makecheck}"
    fi

    if test x"${do_excludecheck}" != x; then
        echo "excludecheck       ${do_excludecheck}"
    fi

    if test x"${runtests}" != x; then
        echo "checking           ${runtests}"
    else
        echo "checking           {none}"
    fi
}

export PATH="${local_builds}/destdir/${build}/bin:$PATH"

# do_ switches are commands that should be executed after processing all
# other switches.
do_dump=
do_checkout=
do_makecheck=
do_excludecheck=
do_build=
do_build_stage=stage2

declare -A extraconfig

# Process the multiple command line arguments
while test $# -gt 0; do
    # Get a URL for the source code for this toolchain component. The
    # URL can be either for a source tarball, or a checkout via svn, bzr,
    # or git
    case "$1" in
        --fileserver)
            warning "The --fileserver option has been removed, so ignoring it."
	    continue
	    ;;
	--bu*|-bu*)			# build
	    check_directive $1 build bu $2
   
	    # Save and process this after all other elements have been processed.
	    do_build="$2"

	    # Shift off the 'all' or the package identifier.
	    shift
	    ;;
	--checkout*|-checkout*)
	    check_directive $1 checkout "checkout" $2
	    # Save and process this after all other elements have been processed.
	    do_checkout="$2"

	    # Shift off the 'all' or the package identifier.
	    shift
	    ;;
	# This is after --checkout because we want to catch every other usage
	# of check* but NOT 'checkout'.
	--check*|-check*)
	    tmp_do_makecheck=
	    tmp_do_makecheck="`check_optional_directive $1 check "check" "$2" "all"`"
	    ret=$?

	    # do_makecheck already contains the directive or 'all'.  This
	    # test determines whether we need to strip off an additional
	    # parameter from the command line argument if directive was
	    # provided.
	    if test $ret -eq 0; then
	      shift;
            fi

	    crosscheck_unit_test ${tmp_do_makecheck}
	    ret=$?
	    if test $ret -eq 1; then
		error "${tmp_do_makecheck} is an invalid package name to pass to --check. The choices are {all $all_unit_tests}."
		build_failure
	    fi

	    # Accumulate --check packages from consecutive --check calls.  Yes
	    # there might be potential duplicates but we'll prune those later.
	    # parse later.
	    do_makecheck=${do_makecheck:+${do_makecheck} }${tmp_do_makecheck}
	    ;;
	# This will exclude an individual package from the list of packages
	# to run make check (unit-test) against.
        --excludecheck*|-excludecheck*)
	    check_directive $1 excludecheck "excludecheck" $2

	    # Verify that $2 is a valid option to exclude.
	    crosscheck_unit_test $2
	    if test $? -eq 1; then
		error "${2} is an invalid package name to pass to --excludecheck. The choices are {all $all_unit_tests}."
		build_failure
	    fi

	    # Concatenate this onto the list of packages to exclude from make check.
            do_excludecheck="${do_excludecheck:+${do_excludecheck} }$2"

	    shift
	    ;;
	--extraconfig|-extraconfig)
	    check_directive $1 extraconfig extraconfig $2
	    extraconfig_tool=`echo $2 | sed 's/\(.*\)=.*/\1/'`
	    extraconfig_val=`echo $2 | sed 's/.*=\(.*\)/\1/'`
	    extraconfig[${extraconfig_tool}]="${extraconfig_val}"
	    shift
            ;;
	--host|-h*)
	    host=$2
	    shift
	    ;;
	--manifest*|-m*)
	    check_directive $1 manifest "m" $2
	    import_manifest $2
	    if test $? -gt 0; then
	        build_failure
	    fi
	    shift
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
	    check_directive $1 set "set" "$2"

	    # Test if --target follows the --set command put --set and it's
	    # directive on to the back of the inputs.  This is because clibrary
	    # validity depends on the target.
	    if test "`echo $@ | grep -c "\-targ.*"`" -gt 0; then
		# Push $1 and $2 onto the back of the inputs for later processing.
		set -- "$@" "$1" "$2"
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
	--sp*|-sp*)
	    check_directive $1 space space $2
	    space_needed=$2
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
	--rpm|-rpm*)
	    rpmbin=yes
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
		    gerrit_trigger="${value}"
		    # Initialize settings for gerrit
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
	    echo "Run \"${abe} --help\" for detailed usage information."
	    exit 0
	    ;;
	*)
	    # Look for unsupported -<foo> or --<foo> directives.
	    if test `echo $1 | grep -Ec "^-+"` -gt 0; then
		error "${1}: Directive not supported.  See ${abe} --help for supported options."
		build_failure
	    fi

	    # Test for <foo>= specifiers
	    if test `echo $1 | grep -c =` -gt 0; then
		name="`echo $1 | cut -d '=' -f 1`"
		value="`echo $1 | cut -d '=' -f 2`"
		case ${name} in
		    b*|binutils)
			binutils_version="`echo ${value}`"
			;;
		    dejagnu)
			dejagnu_version="${value}"
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
                    lin*|linux)
			linux_version="${value}"
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
				error "FIXME: Execution should never reach this point."
				build_failure
				;;
			esac
			;;
		    *)
			# This will catch unsupported component specifiers like <foo>=
			error "${name}: Component specified not supported.  See ${abe} --help for supported components."
			build_failure
			;;
		esac
	    else
		# This will catch dangling words like <foo> that don't contain
		# --<foo> and don't contain <foo>=
		error "$1: Command not recognized.  See ${abe} --help for supported options."
		build_failure
	    fi
            ;;
    esac
    if test $# -gt 0; then
	shift
    fi
done

# Check disk space. Each builds needs about 3.8G free
if test x"${space_needed}" = x; then
  space_needed=4194304
fi
if test ${space_needed} -gt 0; then
  df="`df ${abe_top} | tail -1 | tr -s ' ' | cut -d ' ' -f 4`"
  if test ${df} -lt ${space_needed}; then
      error "Not enough disk space!"
      exit 1
  fi
fi

# if test x"${tarbin}" = x"yes" -o x"${tarsrc}" = x"yes"; then
#     warning "No testsuite will be run when building tarballs!"
#     runtests=no
# fi

# If triggered by Gerrit, use the REST API. This assumes the lava-bot account
# is supported by Gerrit, and the public SSH key is available. 
if test x"${GERRIT_CHANGE_ID}" != x -o x"${gerrit_trigger}" = xyes; then
    eval `gerrit_info $HOME`
fi

if test x"${force}" = xyes -a x"$supdate" = xno; then
    warning "You have specified \"--force\" and \"--disable update\"."
    echo "         Using \"--force\" overrides \"--disable update\".  Sources will be redownloaded."
fi

if test ! -z "${do_makecheck}"; then
    # If we encounter 'all' in ${do_makecheck} anywhere we just overwrite
    # runtests with ${all_unit_tests} and ignore the rest.
    test_all="${do_makecheck//all/}"

    if test x"${test_all}" != x"${do_makecheck}"; then
	runtests="${all_unit_tests}"
    else
	# Don't accumulate any duplicates.
        for i in ${do_makecheck}; do
	    # Remove it if it's already there
	    runtests=${runtests//${i}/}
	    # Remove any redundant whitespace
	    runtests=${runtests//  /}
	    # Reinsert it if it was already in the list.
            runtests="${runtests:+${runtests} }${i}"
        done
    fi
fi

if test ! -z "${do_excludecheck}"; then

    # If we encounter 'all' in ${do_excludecheck} anywhere we just
    # empty out runtests because 'all' trumps everything.
    exclude_all="${do_excludecheck//all/}"
    if test x"${exclude_all}" != x"${do_excludecheck}"; then
        runtests=
    else
	#Remove excluded packages (stored in do_excludecheck) from ${runtests}
	for i in ${do_excludecheck}; do
	    runtests="${runtests//$i/}"
	    # Strip redundant white spaces
	    runtests="${runtests//  / }"
	done
	# Strip white space from the beginning of the string
	runtests=${runtests# }
	# Strip white space from the end of the string
	runtests=${runtests% }
    fi
fi

# Process 'dump' after we process 'check' and 'excludecheck' so that the list
# of tests to be evaluated is resolved before the dump.
if test ! -z ${do_dump}; then
    dump
fi

# Both checkout and build need the build dir.  'build' uses it for the builds
# but checkout uses it for file git locks.
if test ! -z "${do_checkout}" -o ! -z "${do_build}"; then
    # Sometimes a user might remove ${local_builds} to restart the build.
    if test ! -d "${local_builds}"; then
	warning "${local_builds} does not exist. Recreating build directory!"
	mkdir -p ${local_builds}
    fi
fi

if test ! -z ${do_checkout}; then
    if test x"${do_checkout}" != x"all"; then
	checkout ${do_checkout}
	if test $? -gt 0; then
	    error "--checkout ${url} failed."
	    build_failure
	fi
    else
	infrastructure="`grep ^depends ${topdir}/config/infrastructure.conf | tr -d '\"' | sed -e 's:^depends=::'`"
	builds="${infrastructure} binutils gcc gdb libc"
	checkout_all ${builds}
	if test $? -gt 0; then
	    error "--checkout all failed."
	    build_failure
	fi
    fi
fi

if test ! -z ${do_build}; then
    if test x"${do_build}" != x"all"; then
	buildingall=no
	gitinfo="${do_build}"
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
