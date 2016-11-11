local fs = require "nixio.fs"
local ut = require "luci.util"
local uci = require "luci.model.uci".cursor()
local dsp = require "luci.dispatcher"

uci:check_cfg("xl2tpd")

m = Map("xl2tpd",translate(""), translate(""))
m.pageaction = false

if luci.http.formvalue("cbi.cancel") then
	m.redirect = dsp.build_url("admin","wizard","4")
elseif luci.http.formvalue("cbi.save") then
	m.redirect = dsp.build_url("admin","status","overview")
end

s = m:section(TypedSection,"l2tpc","")
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
option = s:option(ListValue,"enabled","启动L2TP服务")
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
option.datatype = "password"
option.datatype = "length(3,32)"

option = s:option(DummyValue,"_footer")
option.template = "admin_wizard/footer"

return m
