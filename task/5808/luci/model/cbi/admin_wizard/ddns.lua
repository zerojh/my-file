local uci = require "luci.model.uci".cursor()
local uci_tmp = require "luci.model.uci".cursor("/tmp/config")
local dsp = require "luci.dispatcher"
local flag = uci_tmp:get("wizard","globals","ddns") or "1"

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

local ip_url_tbl =
{
	"http://checkip.dyndns.com",
	"http://ip.changeip.com",
	"http://checkip.dns.he.net",
	"http://checkip.dyndns.it",
	"http://myip.dnsomatic.com",
	"http://www.3322.net/dyndns/getip",
	"http://www.myip.ch",
	"http://checkip.twodns.de",
	"http://ddns.oray.com/checkip",
	"http://city.ip138.com/ip2city.asp"
}

m = Map("ddns","动态域名服务")
m.pageaction = false

if luci.http.formvalue("cbi.cancel") then
	if uci:get("wireless","wifi0","mode") ~= "sta" then
		m.redirect = dsp.build_url("admin","wizard","ap")
	else
		m.redirect = dsp.build_url("admin","wizard","ddns")
	end
elseif luci.http.formvalue("cbi.save") then
	flag = "1"
	uci_tmp:set("wizard","globals","ddns","1")
	uci_tmp:save("wizard")
	uci_tmp:commit("wizard")
	m.redirect = dsp.build_url("admin","wizard","pptp")
end

s = m:section(NamedSection,"myddns_ipv4","service","")
s.addremove = false
s.anonymous = true

--#### Description #####----
option = s:option(DummyValue,"_description")
option.template = "admin_wizard/description"
option.data = {}
table.insert(option.data,"此处可选择是否启动动态域名服务．")
table.insert(option.data,"如果启用动态域名服务，可以实现网页输入字段如＂www.xxx.com＂登入本设备网页．")

--#### Enable #####----
option = s:option(ListValue,"enabled","启动动态域名服务")
option:value("0" , "禁用")
option:value("1" , "启用")
function option.cfgvalue(self, section)
	if flag == "1" then
		return AbstractValue.cfgvalue(self, section)
	else
		return nil
	end
end

--#### Service #####----
option = s:option(ListValue,"service_name_list","服务商列表")
option.rmempty = false
option:depends("enabled" , "1")
for k,v in ipairs(service_url_tbl) do
	option:value(v,translate(v))
end
function option.cfgvalue(self, section)
	if flag == "1" then
		return AbstractValue.cfgvalue(self, section)
	else
		return nil
	end
end
function option.validate(self,value)
	if value then
		return AbstractValue.validate(self, value)
	else
		return ""
	end
end
function option.write(self,section,value)
	m.uci:set("ddns" , "myddns_ipv4" , "service_name_list" , value)
	if value ~= "custom" then
		m.uci:set("ddns" , "myddns_ipv4" , "service_name" , value)
	end
	m.uci:save("ddns")
end

option = s:option(Value,"domain","域名")
option:depends("enabled" , "1")
option.rmempty = false
option.datatype = "domain"
function option.cfgvalue(self, section)
	if flag == "1" then
		return AbstractValue.cfgvalue(self, section)
	else
		return nil
	end
end
function option.validate(self,value)
	if value then
		return AbstractValue.validate(self, value)
	else
		return ""
	end
end

option = s:option(Value,"username","用户名")
option:depends("enabled" , "1")
option.rmempty = false
option.datatype = "notempty"
function option.cfgvalue(self, section)
	if flag == "1" then
		return AbstractValue.cfgvalue(self, section)
	else
		return nil
	end
end
function option.validate(self,value)
	if value then
		return AbstractValue.validate(self, value)
	else
		return ""
	end
end

option = s:option(Value,"password","密码")
option:depends("enabled" , "1")
option.rmempty = false
option.password = true
option.datatype = "notempty"
function option.cfgvalue(self, section)
	if flag == "1" then
		return AbstractValue.cfgvalue(self, section)
	else
		return nil
	end
end
function option.validate(self,value)
	local value = m:formvalue("cbid.ddns.myddns_ipv4.password")

	if m:formvalue("cbid.ddns.myddns_ipv4.enabled") == "1" then
		m.uci:set("ddns","myddns_ipv4","check_interval","10")
		m.uci:set("ddns","myddns_ipv4","force_interval","72")
		m.uci:set("ddns","myddns_ipv4","retry_interval","60")
	end

	if value then
		return AbstractValue.validate(self, value)
	else
		return ""
	end
end
function option.write(self,section,value)
	m.uci:set("ddns","myddns_ipv4","password",value or "")
end

option = s:option(ListValue , "ip_source" , "IP来源")
option.rmempty = false
option:depends("enabled" , "1")
option:value("web" , "外部地址")
option:value("network" , "设备地址")
function option.cfgvalue(self, section)
	if flag == "1" then
		return AbstractValue.cfgvalue(self, section)
	else
		return nil
	end
end
function option.validate(self,value)
	return value or ""
end

option = s:option(Value , "ip_url" , "IP检查地址")
option:depends("ip_source" , "web")
option.default = "http://checkip.dyndns.com"
option.rmempty = false
for k,v in ipairs(ip_url_tbl) do
	option:value(v,translate(v))
end
function option.cfgvalue(self, section)
	if flag == "1" then
		return AbstractValue.cfgvalue(self, section)
	else
		return nil
	end
end
function option.validate(self,value)
	return value or ""
end

option = s:option(DummyValue,"_footer")
option.template = "admin_wizard/footer"

return m
