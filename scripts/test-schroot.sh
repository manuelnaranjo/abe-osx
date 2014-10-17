#!/bin/bash

set -e

arch="native"
begin_session=false
schroot_master=""
shared_dir=""
board_exp=""
finish_session=false
gen_schroot=false
sysroot=""
ssh_master=false
target_ssh_opts=""
host_ssh_opts=""
multilib_path="lib"

while getopts "a:bc:d:e:fgh:l:mo:p:qv" OPTION; do
    case $OPTION in
	a) arch=$OPTARG ;;
	b) begin_session=true ;;
	c) schroot_master="$OPTARG" ;;
	d) shared_dir=$OPTARG ;;
	e) board_exp="$OPTARG" ;;
	f) finish_session=true ;;
	g) gen_schroot=true ;;
	h) multilib_path="$OPTARG" ;;
	l) sysroot=$OPTARG ;;
	m) ssh_master=true ;;
	o) target_ssh_opts="$OPTARG" ;;
	p) host_ssh_opts="$OPTARG" ;;
	q) exec > /dev/null ;;
	v) set -x ;;
    esac
done
shift $((OPTIND-1))

target="${1%:*}"
port="${1#*:}"

triplet_to_deb_arch()
{
    set -e
    case "$1" in
	aarch64-*linux-gnu) echo arm64 ;;
	arm-*linux-gnueabi*) echo armhf ;;
	i686-*linux-gnu) echo i386 ;;
	x86_64-*linux-gnu) echo amd64 ;;
	*) return 1 ;;
    esac
}

triplet_to_deb_dist()
{
    set -e
    case "$arch" in
	aarch64-*linux-gnu) echo trusty ;;
	arm-*linux-gnueabi*) echo trusty ;;
	i686-*linux-gnu) echo trusty ;;
	x86_64-*linux-gnu) echo trusty ;;
	*) return 1 ;;
    esac
}

if [ -z "$target" ]; then
    echo ERROR: no target specified
    exit 1
fi

if [ -z "$port" ]; then
    port="22"
fi

use_qemu=false
if ! triplet_to_deb_arch "$arch" >/dev/null 2>&1; then
    use_qemu=true
    arch="native"
fi

if [ "x$arch" = "xnative" ]; then
    cpu="$(ssh $target uname -m)"
    case "$cpu" in
	aarch64) arch=aarch64-linux-gnu ;;
	armv7l) arch=arm-linux-gnueabihf ;;
	armv7*) arch=arm-linux-gnueabi ;;
	i686) arch=i686-linux-gnu ;;
	x86_64) arch=x86_64-linux-gnu ;;
	*)
	    echo "ERROR: unrecognized native target $cpu"
	    exit 1
	    ;;
    esac
fi

