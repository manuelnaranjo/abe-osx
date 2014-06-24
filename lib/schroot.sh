#!/bin/bash

# Print DJ board files used for testing
# $1 - [optional] target triplet
print_schroot_board_files()
{
    trace "$*"

    local target="$1"

    if ! [ -z "$target" ]; then
	target="--target=$target"
    fi

    # Run dummy runtest to figure out which target boards load schroot-ssh.exp
    runtest $target --tool none 2>&1 \
	| grep -B5 "^Using .*/schroot-ssh.exp as generic interface file for target\.\$" \
	| grep "^Using .* as board description file for target\.\$" \
	| sed -e "s/^Using \(.*\) as board description file for target\.\$/\1/"
    rm -f none.log none.sum
}

# Print unique port to be used for ssh server on the boards
print_schroot_port()
{
    trace "$*"

    # Set build_n to the last digit appearing in hostname.
    # E.g., tcwgbuild04 becomes "4" (and so does x86_64).
    # This is purely for convenience when determining which hosts use
    # a particular target board.
    # If the port turns out to be already in use on one of the boards then
    # test-schroot.sh will gracefully fail.
    local build_n
    build_n="$(hostname | sed -e "s/.*\([0-9]\).*/\1/" | grep "[0-9]")"
    test -z "$build_n" && build_n="0"
    port=$((50000+1000*$build_n+$RANDOM%1000))
    # We return ports between 50000 and 59999
    echo $port
}

# Start schroot sessions on boards.
# $1 - target triplet
# $2 - port on which to start ssh server in schroot session
# $3 - [optional] target sysroot
start_schroot_sessions()
{
    trace "$*"

    local target="$1"
    local port="$2"
    local sysroot="$3"

    local target_opt
    if ! [ -z "$target" ]; then
	target_opt="-a $target"
    fi

    local sysroot_opt
    if ! [ -z "$sysroot" ]; then
	local multilib_dir
	multilib_dir="$(find "$sysroot" -type f -name ld-\*.so)"
	multilib_dir="$(basename $(dirname $multilib_dir))"
	sysroot_opt="-l $sysroot -h $multilib_dir"
    fi

    local -a board_exps
    board_exps=($(print_schroot_board_files "$target"))
    for board_exp in "${board_exps[@]}"; do
	local hostname sysroot lib_path multilib_dir

	# Get board hostname
	hostname="$(grep "^set_board_info hostname " $board_exp | sed -e "s/^set_board_info hostname //")"
	if [ -z "$hostname" ]; then
	    error "Board file $board_exp uses schroot testing, but does not define \"set_board_info hostname\""
	    continue
	fi

	# This command is very handy to have in logs to reproduce test
	# environment.
	set -x
	# Start testing schroot session.
	dryrun "$topdir/scripts/test-schroot.sh -v -b $target_opt -m -e $board_exp $sysroot_opt $hostname:$port" 1>&2
	set +x

	# Print the hostname to the caller
	echo $hostname
    done
}

# Stop schroot sessions on given boards/ports
# $1 - port on which ssh server for schroot session was started
# $2, $3, ... - hostnames of boards as printed by start_schroot_sessions.
stop_schroot_sessions()
{
    trace "$*"

    local port="$1"
    shift 1

    for hostname in "$@"; do
	dryrun "${topdir}/scripts/test-schroot.sh -f $hostname:$port"
    done
}
