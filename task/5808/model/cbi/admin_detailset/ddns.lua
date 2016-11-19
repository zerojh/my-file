--@*******************************************
--文件描述:DDNS网页配置文件

--版本:V1.0
--@*******************************************
require "luci.model.network"
local fs = require "nixio.fs"
local dsp = require "luci.dispatcher"
local uci = require "luci.model.uci".cursor()

m = Map("ddns","配置 / 动态域名服务")

s = m:section(NamedSection,"myddns_ipv4","service",translate(""))
m.currsection = s
s.addremove = false
s.anonymous = true

local result = luci.util.exec("tail /tmp/log/ddns/myddns_ipv4.log")

if "1" ~= m.uci:get("ddns" , "myddns_ipv4" , "enabled") then
	--do nothing
elseif not fs.access("/usr/bin/wget") and not fs.access("/usr/bin/curl") then
	m.message = "error"..translate("DDNS kernel program missed, please upgrade system !")
elseif string.find(result,"CRITICAL ERROR =: Private or invalid or no IP") then
	local ip = result:match("CRITICAL ERROR =: Private or invalid or no IP '([0-9%.]+)' given")
	m.message = "error"..translatef("Device Address '%s' is a private or invalid IP ! DDNS can not to be updated !",ip)
elseif result:match("waiting =: 10 seconds for interfaces to fully come up\n$") then
	m.message = translate("Ready to connect DDNS Provider...")
elseif string.find(result,"bad address ") and not string.find(result,"via web") then
	local addr = result:match("bad address '(.+)'")
	m.message = "error"..translatef("Address '%s' can not be resolved, please check the address or DNS is correct !",addr)
elseif string.find(result,"DETECT =: Local IP\n%s*transfer prog =:.+'.+' 2>/dev/null\n$") then
	local url = result:match("detected via web at '(.+)'\n$") or result:match("transfer prog =:.+'(.+)' 2>/dev/null\n$")
	m.message = translatef("Detecting external address via IP Check URL '%s'",url)
elseif string.find(result,"ERROR =: detecting local IP %- retry") and (string.find(result,"detected via web") or string.find(result,"detected on network")) and not string.find(result,"DDNS Provider answered") and not string.find(result,"wget: bad address") then
	local retrycnt, retrytime = result:match("retry (%d)/5 in (%d+)")
	m.message = translate("Detecting IP address").." - "..translatef("retry in %d seconds (%d)",retrytime,retrycnt)
elseif result:match("local ip =: '%d+%.%d+%.%d+%.%d+' detected via web at '.+'\n%s*%*%*%*%*%*%* WAITING =: %d+ seconds %(Check Interval%) before continue\n$") or result:match("local ip =: '%d+%.%d+%.%d+%.%d+' detected on network 'wan'\n%s*%*%*%*%*%*%* WAITING =: %d+ seconds %(Check Interval%) before continue\n$")then
	local time = result:match("WAITING =: (%d+) seconds %(Check Interval%) before continue\n$")
	local local_ip = result:match("resolved ip =: '(%d+%.%d+%.%d+%.%d+)'")
	if local_ip and time then
		m.message = translatef("IP address doesn't change, will recheck in %s minutes !",time/60)
	end
elseif ((string.find(result,"transfer prog =:.+'.+' 2>/dev/null\n$") and not string.find(result,"DDNS Provider answered"))) and not string.find(result,"wget: bad address") then
	local url = result:match("transfer prog =:.+'(.+)' 2>/dev/null\n$")
	m.message = translatef("Connecting to DDNS Provider by '%s'",url)
elseif (string.find(result,"Connecting to ") and string.find(result,"error getting response: Connection reset by peer")) then
	local host = result:match("Connecting to (.+%))\n") or m.uci:get("ddns" , "myddns_ipv4" , "service_name") or ""
	local retrycnt, retrytime = result:match("retry (%d)/5 in (%d+)")
	if retrycnt and retrytime then
		m.message = "error"..translatef("Connecting to '%s' fail, connection reset by peer !",host).." - "..translatef("retry in %d seconds (%d)",retrytime,retrycnt)
	else
		m.message = "error"..translatef("Connecting to '%s' fail, connection reset by peer !",host)
	end
