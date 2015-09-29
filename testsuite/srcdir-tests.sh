# tests for the get_srcdir() function

echo "============= get_srcdir() tests ================"

# FIXME: Note these following test cases only PASS if you have the source
# directories created already.
if test -d ${local_snapshots}/gcc.git; then
    in="git://git@git.linaro.org/toolchain/gcc.git"
    out="`get_srcdir $in | grep -v TRACE`"
    if test x"${out}" = x"${local_snapshots}/gcc.git"; then
	pass "get_srcdir: git repository"
    else
	fail "get_srcdir: git repository"
	fixme "get_srcdir returned ${out}"
    fi

    in="gcc.git"
    out="`get_srcdir $in | grep -v TRACE`"
    if test x"${out}" = x"${local_snapshots}/gcc.git"; then
	pass "get_srcdir: git repository no path"
    else
	fail "get_srcdir: git repository no path"
	fixme "get_srcdir returned ${out}"
    fi
else
    untested  "get_srcdir: git repository"
fi


if test -d ${local_snapshots}/gcc.git-linaro-4.8-branch; then
    in="gcc.git/linaro-4.8-branch"
    out="`get_srcdir $in | grep -v TRACE`"
    if test x"${out}" = x"${local_snapshots}/gcc.git-linaro-4.8-branch/gcc-4_8-branch"; then
	pass "get_srcdir: git repository with branch"
    else
	fail "get_srcdir: git repository with branch"
	fixme "get_srcdir returned ${out}"
    fi

    in="git://git@git.linaro.org/toolchain/gcc.git/linaro-4.8-branch"
    out="`get_srcdir $in | grep -v TRACE`"
    if test x"${out}" = x"${local_snapshots}/gcc.git-linaro-4.8-branch/gcc-4_8-branch"; then
	pass "get_srcdir: git repository URL with branch"
    else
	fail "get_srcdir: git repository URL with branch"
	fixme "get_srcdir returned ${out}"
    fi

else
    untested "get_srcdir: git repository with branch"
fi

if test -d ${local_snapshots}/gcc.git-linaro-4.8-branch@123456; then
    in="git://git@git.linaro.org/toolchain/gcc.git/linaro-4.8-branch@123456"
    out="`get_srcdir $in | grep -v TRACE`"
    if test x"${out}" = x"${local_snapshots}/gcc.git-linaro-4.8-branch@123456/gcc-4_8-branch"; then
	pass "get_srcdir: git repository with branch and commit"
    else
	fail "get_srcdir: git repository with branch and commit"
	fixme "get_srcdir returned ${out}"
    fi
else
    untested "get_srcdir: git repository with branch and commit"
fi

if test -d ${local_snapshots}/gcc-linaro-4.8-2013.06-1; then
    in="gcc-linaro-4.8-2013.06-1.tar.xz"
    out="`get_srcdir $in | grep -v TRACE`"
    if test x"${out}" = x"${local_snapshots}/gcc-linaro-4.8-2013.06-1"; then
	pass "get_srcdir: with tarball and full path"
    else
	fail "get_srcdir: with tarball and full path"
	fixme "get_srcdir returned ${out}"
    fi
else
    untested "get_srcdir: with tarball and full path"
fi

in="infrastructure/gmp-5.1.2.tar.xz"
out="`get_srcdir $in | grep -v TRACE`"
if test x"${out}" = x"${local_snapshots}/infrastructure/gmp-5.1.2"; then
    pass "get_srcdir: with tarball in subdirectory"
else
    fail "get_srcdir: with tarball in subdirectory"
    fixme "get_srcdir returned ${out}"
fi

if test -d ${local_snapshots}/gcc-linaro-4.7-2013.09; then
    in="gcc-linaro-4.7-2013.09.tar.bz2"
    out="`get_srcdir $in | grep -v TRACE`"
    if test x"${out}" = x"${local_snapshots}/gcc-linaro-4.7-2013.09"; then
	pass "get_srcdir: with tarball"
    else
	fail "get_srcdir: with tarball"
	fixme "get_srcdir returned ${out}"
    fi
else
    untested "get_srcdir: with tarball"
