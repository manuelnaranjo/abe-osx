# tests for the gerrit REST API functions

set -x
echo "============= gerrit() tests ================"

review="/tmp/.gitreview"
cat <<EOF > ${review}
[gerrit]
	host=review.linaro.org
	port=29418
	project=toolchain/abe

[gitreview]
	username=buildslave
EOF

srcdir="/tmp"

out="`extract_gerrit_host ${srcdir}`"
if test x"${out}" = x"review.linaro.org"; then
    pass "extract_gerrit_host"
else
    ${fail_state} "extract_gerrit_host"
    fixme "extract_gerrit_host returned ${out}"
fi

out="`extract_gerrit_project ${srcdir}`"
if test x"${out}" = x"toolchain/gcc"; then
    pass "extract_gerrit_project"
else
    ${fail_state} "extract_gerrit_project"
    fixme "extract_gerrit_project returned ${out}"
fi

out="`extract_gerrit_username ${srcdir}`"
if test x"${out}" = x"buildslave"; then
    pass "extract_gerrit_project"
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

export BUILD_CAUSE="SCMTRIGGER"
export BUILD_CAUSE_SCMTRIGGER="true"
export GERRIT_CHANGE_ID="I39b6f9298b792755db08cb609a1a446b5e83603b"
export GERRIT_CHANGE_NUMBER="5282"
export GERRIT_CHANGE_OWNER="Foo Bar <foobar@linaro.org>"
export GERRIT_CHANGE_OWNER_EMAIL="foobar@linaro.org"
export GERRIT_CHANGE_OWNER_NAME="Foo Bar"
export GERRIT_CHANGE_SUBJECT="Backport mania!"
export GERRIT_CHANGE_URL="https://review.linaro.org/5282"
export GERRIT_EVENT_TYPE="patchset-created"
export GERRIT_HOST="review.linaro.org"
export GERRIT_NAME="review.linaro.org"
export GERRIT_PATCHSET_NUMBER="1"
export GERRIT_PATCHSET_REVISION="6a645e59867c728c4b3bb897488faa00505725c4"
export GERRIT_PORT="29418"
export GERRIT_PROJECT="toolchain/gcc"
export GERRIT_REFSPEC="refs/changes/82/5282/1"
export GERRIT_TOPIC="foobar-backport-219656"

eval "`gerrit_info $HOME`"
if test x"${gerrit['PORT']}" = x"${GERRIT_PORT}"; then
    pass "gerrit_info PORT"
else
    ${fail_state} "gerrit_info PORT"
    fixme "gerrit_info PORT returned ${out}"
fi

if test x"${gerrit['REVIEW_HOST']}" = x"${GERRIT_HOST}"; then
    pass "gerrit_info REVIEW_HOST"
else
    ${fail_state} "gerrit_info REVIEW_HOST"
    fixme "gerrit_info REVIEW_HOST returned ${out}"
fi

if test x"${gerrit['CHANGE_ID']}" = x"${GERRIT_CHANGE_ID}"; then
    pass "gerrit_info PORT"
else
    ${fail_state} "gerrit_info PORT"
    fixme "gerrit_info PORT returned ${out}"
fi

if test x"${gerrit['REFSPEC']}" = x"${GERRIT_REFSPEC}"; then
    pass "gerrit_info REFSPEC"
else
    ${fail_state} "gerrit_info REFSPEC"
    fixme "gerrit_info REFSPEC returned ${out}"
fi

if test x"${gerrit['TOPIC']}" = x"${GERRIT_TOPIC}"; then
    pass "gerrit_info TOPIC"
else
    ${fail_state} "gerrit_info TOPIC"
    fixme "gerrit_info TOPIC returned ${out}"
fi

if test x"${gerrit['REVISION']}" = x"${GERRIT_PATCHSET_REVISION}"; then
    pass "gerrit_info REVISION"
else
    ${fail_state} "gerrit_info REVISION"
    fixme "gerrit_info REVISION returned ${out}"
fi

# These next tests require a working SSH auth
eval "`gerrit_query_status gcc`"
if test ${#query[@]} -gt 0; then
    pass "gerrit_query_status"
else
    if test x"${GERRIT_CHANGE_ID}" = x;then
	untested "gerrit_query_status"
    else
	fail "gerrit_query_status"
    fi
    fixme "gerrit_query_status returned ${out}"
fi

patch="`gerrit_fetch_patch ${gerrit['REVISION']}`"
if test "`echo $patch | grep -c "/tmp/gerrit[0-9]*.patch"`" -gt 0; then
    pass "gerrit_fetch_patch"
else
    if test x"${GERRIT_CHANGE_ID}" = x;then
	untested "gerrit_fetch_patch"
    else
	fail "gerrit_fetch_patch"
    fi
    fixme "gerrit_fetch_patch returned ${patch}"
fi
