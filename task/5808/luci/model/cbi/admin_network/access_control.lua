local uci = require "luci.model.uci".cursor()

m = Map("lucid", translate("Network / Access Control"))
m:chain("system")
m:chain("dropbear")
m:chain("firewall")
m:chain("telnet")

local existports = ""
for k,v in pairs(uci:get_all("profile_sip") or {}) do
	if v.localport then
		existports = existports..v.localport.."&"
	end
end
existports = existports.."8021".."&"
existports = existports.."53".."&"
existports = existports..(uci:get("callcontrol","voice","rtp_start_port") or "16000").."-"..(uci:get("callcontrol","voice","rtp_end_port") or "16200")

s = m:section(NamedSection,"main","lucid", translate("Web Server"))
s.anonymous = true
s.addremove = false

--o = s:option(Value, "_http", translate("HTTP Port"))
--o.datatype = "serviceport("..existports..")"
--o.rmempty = false
--
--function o.cfgvalue(...)
--	local value = ""
--	local addr = m.uci:get_list("lucid", "http", "address")
--	for k,v in ipairs(addr) do
--		value = value .. v
--	end
--	return value
--end
--
--function o.write(self, section, value)
--	m.uci:set("lucid", "http", "address", value)
--end

--# Allow WAN http
o = s:option(Flag,"http_enable","允许WAN口访问HTTP端口")
function o.cfgvalue(...)
	return m.uci:get("firewall","defaults","enabled_http") or "0"
end
function o.parse(self,section,value)
	local value = m:formvalue("cbid.lucid.main.http_enable")
	m.uci:set("firewall","defaults","enabled_http",value or "0")
end

--o = s:option(Value, "_https", translate("HTTPS Port"))
--o.datatype = "serviceport("..existports..")"
--o.rmempty = false
--
--function o.cfgvalue(...)
--	local value = ""
--	local addr = m.uci:get_list("lucid", "https", "address")
--	for k,v in ipairs(addr) do
--		value = value .. v
--	end
--	return value
--end
--
--function o.write(self, section, value)
--	m.uci:set_list("lucid", "https", "address", value)
--end

--# Allow WAN https
o = s:option(Flag,"https_enable","允许WAN口访问HTTPS端口")
function o.cfgvalue(...)
	return m.uci:get("firewall","defaults","enabled_https") or "0"
end
function o.parse(self,section,value)
	local value = m:formvalue("cbid.lucid.main.https_enable")
	m.uci:set("firewall","defaults","enabled_https",value or "0")
end

o = s:option(Flag,"enable_8345","允许WAN口访问8345端口")
function o.cfgvalue(...)
	return m.uci:get("firewall","defaults","enabled_8345") or "0"
end
function o.parse(self,section,value)
	local value = m:formvalue("cbid.lucid.main.enable_8345")
	m.uci:set("firewall","defaults","enabled_8345",value or "0")
end

--o = s:option(Flag,"enable_8848","允许WAN口访问8848端口")
--function o.cfgvalue(...)
--	return m.uci:get("firewall","defaults","enabled_8848") or "0"
--end
--function o.parse(self,section,value)
--	local value = m:formvalue("cbid.lucid.main.enable_8848")
--	m.uci:set("firewall","defaults","enabled_8848",value or "0")
--end

s = m:section(NamedSection,"main","lucid",translate("Telnet"))
s.anonymous = true
s.addremove = false

o = s:option(Flag, "action", translate("Enable"))

function o.cfgvalue(...)
	return ((m.uci:get("system", "telnet", "action") or "off") == "on") and "1" or "0"
end

function o.parse(self, section, value)
	local value = m:formvalue("cbid.lucid.main.action")
	m.uci:set("system", "telnet", "action", ((value == "1") and "on" or "off"))
	m.uci:set("telnet", "telnet", "action", ((value == "1") and "on" or "off"))
end

--o = s:option(Value, "_telnet", translate("Port"))
--o:depends("action","1")
--o.datatype = "serviceport("..existports..")"
--o.rmempty = false
--
--function o.cfgvalue(...)
--	return m.uci:get("system", "telnet", "port")
--end
--
--function o.validate(self, value)
--	if "1" == m.uci:get("system","telnet","action") then
--		return AbstractValue.validate(self, value)
--	else
--		return value or "23"
--	end
--end
--
--function o.write(self, section, value)
--	m.uci:set("system", "telnet", "port", value)
--	m.uci:set("telnet", "telnet", "port", value)
--end

--# Allow WAN enable
o = s:option(Flag,"telnet_enable",translate("Allow WAN access"))
o:depends("action","1")
function o.cfgvalue(...)
	return m.uci:get("firewall","defaults","enabled_telnet") or "0"
end
function o.parse(self,section,value)
	local value = m:formvalue("cbid.lucid.main.telnet_enable")
	m.uci:set("firewall","defaults","enabled_telnet",value or "0")
end

--@ SSH
s = m:section(NamedSection,"main","lucid", translate("SSH"))
s.anonymous = true
s.addremove = false
--
--o = s:option(Value, "_ssh", translate("Port"))
--o.datatype = "serviceport("..existports..")"
--o.rmempty = false
--
--function o.cfgvalue(...)
--	return m.uci:get("dropbear", "main", "Port")
--end
--
--function o.write(self, section, value)
--	m.uci:set("dropbear", "main", "Port", value)
--end

--# Allow WAN ssh
o = s:option(Flag,"ssh_enable",translate("Allow WAN access"))
function o.cfgvalue(...)
	return m.uci:get("firewall","defaults","enabled_ssh") or "0"
end
function o.parse(self,section,value)
	local value = m:formvalue("cbid.lucid.main.ssh_enable")
	m.uci:set("firewall","defaults","enabled_ssh",value or "0")
end

return m
