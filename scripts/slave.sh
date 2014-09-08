#!/bin/bash

# Update all the packages we need
apt-get update
# Optionally use a package list from another machine
#apt-get install `cat /tmp/packages.lst`
apt-get build-dep gcc gdb
apt-get install texinfo git-core build-essential openssh-server openjdk-6-jre-headless iptables flex bison autogen autoconf automake libtool dejagnu lsyncd gawk gcc-multilib g++-multilib libncurses5-dev lsb ccrypt nagios-nrpe-server

# Add the user we use for all Jenkins builds
adduser buildslave
mkdir -p /opt/linaro /linaro/shared/snapshots
chown -R buildslave:buildslave /linaro/
chown -R buildslave:buildslave /opt/

# Move git-new-workdir to someplace so we can use it.
cp /usr/share/doc/git/contrib/workdir/git-new-workdir /usr/local/bin/
chmod a+x /usr/local/bin/git-new-workdir

# Update hosts so we can find this machine via HTTP
echo "88.98.47.97	 cbuild.validation.linaro.org" >> /etc/hosts

# Setup default SSH config so builds can use SSH to access the targets for testing
mkdir -p /home/buildslave/.ssh/
cp ssh-config.txt /home/buildslave/.ssh/
