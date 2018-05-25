#!/bin/bash

tsamp=5     # sampling interval
url1=http://192.168.2.9/api/meters/aggregates   # Tesla adress of Metering info
url2=http://192.168.2.9/api/system_status/soe   # Battery level in percent

Told=$(date +%F,%T)
mv aggregates.json aggregates_$Told.json

while true ; do
  # wait for seconds rollover
  while [ $(( $(date +%S | sed -e 's/^0//') % $tsamp)) -ne 0 ] ; do 
    sleep 0.1 ;
  done
  Tnew=$(date +%F,%T)
  dold=$(echo $Told | sed -e 's/,.*//')    # extract old date
  dnew=$(echo $Tnew | sed -e 's/,.*//')    # extract new date
  #curl $url1 >> aggregates.json
  wget -O - $url1  >> aggregates.json
  echo             >> aggregates.json
  if [ $dold != $dnew ] ; then
    mv aggregates.json teslog_$dold.json
    gzip teslog_$dold.json
    ls -l teslog_$dold.*
  fi
  sleep 1     # let actual second pass away
  told=$tnew
done

  
