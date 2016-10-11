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
		s.wlan.rx_pkts,s.wlan.tx_pkts,s.wlan.rx_bytes,s.wlan.tx_bytes = get_netstat_detail(raw_info,"wlan0");
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

	if fs.access("/lib/modules/3.14.18/rt2860v2_ap.ko") then
		raw_info = utl.exec("iwinfo ra0 info")
	else
		raw_info = utl.exec("iwinfo")
	end

	wlan.mac_addr = raw_info:match("Access Point:%s+([%w%:]+)")

	if not wlan.mac_addr or (wlan.mac_addr and "00:00:00:00:00:00" == wlan.mac_addr) then
		return nil
	end

	wlan.ssid = raw_info:match("ESSID:%s+%\"*([0-9a-zA-Z%-%.%_]+)\"*")
	wlan.channel = raw_info:match("Channel:%s+(%d+)")
	wlan.encrypt = raw_info:match("Encryption:%s+(.+)Type:")

	return wlan
end

function get_dhcp_info()
	local uci = require "luci.model.uci".cursor()
	local cfg = uci:get_all("dhcp","lan")
	local dhcp = {}

	if cfg then
		dhcp.status = ("1" == cfg.ignore and "Disabled") or "Enabled"
		dhcp.startaddr = cfg.start or 1
		dhcp.endaddr = cfg.limit or 99
		dhcp.expires = (cfg.leasetime and cfg.leasetime:match("(%d+)")) or "24"
		if cfg.dhcp_option and "table" == type(cfg.dhcp_option) then
			for k,v in pairs(cfg.dhcp_option) do
				if v:match("3,") then
					dhcp.gateway = v:match("3,([0-9%.]+)")
				end
				if v:match("6,") then
					dhcp.dns = v:match("6,([0-9%.%,]+)")
					dhcp.dns = string.gsub(dhcp.dns,","," ")
				end
			end
		end
	end

	return dhcp
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
function get_netinfo()
	local nxo = require "nixio"
	local utl = require "luci.util"
	local uci = require "uci"
	local bit = require "bit"

	local tmp = uci.cursor("/tmp/config", "/tmp/state")
	local lan_info = tmp:get_all("network","lan")
	local wan_info = tmp:get_all("network","wan")
	local wlan_info = get_wifi_info()
	local lte_info
	local dhcp_info

	if not lan_info then
		lan_info = {}
	end

	local netstat = {}

	lan_info.ipaddr,lan_info.netmask,lan_info.gateway,lan_info.dns = ubus_get_addr("lan")
	if luci.version.license and luci.version.license.lte then
		lte_info = {}
		lte_info.ipaddr,lte_info.netmask,lte_info.gateway,lte_info.dns = ubus_get_addr("wan2")
		local tmp = utl.exec("cat /etc/config/endpoint_mobile | grep lte_mode")
		lte_info.mode = string.upper(tmp:match("lte_mode '(%w+)'") or "unknown")
		tmp = utl.exec("fs_cli -x 'gsm dump list'")
		lte_info.mode = lte_info.mode.." / "..(tmp:match("lte_mode%s*=%s*([a-zA-Z0-9]+)\n") or "UNKNOWN")
		lte_info.signal = tmp:match("got_signal%s*=%s*(%d+)\n") or 0
	end
	
	if wan_info then
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

		wan_info.ipaddr,wan_info.netmask,wan_info.gateway,wan_info.dns = ubus_get_addr("wan")
		dhcp_info = get_dhcp_info()
		
		local tmp_ip = utl.split(lan_info.ipaddr or "192.168.11.1",".")
		local tmp_netmask = utl.split(lan_info.netmask or "255.255.255.0",".")
		local dhcp_ip_pool = bit.band(tmp_ip[1],tmp_netmask[1]).."."..bit.band(tmp_ip[2],tmp_netmask[2]).."."..bit.band(tmp_ip[3],tmp_netmask[3]).."."..bit.band(tmp_ip[4],tmp_netmask[4])
		local tmp_start = dhcp_info.startaddr
		local tmp_limit = dhcp_info.endaddr
		local start_number = bit.bor(bit.band(bit.bnot(ip2number(lan_info.netmask or "255.255.255.0")),tmp_start),ip2number(dhcp_ip_pool))
		local max_number = ip2number(dhcp_ip_pool) + bit.band(bit.bnot(ip2number(lan_info.netmask or "255.255.255.0")),ip2number("255.255.255.255")) - 1
			
		dhcp_info.startaddr = number2ip(start_number)
		if (start_number + tonumber(tmp_limit)) >= max_number then
			dhcp_info.endaddr = number2ip(max_number)
		else
			dhcp_info.endaddr = number2ip(bit.bor(bit.band(bit.bnot(ip2number(lan_info.netmask or "255.255.255.0")),tmp_start + tmp_limit - 1),ip2number(dhcp_ip_pool)))
		end
	end
	
	if lan_info.proto == "dhcp" then
		lan_info.lease_server,lan_info.lease = dhcp_get_server_status("br-lan")
	elseif lan_info and lan_info.proto == "pppoe" then
		lan_info.status = get_pppoe_status("pppoe-lan")
		lan_info.username=nil
		lan_info.password=nil
	end

	if wan_info and wan_info.proto == "dhcp" then
		wan_info.lease_server = dhcp_get_server_status("eth0.2")
	elseif wan_info and wan_info.proto == "pppoe" then
		wan_info.status = get_pppoe_status("pppoe-wan")
		wan_info.username=nil
		wan_info.password=nil
	end

	netstat.uptime = nxo.sysinfo().uptime - (lan_info.connect_time or 0)

	netstat = get_netstat(wan_info,lan_info,wlan_info,lte_info)

	return wan_info,lte_info,lan_info,wlan_info,netstat,dhcp_info
end

function profile_network_init()
	local fs = require "luci.fs"
	local uci = require "luci.model.uci".cursor()
	
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
	
	if not fs.access("/lib/modules/3.14.18/rt2860v2_ap.ko") then
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
					if fs.access("/lib/modules/3.14.18/rt2860v2_ap.ko") then
						option_tb["wifi_channel"] = uci:get("wireless","ra0","channel") or "auto"
						option_tb["wifi_disabled"] = uci:get("wireless","ra0","disabled") or "0"
					else
						option_tb["wifi_channel"] = uci:get("wireless","radio0","channel") or "auto"
						option_tb["wifi_disabled"] = uci:get("wireless","radio0","disabled") or "0"
					end
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
	end	

	--@ delete some value
	option_tb["lan_macaddr"] = nil
	option_tb["lan_ifname"] = nil
	option_tb["wan_macaddr"] = nil
	option_tb["wan_ifname"] = nil
	
	uci:create_section("network_tmp","setting","network",option_tb)
end
