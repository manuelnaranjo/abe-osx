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
