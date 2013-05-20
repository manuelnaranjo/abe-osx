dnl  

AC_PREREQ(2.59c)
AC_INIT(cbuild, 2.0dev)
AC_CONFIG_SRCDIR([cbuild2.sh])
dnl AC_CONFIG_HEADERS([config.h])
dnl AC_CONFIG_MACRO_DIR([macros])

AC_CANONICAL_BUILD
AC_CANONICAL_HOST

dnl --------------------------------------------------------
dnl Figure out development tool stuff
dnl --------------------------------------------------------

AC_PROG_CXX
AC_PROG_CC
AC_PROG_INSTALL
AC_PROG_MAKE_SET

AC_PATH_PROG(WGET, wget)
AC_SUBST(WGET)
AC_PATH_PROG(CURL, curl)
AC_SUBST(CURL)
AC_PATH_PROG(SCP, scp)
AC_SUBST(SCP)
AC_PATH_PROG(RSYNC, rsync)
AC_SUBST(RSYNC)

dnl Get build date for helping us debugging
BUILDDATE="`date +%Y%m%d`"
AC_SUBST(BUILDDATE)

dnl While it's a bad idea to store the database access information in an unencrypted
dnl text file, this is useful for cbuild development itself. This option should never
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
   AC_MSG_WARN(${CBUILD_TOP} doesn't exist so creating directory!)
   mkdir -p ${CBUILD_TOP}
fi

dnl The local directory where snapshots are stored
AC_ARG_WITH(local-snapshots,
  AC_HELP_STRING([--with-local-snapshots], []),
  LOCAL_SNAPSHOTS=${withval},
  LOCAL_SNAPSHOTS="${HOME}/cbuild/snapshots")
AC_SUBST(LOCAL_SNAPSHOTS)

if test ! -d ${LOCAL_SNAPSHOTS}; then
   AC_MSG_WARN(${LOCAL_SNAPSHOTS} doesn't exist so creating directory!)
   mkdir -p ${LOCAL_SNAPSHOTS}
fi

dnl A URL to the remote directory where snapshots are stored
AC_ARG_WITH(remote-snapshots,
  AC_HELP_STRING([--with-remote-snapshots], []),
  REMOTE_SNAPSHOTS=${withval},
  REMOTE_SNAPSHOTS='http://cbuild.validation.linaro.org/snapshots')
AC_SUBST(REMOTE_SNAPSHOTS)

dnl if you have SSH access to the remote machine
AC_ARG_ENABLE(ssh, AC_HELP_STRING([--enable-ssh], [If you have SSH access to remote build host]),
[case "${enableval}" in
  yes) ENABLE_SSH=yes ;;
  no)  ENABLE_SSH=no ;;
  *)   AC_MSG_ERROR([bad value ${enableval} for enable-ssh option]) ;;
esac], ENABLE_SSH=no)
AC_SUBST(ENABLE_SSH)

dnl AC_ARG_WITH(snapshots,
dnl   AC_HELP_STRING([--with-snapshots], []),
dnl   snapshots=${withval},
dnl   snapshots='cbuild')

dnl Get and store often used information on this build machine
BUILDHOST=${build}
AC_SUBST(BUILDHOST)
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
BUILD_ARCH="`uname -p`"
AC_SUBST(BUILD_ARCH)
HOSTNAME="`uname -n`"
AC_SUBST(HOSTNAME)
DISTRIBUTION="`lsb_release -sc`"
AC_SUBST(DISTRIBUTION)

AC_OUTPUT(host.conf)

# Local Variables:
# c-basic-offset: 2
# tab-width: 2
# indent-tabs-mode: nil
# End:
