# tests for the get_builddir function

echo "============= get_builddir() tests ================"

in="gdb-7.6~20121001+git3e2e76a.tar"
out="`get_builddir ${in}`"
#if test ${out} = "${local_builds}/${build}/x86_64-linux-gnu/gdb-7.6~20121001+git3e2e76a"; then
#    pass "get_builddir: tarball uncompressed old git"
#else
#    fail "get_builddir: tarball uncompressed old git"
#    fixme "${in} returned ${out}"
#fi

in="gcc-linaro-4.8-2013.06-1.tar.xz"
out="`get_builddir ${in}`"
if test ${out} = "${local_builds}/${build}/x86_64-linux-gnu/gcc-linaro-4.8-2013.06-1"; then
    pass "get_builddir: tarball compressed"
else
    fail "get_builddir: tarball compressed"
    fixme "${in} returned ${out}"
fi

in="svn://gcc.gnu.org/svn/gcc/branches/gcc-4_7-branch"
out="`get_builddir ${in}`"
if test ${out} = "${local_builds}/${build}/x86_64-linux-gnu/gcc-4_7-branch"; then
    pass "get_builddir: svn branch"
else
    fail "get_builddir: svn branch"
    fixme "${in} returned ${out}"
fi

in="lp:gdb-linaro/7.5"
out="`get_builddir ${in}`"
if test ${out} = "${local_builds}/x86_64-unknown-linux-gnu/x86_64-linux-gnu/gdb-linaro_7.5"; then
    pass "get_builddir: bzr branch"
else
    fail "get_builddir: bzr branch"
    fixme "${in} returned ${out}"
fi

in="git://git.linaro.org/toolchain/binutils.git"
out="`get_builddir ${in}binutils-2_18-branch@654321`"
if test ${out} = "${local_builds}/${build}/x86_64-linux-gnu/binutils.git-binutils-2_18-branch@654321"; then
    pass "get_builddir: git repository with branch and commit"
else
    fail "get_builddir: git repository with branch and commit"
    fixme "${in} returned ${out}"
fi

