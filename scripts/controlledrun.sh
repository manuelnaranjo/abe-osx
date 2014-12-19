#!/bin/bash

#TODO: Test/finish crouton support

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
old_policy=

#The chroot part is often a nop, but will get us out of chroot if necessary
if test "${USER}" = root; then
  sudo="chroot /proc/1/root"
else
  sudo="sudo chroot /proc/1/root"
fi

cleanup()
{
  local ret=$?
  local tmp

  if test x"${rva_setting}" != x; then
    ${sudo} bash -c "echo ${rva_setting} > /proc/sys/kernel/randomize_va_space"
    if test $? -ne 0; then
      echo "Failed to restore ASLR setting" | tee -a /dev/stderr "${log}"
      ret=1
    fi
  fi

  start_services
  tmp=$?
  if test ${tmp} -gt ${ret}; then
    ret=${tmp}
  fi
  restore_policy
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
    echo "Problem restoring target system" | tee -a /dev/stderr "${log}" > /dev/null
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
      echo "Service '${service}' does not exist" | tee -a /dev/stderr "${log}" > /dev/null
      ret=1
      continue
    fi
    if echo "${service_status}" | grep ' stop/waiting$' > /dev/null; then
      echo "Service '${service}' already stopped" | tee -a /dev/stderr "${log}" > /dev/null
      continue
    fi
    if echo "${service_status}" | grep -v ' start/running$' > /dev/null; then
      echo "Service '${service}' does not appear to be running. Will try to stop it anyway. Are you specifying services in the right order?" | tee -a /dev/stderr "${log}" > /dev/null
    fi
    ${sudo} stop "${service}" > /dev/null
    if test $? -eq 0; then
      stopped_services+=("${service}")
    else
      echo "Service '${service}' could not be stopped" | tee -a /dev/stderr "${log}" > /dev/null
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
      echo "Failed to restart service '${stopped_service[$i]}'" | tee -a /dev/stderr "${log}" > /dev/null
      ret=1
    fi
  done
  return ${ret}
}

set_policy()
{
  old_policy=(`cpufreq-info -p`) #0 = min freq, 1 = max freq, 2 = governor
  if test $? -ne 0 || \
     test x"${old_policy[0]}" = x || \
     test x"${old_policy[1]}" = x || \
     test x"${old_policy[2]}" = x; then
    echo "Frequency scaling not supported" | tee -a /dev/stderr "${log}" > /dev/null
    return 1
  fi
  ${sudo} cpufreq-set -g userspace -d "${freq}" -u "${freq}"
  if test $? -ne 0; then
      old_policy=
      echo "Frequency scaling not supported" | tee -a /dev/stderr "${log}" > /dev/null
      return 1
  fi
}

restore_policy()
{
  #If freq scaling was unsupported then there is nothing to do
  if test x"${old_policy}" = x; then
    return 0
  fi
  ${sudo} cpufreq-set -g "${old_policy[2]}" -d "${old_policy[0]}" -u "${old_policy[1]}"
  if test $? -ne 0; then
    echo "Unable to restore policy '${old_policy}'" | tee -a /dev/stderr "${log}" > /dev/null
  fi
}

