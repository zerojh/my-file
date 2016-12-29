#!/bin/sh
. /lib/netifd/netifd-wireless.sh
. /lib/functions.sh
init_wireless_driver "$@"

dat_file=/etc/Wireless/RT2860/RT2860.dat
sta_file=/etc/Wireless/RT2860/RT2860_STA.dat 
ap_file=/etc/Wireless/RT2860/RT2860_AP.dat 
mode_file=/etc/modules.d/36-rt2860v2-ap 

oldup=""

nvram_get() {
	local var=$2
	local val

	if [ "$#" -lt "2" ]; then
		return
	fi
	val=`cat $dat_file | grep -e "^$var="`
	val=${val##*=}
	echo $val
}

nvram_set() {
	if [ "$#" -lt "3" ]; then
		return
	fi
	sed -i "s/^$2=.*/$2=$3/" $dat_file
}

find_phy() {
	[ -n "$phy" -a -d /sys/class/net/$phy ] && return 0
	return 1
}

drv_mt7620a_init_device_config() {
	#echo "drv_mt7620a_init_device_config" >> /tmp/aaaaaa
	config_add_string path phy 'macaddr:macaddr'
	config_add_string hwmode htmode wdsmode wps
	config_add_int beacon_int chanbw frag rts channel
	config_add_int rxantenna txantenna antenna_gain txpower distance
	config_add_boolean noscan
	config_add_array ht_capab
	config_add_boolean \
		rxldpc \
		short_gi_80 \
		short_gi_160 \
		tx_stbc_2by1 \
		su_beamformer \
		su_beamformee \
		mu_beamformer \
		mu_beamformee \
		vht_txop_ps \
		htc_vht \
		rx_antenna_pattern \
		tx_antenna_pattern \
		isolate
	config_add_int vht_max_a_mpdu_len_exp vht_max_mpdu vht_link_adapt vht160 rx_stbc tx_stbc
	config_add_boolean \
		ldpc \
		greenfield \
		short_gi_20 \
		short_gi_40 \
		dsss_cck_40
}

drv_mt7620a_init_iface_config() {
	#echo "drv_mt7620a_init_iface_config" >> /tmp/aaaaaa
	config_add_string 'bssid:macaddr' 'ssid:string'
	config_add_boolean wmm hidden
	config_add_int maxassoc max_inactivity
	config_add_boolean disassoc_low_ack isolate short_preamble
	config_add_int \
		wep_rekey eap_reauth_period \
		wpa_group_rekey wpa_pair_rekey wpa_master_rekey
	config_add_boolean rsn_preauth auth_cache
	config_add_string wdspeermac wdsencryptype wdskey wdsphymode
	config_add_string 'auth_server:host' 'server:host'
	config_add_string auth_secret
	config_add_int 'auth_port:port' 'port:port'

	config_add_string 'macaddr:macaddr' ifname
	config_add_string device
	config_add_boolean wds powersave
	config_add_int maxassoc
	config_add_int max_listen_int
	config_add_int dtim_period

	# mesh
	config_add_string mesh_id
	config_add_int $MP_CONFIG_INT
	config_add_boolean $MP_CONFIG_BOOL
	config_add_string $MP_CONFIG_STRING
}

list_phy_interfaces() {
	#echo "list_phy_interfaces" >> /tmp/aaaaaa
	local phy="$1"

	if [ -d "/sys/class/net/${phy}" ]; then
		echo "${phy} " 2> /dev/null
	fi
}

mt7620a_interface_cleanup() {
	#echo "list_phy_interfaces" >> /tmp/aaaaaa
	local phy="$1"

	for wdev in $(list_phy_interfaces "$phy"); do
		ifconfig "$wdev" down 2>/dev/null
		#echo "ifconfig $wdev down" > /dev/console
	done
}

mt7620a_interface_up() {
	#echo "mt7620a_interface_up" >> /tmp/aaaaaa
	local phy="$1"

	for wdev in $(list_phy_interfaces "$phy"); do
		ifconfig "$wdev" up 2>/dev/null
	done
}

mt7620a_interface_cleanup_all() {
	#echo "mt7620a_interface_cleanup_all" >> /tmp/aaaaaa
	mt7620a_interface_cleanup "ra0"
	mt7620a_interface_cleanup "ra1"
	mt7620a_interface_cleanup "ra2"
	mt7620a_interface_cleanup "ra3"
	mt7620a_interface_cleanup "wds0"
	mt7620a_interface_cleanup "wds1"
	mt7620a_interface_cleanup "wds2"
	mt7620a_interface_cleanup "wds3"
}

mt7620a_interface_up_all() {
	#echo "mt7620a_interface_up_all" >> /tmp/aaaaaa
	local start
	local end

	start=0
	end=$(($1+1))
	while [[ $start != $end ]]
	do
		mt7620a_interface_up "ra$start"
		start=$((start+1))
	done
}

check_and_update() {
	#echo "check_and_update" >> /tmp/aaaaaa
	local nv_var="$1"
	local val="$2"
	[ -n "$val" ] && {
		local inter_val=`nvram_get 2860 $nv_var`
		[ "$val" = "$inter_val" ] || {
			nvram_set 2860 $nv_var $val
		}
	}
}

update_var_offset() {
	#echo "update_var_offset" >> /tmp/aaaaaa
	local nv_var="$1"
	local offset=$2
	local val="$3"
	local oldval0=""
	local oldval1=""
	local oldval2=""
	local oldval3=""
	local inter_val=""
	local ch=""
	local index=0
	local i=""


	#echo "nv_var $nv_var" > /dev/console
	inter_val=`nvram_get 2860 $nv_var`
	#echo "inter_val $inter_val" > /dev/console
	for i in `seq ${#inter_val}`
	do
		#echo "i $i" > /dev/console
		ch=${inter_val:$((i-1)):1}
		#echo "ch $ch" > /dev/console
		if [ "$ch" = ";" ]; then
			index=$((index+1))
		else
			case $index in
				0)
					oldval0="${oldval0}${ch}"
					;;
				1)
					oldval1="${oldval1}${ch}"
					;;
				2)
					oldval2="${oldval2}${ch}"
					;;
				3)
					oldval3="${oldval3}${ch}"
					;;
			esac
		fi
	done

	#echo "oldval0 $oldval0" > /dev/console
	#echo "oldval1 $oldval1" > /dev/console
	#echo "oldval2 $oldval2" > /dev/console
	#echo "oldval3 $oldval3" > /dev/console

	case $offset in
		0)
			oldval0="$val"
			;;
		1)
			oldval1="$val"
			;;
		2)
			oldval2="$val"
			;;
		3)
			oldval3="$val"
			;;
	esac

	val="${oldval0};${oldval1};${oldval2};${oldval3}"
	check_and_update "$1" "$val"
}

