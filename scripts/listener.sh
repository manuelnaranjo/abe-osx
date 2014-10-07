function get_addr
{
  local listener_addr
  listener_addr=`hostname -I`
  if test x"`echo ${listener_addr} | wc -l`" != x1; then
   echo "Warning: Multiple IPs found for current host, will use first one" 1>&2
  fi 
  listener_addr="`hostname -I | head -n1 | sed 's/^[[:blank:]]*//' | sed 's/[[:blank:]]*$//'`"
  if ! echo "${listener_addr}" | grep '^\([[:digit:]]\+\.\)\{3\}[[:digit:]]\+$' > /dev/null; then
    echo "${listener_addr} does not look like an IP address" 1>&2
    return 1
  fi
  echo "${listener_addr}"
  return 0
}

function establish_listener
{
  local listener_addr
  local listener_file
  local start_port
  local end_port
  local listener_pid

  if test ${#@} -ne 4; then
    echo "establish_listener needs 4 args" 1>&2
    return 1
  fi

  listener_addr="$1"
  if ! echo "${listener_addr}" | grep '^\([[:digit:]]\+\.\)\{3\}[[:digit:]]\+$' > /dev/null; then
    echo "${listener_addr} does not look like an IP address" 1>&2
    return 1
  fi
  listener_file="$2"
  start_port="$3"
  end_port="$4"

  local listener_port
  for ((listener_port=${start_port}; listener_port < ${end_port}; listener_port++)); do
    #Try to listen on the port. nc will fail if something has snatched it.
    echo "Attempting to establish listener on ${listener_addr}:${listener_port}" 1>&2
    nc -kl "${listener_addr}" "${listener_port}" > "${listener_file}"&
    listener_pid=$!

    #nc doesn't confirm that it's got the port, so we spin until either:
    #1) We see that the port has been taken by our process
    #2) We see our process exit (implying that the port was taken)
    #3) We've waited long enough
    #(listener_pid can't be reused until we wait on it)
    for j in {1..5}; do
      if test x"`lsof -i tcp@${listener_addr}:${listener_port} | sed 1d | awk '{print $2}'`" = x"${listener_pid}"; then
        break 2; #success, exit outer loop
      elif ! ps -p "${listener_pid}" > /dev/null; then
        #listener has exited, reap it and go back to start of outer loop
        wait "${listener_pid}"
        listener_pid=
        continue 2
      else
        sleep 1
      fi
    done

    #We gave up waiting, kill and reap the nc process
    kill "${listener_pid}"
    wait "${listener_pid}"
    listener_pid=
  done

  if test x"${listener_pid}" = x; then
    echo "Failed to find a free port in range ${start_port}-${end_port}" 1>&2
    return 1
  fi
  echo "${listener_port}"
  return 0
}
