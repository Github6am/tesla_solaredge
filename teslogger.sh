#!/bin/bash
#
# teslogger.sh
#
# Purpose: 
#   sample energy streams from Tesla Powerwall Gateway and log data to file
#
# Usage examples:
#
#   # record energy data
#   teslogger.sh
#   teslogger.sh tsamp=2
#
#   teslogger.sh wgetopts="'-d'"   # debug output, see wget -h, man wget
#
#   nohup teslogger.sh tsamp=2 &   # run as a daemon
#
#   nohup teslogger.sh tsamp=2 | gzip > nohup.out.gz &   # compress huge output
#
#   # export and understand the structure of the data
#   teslogger.sh -e outformat="" pattern="" teslog_2018*.json.gz | head -n 200 
#   teslogger.sh action=extract,pretty-print linerange=1,2 outformat="" aggregates.json
#
#   # export data to matlab/octave array
#   teslogger.sh -e teslog_2018-05-26.json.gz | head -n 30 > e.dat
#   teslogger.sh -e teslog_2018*.json.gz | head -n 30 > e.dat
#   teslogger.sh -e teslog_2018*.json.gz  > e.dat
#   teslogger.sh -e pattern='"date_time\|instant_power"' aggregates_2018*.json.gz > p.dat
#   teslogger.sh -e pattern='"date_time\|instant_power"' linerange=/07:15:00/,/07:16:00/ aggregates_2018-10*.json.gz > p.dat
#   teslogger.sh -e pattern='"date_time\|_v_V"' aggregates.json
#
#   # gnu octave graph
#   load 'p.dat' ; figure, plot(p(:,7:10));
#   tlpower('aggregates_2018-06-17.json.gz');
#
# Background:
#   - since powerwall2 v20.49.0 we need all this login stuff; 
#     the credentials are in teslogin.sh, which has to be edited and in your PATH
#   - since powerwall2 v21.35.0 , 2021-10-01 the stuff does not run stable anymore. :-( F*CK Tesla
#     It happens that the Gateway does not respond over the network anymore
#     and needs a power-down reset - the dumb thing has no reset button...
#   - in v21.44 they introduced a last_phase_energy_communication_time field.
#   - for each day, a gzipped file containing energy data is stored on the file system.
#   - connect with browser to Tesla Powerwall 2 and watch http traffic
#     to learn how it works
#   - GnuTLS problem with wget 1.13.4 on Raspbian. Worked with wget 1.16
#   - try to work correctly with mawk and gawk
#   - lots of thanks to Vince, https://github.com/vloschiavo/powerwall2.git
#     his powerwallstats.sh script helped a lot after the annoying silent 
#     Tesla update on 2021-02-02 18:26:32.

# $Header: teslogger.sh, v1.5, Andreas Merz, 2018-2021 GPL3 $

hc=cat                        # header filter: none               

# Put PID in the cookie file name to allow for multiple logger threads
cookie=/tmp/teslogger_cookie$$.txt

#--- default settings ---
tsamp=5     # sampling interval in seconds, 0.1 < tsamp < 60
url0=api/system/update/status # current version info
url1=api/meters/aggregates   # Tesla adress of Metering info
url2=api/system_status/soe   # Battery level in percent
url3=api/meters/readings     # Neurio sensors data
logfile=aggregates
action=log,stamp           # default action: start logging, add PC timestamp
outformat="dat"            # output file format [dat | csv | "" ]
pattern="date_time\|energy_"
reject="busway_\|frequency_\|generator_\|last_phase_"
wgetopts=""
authopts="--no-check-certificate --keep-session-cookies"
linerange='1,'             # sed adress, eg 1,100 or /13:15:50/,

#--- process arguments ---
cmdline="$0 $@"
narg=$#
echo=echo
cnt=0

while [ "$1" != "" ] ; do
  case "$1" in
   -h)       sed -n '2,/^#.*Header: /p' $0 | cut -c 2- ; exit ;;   # help
   -t)       t=echo ; echo="echo -ne \\c" ;;  # dry run, test
   -e)       action=extract ; hc="sed -e s/^/#/" ;;     # extract
   -l)       action=log ;;      # log, no pc timestamps
   -w)       action=watch ;;    # observe
   -*)       echo "warning: unknown option $1" ;  sleep 2 ;;
   *=*)      echo $1 | $hc ; eval $1 ;;
   *)        par="$1" ; cnt=`expr $cnt + 1` ; echo "arg[$cnt]=$par" | $hc ;;
  esac
  shift

  # compatibility to enumerated parameter interface  - no mixing, only appending of new will work!
  case "$cnt" in 
   0)  ;; 
   1)  logfile="$par" ; logfiles="$logfile" ;;
   *)  logfiles="$logfiles $par" ;;             # append all further arguments
  esac 
