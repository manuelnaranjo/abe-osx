#!/bin/bash

set -e

usage ()
{
    cat <<EOF
Usage: $0 [-r] [-v] [-h] [machine1 machine2 ...]
	This scripts generates and rsync's reference snapshots to machines

	-r: Only rsync snapshots-ref to machines
	-v: Be verbose
	-h: Print help
EOF
}

abe_temp="$(dirname "$0")/.."
generate=true
snapshots_dir=$HOME/snapshots-ref
verbose="set +x"

while getopts "hrv" OPTION; do
    case $OPTION in
	h)
	    usage
	    exit 0
	    ;;
	r)
	    generate=false
	    ;;
	v) verbose="set -x" ;;
    esac
done

$verbose

shift $((OPTIND-1))

# Checkout into $snapshots_dir using ABE
generate_snapshots ()
{
    cd $abe_temp
    git reset --hard
    git clean -fd
    ./configure --with-local-snapshots=${snapshots_dir}-new --with-fileserver=ex40-01.tcwglab.linaro.org/snapshots-ref

    if [ -e $HOME/.aberc ]; then
	echo "WARNING: $HOME/.aberc detected and it might override ABE's behavior"
    fi

    targets=(
	aarch64-linux-gnu
	aarch64-none-elf
	arm-linux-gnueabihf
	arm-none-eabi
	i686-linux-gnu
	x86_64-linux-gnu
    )

    for t in "${targets[@]}"; do
	./abe.sh --target $t --checkout all
    done
}

if $generate; then
    generate_snapshots
fi

# Remove checked-out branch directories
rm -rf $snapshots_dir-new/*~*

# Cleanup stale branches
for repo in $snapshots_dir-new/*.git; do
    (
	cd $repo
	git remote update -p
	git branch | grep -v \* | xargs -r git branch -D
    )
done

# "if true" is to have same indent as configure-machine.sh hunk from which
# handling of parallel runs was copied.
if true; then
    declare -A pids
    declare -A results

    todo_machines="$@"

    for M in $todo_machines; do
	(
	    rsync -az --delete $snapshots_dir-new/ $M:$snapshots_dir-new/
	    ssh -fn $M "flock -x $snapshots_dir.lock -c \"rsync -a $snapshots_dir-new/ $snapshots_dir/\""
	) > /tmp/update-snapshots-ref.$$.$M 2>&1 &
	pids[$M]=$!
    done

    for M in $todo_machines; do
	set +e
	wait ${pids[$M]}
	results[$M]=$?
	set -e

	sed -e "s/^/$M: /" < /tmp/update-snapshots-ref.$$.$M
	rm /tmp/update-snapshots-ref.$$.$M
    done

    all_ok="0"
    for M in $todo_machines; do
	if [ ${results[$M]} = 0 ]; then
	    result="SUCCESS"
	else
	    result="FAIL"
	    all_ok="1"
	fi
	echo "$result: $M"
    done

    exit $all_ok
fi
