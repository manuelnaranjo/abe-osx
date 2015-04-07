# Tests for the report.sh script


#in="gdb-7.6~20121001+git3e2e76a.tar.bz2"
#out="`normalize_path ${in}`"
#if test x"${out}" = x"gdb-7.6~20121001@3e2e76a"; then
#    pass "normalize_path: tarball old git format"
#else
#    fail "normalize_path: tarball old git format"
#    fixme "${in} returned ${out}"
#fi


# Tests that make sure the output has the right output fields.
echo ""
echo "============= report.sh Output Fields tests ================"
echo ""

out="`${topdir}/scripts/report.sh ${topdir}/testsuite/report-files/x86_64-unknown-linux-gnu.aarch64-linux-gnu gcc`"
if test "`echo ${out} | grep -c aarch64-unknown-linux-gnu`" -gt 0; then
    pass "report.sh: target in output"
else
    fail "report.sh: target in output"
    fixme "returned ${out} in output"
fi

if test "`echo ${out} | grep -c ./26b48800dfae74319b1afa503f286934e5271b5e`" -gt 0; then
    pass "report.sh: revisions in output"
else
    fail "report.sh: revisions in output"
    fixme "returned ${out}"
fi

if test "`echo ${out} | grep -c Passes.*93398`" -gt 0; then
    pass "report.sh: passes in output"
else
    fail "report.sh: passes in output"
    fixme "returned ${out}"
fi

if test "`echo ${out} | grep -c Unexpected.*16`" -gt 0; then
    pass "report.sh: unexpected in output"
else
    fail "report.sh: unexpected in output"
    fixme "returned ${out}"
fi

if test "`echo ${out} | grep -c Expected.*266`" -gt 0; then
    pass "report.sh: expected in output"
else
    fail "report.sh: expected in output"
    fixme "returned ${out}"
fi
if test "`echo ${out} | grep -c Unresolved.*1`" -gt 0; then
    pass "report.sh: unresolved in output"
else
    fail "report.sh: unresolved in output"
    fixme "returned ${out}"
fi

if test "`echo ${out} | grep -c Unsupported.*1504`" -gt 0; then
    pass "report.sh: unsupported in output"
else
    fail "report.sh: unsupported in output"
    fixme "returned ${out}"
fi

# Tests that make look for regressions
echo ""
echo "============= report.sh Major Regression Extraction tests ================"
echo ""

if test "`echo ${out} | grep -c 'PASS => FAIL'`" -eq 2; then
    pass "report.sh: PASS => FAIL"
else
    fail "report.sh: PASS => FAIL"
    fixme "returned ${out}"
fi


if test "`echo ${out} | grep -c 'FAIL =>     '`" -eq 3; then
    pass "report.sh: FAILS Disappears"
else
    fail "report.sh: FAIL Disappears"
    fixme "returned ${out}"
fi

if test "`echo ${out} | grep -c 'PASS =>     '`" -eq 3; then
    pass "report.sh: PASS Disappears"
else
    fail "report.sh: PASS Disappears"
    fixme "returned ${out}"
fi

echo ""
echo "============= report.sh MINOR Regression Extraction tests ================"
echo ""

if test "`echo ${out} | grep -c 'FAIL => PASS'`" -gt 0; then
    pass "report.sh: FAIL => PASS"
else
    fail "report.sh: FAIL => PASS"
    fixme "returned ${out}"
fi

if test "`echo ${out} | egrep -c 'UNRESOLVED|UNSUPPORTED|UNTESTED'`" -eq 3; then
    pass "report.sh: UNSTABLE"
else
    fail "report.sh: UNSTABLE"
    fixme "returned ${out}"
fi

