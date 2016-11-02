--[[

]]--
local dsp = require "luci.dispatcher"
local uci = require "luci.model.uci".cursor()
local fs = require "luci.fs"

dev_name = ""
if fs.access("/lib/modules/3.14.18/rt2860v2_ap.ko") then
	dev_name = "ra0"
else
	dev_name = "radio0"
end

m = Map("wireless",translate("WLAN"))

s = m:section(NamedSection,dev_name,"")
disabled = s:option(ListValue,"disabled",translate("WIFI Status"))
disabled:value("0",translate("On"))
disabled:value("1",translate("Off"))

option = s:option(ListValue,"ssid",translate("SSID"))
option.template = "admin_network/wifi_list"

--# wifi encryption
option = s:option(ListValue,"encryption",translate("Encryption"))
option.margin = "30px"
option.default = "psk2"
--option:depends("wifi_disabled","0")
option:value("wep","WEP")
option:value("psk","WPA+PSK")
option:value("psk2","WPA2+PSK")
option:value("none",translate("NONE"))

--# wifi wep encryption
option = s:option(ListValue,"wep",translate(" "))
option:depends("encryption","wep")
option:value("64bit","64bit")
option:value("128bit","128bit")

--# wifi normal key
option = s:option(Value,"wifi_normal_key",translate("Password"))
option.margin = "30px"
option.rmempty = false
option.datatype = "wifi_password"
option.password = true
option:depends({wifi_disabled="0",wifi_encryption="psk"})
option:depends({wifi_disabled="0",wifi_encryption="psk2"})

function option.cfgvalue(...)
	local key = m.uci:get("network_tmp","network","wifi_key")

	return key or ""
end

function option.write(self,section,value)
	local tmp = m:formvalue("cbid.network_tmp.network.wifi_encryption")

	if tmp ~= "wep" then
		m.uci:set("network_tmp","network","wifi_key",value or "")
	end
end

function option.validate(self,value)
	local tmp = m:formvalue("cbid.network_tmp.network.wifi_encryption")
	local tmp_disabled = m:formvalue("cbid.network_tmp.network.wifi_disabled")
	
	if tmp_disabled == "0" and (tmp ~= "wep" and tmp ~= "none") then
		return Value.validate(self,value)
	else
		return value or ""
	end
end

--# wifi wep key
option = s:option(Value,"wifi_wep_key",translate("Password"))
option.margin = "30px"
option.rmempty = false
option:depends({wifi_disabled="0",wifi_encryption="wep"})
option.datatype = "wep_password"
option.password = true
function option.cfgvalue(...)
	local tmp = m.uci:get("network_tmp","network","wifi_encryption")
	local key = m.uci:get("network_tmp","network","wifi_key")
	
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

local sys = require "luci.sys"
function option.write(self, section, value)
	local tmp = m:formvalue("cbid.network_tmp.network.wifi_encryption")
	local wep_type = m:formvalue("cbid.network_tmp.network.wifi_wep")

	if tmp == "wep" then
		if wep_type == "64bit" then
			local ret_str = sys.exec("echo -n '"..(value or "").."' | hexdump -e '5/1 \"%02x\"'")	
			m.uci:set("network_tmp","network","wifi_key",ret_str or "")
		else
			local ret_str = sys.exec("echo -n '"..(value or "").."' | hexdump -e '13/1 \"%02x\"'")	
			m.uci:set("network_tmp","network","wifi_key",ret_str or "")							
		end
	end
end
function option.validate(self,value)
	local tmp = m:formvalue("cbid.network_tmp.network.wifi_encryption")
	local disabled = m:formvalue("cbid.network_tmp.network.wifi_disabled")
	
	if disabled == "0" and tmp == "wep" then
		return Value.validate(self,value)
	else
		return value or ""
	end
end

m2 = Map("network",translate(""))

if not uci:get("network","wlan") then
	m2.uci:section("network","interface","wlan")
	uci:save("network")
end

s = m2:section(NamedSection,"wlan","interface")

--####wlan proto#####----
option = s:option(ListValue,"proto",translate("Protocol"))
option:value("dhcp",translate("DHCP"))
option:value("statuc",translate("Static address"))

--@ WLAN Static IP {
--####wlan static ip addr####----
option = s:option(Value,"ipaddr",translate("IP Address"))
option.datatype = "wlan_addr"
option.rmempty = false
option:depends("proto","static")
function option.validate(self, value)
	local proto = m2:formvalue("cbid.network.wlan.proto")
	
	if  proto == "static" then
		return Value.validate(self, value)
	else
		m2.uci:delete("network","wlan","ipaddr")
		return value or ""
	end
end

--####wlan static netmask####----
option = s:option(Value,"netmask",translate("Netmask"))
option.rmempty = false
option:depends("proto","static")
option.datatype = "netmask"
option.default = "255.255.255.0"
option:value("255.0.0.0","255.0.0.0")
option:value("255.255.0.0","255.255.0.0")
option:value("255.255.255.0","255.255.255.0")
function option.validate(self,value)
	local proto = m2:formvalue("cbid.network.wlan.proto")

	if proto == "static" then
		return Value.validate(self,value)
	else
		m2.uci:delete("network","wlan","netmask")
		return value or ""
	end
end

--####wlan static gateway####----
option = s:option(Value,"gateway",translate("Default Gateway"))
option.datatype = "wlan_gateway"
option.rmempty = false
option:depends("proto","static")

function option.validate(self, value)
	local proto = m2:formvalue("cbid.network.wlan.proto")
	
	if proto == "static"  then
		return Value.validate(self, value)
	else
		m2.uci:delete("network","wlan","gateway")
		return value or ""
	end
end

return m,m2
