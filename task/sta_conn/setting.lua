local fs = require "nixio.fs"
local ut = require "luci.util"
local uci = require "luci.model.uci".cursor()
local sys = require "luci.sys"
local fs_server = require "luci.scripts.fs_server"
local drv_str = ut.exec("lsmod | sed -n '/^rt2x00/p;/^rt2860v2_ap/p;/^rt2860v2_sta/p;'")
drv_str = drv_str:match("(rt2860v2_ap)") or drv_str:match("(rt2860v2_sta)") or drv_str:match("(rt2x00)") or ""

--@ init network_tmp from network,wireless
if not fs.access("/etc/config/network_tmp") then
	require "luci.model.network".profile_network_init()
end

m = Map("network_tmp",translate("Network / Setting"), translate(""))
m:chain("network")
m:chain("firewall")
m:chain("wireless")

--@ first
s = m:section(NamedSection,"network","setting")

local section_firewall

for k,v in pairs(m.uci:get_all("firewall") or {}) do
	if v['.type'] == "defaults" then
		section_firewall = k
		break
	end
end

network_mode = s:option(ListValue,"network_mode",translate("Network Model"))
network_mode.rmempty = false
network_mode:value("route",translate("Route"))
network_mode:value("bridge",translate("Bridge"))
if fs.access("/lib/modules/3.14.18/rt2860v2_ap.ko") and fs.access("/lib/modules/3.14.18/rt2860v2_sta.ko") then
	network_mode:value("client",translate("Wireless Client"))
end

function network_mode.write(self, section, value)
	local tmp = m:formvalue("cbid.network_tmp.network.network_mode")

	if drv_str == "rt2860v2_ap" or drv_str == "rt2860v2_sta" then
		if tmp == "client" then
			for k,v in pairs(uci:get_all("wireless") or {}) do
				if v[".name"] == "ra0" then
					m.uci:set("wireless",k,"disabled","0")
					m.uci:set("wireless",k,"wdsmode","disable")
					m.uci:set("wireless",k,"wps","off")
				elseif v[".name"] == "wifi0" then
					m.uci:set("wireless",k,"disabled","0")
				else
					m.uci:set("wireless",k,"disabled","1")
				end
			end
			m.uci:set("wireless","wifi0","mode","sta")
		else
			if m.uci:get("wireless","wifi0","mode") == "sta" then
				local ssid_str = "domain_"..ut.exec("cat /sys/class/net/ra0/address | cut -c 10- | sed 's/://g' | tr '\\n' '\\0'")

				m.uci:set("wireless","wifi0","mode","ap")
				m.uci:set("wireless","wifi0","ssid",ssid_str)
				m.uci:set("wireless","wifi0","encryption","none")
				m.uci:delete("wireless","wifi0","key")
			end
		end
	end

	if section_firewall then
		if tmp == "route" then
			m.uci:set("firewall",section_firewall,"enabled","1")
		elseif tmp == "bridge" or tmp == "client" then
			m.uci:set("firewall",section_firewall,"enabled","0")
		end
	end
	
	m.uci:set("network_tmp","network","network_mode",tmp or "route")
end