elseif (string.find(result,"Connecting to ") and string.find(result,"server returned error: HTTP/1.1 404 Not Found")) then
	local host = result:match("Connecting to (.+%))\n") or m.uci:get("ddns" , "myddns_ipv4" , "service_name") or ""
	local retrycnt, retrytime = result:match("retry (%d)/5 in (%d+)")
	if retrycnt and retrytime then
		m.message = "error"..translatef("Connecting to '%s' fail, DDNS Provider returned error: HTTP/1.1 404 Not Found !",host).." - "..translatef("retry in %d seconds (%d)",retrytime,retrycnt)
	else
		m.message = "error"..translatef("Connecting to '%s' fail, DDNS Provider returned error: HTTP/1.1 404 Not Found !",host)
	end
elseif string.find(result,"Error sending update to DDNS Provider") then
	local retrycnt, retrytime = result:match("retry (%d)/5 in (%d+)")
	if retrycnt and retrytime then
		m.message = "error"..translate("Error sending update to DDNS Provider !").." - "..translatef("retry in %d seconds (%d)",retrytime,retrycnt)
	else
		m.message = "error"..translate("Error sending update to DDNS Provider !")
	end
elseif string.find(result,"DDNS Provider answered") then
	local answer = result:match("DDNS Provider answered %[(.+)%]") or ""
	if "badauth" == answer then
		m.message = "error"..translate("Username or Password is not correct !")
	elseif "abuse" == answer then
		m.message = "DDNS update fail because requests too frequently !"
	elseif "nohost" == answer or "notfqdn" == answer or "numhost" == answer then
		local d = m.uci:get("ddns" , "myddns_ipv4" , "domain") or ""
		m.message = "error"..translatef("Domain '%s' doesn't exit !",d)
	elseif "good 127.0.0.1" == answer or "badagent" == answer then
		m.message = "error"..translate("Update url doesn't follow DDNS Provider's specifications !")
	elseif "good" == answer or "nochg" == answer or answer:match("good %d+%.%d+%.%d+%.%d+") or answer:match("nochg %d+%.%d+%.%d+%.%d+") then
		m.message = "succ"..translate("DDNS update success !")
	elseif "dnserr" == answer or "911" == answer then
		m.message = "error"..translate("There is a problem [%s] on DDNS Provider !",answer)
	elseif "" ~= answer then
		m.message = translatef("DDNS Provider Answered! [%s]",answer)
	end
elseif string.find(result,"nslookup: can't resolve") and not string.find(result,"START LOOP") then
	local host = result:match("nslookup: can't resolve '(.+)':") or ""
	local retrycnt, retrytime = result:match("retry (%d)/5 in (%d+)")
	if retrycnt and retrytime then
		m.message = "error"..translatef("Domain '%s' can not be resolved !",host).." - "..translatef("retry in %d seconds (%d)",retrytime,retrycnt)
	else
		m.message = "error"..translatef("Domain '%s' can not be resolved ! DDNS update fail !",host)
	end
elseif string.find(result,"detected via web at") and string.find(result,"wget: bad address") then                                  
		local web_url = result:match("detected via web at '(.+)'")                                                                              
		m.message = "error"..translatef("Can not get external address via IP Check URL '%s' !",web_url)
end

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
	"custom"
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
--@*******************************************
--#功能模块:设置DDNS服务器的开关

--#控件特性:下拉框
--@*******************************************
mode = s:option(ListValue , "enabled" , translate("DDNS Service"))
mode:value("0" , translate("Disable"))
mode:value("1" , translate("Enable"))

--@*******************************************
--#功能模块:选择DDNS服务商

--#控件特性:下拉框+文本框
--@*******************************************
service_list = s:option(ListValue , "service_name_list" , translate("Service Providers List"))
service_list:depends("enabled" , "1")
for k,v in ipairs(service_url_tbl) do
	service_list:value(v,translate(v))
end

function service_list.write(self,section,value)
	m.uci:set("ddns" , "myddns_ipv4" , "service_name_list" , value)
	if value ~= "custom" then
		m.uci:set("ddns" , "myddns_ipv4" , "service_name" , value)
	end
	m.uci:save("ddns")
end

service_custom = s:option(Value , "service_name" , translate("Service Providers"))
service_custom:depends("service_name_list" , "custom")
service_custom.rmempty = false
service_custom.datatype = "notempty"