#Bind all existing processes to CPU $1.  We then run benchmarks on CPU #1.
#Note that some processes cannot be bound, for example per-cpu kernel threads.
bind_processes()
{
  ${sudo} taskset -a -p -c $1 1 > /dev/null
  if test $? -ne 0; then
    echo "CPU bind not supported" | tee -a /dev/stderr "${log}" > /dev/null
    return 1
  fi

  bound_processes=(1)
  local all_processes
  all_processes=`ps ax --format='%p' | tail -n +3`
  if test $? -ne 0; then
    echo "Unable to list processes" | tee -a /dev/stderr "${log}" > /dev/null
    return 1
  fi

  local p
  local ppid
  local ppcmd
  local output
  local ret=0
  for p in ${all_processes}; do
    ppid="`ps -p $p -o ppid=`"
    if test $? -ne 0; then
      continue #Probably some process completed since we made the list
    fi
    if test ${ppid} -ne 0; then
      ppcmd="`ps -p ${ppid} -o cmd=`" 
      if test $? -ne 0; then
        echo "Failed to get cmd for pid $ppid (parent of $pid)" 1>&2
      fi
      if [[ "${ppcmd}" = *kthreadd* ]]; then
        continue #don't try to change the affinity of kernel procs
      fi
    fi
    output="`${sudo} taskset -a -p -c $1 ${p} 2>&1`"
    if test $? -eq 0; then
      bound_processes+=("${p}")
    else
      local name="`grep Name: /proc/$p/status | cut -f 2`"
      echo "Failed to bind $name to CPU $1: $output" | tee -a /dev/stderr "${log}" > /dev/null
      ret=1
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
      echo "Failed to unbind $name: $output" | tee -a /dev/stderr "${log}" > /dev/null
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
      echo "Failed to stop network" | tee -a /dev/stderr "${log}" > /dev/null
      return 1
    fi
    downed_interfaces+=("crouton")
    return 0
  fi

  #Stop network on not-crouton

  #Get interfaces
  local -a interfaces
  #TODO: Remote corner case - this'll break on interface names with a space in
  interfaces=(`ifconfig | cut -f 1 -d ' ' | sed '/^$/d' | grep -v '^lo$'`)
  if test $? -ne 0; then
    echo "Failed to read network interfaces" | tee -a /dev/stderr "${log}" > /dev/null
    return 1
  fi

  #Work out how to stop interfaces by stopping one of them
  local netcmd
  if ${sudo} stop network-interface INTERFACE="${interfaces[0]}" >/dev/null 2>&1; then
    netcmd="${sudo} stop network-interface INTERFACE="
  elif ${sudo} ifdown "${interfaces[0]}"; then #don't redirect stderr as this is our last try and failure information would be helpful
    netcmd="${sudo} ifdown "
  else
    echo "Cannot bring down network interfaces" | tee -a /dev/stderr "${log}" > /dev/null
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
      echo "Failed to bring down network interface '${interface}'" | tee -a /dev/stderr "${log}" > /dev/null
      ret=1
    fi
  done

  #Ensure that interfaces are have finished going down
  #TODO: A little manpage scanning suggests that this isn't needed at least the upstart case
  for i in {0..4}; do
    if test x"`ifconfig | cut -f 1 -d ' ' | sed '/^$/d' | grep -v '^lo$'`" = x; then
      break
    fi
    sleep 2
    echo "Brought-down network interface(s) "`ifconfig | cut -f 1 -d ' ' | sed '/^$/d' | grep -v '^lo$'`" still up after >10s" | tee -a /dev/stderr "${log}" > /dev/null
    echo "Will continue and hope for the best unless we're being cautious (-c)" | tee -a /dev/stderr "${log}" > /dev/null
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
      echo "Failed to restart network" | tee -a /dev/stderr "${log}" > /dev/null
      return 1
    fi
    return 0
  fi

  local netcmd
  local i
  if ${sudo} /bin/bash -c "start network-interface INTERFACE=${downed_interfaces[0]}" >/dev/null 2>&1; then
    netcmd="${sudo} start network-interface INTERFACE="
  elif ${sudo} /bin/bash -c "ifup ${downed_interfaces[0]}"; then #don't redirect stderr as this is our last try and failure information would be helpful
    netcmd="${sudo} ifup "
  else
    echo "Cannot bring up network interfaces" | tee -a /dev/stderr "${log}" > /dev/null
    return 1
  fi
  for i in {1..60}; do
    echo "Ping ${downed_interfaces[0]}: $i" | tee -a /dev/stderr "${log}" > /dev/null
    ping -c 1 "`ip -f inet -o addr show ${downed_interfaces[0]} | awk '{print $4}' | sed 's#/.*##'`" > /dev/null
    if test $? -eq 0; then
      break
    fi
    sleep 1
    false
  done
  if test $? -ne 0; then
    echo "Restored interface ${downed_interfaces[0]} not answering pings after ${i} seconds" | tee -a /dev/stderr "${log}" > /dev/null
    echo "Ping rune: ping -c 1 \"`ip -f inet -o addr show ${downed_interfaces[0]} | awk '{print $4}' | sed 's#/.*##'`\" > /dev/null" | tee -a /dev/stderr "${log}" > /dev/null
  fi
  downed_interfaces=("${downed_interfaces[@]:1}")

  local ret=0
  local interface
  for interface in "${downed_interfaces[@]}"; do
    bash -c "${netcmd}${interface}"
    if test $? -ne 0; then
      echo "Failed to bring up network interface '${interface}'" | tee -a /dev/stderr "${log}" > /dev/null
      ret=1
    fi
    for i in {1..60}; do
      ping -c 1 "`ip -f inet -o addr show ${interface} | awk '{print $4}' | sed 's#/.*##'`" > /dev/null
      if test $? -eq 0; then
	break
      fi
      sleep 1
      false
    done
    if test $? -ne 0; then
      echo "Restored interface ${interface} not answering pings after ${i} seconds" | tee -a /dev/stderr "${log}" > /dev/null
      echo "Ping rune: ping -c 1 \"`ip -f inet -o addr show ${downed_interfaces[0]} | awk '{print $4}' | sed 's#/.*##'`\" > /dev/null" | tee -a /dev/stderr "${log}" > /dev/null
    fi
  done
  return ${ret}
} 

