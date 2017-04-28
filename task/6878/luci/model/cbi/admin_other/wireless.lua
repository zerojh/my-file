m = Map("wireless","Wireless")
s = m:section(NamedSection,"wifi0","wifi-iface","")

option = s:option(ListValue,"disabled",translate("Status"))
option.rmempty = false
option:value("1",translate("Disable"))
option:value("0",translate("Enable"))

option = s:option(Value,"ssid",translate("SSID"))
option.rmempty = false
option.datatype = "uni_ssid"

option = s:option(ListValue,"encryption",translate("Encryption"))
option.default = "psk2"
option:value("none",translate("NONE"))
option:value("psk","WPA+PSK")
option:value("psk2","WPA2+PSK")

option = s:option(Value,"key",translate("Password"))
option.rmempty = false
option.datatype = "wifi_password"
option.password = true
option:depends("encryption","psk")
option:depends("encryption","psk2")
function option.cfgvalue(...)
	local key = m.uci:get("wireless","wifi0","key")
	return key or ""
end
function option.validate(self,value)
	local tmp = m:formvalue("cbid.wireless.wifi0.encryption")
	
	if tmp and tmp ~= "none" then
		return Value.validate(self,value)
	else
		m.uci:delete("wireless","wifi0","key")
		return value or ""
	end
end

return m