if [ "x$board_exp" != "x" ] ; then
    lava_json="$(grep "^set_board_info lava_json " $board_exp | sed -e "s/^set_board_info lava_json //")"
    if [ "x$lava_json" != "x" ] && $begin_session; then
	job_id="$(lava-tool submit-job http://maxim-kuvyrkov@validation.linaro.org/RPC2/ "$lava_json" | sed -e "s/submitted as job id: //")"
	while sleep 60; do
	    if lava-tool job-output -o - http://maxim-kuvyrkov@validation.linaro.org/RPC2/ $job_id | grep "^Hacking session active" >/dev/null; then
		lava_ssh_opts="$(lava-tool job-output -o - http://maxim-kuvyrkov@validation.linaro.org/RPC2/ $job_id | grep -a "^Please connect to" | sed -e "s/.* ssh \(.*\) \([^ ]*\) (.*$/\1/")"
		lava_target="$(lava-tool job-output -o - http://maxim-kuvyrkov@validation.linaro.org/RPC2/ $job_id | grep -a "^Please connect to" | sed -e "s/.* ssh \(.*\) \([^ ]*\) (.*$/\2/")"
		sed -i -e "s/^set_board_info hostname .*/set_board_info hostname $lava_target/" "$board_exp"
		echo "set_board_info lava_ssh_opts \"$lava_ssh_opts\"" >> "$board_exp"
		echo "set_board_info lava_job_id $job_id" >> "$board_exp"

		target="$lava_target"
		target_ssh_opts="$target_ssh_opts $lava_ssh_opts"
		break
	    fi
	done
    fi
fi

orig_target_ssh_opts="$target_ssh_opts"
target_ssh_opts="$target_ssh_opts -o ControlMaster=auto -o ControlPersist=1m -o ControlPath=/tmp/ssh-tcwg-test-$port-%u-%r@%h:%p"

deb_arch="$(triplet_to_deb_arch $arch)"
deb_dist="$(triplet_to_deb_dist $arch)"

schroot_id=tcwg-test-$deb_arch-$deb_dist

schroot="ssh $target_ssh_opts $target schroot -r -c session:tcwg-test-$port -d / -u root --"
rsh_opts="$target_ssh_opts -o Port=$port -o StrictHostKeyChecking=no"
rsh="ssh $rsh_opts"
user="$(ssh $target_ssh_opts $target echo \$USER)"
home="$(ssh $target_ssh_opts $target pwd)"

if $gen_schroot; then
    chroot=/tmp/$schroot_id.$$

    # Make sure machine in the lab agree on what time it is.
    ssh $target_ssh_opts $target \
	sudo ntpdate pool.ntp.org >/dev/null 2>&1 || true

    ssh $target_ssh_opts $target \
	sudo rm -rf $chroot
    ssh $target_ssh_opts $target \
	sudo debootstrap \
	--arch=$deb_arch \
	--variant=minbase \
	--include=iptables,openssh-server,rsync,sshfs \
	--foreign \
	$deb_dist $chroot
    # Copy qemu binaries to handle foreign schroots.
    ssh $target_ssh_opts $target \
	sudo cp /usr/bin/qemu-\*-static $chroot/usr/bin/ || true
    ssh $target_ssh_opts $target \
	sudo chroot $chroot ./debootstrap/debootstrap --second-stage &
    pid=$!
    while sleep 10; do
	if ! ssh $target_ssh_opts $target ps -e -o cmd= | grep -v "grep\|ssh" | grep "./debootstrap/debootstrap --second-stage" >/dev/null; then
	    kill $pid || true
	    break
	fi
    done

    # Configure APT sources.
    case "$deb_arch" in
	amd64) deb_mirror="http://archive.ubuntu.com/ubuntu/" ;;
	*) deb_mirror="http://ports.ubuntu.com/ubuntu-ports/" ;;
    esac
    ssh $target_ssh_opts $target \
	sudo chroot $chroot bash -c "\"for i in '' -updates -security -backports; do for j in '' -src; do echo deb\\\$j $deb_mirror $deb_dist\\\$i main restricted universe multiverse >> /etc/apt/sources.list; done; done\""

    case "$deb_arch" in
	amd64) extra_packages="qemu-user-static gdb gdbserver" ;;
	*) extra_packages="gdb gdbserver" ;;
    esac

    if ! [ -z "$extra_packages" ]; then
	ssh $target_ssh_opts $target \
	    sudo chroot $chroot apt-get update
	ssh $target_ssh_opts $target \
	    sudo chroot $chroot apt-get install -y "$extra_packages"
    fi

    if [ "$(echo "$extra_packages" | grep -c qemu-user-static)" = "0" ]; then
	ssh $target_ssh_opts $target \
	    sudo rm -f $chroot/usr/bin/qemu-\*-static
    fi

    # Install foundation model in x86_64 chroots for bare-metal testing
    if [ x"$deb_arch" = x"amd64" ]; then
	ssh $target_ssh_opts $target \
	    sudo mkdir -p $chroot/linaro/foundation-model/Foundation_v8pkg
	ssh $target_ssh_opts $target \
	    sudo rsync -a /linaro/foundation-model/Foundation_v8pkg/ $chroot/linaro/foundation-model/Foundation_v8pkg/
    fi

    ssh $target_ssh_opts $target \
	sudo mkdir -p /var/chroots/
    ssh $target_ssh_opts $target \
	sudo bash -c "\"cd $chroot && tar --one-file-system -czf /var/chroots/$schroot_id.tgz .\""

    ssh $target_ssh_opts $target \
	sudo rm -rf $chroot

    ssh $target_ssh_opts $target \
	sudo bash -c "\"cat > /etc/schroot/chroot.d/$schroot_id\"" <<EOF
