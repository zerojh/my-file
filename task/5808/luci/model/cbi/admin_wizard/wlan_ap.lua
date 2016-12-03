local dsp = require "luci.dispatcher"
local uci = require "luci.model.uci".cursor()
local uci_tmp = require "luci.model.uci".cursor("/tmp/config")
local flag = uci_tmp:get("wizard","globals","ap") or "1"

if uci:get("wireless","wifi0","mode") == "sta" then
	luci.http.redirect(dsp.build_url("admin","affair","overview"))
end

m = Map("wireless","无线热点")
m.pageaction = false

if luci.http.formvalue("cbi.cancel") then
	m.redirect = dsp.build_url("admin","wizard","sim")
elseif luci.http.formvalue("cbi.save") then
	flag = "1"
	uci_tmp:set("wizard","globals","ap","1")
	uci_tmp:save("wizard")
	uci_tmp:commit("wizard")
	m.redirect = dsp.build_url("admin","wizard","ddns")
end

s = m:section(NamedSection,"wifi0")

--#### Description #####----
option = s:option(DummyValue,"_description")
option.template = "admin_wizard/description"
option.data = {}
table.insert(option.data,"此处可选择是否使用无线热点．")
table.insert(option.data,"")

--#### Disabled ####----
option = s:option(ListValue,"disabled","启用热点")
option.rmempty = false
option.default = "0"
option:value("1",translate("Disable"))
option:value("0",translate("Enable"))
function option.cfgvalue(self, section)
	if flag == "1" then
		return AbstractValue.cfgvalue(self, section)
	else
		return nil
	end
end
function option.validate(self, value)
	m.uci:set("wireless","ra0","disabled",value)
	return Value.validate(self, value)
end

--#### SSID ####----
option = s:option(Value,"ssid","热点名称")
option.rmempty = false
option.datatype = "uni_ssid"
option:depends("disabled","0")
function option.cfgvalue(self, section)
	if flag == "1" then
		return AbstractValue.cfgvalue(self, section)
	else
		return nil
	end
end
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
function option.cfgvalue(self, section)
	if flag == "1" then
		return AbstractValue.cfgvalue(self, section)
	else
		return nil
	end
end
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
function option.cfgvalue(self, section)
	if flag == "1" then
		return AbstractValue.cfgvalue(self, section)
	else
		return nil
	end
end
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

option = s:option(DummyValue,"_footer")
option.template = "admin_wizard/footer"

return m
