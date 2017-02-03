module("luci.model.network", package.seeall)

local cidr2netmask={
	"128.0.0.0",
	"192.0.0.0",
	"224.0.0.0",
	"240.0.0.0",
	"248.0.0.0",
	"252.0.0.0",
	"254.0.0.0",
	"255.0.0.0",
	"255.128.0.0",
	"255.192.0.0",
	"255.224.0.0",
	"255.240.0.0",
	"255.248.0.0",
	"255.252.0.0",
	"255.254.0.0",
	"255.255.0.0",
	"255.255.128.0",
	"255.255.192.0",
	"255.255.224.0",
	"255.255.240.0",
	"255.255.248.0",
	"255.255.252.0",
	"255.255.254.0",
	"255.255.255.0",
	"255.255.255.128",
	"255.255.255.192",
	"255.255.255.224",
	"255.255.255.240",
	"255.255.255.248",
	"255.255.255.252",
	"255.255.255.254",
	"255.255.255.255",
}
function ubus_get_addr(iname)
	require "ubus"
	local conn = ubus.connect()
	local ret_ipaddr,ret_mask,ret_gateway,ret_dns

	if conn then
		local status = conn:call("network.interface."..iname,"status",{ name = iname})
		if status then
			local t = status['ipv4-address']
			if t then
				local addr = t[1]
				if addr then
					if addr['address'] then
						--@ ipddr
						ret_ipaddr = addr['address'] or "0.0.0.0"
					end
					if addr['mask'] then
						--@ mask
						if addr['mask'] > 0 and addr['mask'] <=32 then
							ret_mask=cidr2netmask[addr['mask']]
						else
							ret_mask="0.0.0.0"
						end
					end
				end
			end

			t = status['route']
			if t then
				for k=1,#t do
					addr = t[k]
					if addr then
						if "0.0.0.0" == addr['target'] then
								--@ gateway 
							ret_gateway = addr['nexthop'] or "0.0.0.0"
						end
					end
				end
			end

			t = status['dns-server']
			if t then
				local val = ""
				
				if type(t) == "table" then
					for i=1,table.getn(t) do
						val = t[i].." "..val
					end
				else
					val = t
				end
				
				--@ dns
				ret_dns = #val>0 and val or "0.0.0.0"
			end
		end
	end

	conn:close()
	return ret_ipaddr or "0.0.0.0",ret_mask or "0.0.0.0",ret_gateway or "0.0.0.0",ret_dns or "0.0.0.0"
end

function dhcp_get_server_status(interface)
	local fs = require "luci.fs"
	local tmp_file 
	local dhcp_dir = "/tmp/dhcp.options."..interface
	local server_ip = "0.0.0.0"
	local lifetime = ""

	if fs.access(dhcp_dir) then
		tmp_file = io.open(dhcp_dir,"r")
	end

	if tmp_file then
		for line in tmp_file:lines() do
			if line:match("^serverid=([0-9.']+)") then
				server_ip = line:match("serverid='([0-9.]+)'")
			end
			if line:match("^lease=([0-9.']+)") then
				lifetime = line:match("^lease='([0-9]+)'") 
			end
		end
	end

	return server_ip,lifetime
end

function get_netstat_detail(raw_info,interface)
	local start_idx = string.find(raw_info,interface)

	if start_idx then
		local end_idx = string.find(raw_info,"\n\n",start_idx)
		local info = string.sub(raw_info,start_idx,end_idx)

		rx_pkt = info:match("RX packets:(%d+)")
		tx_pkt = info:match("TX packets:(%d+)")
		rx_bytes = info:match("RX bytes:(%d+)")
		tx_bytes = info:match("TX bytes:(%d+)")
	else
		rx_pkt = 0
		tx_pkt = 0
		rx_bytes = 0
		tx_bytes = 0
	end

	return rx_pkt,tx_pkt,rx_bytes,tx_bytes
end

