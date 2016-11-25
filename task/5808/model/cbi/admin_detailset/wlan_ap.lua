local dsp = require "luci.dispatcher"
local uci = require "luci.model.uci".cursor()

m = Map("wireless","配置 / 无线热点")

s = m:section(NamedSection,"wifi0")

--#### Disabled ####--
option = s:option(ListValue,"disabled","启用热点")
option.rmempty = false
option:value("1",translate("Disable"))
option:value("0",translate("Enable"))
function option.validate(self, value)
	if value then
		m.uci:set("wireless","ra0","disabled",value)
		return Value.validate(self, value)
	else
		return ""
	end
end

--#### SSID ####--
option = s:option(Value,"ssid","热点名称")
option.rmempty = false
option.datatype = "uni_ssid"
option:depends("disabled","0")
function option.validate(self, value)
	if value then
		return Value.validate(self,value)
	else
		return ""
	end
end

--#### Encryption ####--
option = s:option(ListValue,"encryption","加密方式")
option.rmempty = false
option.default = "psk2"
option:value("psk","WPA+PSK")
option:value("psk2","WPA2+PSK")
option:value("none",translate("NONE"))
option:depends("disabled","0")
function option.validate(self, value)
	if value then
		return Value.validate(self,value)
	else
		return ""
	end
end

--#### Password ####--
option = s:option(Value,"key","密码")
option.rmempty = false
option.datatype = "wifi_password"
option.password = true
option:depends({disabled="0",encryption="psk"})
option:depends({disabled="0",encryption="psk2"})
function option.validate(self,value)
	if value then
		local tmp = m:formvalue("cbid.wireless.wifi0.encryption")
		
		if tmp ~= "none" then
			return Value.validate(self,value)
		else
			m.uci:delete("wireless","wifi0","key")
			return value or ""
		end
	else
		return ""
	end
end

option = s:option(ListValue,"wmm","无线多媒体扩展")
option.rmempty = false
option.default = "0"
option:value("0",translate("Off"))
option:value("1",translate("On"))
option:depends("disabled","0")
function option.validate(self, value)
	if value then
		return Value.validate(self,value)
	else
		return ""
	end
end

option = s:option(ListValue,"within_isolate","无线隔离")
option.rmempty = false
option.default = "0"
option:value("0",translate("Disable"))
option:value("1",translate("Enable"))
option:depends("disabled","0")
function option.validate(self, value)
	if value then
		return Value.validate(self,value)
	else
		return ""
	end
end

return m
