#!/bin/bash
#
# teslogger.sh
#
# sample energy streams from Telsa Powerwall Gateway and log data to file

# settings
tsamp=5     # sampling interval
url1=http://192.168.2.9/api/meters/aggregates   # Tesla adress of Metering info
url2=http://192.168.2.9/api/system_status/soe   # Battery level in percent

Told=$(date +%F,%T.%N)
mv aggregates.json aggregates_$Told.json   # save any unfinished data

while true ; do

  # wait for seconds rollover
  while [ $(( $(date +%S | sed -e 's/^0//') % $tsamp)) -ne 0 ] ; do 
    sleep 0.01 ;
  done
  Tnew=$(date +%F,%T.%N)
  dnew=$(echo $Tnew | sed -e 's/,.*//')    # extract new date
  dold=$(echo $Told | sed -e 's/,.*//')    # extract old date

  # fetch new energy state
  echo -n "$Tnew: " >> aggregates.json     # add PC timestamp
  #curl $url1 >> aggregates.json
  wget -O - $url1   >> aggregates.json
  echo              >> aggregates.json
  
  # when a new day starts, save and compress data
  if [ "$dold" != "$dnew" ] ; then
    mv aggregates.json teslog_$dold.json
    gzip teslog_$dold.json
    ls -l teslog_$dold.*
  fi

  sleep 1     # let actual second pass away
  told=$tnew
done

  
