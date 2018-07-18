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
#   # export and understand the structure of the data
#   teslogger.sh -e outformat="" pattern="" teslog_2018*.json.gz | head -n 200 
#
#   # export data to matlab/octave array
#   teslogger.sh -e teslog_2018-05-26.json.gz | head -n 30 > e.dat
#   teslogger.sh -e teslog_2018*.json.gz | head -n 30 > e.dat
#   teslogger.sh -e teslog_2018*.json.gz  > e.dat
#   teslogger.sh -e pattern='"date_time\|instant_power"' teslog_2018*.json.gz > p.dat
#
#   # gnu octave graph
#   load 'p.dat' ; figure, plot(p(:,7:10));
#   tlpower('aggregates_2018-06-17.json.gz');
#
# Background:
#   - connect with browser to Tesla Powerwall 2 and watch IP traffic
#     to learn how it works
#   - see also: jshon   - tool for parsing JSON data on the command-line

# $Header: teslogger.sh, v1.3, Andreas Merz, 2018, GPL $

hc=cat                        # header filter: none               
ip=192.168.2.7    # 1099752-01-B--T17J0003327  # my Tesla hostname

#--- default settings ---
tsamp=5     # sampling interval in seconds, 0.1 < tsamp < 60
url1=http://$ip/api/meters/aggregates   # Tesla adress of Metering info
url2=http://$ip/api/system_status/soe   # Battery level in percent
logfile=aggregates
action=log,stamp           # default action: start logging, add PC timestamp
outformat="dat"            # output file format [dat | csv | "" ]
pattern="date_time\|energy_"
reject="busway_\|frequency_\|generator_"

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

  Told=$(date +%F,%T.%N)
  $t mv $logfile.json ${logfile}_$Told.json   # save any unfinished data

  while true ; do

    # wait to the next multiple of tsamp seconds
    wait=$(date +%S.%N | sed -e 's/^0//' |
      awk -v tsamp=$tsamp '{ printf("%f", tsamp -0.007 - ($1 % tsamp))}')
    sleep $wait
    Tnew=$(date +%F,%T.%N)
    dnew=$(echo $Tnew | sed -e 's/,.*//')    # extract new date
    dold=$(echo $Told | sed -e 's/,.*//')    # extract old date

    # fetch new energy state
    if echo $action | grep "stamp" > /dev/null ; then
      echo -n "$Tnew: " >> $logfile.json     # add PC timestamp
    fi
    #curl $url1 >> $logfile.json
    $t wget --no-check-certificate -O - $url1   >> $logfile.json
    echo              >> $logfile.json

    # when a new day starts, save and compress data
    if [ "$dold" != "$dnew" ] ; then
      $t mv $logfile.json ${logfile}_$dold.json
      $t gzip ${logfile}_$dold.json
      $t ls -l ${logfile}_$dold.*
    fi

    Told=$Tnew
  done

fi

#-------------------------------------------------
# observer loop
#-------------------------------------------------
if echo "$action" | grep "watch" > /dev/null ; then
  echo "not implemented yet"
fi  

#-------------------------------------------------
# extract data
#-------------------------------------------------
if echo "$action" | grep "extract" > /dev/null ; then
  for logf in $logfiles ; do
    cat=cat
    if file $logf | grep "gzip compressed data" > /dev/null ; then
      cat=zcat
    fi
    if echo "$action" | grep "pretty-print" > /dev/null ; then
      # simple json formatter
      $t $cat $logf | tr ',' '\n' |
	 sed -e 's/{/\n{\n/g'     | sed -e 's/}/\n}\n/g' |
	 awk '   
           /\}/  { ident--; }
        	 { if(0) print $0;
	           if(1) {fmt=sprintf("%%%ds%%s\n",2*ident); printf(fmt,"",$0)};
		 };
           /\{/  { ident++; }
	   '
    else
      # simple json parser
      $t $cat $logf | tr ',' '\n' |  
	 sed -e 's/{/\n{\n/g'     | sed -e 's/}/\n}\n/g' |
	 awk '          
	                   { if(0) print $0; }   # debug
           /\{/            { ident++; }
           /\}/            { ident--; }
	   /^[0-9]{4}-[0-9]{2}-[0-9]{2}/ { 
	                     pcdate=$1;
	                     gsub("-"," ", pcdate); 
			   }
	   /^[0-9:\.]+: $/ { pctime=$1;
	                     gsub(":"," ", pctime); 
			     date_time=sprintf("\"%s %s\"", pcdate, pctime);
			     if (ident<1)
			       print "\ndate_time = " date_time ;
			   }
	   /.[A-z].*:/     { if(0) print $0;
	        	     split($1, t, ":", seps);
	        	     key=t[1];
			     val=t[2];
			     # last_communication_time special treatment:
			     if(t[5] != "") val=sprintf("%s:%s:%s:%s",t[2],t[3],t[4],t[5]);
			     if (val == "") 
			       obj=key ;
			     else { 
			       k=sprintf("%s_%s",obj,key);  # create a unique key
			       gsub("\"","",k);             # remove quotes
			       v[k]=val;
			     }
	        	     if(k != "") print k " = " v[k] ;
			   }
	   ' | grep -v "$reject" | grep "$pattern" |
	 awk -F "=" -v format=$outformat '
                       { newline=0; if(0) print $0; }
	   /date_time/ { newline=1; }
	               { if( format == "" ) 
		            print $0;
		       }         
	               { if( format == "dat" ) {    # Matlab ascii data
		            if(newline) {
			      newline=0
			      gsub("\"","",$2);
			      if(cnt++ == 1) { 
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
			    if($1) keycnt++;
		         }
		       }         
	               '
    fi
  done 
fi  
