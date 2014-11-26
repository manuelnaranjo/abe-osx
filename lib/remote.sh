#TODO: Check that remote_{down,up)load behave as one might think
#TODO: Copy more of the dejagnu contract? e.g. return target-side name of copied file
#TODO: Tests?

#ON USING remote_exec*
#---------------------
#Quotes in command can be tricky. It's a good idea to use single-quotes when
#you can get away with it, because these are easier to think about. Remember:
#1) It isn't legal to escape a single-quote within single-quotes
#2) \ is only removed on expansion if it actualy escaped something
#3) \ only escapes $,`,\ when in `` (critically, it does not escape either kind of quote) - but if you push \ through to the execution of the contents of the `` (by typing \\ everywhere you want \) then will of course behave as normal when shoved through the shell commands within  the ``.
#Because of (1), it's sensible to use "" rather than '' when we're expecting input that
#may in turn contain quotes. And actually more robust to do that in general.
#I may never fathom the laws on behaviour of \, so further dragons may lurk here.
#Some examples of how to call:
#remote_exec2 localhost "grep 'foo bar' ~/file"
##Becomes ssh localhost "grep 'foo bar' ~/file"
##Becomes grep 'foo bar' ~/file
#
#x="`remote_exec2 localhost \"grep 'foo bar' ~/file\"`"
##Becomes ssh localhost "grep 'foo bar' ~/file"
##Becomes grep 'foo bar' ~/file
##So x ends up as the non-expanded, non-globbed output of that grep command
#
#Four ways to grep for a single-quote - the first 2 are vim-highlighting-friendly
#x="$(remote_exec2 localhost "grep \"'\" ~/file")"
#x="`remote_exec2 localhost "grep \\\"'\\\" ~/file"`"
#x="`remote_exec2 localhost \"grep \\\"'\\\" ~/file\"`"
#x="`remote_exec2 localhost "grep \\"'\\" ~/file"`"
#These (all?) effectively expand to:
##ssh localhost "grep \"'\" ~/file"
##grep "'" ~/file
##So x ends up as the non-expanded, non-globbed output of that grep command
#
#One way to grep for a double-quote.
#x="`remote_exec localhost "grep \\\"\\\\\\\\\\"\\\" ~/file"`"
#My personal favourite. Using single-quotes would be much simpler, but there
#are real cases where we can't do that. Expands to:
##ssh localhost "grep \"\\\"\" ~/file"
##grep "\"" ~/file
##So x ends up as the non-expanded, non-globbed output of that grep command

remote_download()
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
  dryrun "scp -o PasswordAuthentication=no -o PubkeyAuthentication=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -l 200 -rq '${target}:${sourcefile}' '${destfile}' > /dev/null"
  if test $? -ne 0; then
    error "Download of '${target}:${sourcefile}' to '${destfile}' failed"
    return 1
  fi
  return 0
}

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
  dryrun "scp -o PasswordAuthentication=no -o PubkeyAuthentication=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -l 200 -rq '${sourcefile}' '${target}:${destfile}' > /dev/null"
  if test $? -ne 0; then
    error "Upload of '${sourcefile}' to '${target}:${destfile}' failed"
    return 1
  fi
  return 0
}

remote_exec()
{
  local target="${1//\"/\\\"}"
  local cmd="${2//\"/\\\"}"
  if test $# -lt 2; then
    error "Target and/or command not specified"
    return 1
  fi
  if test $# -gt 2; then
    error "Too many args: $@"
    return 1
  fi
  dryrun "ssh -o PasswordAuthentication=no -o PubkeyAuthentication=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \"${target}\" \"${cmd}\""
  return $?
}

remote_exec_async()
{
  local target="${1//\"/\\\"}"
  local cmd="${2//\"/\\\"}"
  local stdoutfile="${3:-stdout}"
  local stderrfile="${4:-stderr}"
  if test $# -lt 2; then
    error "Target and/or command not specified"
    return 1
  fi
  if test $# -gt 4; then
    error "Too many args: $@"
    return 1
  fi

  #The combination of backgrounding the command that we run, the -n option to 
  #ssh (don't read stdin) and the redirection of stdout appears to be enough
  #to allow the ssh command to effectively do a dispatch-and-exit. Seems to
  #no actual need for nohup.

  #Logging command that docs say is needed to work
  #dryrun "ssh -n -o PasswordAuthentication=no -o PubkeyAuthentication=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR ${target} -- \"nohup bash -c 'exec 1>${stdoutfile}; exec 2>${stderrfile}; ${cmd}; echo EXIT CODE: \$?' &\""

  #Using command that experiments show is sufficient
  dryrun "ssh -n -o PasswordAuthentication=no -o PubkeyAuthentication=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR ${target} -- \"exec 1>${stdoutfile}; exec 2>${stderrfile}; ${cmd}; echo EXIT CODE: \\\$?\" &"
  return $?
}
