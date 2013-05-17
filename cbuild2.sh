#!/bin/sh

# load commonly used functions
. "$(dirname "$0")/common.sh" || exit 1

clean_build()
{
    echo "Cleaning build..."
}

#
# These functions actually do something
#
get_list()
{
    echo "Get version list for $1..."
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

# fetch a tarball from the remote snapshot server or local directory
fetch()
{
    echo "Fetching $1..."
    file="`echo $1 | sed -e 's:^.*//:/:'`"
    case "$1" in
	file:*)
	    echo "Local File URL: $file"
	    if test ! -f ${file}; then
		echo "ERROR: ${file} doesn't exist!"
	    fi
	    ;;
	http:*|https:|ftp*)
	    echo "Remote file"
	    echo "FIXME: wget -c $1 --directory-prefix=${snapshots}"
	    ;;
	*)
	    if test ! -f ${file}; then
		if test ! -f ${snapshots}/${file}; then
		    echo "ERROR: $file doesn't exist!"
		fi
		file="${snapshots}/${file}"
	    else
		file="${file}"
	    fi
	    echo "Local File: $file"
	    ;;
    esac
}

# decompress and untar a fetched tarball
extract()
{
    extractor=
    taropt=
    echo "Uncompressing and untarring $1 into $2..."

    # Figure out how to decompress a tarball
    case "$1" in
	*.xz)
	    echo "XZ File"
	    extractor="xz -d "
	    taropt="J"
	    ;;
	*.bz*)
	    echo "bzip2 file"
	    extractor="bzip2 -d "
	    taropt="j"
	    ;;
	*.gz)
	    echo "Gzip file"
	    extractor="gunzip "
	    taropt="x"
	    ;;
	*) ;;
    esac

    taropts="${taropt}vf"
    if test x"$2" != x; then
       taropts="${taropts} -C$2"
    fi

    out="`tar ${taropts} $1`"
}

# $1 - The dccs system to use
# $2 - The parent directory for the sources
# $3 - The URL to fetch from
# $4 - The branch to fetch
checkout_source()
{
    dir="$2"
    url="$3"
    
    if test x"$4" x= x; then
	branch=""
    else
	branch="$4"
    fi

    case $1 in 
	git)
	    dccs="git clone "
	    ;;
	svn)
	    dccs="svn checkout "
	    ;;
	bzr)
	    dccs="bzr branch "
	    ;;
	*) ;;
    esac

    (cd $2 && ${dccs} ${url} ${branch})
}

# This updates an existing checked out source tree 
update_source()
{
    # Figure out which DCCS it uses
    dccs=
    if test -f .git; then
	dccs="git pull"
    fi
    if test -f .bzr; then
	dccs="bzr pull"
    fi
    if test -f .svn; then
	dccs="svn update"
    fi
    if test x"${dccs}" != x; then
	echo "Update sources with: ${dccs}"
    else
	echo "ERROR: can't determine DCCS!"
	return
    fi

    # update the source
    (cd $1 && ${dccs})
}

dispatch()
{
    echo "Dispatching LAVA build on $1..."
}

# Configure a source directory
# $1 - directory to run configure in
# $2 - the source directory
# $3 - configure options
configure()
{
    dir=""
    opts=""
    srcdir=""
    if test x"$1" != x; then
	echo "ERROR: no directory soecified!"
    else
	dir="$1"
    fi
    if test x"$2" != x; then
	echo "WARNING: no srcdir specified!"
	srcdir="./"
    else
	srcdir="$2"
    fi
    if test x"$3" != x; then
	opts="${opts} $3"
    fi
    echo "Configuring with $1..."

    (cd ${dir} && ${srcdir}/configure ${opts})
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

get_build_machine_info
# get_build_machine_info gnashdev.org

case "$1" in
    --build)
        set_build $2
        ;;
    --fetch)
        fetch $2
        ;;
    --target)
        set_target $2
        ;;
    --sysroot)
        set_sysroot $2
        ;;
    --binutils)
        set_binutils $2
        ;;
    --clean)
        clean_build $2
        ;;
    --config)
        set_config $2
        ;;
    --gcc)
        set_gcc $2
        ;;
    --libc)
        set_libc $2
        ;;
    --list)
        get_list $2
        ;;
    --dispatch)
        dispatch $2
        ;;
    --snapshots)
        set_snapshots $2
        ;;
    --db-user)
        set_dbuser $2
        ;;
    --db-passwd)
        set_dbpasswd $2
        ;;
    --dump)
        dump $2
        ;;
    *)
        echo "Usage: $0 "
        echo "  --build (architecture for the build machine, default native)"
        echo "  --target (architecture for the target machine, default native)"
        echo "  --snapshots XXX (URL of remote host or local directory)"
        echo "  --libc {newlib,eglibc,glibc} (C library to use)"
        echo "  --list {gcc,binutils,libc} (list possible values for component versions)"
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
        exit 1
        ;;
esac

