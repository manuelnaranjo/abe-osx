#!/bin/sh

# load al the global varibles
. "$(dirname "$0")/lib/globals.sh" || exit 1
. "$(dirname "$0")/lib/fetch.sh" || exit 1
. "$(dirname "$0")/lib/configure.sh" || exit 1
. "$(dirname "$0")/lib/release.sh" || exit 1
. "$(dirname "$0")/lib/checkout.sh" || exit 1
. "$(dirname "$0")/lib/depend.sh" || exit 1
. "$(dirname "$0")/lib/make.sh" || exit 1
. "$(dirname "$0")/lib/test.sh" || exit 1

#
# All the set* functions set global variables used by the other functions.
# This way there can be some error recovery and handing.
#

set_build()
{
    echo "Set build architecture $1..."
    build="$1"
}

set_target()
{
    echo "Set target architecture $1..."
    target="$1"
}

set_snapshots()
{
    echo "Set snapshot URL $1..."
    snapshots="$1"
}

set_gcc()
{
    echo "Set gcc version $1..."
    gcc="$1"
}

set_binutils()
{
    echo "Set binutils version $1..."
    binutils="$1"
}

set_sysroot()
{
    echo "Set sysroot to $1..."
    sysroot="$1"
}

set_libc()
{
    echo "Set libc to $1..."
    libc="$1"
}

set_config()
{
    echo "Set config file to $1..."
    configfile="$1"
}

set_dbuser()
{
    echo "Setting MySQL user to $1..."
    dbuser="$1"
}

set_dbpasswd()
{
    echo "Setting MySQL password to $1..."
    dbpasswd="$1"
}

error()
{
    echo "ERROR: $1"
    exit 1
}

warning()
{
    echo "WARNING: $1"
}

notice()
{
    echo "NOTE: $1"
}
