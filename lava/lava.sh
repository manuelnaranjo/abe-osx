#!/bin/bash
set -o pipefail

lava_server=$1
lava_json=$2
thing_to_run=$3
cmd_to_run=${4//\"/\\\"}
keyfile=$5 #Must have suitable permissions. Could be the same private key we're using for ssh authentication.
shift 5
#Remaining args are log files to copy back

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
rm -f $t2
id=`echo $id | grep '^submitted as job id: [[:digit:]]\+$' | cut -d ' ' -f 5`
if test $? -ne 0; then
  echo "Failed to read job id" > /dev/stderr
  exit 1
fi
echo "LAVA job id: $id"

for i in {1..90}; do #Wait up to 90 mins for boot
  sleep 60
  line=`lava-tool job-output $lava_server $id -o - | sed 's/[[:blank:]]*\r$//' | grep '^Please connect to: ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@\([[:digit:]]\+\.\)\{3\}[[:digit:]]\+ (.\+)$'`
  if test $? -eq 0; then
    user_ip=`echo $line | grep -o '[^[:blank:]]\+@\([[:digit:]]\+\.\)\{3\}[[:digit:]]\+'`
    uid=`echo $line | grep -o '(.\+)$' | sed 's/.\(.*\)./\1/'`
    uid=lava_${uid}_`date +%s`
    uid=`echo $uid | tr [[:blank:]] _`
    echo "Found target at ${user_ip}"
    echo "Will log to logs/$uid"
    break
  fi
done

#From here we are doing dispatch, not reservation. Nothing in here has anything to do with lava.
rsync -e 'ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null' -azvx $thing_to_run $user_ip: || exit 1
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $user_ip "${cmd_to_run}" || exit 1
rm -rf logs/$uid || exit 1
mkdir -p logs/$uid || exit 1
for log in $@; do
  mkdir -p logs/$uid/`dirname $log` || exit 1
  ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $user_ip "cat $log" | ccencrypt -k $keyfile > logs/$uid/$log || exit 1
done
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $user_ip "rm -rf $thing_to_run" #clean up, we don't want to leave source or data lying around


#And now we're back in target management (lava-specific)
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $user_ip stop_hacking
#TODO: Might want to collect some data here, too - git hash of the yaml files, for instance

#TODO: Basic hacking session images are nearly adeqate, but there will be some deps. How to specify? Again, cbuild2 copying would allow us to use configure.
#      Might be best just to customize the image - I believe I can even specify packages in the .json if the OS is flexible enough.
#      In the yaml, not the json. I just need to put a suitable yaml file in a repo. Should be able to cobble something from the hacking session scripts.
