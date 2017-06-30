local fs = require "nixio.fs"
local util = require "luci.util"
local uci = require "luci.model.uci".cursor()

if luci.version.license and luci.version.license.volte then
	m = Map("network",translate("Network / VoLTE Config"))
else
	m = Map("network",translate("Network / LTE Config"))
end
m:chain("endpoint_mobile")

local gsm_section
for k,v in pairs(uci:get_all("endpoint_mobile") or {}) do
	if v.slot_type == "1-LTE" or v.slot_type == "1-VOLTE" then
		gsm_section = k
		break
	end
end

if not gsm_section or (not uci:get_all("network","wan2"))then
	uci:create_section("network","interface","wan2",{ifname="ppp0",disabled="0",userdisabled="0",proto="3g",device="/dev/ttyUSB3",apn="cmnet",dialnumber="*99#",service="umts",metric="20",hostname="UC200"})
end

s = m:section(NamedSection,"wan2","interface")

option = s:option(DummyValue,"cur_mode",translate("Current Mode"))
function option.cfgvalue(...)
	local ret_str 
	local tmp = util.exec("fs_cli -x 'gsm dump list'")
	
	ret_str = tmp:match("lte_mode%s*=%s*([a-zA-Z0-9]+)\n") or translate("UNKNOWN")
	
	return ret_str
end

option = s:option(ListValue,"disabled",translate("Status"))
option:value("0",translate("Enabled"))
option:value("1",translate("Disabled"))
function option.write(self,section,value)
	if value then
		m.uci:set("network","wan2","disabled",value)
		m.uci:set("network","wan2","userdisabled",value)
	end
end

option = s:option(Value,"apn",translate("APN"))
option.rmempty = false
option.default = "3gnet"
option:value("3gnet","3GNET")
option:value("cmnet","cmnet")

option = s:option(Value,"username",translate("Username"))

option = s:option(Value,"password",translate("Password"))
option.password = true

option = s:option(ListValue,"lte_mode",translate("Mode"))
option:value("auto",translate("Auto"))
option:value("4g","4G")
option:value("2g-3g","2G & 3G")

function option.cfgvalue(...)
	local ret_str = "auto"
	
	if gsm_section then
		ret_str = m.uci:get("endpoint_mobile",gsm_section,"lte_mode") or "auto"
	end

	return ret_str
end
function option.write(self,section,value)
	if gsm_section then
		m.uci:set("endpoint_mobile",gsm_section,"lte_mode",value)
	end
end

pin_code = s:option(Value,"pincode",translate("PIN Code"))
pin_code.datatype = "pincode"
function pin_code.cfgvalue(...)	
	if gsm_section then
		ret_str = m.uci:get("endpoint_mobile",gsm_section,"pincode") or ""
	end

	return ret_str
end

function pin_code.write(self,section,value)
	if gsm_section then
		m.uci:set("endpoint_mobile",gsm_section,"pincode",value)
	end
end

option = s:option(Value,"dialnumber",translate("Dial Number"))
option.rmempty = false

option = s:option(Value,"service",translate("Service"))

--option = s:option(Value,"metric",translate("Metric"))
--option.rmempty = false
--local tmp_val_diff_str = "10&"
--for i=1,8 do
--	if uci:get("network","vwan"..i,"metric") and  "vwan"..i ~= this_section then
--		tmp_val_diff_str = tmp_val_diff_str..uci:get("network","vwan"..i,"metric").."&"
--	end
--end
--option.datatype = "numberdiff("..tmp_val_diff_str..")"
--function option.validate(self,value)
--	local tmp_disabled = m:formvalue("cbid.network.wan2.disabled")
--
--	if tmp_disabled == "1" then
--		self.datatype = nil
--		
--		return value or ""
--	else
--		return Value.validate(self,value)
--	end
--end

return m
