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
  dryrun "rsync -e 'ssh -o PasswordAuthentication=no -o PubkeyAuthentication=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null' -avzx \"${sourcefile}\" \"${target}:${destfile}\""
  if test $? -ne 0; then
    error "rsync of '${sourcefile}' to '${target}:${destfile}' failed"
    return 1
  fi
  return 0
}

remote_exec()
{
  local target="${1//\"/\\\"}"
  local cmd="${2//\"/\\\"}"
  #TODO: Need some expect or timeout around this (e.g. we can hang indefinitely waiting for a password if we don't have key access)
  cmd="ssh -o PasswordAuthentication=no -o PubkeyAuthentication=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \"${target}\" \"${cmd}\""
  echo "RUN: $cmd" 1>&2
  dryrun "$cmd"
  return $?
}
