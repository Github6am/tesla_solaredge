#!/bin/bash
# teslogin.sh
# 
# Purpose: 
#   set new cookie and return tesla powerwall gateway ip adress
#
# Usage:
#   teslogin.sh [cookiefile]
#
# Usage examples:
#   teslogin.sh /tmp/powerwall_cookie.txt
#
# Background:
#   - contains all local access parameters, thus needs editing.
#   - if used by teslogger.sh or solarmonitor.awk, then edit and
#     copy this file to a location in your PATH, e.g. to ~/bin
#     or /usr/local/bin
#   - see also https://github.com/vloschiavo/powerwall2.git
#
# Author: 
#   Andreas Merz, 2021, GPL3

# Tesla Powerwall Gateway access credentials
ip=192.168.2.9
cookie=/tmp/teslogin_cookie.txt   # where to store the cookie
username="customer"
email="powerwall@mydomain"
passw="powerwall-password"
wgetopts="--quiet"
authopts="--no-check-certificate --keep-session-cookies"

if [ "$1" != "" ] ; then
  cookie=$1
fi

# for now, we keep the last file for investigation purposes..
if [ -f $cookie ] ; then
  mv $cookie $cookie.old
fi
wget $wgetopts $authopts --save-cookies $cookie -O /dev/null \
     --header="Content-Type: application/json" \
     --post-data="{\"username\":\"$username\",\"password\":\"$passw\", \"email\":\"$email\",\"force_sm_off\":false}" "https://$ip/api/login/Basic"

if [ $? -eq 200 ]; then
	echo "Login failed"
#	exit;
fi

# provide IP adress to caller
echo $ip

