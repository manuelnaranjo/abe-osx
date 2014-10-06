#!/bin/bash

#Deps: lava-tool, auth token for lava-tool
set -o pipefail

release()
{
  if test -d "${temps}"; then
    rm -rf "${temps}"
    if test $? -ne 0; then
      echo "Failed to delete temporary file store ${temps}" 1>&2
    fi
  fi
  if test x"${listener_pid}" != x; then
    if ps -p "${listener_pid}"; then
      kill "${listener_pid}"
      wait "${listener_pid}"
    fi
  fi
  if test ${keep} -eq 0; then
    lava-tool cancel-job https://"${lava_server}" "${id}"
    if test $? -eq 0; then
      echo "Cancelled job ${id}" 1>&2
      exit 0
    else
      echo "Failed to cancel job ${id}" 1>&2
      exit 1
    fi
  else
    echo "Did not cancel job ${id} - keep requested" 1>&2
    echo "Run 'lava-tool cancel-job https://"${lava_server}" "${id}"' to cancel" 1>&2
    exit 0
  fi
}

lava_server="${LAVA_SERVER}"
lava_json=
boot_timeout="$((120*60))" #2 hours
keep=0
key=
while getopts s:j:b:kp: flag; do
  case "${flag}" in
    s) lava_server="${OPTARG}";;
    j) lava_json="${OPTARG}";;
    b) boot_timeout="$((OPTARG*60))";;
    k) keep=1;;
    p) key="${OPTARG}";;
    *)
       echo 'Unknown option' 1>&2
       exit 1
    ;;
  esac
done

expr ${lava_server:?'Must give a lava server (-l) or set $LAVA_SERVER'} > /dev/null

if ! test -f ${lava_json:?'Must give a json file (-j)'}; then
  echo "JSON file ${lava_json} not a file"
  exit 1
fi