services_file=''
log=/dev/null
freq=''
bench_cpu=0
non_bench_cpu=''
cautiousness=0
do_network=0
do_aslr=1 #Enabled by default
do_renice=1 #Enabled by default
while getopts s:f:b:p:cnul: flag; do
  case $flag in
    s)  services_file="${OPTARG}";;
    f)  freq="${OPTARG}";;
    b)  bench_cpu="${OPTARG}";;
    p)  non_bench_cpu="${OPTARG}";;
    c)  cautiousness=1;;
    n)  do_network=1;;
    l)  log="${OPTARG}";;
    u)  #Set everything to 'uncontrolled', even the controls that default on
        sudo=''
        services_file=''
        freq=''
        bench_cpu=''
        non_bench_cpu=''
        do_network=0
        do_aslr=0
        do_renice=0
        echo "Uncontrolled (-u) set, no controls enabled" 1>&2
        echo "Individual control flags set after -u will still be respected" 1>&2
    ;;
    *)
        echo 'Unknown option' | tee -a /dev/stderr "${log}" > /dev/null
        exit 1
    ;;
  esac
done

echo "$@" | tee -a "${log}"
echo | tee -a "${log}"

shift $((OPTIND - 1))

#Cheap sanity checks, before we start tearing the target down
if test x"${services_file}" != x; then
  if test \! -f "${services_file}"; then
    echo "Services file '${services_file}' missing" | tee -a /dev/stderr "${log}" > /dev/null
    exit 1
  fi
  if test x"`cat ${services_file}`" = x; then
    echo "Services file '${services_file}' is empty" | tee -a /dev/stderr "${log}" > /dev/null
    exit 1
  fi
fi

echo "$bench_cpu" | grep '^[[:digit:]]*$' > /dev/null
if test $? -ne 0; then
  echo "Benchmark CPU (-b) must be null or a decimal number" | tee -a /dev/stderr "${log}" > /dev/null
  exit 1
fi
echo "$non_bench_cpu" | grep '^[[:digit:]]*$' > /dev/null
if test $? -ne 0; then
  echo "Non-benchmark CPU (-p) must be null or a decimal number" | tee -a /dev/stderr "${log}" > /dev/null
  exit 1
fi
if test x"${bench_cpu}" != x && test x"${non_bench_cpu}" != x && test x"${bench_cpu}" = x"${non_bench_cpu}"; then
  echo "If set, benchmark CPU (-b) and non-benchmark CPU (-p) must be different" | tee -a /dev/stderr "${log}" > /dev/null
  exit 1
fi

cmd="$@"

if test x"${bench_cpu}" != x; then
  taskset -c ${bench_cpu} true
  if test $? -ne 0; then
    echo "Could not bind benchmark to CPU ${bench_cpu}" | tee -a /dev/stderr "${log}" > /dev/null
    exit 1
  fi
