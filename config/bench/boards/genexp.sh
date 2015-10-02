#!/bin/bash

set -ue -o pipefail

other=0
alt_other=5
size=(L B B L L L)
declare -A freqL=([slowest]=450MHz [slower]=575MHz [freq]=700MHz [faster]=775MHz [fastest]=850MHz)
declare -A freqB=([slowest]=450MHz [slower]=625MHz [freq]=800MHz [faster]=950MHz [fastest]=1100MHz)
for y in 0 1 2 3 4 5; do
  for x in base slowest slower freq faster fastest net aslr env nice; do
    cat > noise-control-experiment-juno-${y}-${x}.conf << EOF
#$y $x
benchcore=$y
othercore=`if test $y -eq $other; then echo $alt_other; else echo $other; fi`
freq=`if test x${size[$y]} = xL; then
        echo ${freqL[$x]:-}
      elif test x${size[$y]} = xB; then
        echo ${freqB[$x]:-}
      fi`
netctl=`if test $x = net; then echo yes; else echo no; fi`
aslrctl=`if test $x = aslr; then echo yes; else echo no; fi`
envctl=`if test $x = env; then echo yes; else echo no; fi`
nicectl=`if test $x = nice; then echo yes; else echo no; fi`
servicectl=no
ip=root@noise-experiment-juno
boot_timeout=90

#Avoid spaces within parameters, they aren't worth the heartache
`for z in 1 2; do
   if test $y -eq $z; then
     echo board_benchargs=\"HW_MODEL=Juno_r0 HW_CPU=Cortex-A57 HW_FPU=fp_asimd_evtstrm_aes_pmull_sha1_sha2_crc32\"
     exit
   fi
 done
 echo board_benchargs=\"HW_MODEL=Juno_r0 HW_CPU=Cortex-A53 HW_FPU=fp_asimd_evtstrm_aes_pmull_sha1_sha2_crc32\"`

EOF
  done
done