[$schroot_id]
type=file
file=/var/chroots/$schroot_id.tgz
groups=buildslave,tcwg,users
root-groups=buildslave,tcwg,users
profile=tcwg-test
EOF

    if ! [ -z "$schroot_master" ]; then
	scp $target_ssh_opts $target:/var/chroots/$schroot_id.tgz $schroot_master/
	mkdir -p $schroot_master/chroot.d/
	scp $target_ssh_opts $target:/etc/schroot/chroot.d/$schroot_id $schroot_master/chroot.d/
    fi
fi

if ! [ -z "$schroot_master" ]; then
    # Make sure machine in the lab agree on what time it is.
    ssh $target_ssh_opts $target \
	sudo ntpdate pool.ntp.org >/dev/null 2>&1 || true

    ssh $target_ssh_opts $target \
	sudo mkdir -p /var/chroots/

    cat $schroot_master/$schroot_id.tgz | ssh $target_ssh_opts $target \
	sudo bash -c "\"cat > /var/chroots/$schroot_id.tgz\""
    cat $schroot_master/chroot.d/$schroot_id | ssh $target_ssh_opts $target \
	sudo bash -c "\"cat > /etc/schroot/chroot.d/$schroot_id\""

    (cd $schroot_master && tar -c tcwg-test/ | ssh $target_ssh_opts $target \
	sudo bash -c "\"cd /etc/schroot && rm -rf tcwg-test && tar -x && chown -R root:root tcwg-test/\"")
fi

if $begin_session; then
    ssh $target_ssh_opts $target schroot -b -c chroot:$schroot_id -n tcwg-test-$port -d /
    $schroot sh -c "\"echo $user - data $((1024*1024)) >> /etc/security/limits.conf\""
    # Set ssh port
    $schroot sed -i -e "\"s/^Port 22/Port $port/\"" /etc/ssh/sshd_config
    # Run as root
    $schroot sed -i -e "\"s/^UsePrivilegeSeparation yes/UsePrivilegeSeparation no/\"" /etc/ssh/sshd_config
    # Increase number of incoming connections from 10 to 256
    $schroot sed -i -e "\"/.*MaxStartups.*/d\"" -e "\"/.*MaxSesssions.*/d\"" /etc/ssh/sshd_config
    $schroot bash -c "\"echo \\\"MaxStartups 256\\\" >> /etc/ssh/sshd_config\""
    $schroot bash -c "\"echo \\\"MaxSessions 256\\\" >> /etc/ssh/sshd_config\""
    $schroot sed -i -e "'/check_for_upstart [0-9]/d'" /etc/init.d/ssh
    $schroot /etc/init.d/ssh start
    # Crouton needs firewall rule.
    $schroot iptables -I INPUT -p tcp --dport $port -j ACCEPT || true
    # Debian (but not Ubuntu) has wrong permissions on /bin/fusermount.
    $schroot chmod +x /bin/fusermount || true

    $schroot mkdir -p /root/.ssh
    ssh $target_ssh_opts $target cat .ssh/authorized_keys | $schroot bash -c "'cat > /root/.ssh/authorized_keys'"
    $schroot chmod 0600 /root/.ssh/authorized_keys

    $rsh root@$target rsync -a /root/ $home/
    $rsh root@$target chown -R $user $home/

    $rsh $target touch /dont_keep_session
    $rsh $target chmod 0666 /dont_keep_session

    echo $target:$port started schroot: $rsh $target
fi

