# tests for the dryrun function

echo "============= dryrun() tests ================"

dryrun="no"
testing="dryrun quote preservation (dryrun=no)"

# 'RUN' gets put on stderr.
out=`dryrun 'echo "enquoted"' 2>&1`
if test x"${out/$'\n'/ }" = x"RUN: echo \"enquoted\" enquoted"; then
  pass "${testing}"
else
  fail "${testing}"
fi

# Without piping stderr to stdout we shouldn't get 'RUN' output.
out=`dryrun 'echo "enquoted"' 2>/dev/null`
if test x"${out/$'\n'/}" = x"enquoted"; then
  pass "${testing}"
else
  fail "${testing}"
fi

dryrun="yes"
testing="dryrun quote preservation (dryrun=yes)"
out=`dryrun 'echo "enquoted"' 2>&1`
if test x"${out}" = 'xDRYRUN: echo "enquoted"'; then
  pass "${testing}"
else
  fail "${testing}"
fi
dryrun="no"

# Without the set -o pipefail fix these are the following inconsistent
# behaviors of the return value when using dryrun with an embedded | tee
#
# dryrun "internal_function_that_returns 1 | tee)" returns 1
# dryrun "$(subshell_of_internal_function_that_returns_1 | tee)" returns 1
# dryrun "external application that returns 1 | tee)" returns 0
# *** The last one of these is incorrect behavior ***

# These two functions test how dryrun <foo> | tee works with internal functions.
dryrun_return_1()
{
    echo "dryrun_return_1"
    return 1
}

dryrun_return_0()
{
    echo "dryrun_return_0"
    return 0
}

dryrun="no"

expected_ret=0
testing="dryrun return value propogation on success returning external call using (set -o pipefail)."
ret=
dryrun 'pwd 2>&1 | tee -a _dryrun' &>/dev/null
ret=$?
if test ${ret} -le ${expected_ret}; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "dryrun 'pwd 2>&1 | tee -a _dryrun' returned ${ret}"
fi

expected_ret=0
testing="dryrun return value propogation on success returning internal subshell function using (set -o pipefail)."
ret=
dryrun '$(dryrun_return_0 2>&1 | tee -a _dryrun)' &>/dev/null
ret=$?
if test ${ret} -le ${expected_ret}; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "dryrun '$$(dryrun_return_0 2>&1 | tee _dryrun)' returned ${ret}"
fi

expected_ret=0
testing="dryrun return value propogation on success returning internal function using (set -o pipefail)."
ret=
dryrun 'dryrun_return_0 2>&1 | tee -a _dryrun' &>/dev/null
ret=$?
if test ${ret} -le ${expected_ret}; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "dryrun 'dryrun_return_0 2>&1 | tee -a _dryrun' returned ${ret}"
fi

expected_ret=1
testing="dryrun return value propogation on failure returning external call using (set -o pipefail)."
ret=
dryrun 'ls unknownfile 2>&1 | tee -a _dryrun' &>/dev/null
ret=$?
if test ${ret} -ge ${expected_ret}; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "dryrun 'ls unknownfile 2>&1 | tee _dryrun' returned ${ret}"
fi

expected_ret=1
testing="dryrun return value propogation on failure returning internal subshell function using (set -o pipefail)."
ret=
dryrun '$(dryrun_return_1 2>&1 | tee -a _dryrun)' &>/dev/null
ret=$?
if test ${ret} -ge ${expected_ret}; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "dryrun '$$(dryrun_return_1 2>&1 | tee _dryrun)' returned ${ret}"
fi

expected_ret=1
testing="dryrun return value propogation on failure returning internal function using (set -o pipefail)."
ret=
dryrun 'dryrun_return_1 2>&1 | tee -a _dryrun' &>/dev/null
ret=$?
if test ${ret} -ge ${expected_ret}; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "dryrun 'dryrun_return_1 2>&1 | tee -a _dryrun' returned ${ret}"
fi

rm _dryrun

dryrun="no"

