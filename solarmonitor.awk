#!/usr/bin/awk -E
# File: solarmonitor.awk
#
# Purpose: a ksysguardd to retrieve and report Tesla Powerwall gateway solar sensor data
#
# Usage Example:
#   ksysguard # Neues Arbeitsblatt, Entfernten Rechner ueberwachen -> Name der Quelle, Befehl 
#   ls -ltr ~/.local/share/ksysguard  # new sgrd file occurs, if not saved
#   vi ~/.config/ksysguardrc          # set active sheets and other stuff    
#
#   echo monitors | ./solarmonitor.awk
#
#   echo load_instant_power? | ./solarmonitor.awk
#   echo load_instant_power  | ./solarmonitor.awk
#
# Background:
#   - Since ksysguard has a nice display of live performance data, 
#     I wanted to use it to monitor my photovoltaic system, see Solaranlage.sgrd
#   - https://techbase.kde.org/Development/Tutorials/Sensors
#   - TODO: time is not processed yet.
#           tesla cookie will expire after 24h, not yet handled
#   - server IP addresses/names and access credentials are moved to teslogin.sh - needs to be in PATH
#   - take care: awk seems to deny scalar re-use of a variable, once it has been promoted to an array...
#   - debugging:  set dbg=1 in the code, start in different terminals:
#     nc -lk localhost 55555 | ./solarmonitor.awk
#     echo monitors | nc localhost 55555
#     tail -f /tmp/solarmonitor.log
#   - this is the kind of telegram we want to parse:
#     {"site":{"last_communication_time":"2020-11-07T18:03:17.689290067+01:00","instant_power":1307.253238916397,"instant_reactive_power":774.6698570251465,"instant_apparent_power":1519.5474385621437,"frequency":49.99971389770508,"energy_exported":11629334.309208203,"energy_imported":3029011.8005970903,"instant_average_voltage":217.46618143717447,"instant_total_current":0,"i_a_current":0,"i_b_current":0,"i_c_current":0,"timeout":1500000000},"battery":{"last_communication_time":"2020-11-07T18:03:17.690092061+01:00","instant_power":0,"instant_reactive_power":0,"instant_apparent_power":0,"frequency":49.992000000000004,"energy_exported":3256440,"energy_imported":3889760,"instant_average_voltage":217.4,"instant_total_current":0,"i_a_current":0,"i_b_current":0,"i_c_current":0,"timeout":1500000000},"load":{"last_communication_time":"2020-11-07T18:03:17.689290067+01:00","instant_power":1320.3204550697542,"instant_reactive_power":812.0530246793107,"instant_apparent_power":1550.0568437855495,"frequency":49.99971389770508,"energy_exported":0,"energy_imported":10389789.47222222,"instant_average_voltage":217.46618143717447,"instant_total_current":6.071382898913834,"i_a_current":0,"i_b_current":0,"i_c_current":0,"timeout":1500000000},"solar":{"last_communication_time":"2020-11-07T18:03:17.689608398+01:00","instant_power":12.455572962760925,"instant_reactive_power":35.099782943725586,"instant_apparent_power":37.244275540374126,"frequency":49.99971389770508,"energy_exported":19623486.929171618,"energy_imported":54.94833828607079,"instant_average_voltage":217.57920837402344,"instant_total_current":0,"i_a_current":0,"i_b_current":0,"i_c_current":0,"timeout":1500000000}}
#
# Author: A. Merz, 2021, GPLv3 or later, see http://www.gnu.org/licenses

 BEGIN		        { printf("ksysguardd 1.2.1\nksysguardd> "); fflush();
			  
			  cookiefile=sprintf("/tmp/solarmonitor_cookie%d.txt", PROCINFO["pid"]); # thread-safe cookie file name
                          cmdB=sprintf("teslogin.sh %s", cookiefile);
			  cmdB | getline ipaddress;    # set new cookie to access powerwall and get its ip address
			  close(cmdB);
			  
			  # the powerwall query commands
			  cmd1=sprintf("wget -q --no-check-certificate --keep-session-cookies --load-cookies %s -O - https://%s/api/meters/aggregates", cookiefile, ipaddress) ;
                          cmd2=sprintf("wget -q --no-check-certificate --keep-session-cookies --load-cookies %s -O - https://%s/api/system_status/soe", cookiefile, ipaddress) ;
                          cmd3=sprintf("wget -q --no-check-certificate --keep-session-cookies --load-cookies %s -O - https://%s/api/meters/readings/",   cookiefile, ipaddress) ;
                          
			  cmdT="date '+%s.%N'";
                          cmdE="ssh rapk head -n 1 /home/amerz/office/projects/solar/tesla_solaredge/log/aggregates.json" ;
			  
			  # assemble key patterns which can be monitored
			  keyglo="site battery load solar";
			  keysub="last_communication_time instant_power energy_exported energy_imported frequency"
			  vtype="integer float float float float"
			  vunit="s W kWh kWh Hz"
			  split(keyglo, glob_kg, " ", seps);
			  split(keysub, glob_ks, " ", seps);
			  split(vtype,  glob_vt, " ", seps);
			  split(vunit,  glob_vu, " ", seps);
			  monitors="battery_charge\tfloat";
			  for (k in glob_kg)
			    for (s in glob_ks ) {
			      monitors=sprintf("%s\n%s", monitors, glob_kg[k] "_" glob_ks[s] "\t" glob_vt[s]);
			    }
			  for (j=1; j<=2 ; j++)
			    for (i=1 ; i<=4 ; i++ ) {
			      monitors=sprintf("%s\nsensor%d/L%d_v\tfloat",    monitors, j, i );
			      monitors=sprintf("%s\nsensor%d/L%d_p\tfloat",    monitors, j, i );
			      monitors=sprintf("%s\nsensor%d/L%d_q\tfloat",    monitors, j, i );
			      monitors=sprintf("%s\nsensor%d/L%d_eExp\tfloat", monitors, j, i );
			      monitors=sprintf("%s\nsensor%d/L%d_eImp\tfloat", monitors, j, i );
			    }
			  cmdT | getline t_old;
			  close(cmdT);
			  #cmdE | getline resp0;  # get the first message of today for Energy calculations
			  #close(cmdE);
			  
			  # logging / debugging
			  dbg=0;
			  logfile="/tmp/solarmonitor.log"
			  if(dbg>0) printf("%d: BEGIN\n", t_old) > logfile ;  # debug
			  sensor_group=0;
			}
			
			# a new request 
			{  
			  request=$0;
			}
			
