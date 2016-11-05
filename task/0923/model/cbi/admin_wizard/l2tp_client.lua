local fs = require "nixio.fs"
local ut = require "luci.util"
local uci = require "luci.model.uci".cursor()

uci:check_cfg("xl2tpd")

m = Map("xl2tpd",translate(""), translate(""))

s = m:section(TypedSection,"l2tpc","")
s.addremove = false
s.anonymous = true
s.useable = false

option = s:option(ListValue,"enabled",translate("Status"))
option:value("1",translate("Enable"))
option:value("0",translate("Disable"))

function option.write(self,section,value)
	m.uci:set("xl2tpd","main","enabled",value)
	m.uci:set("qos","qos_l2tp1","enabled",(uci:get("xl2tpd","l2tpd","enabled") == "1" or value == "1" ) and "1" or "0")
	m.uci:set("qos","qos_l2tp2","enabled",(uci:get("xl2tpd","l2tpd","enabled") == "1" or value == "1" ) and "1" or "0")
end
function option.validate(self, value)
	m.uci:set("xl2tpd","main","defaultroute","0")
	return Value.validate(self, value)
end

option = s:option(Value,"server",translate("Server Address"))
option.rmempty = false
option.datatype = "abc_ip4addr_domain"

option = s:option(Value,"username",translate("Username"))
option.rmempty = false
option.datatype = "notempty"

option = s:option(Value,"password",translate("Password"))
option.password = true
option.rmempty = false
option.datatype = "password"
option.datatype = "length(3,32)"

return m
