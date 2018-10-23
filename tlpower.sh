#!/bin/bash
# convert teslogger log files to octave readable .dat file
for ii in $* ; do
  jj=$(echo $ii | sed -e 's/json.*/dat/')
  pp=$(echo $ii | sed -e 's/json.*/percentage.dat/')

  # extract energy data
  ./teslogger.sh -e pattern='"date_time\|instant_power\|energy_\|frequency"' $ii > $jj

  # extract battery charging state
  ./teslogger.sh -e pattern='"date_time\|percentage"' $ii > $pp
done
