#TODO: Check that remote_{down,up)load behave as one might think
#TODO: Copy more of the dejagnu contract? e.g. return target-side name of copied file
remote_upload()
{
  local target="${1//\"/\\\"}"
  local sourcefile="${2//\"/\\\"}"
  local destfile="${3//\"/\\\"}"
  if test x"${target}" = x; then
    error "target not specified"
    return 1
  fi
  if test x"${sourcefile}" = x; then
    error "file/dir to copy not specified"
    return 1
  fi
  if test x"${destfile}" = x; then
    destfile="${sourcefile}"
  fi
  #TODO: Need some expect or timeout around this (e.g. we can hang indefinitely waiting for a password if we don't have key access)
  dryrun "rsync -e 'ssh -o PasswordAuthentication=no -o PubkeyAuthentication=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR' -avzx \"${sourcefile}\" \"${target}:${destfile}\" > /dev/null 2>&1"
  if test $? -ne 0; then
    dryrun "scp -o PasswordAuthentication=no -o PubkeyAuthentication=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -rq \"${sourcefile}\" \"${target}:${destfile}\" > /dev/null"
    if test $? -ne 0; then
      error "Upload of '${sourcefile}' to '${target}:${destfile}' failed"
      return 1
    fi
  fi
  return 0
}

remote_exec()
{
  local target="${1//\"/\\\"}"
  local cmd="${2//\"/\\\"}"
  #TODO: Need some expect or timeout around this (e.g. we can hang indefinitely waiting for a password if we don't have key access)
  cmd="ssh -o PasswordAuthentication=no -o PubkeyAuthentication=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \"${target}\" \"${cmd}\""
  dryrun "$cmd"
  return $?
}

remote_exec_async()
{
  local target="${1//\"/\\\"}"
  local cmd="${2//\"/\\\"}" #I think cmd is not allowed to contain single quotes (')
  local stdoutfile="stdout"
  local stderrfile="stderr"
  if test x"$3" != x; then
    stdoutfile="${3//\"/\\\"}"
    if test x"$4" != x; then
      stderrfile="${4//\"/\\\"}"
    fi
  fi
  #TODO: Need some expect or timeout around this (e.g. we can hang indefinitely waiting for a password if we don't have key access) (or perhaps -n has me covered)

  #To divorce the cmd from the ssh process we need to nohup it and put it into the background
  #-n will prevent reading from stdin. I'm not convinced it's needed for this case, but the manpage says it is required when ssh is running in the background, so let's just do it.
  #nohup will read stdin from /dev/null, but of course its scope is different from -n. It will also redirect stdout to nohup.out and stderr to stdout, so we don't need to worry about that part. But the point of using nohup is to reparent the process on init rather than sshd, so that it can keep running in the absence of network - the IO stream thing is just a part of that
  #We redirect stderr to stdout so that any stderr from the nohup'd command will show up in nohup.out
  #But the actual output of the script will go to the files named above, where we construct the script

  #dryrunning a bit fiddly as we background the command - it might well
  #work as $! is the last _backgrounded_ process, but I don't want to
  #rely on nothing else getting backgrounded behind the function call
  #TODO Figure out the quoting rules sufficiently to put this cmd into a
  #     variable instead of writing it out twice
  if test x"${dryrun}" = xyes; then
    dryrun "ssh -n -o PasswordAuthentication=no -o PubkeyAuthentication=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR ${target} -- \"nohup bash some_script 2>&1 &\"&"
    return 0 #TODO: Dangerous if we try to kill process 0?
  fi
    #It's just much simpler to dump the wrapper gubbins and the cmd
    #into a script. But it would be nice to get rid of the tmpfile.
    #local script=`mktemp -t XXXXXXX`
    #if test $? -ne 0; then
    #  rm -f "${script}"
    #  error "Failed to create tmpfile for async script"
    #  return 1
    #fi
    #echo 'exec 4<&1' > "${script}"
    #echo 'exec 5<&2' >> "${script}"
    #echo "exec 1>${stdoutfile}" >> "${script}"
    #echo "exec 2>${stderrfile}" >> "${script}"
    #echo "$cmd" >> "${script}"
    #echo 'echo EXIT CODE: $?' >> "${script}"
    #echo 'exec 1<&4' >> "${script}"
    #echo 'exec 2<&5' >> "${script}"

    #ssh -n -o PasswordAuthentication=no -o PubkeyAuthentication=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR ${target} -- "nohup bash ${script} 2>&1 &"&
  ssh -n -o PasswordAuthentication=no -o PubkeyAuthentication=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR ${target} -- "nohup bash -c 'exec 1>${stdoutfile}; exec 2>${stderrfile}; ${cmd}; echo EXIT CODE: \$? | tee /dev/console' 2>&1 &"&

  return $! #$! is the last backgrounded process, so will be correct
}
