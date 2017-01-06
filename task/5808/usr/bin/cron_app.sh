#!/bin/sh

check_app()
{
	local pid;
	local retry;
	local file=$2
	local app=$1

	if [ ! -f $file ]; then
		touch $file
		echo "0" > $file
	fi

	retry=`cat $file`

	pid=`ps -w | grep $app | grep -v grep | awk '{print $1}'`

	logger -p cron.debug "check $app process is exist..."

	if [ -z "$pid" ]; then
		if [ $retry -lt 1 ]; then

			retry=$(($retry + 1))
			logger -p cron.crit "$app is died, now continue to check it..."
			#need restart $app
			echo "$retry" > $file
		else
			#restart system
			logger -p cron.crit "$app is died, , so restart fs and dsp..."
			echo "`date` $app is died, so restart fs and dsp..." >> /etc/coredump.log
			#reboot
			/etc/init.d/dsp stop
			sleep 1
			/etc/init.d/dsp start
			/etc/init.d/freeswitch stop
			sleep 1
			/etc/init.d/freeswitch start
		fi
	else
		if [ $retry -ne 0 ]; then
			echo "0" > $file
		fi
	fi

}

#check dsp, rely on freeswitch. fs discover dsp  abnormal -> check_dsp restart dsp -> fs reinit dsp
check_dsp()
{
	local pid;
	local action;
	local file=$2
	local app=$1
	if [ -f $file ]; then
		action=`cat $file`
		if [ -n "$action" ]; then
			if [ "$action" == "restart dsp" ]; then
				logger -p cron.crit "$app is abnormal, now reboot it..."
				echo "`date` $app is abnormal, so restart dsp..." >> /etc/coredump.log
				#need restart dsp
				/etc/init.d/$app stop
				/etc/init.d/$app start
				echo "reinit dsp">$file
			fi
		fi
	fi
}

check_process()
{
	local pid;
	local name=$1

	pid=`ps -w | grep $name | grep -v grep | awk '{print $1}'`

	logger -p cron.notice "check $name process is exist..."

	if [ -z "$pid" ]; then
			logger -p cron.notice "$name is died, now try to restart it..."
			#need restart
			/etc/init.d/$name stop
			/etc/init.d/$name start
	fi
}

resize_file()
{
	local filename=$1
	local maxsize=$2
	if [ -f $filename ]; then
		local curr_size=`ls -l $filename | awk '{print $5}'`
		if [ $curr_size -gt $maxsize ]; then
			local curr_linenum=`cat $filename | wc -l`
			local del_linenum=`expr $(($curr_linenum*(curr_size-$maxsize*9/10)/curr_size))`
			sed -i "1,${del_linenum}d" $filename
		fi
	fi
}

sync_file()
{
	local src_file=$1
	local dst_file=$2
	if [ -f $dst_file -a ! -f $src_file ]; then
		cp $dst_file $src_file
	elif [ -f $src_file -a ! -f $dst_file ]; then
		cp $src_file $dst_file
	elif [ `ls -l $src_file | awk '{print $5}'` != `ls -l $dst_file | awk '{print $5}'` ]; then
		cp $src_file $dst_file
	fi
}
check_tmp_maxsize_log_dir()
{
	local maxsize=$1
	local log_dir="/tmp/log/$maxsize/"

	if [ -d "$log_dir" ]; then
		local file_list="`ls $log_dir`"
		for i in $file_list 
		do
			if [ -f $log_dir$i ]; then
				resize_file $log_dir$i $(($maxsize*1024))
			fi
		done
	else
		mkdir $log_dir
	fi
}
check_log_file()
{
	if [ -f "/tmp/calltrace_flag" ]; then
		if [ `ls -l /tmp/calltrace.txt | awk '{print $5}'` -gt 2097152 ]; then
			mv /tmp/calltrace.txt /tmp/calltrace0.txt
			killall logread && logread -f > /tmp/calltrace.txt &
		fi
	fi
	if [ -f "/tmp/log/easycwmp_log" ]; then
		if [ `ls -l /tmp/log/easycwmp_log | awk '{print $5}'` -gt 2097152 ]; then
			mv /tmp/log/easycwmp_log /tmp/log/easycwmp_log.0
		fi
	fi
	if [ ! -d /etc/log ]; then
		mkdir /etc/log
	fi
	local logfile_list="weblog clilog pptpc_log l2tpc_log openvpnc_log service_state_log"
	for i in $logfile_list 
	do
		if [ -f "/ramlog/"$i -o -f "/etc/log/"$i ]; then
			resize_file "/ramlog/"$i 262144
			sync_file "/ramlog/"$i "/etc/log/"$i
		fi
	done
	local ramlog_size=`df /dev/ramreserve | tail -n 1 | awk '{print $5}'`
	if [ ${ramlog_size%\%} -gt 90 ]; then
		resize_file /ramlog/log.0 1048576
	fi
	local size_list="2048 1024 512 256"
	for i in $size_list
	do
		check_tmp_maxsize_log_dir $i
	done
}

