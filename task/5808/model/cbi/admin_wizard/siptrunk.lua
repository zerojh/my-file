local uci = require "luci.model.uci".cursor()
local dsp = require "luci.dispatcher"

uci:check_cfg("endpoint_siptrunk")

if not uci:get("endpoint_siptrunk","main_trunk") then
	uci:section("endpoint_siptrunk","sip","main_trunk")
	uci:save("endpoint_siptrunk")
end

m = Map("endpoint_siptrunk",translate("通讯调度平台"))
m.pageaction = false

if luci.http.formvalue("cbi.cancel") then
	m.redirect = dsp.build_url("admin","wizard","2")
elseif luci.http.formvalue("cbi.save") then
	m.redirect = dsp.build_url("admin","wizard","4")
end

s = m:section(NamedSection,"1","sip")

--#### Description #####----
option = s:option(DummyValue,"_description")
option.template = "admin_wizard/description"
option.data = {}
table.insert(option.data,"此处填写本设备要连接通讯调度平台的信息，连接成功方可与远端号码通话．")

--#### Address #####----
option = s:option(Value,"ipv4","服务器地址")
option.rmempty = false
option.datatype="abc_ip4addr_domain"

function option.validate(self,value)
	m.uci:set("endpoint_siptrunk","1","expire_seconds","1800")
	m.uci:set("endpoint_siptrunk","1","from_username","username")
	m.uci:set("endpoint_siptrunk","1","heartbeat","off")
	m.uci:set("endpoint_siptrunk","1","index","1")
	m.uci:set("endpoint_siptrunk","1","name","1")
	m.uci:set("endpoint_siptrunk","1","profile","2")
	m.uci:set("endpoint_siptrunk","1","reg_url_with_transport","off")
	m.uci:set("endpoint_siptrunk","1","register","on")
	m.uci:set("endpoint_siptrunk","1","retry_seconds","60")
	m.uci:set("endpoint_siptrunk","1","status","Enabled")
	m.uci:set("endpoint_siptrunk","1","transport","udp")

	return Value.validate(self, value)
end

--#### Port #####----
option = s:option(Value,"port","服务器端口")
option.datatype = "port"

--#### Username #####----
option = s:option(Value,"username","用户名")
option.rmempty = false
option.datatype="notempty"

function option.write(self,section,value)
	m.uci:set("endpoint_siptrunk","1","username",value or "")
end

--#### Password #####----
option = s:option(Value,"password","密码")
option.password = true

option = s:option(DummyValue,"_footer")
option.template = "admin_wizard/footer"

return m
