dnl  
dnl This script configures the build machine to have what it needs to
dnl build and test a GNU toolchain.
dnl 

AC_PREREQ(2.59c)
AC_INIT(cbuild, 2.0dev)
AC_CONFIG_SRCDIR([cbuild2.sh])
dnl AC_CONFIG_HEADERS([config.h])
dnl AC_CONFIG_MACRO_DIR([macros])

dnl --------------------------------------------------------
dnl Figure out development tool stuff
dnl --------------------------------------------------------
AC_PROG_CC
AC_PROG_CXX
if test x"${CC}" = x -a x"${CXX}" = x; then
   AC_MSG_ERROR([You need 'gcc' and 'g++' to fully run cbuild!])
fi
AC_PROG_INSTALL
dnl AC_CANONICAL_BUILD
dnl AC_CANONICAL_HOST

missing=
AC_PATH_PROG(WGET, wget)
AC_SUBST(WGET)
if test x"${WGET}" = x; then
   AC_MSG_WARN([You need 'wget' to fully run cbuild!])
   missing="${missing} wget"
fi

AC_PATH_PROG(CCACHE, ccache)

AC_PATH_PROG(LSBCC, lsbcc)
AC_PATH_PROG(LSBCXX, lsbc++)
if test x"${LSBCC}" = x; then
   AC_MSG_WARN([You need 'lsbcc' and 'lsbc++' to produce binary releases!])
#   missing="${missing} lsbcc"
fi
AC_SUBST(LSBCC)
AC_SUBST(LSBCXX)

dnl AC_PATH_PROG(GITBZR, git-bzr)
AC_PATH_PROG(BASH, bash)
AC_SUBST(BASH)
if test x"${BASH}" = x; then
   AC_MSG_WARN([You need Bash to run configure properly!])
   missing="${missing} bash"
fi

AC_PATH_PROG(FLEX, flex)
if test x"${FLEX}" = x; then
   AC_MSG_WARN([You need 'flex' to run configure  GCC properly!])
   missing="${missing} flex"
fi

AC_PATH_PROG(BISON, bison)
if test x"${BISON}" = x; then
   AC_MSG_WARN([You need 'bison' to run configure  GCC properly!])
   missing="${missing} bison"
fi

AC_PATH_PROG(AUTOGEN, autogen)
if test x"${AUTOGEN}" = x; then
   AC_MSG_WARN([You need 'autogen' to run configure for GCC properly!])
   missing="${missing} autogen"
fi

dnl Building GDB requires ncurses and termcap
AC_CHECK_LIB(ncurses, doupdate)
if test x${ac_cv_lib_ncurses_doupdate} != x"yes"; then
   AC_MSG_WARN([You need 'libncurses' to run configure for GDB properly!])
   missing="${missing} ncurses"
fi
AC_CHECK_LIB(z, gzread)

dnl Look for packages that do not have executables, so we are forced
dnl to ask the packaging system if they are installed. This is more
dnl reliable and portble than using pkg-config.
#packages="git-svn bzr-fastimport svn-all-fast-exp libncurses5-dev texinfo"
packages="texinfo gawk"
dpkg="`which dpkg`"
result=$?
if test ${result} -eq 0; then
    # add Ubuntu specific packages
    packages="${packages} gcc-multilib g++-multilib"
    for i in ${packages}; do
	AC_MSG_CHECKING([if $i is installed])
#	exists=`dpkg --get-selections | grep -c "^$i\[[:space:]\]*install"`
	exists="`dpkg -l $i | tail -1| cut -d ' ' -f 1`"
	if test x"${exists}" != x'ii'; then
	    AC_MSG_RESULT([no, install $i])
	    missing="${missing} $i"
	else
	    AC_MSG_RESULT([yes])
	fi
    done
else
    yum="`which yum`"
    result=$?
    for i in ${packages}; do
    	exists="`rpm -q -a $i| grep -c $i`"
	    if test ${exists} -eq 0; then
	       AC_MSG_RESULT([no, install $i])
	       missing="${missing} $i"
	else                      
	    AC_MSG_RESULT([yes])
	fi
    done
