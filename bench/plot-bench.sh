#!/bin/bash

# NOTE: because this script uses arrays, it needs to be run using 'bash'. not 'dash'

if test "$#" -eq 0; then
   echo "Need to supply a graph name!"
   name="eembc"
else
    name=$1
fi

# lines        dots       steps     errorbars     xerrorbar    xyerrorlines
# points       impulses   fsteps    errorlines    xerrorlines  yerrorbars
# linespoints  labels     histeps   financebars   xyerrorbars  yerrorlines
# vectors
#	or
# boxes            candlesticks   image      circles
# boxerrorbars     filledcurves   rgbimage   ellipses
# boxxyerrorbars   histograms     rgbalpha   pm3d
# boxplot

# specify a different line style
itype=""
type="with lines"

#echo "plot "\'eembc.data\'" using (\$7) title "\'Min\'" lt rgb "\'green\'" ${type},  '' using (\$8) title "\'Max\'" lt rgb "\'red\'"  ${type},  '' using (\$11) title "\'Best\'" lt rgb "\'cyan\'" ${type}" >> gnuplot.cmd
#plot "\'eembc.data\'"  using (\$4) title "\' Min\'" lt rgb "\'red\'" ${type}, '' using (\$5) title "\'Max\'" lt rgb "\'green\'" ${type}"

# setup aarray of colors, since the number of data files varies
declare -a colors=('red' 'green' 'cyan' 'blue' 'purple' 'brown' 'coral' 'aqua')

# We could get these from the database, but right now this script isn't setup
# for dirct MySQL access
benchmarks="eembc coremark denbench eembc_office spec2000"
variants="o3-neon o3-arm o3-armv6 o3-vfpv3"
machines="cortexa9r1 armv5r2 x86_64r1 cortexa8r1 cortexa9hfr1 armv6r1"

for i in ${benchmarks}; do
    cindex=0
    rm -f gnuplot-$i.cmd
    for j in ${machines}; do
	if test -f $i.$j.data; then
	    if test ${cindex} -eq 0; then
		cat <<EOF >gnuplot-$i.cmd
set boxwidth 0.9 relative 
set style data histograms 
set style histogram cluster 
set style fill solid 1.0 border lt -1
set autoscale x
set autoscale y
set title "$i Benchmark Results"
set ylabel "Count"
set xlabel "Architecture"

# Rotate the X axis labels 90 degrees, so they all fit
set xtics border in scale 1,0.5 nomirror rotate by -90  offset character 0, 0, 0

# Out the key in out of the way
set key left top

set term png size 1900,1024
set output "benchrun.png"

set xlabel "gcc-linaro releases"

set grid ytics lt 0 lw 1 lc rgb "#bbbbbb"
#set grid xtics lt 0 lw 1 lc rgb "#bbbbbb"

EOF
		echo -n "plot \"$i.$j.data\" using (\$6):xtic(2) title \"$j\" lt rgb \"${colors[$cindex]}\"  ${type}" >> gnuplot-$i.cmd

	    else
		echo -n ", \"$i.$j.data\" using (\$6):xtic(1) title \"$j\" lt rgb \"${colors[$cindex]}\" ${type}" >> gnuplot-$i.cmd
	    fi
# 	    gnuplot gnuplot-$i.cmd &
	    cindex=`expr $cindex + 1`
	fi
    done
    echo "" >> gnuplot-$i.cmd
    echo "set term x11 persist" >> gnuplot-$i.cmd
    echo "replot" >> gnuplot-$i.cmd
done
