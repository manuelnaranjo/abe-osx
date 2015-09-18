#!/bin/bash

# This script adds the Linux Foundation LSB RPM Repository to the system
# repositories list and then installs the LSB packages and keys.
# This script must be run as sudo

# Bail if any shell invocation fails.
set -e

root_UID=0
LSB_ARCH="x86_64"
LSB_VER="4.1"

# Only allow this script to be run by: sudo <script> and not as root or
# as the user.
if test -z $SUDO_USER; then
    if test $UID = $root_UID; then
	echo "Don't execute this script as root, use sudo!"
        exit 1
    elif test $UID != $root_UID; then
	echo "You don't have sufficient privileges to run this script.  Run this script under sudo."
	exit 1
    fi
fi

remote_keyfile="http://ftp.linuxfoundation.org/pub/lsb/keys-for-rpm/lsb-${LSB_VER}-release-key.asc"

# Always store this temporarily
tmpdir=$(su - $SUDO_USER -c "mktemp -d")
tmp_keyfile="${tmpdir}/$(basename ${remote_keyfile})"

# Don't execute this command under root permissions.
# Using -o forces this to overwrite the file if it's been downloaded multiple
# times.
su - $SUDO_USER -c "wget --quiet ${remote_keyfile} --output-document=${tmp_keyfile}"

# Looking for "PGP public key block"
if test x"$(file ${tmp_keyfile} | awk -F ' ' '{ print $2 }')" != x"PGP"; then
    echo "Keyfile: ${tmp_keyfile} downloaded from ${remote_keyfile} is not a PGP public key block."
    exit 1
fi

# rpm won't complain if the key is already imported.
rpm --import ${tmp_keyfile}

# Remove the keyfile, no priveleged permissions necessary.  Do it in stages so
# we don't have to use a force-recursive remove.
su - $SUDO_USER -c "rm ${tmp_keyfile}"
su - $SUDO_USER -c "rmdir ${tmpdir}"

# This is the REPO we want
# http://ftp.linuxfoundation.org/pub/lsb/repositories/yum/lsb-4.1/lsb-4.1-x86_64.repo

# Download the repomd files into /etc/yum.repos.d/ for the lsb rpms:
TOP="http://ftp.linuxfoundation.org/pub/lsb/repositories/yum/lsb-${LSB_VER}"
wget --quiet -O /etc/yum.repos.d/LSB-${LSB_VER}-${LSB_ARCH}.repo $TOP/lsb-${LSB_VER}-${LSB_ARCH}.repo

# Update the repo with the new lsb repository but don't force a system update
dnf --assumeyes --quiet makecache

# This will install all of the lsb packages
dnf --assumeyes install lsb-task-dist-testkit lsb-task-app-testkit lsb-task-sdk

exit 0