--@ WAN Config {------
option = s:option(DummyValue,"_wan",translate("WAN"))
option:depends("network_mode","route")
option:depends("network_mode","client")

--####wan proto#####----
option = s:option(ListValue,"wan_proto",translate("Protocol"))
option.margin = "30px"
option:value("dhcp",translate("DHCP"))
option:value("static",translate("Static address"))
option:value("pppoe",translate("PPPOE"))
option:depends("network_mode","route")

--####wlan proto#####----
option = s:option(ListValue,"wlan_proto",translate("Protocol"))
option.margin = "30px"
option:value("dhcp",translate("DHCP"))
option:value("static",translate("Static address"))
option:depends("network_mode","client")
function option.cfgvalue(self, section)
	return m.uci:get("network_tmp","network","wan_proto")
end
function option.write(self,section,value)
	return m.uci:set("network_tmp","network","wan_proto",value or "dhcp")
end

if drv_str == "rt2860v2_ap" or drv_str == "rt2860v2_sta" then
	--####Extranet WIFI####----
	option = s:option(Value,"wifi_ssid",translate("Access Point List"))
	option.margin = "30px"
	option.rmempty = false
	option.datatype = "uni_ssid"
	option.template = "admin_network/ssid"
	option:depends("network_mode","client")
	function option.cfgvalue(self, section)
		return m.uci:get("wireless","wifi0","ssid")
	end
	function option.validate(self, value)
		if value then
			return Value.validate(self, value)
		else
			return ""
		end
	end
	function option.write(self,section,value)
		return m.uci:set("wireless","wifi0","ssid",value or "")
	end

	option = s:option(ListValue,"wifi_encryption",translate("Encryption"))
	option.margin = "30px"
	option.default = "psk2"
	option:value("psk","WPA+PSK")
	option:value("psk2","WPA2+PSK")
	option:value("wep","WEP")
	option:value("none","None")
	option:depends("network_mode","client")
	function option.cfgvalue(self, section)
		return m.uci:get("wireless","wifi0","encryption")
	end
	function option.validate(self,value)
		if value then
			if value == "none" then
				m.uci:delete("wireless","wifi0","key")
			end
			if value ~= "wep" and m.uci:get("wireless","wifi0","wep") then
				m.uci:delete("wireless","wifi0","wep")
			end
			return Value.validate(self,value)
		else
			return ""
		end
	end
	function option.write(self,section,value)
		return m.uci:set("wireless","wifi0","encryption",value or "psk2")
	end

	option = s:option(Value,"wifi_key",translate("Password"))
	option.margin = "30px"
	option.datatype = "wifi_password"
	option.rmempty = false
	option.password = true
	option:depends({network_mode="client",wifi_encryption="psk"})
	option:depends({network_mode="client",wifi_encryption="psk2"})
	function option.cfgvalue(self, section)
		local encrypt = m.uci:get("wireless","wifi0","encryption") or "psk2"
		if encryption ~= "none" then
			return m.uci:get("wireless","wifi0","key")
		else
			return nil
		end
	end
	function option.validate(self,value)
		if value then
			return Value.validate(self,value)
		else
			return ""
		end
	end
	function option.write(self,section,value)
		return m.uci:set("wireless","wifi0","key",value or "")
	end

	--# wifi wep encryption
	option = s:option(ListValue,"wifi_wep",translate(" "))
	option.margin = "30px"
	option:depends({network_mode="client",wifi_encryption="wep"})
	option:value("64bit","64bit")
	option:value("128bit","128bit")
	function option.cfgvalue(self, section)
		return m.uci:get("wireless","wifi0","wep")
	end
	function option.validate(self, value)
		if value then
			return Value.validate(self, value)
		else
			return ""
		end
	end
	function option.write(self,section,value)
		return m.uci:set("wireless","wifi0","wep",value or "")
	end

	--# wifi wep key
	option = s:option(Value,"wifi_wep_key",translate("Password"))
	option.margin = "30px"
	option.rmempty = false
	option:depends("wifi_encryption","wep")
	option.datatype = "wep_password"
	option.password = true
	function option.cfgvalue(...)
		local tmp = m.uci:get("wireless","wifi0","encryption")
		local key = m.uci:get("wireless","wifi0","key")
		
		if tmp == "wep" and key and key:match("^[0-9a-fA-F]+$") then
			local ret_key = ""
			local i = 1

			while string.byte(key,i) do
				ret_key = ret_key..string.format("%c","0x"..string.sub(key,i,i+1))
				i = i + 2
			end
			
			return ret_key
		else
			return key or ""
		end
	end
	function option.write(self, section, value)
		local tmp = m:formvalue("cbid.network_tmp.network.wifi_encryption")
		local wep_type = m:formvalue("cbid.network_tmp.network.wifi_wep")

		if tmp == "wep" then
			if wep_type == "64bit" then
				local ret_str = sys.exec("echo -n '"..(value or "").."' | hexdump -e '5/1 \"%02x\"'")
				m.uci:set("wireless","wifi0","key",ret_str or "")
			else
				local ret_str = sys.exec("echo -n '"..(value or "").."' | hexdump -e '13/1 \"%02x\"'")
				m.uci:set("wireless","wifi0","key",ret_str or "")
			end
		end
	end
	function option.validate(self,value)
		local tmp = m:formvalue("cbid.network_tmp.network.wifi_encryption")
		
		if value and tmp == "wep" then
			return Value.validate(self,value)
		else
			return value or ""
		end
	end
	
	-- wifi connect test
	local req_ip = luci.http.getenv("SERVER_ADDR")
	local lan_ip = ut.exec("ifconfig br-lan | grep 'inet addr'"):match("inet%saddr:([0-9%.]+)")
	if req_ip and lan_ip and req_ip == lan_ip and drv_str == "rt2860v2_sta" then
		option = s:option(DummyValue,"_sta_test","　")
		option.template = "admin_network/wifi_check"
	end
end

--@ WAN Static IP {
--####wan static ip addr####----
option = s:option(Value,"wan_ipaddr",translate("IP Address"))
option.margin = "30px"
option.datatype = "wan_addr"
option.rmempty = false
option:depends({network_mode="route",wan_proto="static"})
option:depends({network_mode="client",wlan_proto="static"})
function option.validate(self, value)
	local tmp = m:formvalue("cbid.network_tmp.network.wan_proto") or m:formvalue("cbid.network_tmp.network.wlan_proto")
	
	if tmp == "static" then
		return Value.validate(self, value)
	else
		m.uci:delete("network_tmp","network","wan_ipaddr")
		m.uci:delete("network","wan","ipaddr")
		return value or ""
	end
end	

--####wan static netmask####----
option = s:option(Value,"wan_netmask",translate("Netmask"))
option.margin = "30px"
option.rmempty = false
option:depends({network_mode="route",wan_proto="static"})
option:depends({network_mode="client",wlan_proto="static"})
option.datatype = "netmask"
option.default = "255.255.255.0"
option:value("255.0.0.0","255.0.0.0")
option:value("255.255.0.0","255.255.0.0")
option:value("255.255.255.0","255.255.255.0")
function option.validate(self,value)
	local tmp = m:formvalue("cbid.network_tmp.network.wan_proto") or m:formvalue("cbid.network_tmp.network.wlan_proto")

	if tmp == "static" then
		return Value.validate(self,value)
	else
		m.uci:delete("network_tmp","network","wan_netmask")
		m.uci:delete("network","wan","netmask")
		return value or ""
	end
end
--@ } END static IP

--@ PPPOE {
--####wan pppoe username####----
option = s:option(Value,"wan_username",translate("Username"))
option.margin = "30px"
option.rmempty = false
option:depends({network_mode="route",wan_proto="pppoe"})
function option.validate(self, value)
	local tmp = m:formvalue("cbid.network_tmp.network.wan_proto")

	if  tmp == "pppoe" then
		return Value.validate(self, value)
	else 
		m.uci:delete("network_tmp","network","wan_username")
		m.uci:delete("network","wan","username")
		return value or ""
	end
end	

--####wan pppoe password####----
option = s:option(Value,"wan_password",translate("Password"))
option.password = true
option.margin = "30px"
option.rmempty = false
option:depends({network_mode="route",wan_proto="pppoe"})
function option.validate(self,value)
	local tmp = m:formvalue("cbid.network_tmp.network.wan_proto")

	if tmp == "pppoe" then
		return Value.validate(self,value)
	else
		m.uci:delete("network_tmp","network","wan_password")
		m.uci:delete("network","wan","password")
		return value or ""
	end
end

--####wan pppoe service####----
option = s:option(Value,"wan_service",translate("Server Name"))
option.margin = "30px"
option:depends({network_mode="route",wan_proto="pppoe"})
function option.validate(self,value)
	local tmp = m:formvalue("cbid.network_tmp.network.wan_proto")

	if tmp == "pppoe" then
		return Value.validate(self,value)
	else
		m.uci:delete("network_tmp","network","wan_service")
		m.uci:delete("network","wan","service")
		return value or ""
	end
end


--@ } END PPPOE

--####wan static gateway####----
option = s:option(Value,"wan_gateway",translate("Default Gateway"))
option.margin = "30px"
option.datatype = "wan_gateway"
option.rmempty = false
option:depends({network_mode="route",wan_proto="static"})
option:depends({network_mode="client",wlan_proto="static"})

function option.validate(self, value)
	local tmp = m:formvalue("cbid.network_tmp.network.wan_proto") or m:formvalue("cbid.network_tmp.network.wlan_proto")
	
	if tmp == "static" then
		return Value.validate(self, value)
	else
		m.uci:delete("network_tmp","network","wan_gateway")
		m.uci:delete("network","wan","gateway")
		return value or ""
	end
end

--####wan auto dns####----
option = s:option(Flag,"wan_peerdns",translate("Obtain DNS server address automatically"))
option.margin = "30px"
option.rmempty = false
option:depends("wan_proto","dhcp")
option:depends("wan_proto","pppoe")
option:depends("wlan_proto","dhcp")
option.default = option.enabled

--####wan static dns####----
option = s:option(DynamicList, "wan_dns",translate("Use custom DNS server"))
option:depends({network_mode="route",wan_peerdns=""})
option:depends({network_mode="client",wan_peerdns=""})
option.margin = "30px"
option.datatype = "abc_ip4addr"
option.cast     = "string"
option.addremove = false
option.max = 2

function option.cfgvalue(...)
	return m.uci:get("network_tmp","network","wan_dns") or {""}
end

function option.parse(self, section, value)
	local value = m:formvalue("cbid.network_tmp.network.wan_dns")

	if value then
		m.uci:set("network_tmp","network","wan_dns",value)
	else
		m.uci:delete("network_tmp","network","wan_dns")
		m.uci:delete("network","wan","dns")
	end
end

rp = s:option(Flag,"rebind_protection",translate("Disable Private Internets(RFC2918) DNS responses"))
rp:depends("network_mode","route")
rp:depends("network_mode","client")
rp.margin = "30px"

function rp.cfgvalue(...)
	return m.uci:get("dhcp", "dnsmasq", "rebind_protection") or "0"
end

function rp.parse(self, section, value)
	local mod = m:formvalue("cbid.network_tmp.network.network_mode")
	local v = m:formvalue("cbid.network_tmp.network.rebind_protection")

	if "route" == mod or "client" == mod then
		m.uci:set("dhcp", "dnsmasq", "rebind_protection", v or "0")
		m.uci:save("dhcp")
	end
end

--####wan mtu####----
option = s:option(Value,"wan_mtu",translate("MTU"))
option.margin = "30px"
option.placeholder = "1500"
option.datatype    = "range(576,1500)"
option:depends("network_mode","route")
option:depends("network_mode","client")
--@ } END WAN Config-----

