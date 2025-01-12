#!/bin/bash
#
# tlpower.sh [-h | -r | -d ] [file ..]
#
# Purpose: 
#   convert teslogger log files to octave readable .dat file
#
# Usage examples:
#   tlpower.sh       # extract default keys from aggregates.json 
#   tlpower.sh -r    # do this on remote machine 
#   tlpower.sh -d    # extract differentially 
#
# Background:
#   - in case no file name is given, a differential extract is tried
#   - simple interface to extract "standard" data from teslogger logs
#   - calls teslogger -e .. to extract the data
#   - implements a way extract and transmit data differentially
#   - -d does not yet allow multiple clients/threads.

# $Header: tlpower.sh, v1.04, Andreas Merz, 2018, GPL $

# TODO: read this from a common config.m file
logsrv='192.168.2.9'
logdir='/home/amerz/office/projects/solar/tesla_solaredge/log'
logfile='aggregates'

if [ "$1" == "-h" ] ; then   # help
  sed -n '2,/^#.*Header: /p' $0 | cut -c 2- ;
  exit ;   # help
fi

if [ "$1" == "-r" ] ; then   # call remote counterpart
  shift
  # execute this script on the remote machine
  if "$1" == "" ] ; then
    ssh $logsrv "cd $logdir ; tlpower.sh -d"
    scp $logsrv:$logdir/diff.dat diff$$.dat
  else
    ssh $logsrv "cd $logdir ; tlpower.sh $*;"
    scp $logsrv:$logdir/*.dat .
  fi 
fi

if [ "$1" == "-d" ] ; then   # differential extraction
  shift
  if find . -name aggregates.dat -daystart -mtime 0 ; then 
    echo "recent $logfile.dat found. Converting only newer data from $logfile.json"
    # zeit des vorletzten Eintrags ermitteln
    lasttime=$(tail -n 1 $logfile.dat | awk '{ printf("%s-%s-%s,%s:%s:%s",$1,$2,$3,$4,$5,$6);}')
    echo "# lasttime=$lasttime"
    #echo "sed -n /$lasttime/,\$p $logfile.json"
    sed -n "/$lasttime/,\$p" $logfile.json > diff.json
    ./teslogger.sh -e pattern='"date_time\|instant_power\|energy_\|frequency\|percentage"' diff.json > diff.dat
    mv $logfile.dat $logfile.tmp
    
    # die letzte Zeile der bisherigen Daten ignorieren und neue Daten anhaengen
    head -n -1 $logfile.tmp > $logfile.dat
    echo "# lasttime=$lasttime" >> $logfile.dat
    cat diff.dat | grep -v "^#" >> $logfile.dat
    exit
    
  else
    if [ -f $logfile.dat ] ; then
      echo "$logfile.dat outdated, removing it"
      echo rm $logfile.dat
      echo "no $logfile.dat, extracting it from $logfile.json"
    fi
  fi
fi

args="$*"
if [ "$args" == "" ] ; then
  # process today's file as default
  args=$logfile.json
fi

# process all other file arguments locally
for ii in $args ; do
  jj=$(echo $ii | sed -e 's/json.*/dat/')
  
  echo "processing $ii --> $jj"

  # extract energy data and battery charging state
  # ./teslogger.sh -e pattern='"date_time\|instant_power\|energy_\|frequency\|percentage"' $ii > $jj
  # ... and L123 powers
  ./teslogger.sh -e pattern='"date_time\|instant_power\|energy_\|frequency\|percentage\|_p_W\|_q_VAR"' $ii > $jj

  # extract battery charging state
  # pp=$(echo $ii | sed -e 's/json.*/percentage.dat/')
  #./teslogger.sh -e pattern='"date_time\|percentage"' $ii > $pp
  
  echo
done
