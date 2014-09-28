#!/bin/bash

#set -x

master="$(dirname $0)"
test_schroot="$master/../../scripts/test-schroot.sh"

tcwgbuild_archs=(
    aarch64-linux-gnu
    arm-linux-gnueabihf
    i686-linux-gnu
    x86_64-linux-gnu
)

# Generate chroots for all supported targets on tcwgbuild01 ...
pids=""
set -e
for a in "${tcwgbuild_archs[@]}"; do
    true &
    #eval $test_schroot -g -c $master -a $a linaro@tcwgbuild01 &
    pids="$pids $!"
done
set +e
wait $pids

ssh_opts="-o ConnectTimeout=5"

cmd1="true"
#cmd1="ssh $ssh_opts \$m sudo apt-get install -y schroot"
#cmd1="ssh $ssh_opts \$m sudo rm -f /etc/schroot/chroot.d/tcwg-test-\\\* /var/chroots/tcwg-test-\\\*"
#cmd1="echo \$m; ssh $ssh_opts \$m bash -c \\\"schroot -l --all-sessions \| grep -e tcwg-test \\\""
#cmd1="echo \$m; ssh $ssh_opts \$m bash -c \\\"schroot -l --all-sessions \| grep -e tcwg-test \| xargs -i@ sudo schroot -e -c @\\\""

#cmd2="true"
cmd2="($test_schroot -c $master -a \$a -o \"$ssh_opts\" \$m && echo \$m:\$a: OK) || echo \$m:\$a: ERROR"

# ... then copy them to all other tcwgbuildXX machines.
pids=""
for m in $(for i in `seq 1 6`; do echo linaro@tcwgbuild0$i; done); do
    eval $cmd1 &
    pids="$pids $!"
    for a in i686-linux-gnu x86_64-linux-gnu; do
	eval $cmd2 &
	pids="$pids $!"
    done
done
# Copy ARMv7 hard-fp and soft-fp chroots to all D01s and chromebooks.
for m in $(for i in `seq 1 4`; do echo linaro@tcwg-d01-0$i; done) linaro@tcwg-chrome2-01; do
    eval $cmd1 &
    pids="$pids $!"
    for a in arm-linux-gnueabihf; do
	eval $cmd2 &
	pids="$pids $!"
    done
done
# Copy Aarch64 and ARM 32-bit chroots to APM boards.
for m in $(for i in `seq 1 4`; do echo linaro@tcwg-apm-0$i; done); do
    eval $cmd1 &
    pids="$pids $!"
    for a in aarch64-linux-gnu arm-linux-gnueabihf; do
	eval $cmd2 &
	pids="$pids $!"
    done
done

wait $pids
echo ALL DONE
