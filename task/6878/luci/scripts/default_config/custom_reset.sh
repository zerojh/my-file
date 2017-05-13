#!/bin/sh

[ -f "/usr/lib/lua/luci/scripts/default_config/wireless" ] && {
	cp /usr/lib/lua/luci/scripts/default_config/wireless /etc/config/wireless
	ssid="HomeULTERA_`readwifimac | awk -F ':' '{print $4$5$6}' | tr '[a-f]' '[A-F]'`"
	passwd="`echo -n $ssid | md5sum | awk -F '' '{print$1$3$5$7$9$11$13$15}' | tr '[a-f]' '[A-F]'`"
	uci set wireless.wifi0.ssid=$ssid
	uci set wireless.wifi0.key=$passwd
	uci commit wireless
}
