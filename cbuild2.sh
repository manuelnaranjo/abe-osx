#!/bin/sh

# load commonly used functions
. "$(dirname "$0")/common.sh" || exit 1

# load the configure file produced by configure
. "${PWD}/host.conf" || exit 1

# this is used to launch builds of dependant components
command_line_arguments=$*

clean_build()
{
    echo "Cleaning build..."
}

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

    url="http://cbuild.validation.linaro.org/snapshots"
    # http://cbuild.validation.linaro.org/snapshots
    case $1 in
	base|b*)
	    #base="`ssh cbuild@toolchain64.lab ls -C1 /home/cbuild/var/snapshots/base/*.xz | sed -e 's:^.*/::'`"
	    base="`lynx -dump ${url}/base | grep "${url}" | sed -e 's:.*/::' -e 's:%2b:+:' | grep -v '^$'`"
	    echo "${base}"
	    ;;
	snapshots|s*)
	    #snapshots="`ssh cbuild@toolchain64.lab ls -C1 /home/cbuild/var/snapshots/*.{xz,bz2} | sed -e 's:^.*/::'`"
	    snapshots="`lynx -dump ${url} | grep "${url}" | sed -e 's:.*/::' -e 's:%2b:+:' | egrep -v "md5sums|base|prebuilt" | grep -v '^$'`"
	    echo "${snapshots}"
	    ;;
	prebuilt|p*)
	    #prebuilt="`ssh cbuild@toolchain64.lab ls -C1 /home/cbuild/var/snapshots/prebuilt/*.{xz,bz2} | sed -e 's:^.*/::'`"
	    #prebuilt="`lynx -dump ${url}/prebuilt | `"
	    echo "${prebuilt}"
	    ;;
    esac
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

# Build the project
build()
{
    echo "Building $1..."
}

# Run 'make check'
check()
{
    echo "Checking $1..."
}

# $1 - the parent directory to run make in
# $2 - the target to make, all is the default
make()
{
    dir=
    target=
    if test x"$1" != x; then
	dir="-C $1"
    fi

    target=
    if test x"$2" != x; then
	target="$2"
    fi

    echo "make ${MAKEFLAGS} ${dir} ${target}"
    make ${MAKEFLAGS} ${dir} ${target}
}

# Takes no arguments. Dumps all the important config data
dump()
{
    # These variables are always determined dynamically at run time
    echo "Build triplet is:  ${build}"
    echo "Target triplet is: ${target}"
    echo "GCC is:            ${gcc}"
    echo "Sysroot is:        ${sysroot}"

    # These variables have default values which we don't care about
    echo "Binutils is:       ${binutils}"
    echo "Libc is:           ${libc}"
    echo "Config file is:    ${configfile}"
    echo "Snapshot URL is:   ${snapshots}"
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
    echo "  --libc {newlib,eglibc,glibc} (C library to use)"
#        echo "  --list {gcc,binutils,libc} (list possible values for component versions)"
    echo "  --list {base,prebuilt,snapshots} (list possible values for component versions)"
    echo "  --set {gcc,binutils,libc,latest}=XXX (change config file setting)"
    echo "  --binutils (binutils version to use, default $PATH)"
    echo "  --gcc (gcc version to use, default $PATH)"
    echo "  --config XXX (alternate config file)"
    echo "  --clean (clean a previous build, default is to start where it left off)"
    echo "  --dispatch (run on LAVA build farm, probably remote)"
    echo "  --sysroot XXX (specify path to alternate sysroot)"
    echo "  --db-user XXX (specify MySQL user"
    echo "  --db-passwd XXX (specify MySQL password)"
    echo "  --dump (dump the values in the config file)"
    echo "  --dostep XXX (fetch,extract,configure,build,check)"
    echo "  --clobber (force files to be downloaded even when they exist)"
    exit 1
}

# get_build_machine_info

# Process the multiple command line arguments
while test $# -gt 0; do
    case "$1" in
	--build)
            set_build $2
	    shift
            ;;
	--fetch)
            fetch $2
	    shift
            ;;
	--target)
            set_target $2
	    shift
            ;;
	--sysroot)
            set_sysroot $2
	    shift
            ;;
	--binutils)
            set_binutils $2
	    shift
            ;;
	--clean)
            clean_build $2
	    shift
            ;;
	--config)
            set_config $2
	    shift
            ;;
	--gcc)
            set_gcc $2
	    shift
            ;;
	--libc)
            set_libc $2
	    shift
            ;;
	--list)
            get_list $2
	    shift
            ;;
	--dispatch)
            dispatch $2
	    shift
            ;;
	--snapshots)
            set_snapshots $2
	    shift
            ;;
	--db-user)
            set_dbuser $2
	    shift
            ;;
	--db-passwd)
            set_dbpasswd $2
	    shift
            ;;
	--dump)
            dump $2
	    shift
            ;;
	--dostep)
            case $2 in
		fetch)
		    fetch $3   
		    ;;
		extract)
		    extract $3
		    ;;
		configure)
		    configure $3
		    ;;
		build)
		    build $3
		    ;;
		check)
		    make_check $3
		    ;;
		*)
		    ;;
            esac
	    shift
            ;;
	--clobber)
            clobber=yes
            ;;
	--help)
            usage
            ;;
	*)
	    #usage
            ;;
    esac
    shift
done