done

logfile=$logfile$t   # avoid overwriting of files in test case

# show settings
varlist="$(sed -ne "/^#--- default settings ---/,/^#--- process arguments ---/p" $0 | grep "=" | grep -v "^if " | grep -v "^ *echo "  | sed -e 's/=.*//' -e 's/^ *//' | grep -v "#" | sort -u )"
#echo $varlist
echo                    | $hc
echo "# command line:"  | $hc
echo "$cmdline"         | $hc
echo                    | $hc
echo "# settings:"      | $hc
for vv in $varlist ; do
  echo "$vv=\"${!vv}\"" | $hc
done                    
echo                    | $hc


#-------------------------------------------------
# logger loop
#-------------------------------------------------
if echo "$action" | grep "log" > /dev/null ; then

  Told=$(date +%F,%T.%N#%s)
  sold=$(echo $Told | sed -e 's/.*#//')       # old unix second
  told=$(echo $Told | sed -e 's/#.*//')       # old time stamp
  $t mv $logfile.json ${logfile}_$told.json   # save any unfinished data after restart

  ip="$(teslogin.sh $cookie)"   # create session cookie and get powerwall2 IP address
  pollstatus="startup"          # poll gateway status after startup of this script
  
  while true ; do

    # wait to the next multiple of tsamp seconds
    wait=$(date +%S.%N | sed -e 's/^0//' |
      awk -v tsamp=$tsamp '{ printf("%f", tsamp -0.007 - ($1 % tsamp))}')
    sleep $wait
    Tnew=$(date +%F,%T.%N#%s)
    dnew=$(echo $Tnew | sed -e 's/,.*//')    # extract new date
    dold=$(echo $Told | sed -e 's/,.*//')    # extract old date
    snew=$(echo $Tnew | sed -e 's/.*#//')    # extract new unix second
    hnew=$(echo $Tnew | sed -e 's/.*,\(..\):.*/\1/')    # extract new hour
    hold=$(echo $Told | sed -e 's/.*,\(..\):.*/\1/')    # extract old hour
    #Mnew=$(echo $Tnew | sed -e 's/.*:\(..\):.*/\1/')    # extract new minute
    #Mold=$(echo $Told | sed -e 's/.*:\(..\):.*/\1/')    # extract old minute


    # fetch new energy state
    if echo $action | grep "stamp" > /dev/null ; then
      echo -n "$Tnew: " | sed -e 's/#.*:/:/' >> $logfile.json     # add PC timestamp
    fi
    $t wget $wgetopts $authopts --load-cookies $cookie -O - https://$ip/$url1   >> $logfile.json
    error_status1=$?
    echo              >> $logfile.json

    # fetch new battery state every minute
    #if [ "$Mold" != "$Mnew" ] ; then
    # if echo $action | grep "stamp" > /dev/null ; then
    #   echo -n "$Tnew: " >> $logfile.json     # add PC timestamp
    # fi
      $t wget $wgetopts $authopts --load-cookies $cookie -O - https://$ip/$url2   >> $logfile.json
      error_status2=$?
      echo              >> $logfile.json
    #fi

    # fetch new voltages and reactive power data
    $t wget $wgetopts $authopts --load-cookies $cookie -O - https://$ip/$url3	>> $logfile.json
    error_status3=$?
    echo	      >> $logfile.json

    # when a new hour starts, get status info
    if [ "$hold" != "$hnew" -o "$pollstatus" != "" ] ; then
      $t wget $wgetopts $authopts --load-cookies $cookie -O - https://$ip/$url0	>> $logfile.json
      error_status0=$?
      echo	      >> $logfile.json
    fi

    # when a new day starts, save and compress data
    if [ "$dold" != "$dnew" ] ; then
      $t mv $logfile.json ${logfile}_$dold.json
      $t gzip ${logfile}_$dold.json &
      $t ls -l ${logfile}_$dold.*
      teslogin.sh $cookie
    fi

    # error handling
    error_status="$error_status1$error_status2$error_status3"
    if [ "$error_status" == "000" ] ; then
      sold=$(echo $Told | sed -e 's/.*#//')    # update unix second of last success
      pollstatus=""                            # reset poll flag
    else
      dt=$(( $snew - $sold))
      echo "error_status=$error_status # at $Tnew  since $dt s"
      pollstatus="active"    # try to log more info from frequent status telegrams
      
      case "$error_status" in
	444)
          echo "error: network connection seems to be broken"
	  ;;

	555|666|888)
          echo "error: auth failed, trying to login and renew cookie" 
          teslogin.sh $cookie 
	  ;;

	*)
          echo "error: no handler for this type available yet, see also: man wget" 
          teslogin.sh $cookie 
	  ;;
      esac
      if [ $dt -gt 30 ] ; then
        echo "error state still remains - retrying after 2 min"
        sleep 120
      fi 
    fi
 
    # finally ... update time FIFO
    Told=$Tnew
  done

