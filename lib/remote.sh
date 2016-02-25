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
  OPTIND=1
  local retries=0
  while getopts r: flag; do
    case "${flag}" in
      r) retries="${OPTARG}";;
      *)
         echo "Bad arg" 1>&2
         return 1
      ;;
    esac
  done
  shift $((OPTIND - 1))

  local target="${1:-}"
  local sourcefile="${2:-}"
  local destfile="${3:-}"
  if test x"${target}" = x; then
    error "target not specified"
    return 1
  fi
  if test x"${sourcefile}" = x; then
    error "file/dir to copy not specified"
    return 1
  fi
  if test x"${destfile}" = x; then
    error "file/dir to copy to not specified"
    return 1
  fi
  shift 3

  local c
  for ((c = ${retries}; c >= 0; c--)); do
    dryrun "rsync -e \"ssh -o PasswordAuthentication=no -o PubkeyAuthentication=yes -o LogLevel=ERROR $* ${ABE_REMOTE_SSH_OPTS}\" -avzx '${target}:${sourcefile}' '${destfile}' > /dev/null"
    if test $? -eq 0; then
      return 0
    elif test $c -gt 0; then
      warning "Download of '${target}:${sourcefile}' to '${destfile}' failed: will try $c more times"
      sleep 3
    fi
  done
  error "Download of '${target}:${sourcefile}' to '${destfile}' failed"
  return 1
}

remote_upload()
{
  OPTIND=1
  local retries=0
  while getopts r: flag; do
    case "${flag}" in
      r) retries="${OPTARG}";;
      *)
         echo "Bad arg" 1>&2
         return 1
      ;;
    esac
  done
  shift $((OPTIND - 1))

  local target="${1:-}"
  local sourcefile="${2:-}"
  local destfile="${3:-}"
  if test x"${target}" = x; then
    error "target not specified"
    return 1
  fi
  if test x"${sourcefile}" = x; then
    error "file/dir to copy from not specified"
    return 1
  fi
  if test x"${destfile}" = x; then
    error "file/dir to copy to not specified"
    return 1
  fi
  shift 3

  local c
  for ((c = ${retries}; c >= 0; c--)); do
    dryrun "rsync -e \"ssh -o PasswordAuthentication=no -o PubkeyAuthentication=yes -o LogLevel=ERROR $* ${ABE_REMOTE_SSH_OPTS}\" -avzx '${sourcefile}' '${target}:${destfile}' > /dev/null"
    if test $? -eq 0; then
      return 0
    elif test $c -gt 0; then
      warning "Upload of '${sourcefile}' to '${target}:${destfile}' failed: will try $c more times"
      sleep 3
    fi
  done
  error "Upload of '${sourcefile}' to '${target}:${destfile}' failed"
  return 1
}

remote_exec()
{
  local target="${1//\"/\\\"}"
  local cmd="${2//\"/\\\"}"
  if test $# -lt 2; then
    error "Target and/or command not specified"
    return 1
  fi
  shift 2
  dryrun "ssh -o PasswordAuthentication=no -o PubkeyAuthentication=yes -o LogLevel=ERROR $* ${ABE_REMOTE_SSH_OPTS} \"${target}\" \"${cmd}\""
  return $?
}

remote_exec_async()
{
  local target="${1//\"/\\\"}"
  local cmd="${2//\"/\\\"}"
  local stdoutfile="${3}"
  local stderrfile="${4}"
  if test $# -lt 4; then
    error "Target and/or command not specified"
    return 1
  fi
  shift 4

  dryrun "ssh -n -o PasswordAuthentication=no -o PubkeyAuthentication=yes -o LogLevel=ERROR $* ${ABE_REMOTE_SSH_OPTS} ${target} -- \"exec 1>${stdoutfile}; exec 2>${stderrfile}; ${cmd}; echo EXIT CODE: \\\$?\" &"

  #Backgrounded command won't give a meaningful error code
  return 0
}
