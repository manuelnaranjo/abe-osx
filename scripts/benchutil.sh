set -o pipefail
set -o nounset

function get_addr
{
  local hostname="${1:-localhost}"
  local listener_addr
  if test x"${hostname}" = xlocalhost; then
    listener_addr="`hostname -I`"
  else
    listener_addr="`ssh -F /dev/null -o PasswordAuthentication=no -o PubkeyAuthentication=yes ${hostname} 'hostname -I'`"
  fi
  if test $? -ne 0; then
    echo "Failed to run 'hostname -I' on ${hostname}" 1>&2
    return 1
  fi

  #We only try to support IPv4 for now
  listener_addr="`echo ${listener_addr} | tr ' ' '\n' | grep '^\([[:digit:]]\{1,3\}\.\)\{3\}[[:digit:]]\{1,3\}$'`"
  if test $? -ne 0; then
    echo "No IPv4 address found, aborting" 1>&2
    return 1
  fi

  #We don't try to figure out what'll happen if we've got multiple IPv4 interfaces
  if test "`echo ${listener_addr} | wc -w`" -ne 1; then
    echo "Multiple IPv4 addresses found, aborting" 1>&2
    return 1
  fi

  echo "${listener_addr}" | sed 's/^[[:blank:]]*//' | sed 's/[[:blank:]]*$//'
}

#Attempt to use read to discover whether there is a record to read from the producer
#If we time out, check to see whether the producer still seems to be alive.
#We can check more than one pid, if we have visibility of some other process(s) that we
#would also like to monitor while we wait to read something. If any of these
#processes seem dead then return 2, otherwise keep trying to read.
#Once we've established that there seems to be a record, try to read it with a
#read timeout. If we fail to read within read_timeout, return 1 to indicate
#read failure - but the producer may still be alive in this case.
#Can also set a deadline - bgread will return 3 if it hasn't seen any new output
#before deadline expires. deadline is only checked at read_timeout intervals.
#Typical invocation: foo="`bgread ${child_pid} <&3`"
#Invocation with read checks every 5 seconds, failure after 2 minutes and two
#pids to monitor:
#foo="`bgread -T 120 -t 5 ${child_pid} ${other_pid} <&3`"
function bgread
{
  OPTIND=1
  local read_timeout=60
  local deadline=
  local pid

  while getopts T:t: flag; do
    case "${flag}" in
      t) read_timeout="${OPTARG}";;
      T) deadline="$((${OPTARG} + `date +%s`))";;
      *)
         echo "Bad arg" 1>&2
         return 1
      ;;
    esac
  done
  shift $((OPTIND - 1))

  if test $# -eq 0; then
    echo "No pid(s) to poll!" 1>&2
    return 1
  fi
  local buffer=''
  local line=''

  #We have to be careful here. If the read times out when there was a partial
  #record on the fifo then the part that has been read just gets discarded. We
  #can avoid this problem by using -N to ensure that we read the minimal amount
  #and DO NOT discard it. -N 0 might be intuited to do the right thing, but is
  #arguably undefined behaviour and empirically doesn't work.
  #Read 1 char then timeout if it isn't a delimiter: buffer is the char, exit code 0 OR
  #Read the delimiter, don't timeout: buffer is empty, exit code 0 OR
  #Fail to read any chars coz there aren't any, then timeout: buffer is empty, exit code 1
  while ! read -N 1 -t "${read_timeout}" buffer; do
    for pid in "$@"; do
      kill -0 "${pid}" > /dev/null 2>&1 || return 2
    done
    if test x"${deadline:-}" != x; then
      if test `date +%s` -ge ${deadline}; then
        echo "bgread timed out" 1>&2
        return 3
      fi
    fi
  done

  #If we get here, we managed to read 1 char. If we have a null string just
  #return it (the record was empty). Otherwise, assume the rest of the record is ready to be read,
  #especially within the generous timeout that we allow.
  if test x"${buffer:-}" != x; then
    read -t 60 line
    if test $? -ne 0; then
      echo "Record did not complete" 1>&2
      return 1
    fi
  fi
  echo "${buffer}${line}"
  return 0
}