mt7620a_setup_vif() {
	#echo "mt7620a_setup_vif" >> /tmp/aaaaaa
	local name="$1"
	local authmode_val
	local entype_val
	local key_len
	local key_type
	local index=0
	local bssidnum
	local val
	local ifname=""
	local dat_coment
	local mode_coment

	config_load wireless
	config_get mode "wifi0" mode
	mode_coment=`cat $mode_file`

	dat_coment=`cat $dat_file | grep -e "AutoRoaming"`
	if [ "$mode" = "sta" ]; then
		if [ "$mode_coment" = "rt2860v2_ap" ]; then
			echo > $mode_file
			echo "rt2860v2_sta" > $mode_file
		fi
		if [ -z "$dat_coment" ]; then	
			cp $sta_file $dat_file
		fi
	elif [ "$mode" = "ap" ]; then
		if [ "$mode_coment" = "rt2860v2_sta" ]; then
			echo > $mode_file
			echo "rt2860v2_ap" > $mode_file
		fi
		if [ -n "$dat_coment" ]; then	
			cp $ap_file $dat_file
		fi
	fi


	isolate=0
	json_select config
	json_get_vars \
		ssid wmm wds encryption \
		key device isolate wdspeermac wdsencryptype \
		wdskey wdsphymode device ifname 

	[ -n "$ifname" ] || ifname="$device"
	wireless_set_data ifname="$ifname"
	#ifname="$device"
	#echo "ifname $ifname" > /dev/console

	#echo "device $device" > /dev/console
	case $ifname in
		ra0)
			index=0
			;;
		wds0)
			index=0
			;;
		ra1)
			index=1
			;;
		wds1)
			index=1
			;;
		ra2)
			index=2
			;;
		wds2)
			index=2
			;;
		ra3)
			index=3
			;;
		wds3)
			index=3
			;;
	esac

	#mt7620a_interface_cleanup_all
	#mt7620a_interface_cleanup "$ifname"

	ifindex=$((index+1))

	if [ "${ifname:0:2}" = "ra" ]; then
		if [ "$mode" = "sta" ] && [ $index -eq 0 ]; then 
			check_and_update "SSID" "$ssid"	
		else
			check_and_update "SSID$((index+1))" "$ssid"
		fi
		wireless_vif_parse_encryption
		if [ "$wpa" = "2" ] && [ "$auth_type" = "psk" ]; then
			authmode_val=wpa2psk
			if [ "$wpa_pairwise" = "CCMP TKIP" ]; then
				entype_val=tkipaes
			elif [ "$wpa_pairwise" = "CCMP" ]; then
				entype_val=aes
			elif [ "$wpa_pairwise" = "TKIP" ]; then
				entype_val=tkip
			fi
			if [ "$mode" = "sta" ] && [ $index -eq 0 ]; then
				check_and_update "WPAPSK" "$key"
			else
				check_and_update "WPAPSK${ifindex}" "$key"
			fi

		elif [ "$wpa" = "1" ] && [ "$auth_type" = "psk" ]; then
			authmode_val=wpapsk
			if [ "$wpa_pairwise" = "CCMP TKIP" ]; then
				entype_val=tkipaes
			elif [ "$wpa_pairwise" = "CCMP" ]; then
				entype_val=aes
			elif [ "$wpa_pairwise" = "TKIP" ]; then
				entype_val=tkip
			fi
			if [ "$mode" = "sta" ] && [ $index -eq 0 ]; then
				check_and_update "WPAPSK" "$key"
			else
				check_and_update "WPAPSK${ifindex}" "$key"
			fi
		elif [ "$wpa" = "3" ]; then
			authmode_val=wpapskwpa2psk
			if [ "$wpa_pairwise" = "CCMP TKIP" ]; then
				entype_val=tkipaes
			elif [ "$wpa_pairwise" = "CCMP" ]; then
				entype_val=aes
			elif [ "$wpa_pairwise" = "TKIP" ]; then
				entype_val=tkip
			fi
			if [ "$mode" = "sta" ] && [ $index -eq 0 ]; then
				check_and_update  "WPAPSK" "$key"
			else
				check_and_update "WPAPSK${ifindex}" "$key"
			fi
		elif [ "$wpa" = "0" ] && [ "$auth_type" = "wep" ] && [ "$auth_mode_open" = "0" ] && [ "$auth_mode_shared" = "1" ]; then
			authmode_val=shared
			entype_val=wep
			key_len=`expr length $key`
			if [ "$key_len" = "10" ] || [ "$key_len" = "26" ]; then
				key_type=0
				check_and_update "Key${ifindex}Type" "$key_type"
			elif [ "$key_len" = "5" ] || [ "$key_len" = "13" ]; then
				key_type=1
				check_and_update "Key${ifindex}Type" "$key_type"
			fi
			check_and_update "Key${ifindex}Str1" "$key"

		elif [ "$wpa" = "0" ] && [ "$auth_type" = "wep" ]; then
			authmode_val=wepauto
			entype_val=wep
			if [ "$key_len" = "10" ] || [ "$key_len" = "26" ]; then
				key_type=0
				check_and_update "Key${ifindex}Type" "$key_type"
			elif [ "$key_len" = "5" ] || [ "$key_len" = "13" ]; then
				key_type=1
				check_and_update "Key${ifindex}Type" "$key_type"
			fi
			check_and_update "Key${ifindex}Str1" "$key"
		else
			authmode_val=open
			entype_val=none
		fi
		if [ "$mode" = "sta" ] && [ $index -eq 0 ]; then

			check_and_update "AuthMode" "${authmode_val}"
			check_and_update "EncrypType" "${entype_val}"
			check_and_update "WmmCapable" "${wmm}"
			check_and_update "NoForwarding"  "${isolate}"

		else
			update_var_offset "AuthMode" $index "${authmode_val}"
			update_var_offset "EncrypType" $index "${entype_val}"
			update_var_offset "WmmCapable" $index "${wmm}"
			update_var_offset "NoForwarding" $index "${isolate}"
		fi
		#check_and_update "BssidNum" "$ifindex"
		check_and_update "CountryCode" "$country" 
	fi

	if [ "${ifname:0:3}" = "wds" ]; then
		update_var_offset "WdsList" $index "${wdspeermac}"
		update_var_offset "WdsEncrypType" $index "${wdsencryptype}"
		update_var_offset "WdsPhyMode" $index "${wdsphymode}"

		check_and_update "Wds${index}Key" "$wdskey"
	fi

	#mt7620a_interface_up_all "$1"
	mt7620a_interface_up "$ifname"
	#echo "network_bridge $network_bridge" > /dev/console
	#[ -n "$network_bridge" ] && {
	#	echo "brctl addif $network_bridge $device" > /dev/console
	#        brctl addif $network_bridge "$device"
	#}

	json_select ..
	#echo "name $name ifname $ifname" > /dev/console
	wireless_add_vif "$name" "$ifname"
	allif="$allif $ifname"
}