shift $((OPTIND - 1))
if test ${#@} -ne 0; then
  echo "Unknown option(s): $@" 1>&2
  exit 1
fi

#Store the public key in key - if no public key file given on CLI, try a few
#sensible defaults. (We only ever end up sharing a public key, so there's no
#security issue here.)
if test x"$key" = x; then
  if ssh-add -l; then
    key="`ssh-add -L | head -n1 2>/dev/null`"
    if test $? -ne 0; then
      echo "Failed to get public key from ssh-agent" 1>&2
      exit 1
    fi
  elif test -f ~/.ssh/id_rsa; then
    key="`ssh-keygen -y -f ~/.ssh/id_rsa`"
    if test $? -ne 0; then
      echo "Failed to get public key from private key file" 1>&2
      exit 1
    fi
  else
    echo "Could not find a key to authenticate with target (tried ssh-agent, ~/.ssd/id_rsa)" 1>&2
    exit 1
  fi
else
  if test -f "${key}"; then
    #Build in a little protection against accidental private key publication
    if head -n 1 "${key}" | grep PRIVATE > /dev/null; then
      echo "Given key file appears to be a private key"
      exit 1
    elif head -n 1 "${key}" | grep -v ^ssh-; then
      echo "Given key file does not look like an ssh public key"
      exit 1
    fi
    key="`cat ${key}`"
  else
    echo "Public key file ${key} does not exist or is not a file" 1>&2
    exit 1
  fi
fi

#Convert key into a sed-friendly replacement string (i.e. escape chars that are special on the RHS of s//)
#Danger - Don't change the sed runes to backticks, they resolve differently and render all the matches as ampersands
key="$(set -f; echo ${key} | sed 's/[\/&]/\\&/g')"

temps="`mktemp -dt XXXXXXXXX`" || exit 1
trap "if test -d ${temps}; then rm -rf ${temps}; fi" EXIT
json_copy="${temps}/job.json"
listener_file="${temps}/listener_file"
sed "s/^\(.*\"PUB_KEY\":\)[^\"]*\".*\"[^,]*\(,\?\)[[:blank:]]*$/\1 \"${key}\"\2/" ${lava_json} > "${json_copy}"
if test $? -ne 0; then
  echo "Failed to populate json file with public key" 1>&2
  exit 1
fi

listener_addr=`hostname -I`
if test x"`echo ${listener_addr} | wc -l`" != x1; then
  echo "Warning: Multiple IPs found for current host, will use first one" 1>&2
fi
listener_addr="`hostname -I | head -n1 | sed 's/^[[:blank:]]*//' | sed 's/[[:blank:]]*$//'`"
if ! echo "${listener_addr}" | grep '^\([[:digit:]]\+\.\)\{3\}[[:digit:]]\+$' > /dev/null; then
  echo "${listener_addr} does not look like an IP address" 1>&2
  exit 1
fi

for listener_port in {4100..5100}; do
  #Try to listen on the port. nc will fail if something has snatched it.
  echo "Attempting to establish listener on ${listener_addr}:${listener_port}" 1>&2
  nc -kl "${listener_addr}" "${listener_port}" > "${listener_file}"&
  listener_pid=$!

  #nc doesn't confirm that it's got the port, so we spin until either:
  #1) We see that the port has been taken by our process
  #2) We see our process exit (implying that the port was taken)
  #3) We've waited long enough
  #(listener_pid can't be reused until we wait on it)
  for j in {1..5}; do
    if test x"`lsof -i tcp@${listener_addr}:${listener_port} | sed 1d | awk '{print $2}'`" = x"${listener_pid}"; then
      break 2; #success, exit outer loop
    elif ! ps -p "${listener_pid}" > /dev/null; then
      #listener has exited, reap it and go back to start of outer loop
      wait "${listener_pid}"
      listener_pid=
      continue 2
    else
      sleep 1
    fi
  done

  #We gave up waiting, kill and reap the nc process
  kill "${listener_pid}"
  wait "${listener_pid}"
  listener_pid=
done

#Pretty much use this as a fifo - had trouble when using an actual fifo,
#either in netcat or in my fingers
exec 4< <(tail -f "${listener_file}")

if test x"${listener_pid}" != x; then
  echo "Listener pid ${listener_pid} at ${listener_addr}:${listener_port}, writing to file ${listener_file}"
else
  echo "Failed to find a free port in range 4100-5100" 1>&2
  exit 1
fi

sed -i "s/^\(.*\"LISTENER_ADDR\":\)[^\"]*\".*\"[^,]*\(,\?\)[[:blank:]]*$/\1 \"${listener_addr}\"\2/" "${json_copy}"
if test $? -ne 0; then
  echo "Failed to populate json file with listener ip" 1>&2
  exit 1
fi
sed -i "s/^\(.*\"LISTENER_PORT\":\)[^\"]*\".*\"[^,]*\(,\?\)[[:blank:]]*$/\1 \"${listener_port}\"\2/" "${json_copy}"
if test $? -ne 0; then
  echo "Failed to populate json file with listener port" 1>&2
  exit 1
fi

id="`lava-tool submit-job https://${lava_server} ${json_copy}`"
if test $? -ne 0; then
  echo "Failed to submit job" 1>&2
  echo "SERVER: https://${lava_server}" 1>&2
  echo "JSON: " 1>&2
  cat "${json_copy}" 1>&2
  exit 1
fi
trap release EXIT

#TODO: Should be able to use cut at the end of this pipe, but when lava-tool
#      is invoked through expect wrapper this line ends up with a carriage return 
#      at the end. Should be fixed on the expect side, or expect script should
#      be discarded, but hack it here for now.
id="`echo ${id} | grep 'submitted as job id: [[:digit:]]\+' | grep -o '[[:digit:]]\+'`"
if test $? -ne 0; then
  echo "Failed to read job id" 1>&2
  echo "Input string was: ${id}" 1>&2
  echo "JSON: " 1>&2
  cat "${json_copy}" 1>&2
  exit 1
fi
echo "Dispatched LAVA job ${id}"

while true; do
  sleep 60
  jobstatus="`lava-tool job-status https://${lava_server} ${id}`"
  if test $? -ne 0; then
    echo "Job ${id} disappeared!" 1>&2
    exit 1
  fi
  echo "${jobstatus}" | grep 'Job Status: Running' > /dev/null
  if test $? -eq 0; then
    echo "Job ${id} is running, waiting for boot"
    break
  fi
done

read -t "${boot_timeout}" user_ip <&4

if test $? -ne 0; then
  echo "read -t ${boot_timeout} user_ip < ${listener_file}"
  exit 1
fi
if test x"${user_ip}" = x; then
  echo "LAVA boot failed, or abandoned after $((boot_timeout/60)) minutes" 1>&2
  exit 1
fi

echo "LAVA target ready at ${user_ip}"
#Continue to report whatever comes across the listener
while true; do
  read line <&4
  echo "${line}"
done