function service_custom.write(self,section,value)
	local service_list_v = m.uci:get("ddns" , "myddns_ipv4" , "service_name_list")
	if service_list_v == "custom" then
		m.uci:set("ddns" , "myddns_ipv4" , "service_name" , value)
	end
	m.uci:save("ddns")
end

function service_custom.validate(self,value)
	local service_list= m.uci:get("ddns" , "myddns_ipv4" , "service_name_list")
	if service_list ~= "custom" then
		return value or ""
	else
		return  AbstractValue.validate(self, value)
	end
end

--@*******************************************
--#功能模块:填写自己的DDNS的域名

--#控件特性:文本框
--@*******************************************
domain = s:option(Value, "domain", translate("Domain"))
domain:depends("enabled" , "1")
domain.rmempty = false
domain.datatype = "domain"

function domain.validate(self,value)
	local value = m:formvalue("cbid.ddns.myddns_ipv4.domain")
	if value then
		return AbstractValue.validate(self, value)
	else
		return ""
	end
end

--@*******************************************
--#功能模块:满足用户要求自己填写update_url

--#控件特性:文本框
--@*******************************************
update_url = s:option(Value, "update_url", translate("Update Url"))
update_url:depends("service_name_list" , "custom")
update_url.rmempty = false
update_url.datatype = "notempty"

function update_url.validate(self,value)
	local value = m:formvalue("cbid.ddns.myddns_ipv4.update_url")
	if value then
		return AbstractValue.validate(self, value)
	else
		return ""
	end
end

--@*******************************************
--#功能模块:填写域名的用户名

--#控件特性:文本框
--@*******************************************
username = s:option(Value , "username" , translate("Username"))
username:depends("enabled" , "1")
username.rmempty = false
username.datatype = "notempty"

function username.validate(self,value)
	local value = m:formvalue("cbid.ddns.myddns_ipv4.username")
	if value then
		return AbstractValue.validate(self, value)
	else
		return ""
	end
end

--@*******************************************
--#功能模块:填写域名的密码

--#控件特性:文本框
--@*******************************************
password = s:option(Value , "password" , translate("Password"))
password:depends("enabled" , "1")
password.rmempty = false
password.password = true
password.datatype = "notempty"

function password.validate(self,value)
	local value = m:formvalue("cbid.ddns.myddns_ipv4.password")
	if value then
		return AbstractValue.validate(self, value)
	else
		return ""
	end
end

--@*******************************************
--#功能模块:提供本地IP地址获取方式

--#控件特性:文本框
--************************************************************   
ipsource = s:option(ListValue , "ip_source" , translate("IP Source"))
ipsource:depends("enabled" , "1")
ipsource:value("web" , translate("External Address"))
ipsource:value("network" , translate("Device Address"))


ipurl = s:option(Value , "ip_url" , translate("IP Check URL"))
ipurl:depends("ip_source" , "web")
ipurl.default = "http://checkip.dyndns.com"
ipurl.rmempty = false
for k,v in ipairs(ip_url_tbl) do
	ipurl:value(v,translate(v))
end
function ipurl.validate(self,value)
		return value or ""
end  
--@*******************************************
--#功能模块:填写检测本地IP周期
--#控件特性:文本框
--************************************************************   
check_local_ip_time = s:option(Value , "check_interval" , translate("IP Check Period(m)"))
check_local_ip_time:depends("enabled" , "1")
check_local_ip_time.datatype="max(4320)"
check_local_ip_time.default="10"

--@*******************************************
--#功能模块:填写服务器的刷新周期

--#控件特性:文本框                     
--************************************************************
update_service_ip_time = s:option(Value , "force_interval" , translate("Force Update Interval(h)"))
update_service_ip_time:depends("enabled" , "1") 
update_service_ip_time.datatype="max(168)"
update_service_ip_time.default = "72"

--@*******************************************
--#功能模块:填写失败重新更新IP的周期

--#控件特性:文本框
--************************************************************                                   
retry_time = s:option(Value , "retry_interval" , translate("Retry Interval When Fail(s)"))
retry_time:depends("enabled" , "1")
retry_time.datatype = "max(600)"
retry_time.default = "60"
 
return m
