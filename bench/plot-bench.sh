#!/bin/sh


if test "$#" -eq 0; then
   echo "Need to supply a graph name!"
   name="EEMBC Benchmark"
else
    name=$1
fi

cat <<EOF >gnuplot.cmd
set boxwidth 0.9 relative 
set style data histograms 
set style histogram cluster 
set style fill solid 1.0 border lt -1
set autoscale x
set autoscale y
set title "Benchmrk Results"
set ylabel "Count"
set xlabel "Architecture"

# Rotate the X axis labels 90 degrees, so they all fit
set xtics border in scale 1,0.5 nomirror rotate by -90  offset character 0, 0, 0

# Out the key in out of the way
set key left top

set term png
set output "benchrun.png"

set xlabel "${name}"

set grid ytics lt 0 lw 1 lc rgb "#bbbbbb"
#set grid xtics lt 0 lw 1 lc rgb "#bbbbbb"

EOF

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
type=""
type="with lines"

#echo "plot "\'eembc.data\'" using (\$7) title "\'Min\'" lt rgb "\'green\'" ${type},  '' using (\$8) title "\'Max\'" lt rgb "\'red\'" ${type},  '' using (\$11) title "\'Best\'" lt rgb "\'cyan\'" ${type}" >> gnuplot.cmd
#echo "plot "\'eembc.data\'"  using (\$4) title "\'Min\'" lt rgb "\'red\'" ${type}, '' using (\$5) title "\'Max\'" lt rgb "\'green\'" ${type}" >> gnuplot.cmd

echo "plot "\'eembc.data\'" using (\$6):xtic(2) title "\'Best\'" lt rgb "\'green\'" ${type}" >> gnuplot.cmd

#echo "plot "\'eembc.data\'" using (\$5):xtic(int(\$0)%3==0?stringcolumn(1):\"\") t column(2) title "\'Min\'" lt rgb "\'red\'" ${type}" >> gnuplot.cmd

cat <<EOF >> gnuplot.cmd
set term x11 persist
replot

# Line graph
# set style data linespoints
# replot

EOF

gnuplot gnuplot.cmd
