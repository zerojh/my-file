local uci = require "luci.model.uci".cursor()
local fs_server = require "luci.scripts.fs_server"

m = Map("network_tmp",translate("First Stage: Internet Settings"))
m:chain("network")
m:chain("firewall")

--@ first
s = m:section(NamedSection,"network","setting")

--#### Description #####----
option = s:option(DummyValue,"_desciption")
option.template = "admin_wizard/desc_net_access"

local section_firewall

for k,v in pairs(m.uci:get_all("firewall") or {}) do
	if v['.type'] == "defaults" then
		section_firewall = k
		break
	end
end

--####access mode#####----
option = s:option(ListValue,"access_mode",translate("Network Model"))
option.rmempty = false
option:value("wan_dhcp",translate("Wired Dynamic IP"))
option:value("wan_static",translate("Wired Static IP"))
option:value("wan_pppoe",translate("PPPoE"))
option:value("wlan_dhcp",translate("Wire Dynamic IP"))
option:value("wlan_static",translate("Wire Static IP"))

function option.write(self, section, value)
	local tmp = m:formvalue("cbid.network_tmp.network.access_mode") or "wan_dhcp"

	if tmp == "wan_dhcp" or tmp == "wan_static" or tmp == "wan_pppoe"then
		m.uci:set("network_tmp","network","network_mode","route")
		m.uci:set("network_tmp","network","wan_proto",string.sub(tmp,5))
		m.uci:set("firewall",section_firewall,"enabled","1")
	elseif tmp == "wlan_dhcp" or tmp == "wlan_static" then
		m.uci:set("network_tmp","network","network_mode","client")
		m.uci:set("network_tmp","network","wlan_proto",string.sub(tmp,5))
		m.uci:set("firewall",section_firewall,"enabled","0")
	end

	m.uci:set("network_tmp","network","access_mode",tmp)
end

--@ WAN Static IP {
--####wan static ip addr####----
option = s:option(Value,"wan_ipaddr",translate("IP Address"))
option.datatype = "wan_addr"
option.rmempty = false
option:depends("access_mode","wan_static")
function option.validate(self, value)
	local tmp = m:formvalue("cbid.network_tmp.network.access_mode")
	
	if  tmp == "wan_static" then
		return Value.validate(self, value)
	else
		m.uci:delete("network_tmp","network","wan_ipaddr")
		m.uci:delete("network","wan","ipaddr")
		return value or ""
	end
end

--####wan static netmask####----
option = s:option(Value,"wan_netmask",translate("Netmask"))
option.rmempty = false
option:depends("access_mode","wan_static")
option.datatype = "netmask"
option.default = "255.255.255.0"
option:value("255.0.0.0","255.0.0.0")
option:value("255.255.0.0","255.255.0.0")
option:value("255.255.255.0","255.255.255.0")
function option.validate(self,value)
	local tmp = m:formvalue("cbid.network_tmp.network.access_mode")

	if tmp == "wan_static" then
		return Value.validate(self,value)
	else
		m.uci:delete("network_tmp","network","wan_netmask")
		m.uci:delete("network","wan","netmask")
		return value or ""
	end
end

--####wan static gateway####----
option = s:option(Value,"wan_gateway",translate("Default Gateway"))
option.datatype = "wan_gateway"
option.rmempty = false
option:depends("access_mode","wan_static")

function option.validate(self, value)
	local tmp = m:formvalue("cbid.network_tmp.network.access_mode")
	
	if  tmp == "wan_static"  then
		return Value.validate(self, value)
	else
		m.uci:delete("network_tmp","network","wan_gateway")
		m.uci:delete("network","wan","gateway")
		return value or ""
	end
end

--@ } END static IP

--@ PPPOE {
--####wan pppoe username####----
option = s:option(Value,"wan_username",translate("Username"))
option.rmempty = false
option:depends("access_mode","wan_pppoe")
function option.validate(self, value)
	local tmp = m:formvalue("cbid.network_tmp.network.access_mode")

	if tmp == "wan_pppoe" then
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
option.rmempty = false
option:depends("access_mode","wan_pppoe")
function option.validate(self,value)
	local tmp = m:formvalue("cbid.network_tmp.network.access_mode")

	if tmp == "wan_pppoe" then
		return Value.validate(self,value)
	else
		m.uci:delete("network_tmp","network","wan_password")
		m.uci:delete("network","wan","password")
		return value or ""
	end
end

--####wan pppoe service####----
option = s:option(Value,"wan_service",translate("Server Name"))
option:depends("access_mode","wan_pppoe")
function option.validate(self,value)
	local tmp = m:formvalue("cbid.network_tmp.network.access_mode")

	if tmp == "wan_pppoe" then
		return Value.validate(self,value)
	else
		m.uci:delete("network_tmp","network","wan_service")
		m.uci:delete("network","wan","service")
		return value or ""
	end
end
--@ } END PPPOE

--####wan auto dns####----
option = s:option(Flag,"wan_peerdns",translate("Obtain DNS server address automatically"))
option.rmempty = false
option:depends("access_mode","wan_dhcp")
option:depends("access_mode","wan_pppoe")
option.default = option.enabled