function get_netstat(wan,lan,wlan,lte)
	local utl = require "luci.util"
	local s = {wan={},lan={},wlan={},lte={}}
	local tmp = {}

	local raw_info = utl.exec("ifconfig")
	local start_idx,end_idx,info

	if wan then
		if wan.proto and "pppoe" == wan.proto then
			s.wan.rx_pkts,s.wan.tx_pkts,s.wan.rx_bytes,s.wan.tx_bytes = get_netstat_detail(raw_info,"pppoe%-wan");
		else
			s.wan.rx_pkts,s.wan.tx_pkts,s.wan.rx_bytes,s.wan.tx_bytes = get_netstat_detail(raw_info,"eth0.2");
		end
	end

	if lan.proto and "pppoe" == lan.proto then
		s.lan.rx_pkts,s.lan.tx_pkts,s.lan.rx_bytes,s.lan.tx_bytes = get_netstat_detail(raw_info,"pppoe%-lan");
	else
		if wan then
			s.lan.rx_pkts,s.lan.tx_pkts,s.lan.rx_bytes,s.lan.tx_bytes = get_netstat_detail(raw_info,"eth0.1");
		else
			s.lan.rx_pkts,s.lan.tx_pkts,s.lan.rx_bytes,s.lan.tx_bytes = get_netstat_detail(raw_info,"br%-lan");
		end
	end

	if wlan then
		if wlan.drv_str == "rt2860v2_ap" or wlan.drv_str == "rt2860v2_sta" then
			s.wlan.rx_pkts,s.wlan.tx_pkts,s.wlan.rx_bytes,s.wlan.tx_bytes = get_netstat_detail(raw_info,"ra0");
			if wlan.drv_str == "rt2860v2_sta" then
				s.wan = s.wlan
			end
		else
			s.wlan.rx_pkts,s.wlan.tx_pkts,s.wlan.rx_bytes,s.wlan.tx_bytes = get_netstat_detail(raw_info,"wlan0");
		end
	end

	if lte then
		s.lte.rx_pkts,s.lte.tx_pkts,s.lte.rx_bytes,s.lte.tx_bytes = get_netstat_detail(raw_info,"3g%-wan2");
	end

	return s
end

function get_wifi_info()
	local fs = require "luci.fs"
	local utl = require "luci.util"

	local wlan = {}
	local raw_info = ""
	local drv_str = utl.exec("lsmod | sed -n '/^rt2x00/p;/^rt2860v2_ap/p;/^rt2860v2_sta/p;'")
	drv_str = drv_str:match("(rt2860v2_ap)") or drv_str:match("(rt2860v2_sta)") or drv_str:match("(rt2x00)") or ""

	if drv_str == "rt2860v2_ap" or drv_str == "rt2860v2_sta" then
		raw_info = utl.exec("iwinfo ra0 info")
	elseif drv_str == "rt2x00" then
		raw_info = utl.exec("iwinfo")
	end

	wlan.drv_str = drv_str

	wlan.mac_addr = raw_info:match("Access Point:%s+([%w%:]+)")

	if not wlan.mac_addr or (wlan.mac_addr and "00:00:00:00:00:00" == wlan.mac_addr) then
		return nil
	end

	wlan.ssid = raw_info:match("ESSID:%s+%\"*([0-9a-zA-Z%-%.%_]+)\"*")
	wlan.channel = raw_info:match("Channel:%s+(%d+)")
	if drv_str == "rt2860v2_ap" then
		local ra0_info=utl.exec("iwpriv ra0 show stasecinfo | grep BSS\\\(0\\\)")
		wlan.encrypt = ra0_info:match("AuthMode%(%d%)=([0-9A-Z]+),")
	else
		wlan.encrypt = raw_info:match("Encryption:%s+(.+)Type:")
	end

	return wlan
end

function get_pppoe_status(interface)
	local utl = require "luci.util"
	local ifconfig = utl.exec("ifconfig "..interface)
	local ps = utl.exec("ps -w | grep "..interface.." | grep -v grep")
	if #ifconfig > 0 and #ps > 0 then
		return "connected"
	elseif #ifconfig == 0 and #ps > 0 then
		return "connecting"
	elseif #ifconfig == 0 and #ps == 0 then
		return "disconnected"
	else
		return "unknown"
	end
end
function number2ip(param)
	local ret_ip = ""
	local tmp_a = param
	local tmp_b = param
	local index = 0
	
	repeat
		index = index + 1
		tmp_a = tmp_b % 256
		tmp_b = math.floor(tmp_b / 256)
		if index == 1 then
			ret_ip = tmp_a
		else
			ret_ip = tmp_a.."."..ret_ip
		end
	until (tmp_b < 256)

	if index == 1 then
		ret_ip = "0.0."..tmp_b.."."..ret_ip
	elseif index == 2 then
		ret_ip = "0."..tmp_b.."."..ret_ip
	elseif index == 3 then
		ret_ip = tmp_b.."."..ret_ip
	end

	return ret_ip
end

function ip2number(param)
	local ret_number = 0

	if param then
		local param_tb = utl.split(param,".")
		for i=1,4,1 do
			ret_number = ret_number + tonumber(param_tb[i])*(256^(4-i))
		end
	end

	return ret_number
end

