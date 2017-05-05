#!/bin/sh

[ -f "/usr/lib/lua/luci/scripts/default_config/wireless" ] && {
	cp /usr/lib/lua/luci/scripts/default_config/wireless /etc/config/wireless
	uci set wireless.wifi0.ssid="HomeULTERA_"`readwifimac | awk -F ':' '{print $4$5$6}' | tr '[a-f]' '[A-F]'`
	uci set wireless.wifi0.key="`readwifimac | tr -d ':' | tr '[a-f]' '[A-F]'`"
	uci commit wireless
}