--####wan static dns####----
option = s:option(DynamicList, "wan_dns",translate("Use custom DNS server"))
option.datatype = "abc_ip4addr"
option.cast     = "string"
option.addremove = false
option.max = 2
option:depends({access_mode="wan_dhcp",wan_peerdns=""})
option:depends({access_mode="wan_pppoe",wan_peerdns=""})
option:depends("access_mode","wan_static")

function option.cfgvalue(...)
	return m.uci:get("network_tmp","network","wan_dns") or ""
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

--@ } END WAN Config-----

option = s:option(Value,"wifi_ssid",translate("SSID"))
option.rmempty = false
option.datatype = "uni_ssid"
option:depends("access_mode","wlan_dhcp")
option:depends("access_mode","wlan_static")
local wireless_tb = fs_server.get_wifi_list()
local ssid_list = {}
local name_list_str = ""
for k,v in pairs(wireless_tb) do
	if v['.type'] == "wifi" and v.ssid and not ssid_list[v.ssid] then
		ssid_list[v.ssid] = 1
		option:value(v.ssid,v.ssid)
	end
end
function option.cfgvalue(...)
	return m.uci:get("wireless","wifi0","ssid") or ""
end
function option.validate(self, value)
	local tmp = m:formvalue("cbid.network_tmp.network.access_mode")

	if tmp == "wlan_dhcp" or tmp == "wlan_static"then
		return Value.validate(self, value)
	else
		m.uci:delete("wireless","wifi0","ssid")
		return value or ""
	end
end
function option.write(self,section,name)
	local tmp = m:formvalue("cbid.network_tmp.network.wifi_ssid")

	if tmp then
		return m.uci:set("wireless","wifi0","ssid",tmp)
	else
		return m.uci:delete("wireless","wifi0","ssid")
	end
end

option = s:option(Value,"wifi_key",translate("Password"))
option.rmempty = false
option.datatype = "wifi_password"
option.password = true
option:depends("access_mode","wlan_dhcp")
option:depends("access_mode","wlan_static")
function option.cfgvalue(...)
	local key = m.uci:get("wireless","wifi0","key")

	return key or ""
end
function option.validate(self, value)
	local tmp = m:formvalue("cbid.network_tmp.network.access_mode")

	if tmp == "wlan_dhcp" or tmp == "wlan_static"then
		return Value.validate(self, value)
	else
		m.uci:delete("wireless","wifi0","key")
		m.uci:delete("wireless","wifi0","encryption")
		return value or ""
	end
end
function option.write(self,section,name)
	local tmp = m:formvalue("cbid.network_tmp.network.wifi_key")

	if tmp then
		return m.uci:set("wireless","wifi0","key",tmp)
	else
		return m.uci:delete("wireless","wifi0","key")
	end
end

option = s:option(Value,"wlan_ipaddr","IP Address")
option.rmempty = false
option.datatype = "wlan_addr"
option:depends("access_mode","wlan_static")
function option.validate(self, value)
	local tmp = m:formvalue("cbid.network_tmp.network.access_mode")
	
	if  tmp == "wlan_static" then
		return Value.validate(self, value)
	else
		m.uci:delete("network_tmp","network","wlan_ipaddr")
		m.uci:delete("network","wlan","ipaddr")
		return value or ""
	end
end

option = s:option(Value,"wlan_netmask",translate("Netmask"))
option.rmempty = false
option:depends("access_mode","wlan_static")
option.datatype = "netmask"
option.default = "255.255.255.0"
option:value("255.0.0.0","255.0.0.0")
option:value("255.255.0.0","255.255.0.0")
option:value("255.255.255.0","255.255.255.0")
function option.validate(self,value)
	local tmp = m:formvalue("cbid.network_tmp.network.access_mode")

	if tmp == "wlan_static" then
		return Value.validate(self,value)
	else
		m.uci:delete("network_tmp","network","wlan_netmask")
		m.uci:delete("network","wlan","netmask")
		return value or ""
	end
end

option = s:option(Value,"wlan_gateway",translate("Default Gateway"))
option.datatype = "wlan_gateway"
option.rmempty = false
option:depends("access_mode","wlan_static")

function option.validate(self, value)
	local tmp = m:formvalue("cbid.network_tmp.network.access_mode")
	
	if  tmp == "wlan_static"  then
		return Value.validate(self, value)
	else
		m.uci:delete("network_tmp","network","wlan_gateway")
		m.uci:delete("network","wlan","gateway")
		return value or ""
	end
end

option = s:option(Flag,"wlan_peerdns",translate("Obtain DNS server address automatically"))
option.rmempty = false
option:depends("access_mode","wlan_dhcp")
option:depends("access_mode","wlan_pppoe")
option.default = option.enabled

option = s:option(DynamicList, "wlan_dns",translate("Use custom DNS server"))
option.datatype = "abc_ip4addr"
option.cast     = "string"
option.addremove = false
option.max = 2
option:depends({access_mode="wlan_dhcp",wlan_peerdns=""})
option:depends({access_mode="wlan_pppoe",wlan_peerdns=""})
option:depends("access_mode","wlan_static")

function option.cfgvalue(...)
	return m.uci:get("network_tmp","network","wlan_dns") or ""
end

function option.parse(self, section, value)
	local value = m:formvalue("cbid.network_tmp.network.wlan_dns")

	if value then
		m.uci:set("network_tmp","network","wlan_dns",value)
	else
		m.uci:delete("network_tmp","network","wlan_dns")
		m.uci:delete("network","wlan","dns")
	end
end

return m