function get_dhcp_info()
	local utl = require "luci.util"
	local i18n = require "luci.i18n"
	local dhcp = {}
	local dnsmasq_running_conf=utl.exec("cat /tmp/etc/dnsmasq.conf") or ""

	if "" == dnsmasq_running_conf or string.find(dnsmasq_running_conf,"no%-dhcp%-interface") then
		dhcp.status = tostring(i18n.translate("Disabled"))
		dhcp.startaddr = "-"
		dhcp.endaddr = "-"
		dhcp.expires = "-"
		dhcp.gateway = "-"
		dhcp.dns = "-"
	else
		dhcp.status = tostring(i18n.translate("Enabled"))
		if string.find(dnsmasq_running_conf,"dhcp%-range=lan") then
			dhcp.startaddr, dhcp.endaddr,dhcp.netmask,dhcp.expires=dnsmasq_running_conf:match("dhcp%-range=lan,([0-9%.]+),([0-9%.]+),([0-9%.]+),(%d+)")
			dhcp.gateway=dnsmasq_running_conf:match("dhcp%-option=lan,3,([0-9%.]+)") or "-"
			dhcp.dns=dnsmasq_running_conf:match("dhcp%-option=lan,6,([0-9%.,]+)") or "-"
			dhcp.expires=dhcp.expires.." "..tostring(i18n.translate("Hours"))
		else
			dhcp.startaddr = "-"
			dhcp.endaddr = "-"
			dhcp.expires = "-"
			dhcp.gateway = "-"
			dhcp.dns = "-"
		end
	end
	return dhcp
end

function get_lte_info()
	local utl = require "luci.util"
	local i18n = require "luci.i18n"
	local lte_info = {}

	lte_info.ipaddr,lte_info.netmask,lte_info.gateway,lte_info.dns = ubus_get_addr("wan2")

	local tmp = utl.exec("cat /etc/config/endpoint_mobile | grep lte_mode")
	local config_mode = string.upper(tmp:match("lte_mode '([a-zA-Z0-9%-]+)'"))
	if "4G" == config_mode then
		
	elseif "2G-3G" == config_mode then
		config_mode="(2G & 3G)"
	else
		config_mode=i18n.translate("Auto")
	end
	tmp = utl.exec("fs_cli -x 'gsm dump list'")
	lte_info.module = (tmp:match("dev_state%s*=%s*DEV_([a-zA-Z0-9_]+)") or "Unknown")
	lte_info.sim = (tmp:match("simpin_state%s*=%s*([a-zA-Z0-9_]+)\n") or "Unknown")
	lte_info.carrier = tostring(i18n.translate(tmp:match("opname%s*=%s*(.+)\nphone_num") or "Unknown"))

	local running_mode=(tmp:match("lte_mode%s*=%s*([a-zA-Z0-9%-%+]+)\n") or "Unknown")
	if "Unknown" == running_mode then
		running_mode=tostring(i18n.translate("Unknown"))
	elseif string.find(running_mode,"+") then
		running_mode="("..string.gsub(running_mode,"+"," & ")..")"
	end

	local running_mode_detail= (tmp:match("lte_detail_mode%s*=%s*(.+)\nhide_callernumber_mode") or "")
	if "" == running_mode_detail then
		lte_info.mode = config_mode.." / "..i18n.translate(running_mode)
	else
		if string.find(running_mode_detail,"and") then
			running_mode_detail=string.gsub(running_mode_detail,"and","&")
			running_mode_detail=string.gsub(running_mode_detail,"HYBRID","")
		end
		lte_info.mode = config_mode.." / "..i18n.translate(running_mode).." / "..running_mode_detail
	end

	lte_info.signal = tmp:match("got_signal%s*=%s*(%d+)\n") or 0

	return lte_info
end
function get_multi_wan_info()
	local utl = require "luci.util"
	local i18n = require "luci.i18n"
	local multi_wan_info

	local tmp = utl.exec("mwan3 status")

	if tmp then
		multi_wan_info={}
		local uplink_res = tmp:match("Policy wan_wan2:%s*\n%s*([a-z0-9]+)%s*")
		
		if uplink_res == "wan2" then
			curr_uplink = "LTE"
		else
			curr_uplink = "WAN"
		end
		multi_wan_info.curr_uplink = curr_uplink
		local wan_status = tmp:match("Interface wan is%s*([a-zA-Z]+)%s*")
		if wan_status and "ONLINE" == string.upper(wan_status) then
			multi_wan_info.wan_status = tostring(i18n.translate("Online"))
		else
			multi_wan_info.wan_status = tostring(i18n.translate("Offline"))
		end
		local lte_status = tmp:match("Interface wan2 is%s*([a-zA-Z]+)%s*")
		if lte_status and "ONLINE" == string.upper(lte_status) then
			multi_wan_info.lte_status = tostring(i18n.translate("Online"))
		else
			multi_wan_info.lte_status = tostring(i18n.translate("Offline"))
		end
	end
	return multi_wan_info