--@ LAN Config { -------
option = s:option(DummyValue,"_lan",translate("LAN"))
option:depends("network_mode","route")
option:depends("network_mode","client")

	--@ only for bridge model
	option = s:option(ListValue,"lan_proto",translate("Protocol"))
	option.margin = "30px"
	option:value("static",translate("Static address"))
	option:value("dhcp",translate("DHCP"))
	option:value("pppoe",translate("PPPOE"))
	option:depends("network_mode","bridge")
	--@ only for bridge model

	--####lan static ip addr####----
	option = s:option(Value,"lan_ipaddr",translate("IP Address"))
	option.margin = "30px"
	option.rmempty = false
	option.datatype = "lan_addr"
	option.default = "192.168.11.1"
	option:depends("network_mode","route")
	option:depends("network_mode","client")
	option:depends("lan_proto","static")

	function option.validate(self, value)
		local tmp = m:formvalue("cbid.network_tmp.network.lan_proto")
		local network_mode = m:formvalue("cbid.network_tmp.network.network_mode")
		local tmp_wan_ip = m:formvalue("cbid.network_tmp.network.wan_ipaddr")
		
		if tmp == "static" or network_mode == "route" or network_mode == "client" then
			if tmp_wan_ip then
				--@ check for different wan and lan ip
				
				return Value.validate(self, value)
			else
				return Value.validate(self, value)
			end
		else 
			m.uci:delete("network_tmp","network","lan_ipaddr")
			m.uci:delete("network","lan","ipaddr")
			return value or ""
		end
	end	

	--####lan static netmask####----
	option = s:option(Value,"lan_netmask",translate("Netmask"))
	option.margin = "30px"
	option.datatype = "netmask"
	option.rmempty = false
	option.default = "255.255.255.0"
	option:value("255.0.0.0","255.0.0.0")
	option:value("255.255.0.0","255.255.0.0")
	option:value("255.255.255.0","255.255.255.0")
	option:depends("network_mode","route")
	option:depends("network_mode","client")
	option:depends("lan_proto","static")

	function option.validate(self,value)
		local tmp = m:formvalue("cbid.network_tmp.network.network_mode")
		local pro = m:formvalue("cbid.network_tmp.network.lan_proto")

		if (tmp == "route") or (tmp == "client") or (tmp == "bridge" and pro == "static") then
			return Value.validate(self,value)
		else
			m.uci:delete("network_tmp","network","lan_netmask")
			m.uci:delete("network","lan","netmask")
			return value or ""
		end
	end
	
	--####bridge model lan pppoe username####----
	option = s:option(Value,"lan_username",translate("Username"))
	option.margin = "30px"
	option.rmempty = false
	option:depends("lan_proto","pppoe")
	function option.validate(self, value)
		local tmp = m:formvalue("cbid.network_tmp.network.lan_proto")
		
		if  tmp == "pppoe" then
			return Value.validate(self, value)
		else 
			m.uci:delete("network_tmp","network","lan_username")
			m.uci:delete("network","lan","username")
			return value or ""
		end
	end	

	--####bridge model lan pppoe password####----
	option = s:option(Value,"lan_password",translate("Password"))
	option.password = true
	option.margin = "30px"
	option.rmempty = false
	option:depends("lan_proto","pppoe")
	function option.validate(self,value)
		local tmp = m:formvalue("cbid.network_tmp.network.lan_proto")

		if tmp == "pppoe" then
			return Value.validate(self,value)
		else
			m.uci:delete("network_tmp","network","lan_password")
			m.uci:delete("network","lan","password")
			return value or ""
		end
	end

	--####bridge model lan pppoe service####----
	option = s:option(Value,"lan_service",translate("Server Name"))
	option.margin = "30px"
	option:depends("lan_proto","pppoe")
	function option.validate(self,value)
		local tmp = m:formvalue("cbid.network_tmp.network.lan_proto")

		if tmp == "pppoe" then
			return Value.validate(self,value)
		else
			m.uci:delete("network_tmp","network","lan_service")
			m.uci:delete("network","lan","service")
			return value or ""
		end
	end

	--####lan static gateway####----
	option = s:option(Value,"lan_gateway",translate("Default Gateway"))
	option.margin = "30px"
	option.datatype = "lan_gateway"
	option.rmempty = false
	option:depends({network_mode="bridge",lan_proto="static"})

	function option.validate(self, value)
		local tmp = m:formvalue("cbid.network_tmp.network.lan_proto")
		
		if  tmp == "static" then
			return Value.validate(self, value)
		else 
			m.uci:delete("network_tmp","network","lan_gateway")
			m.uci:delete("network","lan","gateway")
			return value or ""
		end
	end

	--####lan auto dns####----
	option = s:option(Flag,"lan_peerdns",translate("Obtain DNS server address automatically"))
	option.margin = "30px"
	option:depends("lan_proto","dhcp")
	option:depends("lan_proto","pppoe")
	option.rmempty = false
	option.default = option.enabled

	function option.validate(self,value)
		local tmp_mod = m:formvalue("cbid.network_tmp.network.network_mode")
		local tmp_pro = m:formvalue("cbid.network_tmp.network.lan_proto")

		if tmp_mode == "bridge" and (tmp_pro == "dhcp" or tmp_pro == "pppoe") then
			return Value.validate(self,value)
		else
			m.uci:delete("network_tmp","network","lan_peerdns")
			m.uci:delete("network","lan","peerdns")
			return value or ""
		end
	end
	
	--####lan static dns####----
	option = s:option(DynamicList, "lan_dns",translate("Use custom DNS server"))
	option:depends({network_mode="bridge",lan_peerdns=""})
	option.margin = "30px"
	option.datatype = "abc_ip4addr"
	option.cast     = "string"
	option.addremove = false
	option.max = 2

	function option.cfgvalue(...)
		return m.uci:get("network_tmp","network","lan_dns") or ""
	end

	function option.parse(self, section, value)
		local value = m:formvalue("cbid.network_tmp.network.lan_dns")

		if value then
			m.uci:set("network_tmp","network","lan_dns",value)
		else
			m.uci:delete("network_tmp","network","lan_dns")
			m.uci:delete("network","lan","dns")
		end
	end

	lan_rp = s:option(Flag,"lan_rebind_protection",translate("Disable Private Internets(RFC2918) DNS responses"))
	lan_rp.margin = "30px"
	lan_rp:depends("network_mode","bridge")

	function lan_rp.cfgvalue(...)
		return m.uci:get("dhcp", "dnsmasq", "rebind_protection") or "0"
	end

	function lan_rp.parse(self, section, value)
		local mod = m:formvalue("cbid.network_tmp.network.network_mode")
		local v = m:formvalue("cbid.network_tmp.network.lan_rebind_protection")
		if "bridge" == mod then
			m.uci:set("dhcp", "dnsmasq", "rebind_protection", v or "0")
			m.uci:save("dhcp")
		end
	end

	--####lan mtu####----
	option = s:option(Value,"lan_mtu",translate("MTU"))
	option.margin = "30px"
	option.placeholder = "1500"
	option.datatype    = "range(576,1500)"
	
--@ } END LAN Config -------

return m
