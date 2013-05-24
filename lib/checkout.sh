#!/bin/sh

#
# This does a checkout from a source code repository
#

# 
# branch gcc-linaro/4.7 lp:gcc-linaro/4.7 gcc-linaro-4.7
# branch gcc-linaro/4.6 lp:gcc-linaro/4.6 gcc-linaro-4.6

# branch gdb-linaro/7.6 lp:gdb-linaro/7.6 gdb-linaro-7.6
# branch gdb-linaro/7.5 lp:gdb-linaro/7.5 gdb-linaro 7.5

# branch crosstool-ng/linaro lp:~linaro-toolchain-dev/crosstool-ng/linaro crosstool-ng-linaro

# branch cortex-strings lp:cortex-strings cortex-strings
# branch boot-wrapper git://git.linaro.org/arm/models/boot-wrapper.git boot-wrapper

# branch binutils git://sourceware.org/git/binutils.git binutils
# branch bitbake git://git.openembedded.org/bitbake bitbake
# branch eglibc http://www.eglibc.org/svn/trunk eglibc
# branch gdb git://sourceware.org/git/gdb.git gdb
# branch glibc git://sourceware.org/git/glibc.git glibc
# branch libav git://git.libav.org/libav.git libav
# branch libffi git://github.com/atgreen/libffi.git libffi
# branch llvm http://llvm.org/svn/llvm-project/llvm/trunk llvm
# branch meta-linaro git://git.linaro.org/openembedded/meta-linaro.git meta-linaro
# branch newlib git://sourceware.org/git/newlib.git newlib
# branch openembedded-core git://git.openembedded.org/openembedded-core openembedded-core
# branch qemu-git git://git.qemu.org/qemu.git qemu
# branch qemu-linaro git://git.linaro.org/qemu/qemu-linaro.git qemu-linaro
# branch valgrind svn://svn.valgrind.org/valgrind/trunk valgrind

# branch gcc-4.6 svn://gcc.gnu.org/svn/gcc/branches/gcc-4_6-branch gcc-4.6
# branch gcc-4.7 svn://gcc.gnu.org/svn/gcc/branches/gcc-4_7-branch gcc-4.7
# branch gcc-4.8 svn://gcc.gnu.org/svn/gcc/branches/gcc-4_8-branch gcc-4.8
# branch gcc-arm-aarch64-4.7 svn://gcc.gnu.org/svn/gcc/branches/ARM/aarch64-4.7-branch gcc-am-aarch64-4.7
# branch gcc-arm-embedded-4.6 svn://gcc.gnu.org/svn/gcc/branches/ARM/embedded-4_6-branch gccarm-embedded-4.6
# branch gcc-google-4.6 svn://gcc.gnu.org/svn/gcc/branches/google/gcc-4_6 gcc-google-4.6
# branch gcc-trunk svn://gcc.gnu.org/svn/gcc/trunk gcc
 

checkout()
{
    if test x"$1" = x; then
	error "No URL given!"
	return 1
    fi

    dir="`basename $1 |sed -e 's/^.*://'`"

    # We use git for our copy by importing from the other systems
    case $1 in
	bzr*|lp*)
	    out="`git-bzr clone $1 ${local_snapshots}/${dir}`"
	    ;;
	svn*)
	    out="`git svn clone $1 ${local_snapshots}/${dir}`"
	    ;;
	git*)
	    out="`git clone $1 ${local_snapshots}/${dir}`"
	    ;;
	*)
	    ;;
    esac

    if test $? -gt 1; then
	error "Couldn't checkout $1 !"
	return 1
    fi

    return 0
}