if ! [ -z "$shared_dir" ]; then
    # Generate a one-time key to allow ssh back to host.
    ssh-keygen -t rsa -N "" -C "test-schroot.$$" -f ~/.ssh/id_rsa-test-schroot.$$
    echo >> ~/.ssh/authorized_keys
    cat ~/.ssh/id_rsa-test-schroot.$$.pub >> ~/.ssh/authorized_keys
    scp $rsh_opts ~/.ssh/id_rsa-test-schroot.$$ $target:.ssh/

    $rsh root@$target mkdir -p "$shared_dir"
    $rsh root@$target chown -R $user "$shared_dir"

    $rsh root@$target rm -f /etc/mtab
    $rsh root@$target ln -s /proc/mounts /etc/mtab
    tmp_ssh_port="$(($port-10000))"
    host_ssh_port="$(grep "^Port" /etc/ssh/sshd_config | sed -e "s/^Port //")"
    test -z "$host_ssh_port" && host_ssh_port="22"
    # Establish port forwarding
    $rsh -fN -S none -R $tmp_ssh_port:127.0.0.1:$host_ssh_port $target
    $rsh $target sshfs -C -o ssh_command="ssh -o Port=$tmp_ssh_port -o IdentityFile=$home/.ssh/id_rsa-test-schroot.$$ -o StrictHostKeyChecking=no $host_ssh_opts" "$USER@127.0.0.1:$shared_dir" "$shared_dir" | true
    res="${PIPESTATUS[0]}"

    # Remove temporary key and delete extra empty lines at the end of file.
    sed -i -e "/.*test-schroot\.$$\$/d" -e '/^$/N;/\n$/D' ~/.ssh/authorized_keys
    rm ~/.ssh/id_rsa-test-schroot.$$*

    if [ x"$res" = x"0" ]; then
	echo "$target:$port shared directory $shared_dir: SUCCESS"
    else
	echo "$target:$port shared directory $shared_dir: FAIL"
    fi
fi

if ! [ -z "$sysroot" ]; then
    rsync -az -e "$rsh" $sysroot/ root@$target:/sysroot/

    if ! $use_qemu; then
	# Make sure that sysroot libraries are searched before any other.
	$rsh root@$target "cat > /etc/ld.so.conf.new" <<EOF
/$multilib_path
/usr/$multilib_path
EOF
	$rsh root@$target "cat /etc/ld.so.conf >> /etc/ld.so.conf.new"
	$rsh root@$target "mv /etc/ld.so.conf.new /etc/ld.so.conf && rsync -a --exclude=/sysroot /sysroot/ / && ldconfig"
    else
	# Remove /etc/ld.so.cache to workaround QEMU problem for targets with
	# different endianness (i.e., /etc/ld.so.cache is endian-dependent).
	$rsh root@$target "rm /etc/ld.so.cache"
	# Cleanup runaway QEMU processes that ran for more than 2 minutes.
	# Note the "-S none" option -- ssh does not always detach from process
	# when multiplexing is used.  I think this is a bug in ssh.
	$rsh -f -S none $target bash -c "\"while sleep 30; do ps uxf | sed -e \\\"s/ \+/ /g\\\" | cut -d\\\" \\\" -f 2,10- | grep \\\"^[0-9]\+ [0-9]*2:[0-9]\+ ._ qemu-\\\" | cut -d\\\" \\\" -f 1 | xargs -r kill -9; done\""
    fi
    echo $target:$port installed sysroot $sysroot
fi

if $ssh_master; then
    ssh $orig_target_ssh_opts -o Port=$port -o StrictHostKeyChecking=no -fMN $target
fi

# Keep the session alive when file /dont_kill_me is present
if $finish_session && `$schroot test -f /dont_keep_session`; then
    $schroot iptables -I INPUT -p tcp --dport $port -j REJECT || true
    ssh $target_ssh_opts $target schroot -f -e -c session:tcwg-test-$port | true
    if [ x"${PIPESTATUS[0]}" != x"0" ]; then
	# tcwgbuildXX machines have a kernel problem that a bind mount will be
	# forever busy if it had an sshfs under it.  Seems like fuse is not
	# cleaning up somethings.  The workaround is to lazy unmount the bind.
	$schroot umount -l /
	ssh $target_ssh_opts $target schroot -f -e -c session:tcwg-test-$port
    fi
    echo $target:$port finished session
fi

if [ "x$board_exp" != "x" ] ; then
    lava_job_id="$(grep "^set_board_info lava_job_id " $board_exp | sed -e "s/^set_board_info lava_job_id //")"
    if [ "x$lava_job_id" != "x" ] && $finish_session; then
	lava-tool cancel-job http://maxim-kuvyrkov@validation.linaro.org/RPC2/ $lava_job_id
    fi
fi
