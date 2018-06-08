#!/bin/bash
# convert teslogger log files to octave readable .dat file
for ii in $* ; do
  jj=$(echo $ii | sed -e 's/json.*/dat/')
  ./teslogger.sh -e pattern='"date_time\|instant_power\|energy_\|frequency"' $ii > $jj
done