drv_mt7620a_setup() {
	#echo "drv_mt7620a_setup" >> /tmp/aaaaaa
	local j
	allif=""
	local LOCKFILE="/tmp/.wifi_lock"

	[ ! -e $LOCKFILE ] && touch $LOCKFILE
	exec 7<>$LOCKFILE
	flock 7

	json_select config
	json_get_vars \
		phy macaddr path htmode channel \
		country chanbw distance \
		txpower antenna_gain \
		rxantenna txantenna \
		frag rts beacon_int hwmode ssid \
		isolate wdsmode wps
	json_get_values basic_rate_list basic_rate
	json_select ..

	#find_phy || {
	#	echo "Could not find PHY for device '$1'"
	#	wireless_set_retry 0
	#	return 1
	#}

	#mt7620a_interface_cleanup "$phy"
	#echo "var 1 $1" > /dev/console

	#if [ "$1" = "ra0" ]; then

	check_and_update "CountryCode" "$country"
	check_and_update "TxPower" "$txpower"
	if [ "$channel" = "0" ] || [ "$channel" = "auto" ]; then
		check_and_update "AutoChannelSelect" "1"
	else
		check_and_update "AutoChannelSelect" "0"
		check_and_update "Channel" "$channel"
	fi
	check_and_update "NoForwardingBTNBSSID" "$isolate"
	if [ "$htmode" = "HT40" ]; then
		check_and_update "HT_BW" "1"
		check_and_update "HT_BSSCoexistence" "0"
	elif [ "$htmode" = "HT20/HT40" ]; then
		check_and_update "HT_BW" "1"
		check_and_update "HT_BSSCoexistence" "1"
	else
		check_and_update "HT_BW" "0"
	fi

	if [ "$wdsmode" = "disable" ]; then
		check_and_update "WdsEnable" "0"
	elif [ "$wdsmode" = "bridge" ]; then
		check_and_update "WdsEnable" "2"
	elif [ "$wdsmode" = "repeater" ]; then
		check_and_update "WdsEnable" "3"
	elif [ "$wdsmode" = "lazy" ]; then
		check_and_update "WdsEnable" "4"
	fi

	if [ "$wps" = "on" ]; then
		check_and_update "WscConfMode" "7"
	elif [ "$wps" = "off" ]; then
		check_and_update "WscConfMode" "0"
	fi

	if [ "$hwmode" = "11bg" ]; then
		check_and_update "WirelessMode" "0"
	elif [ "$hwmode" = "11b" ]; then
		check_and_update "WirelessMode" "1"
	elif [ "$hwmode" = "11a" ]; then
		check_and_update "WirelessMode" "2"
	elif [ "$hwmode" = "11abg" ]; then
		check_and_update "WirelessMode" "3"
	elif [ "$hwmode" = "11g" ]; then
		check_and_update "WirelessMode" "4"
	elif [ "$hwmode" = "11abgn" ]; then
		check_and_update "WirelessMode" "5"
	elif [ "$hwmode" = "11n" ]; then
		check_and_update "WirelessMode" "6"
	elif [ "$hwmode" = "11gn" ]; then
		check_and_update "WirelessMode" "7"
	elif [ "$hwmode" = "11an" ]; then
		check_and_update "WirelessMode" "8"
	elif [ "$hwmode" = "11bgn" ]; then
		check_and_update "WirelessMode" "9"
	elif [ "$hwmode" = "11agn" ]; then
		check_and_update "WirelessMode" "10"
	else
		check_and_update "WirelessMode" "9"
	fi
	#fi

	#check_and_update "BssidNum" "0"

	#mt7620a_interface_cleanup_all
	#mt7620a_interface_cleanup "$1"
	for_each_interface "ap sta adhoc mesh monitor" mt7620a_setup_vif

	config_load network
	config_get proto "wan" proto 
	[ "$mode" = "sta" ] && [ "$proto" = "static" ] || mt7620a_interface_cleanup_all
	#	oldup=`cat /tmp/oldwifiupif`
	for i in $allif
	do
		[ "$mode" = "sta" ]  && [ "$proto" = "static" ] || mt7620a_interface_up "$i"
#		echo "i $i" > /dev/console
#		if [ -z "${oldup}"] || [ "${oldup%$i*}" = "${oldup}" ]; then
#			oldup="$oldup $i"
#		fi
	done
	wireless_set_up
	#	echo "$oldup" > /tmp/oldwifiupif
	flock -u 7
}

drv_mt7620a_teardown() {
#echo "drv_mt7620a_teardown" >> /tmp/aaaaaa
#	local LOCKFILE="/tmp/.wifi_lock"
#	local olduppre=""
#	local olduppost=""
#	local ifname

#        [ ! -e $LOCKFILE ] && touch $LOCKFILE
#        exec 7<>$LOCKFILE
#        flock 7

	mt7620a_interface_cleanup "$1"
#	echo "drv_mt7620a_teardown $1" > /dev/console
#	oldup=`cat /tmp/oldwifiupif`
#	if [ -n "${oldup}" ] && [ "${oldup%$1*}" != "${oldup}" ]; then
#		olduppre="${oldup%%$1*}"
#		olduppost="${oldup##*$1}"
#		oldup="${olduppre} ${olduppost}"
#		echo "$oldup" > /tmp/oldwifiupif
#	fi

#	flock -u 7
}

#echo "add_driver" >> /tmp/aaaaaa
add_driver mt7620a
