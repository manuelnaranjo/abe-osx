#Requires passwordless sudo, or root
stop_services()
{
  if test "${USER}" = root; then
      sudo="chroot /proc/1/root" #A nop for many cases, but makes sure we can get out of chroot jail where necessary, if we are in one
  else
      sudo="sudo chroot /proc/1/root"
  fi
  stopped_services="`mktemp`"
  if test $? -gt 0; then
      error "Failed to create temporary file"
      return 1
  fi

  #TODO This may get a bit complicated - services have dependencies that are not necessarily easy to determine and therefore cannot be stopped in an
  #     arbitrary order. I think the only robust way to do this is to have knowledge of the target system, either in config files or via a dispatcher
  #     (e.g. Jenkins/LAVA). Which tty service to keep also presumably depends on the target system.
  if $sudo initctl list >/dev/null \
      || croutonversion >/dev/null 2>&1; then
      # Stop all but few services.  Note all stopped services in stopped_services
      # file to restart them after benchmarks.  Network and SSH server are
      # handled separately.

      sudo_old=$sudo
      #TODO Do we still need crouton support?
      if croutonversion >/dev/null 2>&1; then
	  # For Crouton chroot back into Chrome OS to stop services.
	  keep="dbus\|boot-services\|shill\|wpasupplicant"
	  keep="$keep\|tty2"
      else
	  keep="dbus\|network"
          #keep="$keep\lightdm\|binfmt-support"  #For Ubuntu chroot
          keep="$keep\|auto-serial-console" #For Linaro dist target
	  keep="$keep\|tty1"
          keep="$keep\|rcS" #For (just lava?) highbank
      fi

      for s in $($sudo initctl list | grep running | cut -f 1 -d " "); do
	  echo $s | grep "$keep" > /dev/null
          if test $? -eq 0; then
              notice "Keeping service $s"
              continue
          fi
          output="`$sudo stop $s 2>&1`"
          if test $? -eq 0; then
	      echo $s >> $stopped_services
          else
              warning "Failed to stop service $s: $output"
          fi
      done

      sudo=$sudo_old
  else
      error "Unable to access services"
      rm -f $stopped_services
      return 1
  fi

  echo $stopped_services
}

start_services()
{
  stopped_services="$1"
  if test "${USER}" = root; then
      sudo="chroot /proc/1/root"
  else
      sudo="sudo chroot /proc/1/root"
  fi

  if $sudo initctl list >/dev/null || ssh $target croutonversion >/dev/null 2>&1; then
      for s in $(cat $stopped_services); do
	  output="`$sudo start $s 2>&1`"
          if test $? -gt 0; then
              warning "Failed to restart $s: $output"
          fi
      done
  else
      error "Unable to access services"
      return 1
  fi
  rm -f $stopped_services
  return 0
}

# TODO Maybe break this down into more smaller parts (set_freq, bind_process, stop/start network)
controlled_run()
{
  cmd="$@"
  if test "${USER}" = root; then
      sudo="chroot /proc/1/root"
  else
      sudo="sudo chroot /proc/1/root"
  fi
  if croutonversion >/dev/null 2>&1; then
      sudo="$sudo chroot /proc/1/root"
  fi
  stopped_services="`stop_services`"
  if test $? -gt 0; then
      return 1
  fi
  # TODO: also fix to a low frequency, so we don't melt?
  # Disable frequency scaling
  #old_governor=$(cpufreq-info -p | cut -f 3 -d " ")
  #if test "x$old_governor" = "x" \
  #    || ! $sudo cpufreq-set -g performance; then
  #    old_governor=""
  #    warning "Frequency scaling not supported"
  #fi

  # Bind all existing processes to CPU #0.  We then run benchmarks on CPU #1.
  # Note that some processes cannot be bound (e.g. ksoftirqd, which is a per-cpu kernel thread)
  # TODO: The correct CPUs to use are target dependent - this needs to be derived from a config file,
  #       or by the dispatcher
  # TODO: Strictly, we should remember the binding we found and restore it later
  if $sudo taskset -a -p 0x1 1 > /dev/null; then
      for p in $(ps ax --format='%p' | tail -n +2); do
          output="`$sudo taskset -a -p 0x1 $p 2>&1`"
          if test $? -gt 0; then
              name="`grep Name: /proc/$p/status | cut -f 2`"
              notice "Failed to bind $name to CPU 0: $output"
          fi
      done
  else
      warning "CPU bind not supported"
  fi

  # Figure out how to stop/start network.
  #TODO: Do we still need to support crouton?
  #TODO: Strictly, should either figure out the interfaces on the fly, or get them from some known good target info
  if croutonversion >/dev/null 2>&1; then
      network_before="$sudo /bin/bash -c 'stop shill && stop wpasupplicant' && sleep 2"
      network_after="$sudo /bin/bash -c 'start wpasupplicant && start shill' && $sudo /sbin/iptables -P INPUT ACCEPT"
  elif $sudo stop network-interface INTERFACE=lo && $sudo start network-interface INTERFACE=lo; then
      network_before="$sudo stop network-interface INTERFACE=eth0 && sleep 2"
      network_after="$sudo start network-interface INTERFACE=eth0"
  elif $sudo ifdown lo && $sudo ifup lo; then
      network_before="$sudo ifdown eth0 && sleep 2"
      network_after="$sudo ifup eth0"
  else
      network_before="warning Network control not supported"
      network_after="warning Network control not supported"
  fi
  #For some reason, this needs the explicit 'bash -c' to work - I guess INTERFACE=eth0 gets interpreted wrong otherwise
  output="`bash -c \"$network_before\" 2>&1`"
  if test $? -gt 0; then
    warning "Failed to stop network with '$network_before': $output"
  fi

  #At last, run the controlled command. Defer error handling until we've restored the system.
  taskset 0x2 bash -c "$cmd"
  result=$?

  #Now bring everything back
  output="`bash -c \"$network_after\" 2>&1`"
  if test $? -gt 0; then
    warning "Failed to start network with '$network_after': $output"
  fi
  start_services $stopped_services

  if $sudo taskset -a -p 0xFFFFFFFF 1 > /dev/null; then
      for p in $(ps ax --format='%p' | tail -n +2); do
          output="`$sudo taskset -a -p 0xFFFFFFFF $p 2>&1`"
          if test $? -gt 0; then
              notice "Failed to unbind process $p (may not have bound it in the first place): $output"
          fi
      done
  fi

  #if [ "x$old_governor" != "x" ]; then
  #    $sudo cpufreq-set -g $old_governor
  #    if test $? -gt 0; then
  #        warning "Failed to restore freq"
  #    fi
  #fi

  if test $result -gt 0; then
      error "$cmd failed"
      return 1
  fi
  return 0
}
