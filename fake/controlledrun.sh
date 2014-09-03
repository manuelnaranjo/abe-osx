#!/bin/bash

#Assumptions:
#1) We have are root, or a non-root user with passwordless sudo
#2) We don't care about cleanup. We have a cleanup handler for exit, but not
#   for signals. If you kill it, the target could be in a messy state.

#The chroot part is often a nop, but will get us out of chroot if necessary
if test "${USER}" = root; then
  sudo="chroot /proc/1/root"
else
  sudo="sudo chroot /proc/1/root"
fi
declare -a stopped_services
declare -a bound_processes
declare -a downed_interfaces
old_governor=

cleanup()
{
  start_services
  restore_governor
  unbind_processes
  start_network
}

#Services can have dependencies that are hard to determine. Therefore we pass
#an ordered list of services to stop. We assume that:
#1) User knows about the target
#2) Target is in a known state

#TODO: Temporary notes
#Services to keep for crouton:
#  keep="dbus\|boot-services\|shill\|wpasupplicant"
#  keep="$keep\|tty2"
#Services to keep for 'Linux':
#  keep="dbus\|network"
#  #keep="$keep\lightdm\|binfmt-support"  #For Ubuntu chroot
#  keep="$keep\|auto-serial-console" #For Linaro dist target
#  keep="$keep\|tty1"
#  keep="$keep\|rcS" #For (just lava?) highbank

#TODO: Check the sysv/upstart distinction - are these commands good enough?
#      I think that stop/start/status probably are, not so sure about initctl list
stop_services()
{
  if \! -f service_list; then
    echo "No services to stop" 1>&2
    return 1
  fi

  local service
  for service in `cat service_list`; do
    ${sudo} status "${service}" | grep ' stop/waiting$' > /dev/null
    if test $? -eq 0; then
      echo "Service '${service}' already stopped" 1>&2
      return 1
    fi
    ${sudo} status "${service}" | grep ' start/running$' > /dev/null
    if test $? -ne 0; then
      echo "Could not determine state of service '${service}'" 1>&2
      return 1
    fi

    ${sudo} stop "${service}" 2>&1
    if test $? -eq 0; then
      stopped_services+=("${service}")
    else
      echo "Service '${service}' could not be stopped" 1>&2
      return 2
    fi
  done

  echo "Stopped requested services"
  echo "The following services were not requested to be stopped and are still running: "
  service=`${sudo} initctl list`
  if test $? -ne 0; then
    echo "Unable to list running services" 1>&2
  fi
}

start_services()
{
  local service
  for service in "${stopped_services[@]}"; do
    ${sudo} start "${service}"
    if test $? -ne 0; then
      echo "Failed to restart service '${service}'" 1>&2
    fi
  done
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
  if x"${old_governor}" = x; then
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
  ${sudo} taskset -a -p $1 1 > /dev/null
  if test $? -ne 0; then
    echo "CPU bind not supported" 1>&2
    return 1
  fi

  bound_processes=(1)
  local p
  local ret=0
  for p in "`ps ax --format='%p' | tail -n +2`"; do
    local output="`${sudo} taskset -a -p $1 ${p} 2>&1`"
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
    local output="`${sudo} taskset -a -p 0xFFFFFFFF ${p} 2>&1`"
    local name="`grep Name: /proc/$p/status | cut -f 2`"
    echo "Failed to unbind $name: $output" 1>&2
    ret=1
  done

  return ${ret}
}

