#!/bin/bash

#TODO: Test/finish crouton support
#TODO: Test cpufreq (need a suitable target)

#Assumptions:
#1) We have are root, or a non-root user with passwordless sudo
#2) We don't care about cleanup. We have a cleanup handler for exit, but not
#   for signals. If you kill it, the target could be in a messy state.
#3) Target system is running Crouton or Ubuntu. It might well work with other
#   distributions, though, especially the parts that don't assume upstart.

#Error returns from the 'teardown' functions are ignored by default - we can
#still run the benchmark, just with less faith in repeatability. Specifying -c
#(cautiousness) will cause error on exit from a teardown function.

#Rebuild functions just return 0 if there is nothing to do

set -o pipefail
declare -a stopped_services
declare -a bound_processes
declare -a downed_interfaces
old_governor=

#The chroot part is often a nop, but will get us out of chroot if necessary
if test "${USER}" = root; then
  sudo="chroot /proc/1/root"
else
  sudo="sudo chroot /proc/1/root"
fi

cleanup()
{
  local ret
  local tmp
  start_services
  ret=$?
  restore_governor
  tmp=$?
  if test ${tmp} -gt ${ret}; then
    ret=${tmp}
  fi
  unbind_processes
  tmp=$?
  if test ${tmp} -gt ${ret}; then
    ret=${tmp}
  fi
  start_network
  tmp=$?
  if test ${tmp} -gt ${ret}; then
    ret=${tmp}
  fi

  if test ${ret} -gt 0; then
    echo "Problem restoring target system" 1>&2
    if test ${cautiousness} -eq 1; then
      exit 1
    fi
  fi
}

#Service control is a hairy land. We limit this function to handling upstart
#services for now - experiments so far seem to show this gives enough
#repeatability.  A little research indicates that:
# * The service utility will let us query both upstart and SysV-style init services
# * The service utility's output cannot necessarily be trusted
# * systemd is coming and might change the story further
#So we might want to improve this function in the future, or might be forced
#to change it.

#(Upstart) services can have dependencies that are hard to determine. Therefore
#we pass an ordered list of services to stop. We assume that:
#1) Target is in a known state
#2) List of services to stop is in a dependency-friendly order - though we may
#   often get away with ignoring this one for simple systems
#3) Network servies must be left alone as we handle them separately, if only
#   for convenience in interactive use

#In the past we've kept services matching these patterns:
#For crouton - 
#  "dbus|boot-services|shill|wpasupplicant|tty"
#For Linux -
#  keep="dbus|network|tty|rcS|auto-serial-console"
#If running on an Ubuntu desktop, keeping lightdm is sensible
#If running in a non-native chroot, keep binfmt-support
stop_services()
{
  local service
  local ret=0
  local service_status
  for service in `cat $1 | grep -v '^[[:blank:]]*#'`; do
    service_status=`${sudo} status "${service}"`
    if test $? -ne 0; then
      echo "Service '${service}' does not exist" 1>&2
      ret=1
      continue
    fi
    if echo "${service_status}" | grep ' stop/waiting$' > /dev/null; then
      echo "Service '${service}' already stopped" 1>&2
      continue
    fi
    if echo "${service_status}" | grep -v ' start/running$' > /dev/null; then
      echo "Service '${service}' does not appear to be running. Will try to stop it anyway. Are you specifying services in the right order?" 1>&2
    fi
    ${sudo} stop "${service}" > /dev/null
    if test $? -eq 0; then
      stopped_services+=("${service}")
    else
      echo "Service '${service}' could not be stopped" 1>&2
      ret=1
    fi
  done

  return ${ret}
}

