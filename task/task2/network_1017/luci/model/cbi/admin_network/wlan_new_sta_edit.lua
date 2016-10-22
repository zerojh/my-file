--[[

]]--
local dsp = require "luci.dispatcher"
local uci = require "luci.model.uci".cursor()
local fs = require "luci.fs"

m = Map("network",translate("WLAN"))

if not uci:get("network","wlan") then
	m.uci:section("network","interface","wlan")
	uci:save("network")
end

s = m:section(NamedSection,"wlan","interface")

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
	local proto = m:formvalue("cbid.network.wlan.proto")
	
	if  proto == "static" then
		return Value.validate(self, value)
	else
		m.uci:delete("network","wlan","ipaddr")
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
	local proto = m:formvalue("cbid.network.wlan.proto")

	if proto == "static" then
		return Value.validate(self,value)
	else
		m.uci:delete("network","wlan","netmask")
		return value or ""
	end
end

--####wlan static gateway####----
option = s:option(Value,"gateway",translate("Default Gateway"))
option.margin = "30px"
option.datatype = "wlan_gateway"
option.rmempty = false
option:depends("proto","static")

function option.validate(self, value)
	local proto = m:formvalue("cbid.network.wlan.proto")
	
	if proto == "static"  then
		return Value.validate(self, value)
	else
		m.uci:delete("network","wlan","gateway")
		return value or ""
	end
end

m2 = Map("wireless",translate(""))

s = m:section(NamedSection,"radio0","")
disabled = s:option(ListValue,"disabled",translate("WIFI Status"))
disabled.margin = "30px"
disabled:value("0",translate("On"))
disabled:value("1",translate("Off"))

--@ wifi ap model
--# AP model wifi ssid
option = s:option(Value,"wifi_ssid",translate("SSID"))
option.margin = "30px"
option.rmempty = false
option.datatype = "ssid"
option:depends({network_mode="route",wifi_disabled="0"})
option:depends({network_mode="bridge",wifi_disabled="0"})
function option.validate(self, value)
	local tmp_mode = m:formvalue("cbid.network_tmp.network.network_mode")
	local tmp_enabled = m:formvalue("cbid.network_tmp.network.wifi_disabled")
	
	if (tmp_mode == "route" or tmp_mode == "bridge") and tmp_enabled == "0" then
		return Value.validate(self, value)
	else
		return value or ""
	end
end

--# AP model wifi channel
option = s:option(ListValue,"wifi_channel",translate("Channel"))
option.margin = "30px"
option:depends({network_mode="route",wifi_disabled="0"})
option:depends({network_mode="bridge",wifi_disabled="0"})
option:value("auto",translate("auto"))
for i=1,11 do
	option:value(i,i)
end
--@end

--# wifi encryption
option = s:option(ListValue,"wifi_encryption",translate("Encryption"))
option.margin = "30px"
option.default = "psk2"
option:depends("wifi_disabled","0")
option:value("wep","WEP")
option:value("psk","WPA+PSK")
option:value("psk2","WPA2+PSK")
option:value("none",translate("NONE"))

--# wifi wep encryption
option = s:option(ListValue,"wifi_wep",translate(" "))
option.margin = "30px"
option:depends("wifi_encryption","wep")
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

return m
