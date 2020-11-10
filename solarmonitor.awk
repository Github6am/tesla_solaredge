#!/usr/bin/awk -E
# File: solarmonitor.awk
#
# Purpose: a ksysguardd to retrieve and report solar sensor data
#
# Usage Example:
#   ksysguard # Neues Arbeitsblatt, Entfernten Rechner ueberwachen -> Name der Quelle, Befehl 
#   ls -ltr /home/amerz/.local/share/ksysguard  # new sgrd file occurs, if not saved
#   vi /home/amerz/.config/ksysguardrc   # set active sheets and other stuff    
#
#   echo monitors | ./solarmonitor.awk
#
# Background:
#   - Since ksysguard has a nice display of live performance data, 
#     I wanted to use it to monitor my photovoltaic system
#   - https://techbase.kde.org/Development/Tutorials/Sensors
#   - TODO: time is not processed yet.
#   - this is the kind of telegram we want to parse:
#     {"site":{"last_communication_time":"2020-11-07T18:03:17.689290067+01:00","instant_power":1307.253238916397,"instant_reactive_power":774.6698570251465,"instant_apparent_power":1519.5474385621437,"frequency":49.99971389770508,"energy_exported":11629334.309208203,"energy_imported":3029011.8005970903,"instant_average_voltage":217.46618143717447,"instant_total_current":0,"i_a_current":0,"i_b_current":0,"i_c_current":0,"timeout":1500000000},"battery":{"last_communication_time":"2020-11-07T18:03:17.690092061+01:00","instant_power":0,"instant_reactive_power":0,"instant_apparent_power":0,"frequency":49.992000000000004,"energy_exported":3256440,"energy_imported":3889760,"instant_average_voltage":217.4,"instant_total_current":0,"i_a_current":0,"i_b_current":0,"i_c_current":0,"timeout":1500000000},"load":{"last_communication_time":"2020-11-07T18:03:17.689290067+01:00","instant_power":1320.3204550697542,"instant_reactive_power":812.0530246793107,"instant_apparent_power":1550.0568437855495,"frequency":49.99971389770508,"energy_exported":0,"energy_imported":10389789.47222222,"instant_average_voltage":217.46618143717447,"instant_total_current":6.071382898913834,"i_a_current":0,"i_b_current":0,"i_c_current":0,"timeout":1500000000},"solar":{"last_communication_time":"2020-11-07T18:03:17.689608398+01:00","instant_power":12.455572962760925,"instant_reactive_power":35.099782943725586,"instant_apparent_power":37.244275540374126,"frequency":49.99971389770508,"energy_exported":19623486.929171618,"energy_imported":54.94833828607079,"instant_average_voltage":217.57920837402344,"instant_total_current":0,"i_a_current":0,"i_b_current":0,"i_c_current":0,"timeout":1500000000}}


 BEGIN		        { printf("ksysguardd 1.2.1\nksysguardd> "); fflush(); 
                          cmd1="wget -q --no-check-certificate -O - http://192.168.2.9/api/meters/aggregates" ;
                          cmd2="wget -q --no-check-certificate -O - http://192.168.2.9/api/system_status/soe" ;
                          cmdT="date '+%s.%N'";
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
			  cmdT | getline t_old;
			  close(cmdT);
			  
			  # logging / debugging
			  dbg=0;
			  logfile="/tmp/solarmonitor.log"
			  if(dbg>0) printf("%d: BEGIN\n", t_old) > logfile ;  # debug
			}
/monitors/	        {
                          print  monitors ; 
                        }
/developer_code/        { # create linear source code for this program, which is easier to read than sophisticated loops
                          for (k in glob_kg)
			    for (s in glob_ks ) {
			      key=glob_kg[k] "_" glob_ks[s];
			      printf("%-36s { print \"%s %s\\t0\\t0\\t%s\" }\n", "/" key "\\?/" ,glob_kg[k],glob_ks[s],glob_vu[s]);
			    }
                        }
/json$/	                { # test command
                          cmd1 | getline resp1 ; 
                          close(cmd1);
                          printf("%s\n", resp1); fflush(); 
			}
			 
			{
			  cmdT | getline t_new;        # we use this, to limit the rate of new wget request
			  close(cmdT);
			  if(dbg>0) print "# " t_new " cmd: " $0    >> logfile ;   # debug
			}
			 
/^battery_charge\?/	             { print "Battery charging state\t0\t100\t%" } 
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

/^battery_charge$/	 {request=$0;
			  cmd2 | getline resp ; 
                          close(cmd2);
                          #print "ERRNO: " ERRNO ;
                          #print "comm: " $0;
                          #print "resp: " resp;
                          gsub( /.*:/, "", resp);
                          gsub( /}/, "", resp);
			  if(dbg>0) printf("# %20.9f  re: %s = %s\n", t_new, request, resp) >> logfile ; 
                          printf("%1.6f\n", resp); fflush();
			  request="";
			 }

/^site_last_communication_time$/     { request=$0;}
/^site_instant_power$/  	     { request=$0;}
/^site_energy_exported$/	     { request=$0;}
/^site_energy_imported$/	     { request=$0;}
/^site_frequency$/		     { request=$0;}
/^battery_last_communication_time$/  { request=$0;}
/^battery_instant_power$/	     { request=$0;}
/^battery_energy_exported$/	     { request=$0;}
/^battery_energy_imported$/	     { request=$0;}
/^battery_frequency$/		     { request=$0;}
/^load_last_communication_time$/     { request=$0;}
/^load_instant_power$/  	     { request=$0;}
/^load_energy_exported$/	     { request=$0;}
/^load_energy_imported$/	     { request=$0;}
/^load_frequency$/		     { request=$0;}
/^solar_last_communication_time$/    { request=$0;}
/^solar_instant_power$/ 	     { request=$0;}
/^solar_energy_exported$/	     { request=$0;}
/^solar_energy_imported$/	     { request=$0;}
/^solar_frequency$/		     { request=$0;}

		        { 
			  if( request != "" ) {
			    k1=request;
			    k2=request;
			    gsub( /_.*/, "", k1);   # get first token from key, the keyglo part
			    gsub( k1 "_", "", k2);  # get second part, the keysub part
			    if( t_new - t_old >= 0.5 || resp1 == "" ) {
			      #print "delta t: " t_new - t_old ;
			      t_old=t_new;
                              cmd1 | getline resp1 ; 
                              close(cmd1);
                              #print "ERRNO: " ERRNO ;
                              #print "request: " request;
                              #print "resp1: " resp1;
			    }
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
			    if(dbg>0) printf("# %20.9f  re: %s = %s\n", t_new, request, result) >> logfile ; 
                            printf("%1.6f\n", result);
			    request = "";
			  }
			}
			
                        { # always output new promt and flush stdout
			  printf("ksysguardd> ") ; fflush(); 
			  if(dbg>1) print "#  " resp1 "\n"    >> logfile ;   # debug
			  request = ""
			}
