#TODO: Check that remote_{down,up)load behave as one might think
#TODO: Copy more of the dejagnu contract? e.g. return target-side name of copied file
#TODO: Tests?
remote_upload()
{
  local target="$1"
  local sourcefile="$2"
  local destfile="$3"
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
  dryrun "rsync -e 'ssh -o PasswordAuthentication=no -o PubkeyAuthentication=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR' -avzx '${sourcefile}' '${target}:${destfile}' > /dev/null 2>&1"
  if test $? -ne 0; then
    dryrun "scp -o PasswordAuthentication=no -o PubkeyAuthentication=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -rq '${sourcefile}' '${target}:${destfile}' > /dev/null"
    if test $? -ne 0; then
      error "Upload of '${sourcefile}' to '${target}:${destfile}' failed"
      return 1
    fi
  fi
  return 0
}

remote_exec()
{
  local target="$1"
  local cmd="$2"
  if test ${#@} -lt 2; then
    error "Target and/or command not specified"
    return 1
  fi
  dryrun "ssh -o PasswordAuthentication=no -o PubkeyAuthentication=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR '${target}' '${cmd}'"
  return $?
}

remote_exec_async()
{
  local target="$1"
  local cmd="$2"
  local stdoutfile="${3:-stdout}"
  local stderrfile="${4:-stderr}"
  if test ${#@} -lt 2; then
    error "Target and/or command not specified"
    return 1
  fi

  #To divorce the cmd from the ssh process we need to nohup it and put it into
  #the background.
  #ssh -n: Prevent reading from stdin. I don't think it's needed for this case,
  #but the manpage says it is required when ssh is running in the background
  #so I just do it.
  #nohup: Reparent process on init. Read stdin from /dev/null (within the shell
  #on the remote). It will also redirect stdout to nohup.out and stderr to
  #stdout, but we're redirecting those so nohup won't.
  #The combination of backgrounding the command that we run, the -n option to 
  #ssh and the redirection of stdout appears to be enough to allow the ssh command
  #to effectively do a dispatch-and-exit.

  #Logging command that docs say is needed to work
  #dryrun "ssh -n -o PasswordAuthentication=no -o PubkeyAuthentication=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR ${target} -- \"nohup bash -c 'exec 1>${stdoutfile}; exec 2>${stderrfile}; ${cmd}; echo EXIT CODE: \$? | tee /dev/console' &\""

  #Using command that experiments show is sufficient (it's a bit less complicated)
  dryrun "ssh -n -o PasswordAuthentication=no -o PubkeyAuthentication=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR ${target} -- 'exec 1>${stdoutfile}; exec 2>${stderrfile}; ${cmd}; echo EXIT CODE: \$? | tee /dev/console' &"
  return $?
}
