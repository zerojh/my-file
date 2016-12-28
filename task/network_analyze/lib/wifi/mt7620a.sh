#!/bin/sh
append DRIVERS "mt7620a"

mt7620a_eeprom_die() {
	echo "mt7620a eeprom: " "$*"
	return 1
}

mt7620a_eeprom_extract() {
	local part=$1
	local offset=$2
	local count=$3
	local mtd

	. /lib/functions.sh
	mtd=$(find_mtd_part $part)
	[ -n "$mtd" ] || \
		mt7620a_eeprom_die "no mtd device found for partition $part"

	dd if=$mtd of=/lib/firmware/soc_wmac.eeprom bs=1 skip=$offset count=$count 2>/dev/null || \
		mt7620a_eeprom_die "failed to extract from $mtd"

	#cp /lib/firmware/soc_wmac.eeprom /tmp/RT30xxEEPROM.bin
}

load_wifi_firmware() {
	local FW=""
	FW="/lib/firmware/soc_wmac.eeprom"
	if [ -e "$FW" ]; then
		broadcastwatch --fixwifimac 2>&1 > /dev/null
		#cp $FW /tmp/RT30xxEEPROM.bin
		return 0
	fi
	#[ -e "$FW" ] && [ cp $FW /tmp/RT30xxEEPROM.bin ] && return 0
	
	mt7620a_eeprom_extract "Factory" 0 512
}

detect_mt7620a() {
	local macaddr
	local myssid

	load_wifi_firmware

	devidx=0
	config_load wireless
	while :; do
		config_get type "ra$devidx" type
		[ -n "$type" ] || break
		devidx=$(($devidx + 1))
	done

	for _dev in /sys/class/net/*; do
		[ -e "$_dev" ] || continue

		dev="${_dev##*/}"
		if [ "$dev" != "ra$devidx" ]; then
			continue
		fi

		#found=0
		#config_foreach check_mt7620a_device wifi-device
		#[ "$found" -gt 0 ] && continue

		mode_band="bgn"
		channel="11"
		htmode=""
		ht_capab=""

		macaddr=$(readwifimac)
		if [ -z "$macaddr" ]; then
			macaddr=$(cat /sys/class/net/ra0/address)
		fi
		myssid=${macaddr//:/}
		myssid=${myssid:6}

		cat <<EOF
config wifi-device  ra$devidx
	option type     mt7620a
	option channel  ${channel}
	option hwmode   11${mode_band}
	option htmode HT20/HT40
	option isolate 0
	option txpower 50
	option wdsmode disable
	option wps     off
	# REMOVE THIS LINE TO ENABLE WIFI:
	option disabled 0

config wifi-iface wifi0
	option device   ra$devidx
	option ifname	ra$devidx
	option index	1
	option network  lan
	option mode     ap
	option wmm      0
	option isolate  0
	option ssid     domain_$myssid
	option encryption none
EOF
	devidx=$(($devidx + 1))	
	done
		
}
