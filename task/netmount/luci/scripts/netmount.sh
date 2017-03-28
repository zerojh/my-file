#!/bin/sh

global_action="on"
global_server="172.16.100.18"
global_folder="tmp"
global_username="zero"
global_password="1002000"
local_dir="/mnt/netmount"
log_file="/tmp/netmount_state"

if [ ! -d "$local_dir" ]; then
	mkdir -p $local_dir
fi

cifs_exist=`mount -t cifs`
ping_server_ret=`ping $global_server -w 5 -c 5 2>/dev/null | wc -l`

if [ "$cifs_exist" = "" ] && [ "$ping_server_ret" -gt 4 ] && [ "$global_action" = "on" ]; then
	#need to mount
	[ "$global_folder" = "" ] && {
		mount -t cifs //$global_server $local_dir -o rw,user=$global_username,pass=$global_password,iocharset=utf8 1>$log_file 2>&1
	} || {
		mount -t cifs //$global_server/$global_folder $local_dir -o rw,user=$global_username,pass=$global_password,iocharset=utf8 1>$log_file 2>&1
	}
elif [ "$cifs_exist" != "" ] && [ "$ping_server_ret" -le 4 ]; then
	#force umount
	umount -f $local_dir&
fi
