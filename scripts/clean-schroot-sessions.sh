#!/bin/bash

set -e

usage ()
{
    cat <<EOF
Usage: $0 [-v] [-d DAYS] [machine1 machine2 ...]
	This scripts stops tcwg-test schroot sessions on given machines
	that are more than DAYS old.

	-d DAYS: Number of days (default 1)
	-v: Be verbose
	-h: Print help
EOF
}

verbose="set +x"
days="1"

while getopts "d:hv" OPTION; do
    case $OPTION in
	d) days="$OPTARG" ;;
	h)
	    usage
	    exit 0
	    ;;
	v) verbose="set -x" ;;
    esac
done

$verbose

shift $((OPTIND-1))

# Semantics of find's mtime "+N" stands for N+1 days old or older.
days=$(($days-1))

# "if true" is to have same indent as configure-machine.sh hunk from which
# handling of parallel runs was copied.
if true; then
    declare -A pids
    declare -A results

    todo_machines="$@"

    # Ssh to machines and stop tcwg-test schroot sessions (via
    # "test-schroot -f") that are more than $days old.  Dump output to a temp
    # file for display at the end.
    for M in $todo_machines; do
	(
	    ssh $M find /var/lib/schroot/session -mtime +$days \
		| sed -e "s#^/var/lib/schroot/session/tcwg-test-##" \
		| grep "^[0-9]*\$" \
		| xargs -t -i@ $(dirname $0)/test-schroot.sh -v -f $M:@
	) > /tmp/clean-schroot-sessions.$$.$M 2>&1 &
	pids[$M]=$!
    done

    for M in $todo_machines; do
	set +e
	wait ${pids[$M]}
	results[$M]=$?
	set -e

	sed -e "s/^/$M: /" < /tmp/clean-schroot-sessions.$$.$M
	rm /tmp/clean-schroot-sessions.$$.$M
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
