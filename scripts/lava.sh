#!/bin/bash

#Deps: lava-tool, auth token for lava-tool
set -o pipefail

release()
{
  if test x"${keep}" = x; then
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

dispatch_timeout=1 #720 #12 hours - too pessimistic for some targets, too optimistic for others
boot_timeout=90 #1.5 hours - target-dependent pessimism

#TODO: error checks here
lava_server=$1
lava_json=$2
dispatch_timeout=$3
boot_timeout=$4
keep=$5
#thing_to_run=$3
#cmd_to_run=${4//\"/\\\"}
#keyfile=$5 #Must have suitable permissions. Could be the same private key we're using for ssh authentication.

#Make public key safe to use in a sed replace string
#Danger - Don't change to backticks, they resolve differently and render all the matches as ampersands
subkey=$(ssh-keygen -y -f ~/.ssh/id_rsa | sed 's/[\/&]/\\&/g')

#TODO: Error check, make parameterisable?
t2=`mktemp -t XXXXXXXXX` || exit 1
sed "s/^\(.*\"PUB_KEY\":\)[^\"]*\".*\"[^,]*\(,\?\)[[:blank:]]*$/\1 \"${subkey}\"/" $lava_json > $t2
#TODO submit-results/bundle stream


id=`lava-tool submit-job https://${lava_server} ${t2}`
if test $? -ne 0; then
  echo Failed to submit job > /dev/stderr
  rm -f $t2
  exit 1
fi
trap release EXIT
rm -f $t2
id=`echo $id | grep '^submitted as job id: [[:digit:]]\+$' | cut -d ' ' -f 5`
if test $? -ne 0; then
  echo "Failed to read job id" > /dev/stderr
  exit 1
fi
echo "Dispatched LAVA job $id"

for ((i=0; i<${dispatch_timeout}; i++)); do
  sleep 60
  jobstatus=`lava-tool job-status https://${lava_server} ${id}`
  echo "${jobstatus}" | grep '^Job Status: Running$' > /dev/null
  if test $? -eq 0; then
    echo "Job ${id} is running, waiting for boot"
    break
  fi
done
if test $i -eq ${dispatch_timeout}; then
  echo "Timed out waiting for job to dispatch (waited ${dispatch_timeout} minutes)" 1>&2
  exit 1
fi

#TODO: A more generic approach would take a regexp to watch for boot completion as a parameter, and echo it
#      for caller to extract interesting information from
for ((i=0; i<${boot_timeout}; i++)); do
  sleep 60

  #Check job is still running - sometimes jobs just give up during boot
  if ! lava-tool job-status https://${lava_server} ${id} | grep '^Job Status: Running$' > /dev/null; then
    echo "LAVA target stopped running before boot completed" 1>&2
    exit 1 #TODO A few retries would be better than quitting - perhaps:
           #     release (would need to change the exits to returns, may be ok - would also want to force keep=0)
           #eval "$0" "$@" (will this screw up the process relationships - eg will we still get killed when we should, will we still return error codes to parent?)
  fi
  
  #Check the log to see if we are booted
  line=`lava-tool job-output https://$lava_server $id -o - | sed 's/[[:blank:]]*\r$//' | grep '^Please connect to: ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@\([[:digit:]]\+\.\)\{3\}[[:digit:]]\+ (.\+)$'`
  if test $? -eq 0; then
    user_ip=`echo $line | grep -o '[^[:blank:]]\+@\([[:digit:]]\+\.\)\{3\}[[:digit:]]\+'`
    echo "LAVA target ready at ${user_ip}"
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
