local uci = require "luci.model.uci".cursor()

local service_url_tbl = 
{
	"dyn.com",
	"changeip.com",
	"he.net",
	"ovh.com",
	"dnsomatic.com",
	"3322.org",
	"easydns.com",
	"twodns.de",
	"oray.com",
}

m = Map("ddns",translate("DDNS"))
s = m:section(NamedSection,"myddns_ipv4","service",translate(""))
m.currsection = s
s.addremove = false
s.anonymous = true

--#### Description #####----
option = s:option(DummyValue,"_desciption")
option.template = "admin_wizard/desc_ddns"

--#### Enable #####----
option = s:option(ListValue ,"enabled" ,translate("Enable DDNS Service"))
option:value("0" , translate("Disable"))
option:value("1" , translate("Enable"))

--#### Service #####----
option = s:option(ListValue , "service_name_list" , translate("Service Providers List"))
option:depends("enabled" , "1")
for k,v in ipairs(service_url_tbl) do
	option:value(v,translate(v))
end

function option.write(self,section,value)
	m.uci:set("ddns" , "myddns_ipv4" , "service_name_list" , value)
	if value ~= "custom" then
		m.uci:set("ddns" , "myddns_ipv4" , "service_name" , value)
	end
	m.uci:save("ddns")
end

option = s:option(Value, "domain", translate("Domain"))
option:depends("enabled" , "1")
option.rmempty = false
option.datatype = "domain"

function option.validate(self,value)
	local value = m:formvalue("cbid.ddns.myddns_ipv4.domain")
	if value then
		return AbstractValue.validate(self, value)
	else
		return ""
	end
end

option = s:option(Value , "username" , translate("Username"))
option:depends("enabled" , "1")
option.rmempty = false
option.datatype = "notempty"

function option.validate(self,value)
	local value = m:formvalue("cbid.ddns.myddns_ipv4.username")
	if value then
		return AbstractValue.validate(self, value)
	else
		return ""
	end
end

option = s:option(Value , "password" , translate("Password"))
option:depends("enabled" , "1")
option.rmempty = false
option.password = true
option.datatype = "notempty"

function option.validate(self,value)
	local value = m:formvalue("cbid.ddns.myddns_ipv4.password")

	m.uci:set("ddns","myddns_ipv4","check_interval","10")
	m.uci:set("ddns","myddns_ipv4","force_interval","72")
	m.uci:set("ddns","myddns_ipv4","retry_interval","60")

	if value then
		return AbstractValue.validate(self, value)
	else
		return ""
	end
end

function option.write(self,section,value)
	m.uci:set("ddns","myddns_ipv4","password",value or "")

end

return m
