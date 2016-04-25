fixme()
{
    if test x"${debug}" = x"yes"; then
	echo "($BASH_LINENO): $*" 1>&2
    fi
}

trace()
{
    echo "TRACE(#${BASH_LINENO}): ${FUNCNAME[1]} ($*)" 1>&2
}

passes=0
pass()
{
    echo "PASS: $1"
    passes="`expr ${passes} + 1`"
}

xpasses=0
xpass()
{
    echo "XPASS: $1"
    xpasses="`expr ${xpasses} + 1`"
}

untested=0
untested()
{
    echo "UNTESTED: $1"
    untested="`expr ${untested} + 1`"
}

failures=0
fail()
{
    echo "FAIL: $1"
    failures="`expr ${failures} + 1`"
}

xfailures=0
xfail()
{
    echo "XFAIL: $1"
    xfailures="`expr ${xfailures} + 1`"
}

totals()
{
    echo ""
    echo "Total test results:"
    echo "	Passes: ${passes}"
    echo "	Failures: ${failures}"
    if test ${xpasses} -gt 0; then
	echo "	Unexpected Passes: ${xpasses}"
    fi
    if test ${xfailures} -gt 0; then
	echo "	Expected Failures: ${xfailures}"
    fi
    if test ${untested} -gt 0; then
	echo "	Untested: ${untested}"
    fi
}

