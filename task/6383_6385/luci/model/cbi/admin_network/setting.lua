local fs = require "nixio.fs"
local ut = require "luci.util"
local uci = require "luci.model.uci".cursor()
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

function network_mode.write(self, section, value)
	local tmp = m:formvalue("cbid.network_tmp.network.network_mode")

	if section_firewall then
		if tmp == "route" then
			m.uci:set("firewall",section_firewall,"enabled","1")
		elseif tmp == "bridge" then
			m.uci:set("firewall",section_firewall,"enabled","0")
		end
	end
	
	m.uci:set("network_tmp","network","network_mode",tmp or "route")
end

--@ WAN Config {------
option = s:option(DummyValue,"_wan",translate("WAN"))
option:depends("network_mode","route")

--####wan proto#####----
option = s:option(ListValue,"wan_proto",translate("Protocol"))
option.margin = "30px"
option:value("dhcp",translate("DHCP"))
option:value("static",translate("Static address"))
option:value("pppoe",translate("PPPOE"))
option:depends("network_mode","route")

--@ WAN Static IP {
--####wan static ip addr####----
option = s:option(Value,"wan_ipaddr",translate("IP Address"))
option.margin = "30px"
option.datatype = "wan_addr"
option.rmempty = false
option:depends({network_mode="route",wan_proto="static"})
function option.validate(self, value)
	local tmp = m:formvalue("cbid.network_tmp.network.wan_proto")
	
	if  tmp == "static" then
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
option.datatype = "netmask"
option.default = "255.255.255.0"
option:value("255.0.0.0","255.0.0.0")
option:value("255.255.0.0","255.255.0.0")
option:value("255.255.255.0","255.255.255.0")
function option.validate(self,value)
	local tmp = m:formvalue("cbid.network_tmp.network.network_mode")
	local pro = m:formvalue("cbid.network_tmp.network.wan_proto")

	if tmp == "route" and pro == "static" then
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

function option.validate(self, value)
	local tmp = m:formvalue("cbid.network_tmp.network.wan_proto")
	
	if  tmp == "static"  then
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
option.default = option.enabled

--####wan static dns####----
option = s:option(DynamicList, "wan_dns",translate("Use custom DNS server"))
option:depends({network_mode="route",wan_peerdns=""})
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
rp.margin = "30px"

function rp.cfgvalue(...)
	return m.uci:get("dhcp", "dnsmasq", "rebind_protection") or "0"
end

function rp.parse(self, section, value)
	local mod = m:formvalue("cbid.network_tmp.network.network_mode")
	local v = m:formvalue("cbid.network_tmp.network.rebind_protection")

	if "route" == mod then
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
--@ } END WAN Config-----


--@ LAN Config { -------
option = s:option(DummyValue,"_lan",translate("LAN"))
option:depends("network_mode","route")

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
	option:depends("lan_proto","static")

	function option.validate(self,value)
		local tmp = m:formvalue("cbid.network_tmp.network.network_mode")
		local pro = m:formvalue("cbid.network_tmp.network.lan_proto")

		if (tmp == "route") or (tmp == "bridge" and pro == "static") then
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
