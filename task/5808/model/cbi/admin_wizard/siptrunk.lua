local uci = require "luci.model.uci".cursor()

uci:check_cfg("endpoint_siptrunk")

if not uci:get("endpoint_siptrunk","1") then
	uci:section("endpoint_siptrunk","sip","1")
	uci:save("endpoint_siptrunk")
end

m = Map("endpoint_siptrunk",translate("Communication scheduling platform"))

s = m:section(NamedSection,"1","sip")

--#### Description #####----
option = s:option(DummyValue,"_desciption")
option.template = "admin_wizard/desc_sip_gateway"

--#### Address #####----
option = s:option(Value,"ipv4",translate("Address"))
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
option = s:option(Value,"port",translate("Port"))
option.datatype = "port"

--#### Username #####----
option = s:option(Value,"username",translate("Username"))
option.rmempty = false
option.datatype="notempty"

function option.write(self,section,value)
	m.uci:set("endpoint_siptrunk","1","username",value or "")
end

--#### Password #####----
option = s:option(Value,"password",translate("Password"))
option.password = true

return m
