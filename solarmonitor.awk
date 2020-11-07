#!/usr/bin/awk -E
# a ksysguardd to retrieve and report solar sensor data
# https://techbase.kde.org/Development/Tutorials/Sensors
# 127.0.0.1 /home/amerz/demo/solarmonitor.awk

BEGIN		        {printf("ksysguardd 1.2.1\nksysguardd> "); fflush(); 
                         cmd1="wget -q --no-check-certificate -O - http://192.168.2.9/api/meters/aggregates" ;
                         cmd2="wget -q --no-check-certificate -O - http://192.168.2.9/api/system_status/soe" ;
                         PROCINFO["resp", "RETRY"] = 1
			 }
/monitors/	        {print  "battery_charge\tfloat" ;  }
/battery_charge\?/	{print  "Battery charging state\t0\t100" ;  }
/battery_charge$/	{cmd2 | getline resp ; 
                         close(cmd2);
                         #print "ERRNO: " ERRNO ;
                         #print "comm: " $0;
                         #print "resp: " resp;
                         gsub( /.*:/, "", resp);
                         gsub( /}/, "", resp);
                         printf("%1.6f\n", resp); fflush(); }
		        {printf("ksysguardd> ") ; fflush(); }