fi

#Put the target back in order before we quit
trap cleanup EXIT
trap 'exit 1' TERM INT HUP QUIT

if test x"${services_file}" != x; then
  stop_services "${services_file}"
  if test $? -ne 0 -a ${cautiousness} -eq 1; then
    exit 1
  fi
fi
if test x"${freq}" != x; then
  set_policy "${freq}"
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
echo | tee -a "${log}"
echo "** Target Status **" | tee -a "${log}"
echo "===================" | tee -a "${log}"
echo "General Information:" | tee -a "${log}"
uname -a | tee -a "${log}"
if test -f /etc/lsb-release; then
  cat /etc/lsb-release | tee -a "${log}"
fi
echo | tee -a "${log}"
#A little research shows that it is unclear how
#reliable or complete the information from either
#initctl or service is. So we make a best effort.
echo "** (Possibly) Running Services:" | tee -a "${log}"
echo "According to initctl:" | tee -a "${log}"
${sudo} initctl list | grep running | tee -a "${log}"
if test $? -ne 0; then
  echo "*** initctl unable to list running services" | tee -a "${log}"
fi
echo "According to service:" | tee -a "${log}"
${sudo} service --status-all 2>&1 | grep -v '^...-' | tee -a "${log}"
if test $? -ne 0; then
  echo "*** service unable to list (possibly) running services" | tee -a "${log}"
fi
echo | tee -a "${log}"
echo "** CPUFreq:" | tee -a "${log}"
${sudo} cpufreq-info -p | tee -a "${log}"
if test $? -ne 0; then
  echo "*** Unable to get CPUFreq info" | tee -a "${log}"
fi
echo | tee -a "${log}"
echo "** Affinity Masks:" | tee -a "${log}"
all_processes=`ps ax --format='%p' | tail -n +2`
if test $? -eq 0; then
  for p in ${all_processes}; do
    ${sudo} taskset -a -p ${p} | tee -a "${log}"
    if test $? -ne 0; then
      echo "*** Unable to get affinity mask for process ${p}" | tee -a "${log}"
    fi
  done
else
  echo "*** Unable to get affinity mask info" | tee -a "${log}"
fi
echo | tee -a "${log}"
echo "** Live Network Interfaces:" | tee -a "${log}"
${sudo} ifconfig | tee -a "${log}"
if test $? -ne 0; then
  echo "*** Unable to get network info" | tee -a "${log}"
fi
echo "===================" | tee -a "${log}"
echo | tee -a "${log}"

#"setarch `uname -m` -R" would be a tidier way to run our benchmark without ASLR,
#but doesn't work on our machines (setarch rejects the value of uname -m, and some
#obvious alternatives, as invalid).
if test ${do_aslr} -eq 1; then
  rva_setting="`cat /proc/sys/kernel/randomize_va_space`"
  ${sudo} bash -c 'echo 0 > /proc/sys/kernel/randomize_va_space'
  if test $? -ne 0; then
    echo "Error when disabling ASLR" | tee -a /dev/stderr "${log}"
    if test "${cautiousness}" -eq 1; then
      exit 1
    fi
  fi
fi

#By setting our own niceness, we don't force the benchmark to run as root
if test ${do_renice} -eq 1; then
  sudo renice -19 $$ #Don't use $sudo, we don't want to break out of chroot here
  if test $? -ne 0; then
    echo "Failed to set niceness to -19" 1>&2
  fi
fi

#Finally, run the command!
#We don't tee it, just in case it contains any sensitive output
#TODO We expect to be running with stdout & stderr redirected, insert a test for this
if test x"${bench_cpu}" != x; then
  cmd="taskset -c ${bench_cpu} ${cmd}"
fi
echo "Running ${cmd}"
${cmd}
if test $? -eq 0; then
  echo "Run of ${cmd} complete" | tee -a "${log}"
  exit 0
else
  echo "Run of ${cmd} failed" | tee -a /dev/stderr "${log}" > /dev/null
  exit 1
fi