#Start services in reverse order, to get the dependencies right
start_services()
{
  ret=0
  for ((i=${#stopped_services[@]}-1; i>=0; i--)); do
    ${sudo} start "${stopped_services[$i]}" > /dev/null
    if test $? -ne 0; then
      echo "Failed to restart service '${service}'" 1>&2
      ret=1
    fi
  done
  return ${ret}
}

set_governor()
{
  old_governor=`cpufreq-info -p | cut -f 3 -d " "`
  if test x"${old_governor}" = x \
      || ! ${sudo} cpufreq-set -g performance; then
      old_governor=""
      echo "Frequency scaling not supported" 1>&2
      return 1
  fi
}

restore_governor()
{
  #If freq scaling was unsupported then there is nothing to do
  if test x"${old_governor}" = x; then
    return 0
  fi
  ${sudo} cpufreq-set -g "${old_governor}"
  if test $? -gt 0; then
    echo "Unable to restore governor '${old_governor}'" 1>&2
  fi
}

#Bind all existing processes to CPU $1.  We then run benchmarks on CPU #1.
#Note that some processes cannot be bound, for example per-cpu kernel threads.
bind_processes()
{
  ${sudo} taskset -a -p -c $1 1 > /dev/null
  if test $? -ne 0; then
    echo "CPU bind not supported" 1>&2
    return 1
  fi

  bound_processes=(1)
  local all_processes
  all_processes=`ps ax --format='%p' | tail -n +2`
  if test $? -ne 0; then
    echo "Unable to list processes" 1>&2
    return 1
  fi

  local p
  local output
  local ret=0
  for p in ${all_processes}; do
    output="`${sudo} taskset -a -p -c $1 ${p} 2>&1`"
    if test $? -eq 0; then
      bound_processes+=("${p}")
    else
      if test "`ps -p \`ps -p $p -o ppid=\` -o cmd=`" != '[kthreadd]'; then
        local name="`grep Name: /proc/$p/status | cut -f 2`"
        echo "Failed to bind $name to CPU $1: $output" 1>&2
        ret=1
      fi
    fi
  done

  return ${ret}
}

#TODO: Strictly we shoud rebind to the same mask as before. That would be
#      very easy to do with an associative array, but I don't fancy putting
#      a bash 4 dependency here just yet
unbind_processes()
{
  if test ${#bound_processes[@]} -eq 0; then
    #Either taskset isn't working, or we didn't change any affinities
    return 0
  fi

  local p
  local ret=0
  for p in "${bound_processes[@]}"; do
    local output
    output="`${sudo} taskset -a -p 0xFFFFFFFF ${p} 2>&1`"
    if test $? -ne 0; then
      local name="`grep Name: /proc/$p/status | cut -f 2`"
      echo "Failed to unbind $name: $output" 1>&2
      ret=1
    fi
  done

  return ${ret}
}

#It would be more consistent to get the user to tell us how to manipulate the
#network, but this should work fine and it is convenient.
#We don't stop loopback, that would be madness
stop_network()
{
  #Stop network on crouton (untested)
  if croutonversion > /dev/null 2>&1; then
    #TODO: Rather than sleep 2, we should spin until we see that those services are stopped
    #      Although perhaps we can count on the stop command not exiting until the service is really stopped
    ${sudo} /bin/bash -c 'stop shill && stop wpasupplicant' && sleep 2
    if test $? -ne 0; then
      echo "Failed to stop network" 1>&2
      return 1
    fi
    downed_interfaces+=("crouton")
    return 0
  fi

  #Stop network on not-crouton

  #Get interfaces
  local -a interfaces
  #TODO: Remote corner case - this'll break on interface names with a space in
  interfaces=(`ifconfig -s | sed 1d | cut -d " " -f 1 | grep -v '^lo$'`) 
  if test $? -ne 0; then
    echo "Failed to read network interfaces" 1>&2
    return 1
  fi

  #Work out how to stop interfaces by stopping one of them
  local netcmd
  if ${sudo} stop network-interface INTERFACE="${interfaces[0]}" >/dev/null 2>&1; then
    netcmd="${sudo} stop network-interface INTERFACE="
  elif ${sudo} ifdown "${interfaces[0]}"; then #don't redirect stderr as this is our last try and failure information would be helpful
    netcmd="${sudo} ifdown "
  else
    echo "Cannot bring down network interfaces" 1>&2
    return 1
  fi
  downed_interfaces+=("${interfaces[0]}")
  interfaces=("${interfaces[@]:1}")

  #Stop any remaining interfaces
  local ret=0
  local interface
  for interface in "${interfaces[@]}"; do
    bash -c "${netcmd}${interface}"
    if test $? -eq 0; then
      downed_interfaces+=("${interface}")
    else
      echo "Failed to bring down network interface '${interface}'" 1>&2
      ret=1
    fi
  done

  #Ensure that interfaces are have finished going down
  #TODO: A little manpage scanning suggests that this isn't needed at least the upstart case
  for i in {0..4}; do
    if test x"`ifconfig -s | sed 1d | grep -v '^lo\b'`" = x; then
      break
    fi
    sleep 2
    echo "Brought-down network interface(s) "`ifconfig -s | sed 1d | cut -d ' ' -f 1`" still up after >10s" 1>&2
    echo "Will continue and hope for the best unless we're being cautious (-c)" 1>&2
    ret=1
  done
    
  return ${ret}
} 

start_network()
{
  if test ${#downed_interfaces[@]} -eq 0; then
    return 0
  fi

  if croutonversion > /dev/null 2>&1; then
    ${sudo} /bin/bash -c 'start wpasupplicant && start shill' && ${sudo} /sbin/iptables -P INPUT ACCEPT
    if test $? -ne 0; then
      echo "Failed to restart network" 1>&2
      return 1
    fi
    return 0
  fi

  local netcmd
  if ${sudo} /bin/bash -c "start network-interface INTERFACE=${downed_interfaces[0]}" >/dev/null 2>&1; then
    netcmd="${sudo} start network-interface INTERFACE="
  elif ${sudo} /bin/bash -c "ifup ${downed_interfaces[0]}"; then #don't redirect stderr as this is our last try and failure information would be helpful
    netcmd="${sudo} ifup "
  else
    echo "Cannot bring up network interfaces" 1>&2
    return 1
  fi
  downed_interfaces=("${downed_interfaces[@]:1}")

  local ret=0
  local interface
  for interface in "${downed_interfaces[@]}"; do
    bash -c "${netcmd}${interface}"
    if test $? -ne 0; then
      echo "Failed to bring up network interface '${interface}'" 1>&2
      ret=1
    fi
  done
  return ${ret}
} 

services_file=''
do_freq=0
bench_cpu=0
non_bench_cpu=''
cautiousness=0
do_network=0
while getopts s:fb:p:cn flag; do
  case $flag in
    s)  services_file="${OPTARG}";;
    f)  do_freq=1;;
    b)  bench_cpu="${OPTARG}";;
    p)  non_bench_cpu="${OPTARG}";;
    c)  cautiousness=1;;
    n)  do_network=1;;
    *)
        echo 'Unknown option' 1>&2
        exit 1
    ;;
  esac