fi

dnl FIXME: Look for git-svn and git-bzr, bzr-fastimport svn-all-fast-export

dnl Get build date for helping us debugging
BUILDDATE="`date +%Y%m%d`"
AC_SUBST(BUILDDATE)

dnl While it's a bad idea to store the database access information in an unencrypted
dnl text file, this is useful for cbuild2 development itself. This option should never
dnl be used in a production environment. The default is read-only access. You can also
dnl set DBUSER and DBPASSWD in your environment, but that's also a possible security
dnl risk.
AC_ARG_WITH(dbuser,
  AC_HELP_STRING([--with-dbuser], [set the user name for the database]),
  dbuser=${withval} ; AC_MSG_WARN([The database user name is stored in an unencrypted text file which could be considered a security risk!]),
  dbuser='default')

AC_ARG_WITH(dbpasswd,
  AC_HELP_STRING([--with-dbpasswd], [set the user password for the database]),
  dbpasswd=${withval} ; AC_MSG_WARN([It's a bad idea to set the database password as it's stored in an unencrypted text file!]),
  dbpasswd='default')

AC_ARG_WITH(dbhost,
  AC_HELP_STRING([--with-dbhost], [set the database hostname]),
  dbhost=${withval} ; AC_MSG_WARN([The database hostname is stored in an unencrypted text file which could be considered a security risk!]),
  dbhost='localhost')

dnl The top of the cbuild tree
AC_ARG_WITH(toplevel,
  AC_HELP_STRING([--with-toplevel], []),
  CBUILD_TOP=${withval},
  CBUILD_TOP="${PWD}")
AC_SUBST(CBUILD_TOP)

if test ! -d ${CBUILD_TOP}; then
   AC_MSG_WARN([${CBUILD_TOP} does not exist so creating directory!])
   mkdir -p ${CBUILD_TOP}
fi

AC_ARG_WITH(sources-conf,
  AC_HELP_STRING([--with-sources-conf], []),
  SOURCES_CONF=${withval},
  SOURCES_CONF="${srcdir}/config/sources.conf")
AC_SUBST(SOURCES_CONF)

CBUILD_PATH=${srcdir}
AC_SUBST(CBUILD_PATH)

dnl The top of the cbuild tree
AC_ARG_WITH(sysroot,
  AC_HELP_STRING([--with-sysroot], []),
  SYSROOTS=${withval},
  SYSROOTS="${CBUILD_TOP}"/sysroots)
AC_SUBST(SYSROOTS)

if test x"${target}" != x"${build}"; then
  if test ! -d ${SYSROOTS}; then
    AC_MSG_WARN(${SYSROOTS} does not exist so creating directory!)
    mkdir -p ${SYSROOTS}
  fi
fi

dnl The local directory where snapshots are stored
AC_ARG_WITH(local-snapshots,
  AC_HELP_STRING([--with-local-snapshots], [Where downloaded tarballs are stored]),
  LOCAL_SNAPSHOTS=${withval},
  LOCAL_SNAPSHOTS="${CBUILD_TOP}/snapshots")
AC_SUBST(LOCAL_SNAPSHOTS)

if test ! -d ${LOCAL_SNAPSHOTS}; then
   AC_MSG_WARN(${LOCAL_SNAPSHOTS} does not exist so creating directory!)
   mkdir -p ${LOCAL_SNAPSHOTS}
fi

dnl The top directory for make install, also where all the components we build live
AC_ARG_WITH(local-builds,
  AC_HELP_STRING([--with-local-builds], []),
  LOCAL_BUILDS=${withval},
  LOCAL_BUILDS="${CBUILD_TOP}/builds")
AC_SUBST(LOCAL_BUILDS)

if test ! -d ${LOCAL_BUILDS}; then
   AC_MSG_WARN(${LOCAL_BUILDS} does not exist so creating directory!)
   mkdir -p ${LOCAL_BUILDS}
fi

dnl A URL to the remote directory where snapshots are stored
AC_ARG_WITH(remote-snapshots,
  AC_HELP_STRING([--with-remote-snapshots], []),
  REMOTE_SNAPSHOTS=${withval},
  REMOTE_SNAPSHOTS='http://cbuild.validation.linaro.org/snapshots')
