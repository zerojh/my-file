#!/bin/sh

global_action=""
global_server=""
global_folder=""
global_username=""
global_password=""
#global_action="on"
#global_server="172.16.100.18"
#global_folder="tmp"
#global_username="zero"
#global_password="1002000"
mount_dst="/mnt/netmount"
log_file="/tmp/netmount_state"

cifs_exist=`mount -t cifs`
ping_server_ret=`ping $global_server -w 5 -c 5 2>/dev/null | wc -l`

if [ -z "$cifs_exist" ] && [ "$global_action" = "on" ]; then
	rm -rf $log_file
	[ "$ping_server_ret" -gt 4 ] && {
		#need to mount
		mount_ret=""

		if [ ! -d "$mount_dst" ]; then
			mkdir -p $mount_dst
		fi

		[ "$global_folder" = "" ] && {
			mount_ret=`mount -t cifs //$global_server $mount_dst -o rw,user=$global_username,pass=$global_password,iocharset=utf8 2>&1`
		} || {
			mount_ret=`mount -t cifs //$global_server/$global_folder $mount_dst -o rw,user=$global_username,pass=$global_password,iocharset=utf8 2>&1`
		}
		[ -z "$mount_ret" ] && mount_ret="success"
		echo "$mount_ret" > $log_file
	} || {
		echo "server error" > $log_file
	}
elif [ ! -z "$cifs_exist" ] && [ "$ping_server_ret" -le 4 ]; then
	#force umount
	rm -rf $log_file

	umount -f $mount_dst&
	sleep 1
	pid_num=`pidof umount`
	if [ ! -z "$pid_num" ]; then
		kill -9 $pid_num
	fi

	[ "$global_action" = "off" ] && {
		echo "normal umount" > $log_file
	} || {
		echo "server error" > $log_file
	}
elif [ ! -z "$cifs_exist" ] && [ "$ping_server_ret" -gt 4 ] && [ "$global_action" = "off" ]; then
	#umount -f $mount_dst
	rm -rf $log_file

	umount -f $mount_dst&
	sleep 1
	pid_num=`pidof umount`
	if [ ! -z "$pid_num" ]; then
		kill -9 $pid_num
	fi
	echo "normal umount" > $log_file
fi
