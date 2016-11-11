local fs = require "nixio.fs"
local ut = require "luci.util"
local uci = require "luci.model.uci".cursor()
local dsp = require "luci.dispatcher"

uci:check_cfg("pptpc")

m = Map("pptpc",translate(""), translate(""))
m.pageaction = false

if luci.http.formvalue("cbi.cancel") then
	m.redirect = dsp.build_url("admin","wizard","4")
elseif luci.http.formvalue("cbi.save") then
	m.redirect = dsp.build_url("admin","status","overview")
end

s = m:section(TypedSection,"pptpc","")
s.addremove = false
s.anonymous = true
s.useable = false

--#### Description #####----
option = s:option(DummyValue,"_description")
option.template = "admin_wizard/description"
option.data = {}
table.insert(option.data,"此处可选择是否启动VPN客户端，启动VPN可以实现通话数据加密．")
table.insert(option.data,"")
table.insert(option.data,"本设备支持＂PPTP＂、＂L2TP＂、＂OpenVPN＂三种客户端连接方式＂．")

--#### Enabled #####----
option = s:option(ListValue,"enabled","启动PPTP服务")
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

--#### Data Encryption #####----
option = s:option(ListValue,"mppe","数据加密")
option:value("0",translate("Disable"))
option:value("1",translate("Enable"))
option.default = "1"

--#### server #####----
option = s:option(Value,"server","服务器地址")
option.rmempty = false
option.datatype = "abc_ip4addr_domain"

--#### username #####----
option = s:option(Value,"username","用户名")
option.rmempty = false
option.datatype = "notempty"

--#### password #####----
option = s:option(Value,"password","密码")
option.password = true
option.rmempty = false
option.datatype = "length(3,32)"

option = s:option(DummyValue,"_footer")
option.template = "admin_wizard/footer"

return m
