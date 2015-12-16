# tests for the component data structure

abe_path=/linaro/src/linaro/abe/parser
. ${abe_path}/testsuite/common.sh
. ${abe_path}/lib/component.sh

echo "============= component_init() tests ================"

# FIXME: Note these following test cases only PASS if you have the source
# directories created already.

component_init ld BRANCH="aa" URL="http://cc" REVISION="12345abcdef" gas FILESPEC="bb"
if test $? -eq 0; then
    pass "component_init() two data structures"
    init="yes"
else
    fail "component_init() two data structures"
    init="no"
fi

echo "============= set_component_*() tests ================"

disp="URL is set"
if test x"${init}" = x"yes"; then
    if test x"${ld[URL]}" = x"http://cc"; then
	pass "${disp}"
    else
	fail "${disp}"
	fixme "${disp}"
    fi
else
    untested  "${disp}"
fi

disp="FILESPEC is set"
if test x"${init}" = x"yes"; then
    if test x"${gas[FILESPEC]}" = x"bb"; then
	pass "${disp}"
    else
	fail "${disp}"
	fixme "${disp}"
    fi
else
    untested  "${disp}"
fi

# Test the setter functions
set_component_url ld "aaa"
disp="set_component_url() ld"
if test x"${init}" = x"yes"; then
    if test x"${ld[URL]}" = x"aaa"; then
	pass "${disp}"
    else
	fail "${disp}"
	fixme "${disp}"
    fi
else
    untested  "${disp}"
fi

set_component_srcdir ld "bbb"
disp="set_component_srcdir() ld"
if test x"${init}" = x"yes"; then
    if test x"${ld[SRCDIR]}" = x"bbb"; then
	pass "${disp}"
    else
	fail "${disp}"
	fixme "${disp}"
    fi
else
    untested  "${disp}"
fi

set_component_builddir ld "dddd"
disp="set_component_builddir() ld"
if test x"${init}" = x"yes"; then
    if test x"${ld[BUILDDIR]}" = x"dddd"; then
	pass "${disp}"
    else
	fail "${disp}"
	fixme "${disp}"
    fi
else
    untested  "${disp}"
fi

set_component_revision ld "eeeee"
disp="set_component_revision() ld"
if test x"${init}" = x"yes"; then
    if test x"${ld[REVISION]}" = x"eeeee"; then
	pass "${disp}"
    else
	fail "${disp}"
	fixme "${disp}"
    fi
else
    untested  "${disp}"
fi

set_component_branch ld "ffff"
disp="set_component_branch() ld"
if test x"${init}" = x"yes"; then
    if test x"${ld[BRANCH]}" = x"ffff"; then
	pass "${disp}"
    else
	fail "${disp}"
	fixme "${disp}"
    fi
else
    untested  "${disp}"
fi

set_component_filespec ld "ggg"
disp="set_component_filespec() ld"
if test x"${init}" = x"yes"; then
    if test x"${ld[FILESPEC]}" = x"ggg"; then
	pass "${disp}"
    else
	fail "${disp}"
	fixme "${disp}"
    fi
else
    untested  "${disp}"
fi

# Getter function tests
echo "============= get_component_*() tests ================"

disp="get_component_url() ld"
out="`get_component_url ld`"
if test x"${init}" = x"yes"; then
    if test x"${out}" = x"aaa"; then
	pass "${disp}"
    else
	fail "${disp}"
	fixme "${disp}"
    fi
else
    untested  "${disp}"
fi

disp="get_component_srcdir() ld"
out="`get_component_srcdir ld`"
if test x"${init}" = x"yes"; then
    if test x"${out}" = x"bbb"; then
	pass "${disp}"
    else
	fail "${disp}"
	fixme "${disp}"
    fi
else
    untested  "${disp}"
fi

disp="get_component_builddir() ld"
out="`get_component_builddir ld`"
if test x"${init}" = x"yes"; then
    if test x"${out}" = x"dddd"; then
	pass "${disp}"
    else
	fail "${disp}"
	fixme "${disp}"
    fi
else
    untested  "${disp}"
fi

disp="get_component_revision() ld"
out="`get_component_revision ld`"
if test x"${init}" = x"yes"; then
    if test x"${out}" = x"eeeee"; then
	pass "${disp}"
    else
	fail "${disp}"
	fixme "${disp}"
    fi
else
    untested  "${disp}"
fi

disp="get_component_filespec() ld"
out="`get_component_filespec ld`"
if test x"${init}" = x"yes"; then
    if test x"${out}" = x"ggg"; then
	pass "${disp}"
    else
	fail "${disp}"
	fixme "${disp}"
    fi
else
    untested  "${disp}"
fi

disp="get_component_branch() ld"
out="`get_component_branch ld`"
if test x"${init}" = x"yes"; then
    if test x"${out}" = x"ffff"; then
	pass "${disp}"
    else
	fail "${disp}"
	fixme "${disp}"
    fi
else
    untested  "${disp}"
fi