end
function get_netinfo()
	local nxo = require "nixio"
	local utl = require "luci.util"
	local uci = require "uci"
	local bit = require "bit"
	local i18n = require "luci.i18n"

	local tmp = uci.cursor("/tmp/config", "/tmp/state")
	local lan_info = tmp:get_all("network","lan")
	local wan_info = tmp:get_all("network","wan")
	local wlan_info = get_wifi_info()
	local lte_info
	local multi_wan_info
	local dhcp_info

	if not lan_info then
		lan_info = {}
	end

	local netstat = {}

	lan_info.ipaddr,lan_info.netmask,lan_info.gateway,lan_info.dns = ubus_get_addr("lan")
	if luci.version.license and luci.version.license.lte then
		lte_info=get_lte_info()
		multi_wan_info=get_multi_wan_info()
	end
	
	if wan_info then
		wan_info.ipaddr,wan_info.netmask,wan_info.gateway,wan_info.dns = ubus_get_addr("wan")
		dhcp_info = get_dhcp_info()
	end
	
	if lan_info.proto == "dhcp" then
		lan_info.lease_server,lan_info.lease = dhcp_get_server_status("br-lan")
	elseif lan_info and lan_info.proto == "pppoe" then
		lan_info.status = get_pppoe_status("pppoe-lan")
		lan_info.username=nil
		lan_info.password=nil
	end

	if wan_info and wan_info.proto == "dhcp" then
		local uci_tmp = uci.cursor("/tmp/config")
		local ifname = uci_tmp:get("network","wan","ifname") or "eth0.2"

		wan_info.lease_server = dhcp_get_server_status(ifname)
	elseif wan_info and wan_info.proto == "pppoe" then
		wan_info.status = get_pppoe_status("pppoe-wan")
		wan_info.username=nil
		wan_info.password=nil
	end

	netstat.uptime = nxo.sysinfo().uptime - (lan_info.connect_time or 0)

	netstat = get_netstat(wan_info,lan_info,wlan_info,lte_info)

	return wan_info,lte_info,lan_info,wlan_info,netstat,dhcp_info,multi_wan_info
end

function profile_network_init()
	local fs = require "luci.fs"
	local uci = require "luci.model.uci".cursor()
	local util = require "luci.util"
	local drv_str = util.exec("lsmod | sed -n '/^rt2x00/p;/^rt2860v2_ap/p;/^rt2860v2_sta/p;'")
	drv_str = drv_str:match("(rt2860v2_ap)") or drv_str:match("(rt2860v2_sta)") or drv_str:match("(rt2x00)") or ""
	
	os.execute("touch /etc/config/network_tmp")
	local lan_section = uci:get_all("network","lan")
	local wan_section = uci:get_all("network","wan")
	local option_tb = {}
	
	if lan_section then	
		for k,v in pairs(lan_section) do
			if k and v then
				option_tb["lan_"..k] = v
			end
		end
	end
	
	if drv_str == "rt2x00" then
		local wlan_section = uci:get_all("network","wlan")
		if wlan_section then
			for k,v in pairs(wlan_section) do
				if k and v then
					option_tb["wlan_"..k] = v
				end
			end

			local wifi_section = uci:get_all("wireless","wifi0")
			if wifi_section then
				for k,v in pairs(wifi_section) do
					if k and v then
						option_tb["wifi_"..k] = v
					end
				end
				
				if uci:get("wireless","wifi0","mode") == "ap" then
					option_tb["wifi_channel"] = uci:get("wireless","radio0","channel") or "auto"
					option_tb["wifi_disabled"] = uci:get("wireless","radio0","disabled") or "0"
					option_tb["network_mode"] = "bridge"
				elseif uci:get("wireless","wifi0","mode") == "sta" then
					option_tb["network_mode"] = "client"
				end
			end
		end
		option_tb["wifi_mode"] = nil
		option_tb["wifi_network"] = nil
	end

	if wan_section then
		for k,v in pairs(wan_section) do
			if k and v then
				option_tb["wan_"..k] = v
			end
		end
		
		option_tb["network_mode"] = "route"
		if drv_str == "rt2860v2_ap" or drv_str == "rt2860v2_sta" then
			if option_tb["wan_ifname"] == "ra0" then
				if option_tb["wan_proto"] and option_tb["wan_proto"] == "static" then
					option_tb["access_mode"] = "wlan_static"
				else
					option_tb["access_mode"] = "wlan_dhcp"
				end
			else
				if not option_tb["wan_proto"] or option_tb["wan_proto"] == "dhcp" then
					option_tb["access_mode"] = "wan_dhcp"
				elseif option_tb["wan_proto"] == "static" then
					option_tb["access_mode"] = "wan_static"
				else
					option_tb["access_mode"] = "wan_pppoe"
				end
			end
		end
	else
		option_tb["network_mode"] = "bridge"
	end

	--@ delete some value
	option_tb["lan_macaddr"] = nil
	option_tb["lan_ifname"] = nil
	option_tb["wan_macaddr"] = nil
	option_tb["wan_ifname"] = nil
	
	uci:create_section("network_tmp","setting","network",option_tb)
end
