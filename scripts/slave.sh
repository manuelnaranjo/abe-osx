#!/bin/bash

# Update all the packages we need
apt-get update

# Optionally use a package list from another machine of the same distribution and type
# apt-get install `cat /tmp/packages.lst`
apt-get build-dep gcc gdb
apt-get install texinfo git-core build-essential openssh-server openjdk-6-jre-headless iptables flex bison autogen autoconf automake libtool dejagnu lsyncd gawk gcc-multilib g++-multilib libncurses5-dev lsb ccrypt nagios-nrpe-server qemu sendmail

# Move git-new-workdir to someplace so we can use it.
cp /usr/share/doc/git/contrib/workdir/git-new-workdir /usr/local/bin/
chmod a+x /usr/local/bin/git-new-workdir

# Add the user we use for all Jenkins builds
adduser buildslave
mkdir -p /opt/linaro /linaro/shared/snapshots
chown -R buildslave:buildslave /linaro/
chown -R buildslave:buildslave /opt/

# Update hosts so we can find this machine via HTTP
echo "88.98.47.97	 cbuild.validation.linaro.org" >> /etc/hosts

# Setup default SSH config so builds can use SSH to access the targets for testing. This
# is setup for external access to the TCWG build farm, which go through a proxy, and is
# unnecessary for a build machine in the TCWG internal subnet, although this version can
# be used there as well.
mkdir -p /home/buildslave/.ssh/
cp ssh-config.txt /home/buildslave/.ssh/

# You then need to copy /home/buildslave/.ssh/id_* from an existing slave
# to the new one

# If running make 3.81, you may have to upgrade to make 4.0, as there is a
# bug effecting eglibc.

# You also need to install the ARM Fastmodel for AARCH64 big-endian testing. This
# lives in /linaro/foundation-model on all existing machines, so can just be
# copied to the same location.

# Qualcom Snapdragon

login as linaro linaro

# Remove the desktop packahes, we don't need them and that leaves 728M 
# of free disk space
# Remove gnome
dpkg -l | grep "^ii.*gnome" | cut -d ' ' -f 3 > xx
apt-get remove `cat xx`
rm xx
# Remove Unity
dpkg -l | grep "^ii.*unity" | cut -d ' ' -f 3 > xx
apt-get remove `cat xx`
apt-get clean all
apt-get update