fi

#-------------------------------------------------
# observer loop
#-------------------------------------------------
if echo "$action" | grep "watch" > /dev/null ; then
  echo "not implemented yet, use tail -f aggregates.json"
fi  

#-------------------------------------------------
# extract data
#-------------------------------------------------
if echo "$action" | grep "extract" > /dev/null ; then
  sedrange="$(echo $linerange | sed 's/,$/,$/') p"
  echo "#sedrange=$sedrange"

  for logf in $logfiles ; do
    cat=cat
    if file $logf | grep "gzip compressed data" > /dev/null ; then
      cat=zcat
    fi
    
    # test, if multi-line data set, date tag is considered as start
    multline=$($cat $logf | sed -n '2,/^2[0-9][0-9][0-9]-/ p' | wc -l) 
    
    if echo "$action" | grep "pretty-print" > /dev/null ; then
      # simple json formatter
      $t $cat $logf | sed -n "$sedrange" | tr ',' '\n' |
         sed -e 's/{/\n{\n/g'     | sed -e 's/}/\n}\n/g' |
         awk '   
           /\}/  { ident--; }
                 { if(0) print $0;
                   if(1) {fmt=sprintf("%%%ds%%s\n",2*ident); printf(fmt,"",$0)};
                 };
           /\{/  { ident++; }
           '
    else
      # simple json parser. 
      #   1. select lines, 2. reject lines without data, 3. break up to multiple lines, 
      #   4. add curly braces, 5. awk pattern matching
      $t $cat $logf | sed -n "$sedrange" | grep -v ": $\|^$" | tr ',' '\n' |  
         sed -e 's/{/\n{\n/g'     | sed -e 's/}/\n}\n/g' |
         awk '          
                           { if(0) print $0; }   # debug
           /\{/            { ident++; }
           /\}/            { ident--; }
           /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/ { 
                             pcdate=$1;
                             gsub("-"," ", pcdate);
                             k="";
                           }
           /^[0-9:\.]+: $/ { pctime=$1;
                             gsub(":"," ", pctime); 
                             date_time=sprintf("\"%s %s\"", pcdate, pctime);
                             if (ident<1)
                               print "\ndate_time = " date_time ;
                           }
           /.[A-z].*:/     { if(0) print $0;
                             if(ident<2) obj="global";
                             split($1, t, ":");
                             key=t[1];
                             val=t[2];
                             # last_communication_time special treatment:
                             if(t[5] != "") val=sprintf("%s:%s:%s:%s",t[2],t[3],t[4],t[5]);
                             if (val == "") { 
                               obj=key ;
                               k="";
                             }
                             else { 
                               k=sprintf("%s_%s",obj,key);  # create a unique key
                               gsub("\"","",k);             # remove quotes
                               v[k]=val;
                             }
                             if(k != "") print k " = " v[k] ;
                           }
           ' | grep -v "$reject" | grep "$pattern" |
         awk -F "=" -v format=$outformat '
                       { newline=0; if(0) print $0; 
                       }
           /date_time/ { newline++; 
                       }
                       { if( format == "" ) 
                            print $0;
                       }         
                       { if( format == "dat" ) {    # Matlab ascii data
                            if(newline) {
                              gsub("\"","",$2);
                              if(cnt++ == 1) {      # print title once, then never again
                                print title ; 
                                Nk=keycnt;          # remember number of keys
                              }
                              if( Nk==keycnt) print data ;  # output data, if no item is missing
                              title="#"
                              data=""
                              keycnt=0;
                            }
                            title=sprintf("%s %s", title, $1);   # collect left hand sides (keys)
                            data =sprintf("%s %s",  data, $2);   # collect right hand sides (values)
                            #data =sprintf("%s %10.4f",  data, $2);   # collect right hand sides (values)
                            if($1) keycnt++;
                         }
                       }         
                       '
    fi
  done 
fi

