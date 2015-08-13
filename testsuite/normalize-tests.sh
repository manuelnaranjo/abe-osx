# Tests for the normalize_path function

echo "============= normalize_path() tests ================"

in="gdb-7.6~20121001+git3e2e76a.tar.bz2"
out="`normalize_path ${in}`"
if test x"${out}" = x"gdb-7.6~20121001@3e2e76a"; then
    pass "normalize_path: tarball old git format"
else
    fail "normalize_path: tarball old git format"
    fixme "${in} returned ${out}"
fi

for transport in git ssh http; do
  in="${transport}://git.linaro.org/toolchain/binutils.git"
  out="`normalize_path ${in}`"
  if test x"${out}" = x"binutils.git"; then
      pass "normalize_path: git repository (${transport})"
  else
      fail "normalize_path: git repository (${transport})"
      fixme "${in} returned ${out}"
  fi

  out="`normalize_path binutils.git/binutils-2_18-branch`"
  match="binutils.git~binutils-2_18-branch"
  if test x"${out}" = x"${match}"; then
      pass "normalize_path: git repository with branch (${transport})"
  else
      fail "normalize_path: git repository with branch (${transport})"
      fixme "${in} returned ${out}"
  fi

  testing="normalize_path: git repository with ~ branch and commit (${transport})"
  out="`normalize_path ${in}~binutils-2_18-branch@123456`"
  if test x"${out}" = x"binutils.git~binutils-2_18-branch@123456"; then
      pass "${testing}"
  else
      fail "${testing}"
      fixme "${in} returned ${out}"
  fi

  testing="normalize_path: git repository with ~ and multi-/ branch and commit (${transport})"
  out="`normalize_path ${in}~binutils-2_18-branch/foo/bar@123456`"
  match="binutils.git~binutils-2_18-branch-foo-bar@123456"
  if test x"${out}" = x"${match}"; then
      pass "${testing}"
  else
      fail "${testing}"
      fixme "${in} returned ${out}"
  fi
done

testing="normalize_path: git repository with ~ branch"
in="gcc.git/linaro-4.8-branch"
out="`normalize_path ${in}`"
if test x"${out}" = x"gcc.git~linaro-4.8-branch"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out}"
fi

for transport in git ssh http; do
  testing="normalize_path: full git (${transport}) url with ~ branch"
  in="${transport}://git.linaro.org/git/toolchain/gcc.git/linaro-4.8-branch"
  out="`normalize_path ${in}`"
  if test x"${out}" = x"gcc.git~linaro-4.8-branch"; then
      pass "${testing}"
  else
      fail "${testing}"
      fixme "${in} returned ${out}"
  fi
done

in="gdb-7.6~20121001+git3e2e76a.tar"
out="`normalize_path ${in}`"
if test x"${out}" = x"gdb-7.6~20121001@3e2e76a"; then
    pass "normalize_path: tarball uncompressed"
else
    fail "normalize_path: tarball uncompressed"
    fixme "${in} returned ${out}"
fi

in="http://abe.validation.linaro.org/snapshots/gcc-linaro-4.8-2013.06-1.tar.xz"
out="`normalize_path ${in}`"
if test x"${out}" = x"gcc-linaro-4.8-2013.06-1"; then
    pass "normalize_path: tarball compressed"
else
    fail "normalize_path: tarball compressed"
    fixme "${in} should produce ${out}"
fi

in="svn://gcc.gnu.org/svn/gcc/branches/gcc-4_7-branch"
out="`normalize_path ${in}`"
if test x"${out}" = x"gcc-4_7-branch"; then
    pass "normalize_path: svn repository"
else
    fail "normalize_path: svn repository"
    fixme "${in} should produce ${out}"
fi

in="svn://gcc.gnu.org/svn/gcc/branches/gcc-4_7-branch"
out="`normalize_path ${in}@123456`"
if test x"${out}" = x"gcc-4_7-branch@123456"; then
    pass "normalize_path: svn repository with revision"
else
    fail "normalize_path: svn repository with revision"
    fixme "${in} should produce ${out}"
fi

in="lp:gdb-linaro/7.5"
out="`normalize_path ${in}`"
if test x"${out}" = x"gdb-linaro_7.5"; then
    pass "normalize_path: bzr branch"
else
    fail "normalize_path: bzr branch"
    fixme "${in} returned ${out}"
fi

in="binutils-gdb.git/gdb_7_6-branch"
out="`normalize_path ${in}`"
match="binutils-gdb.git~gdb_7_6-branch"
if test x"${out}" = x"${match}"; then
    pass "normalize_path: new binutils-gdb repository"
else
    fail "normalize_path: new binutils-gdb repository"
    fixme "${in} returned ${out} but expected ${match}"
fi


