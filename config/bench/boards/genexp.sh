#!/bin/bash

other=0
alt_other=5
a53_freq=700MHz
a57_freq=800MHz
for y in 0 1 2 3 4 5; do
  for x in base freq net aslr env nice; do
    cat > noise-control-experiment-juno-${y}-${x}.conf << EOF
#$y $x
benchcore=$y
othercore=`if test $y -eq $other; then echo $alt_other; else echo $other; fi`
freq=`if test $x = freq; then
         for z in 1 2; do
           if test $y -eq $z; then
             echo 800MHz
             exit
           fi
         done
         echo 700MHz
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
