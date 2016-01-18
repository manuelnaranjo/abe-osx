#!/bin/bash
#This script takes a build of a benchmark and transfers it to, and runs it on
#a single target.
set -o pipefail
set -o nounset

error=1

trap clean_benchmark EXIT
trap 'exit ${error}' TERM INT HUP QUIT #Signal death can be part of normal control flow (see 'kill' invocations in benchmark.sh)

#Precondition: the target is in known_hosts
ssh_opts="-F /dev/null -o StrictHostKeyChecking=yes -o CheckHostIP=yes"
host_ip="`hostname -I | cut -f 1 -d ' '`" #hostname -I includes a trailing space

benchmark=
device=
keep=
cautious=''
build_dir=
run_benchargs=
post_run_cmd=
post_target_cmd=
buildtar=
buildtartopdir=
triple=
while getopts a:b:cd:e:f:kpr:t: flag; do
  case "${flag}" in
    a) run_benchargs="${OPTARG}";;
    b) benchmark="${OPTARG}";;
    c) cautious='-c';;
    d) device="${OPTARG}";;
    e) post_target_cmd="${OPTARG}";;
    f) triple="${OPTARG}";;
    k) keep='-k';;
    p) keep='-p';;
    r) post_run_cmd="${OPTARG}";;
    t) buildtar="${OPTARG}";;
    *)
       echo "Bad arg" 1>&2
       error=1
       exit
    ;;
  esac
done
shift $((OPTIND - 1))
if test $# -ne 0; then
  echo "Surplus arguments: $@" 1>&2
  error=1
  exit
fi
if test x"${buildtar}" = x; then
  echo "No tarball given" 1>&2
  error=1
  exit
fi
buildtartopdir="`tar tf ${buildtar} | head -n1`"

# load the configure file produced by configure
if test -e "${PWD}/host.conf"; then
    . "${PWD}/host.conf"
else
    echo "ERROR: no host.conf file!  Did you run configure?" 1>&2
    error=1
    exit
fi
topdir="${abe_path}" #abe global, but this should be the right value for abe
confdir="${topdir}/config/bench/boards"
benchlog="`. ${abe_top}/host.conf && . ${topdir}/lib/common.sh && if test x"${triple}" != x; then target=${triple}; fi && read_config ${benchmark}.git benchlog`"
if test $? -ne 0; then
  echo "Unable to read benchmark config file for ${benchmark}" 1>&2
  error=1
  exit
fi
safe_output="`. ${abe_top}/host.conf && . ${topdir}/lib/common.sh && if test x"${triple}" != x; then target=${triple}; fi && read_config ${benchmark}.git safe_output`"
if test $? -ne 0; then
  echo "Unable to read benchmark config file for ${benchmark}" 1>&2
  error=1
  exit
fi

. "${confdir}/${device}.conf" #We can't use abe's source_config here as it requires us to have something get_toolname can parse
if test $? -ne 0; then
  echo "+++ Failed to source ${confdir}/${device}.conf" 1>&2
  error=1
  exit
fi

#Make sure that subscripts clean up - we must not leave benchmark sources or data lying around,
clean_benchmark()
{
  if test x"${ip:-}" != x; then
    if test x"${target_dir:-}" = x; then
      echo "No directory to remove from ${ip}"
    elif test x"${keep}" = 'x-k'; then
      echo "Not removing ${target_dir} from ${ip} as -k was given. You might want to go in and clean up."
    elif test x"${keep}" != 'x-p' -a ${error} -ne 0; then
      echo "Not removing ${target_dir} from ${ip} as there was an error. You might want to go in and clean up."
    elif ! expr "${target_dir}" : '\(/tmp\)' > /dev/null; then
      echo "Cowardly refusing to delete ${target_dir} from ${ip}. Not rooted at /tmp. You might want to go in and clean up." 1>&2
      error=1
    else
      (. "${topdir}"/lib/common.sh; remote_exec "${ip}" "rm -rf ${target_dir}" ${ssh_opts})
      if test $? -eq 0; then
        echo "Removed ${target_dir} from ${ip}"
        echo "Sending post-target command '${post_target_cmd}' - will not check error code"
        if test x"${post_target_cmd}" != x; then
          (. ${topdir}/lib/common.sh; remote_exec "${ip}" "${post_target_cmd}" ${ssh_opts})
        fi
        #We don't check the error code because this might well include a shutdown
      else
        echo "Failed to remove ${target_dir} from ${ip}. You might want to go in and clean up." 1>&2
        error=1
      fi
    fi
  else
    echo "Target post-boot initialisation did not happen, thus nothing to clean up."
  fi

  exit ${error}
}

