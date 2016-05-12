#!/bin/bash
# 
#   Copyright (C) 2014, 2015, 2016 Linaro, Inc
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
# 

bench_run ()
{
  local builddir="`get_builddir $1`"

  local tool="`get_toolname $1`"
  local runlog="${builddir}/run-${tool}.log"
  local cmd="`grep ^benchcmd= ${topdir}/config/${tool}.conf | cut -d '\"' -f 2`"
  local count="`grep ^benchcount= ${topdir}/config/${tool}.conf | cut -d '\"' -f 2`"

  if test x"${cmd}" = x; then
    error "No benchcmd for ${tool}"
    return 1
  fi
  if test x"${count}" = x; then
    warning "No benchcount for ${tool}, defaulting to 5"
    count=5
  fi

  dryrun "rm -f ${runlog}"
  if test $? -gt 0; then
    error "Failed to delete old runlog ${runlog}"
    return 1
  fi

  for i in `seq 1 "${count}"`; do
    dryrun "eval \"${cmd}\" 2>&1 | tee -a ${runlog}"
    if test $? -gt 0; then
      error "${cmd} failed"
      return 1
    fi
    dryrun "echo -e \"\nRun $i::\" | tee -a ${runlog}"
    bench_log "${tool}" "${runlog}" "${builddir}"
    if test $? -gt 0; then
      error "Logging failed for ${tool}"
      return 1
    fi
    dryrun "echo -e \"\n\" | tee -a ${runlog}"
  done

  return 0
}

bench_log ()
{
  local tool="$1"
  local out_log="$2"
  local builddir="$3"

  local in_log="`grep ^benchlog= ${topdir}/config/${tool}.conf | cut -d '\"' -f 2`"
  if test x"${in_log}" = x; then
    error "No benchlog in ${1}.conf"
    return 1
  fi

  for log in ${in_log}; do
    dryrun "cat ${builddir}/${log} | tee -a ${out_log}"
    if test $? -gt 0; then
      error "Could not tee log ${log} to ${out_log}"
      return 1
    fi
  done

  return 0
}

dump_host_info ()
{
  echo "GCCVERSION=`${CROSS_COMPILE}gcc --version | head -n1`"
  echo "GXXVERSION=`${CROSS_COMPILE}g++ --version | head -n1`"
  echo "DATE=`date +%Y-%m-%d`"
  echo "ARCH=`uname -m`"
  echo "CPU=`grep -E "^(model name|Processor)" /proc/cpuinfo | head -n1 | tr -s [:space:] | awk -F: '{print $2;}'`"
  echo "OS=`lsb_release -sd`"
  echo "TOPDIR=`pwd`"
  echo "date:`date --rfc-3339=seconds -u`"
  echo
  echo "uname:`uname -a`"
  echo
  echo lsb_release:
  lsb_release -a
  echo
  echo /proc/version:
  cat /proc/version
  echo
  echo "gcc: `dpkg -s gcc | grep ^Version`"
  gcc --version
  echo "as: `dpkg -s binutils | grep ^Version`"
  as --version
  echo
  echo ldd:
  ldd --version
  echo
  echo free:
  free
  echo
  echo ulimit:
  bash -c "ulimit -a"
  echo
  echo cpuinfo:
  cat /proc/cpuinfo
  echo gdb:
  dpkg -s gdb | grep ^Version
  gdb --version
  echo gcc-binary:
  #$(PWD)/$(@D)/gcc-binary/bin/gcc --version || true
  echo
  echo libc6:
  dpkg -s libc6 | grep ^Version
  echo PATH:
  echo $PATH
  echo
  echo cpufreq-info:
  echo `cpufreq-info`
  echo
 }
