#!/bin/bash

#Deps: lava-tool, auth token for lava-tool
set -o pipefail
. "`dirname $0`"/listener.sh
if test $? -ne 0; then
  echo "Unable to source `dirname $0`/listener.sh"
fi
trap 'exit 1' TERM INT HUP QUIT

release()
{
  if test -d "${temps}"; then
    rm -rf "${temps}"
    if test $? -ne 0; then
      echo "Failed to delete temporary file store ${temps}" 1>&2
    fi
  fi
  if test ${keep} -eq 0; then
    lava-tool cancel-job https://"${lava_server}" "${id}"
    if test $? -eq 0; then
      echo "Cancelled job ${id}" 1>&2
      ret=0
    else
      echo "Failed to cancel job ${id}" 1>&2
      ret=1
    fi
  else
    echo "Did not cancel job ${id} - keep requested" 1>&2
    echo "Run 'lava-tool cancel-job https://"${lava_server}" "${id}"' to cancel" 1>&2
    ret=0
  fi
  kill -- -$BASHPID >/dev/null 2>&1 #This only makes sense when we were invoked directly, but should be harmless otherwise
  exit ${ret}
}

lava_server="${LAVA_SERVER}"
lava_json=
boot_timeout="$((120*60))" #2 hours
keep=0
key=${LAVA_SSH_KEYFILE}
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
  echo -n "Unknown option(s): " 1>&2
  for opt in "$@"; do
    echo -n " '${opt}'" 1>&2
  done
  echo 1>&2
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
    echo "Could not find a key to authenticate with target (tried ssh-agent, ~/.ssh/id_rsa)" 1>&2
    exit 1
  fi
else
  if test -f "${key}"; then
    #Build in a little protection against accidental private key publication
    if head -n 1 "${key}" | grep PRIVATE > /dev/null; then
      echo "Given key file appears to be a private key, will generate public key" 1>&2
      key="`ssh-keygen -y -f ${key}`"
      if test $? -ne 0; then
        echo "Failed to get public key from private key file" 1>&2
        exit 1
      fi
    elif head -n 1 "${key}" | grep -v ^ssh-; then
      echo "Given key file does not look like an ssh public key" 1>&2
      exit 1
    else
      key="`cat ${key}`"
    fi
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
if test $? -ne 0; then
  echo "Failed to create ${listener_file}" 1>&2
  exit
fi
cp "${lava_json}" "${json_copy}"
sed -i "s/^\(.*\"PUB_KEY\":\)[^\"]*\".*\"[^,]*\(,\?\)[[:blank:]]*$/\1 \"${key}\"\2/" "${json_copy}"
if test $? -ne 0; then
  echo "Failed to populate json file with public key" 1>&2
  exit 1
fi
sed -i "s+^\(.*\"server\":\)[^\"]*\".*\"[^,]*\(,\?\)[[:blank:]]*\$+\1 \"https://${USER}@validation.linaro.org/RPC2/\"\2+" "${json_copy}"
sed -i "s+^\(.*\"stream\":\)[^\"]*\".*\"[^,]*\(,\?\)[[:blank:]]*\$+\1 \"/private/personal/${USER}/\"\2+" "${json_copy}"

listener_addr="`get_addr`"
if test $? -ne 0; then
  echo "Unable to get IP for listener" 1>&2
  exit 1
fi
listener_port="`establish_listener ${listener_addr} ${listener_file} 4200 5200`"
if test $? -ne 0; then
  echo "Unable to establish listener" 1>&2
  exit 1
fi
#Pretty much use this as a pipe - using an actual fifo seems to give nc fits
exec 4< <(tail -f "${listener_file}")
echo "Listener ${listener_addr}:${listener_port}, writing to file ${listener_file}"

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

sleep 15 #A short delay here is handy when debugging (if the LAVA queues are empty then we'll dispatch fast, but not instantly)

#Monitor job status until it starts running or fails
#TODO: This block assumes that lava_tool doesn't return until the job is in 'Submitted' state, which I haven't checked
#TODO: In principle we want a timeout here, but we could be queued for a very long time, and that could be fine
while true; do
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
  echo "${jobstatus}" | grep 'Job Status: Submitted' > /dev/null
  if test $? -ne 0; then
    echo "Job ${id} has surprising status, giving up" 1>&2
    echo -e "${jobstatus}" 1>&2
    exit 1
  fi
  sleep 60
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
  read line < "${listener_file}"
  echo "${line}"
done