check_upnpc_service()
{
	if [ -f "/etc/init.d/upnpc" ]; then
		cat /tmp/upnpc_list >> /tmp/upnpc_list_history
		if [ `ls -l /tmp/upnpc_list_history | awk '{print $5}'` -gt 2097152 ]; then
			mv /tmp/upnpc_list_history /tmp/upnpc_list_history.old
		fi
		echo -e "\n>>>>>>>>>`date` check_upnpc_service......<<<<<<<<<\n" > /tmp/upnpc_list
		upnpc -l >> /tmp/upnpc_list
		/etc/init.d/upnpc restart
	fi
}
check_cloud()
{
	[ "1" == `uci get cloud.cloud.enable -q` ] && {
		local pid=`pgrep remoted`
		if [ -z "$pid" ]; then
			/etc/init.d/cloud restart
		fi
		check_process cloud
		}
}
check_ddns()
{
	local ipv4_pid dinstar_pid
	local enabled=`uci get ddns.myddns_ipv4.enabled -q`
	ipv4_pid=`ps -w | grep myddns_ipv4 | grep -v grep | awk '{print $1}'`
	dinstar_pid=`ps -w | grep dinstar_ddns | grep -v grep | awk '{print $1}'`
	if [ "1" == "$enabled" -a -z "$ipv4_pid" -o -z "$dinstar_pid" ]; then
		/etc/init.d/ddns start
	fi
}
check_dhcp_status()
{
	wan_s=`uci get network.wan.proto -c /tmp/config/`
	if [ "$wan_s" == "dhcp" ];then
		wan_gateway=`route | grep eth0.2 | grep default | awk '{print $2}' | head -1`
		w_flag=`ping -w 2 $wan_gateway | wc -l`
		if [ $w_flag -le 4 ]; then
			ubus call network.interface.wan down
			ubus call network.interface.wan up
		fi
	fi

	# Handle lan.
	lan_s=`uci get network.lan.proto -c /tmp/config/`
	if [ "$lan_s" == "dhcp" ];then
		lan_gateway=`route | grep br-lan | grep default | awk '{print $2}' | head -1`
		l_flag=`ping -w 2 $lan_gateway | wc -l`
		if [ $l_flag -le 4 ]; then
			ubus call network.interface.lan down
			ubus call network.interface.lan up
		fi
	fi
}
check_dhcp_lease()
{
	onlinefile="/tmp/dhcp.onlines"
	random=`cat /proc/sys/kernel/random/uuid`
	detectfile="/tmp/dhcp.detecting_"${random:0:8}
	arpfile=`cat /proc/net/arp`
	now=`date +%s`
	touch $detectfile

	# Produce online list file.
	while read line
	do
		line_time=`echo "$line" | awk '{print $1}'`
		if [ $line_time -gt $now ] || [ "0" = $line_time ] ; then
			time_remain="-1"
			if [ "0" != $line_time ]; then
				time_remain=$(($line_time - $now))
			fi
			ip_addr=`echo "$line" | awk '{print $3}'`
			arp=`echo "$arpfile" | grep "\b$ip_addr\b" | grep -v "0x0"`
			if [ "$arp" != "" ]; then
				ping_ret=`ping -w 2 $ip_addr | wc -l`
				if [ $ping_ret -gt 4 ]; then
					echo "$line" Online 1 $time_remain >>$detectfile
				fi
			else
				echo "$line" Offline 0 $time_remain>>$detectfile
			fi
		fi
	done < /tmp/dhcp.leases
	mv $detectfile $onlinefile
}
check_log_file

if [ `awk -F '.' '{ print $1 }' /proc/uptime` -lt 60 ]; then
	exit 0
fi
#upgrade fail, do not check freeswitch and dsp
if [ ! -f /etc/upgrade_flag ]; then
	check_app freeswitch /tmp/checkfs
fi
check_dsp dsp /tmp/checkdsp
check_process lucid
check_upnpc_service
check_cloud
check_ddns
#check_dhcp_status
check_dhcp_lease