/^monitors$/	        {
                          result=monitors ;
			  print result;
                        }
/^version$/	        {
                          result="\"solarmonitor.awk, v2.0, a ksysguard daemon\"";
			  print result;
                        }
/developer_code/        { # create linear source code for this program, which is easier to read than sophisticated loops
                          for (k in glob_kg)
			    for (s in glob_ks ) {
			      key=glob_kg[k] "_" glob_ks[s];
			      printf("%-36s { print \"%s %s\\t0\\t0\\t%s\" }\n", "/" key "\\?/" ,glob_kg[k],glob_ks[s],glob_vu[s]);
			    }
			  printf("/sensor./L._v\\?/       { print \"Voltage\\t0\\t0\\tV\" }\n");
			  printf("/sensor./L._p\\?/	  { print \"Power\\t0\\t0\\tW\" }\n");
			  printf("/sensor./L._q\\?/	  { print \"Reactive Power\\t0\\t0\\tVar\" }\n");
			  printf("/sensor./L._eExp\\?/    { print \"Energy Exported\\t0\\t0\\tkWh\" }\n");
			  printf("/sensor./L._eImp\\?/    { print \"Energy Imported\\t0\\t0\\tkWh\" }\n");
                        }
/json1$/                { # test command
                          # printf("%s\n", cmd1); fflush();
                          cmd1 | getline resp1 ; 
                          close(cmd1);
                          printf("%s\n", resp1); fflush(); 
			}
/json0$/	        { # test command to read via ssh from my solar logger
                          # vielleicht dauert es zu lange, wenn es bei BEGIN ausgefuehrt wird?
			  cmdE | getline resp0;  # get the first message of today for Energy calculations
			  close(cmdE);
                          printf("%s\n", resp0); fflush(); 
			}
			
			# -------- for every request get a new time stamp -------------
			{
			  cmdT | getline t_new;        # we use this, to limit the rate of new wget request
			  close(cmdT);
			  if(dbg>0) print "# " t_new " cmd: " $0    >> logfile ;   # debug
			}
			 
