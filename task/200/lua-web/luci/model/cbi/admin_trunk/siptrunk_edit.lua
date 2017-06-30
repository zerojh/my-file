local dsp = require "luci.dispatcher"
local uci = require "luci.model.uci".cursor()
local MAX_SIP_TRUNK = tonumber(uci:get("profile_param","global","max_sip_trunk") or '32')
local MAX_SIP_PROFILE = tonumber(uci:get("profile_param","global","max_sip_profile") or '16')

arg[1] = arg[1] or ""
arg[2] = arg[2] or ""

uci:check_cfg("profile_sip")
uci:check_cfg("endpoint_siptrunk")

local current_user = dsp.context.authuser
local profile_access = uci:get("user",current_user.."_web","profile_sip")

local current_section = arg[1]
if arg[2] == "edit" then
    m = Map("endpoint_siptrunk",translate("Trunk / SIP / Edit"))
else
    m = Map("endpoint_siptrunk",translate("Trunk / SIP / New"))
    m.addnew = true
    m.new_section = arg[1]
end

m.redirect = dsp.build_url("admin","trunk","sip")

if not m.uci:get(arg[1]) == "sip" then
	luci.http.redirect(m.redirect)
end

s = m:section(NamedSection,arg[1],"sip","")
m.currsection = s
s.addremove = false
s.anonymous = true

local this_index = uci:get("endpoint_siptrunk",arg[1],"index")
local sip_trunk = uci:get_all("endpoint_siptrunk") or {}
local sip_profile = uci:get_all("profile_sip") or {}

if arg[2] == "edit" then
	index = s:option(DummyValue,"index",translate("Index"))
else
	index = s:option(ListValue,"index",translate("Index"))
	for i=1,MAX_SIP_TRUNK do
		local flag = true
		for k,v in pairs(sip_trunk) do
			if v.index and tonumber(v.index) == i then
				flag = false
				break
			end
		end
		if flag == true or i == tonumber(this_index) then
			index:value(i,i)
		end
	end
end

name = s:option(Value,"name",translate("Name"))
name.rmempty = false
name.datatype = "cfgname"

ipv4 = s:option(Value,"ipv4",translate("Address"))
ipv4.rmempty = false
ipv4.datatype="abc_ip4addr_domain"
-- local str = ""
-- for k,v in pairs(sip_trunk) do
--     if  v.index ~= this_index and v.ipv4 then
--     	str = str..v.ipv4.."&"
--     end
-- end
-- str = "sipaddr("..str..")"
-- ipv4.datatype = str

port = s:option(Value,"port",translate("Port"))
--port.rmempty = false
port.datatype = "port"

outboundproxy = s:option(Value,"outboundproxy",translate("Outbound Proxy"))
outboundproxy.datatype="abc_ip4addr_domain"
function outboundproxy.validate(self, value)
	return luci.util.trim(value)
end

outboundproxy_port = s:option(Value,"outboundproxy_port",translate("Port"))
outboundproxy_port.datatype = "port"

transport = s:option(ListValue,"transport",translate("Transport"))
transport.default = "udp"
transport:value("tcp","TCP")
transport:value("udp","UDP")

register = s:option(ListValue,"register",translate("Register"))
register.default = "off"
register:value("off",translate("Off"))
register:value("on",translate("On"))

username = s:option(Value,"username",translate("Username"))
username:depends("register","on")
username.margin="30px"
username.rmempty = false
username.datatype="notempty"

function username.validate(self, value)
	if "on" == m:get(arg[1],"register") then
		return AbstractValue.validate(self, value)
	else
		m:del(arg[1],"username")
		return value or ""
	end
end

authusername = s:option(Value,"auth_username",translate("Auth Username"))
authusername:depends("register","on")
authusername.margin="30px"

password = s:option(Value,"password",translate("Password"))
password.password = true
password:depends("register","on")
password.margin="30px"

function password.validate(self, value)
	if "on" == m:get(arg[1],"register") then
		return AbstractValue.validate(self, value)
	else
		m:del(arg[1],"password")
		return value or ""
	end
end

fromusername = s:option(ListValue,"from_username",translate("From Header Username"))
fromusername:depends("register","on")
fromusername.margin="30px"
fromusername:value("username",translate("Username"))
fromusername:value("caller",translate("Caller"))

regurl = s:option(ListValue,"reg_url_with_transport",translate("Specify Transport Protocol on Register URL"))
regurl:depends("register","on")
regurl.margin="30px"
regurl:value("off",translate("Off"))
regurl:value("on",translate("On"))

expiresec = s:option(Value,"expire_seconds",translate("Expire Seconds"))
expiresec:depends("register","on")
expiresec.default = "1800"
expiresec.rmempty = false
expiresec.datatype = "range(5,99999)"
expiresec.margin="30px"
function expiresec.validate(self, value)
	if "on" == m:get(arg[1],"register") then
		return AbstractValue.validate(self, value)
	else
		m:del(arg[1],"expire_seconds")
		return value or ""
	end
end

retrysec = s:option(Value,"retry_seconds",translate("Retry Seconds"))
retrysec:depends("register","on")
retrysec.default = "60"
retrysec.rmempty = false
retrysec.datatype = "range(5,99999)"
retrysec.margin="30px"
function retrysec.validate(self, value)
	if "on" == m:get(arg[1],"register") then
		return AbstractValue.validate(self, value)
	else
		m:del(arg[1],"retry_seconds")
		return value or ""
	end
end

heartbeat = s:option(ListValue,"heartbeat",translate("Heartbeat"))
heartbeat.rmempty = false
heartbeat.default = "off"
heartbeat:value("off",translate("Off"))
heartbeat:value("on",translate("On"))

ping = s:option(Value,"ping",translate("Heartbeat Period(s)"))
ping:depends("heartbeat","on")
ping.margin = "32px"
ping.default = 5
ping.datatype = "range(5,99999)"
ping.margin="30px"

profile = s:option(ListValue,"profile",translate("SIP Profile"))
profile.rmempty = false
for i=1,MAX_SIP_PROFILE do
	for k,v in pairs(sip_profile) do
		if v.index and v.name then
			if tonumber(v.index) == i then
				profile:value(v.index,v.index.."-< "..v.name.." >")
				break
			end
		else
			uci:delete("profile_sip",k)
			uci:save("profile_sip")
		end
	end
end
if "admin" == current_user or (profile_access and profile_access:match("edit")) then
	local continue_param = "trunk-sip-"..arg[1].."-"..arg[2]
	if arg[3] then
		continue_param = continue_param .. ";" .. arg[3]
	end
	profile:value("addnew_profile_sip/"..continue_param,translate("< Add New ...>"))
	function profile.cfgvalue(...)
		local v = m.uci:get("endpoint_siptrunk",current_section, "profile")
		if v and v:match("^addnew") then
			m.uci:revert("endpoint_siptrunk",current_section, "profile")
			v = m.uci:get("endpoint_siptrunk",current_section, "profile")
		end
		return v
	end
end
sip_status = s:option(ListValue,"status",translate("Status"))
sip_status.rmempty = false
sip_status:value("Enabled",translate("Enable"))
sip_status:value("Disabled",translate("Disable"))

return m
