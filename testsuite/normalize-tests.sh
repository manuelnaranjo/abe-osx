# Tests for the normalize_path function

echo "============= normalize_path() tests ================"

in="gdb-7.6~20121001+git3e2e76a.tar.bz2"
out="`normalize_path ${in}`"
if test ${out} = "gdb-7.6~20121001@3e2e76a"; then
    pass "normalize_path: tarball old git format"
else
    fail "normalize_path: tarball old git format"
    fixme "${in} returned ${out}"
fi

in="git://git.linaro.org/toolchain/binutils.git"
out="`normalize_path ${in}`"
if test ${out} = "binutils.git"; then
    pass "normalize_path: git repository"
else
    fail "normalize_path: git repository"
    fixme "${in} returned ${out}"
fi

out="`normalize_path ${in}/binutils-2_18-branch`"
if test ${out} = "binutils.git-binutils-2_18-branch"; then
    pass "normalize_path: git repository with branch"
else
    fail "normalize_path: git repository with branch"
    fixme "${in} returned ${out}"
fi

out="`normalize_path ${in}binutils-2_18-branch@123456`"
if test ${out} = "binutils.git-binutils-2_18-branch@123456"; then
    pass "normalize_path: git repository with branch and commit"
else
    fail "normalize_path: git repository with branch and commit"
    fixme "${in} returned ${out}"
fi

in="gdb-7.6~20121001+git3e2e76a.tar"
out="`normalize_path ${in}`"
if test ${out} = "gdb-7.6~20121001@3e2e76a"; then
    pass "normalize_path: tarball uncompressed"
else
    fail "normalize_path: tarball uncompressed"
    fixme "${in} returned ${out}"
fi

in="http://cbuild.validation.linaro.org/snapshots/gcc-linaro-4.8-2013.06-1.tar.xz"
out="`normalize_path ${in}`"
if test ${out} = "gcc-linaro-4.8-2013.06-1"; then
    pass "normalize_path: tarball compressed"
else
    fail "normalize_path: tarball compressed"
    fixme "${in} should produce ${out}"
fi


in="svn://gcc.gnu.org/svn/gcc/branches/gcc-4_7-branch"
out="`normalize_path ${in}`"
if test ${out} = "gcc-4_7-branch"; then
    pass "normalize_path: svn repository"
else
    fail "normalize_path: svn repository"
    fixme "${in} should produce ${out}"
fi

in="svn://gcc.gnu.org/svn/gcc/branches/gcc-4_7-branch"
out="`normalize_path ${in}@123456`"
if test ${out} = "gcc-4_7-branch@123456"; then
    pass "normalize_path: svn repository with revision"
else
    fail "normalize_path: svn repository with revision"
    fixme "${in} should produce ${out}"
fi

in="lp:gdb-linaro/7.5"
out="`normalize_path ${in}`"
if test ${out} = "gdb-linaro_7.5"; then
    pass "normalize_path: bzr branch"
else
    fail "normalize_path: bzr branch"
    fixme "${in} returned ${out}"
fi

