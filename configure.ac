dnl  
dnl This script configures the build machine to have what it needs to
dnl build and test a GNU toolchain.
dnl 

AC_PREREQ(2.59c)
AC_INIT(cbuild, 2.0dev)
AC_CONFIG_SRCDIR([cbuild2.sh])
dnl AC_CONFIG_HEADERS([config.h])
dnl AC_CONFIG_MACRO_DIR([macros])

AC_CANONICAL_BUILD
dnl AC_CANONICAL_HOST

dnl --------------------------------------------------------
dnl Figure out development tool stuff
dnl --------------------------------------------------------
AC_PROG_CXX
AC_PROG_CC
AC_PROG_INSTALL

AC_PATH_PROG(WGET, wget)
AC_SUBST(WGET)
AC_PATH_PROG(CURL, curl)
AC_SUBST(CURL)
AC_PATH_PROG(SCP, scp)
AC_SUBST(SCP)
AC_PATH_PROG(RSYNC, rsync)
AC_SUBST(RSYNC)
AC_PATH_PROG(GITBZR, git-bzr)
AC_PATH_PROG(BASH, bash)
AC_SUBST(BASH)

if test x"${BASH}" = x; then
   AC_MSG_ERROR([You need Bash to run configure properly!])
fi

dnl Look for packages that do not have executables, so we are forced
dnl to ask the packaging system if they are installed. This is more
dnl reliable and portble than using pkg-config.
packages="git-svn  bzr-fastimport svn-all-fast-exp lynx wget rsync flex bison"
dpkg="`which dpkg`"
result=`echo ${dpkg} 2>&1 | grep -c found`
if test ${result} -eq 0; then
    # add Ubuntu specific packages
    packages="${packages} gcc-multilib lib32gmp-dev"
    for i in ${packages}; do
	AC_MSG_CHECKING([if $i is installed])
	exists="`dpkg -l | grep -c $i`"
	if test ${exists} -eq 0; then
	    AC_MSG_RESULT([no, install $i])
	else
	    AC_MSG_RESULT([yes])
	fi
    done
else
    yum="`which yum`"
    result="`echo ${yum} | grep -c found`"
    for i in ${packages}; do
	exis    ts="`rpm -q -a | grep -c $i`"
	if test ${exists} -eq 0; then
	    AC_MSG_RESULT([no, install $i])
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

dnl The local directory where sources from a DCCS are stored
AC_ARG_WITH(sources,
  AC_HELP_STRING([--with-sources], [where checked out sources are stored]),
  SOURCES=${withval},
  SOURCES="${HOME}/cbuild/sources")
AC_SUBST(SOURCES)

if test ! -d ${LOCAL_SNAPSHOTS}; then
   AC_MSG_WARN(${LOCAL_SNAPSHOTS} does not exist so creating directory!)
   mkdir -p ${LOCAL_SNAPSHOTS}
fi

dnl The local directory where snapshots are stored
AC_ARG_WITH(local-snapshots,
  AC_HELP_STRING([--with-local-snapshots], [Where downloaded tarballs are stored]),
  LOCAL_SNAPSHOTS=${withval},
  LOCAL_SNAPSHOTS="${HOME}/cbuild/snapshots")
AC_SUBST(LOCAL_SNAPSHOTS)

if test ! -d ${LOCAL_SNAPSHOTS}; then
   AC_MSG_WARN(${LOCAL_SNAPSHOTS} does not exist so creating directory!)
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

dnl Since the configure script is actually checked in, a developer
dnl does not need to have the GNU Autotools installed. However,
dnl installing these is a good idea anyway.
dnl AC_MSG_NOTICE([These are needed by everything to rebuild configure scripts and Makefiles])
AC_CHECK_PROGS(autoconf_prog,autoconf)
AC_CHECK_PROGS(automake_prog,automake)
AC_CHECK_PROGS(libtool_prog,libtool)
if test x"${autoconf_prog}" = x -o x"${automake_prog}" = x -o x"${libtool_prog}" = x; then
   AC_MSG_WARN([You should install autoconf, automake, and libtool])
fi

dnl DejaGnu is used for testing
AC_PATH_PROG(DEJAGNU,runtest)
if test x"${DEJAGNU}" = x; then
   AC_MSG_WARN([You should install dejagnu so you can run tests])
fi