if ! (. "${topdir}"/lib/common.sh; remote_exec "${ip}" true ${ssh_opts}) > /dev/null 2>&1; then
  echo "Unable to connect to target ${ip:-(unknown)}" 1>&2
  error=1
  exit
fi

#Should be a sufficient UID, as we wouldn't want to run multiple benchmarks on the same target at the same time
logdir="${abe_top}/${benchmark}-log/${device}_${ip}_`date -u +%F_%T.%N`"
if test -e "${logdir}"; then
  echo "Log output directory ${logdir} already exists" 1>&2
fi
mkdir -p "${logdir}/${buildtartopdir}"
if test $? -ne 0; then
  echo "Failed to create dir ${logdir}" 1>&2
  error=1
  exit
fi

#Create and populate working dir on target
target_dir="`. ${topdir}/lib/common.sh; remote_exec ${ip} 'mktemp -dt XXXXXXX' ${ssh_opts}`"
if test $? -ne 0; then
  echo "Unable to get tmpdir on target" 1>&2
  error=1
  exit
fi
for thing in "${buildtar}" "${topdir}/scripts/controlledrun.sh"; do
  (. "${topdir}"/lib/common.sh; remote_upload -r 3 "${ip}" "${thing}" "${target_dir}/`basename ${thing}`" ${ssh_opts})
  if test $? -ne 0; then
    echo "Unable to copy ${thing}" to "${ip}:${target_dir}/${thing}" 1>&2
    error=1
    exit
  fi
done

#Compose and run the ssh command.
#We have to run the ssh command asynchronously, because having the network down during a long-running benchmark will result in ssh
#death sooner or later - we can stop ssh client and ssh server from killing the connection, but the TCP layer will get it eventually.

#These parameters sourced from the board conf file at beginning of this function
flags="${benchcore:+-b ${benchcore}} ${othercore:+-p ${othercore}}"
if test x"${netctl:-}" = xyes; then
  flags+=" -n"
fi
if test x"${servicectl:-}" = xyes; then
  flags+=" -s ${target_dir}/${device}.services"
  (. "${topdir}"/lib/common.sh; remote_upload -r 3 "${ip}" "${confdir}/${device}.services" "${target_dir}" ${ssh_opts})
  if test $? -ne 0; then
    echo "Unable to copy ${confdir}/${device}.services" to "${ip}:${target_dir}/${device}.services" 1>&2
    error=1
    exit
  fi
fi
if test x"${freqctl:-}" = xyes; then
  flags+=" -f"
fi
if test x"${log_output:-}" != x; then
  flags+=" -l ${log_output}"
fi

#This parameter read from the benchmark conf file earlier in this script
if test x"${safe_output}" = xyes; then
  flags+=" -t"
fi

#But, if uncontrolled is set, override all other flags
if test x"${uncontrolled:-}" = xyes; then
  echo "Running without any target controls or special (sudo) privileges, due to 'uncontrolled=yes' in target config file"
  flags="-u"
fi