/^battery_charge\?/	              { print "Battery charging state\t0\t100\t%" } 
/^site_last_communication_time\?/     { print "site last_communication_time\t0\t0\ts" }
/^site_instant_power\?/               { print "site instant_power\t0\t0\tW" }
/^site_energy_exported\?/             { print "site energy_exported\t0\t0\tkWh" }
/^site_energy_imported\?/             { print "site energy_imported\t0\t0\tkWh" }
/^site_frequency\?/                   { print "site frequency\t0\t0\tHz" }
/^battery_last_communication_time\?/  { print "battery last_communication_time\t0\t0\ts" }
/^battery_instant_power\?/            { print "battery instant_power\t0\t0\tW" }
/^battery_energy_exported\?/	      { print "battery energy_exported\t0\t0\tkWh" }
/^battery_energy_imported\?/	      { print "battery energy_imported\t0\t0\tkWh" }
/^battery_frequency\?/  	      { print "battery frequency\t0\t0\tHz" }
/^load_last_communication_time\?/     { print "load last_communication_time\t0\t0\ts" }
/^load_instant_power\?/ 	      { print "load instant_power\t0\t0\tW" }
/^load_energy_exported\?/	      { print "load energy_exported\t0\t0\tkWh" }
/^load_energy_imported\?/	      { print "load energy_imported\t0\t0\tkWh" }
/^load_frequency\?/		      { print "load frequency\t0\t0\tHz" }
/^solar_last_communication_time\?/    { print "solar last_communication_time\t0\t0\ts" }
/^solar_instant_power\?/	      { print "solar instant_power\t0\t0\tW" }
/^solar_energy_exported\?/	      { print "solar energy_exported\t0\t0\tkWh" }
/^solar_energy_imported\?/	      { print "solar energy_imported\t0\t0\tkWh" }
/^solar_frequency\?/		      { print "solar frequency\t0\t0\tHz" }
/^sensor.\/L._v\?/	 { qq=$0; gsub( /[^0-9L]/, "", qq) ; printf( "V%s\t0\t0\tV\n",    qq); } # V2L3   
/^sensor.\/L._p\?/	 { qq=$0; gsub( /[^0-9L]/, "", qq) ; printf( "P%s\t0\t0\tW\n",    qq); } # P2L3    
/^sensor.\/L._q\?/	 { qq=$0; gsub( /[^0-9L]/, "", qq) ; printf( "Q%s\t0\t0\tVA\n",   qq); } # Q2L3    
/^sensor.\/L._eExp\?/	 { qq=$0; gsub( /[^0-9L]/, "", qq) ; printf( "Ex%s\t0\t0\tkWh\n", qq); } # Ex2L3	 
/^sensor.\/L._eImp\?/	 { qq=$0; gsub( /[^0-9L]/, "", qq) ; printf( "Ei%s\t0\t0\tkWh\n", qq); } # Ei2L3 

/^battery_charge$/	 {request=$0;
                          sensor_group=2;
			 }

/^sensor$/	 	 {request=$0;
			  cmd3 | getline resp3 ; cmdT | getline t
                          close(cmd3);
                          print "ERRNO: " ERRNO ;
                          print "comm: " $0;
                          print "resp3: " resp3;
                          gsub( /.*:/, "", resp3);
                          gsub( /}/, "", resp3);
			  if(dbg>0) printf("# %20.9f  re: %21s = %-20s\n", t_new, request, resp3) >> logfile ; 
                          printf("%1.6f\n", resp3); fflush();
			  request="";
			 }



/^[^_]*_last_communication_time$/    { request=$0; sensor_group=1; }
/^[^_]*_instant_power$/  	     { request=$0; sensor_group=1; }
/^[^_]*_energy_exported$/	     { request=$0; sensor_group=1; }
/^[^_]*_energy_imported$/	     { request=$0; sensor_group=1; }
/^[^_]*_frequency$/		     { request=$0; sensor_group=1; }