dnl dnl The GNU toolchain, GCC specifically needs these libraries to build.
dnl AC_MSG_NOTICE([These are needed by GCC to compile and link])
dnl AC_CHECK_LIB(isl, isl_version)	dnl at least version 0.11.1
dnl isl_good=
dnl if test x"${ac_cv_lib_isl_isl_version}" = xyes; then
dnl   AC_MSG_CHECKING([if libisl is a high enough version])
dnl   AC_RUN_IFELSE([AC_LANG_SOURCE([
dnl   #include <isl/version.h>
dnl   #include <stdlib.h>
dnl   int main() {
dnl     if (strtof(isl_version()+4, NULL) >= 0.10)
dnl       { return 0; } else { return 1;}
dnl   }
dnl   ])],[isl_good="yes"], [isl_good="no"],[isl_good="cross"])
dnl   AC_MSG_RESULT(${isl_good})
dnl   if test x"${isl_good}" == xno; then
dnl      AC_MSG_WARN([libisl needs to be higher than or equal to 0.11.1])
dnl   fi
dnl fi

dnl AC_CHECK_LIB(cloog-isl, cloog_version)	dnl at least version 0.18.0
dnl cloog_good=
dnl if test x"${ac_cv_lib_cloog_isl_cloog_version}" = xyes; then
dnl   AC_MSG_CHECKING([if libcloog is a high enough version])
dnl   AC_RUN_IFELSE([AC_LANG_SOURCE([
dnl   #include <cloog/version.h>
dnl   #include <stdlib.h>
dnl   int main() {
dnl     if (strtof(cloog_version()+6, NULL) >= 0.18)
dnl       { return 0; } else { return 1;}
dnl   }
dnl   ])],[cloog_good="yes"], [cloog_good="no"],[cloog_good="cross"])
dnl   AC_MSG_RESULT(${cloog_good})
dnl   if test x"${cloog_good}" == xno; then
dnl      AC_MSG_WARN([libcloog-isl needs to be higher than 0.18])
dnl   fi
dnl fi

dnl AC_CHECK_LIB(gmp, __gmpz_size)	dnl at least version 4.3.2
dnl AC_CHECK_HEADER(gmp.h, has_gmp_h=yes, has_gmp_h=no, )	dnl at least version 4.3.2
dnl gmp_good=
dnl if test x"${ac_cv_header_gmp_h}" = xyes; then
dnl   AC_MSG_CHECKING([if libgmp is a high enough version])
dnl   AC_RUN_IFELSE([AC_LANG_SOURCE([
dnl   #include <gmp.h>
dnl   int main() {
dnl     if (__GNU_MP_VERSION >= 4)
dnl       { return 0; } else { return 1;}
dnl   }
dnl   ])],[gmp_good="yes"], [gmp_good="no"],[gmp_good="cross"])
dnl   AC_MSG_RESULT(${gmp_good})
dnl   if test x"${gmp_good}" = xno; then
dnl      AC_MSG_WARN([libgmp needs to be higher than 4.3.2])
dnl   fi
dnl fi

dnl AC_CHECK_HEADER(mpc.h)	dnl at least version 0.8.1
dnl AC_CHECK_LIB(mpc, mpc_init2)	dnl at least version 0.8.1
dnl mpc_good=
dnl if test x"${ac_cv_header_mpc_h}" = xyes; then
dnl   AC_MSG_CHECKING([if libmpc is a high enough version])
dnl   AC_RUN_IFELSE([AC_LANG_SOURCE([
dnl   #include <mpc.h>
dnl   #include <stdlib.h>
dnl   int main() {
dnl     if (strtof(MPC_VERSION_STRING, NULL) >= 0.8)
dnl       { return 0; } else { return 1;}
dnl   }
dnl   ])],[mpc_good="yes"], [mpc_good="no"],[mpc_good="cross"])
dnl   AC_MSG_RESULT(${mpc_good})
dnl   if test x"${mpc_good}" = xno; then
dnl      AC_MSG_WARN([libmpc needs to be higher than 0.8])
dnl   fi
dnl fi

dnl AC_CHECK_HEADER(mpfr.h)	dnl at least version 2.4.2
dnl AC_CHECK_LIB(mpfr, mpfr_cmp)   dnl at least version 2.4.2
dnl mpfr_good=
dnl if test x"${ac_cv_header_mpfr_h}" = xyes; then
dnl   AC_MSG_CHECKING([if libmpfr is a high enough version])
dnl   AC_RUN_IFELSE([AC_LANG_SOURCE([
dnl   #include <mpfr.h>
dnl   int main() {
dnl     if (__GNU_MP_VERSION >= 2)
dnl       { return 0; } else { return 1;}
dnl   }
dnl   ])],[mpfr_good="yes"], [mpfr_good="no"],[mpfr_good="cross"])
dnl   AC_MSG_RESULT(${mpfr_good})
dnl   if test x"${mpfr_good}" = xno; then
dnl      AC_MSG_WARN([libmpfr needs to be higher than 2.4.2])
dnl   fi
dnl fi

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