#Note that return code from post_run_cmd does not get evaluated, because this
#is an asynchronous ssh invocation, and we cache the return code of the
#benchmark run only.
#exec trick in phonehome stops us getting 'silly rename' when using nfsroot
#see http://nfs.sourceforge.net/#faq_d2
(
   . "${topdir}"/lib/common.sh
   remote_exec_async \
     "${ip}" \
     "function phonehome \
      { \
        exec >/dev/null 2>&1; \
        while test -e ${target_dir}; do \
          ping -c 1 ${host_ip}; \
          sleep 11; \
        done; \
      }; \
      trap phonehome EXIT; \
      cd ${target_dir} && \
      tar xf `basename ${buildtar}` --exclude='*.git/.git/*' && \
      cd ${buildtartopdir} && \
      rm ../`basename ${buildtar}` && \
      ../controlledrun.sh ${cautious} ${flags} -- ./linarobench.sh ${board_benchargs:-} -- ${run_benchargs:-}; \
      echo \\\$? > ${target_dir}/RETCODE && \
      ${post_run_cmd:-true}; \
      echo \\\$? > ${target_dir}/POST_RUN_RETCODE" \
     "${target_dir}/stdout" "${target_dir}/stderr" \
     ${ssh_opts}
   if test $? -ne 0; then
     echo "Something went wrong when we tried to dispatch job" 1>&2
     exit 1
   fi
)

#Wait for a ping from the target
#This assumes that the target's identifier does not change
#This should hold for name in a DNS network, but not necessarily for IP
#Today LAVA lab does not provide DNS, but IP seems stable in practice
#Rather than work around lack of DNS, just make sure we notice if the IP changes
#'sleep 1' just here because the while loop has to do _something_
trgt_resolved_ip="`dig +short hosts ${ip#*@}      | head -n 1`"
if test $? -ne 0; then
  echo "Failed to resolve target IP" >&2
  exit 1
fi
host_resolved_ip="`dig +short hosts ${host_ip#*@} | head -n 1`"
if test $? -ne 0; then
  echo "Failed to resolve host IP" >&2
  exit 1
fi
while ! tcpdump -n -c 1 -i eth0 'icmp and icmp[icmptype]=icmp-echo' | grep -q "${trgt_resolved_ip} > ${host_resolved_ip}"; do sleep 1; done
error="`(. ${topdir}/lib/common.sh; remote_exec "${ip}" "cat ${target_dir}/RETCODE" ${ssh_opts})`"
if test $? -ne 0; then
  echo "Unable to determine benchmark exit code, assuming the worst." 1>&2
  error=1
fi

if test x"${error}" = x || test ${error} -ne 0; then
  echo "Benchmark command failed" 1>&2
  echo "Target: ${ip}:${target_dir}" 1>&2
  error=1
fi

post_run_error="`(. ${topdir}/lib/common.sh; remote_exec "${ip}" "cat ${target_dir}/POST_RUN_RETCODE" ${ssh_opts})`"
if test $? -ne 0; then
  echo "Unable to determine post-run exit code, assuming the worst." 1>&2
  post_run_error=1
fi

if test x"${post_run_error}" = x || test ${post_run_error} -ne 0; then
  echo "Post-run command failed" 1>&2
  echo "Target: ${ip}:${target_dir}" 1>&2
  error=1
fi

echo "Retrieving logs"
for log in ../RETCODE ../stdout ../stderr linarobenchlog ${benchlog}; do
  log="`echo ${log} | sed 's#/*$##'`"
  mkdir -p "${logdir}/${buildtartopdir}/`dirname ${log}`"
  (. "${topdir}"/lib/common.sh; remote_download -r 3 "${ip}" "${target_dir}/${buildtartopdir}/${log}" "${logdir}/${buildtartopdir}/${log}" ${ssh_opts})
  if test $? -ne 0; then
    echo "Error while getting log ${log}: will try to get others" 1>&2
    error=1
  fi
done

if test ${error} -eq 0; then
  echo "+++ Run of ${benchmark} on ${device} succeeded"
else
  echo "+++ Run of ${benchmark} on ${device} failed"
fi
exit
