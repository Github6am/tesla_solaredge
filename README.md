# tesla_solaredge

This project is a collection of scripts and tools performing data
logging and analyis of my solar roof PV system with battery storage.
Currently it consists of several more or less related main components:

1. teslogger.sh  
   The logger runs on a Raspberry Pi and collects json messages
   from the Tesla Powerall Gateway via ethernet.

2. tlpower.m  
   The viewer runs on GNU octave and currently can 
   retrieve and visualize logged data on a day-by-day basis.

3. solarmonitor.awk  
   An independent ksysguardd monitor daemon is able to send requests 
   to the Tesla Powerall Gateway and converts and forwards 
   information to the Linux KDE ksysguard system monitor

4. Support files and work in progress


The comment header of each file provides more information on usage and background.

If you consider using this material, some IP adresses need to be patched.  
* The logger host name here is "rapk" or 192.168.2.6  
* The data is retrieved from adress 192.168.2.9  
