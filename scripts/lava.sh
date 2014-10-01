#!/bin/bash

#Deps: lava-tool, auth token for lava-tool
set -o pipefail

release()
{
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
boot_timeout=120 #2 hours
keep=0
key=
while getopts s:j:b:kp: flag; do
  case "${flag}" in
    s) lava_server="${OPTARG}";;
    j) lava_json="${OPTARG}";;
    b) boot_timeout="${OPTARG}";;
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
    key="`ssh-add -L | head -n1`"
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

#TODO: Error check, make parameterisable?
t2=`mktemp -t XXXXXXXXX` || exit 1
sed "s/^\(.*\"PUB_KEY\":\)[^\"]*\".*\"[^,]*\(,\?\)[[:blank:]]*$/\1 \"${key}\"/" $lava_json > $t2
if test $? -ne 0; then
  echo "Failed to populate json file with public key"
  exit 1
fi
#TODO submit-results/bundle stream


id="`lava-tool submit-job https://${lava_server} ${t2}`"
if test $? -ne 0; then
  echo "Failed to submit job" > /dev/stderr
  rm -f $t2
  exit 1
fi
trap release EXIT
rm -f $t2

#TODO: Should be able to use cut at the end of this pipe, but when lava-tool
#      is invoked through expect wrapper this line ends up with a carriage return 
#      at the end. Should be fixed on the expect side, or expect script should
#      be discarded, but hack it here for now.
id="`echo ${id} | grep 'submitted as job id: [[:digit:]]\+' | grep -o '[[:digit:]]\+'`"
if test $? -ne 0; then
  echo "Failed to read job id" > /dev/stderr
  exit 1
fi
echo "Dispatched LAVA job $id"

while true; do
  sleep 60
  jobstatus="`lava-tool job-status https://${lava_server} ${id}`"
  if test $? -ne 0; then
    echo "Job ${id} disappeared!"
    exit 1
  fi
  echo "${jobstatus}" | grep 'Job Status: Running' > /dev/null
  if test $? -eq 0; then
    echo "Job ${id} is running, waiting for boot"
    break
  fi
done

#TODO: A more generic approach would take a regexp to watch for boot completion as a parameter, and echo it
#      for caller to extract interesting information from
for ((i=0; i<${boot_timeout}; i++)); do
  sleep 60

  #Check job is still running - sometimes jobs just give up during boot
  lava-tool job-status https://${lava_server} ${id} | grep 'Job Status: Running' > /dev/null
  if test $? -ne 0; then
    echo "LAVA target stopped running before boot completed" 1>&2
    exit 1 #TODO A few retries would be better than quitting - perhaps:
           #     release (would need to change the exits to returns, may be ok - would also want to force keep=0)
           #eval "$0" "$@" (will this screw up the process relationships - eg will we still get killed when we should, will we still return error codes to parent?)
  fi
  
  #Check the log to see if we are booted
  line="`lava-tool job-output https://$lava_server $id -o - | cat -v | sed 's/[[:blank:]]*\r$//' | grep 'Please connect to: ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@\([[:digit:]]\+\.\)\{3\}[[:digit:]]\+ (.\+)'`"
  if test $? -eq 0; then
    user_ip=`echo $line | grep -o '[^[:blank:]]\+@\([[:digit:]]\+\.\)\{3\}[[:digit:]]\+'`
    echo "LAVA target ready at ${user_ip}"
    break
  fi
done

#TODO: A more generic approach would be able to block forever (as we do now), OR poll for a 
#      string indicating job completion and then exit 0
if test $i -eq ${boot_timeout}; then
  echo "LAVA boot failed, or abandoned after ${boot_timeout} minutes" 1>&2
  exit 1
else
  sleep infinity #block until we get killed (which will release the target)
fi
