#!/bin/sh
if [ "bluewave" != "`uci get oem.general.brand -q`" ]; then
	#if before is bluewave ver, and upgrade to dinstar to others ver, when reset, remove file blongs to previous bluewave
	cp /rom/bin/network_watch /bin/network_watch
	cp /rom/bin/restore_default /bin/restore_default
	rm /usr/lib/lua/luci/scripts/default_config/endpoint_sipphone
	rm /usr/lib/lua/luci/scripts/default_config/endpoint_ringgroup
	rm /www/luci-static/resources/bluewave_logo.png
	rm /usr/lib/lua/luci/scripts/default_config/custom_reset.sh
	exit 0
fi
reset_param=$1
if [ -z $reset_param ] || [ "${reset_param%%system*}" != "$reset_param" ] || [ "tr069" == "$reset_param" ]; then
	cp /usr/lib/lua/luci/scripts/default_config/system /etc/config

	uci set system.telnet.action=off
	uci commit system

	uci set telnet.telnet.action=off
	uci commit telnet

	if [ "tr069" != "$reset_param" ]; then
		uci set easycwmp.acs.enable=1
		uci set easycwmp.acs.url="http://j42-tr069.bwddns.net:80/tr069"
		uci set easycwmp.acs.periodic_interval=302
		uci commit easycwmp
	fi
fi

if [ -z $reset_param ] || [ "${reset_param%%service*}" != "$reset_param" ] || [ "tr069" == "$reset_param" ]; then
	cp /usr/lib/lua/luci/scripts/default_config/endpoint_sipphone /etc/config
	local mac=`readmac | awk -F: '{print $4$5$6}' | tr '[a-f]' '[A-F]'`
	uci set endpoint_sipphone.@sip[0].password="Wavephone$mac"
	uci commit endpoint_sipphone
	cp /usr/lib/lua/luci/scripts/default_config/endpoint_ringgroup /etc/config
	cp /usr/lib/lua/luci/scripts/default_config/route /etc/config
fi

sh /usr/lib/lua/luci/scripts/change_wireless_dat.sh
