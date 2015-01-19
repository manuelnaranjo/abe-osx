#!/bin/bash
set -o pipefail
set -o nounset

# load the configure file produced by configure
if test -e "${PWD}/host.conf"; then
    . "${PWD}/host.conf"
else
    echo "ERROR: no host.conf file!  Did you run configure?" 1>&2
    exit 1
fi
topdir="${abe_path}" #abe global, but this should be the right value for abe
. "${topdir}"/scripts/benchutil.sh
if test $? -ne 0; then
  echo "Unable to source ${topdir}/benchutil.sh" 1>&2
  exit 1
fi

trap cleanup EXIT
trap 'exit ${error}' TERM INT HUP QUIT

error=1
listener_pid=
forward_pid=
pseudofifo_pid=
temps="`mktemp -dt XXXXXXXXX`" || exit 1
listener_file="${temps}/listener_file"
gateway=

function cleanup
{
  error=$?
  if test x"${listener_pid:-}" != x; then
    kill "${listener_pid}" 2>/dev/null
    wait "${listener_pid}"
  fi
  if test x"${pseudofifo_pid:-}" != x; then
    kill "${pseudofifo_pid}" 2>/dev/null
    #Substituted process is not our child and cannot be waited on. Fortunately,
    #it doesn't matter too much when it dies.
  fi
  if test x"${forward_pid:-}" != x; then
    kill "${forward_pid}" 2>/dev/null
    wait "${forward_pid}"
  fi
  if test -d "${temps}"; then
    exec 3>&-
    rm -rf ${temps}
    if test $? -ne 0; then
      echo "Failed to delete temporary file store ${temps}" 1>&2
    fi
    error=1
  fi
  exit "${error}"
}

#A fifo would make much more sense, but nc doesn't like it
touch "${listener_file}"
if test $? -ne 0; then
  echo "Failed to create listener file '${listener_file}'" 1>&2
  exit 1
fi

#The trap is just to suppress the 'Terminated' message
exec 3>&-
exec 3< <(trap 'exit' TERM; tail -f "${listener_file}"& echo $! >> "${listener_file}"; wait)
read -t 60 pseudofifo_pid <&3
if test $? -ne 0; then
  echo "Failed to read pseudofifo pid" 1>&2
  exit 1
fi

forward_fifo="${temps}/forward_fifo"
mkfifo "${forward_fifo}" || exit 1

while getopts f: flag; do
  case "${flag}" in
    f) gateway="${OPTARG}" ;;
    *)
       echo "Bad arg" 1>&2
       exit 1
    ;;
  esac
done
shift $((OPTIND - 1))
if test $# -ne 3; then
  echo "establish_listener needs 3 args, got $#" 1>&2
  for arg in "$@"; do echo "${arg}" 1>&2; done
  exit 1
fi
if test x"${gateway:-}" != x; then
  if ! echo "${gateway}" | grep -q '.\+:.\+'; then
    echo "If specifying a gateway to forward through, must be in format 'internal_interface:external_interface'" 1>&2
    echo "Got: ${gateway}" 1>&2
    exit 1
  fi
fi

listener_addr="$1"
ping -c 1 "${listener_addr}" > /dev/null
if test $? -ne 0; then
  echo "Unable to ping host ${listener_addr}" 1>&2
  exit 1
fi
start_port="$2"
end_port="$3"

for ((listener_port=${start_port}; listener_port < ${end_port}; listener_port++)); do
  #Try to listen on the port. nc will fail if something has snatched it.
  echo "Attempting to establish listener on ${listener_addr}:${listener_port}" 1>&2
  nc -kl "${listener_addr}" "${listener_port}" >> "${listener_file}"&
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

if test x"${listener_pid:-}" = x; then
  echo "Failed to find a free port in range ${start_port}-${end_port}" 1>&2
  exit 1
fi

if test x"${gateway:-}" != x; then
  internal_interface="${gateway/%:*}"
  external_interface="${gateway/#*:}"
  ssh -o PasswordAuthentication=no -o PubkeyAuthentication=yes -NR ${internal_interface/%:*}:0:${listener_addr}:${listener_port} ${external_interface} >"${forward_fifo}" 2>&1 &
  forward_pid=$!
  read -t 30 line < "${forward_fifo}"
  if test $? -ne 0; then
    echo "Timeout while establishing port forward" 1>&2
    exit 1
  fi
  if echo ${line} | grep -q "^Allocated port [[:digit:]]\\+ for remote forward to ${listener_addr}:${listener_port}"; then
    listener_port="`echo ${line} | cut -d ' ' -f 3`"
  else
    echo "Unable to get port forwarded for listener" 1>&2
    echo "Tried: ssh -o PasswordAuthentication=no -o PubkeyAuthentication=yes -NR ${internal_interface/%:*}:0:${listener_addr}:${listener_port} ${external_interface}" 1>&2
    echo "Got: $line" 1>&2
    exit 1
  fi
  listener_addr="`get_addr ${external_interface}`" || exit 1
fi

echo "${listener_addr}"
echo "${listener_port}"

while true; do
  line="`bgread ${pseudofifo_pid} 60 <&3`"
  if test $? -ne 0; then
    echo "Failed to read pseudofifo pid" 1>&2
    exit 1
  fi
  echo $line
done
