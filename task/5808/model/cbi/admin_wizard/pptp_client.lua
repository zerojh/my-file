local fs = require "nixio.fs"
local ut = require "luci.util"
local uci = require "luci.model.uci".cursor()

uci:check_cfg("pptpc")

m = Map("pptpc",translate(""), translate(""))

s = m:section(TypedSection,"pptpc","")
s.addremove = false
s.anonymous = true
s.useable = false

option = s:option(ListValue,"enabled",translate("Status"))
option:value("1",translate("Enable"))
option:value("0",translate("Disable"))

function option.write(self,section,value)
	m.uci:set("pptpc","main","enabled",value)
	m.uci:set("qos","qos_pptp1","enabled",(uci:get("pptpd","pptpd","enabled") == "1" or value == "1" ) and "1" or "0")
	m.uci:set("qos","qos_pptp2","enabled",(uci:get("pptpd","pptpd","enabled") == "1" or value == "1" ) and "1" or "0")
end

function option.validate(self,value)
	m.uci:set("pptpc","main","defaultroute","0")
	return Value.validate(self, value)
end

option = s:option(ListValue,"mppe",translate("Data Encryption"))
option:value("0",translate("Disable"))
option:value("1",translate("Enable"))
option.default = "1"

option = s:option(Value,"server",translate("Server Address"))
option.rmempty = false
option.datatype = "abc_ip4addr_domain"

option = s:option(Value,"username",translate("Username"))
option.rmempty = false
option.datatype = "notempty"

option = s:option(Value,"password",translate("Password"))
option.password = true
option.rmempty = false
option.datatype = "length(3,32)"

return m
