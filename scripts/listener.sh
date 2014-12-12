function get_addr
{
  local hostname="${1:-localhost}"
  local listener_addr
  listener_addr="`ssh ${hostname} 'hostname -I'`"
  if test $? -ne 0; then
    echo "Failed to run 'hostname -I' on ${hostname}" 1>&2
    return 1
  fi
  if test x"`echo ${listener_addr} | wc -l`" != x1; then
   echo "Warning: Multiple IPs found for ${hostname}, will use first one" 1>&2
  fi 
  listener_addr="`ssh ${hostname} 'hostname -I' | head -n1 | sed 's/^[[:blank:]]*//' | sed 's/[[:blank:]]*$//'`"
  if ! echo "${listener_addr}" | grep '^\([[:digit:]]\+\.\)\{3\}[[:digit:]]\+$' > /dev/null; then
    echo "${listener_addr} does not look like an IP address" 1>&2
    return 1
  fi
  echo "${listener_addr}"
  return 0
}

#Return 0 if we're inside the lava network
#Return 1 if we're outside the lava network
#Return 2 if we don't know where we are
#Typically, 2 will be returned if we can't ssh into the hackbox. This tends
#to mean we're not configured to do so and could happen both inside and outside
#the LAVA network.
function lava_network
{
  local hackbox_mac

  hackbox_mac="`ssh lab.validation.linaro.org 'cat /sys/class/net/eth0/address'`"
  if test $? -ne 0; then
    return 2 #We couldn't get the mac, stop trying to figure out where we are
  fi
  arp 10.0.0.10 | grep -q "${hackbox_mac}";
  if test $? -eq 0; then
    return 0
  else
    return 1
  fi
}

#Attempt to use read to discover whether there is a record to read from the producer
#If we time out, check to see whether the producer still seems to be alive.
#If it seems dead, return 2, otherwise keep trying to read.
#Once we've established that there seems to be a record, try to read it with a
#fixed timeout. If we fail to read within the timeout, return 1 to indicate
#read failure - but the producer may still be alive in this case.
#Typical invocation: foo="`bgread ${child_pid} 5 <&3`"
function bgread
{
  local pid=$1
  if test x"${pid}" = x; then
    echo "No pid to poll!" 1>&2
    return 1
  fi
  local timeout=${2:+60}
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
  while ! read -N 1 -t "${timeout}" buffer; do
    kill -0 "${pid}" > /dev/null 2>&1 || return 1
  done

  #If we get here, we managed to read 1 char. If we have a null string just
  #return it (the record was empty). Otherwise, assume the rest of the record is ready to be read,
  #especially within the generous timeout that we allow.
  if test x"${buffer}" != x; then
    read -t 60 line
    if test $? -ne 0; then
      echo "Record did not complete" 1>&2
      return 1
    fi
  fi
  echo "${buffer}${line}"
  return 0
}
