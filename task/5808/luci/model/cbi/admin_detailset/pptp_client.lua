local fs = require "nixio.fs"
local ut = require "luci.util"
local uci = require "luci.model.uci".cursor()
local uci_tmp = require "luci.model.uci".cursor("/tmp/config")

uci:check_cfg("pptpc")

m = Map("pptpc","")
m:chain("xl2tpd")
m:chain("openvpn")

s = m:section(TypedSection,"pptpc","")
s.addremove = false
s.anonymous = true
s.useable = false

option = s:option(ListValue,"enabled","启动PPTP服务")
option:value("0",translate("Disable"))
option:value("1",translate("Enable"))
function option.write(self,section,value)
	m.uci:set("pptpc","main","enabled",value)
	m.uci:set("qos","qos_pptp1","enabled",(uci:get("pptpd","pptpd","enabled") == "1" or value == "1" ) and "1" or "0")
	m.uci:set("qos","qos_pptp2","enabled",(uci:get("pptpd","pptpd","enabled") == "1" or value == "1" ) and "1" or "0")
end
function option.validate(self, value)
	if value == "1" then
		m.uci:set("xl2tpd","main","enabled","0")
		m.uci:set("openvpn","custom_config","enabled","0")
		uci_tmp:set("wizard","globals","vpntype","pptp")
		uci_tmp:delete("wizard","globals","vpnread")
		uci_tmp:save("wizard")
		uci_tmp:commit("wizard")
	end
	return Value.validate(self, value)
end

option = s:option(ListValue,"defaultroute","默认路由")
option:depends("enabled","1")
option.rmempty = false
option:value("0",translate("Disable"))
option:value("1",translate("Enable"))
option.default = "0"
function option.validate(self, value)
	if value then
		return Value.validate(self,value)
	else
		return ""
	end
end

option = s:option(ListValue,"mppe","数据加密")
option:depends("enabled","1")
option.rmempty = false
option:value("0",translate("Disable"))
option:value("1",translate("Enable"))
option.default = "1"
function option.validate(self, value)
	if value then
		return Value.validate(self,value)
	else
		return ""
	end
end

option = s:option(Value,"server","服务器地址")
option:depends("enabled","1")
option.rmempty = false
option.datatype = "abc_ip4addr_domain"
function option.validate(self, value)
	if value then
		return Value.validate(self,value)
	else
		return ""
	end
end

option = s:option(Value,"username","用户名")
option:depends("enabled","1")
option.rmempty = false
option.datatype = "notempty"
function option.validate(self, value)
	if value then
		return Value.validate(self,value)
	else
		return ""
	end
end

option = s:option(Value,"password","密码")
option:depends("enabled","1")
option.password = true
option.rmempty = false
option.datatype = "length(3,32)"
function option.validate(self, value)
	if value then
		return Value.validate(self,value)
	else
		return ""
	end
end

return m
