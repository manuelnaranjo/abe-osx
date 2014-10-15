# tests for the gerrit REST API functions

echo "============= gerrit() tests ================"

review="/tmp/.gitreview"
cat <<EOF > ${review}
[gerrit]
	host=review.linaro.org
	port=29418
	project=toolchain/cbuild2

[gitreview]
	username=buildslave
EOF

srcdir="/tmp"

# FIXME: Note these following test cases only PASS if you have the source
# directories created already.
if test -d ${srcdir}; then
    fail_state=fail
else
    fail_state=untested
fi

out="`extract_gerrit_host ${srcdir}`"
if test x"${out}" = x"review.linaro.org"; then
    pass extract_gerrit_host""
else
    ${fail_state} "extract_gerrit_host"
    fixme "extract_gerrit_host returned ${out}"
fi

out="`extract_gerrit_project ${srcdir}`"
if test x"${out}" = x"toolchain/cbuild2"; then
    pass extract_gerrit_project""
else
    ${fail_state} "extract_gerrit_project"
    fixme "extract_gerrit_project returned ${out}"
fi

out="`extract_gerrit_username ${srcdir}`"
if test x"${out}" = x"buildslave"; then
    pass extract_gerrit_project""
else
    ${fail_state} "extract_gerrit_project"
    fixme "extract_gerrit_project returned ${out}"
fi

out="`extract_gerrit_port ${srcdir}`"
if test x"${out}" = x"29418"; then
    pass "extract_gerrit_port"
else
    ${fail_state} "extract_gerrit_port"
    fixme "extract_gerrit_port returned ${out}"
fi

rm -f ${review}

# FIXME: Note these following test cases only PASS if you have the source
# directories created already.
#srcdir="${local_snapshots}/gcc.git"
srcdir="/linaro/shared/snapshots/gcc.git"
if test -d ${srcdir}; then
    out="`get_git_revision ${srcdir}`"
    out="`echo ${out} | grep -o [a-z0-9]\*`"
    if test x"${out}" != x; then
	pass "get_git_revision"
    else
	${fail_state} "get_git_revision"
	fixme "get_git_revision returned ${out}"
    fi
fi

