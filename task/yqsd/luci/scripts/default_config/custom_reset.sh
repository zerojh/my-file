#!/bin/sh

[ -f "/usr/lib/lua/luci/scripts/default_config/wireless" ] && {
	cp /usr/lib/lua/luci/scripts/default_config/wireless /etc/config/wireless
	ssid="HomeULTERA_`readwifimac | awk -F ':' '{print $4$5$6}' | tr '[a-f]' '[A-F]'`"
	sn="`lua /usr/bin/factory_test_get_license.lua | grep "sn=" | awk -F '=' '{print $2}' | tr '[a-f]' '[A-F]'`"
	passwd="`echo -n $sn | md5sum | awk -F '' '{print$1$3$5$7$9$11$13$15}' | tr '[a-f]' '[A-F]'`"
	uci set wireless.wifi0.ssid=$ssid
	uci set wireless.wifi0.key=$passwd
	uci commit wireless
}

[ -f "/usr/lib/lua/luci/scripts/default_config/endpoint_siptrunk" ] && cp /usr/lib/lua/luci/scripts/default_config/endpoint_siptrunk /etc/config/endpoint_siptrunk

# telnet
[ -f "/etc/config/system" ] && {
	uci -q delete system.main.pwd_date
	uci set system.telnet.action='off'
	uci commit system
}
[ -f "/usr/lib/lua/luci/scripts/default_config/telnet" ] && cp /usr/lib/lua/luci/scripts/default_config/telnet /etc/config/telnet

[ -f "/etc/config/upload_cdr" ] && rm /etc/config/upload_cdr
