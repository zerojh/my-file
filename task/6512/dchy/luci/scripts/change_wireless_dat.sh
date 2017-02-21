#!/bin/sh

. /lib/functions.sh

dat_file=/etc/Wireless/RT2860/RT2860.dat
sta_file=/etc/Wireless/RT2860/RT2860_STA.dat 
ap_file=/etc/Wireless/RT2860/RT2860_AP.dat 
mode_file=/etc/modules.d/36-rt2860v2-ap 

local mode_coment=`cat $mode_file`
local dat_coment=`cat $dat_file | grep -e "AutoRoaming"`
config_load wireless
config_get mode "wifi0" mode
if [ "$mode" = "sta" ]; then
	if [ "$mode_coment" = "rt2860v2_ap" ]; then
		echo > $mode_file
		echo "rt2860v2_sta" > $mode_file
	fi
	if [ -z "$dat_coment" ]; then
		cp $sta_file $dat_file
	fi
else
	if [ "$mode_coment" = "rt2860v2_sta" ]; then
		echo > $mode_file
		echo "rt2860v2_ap" > $mode_file
	fi
	if [ -n "$dat_coment" ]; then
		cp $ap_file $dat_file
	fi
fi