done
shift $((OPTIND - 1))

#Cheap sanity checks, before we start tearing the target down
if test x"${services_file}" != x; then
  if test \! -f "${services_file}"; then
    echo "Services file '${services_file}' missing" 1>&2
    exit 1
  fi
  if test x"`cat ${services_file}`" = x; then
    echo "Services file '${services_file}' is empty" 1>&2
    exit 1
  fi
fi

echo "$bench_cpu" | grep '^[[:digit:]]\+$' > /dev/null
if test $? -ne 0; then
  echo "Benchmark CPU (-b) must be a decimal number" 1>&2
  exit 1
fi
echo "$non_bench_cpu" | grep '^[[:digit:]]*$' > /dev/null
if test $? -ne 0; then
  echo "Non-benchmark CPU (-p) must be null or a decimal number" 1>&2
  exit 1
fi
if test x"${bench_cpu}" = x"${non_bench_cpu}"; then
  echo "Benchmark CPU (-b) and non-benchmark CPU (-p) must be different" 1>&2
  exit 1
fi

cmd="$@"

taskset -c ${bench_cpu} true
if test $? -ne 0; then
  echo "Could not bind benchmark to CPU ${bench_cpu}" 1>&2
  exit 1
fi

#Put the target back in order before we quit
trap cleanup EXIT

if test x"${services_file}" != x; then
  stop_services "${services_file}"
  if test $? -ne 0 -a ${cautiousness} -eq 1; then
    exit 1
  fi
fi
if test ${do_freq} -eq 1; then
  set_governor
  if test $? -ne 0 -a ${cautiousness} -eq 1; then
    exit 1
  fi
fi
if test x"${non_bench_cpu}" != x; then
  bind_processes ${non_bench_cpu}
  if test $? -ne 0 -a ${cautiousness} -eq 1; then
    exit 1
  fi
fi
if test ${do_network} -eq 1; then
  stop_network
  if test $? -ne 0 -a ${cautiousness} -eq 1; then
    exit 1
  fi
fi

#Report status of the target
echo
echo "** Target Status **"
echo "==================="
echo "General Information:"
uname -a
if test -f /etc/lsb-release; then
  cat /etc/lsb-release
fi
echo
#A little research shows that it is unclear how
#reliable or complete the information from either
#initctl or service is. So we make a best effort.
echo "** (Possibly) Running Services:"
echo "According to initctl:"
${sudo} initctl list | grep running
if test $? -ne 0; then
  echo "*** initctl unable to list running services"
fi
echo "According to service:"
${sudo} service --status-all 2>&1 | grep -v '^...-'
if test $? -ne 0; then
  echo "*** service unable to list (possibly) running services"
fi
echo
echo "** CPUFreq:"
${sudo} cpufreq-info
if test $? -ne 0; then
  echo "*** Unable to get CPUFreq info"
fi
echo
echo "** Affinity Masks:"
all_processes=`ps ax --format='%p' | tail -n +2`
if test $? -eq 0; then
  for p in ${all_processes}; do
    ${sudo} taskset -a -p ${p}
    if test $? -ne 0; then
      echo "*** Unable to get affinity mast for process ${p}"
    fi
  done
else
  echo "*** Unable to get affinity mask info"
fi
echo
echo "** Live Network Interfaces:"
${sudo} ifconfig -s | sed 1d | cut -d ' ' -f 1
if test $? -ne 0; then
  echo "*** Unable to get network info"
fi
echo "==================="
echo

#Finally, run the command!
taskset -c ${bench_cpu} ${cmd}
if test $? -eq 0; then
  echo "Run of ${cmd} complete"
  exit 0
else
  echo "taskset -c ${bench_cpu} ${cmd} failed" 1>&2
  exit 1
fi