#It would be more consistent to get the user to tell us how to manipulate the
#network, but this should work fine and it is convenient.
stop_network()
{
  #Stop crouton (untested)
  if croutonversion > /dev/null 2>&1; then
    #TODO: Rather than sleep 2, we should spin until we see that those services are stopped
    ${sudo} /bin/bash -c 'stop shill && stop wpasupplicant' && sleep 2
    if test $? -ne 0; then
      echo "Failed to stop network" 1>&2
      return 1
    fi
    return 0
  fi

  #Stop anything else
  #Get interfaces
  local interfaces=`ifconfig -s | sed 1d | cut -d " " -f 1`
  if test $? -ne 0; then
    echo "Failed to read network interfaces" 1>&2
    return 1
  fi

  #Work out how to stop interfaces by stopping one of them
  local netcmd
  if ${sudo} stop network-interface INTERFACE="${interfaces[0]}"; then
    netcmd="${sudo} stop network-interface INTERFACE="
  elif ${sudo} ifdown "${interfaces[0]}"; then
    netcmd="${sudo} ifdown "
  else
    echo "Cannot bring down network interfaces" 1>&2
    return 1
  fi
  downed_interfaces+=("${interfaces[0]}")

  #Stop any remaining interfaces
  local ret=0
  local interface
  for interface in "${interfaces[@]:1}"; do
    bash -c "${netcmd}${interface}"
    if test $? -eq 0; then
      downed_interfaces+=("${interface}")
    else
      echo "Failed to bring down network interface '${interface}'" 1>&2
      ret=1
    fi
  done

  #Ensure that interfaces are really down
  for interface in "${downed_interfaces[@]}"; do
    local i
    for i in {0..5}; do
      if test x"`ifconfig -s ${interface} | sed 1d | cut -d ' ' -f 1`" = x; then
        continue 2
      else
        sleep 2
      fi
      echo "Brought-down network interface '${interface}' still up after >10s, will continue and hope for the best" 1>&2
      ret=1
    done
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
  if ${sudo} /bin/bash -c "start network-interface INTERFACE=${downed_interfaces[0]}"; then
    netcmd="${sudo} start network-interface INTERFACE="
  elif ${sudo} /bin/bash -c "ifup ${downed_interfaces[0]}"; then
    netcmd="${sudo} ifup "
  else
    echo "Cannot bring up network interfaces" 1>&2
    return 1
  fi

  local ret=0
  local interface
  for interface in "${interfaces[@]:1}"; do
    bash -c "${netcmd}${interface}"
    if test $? -ne 0; then
      echo "Failed to bring up network interface '${interface}'" 1>&2
      ret=1
    fi
  done
  return ${ret}
} 

do_services=0
do_freq=0
bench_cpu=0
non_bench_cpu=''
cautiousness=1
do_network=0
while getopts sfb:p:cn flag; do
  case $flag in
    s)  do_services=1;;
    f)  do_freq=1;;
    b)  bench_cpu="${OPTARG}";;
    p)  non_bench_cpu="${OPTARG}";;
    c)  cautiousness=0;;
    n)  do_network=0;;
    *)
	echo 'Unknown option' 1>&2
	exit 1
    ;;
  esac
done
shift $((OPTIND - 1))

#Cheap sanity checks, before we start tearing the target down
echo "$bench_cpu" | grep '^[[:digit:]]\+$'
if test $? -ne 0; then
  echo "Benchmark CPU (-b) must be a decimal number" 1>&2
  exit 1
fi
echo "$non_bench_cpu" | grep '^[[:digit:]]\+$'
if test $? -ne 0; then
  echo "Non-benchmark CPU (-p) must be null or a decimal number" 1>&2
  exit 1
fi
if test ${bench_cpu} -eq ${non_bench_cpu}; then
  echo "Benchmark CPU (-b) and non-benchmark CPU (-p) must be different" 1>&2
  exit 1
fi

local cmd="$@"

taskset ${bench_cpu} -- true
if test $? -ne 0; then
  echo "Could not bind benchmark to CPU ${bench_cpu}" 1>&2
  exit 1
fi

trap cleanup EXIT

if test ${do_services} -eq 1; then
  stop_services
  if test $? -gt ${cautiousness}; then
    exit 1
  fi
fi
if test ${do_freq} -eq 1; then
  set_governor
  if test $? -gt ${cautiousness}; then
    exit 1
  fi
fi
if test x"${non_bench_cpu}" != x; then
  bind_processes ${non_bench_cpu}
  if test $? -gt ${cautiousness}; then
    exit 1
  fi
fi
if test ${do_network} -eq 1; then
  stop_network
  if test $? -gt ${cautiousness}; then
    exit 1
  fi
fi

taskset ${bench_cpu} -- ${cmd}
if test $? -eq 0; then
  echo "Run of ${cmd} complete"
  exit 0
else
  echo "taskset ${bench_cpu} -- ${cmd} failed" 1>&2
  exit 1
fi
