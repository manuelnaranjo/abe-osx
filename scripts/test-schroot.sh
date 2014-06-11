#!/bin/bash

set -e

arch="native"
begin_session=false
schroot_master=""
shared_dir=""
board_exp=""
finish_session=false
gen_schroot=false
pubkey=""
sysroot=""
ssh_master=false
target_ssh_opts=""
host_ssh_opts=""
privkey=""

while getopts "a:bc:d:e:fgk:l:mo:p:qs:v" OPTION; do
    case $OPTION in
	a) arch=$OPTARG ;;
	b) begin_session=true ;;
	c) schroot_master="$OPTARG" ;;
	d) shared_dir=$OPTARG ;;
	e) board_exp="$OPTARG" ;;
	f) finish_session=true ;;
	g) gen_schroot=true ;;
	k) pubkey=$OPTARG ;;
	l) sysroot=$OPTARG ;;
	m) ssh_master=true ;;
	o) target_ssh_opts="$OPTARG" ;;
	p) host_ssh_opts="$OPTARG" ;;
	q) exec > /dev/null ;;
	s) privkey=$OPTARG ;;
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
	mips-*linux-gnu) echo mips ;;
	mipsel-*linux-gnu) echo mipsel ;;
	powerpc-*linux-gnu) echo powerpc ;;
	x86_64-*linux-gnu) echo amd64 ;;
	*) exit 1 ;;
    esac
}

triplet_to_deb_dist()
{
    set -e
    case "$arch" in
	aarch64-*linux-gnu) echo trusty ;;
	arm-*linux-gnueabi*) echo trusty ;;
	i686-*linux-gnu) echo trusty ;;
	mips-*linux-gnu) echo wheezy ;;
	mipsel-*linux-gnu) echo wheezy ;;
	powerpc-*linux-gnu) echo wheezy ;;
	x86_64-*linux-gnu) echo trusty ;;
	*) exit 1 ;;
    esac
}

if [ -z "$target" ]; then
    echo ERROR: no target specified
    exit 1
fi

if [ -z "$port" ]; then
    port="22"
fi

if [ "x$arch" = "xnative" ]; then
    cpu="$(ssh $target uname -m)"
    case "$cpu" in
	aarch64) arch=aarch64-linux-gnu ;;
	armv7l) arch=arm-linux-gnueabihf ;;
	armv7*) arch=arm-linux-gnueabi ;;
	i686) arch=i686-linux-gnu ;;
	x86_64) arch=x86_64-linux-gnu ;;
	*) echo ERROR: unrecognized native target $cpu ;;
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
	sudo ntpdate pool.ntp.org || true

    ssh $target_ssh_opts $target \
	sudo rm -rf $chroot
    ssh $target_ssh_opts $target \
	sudo debootstrap \
	--arch=$deb_arch \
	--variant=minbase \
	--include=iptables,openssh-server,rsync,sshfs \
	--foreign \
	$deb_dist $chroot
    ssh $target_ssh_opts $target \
	sudo cp /usr/bin/qemu-\*-static $chroot/usr/bin/ || true
    ssh $target_ssh_opts $target \
	sudo chroot $chroot ./debootstrap/debootstrap --second-stage &
    pid=$!
    while sleep 10; do
	if ! ssh $target_ssh_opts $target ps -e -o cmd= | grep -v "grep\|ssh" | grep "./debootstrap/debootstrap --second-stage"; then
	    kill $pid || true
	    break
	fi
    done
    ssh $target_ssh_opts $target \
	sudo rm -f $chroot/usr/bin/qemu-\*-static

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
groups=buildslave,users
root-groups=buildslave,users
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
	sudo ntpdate pool.ntp.org || true

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
    $schroot sed -i -e "\"s/^Port 22/Port $port/\"" /etc/ssh/sshd_config
    $schroot sed -i -e "\"s/^UsePrivilegeSeparation yes/UsePrivilegeSeparation no/\"" /etc/ssh/sshd_config
    $schroot sed -i -e "'/check_for_upstart [0-9]/d'" /etc/init.d/ssh
    $schroot /etc/init.d/ssh start
    $schroot iptables -I INPUT -p tcp --dport $port -j ACCEPT || true
    # Debian (but not Ubuntu) has wrong permissions on /bin/fusermount.
    $schroot chmod +x /bin/fusermount || true
    echo $target:$port started schroot: $rsh $target
fi

if ! [ -z "$pubkey" ]; then
    $schroot mkdir -p /root/.ssh
    $schroot bash -c "'cat > /root/.ssh/authorized_keys'" < "$pubkey"
    $schroot chmod 0600 /root/.ssh/authorized_keys

    $rsh root@$target rsync -a /root/ $home/
    $rsh root@$target chown -R $user $home/

    echo $target:$port imported ssh pubkey $pubkey
fi

if ! [ -z "$privkey" ]; then
    scp $rsh_opts "$privkey" $target:.ssh/
    echo $target:$port imported ssh privkey $privkey
fi

if ! [ -z "$shared_dir" ]; then
    if [ -z "$privkey" ]; then
	echo ERROR: cannot share directory without privkey
    fi

    $rsh root@$target mkdir -p "$shared_dir"
    $rsh root@$target chown -R $user "$shared_dir"

    $rsh root@$target rm -f /etc/mtab
    $rsh root@$target ln -s /proc/mounts /etc/mtab
    $rsh $target sshfs -o ssh_command="ssh $host_ssh_opts -o IdentityFile=$home/.ssh/$(basename "$privkey") -o StrictHostKeyChecking=no" "$USER@$(hostname):$shared_dir" "$shared_dir"
    echo $target:$port shared directory $shared_dir
fi

if ! [ -z "$sysroot" ]; then
    rsync -az -e "$rsh" $sysroot/ root@$target:/sysroot/
    # Make sure that sysroot libraries are searched before any other.
    $rsh root@$target "cat > /etc/ld.so.conf.new" <<EOF
/lib
/usr/lib
EOF
    $rsh root@$target "cat /etc/ld.so.conf >> /etc/ld.so.conf.new"
    $rsh root@$target "mv /etc/ld.so.conf.new /etc/ld.so.conf && rsync -a --exclude=/sysroot /sysroot/ / && ldconfig"
    echo $target:$port installed sysroot $sysroot
fi

if $ssh_master; then
    $rsh -fMN $target
fi

if $finish_session; then
    $schroot iptables -I INPUT -p tcp --dport $port -j REJECT || true
    $schroot /etc/init.d/ssh stop || true
    ssh $target_ssh_opts $target schroot -e -c session:tcwg-test-$port
    echo $target:$port finished session
fi

if [ "x$board_exp" != "x" ] ; then
    lava_job_id="$(grep "^set_board_info lava_job_id " $board_exp | sed -e "s/^set_board_info lava_job_id //")"
    if [ "x$lava_job_id" != "x" ] && $finish_session; then
	lava-tool cancel-job http://maxim-kuvyrkov@validation.linaro.org/RPC2/ $lava_job_id
    fi
fi
