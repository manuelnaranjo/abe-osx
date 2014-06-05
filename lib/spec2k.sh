. "${topdir}/lib/targetcontrol.sh" || exit 1

spec2k_init()
{
  _spec2k_init=true
  SPEC2k_SUITE="`get_URL cpu2000.git`"
  if test $? -gt 0; then
    error "get_URL failed to resolve spec2k"
    return 1
  fi
  SPEC2k_SUITE="`get_srcdir ${SPEC2k_SUITE}`"
  if test $? -gt 0; then
    error "get_source failed to resolve spec2k"
    return 1
  fi
  SPEC2k_XCFLAGS="`grep ^XCFLAGS:= ${topdir}/config/spec2k.conf \
    | awk -F":=" '{print $2}'`"
  SPEC2k_BUILD_LOG="`grep ^BUILD_LOG:= ${topdir}/config/spec2k.conf \
    | awk -F":=" '{print $2}'`"
  SPEC2k_RUN_LOG="`grep ^RUN_LOG:= ${topdir}/config/spec2k.conf \
    | awk -F":=" '{print $2}'`"
  SPEC2k_CONFIG="`grep ^CONFIG:= ${topdir}/config/spec2k.conf \
    | awk -F":=" '{print $2}'`"
  SPEC2k_EXTENSION="`grep ^EXTENSION:= ${topdir}/config/spec2k.conf \
    | awk -F":=" '{print $2}'`"
  SPEC2k_ITERATIONS="`grep ^ITERATIONS:= ${topdir}/config/spec2k.conf \
    | awk -F":=" '{print $2}'`"
  SPEC2k_WORKLOAD="`grep ^WORKLOAD:= ${topdir}/config/spec2k.conf \
    | awk -F":=" '{print $2}'`"
  SPEC2k_TESTS="`grep ^TESTS:= ${topdir}/config/spec2k.conf \
    | awk -F":=" '{print $2}'`"
  SPEC2k_TARBALL="`grep ^TARBALL:= ${topdir}/config/spec2k.conf \
    | awk -F":=" '{print $2}'`"
  SPEC2k_CONFIG="`grep ^CONFIG:= ${topdir}/config/spec2k.conf \
    | awk -F":=" '{print $2}'`"
  SPEC2k_ARCH="`grep ^ARCH:= ${topdir}/config/spec2k.conf \
    | awk -F":=" '{print $2}'`"
  if test "x$SPEC2k_BUILD_LOG" = x; then
    SPEC2k_BUILD_LOG="spec2k_build_log.txt"
  fi
  SPEC2k_BUILD_LOG="`pwd`/${topdir}/${SPEC2k_BUILD_LOG}"
  if test "x$SPEC2k_RUN_LOG" = x; then
    SPEC2k_RUN_LOG="spec2k_run_log.txt"
  fi
  SPEC2k_RUN_LOG="`pwd`/${topdir}/${SPEC2k_RUN_LOG}"
  if test "x$SPEC2k_TARBALL" = x; then
    error "TARBALL not defined in spec2k.conf"
    return 1
  fi
  if test "x$SPEC2k_CONFIG" = x; then
    error "CONFIG not defined in spec2k.conf"
    return 1
  fi
  if test "x$SPEC2k_ARCH" = x; then
    error "ARCH not defined in spec2k.conf"
    return 1
  fi

  #TODO: Watch out for any of this being undefined -- might be better to just have a 'flags' in the config file
  RUNSPECFLAGS="-c ${SPEC2k_CONFIG} -e ${SPEC2k_EXTENSION} -n ${SPEC2k_ITERATIONS} -i ${SPEC2k_WORKLOAD}"

  return 0
}

spec2k_run ()
{
  controlled_run cd ${SPEC2k_SUITE} \&\& . shrc \&\& runspec ${RUNSPECFLAGS} ${SPEC2k_TESTS} > ${SPEC2k_RUN_LOG} 2>&1
  for i in ${SPEC2k_SUITE}/result/C*.{asc,raw}; do
    echo $i:: >> ${SPEC2k_RUN_LOG}
    cat $i >> ${SPEC2k_RUN_LOG}
  done
  # Check to see if any errors happened in the run
  if cat ${SPEC2k_RUN_LOG} | grep -v reportable | grep errors > ${SPEC2k_RUN_LOG}.tmp; then
    mv ${SPEC2k_RUN_LOG}.tmp ${SPEC2k_RUN_LOG}-failed.txt;
  fi
  rm -f ${SPEC2k_RUN_LOG}.tmp
}

spec2k_build ()
{
  bash -c "cd ${SPEC2k_SUITE} && . shrc && runspec ${RUNSPECFLAGS} -a build ${SPEC2k_TESTS} >> ${SPEC2k_BUILD_LOG} 2>&1"
  if test $? -gt 0; then
    error "Failed while building spec with 'runspec ${RUNSPECFLAGS} -a build ${SPEC2k_TESTS} >> ${SPEC2k_BUILD_LOG} 2>&1'"
    return 1
  fi
}

spec2k_clean ()
{
  output="`cd ${SPEC2k_SUITE} && . shrc && runspec ${RUNSPECFLAGS} -a nuke ${SPEC2k_TESTS} 2>&1`"
  if test $? -gt 0; then
    error "Failed while cleaning spec with 'cd ${SPEC2k_SUITE} && . shrc && runspec ${RUNSPECFLAGS} -a nuke ${SPEC2k_TESTS}': $output"
    return 1
  fi
}


spec2k_build_with_pgo ()
{
  error "Not implemented"
  return 1
}

spec2k_testsuite ()
{
  error "Not implemented"
  return 1
}

spec2k_extract ()
{
  url="`get_source cpu2000.git`"
  if test $? -gt 0; then
      error "Couldn't find the source for ${do_checkout}"
      return 1 
  fi

  checkout ${url}
  if test $? -gt 0; then
      error "--checkout ${url} failed."
      return 1
  fi

  #We do 'install' as part of 'extract'
  if test $? -gt 0; then
    error "Could not cd to ${SPEC2k_SUITE}"
    return 1
  fi

  #This produces a pretty weird error on failure, but that's better than hanging on input
  output="`cd ${SPEC2k_SUITE} && (yes no | ./install.sh ${SPEC2k_ARCH} 2>&1)`" 
  if test $? -gt 0; then
    error "./install.sh ${SPEC2k_ARCH} failed: $output"
    return 1
  fi
}