AC_SUBST(REMOTE_SNAPSHOTS)

dnl Display the default paths so the user does not need to look in the host.conf file.
echo ""
AC_MSG_NOTICE([Downloaded snapshots will be stored in: ${LOCAL_SNAPSHOTS}])
AC_MSG_NOTICE([My builds will be installed in: ${LOCAL_BUILDS}])
AC_MSG_NOTICE([Sysroots will be installed in: ${SYSROOTS}])
AC_MSG_NOTICE([Remote snapshots will be fetched from: ${REMOTE_SNAPSHOTS}])
echo ""

dnl if you have SSH access to the remote machine
AC_ARG_ENABLE(ssh, AC_HELP_STRING([--enable-ssh], [If you have SSH access to remote build host]),
[case "${enableval}" in
  yes) ENABLE_SSH=yes ;;
  no)  ENABLE_SSH=no ;;
  *)   AC_MSG_WARN([bad value ${enableval} for enable-ssh option]) ;;
esac], ENABLE_SSH=no)
AC_SUBST(ENABLE_SSH)

dnl AC_ARG_WITH(snapshots,
dnl   AC_HELP_STRING([--with-snapshots], []),
dnl   snapshots=${withval},
dnl   snapshots='cbuild')

dnl Since the configure script is actually checked in, a developer
dnl does not need to have the GNU Autotools installed. However,
dnl installing these is a good idea anyway.
dnl AC_MSG_NOTICE([These are needed by everything to rebuild configure scripts and Makefiles])
AC_CHECK_PROGS(AUTOCONF,autoconf)
AC_CHECK_PROGS(AUTOMAKE,automake)
AC_CHECK_PROGS(LIBTOOL,libtool)
if test x"${AUTOCONF}" = x -o x"${AUTOMAKE}" = x -o x"${LIBTOOL}" = x; then
   AC_MSG_WARN([You should install autoconf, automake, and libtool])
fi

dnl DejaGnu is used for testing
AC_PATH_PROG(DEJAGNU,runtest)
if test x"${DEJAGNU}" = x; then
   AC_MSG_WARN([You should install dejagnu so you can run tests])
   missing="${missing} dejagnu"
fi

AC_PATH_PROG(NEWWORKDIR,git-new-workdir)
if test x"${NEWWORKDIR}" = x; then
   AC_MSG_WARN([You need to install git-new-workdir to use GIT!])
   missing="${missing} git-new-workdir"
fi

dnl Get and store often used information on this build machine
DBUSER=${dbuser}
AC_SUBST(DBUSER)
DBPASSWD=${dbpasswd}
AC_SUBST(DBPASSWD)
DBHOST=${dbhost}
AC_SUBST(DBHOST)

CPUS="`getconf _NPROCESSORS_ONLN`"
AC_SUBST(CPUS)
LIBC="`getconf GNU_LIBC_VERSION`"
AC_SUBST(LIBC)
KERNEL="`uname -r`"
AC_SUBST(KERNEL)
BUILDHOST="`${srcdir}/config.guess`"
BUILD_ARCH="`uname -m`"
if test x"${BUILD_ARCH}" = x"x86_64" -a -f /etc/debian_chroot; then
   BUILD_ARCH=i486
   BUILDHOST="`echo ${BUILDHOST} | sed -e 's:x86_64:i486:'`"
fi
AC_SUBST(BUILD_ARCH)
AC_SUBST(BUILDHOST)
HOSTNAME="`uname -n`"
AC_SUBST(HOSTNAME)
DISTRIBUTION="`lsb_release -sc`"
AC_SUBST(DISTRIBUTION)

AC_OUTPUT(host.conf)

if test x"${missing}" != x; then
    AC_MSG_ERROR([You need to install these packages: ${missing}])
fi

rm -f Makefile
cat<<EOF > Makefile
check:
	${srcdir}/testsuite/test.sh
EOF

# Local Variables:
# c-basic-offset: 2
# tab-width: 2
# indent-tabs-mode: nil
# End:

