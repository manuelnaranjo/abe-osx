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

rm -f ${review}