fi

echo "============= additional get_srcdir () tests ================"
# Some of these are redundant with those in srcdir_tests but since
# already have abe.git checked out we might as well test them here.
testing="get_srcdir: <repo>.git"
in="abe.git"
out="`get_srcdir $in`"
if test x"${out}" = x"${local_snapshots}/abe.git"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_srcdir returned ${out}"
fi

testing="get_srcdir: <repo>.git@<revision>"
in="abe.git@12345"
out="`get_srcdir $in`"
if test x"${out}" = x"${local_snapshots}/abe.git@12345"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_srcdir returned ${out}"
fi

testing="get_srcdir: <repo>.git/<branch>"
in="abe.git/branch"
out="`get_srcdir $in`"
if test x"${out}" = x"${local_snapshots}/abe.git~branch"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_srcdir returned ${out}"
fi

testing="get_srcdir: <repo>.git/<branch>@<revision>"
in="abe.git/branch@12345"
out="`get_srcdir $in`"
if test x"${out}" = x"${local_snapshots}/abe.git~branch@12345"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_srcdir returned ${out}"
fi

testing="get_srcdir: <repo>.git~<branch>@<revision>"
in="abe.git~branch@12345"
out="`get_srcdir $in`"
if test x"${out}" = x"${local_snapshots}/abe.git~branch@12345"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_srcdir returned ${out}"
fi

testing="get_srcdir: <repo>.git/<multi/part/branch>@<revision>"
in="abe.git/multi/part/branch@12345"
out="`get_srcdir $in`"
if test x"${out}" = x"${local_snapshots}/abe.git~multi-part-branch@12345"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_srcdir returned ${out}"
fi

testing="get_srcdir: <repo>.git~<multi/part/branch>@<revision>"
in="abe.git~multi/part/branch@12345"
out="`get_srcdir $in`"
if test x"${out}" = x"${local_snapshots}/abe.git~multi-part-branch@12345"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_srcdir returned ${out}"
fi


# 
testing="get_srcdir: invalid identifier shouldn't return anything."
in="abe~multi/part/branch@12345"
out="`get_srcdir $in 2>/dev/null`"
if test x"${out}" = x""; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_srcdir returned ${out}"
fi

testing="get_srcdir: <repo>~<multi/part/branch>@<revision>"
in="git://git.linaro.org/people/rsavoye/abe~multi/part/branch@12345"
out="`get_srcdir $in`"
if test x"${out}" = x"${local_snapshots}/abe~multi-part-branch@12345"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_srcdir returned ${out}"
fi

testing="get_srcdir: <repo>.git~<multi/part/branch>@<revision>"
in="abe.git~multi/part/branch@12345"
out="`get_srcdir $in`"
if test x"${out}" = x"${local_snapshots}/abe.git~multi-part-branch@12345"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_srcdir returned ${out}"
fi

testing="get_srcdir: http://<user>@<url>/<repo>.git"
in="http://git@git.linaro.org/git/toolchain/abe.git"
out="`get_srcdir $in`"
if test x"${out}" = x"${local_snapshots}/abe.git"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_srcdir returned ${out}"
fi

testing="get_srcdir: http://<user>@<url>/<repo>.git@<revision>"
in="http://git@git.linaro.org/git/toolchain/abe.git@12345"
out="`get_srcdir $in`"
if test x"${out}" = x"${local_snapshots}/abe.git@12345"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_srcdir returned ${out}"
fi

testing="get_srcdir: eglibc special case"
in="eglibc.git~multi/part/branch@12345"
out="`get_srcdir $in`"
if test x"${out}" = x"${local_snapshots}/eglibc.git~multi-part-branch@12345"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_srcdir returned ${out}"
fi

mkdir -p "${local_snapshots}/eglibc.git~multi-part-branch@12345/libc"
testing="get_srcdir: eglibc special case once /libc directory exists"
in="eglibc.git~multi/part/branch@12345"
out="`get_srcdir $in`"
if test x"${out}" = x"${local_snapshots}/eglibc.git~multi-part-branch@12345/libc"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_srcdir returned ${out}"
fi
