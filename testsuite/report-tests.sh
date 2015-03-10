# Tests for the report.sh script

echo "============= report.sh tests ================"

#in="gdb-7.6~20121001+git3e2e76a.tar.bz2"
#out="`normalize_path ${in}`"
#if test x"${out}" = x"gdb-7.6~20121001@3e2e76a"; then
#    pass "normalize_path: tarball old git format"
#else
#    fail "normalize_path: tarball old git format"
#    fixme "${in} returned ${out}"
#fi

out="`${topdir}/scripts/report.sh ${topdir}/testsuite/report-files/x86_64-unknown-linux-gnu.aarch64-linux-gnu gcc`"
if test "`echo ${out} | grep -c aarch64-unknown-linux-gnu`" -gt 0; then
    pass "report.sh: target"
else
    fail "report.sh: target"
    fixme "returned ${out}"
fi

if test "`echo ${out} | grep -c ./26b48800dfae74319b1afa503f286934e5271b5e`" -gt 0; then
    pass "report.sh: revisions"
else
    fail "report.sh: revisions"
    fixme "returned ${out}"
fi

if test "`echo ${out} | grep -c Passes.*93398`" -gt 0; then
    pass "report.sh: passes"
else
    fail "report.sh: passes"
    fixme "returned ${out}"
fi

if test "`echo ${out} | grep -c Unexpected.*16`" -gt 0; then
    pass "report.sh: unexpected"
else
    fail "report.sh: unexpected"
    fixme "returned ${out}"
fi

if test "`echo ${out} | grep -c Expected.*266`" -gt 0; then
    pass "report.sh: expected"
else
    fail "report.sh: expected"
    fixme "returned ${out}"
fi
if test "`echo ${out} | grep -c Unresolved.*1`" -gt 0; then
    pass "report.sh: unresolved"
else
    fail "report.sh: unresolved"
    fixme "returned ${out}"
fi

if test "`echo ${out} | grep -c Unsupported.*1504`" -gt 0; then
    pass "report.sh: unsupported"
else
    fail "report.sh: unsupported"
    fixme "returned ${out}"
fi
