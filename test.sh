#!/bin/sh

pass()
{
    echo "PASS: $1"
}

fail()
{
    echo "FAIL: $1"
}

test()
{
     case "$1" in
	 *$2*)
             pass $2
             ;;
         *)
             fail $2
             ;;
     esac
}

out="`./cbuild2.sh --build XXX`"
test "${out}" "build"

out="`./cbuild2.sh --target XXX`"
test "${out}" "target"

out="`./cbuild2.sh --snapshots XXX`"
test "${out}" "snapshot"

out="`./cbuild2.sh --libc XXX`"
test "${out}" "libc"

out="`./cbuild2.sh --list XXX`"
test "${out}" "list"

#out="`./cbuild2.sh --set {gcc,binutils,libc,latest}=XXX`"
#test "${out}" "set"

out="`./cbuild2.sh --binutils XXX`"
test "${out}" "binutils"

out="`./cbuild2.sh --gcc XXX`"
test "${out}" "gcc"

out="`./cbuild2.sh --config XXX`"
test "${out}" "config"

out="`./cbuild2.sh --clean`"
test "${out}" "Cleaning"

out="`./cbuild2.sh --dispatch XXX`"
test "${out}" "Dispatch"

out="`./cbuild2.sh --sysroot XXX`"
test "${out}" "sysroot"

out="`./cbuild2.sh --db-user XXX`"
test "${out}" "user"

out="`./cbuild2.sh --db-passwd XXX`"
test "${out}" "password"