/^sensor.\/L._v$/        { request=$0;}
/^sensor.\/L._p$/        { request=$0;} 
/^sensor.\/L._q$/        { request=$0;} 
/^sensor.\/L._eExp$/     { request=$0;} 
/^sensor.\/L._eImp$/     { request=$0;}
/^sensor.\/L./	       { if( request != "" ) {
                            sensor_group=3;  # flag
                          }
                        }

			# -------- process the latest request -------------
  
		        { 
			  # --------------- update responses -----------------
			  
			  if(sensor_group==1) {
			    if( (dt1 = t_new - t_old1) >= 0.5 || resp1 == "" ) {	    # limit polling rate for group 1
			      if(dbg>0) { print "  dt1: " dt1 >> logfile };
			      t_old1=t_new;
			      cmd1 | getline resp1 ;	# get https resp1
                              close(cmd1);
			    }
			  }

			  if(sensor_group==2) {
			    if( (dt2 =  t_new - t_old2) >= 0.5 || resp2 == "" ) {	     # limit polling rate for group 2
			      if(dbg>0) { print "  dt2: " dt2 >> logfile };
			      t_old2=t_new;
			      cmd2 | getline resp2 ;	# get https resp2
                              close(cmd2);
			    }
			  }
			    
			  if(sensor_group==3) {
			    if( (dt3 =  t_new - t_old3) >= 0.5 || resp3 == "" ) {	     # limit polling rate for group 2
			      if(dbg>0) { print "  dt3: " dt3 >> logfile };
			      t_old3=t_new;
			      for( retry =2; retry>0 ; retry--) {
			  	cmd3 | getline tmp3 ;
                          	close(cmd3);
			        # bullshit: sporadic errors, when reading the sensors. Workaround:
			        ierr=match(tmp3, "error\":\"[^\"]");   # break, if error: is empty
			        if( ierr == 0) break;			     
			        if(dbg>0) print "  retry " ierr " ERRNO: " ERRNO >> logfile  
			        if(dbg>1) print tmp3   >> logfile
			      }
			      if(retry>0) resp3=tmp3;	      # use the new response
			    }
			  }
			  
			  # --------------- process responses -----------------
			  
			  if (sensor_group==3) {	  # evaluate resp3 
                            split(request, sns, "[/_]");
			    #print sns[1] " " sns[2] " " sns[3]
			    # etract atoms
			    gsub( "sensor", "", sns[1]);
			    gsub( "L", "",	sns[2]);
			    gsub( "$", "_",	sns[3]);  # append _

			    #re0=resp3; gsub("}", "}\n", re0); gsub("\\[", "\n[", re0); print re0;
			    k2="notUsedHere"
			    split(resp3, re1, "cts.:")
			    re2=re1[sns[1]+1]	# pick sensor1/2
			    split(re2, re3, "ct.:")
			    re4=re3[sns[2]+1]	# pick L1/2/3/4
			    gsub("}.*","", re4) # cut the tail
			    # extract the value immediately after the key
			    gsub(".*,." sns[3] "[^:]*:", "", re4)  # pick and delete key
			    gsub(",.*" , "", re4)     # delete following fields
			    result=re4*1.0
			    #if(dbg>0) printf("# %20.9f  re: %s = %s\n", t_new, sns[3], result) >> logfile ;
			    
			    # postprocess, convert result
			    if( sns[3] ~ /e[EI]../ ) {
			      result=re4/3.6e6;  # convert energy unit to kWh
			    }
			    if( sns[3] ~ /v_$/ && result<0.1) {
			      result=222.22222;    # dirty workaround: not clear, why we read sometimes 0
			      resp3=""; 	   # force a re-read of sensors at the next request
			    }
			  }
			  
			  if (sensor_group==2) {			 # process battery_charge
			    result=resp2;
                            gsub( /.*:/, "", result);
                            gsub( /}/, "", result);
			    #printf("# %20.9f  battery: %s : %s\n", t_new, resp2, result) >> logfile ;
			  }
			  
			  if (sensor_group==1) {			 # process aggregates
			    k1=request;
			    k2=request;
			    gsub( /_.*/, "", k1);   # get first token from key, the keyglo part
			    gsub( k1 "_", "", k2);  # get second part, the keysub part
			    # find matching k1 and k2 in json message, eat up response from the left
			    i1 = match(resp1, k1 ".:");
			    r1=substr(resp1, i1);
			    i2 = match(r1, k2 ".:");
			    r2=substr(r1, i2);
			    #print i1 " " i2 ;
			    #print r2;
			    split(r2, r3, /.:/, seps);
			    #print r3[1]
			    #print r3[2]
			    #print r3[3]
			    result=r3[2];
			    gsub(/,.*/, "", result);
			    if(( k2 ~ /frequency/ ) && ( result < 49.01 )) result = 49.01;  # workaround persistent autoscale of ksysguard 
			  }
			  
			  if (sensor_group>0) {
                            printf("%1.6f\n", result);
			  }
			
			  
                          # --------------- always output new prompt and flush stdout ---------------
			  printf("ksysguardd> ") ; fflush(); 
			  
			  if(dbg>0) {
			      cmdT | getline t_res;
			      close(cmdT);		 # debug - measure overall respons time
                              printf("# %20.9f  re: %-21s = %-20s \tt_response = %8.3f ms\n", t_res, request, result, (t_res-t_new)*1000) >> logfile ; 
			    }
			  if(dbg>1) print "#  " resp1 "\n"    >> logfile ;   # debug
			  if(dbg>1) print "#  " resp3 "\n"    >> logfile ;   # debug
			  request = ""
			  result = ""
		          sensor_group=0;
			  if(dbg>0) fflush();
			}
