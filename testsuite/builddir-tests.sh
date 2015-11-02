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

in="git://git.linaro.org/toolchain/binutils.git"
out="`get_builddir ${in}~binutils-2_18-branch@654321`"
match="${local_builds}/${build}/x86_64-linux-gnu/binutils.git~binutils-2_18-branch@654321"
if test x"${out}" = x"${match}"; then
    pass "get_builddir: git repository with branch and commit"
else
    fail "get_builddir: git repository with branch and commit"
    fixme "${in} returned '${out}' expected '${match}'"
fi

in="git://git.linaro.org/toolchain/binutils.git"
out="`get_builddir ${in}~binutils-2_18-branch/foo/bar@654321`"
match="${local_builds}/${build}/x86_64-linux-gnu/binutils.git~binutils-2_18-branch-foo-bar@654321"
if test x"${out}" = x"${match}"; then
    pass "get_builddir: git repository with branch and commit"
else
    fail "get_builddir: git repository with branch and commit"
    fixme "${in} returned '${out}' expected '${match}'"
fi


in="git://git.linaro.org/toolchain/binutils.git"
out="`get_builddir ${in}/binutils-2_18-branch@654321`"
match="${local_builds}/${build}/x86_64-linux-gnu/binutils.git~binutils-2_18-branch@654321"
if test x"${out}" = x"${match}"; then
    pass "get_builddir: git repository with branch and commit"
else
    fail "get_builddir: git repository with branch and commit"
    fixme "${in} returned '${out}' expected '${match}'"
fi

in="git://git.linaro.org/toolchain/binutils.git"
out="`get_builddir ${in}/binutils-2_18-branch/foo/bar@654321`"
if test ${out} = "${local_builds}/${build}/x86_64-linux-gnu/binutils.git~binutils-2_18-branch-foo-bar@654321"; then
    pass "get_builddir: git repository with branch and commit"
else
    fail "get_builddir: git repository with branch and commit"
    fixme "${in} returned ${out}"
fi



in="gcc.git/linaro-4.8-branch"
out="`get_builddir ${in}`"
if test ${out} = "${local_builds}/${build}/x86_64-linux-gnu/gcc.git~linaro-4.8-branch"; then
    pass "get_builddir: git repository with branch, no URL"
else
    fail "get_builddir: git repository with branch, no URL"
    fixme "get_builddir returned ${out}"
fi

in="infrastructure/gmp-5.1.2.tar.xz"
out="`get_builddir ${in}`"
if test ${out} = "${local_builds}/${build}/x86_64-linux-gnu/infrastructure/gmp-5.1.2"; then
    pass "get_builddir: tarball in subdirectory"
else
    fail "get_builddir: tarball in subdirectory"
    fixme "${in} returned ${out}"
fi

in="git://git.linaro.org/toolchain/binutils-gdb.git"
out="`get_builddir ${in}~linaro_binutils-2_24-branch`"
if test ${out} = "${local_builds}/${build}/x86_64-linux-gnu/binutils-gdb.git~linaro_binutils-2_24-branch"; then
    pass "get_builddir: merged binutils-gdb.git repository without second parameter to get_builddir."
else
    fail "get_builddir: merged binutils-gdb.git repository without second parameter to get_builddir."
    fixme "${in} returned ${out}"
fi

in="git://git.linaro.org/toolchain/binutils-gdb.git"
out="`get_builddir ${in}~linaro_binutils-2_24-branch binutils`"
if test ${out} = "${local_builds}/${build}/x86_64-linux-gnu/binutils-gdb.git~linaro_binutils-2_24-branch-binutils"; then
    pass "get_builddir: merged binutils-gdb.git repository with second parameter to get_builddir."
else
    fail "get_builddir: merged binutils-gdb.git repository with second parameter to get_builddir."
    fixme "${in} returned ${out}"
fi

in="git://git.linaro.org/toolchain/binutils-gdb.git"
out="`get_builddir ${in}~master binutils`"
if test ${out} = "${local_builds}/${build}/x86_64-linux-gnu/binutils-gdb.git~master-binutils"; then
    pass "get_builddir: merged binutils-gdb.git repository with master branch and binutils as a second parameter."
else
    fail "get_builddir: merged binutils-gdb.git repository with master branch and binutils as a second parameter."
    fixme "${in} returned ${out}"
fi

in="git://git.linaro.org/toolchain/binutils-gdb.git"
out="`get_builddir ${in}~master gdb`"
if test ${out} = "${local_builds}/${build}/x86_64-linux-gnu/binutils-gdb.git~master-gdb"; then
    pass "get_builddir: merged binutils-gdb.git repository with master branch and gdb as a second parameter."
else
    fail "get_builddir: merged binutils-gdb.git repository with master branch and gdb as a second parameter."
    fixme "${in} returned ${out}"
fi
