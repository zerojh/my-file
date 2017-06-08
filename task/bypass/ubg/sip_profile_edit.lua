--[[
@file sip_add.lua
@brief config web for sip profile
@version 1.0
@author harlan
@date 2014.04.16
]]--

local dsp = require "luci.dispatcher"
local uci = require "luci.model.uci".cursor()
local fs = require "luci.fs"
local max_count = tonumber(uci:get("profile_param","global","max_sip_profile") or '8')

this_section = arg[1] or ""
arg[2] = arg[2] or ""

uci:check_cfg("profile_sip")
uci:check_cfg("profile_codec")

if arg[2] == "edit" then
    m = Map("profile_sip",translate("SIP Profile / Edit"))
else
    m = Map("profile_sip",translate("SIP Profile / New"))
    m.addnew = true
    m.new_section = this_section
end
local current_section = arg[1]
if arg[3] then
	m.saveaction = false
	m.redirect = m:gen_redirect(arg[3])
else
	m.redirect = dsp.build_url("admin","profile","sip","profile")
end

if not m.uci:get(this_section) == "sip" then
	luci.http.redirect(m.redirect)
end

s = m:section(NamedSection,this_section,"sip","")
m.currsection = s
s.addremove = false
s.anonymous = true

local this_index = uci:get("profile_sip",this_section,"index")
local profile = uci:get_all("profile_sip") or {}

if arg[2] == "edit" then
	index = s:option(DummyValue,"index",translate("Index"))
else
	index = s:option(ListValue,"index",translate("Index"))
	index.rmempty = false
	for i=1,max_count do
		local flag = true
		for k,v in pairs(profile) do
			if v["index"] and tonumber(v["index"]) == i then
				flag = false
				break
			end
		end

		if flag == true or i == tonumber(this_index) then
			index:value(i,i)
		end
	end
end
--
--
name = s:option(Value,"name",translate("Name"))
name.rmempty = false
local name_list_str = "*&"
for k,v in pairs(profile) do
	if v.name and k ~= this_section then
		name_list_str = name_list_str..v.name.."&"
	end
end
name.datatype = "username("..name_list_str..")"

localinterface = s:option(ListValue,"localinterface",translate("Local Listening Interface"))
local network_profile = uci:get_all("network") or {}
for k,v in pairs(network_profile) do
	if "interface" == v['.type'] then
		if k == "wan" or k == "lan" then
			localinterface:value(k,string.upper(k))
		elseif k == "wan2" then
			if fs.access("/dev/ttyUSB0") then		
				localinterface:value(k,"LTE")
			end
		elseif k:match("^vwan") and v.name then
			localinterface:value(k,v.name)
		elseif k:match("^vlan") then
			localinterface:value(k,k)
		end
	end
end
--if ifconfig_str:match("ppp1701") then
if uci:get("xl2tpd","main","enabled") == "1" then
	localinterface:value("L2TP","L2TP")
end
--if ifconfig_str:match("ppp1723") then
if uci:get("pptpc","main","enabled") == "1" then
	localinterface:value("PPTP","PPTP")
end
if uci:get("openvpn","custom_config","enabled") == "1" then
	localinterface:value("OpenVPN","OpenVPN")
end

localport = s:option(Value,"localport",translate("Local Listening Port"))
localport.rmempty = false
localport.default = "5080"
local str = ""
--@ diff with sip
for k,v in pairs(profile) do
    if  v["index"] ~= this_index and v["localport"] then
    	str = str..v["localport"].."&"
    end
end
--@ diff with telnet
str = str..(uci:get("system","telnet","port") or "").."&"
--@ diff with http
local addr = m.uci:get_list("lucid", "http", "address")
for k,v in ipairs(addr) do
	str = str..v.."&"
end
--@ diff with https
addr = m.uci:get_list("lucid", "https", "address")
for k,v in ipairs(addr) do
	str = str..v.."&"
end
--@ diff with ssh
str = str..(uci:get("dropbear","main","Port") or "").."&"
--@ diff with port_map
for k,v in pairs(uci:get_all("firewall") or {}) do
	if v.index and v.name and v['.type'] == "redirect" and v.src_dport then
		str = str..v.src_dport.."&"
	end
end
--@ diff fs esl port
str = str.."8021"

str = "localport("..str..")"
localport.datatype = str

nat = s:option(ListValue,"ext_sip_ip",translate("NAT"))
--nat:value("auto",translate("Auto"))
nat:value("auto-nat","uPNP / NAT-PMP")
nat:value("ip",translate("IP Address"))
--nat:value("ip_autonat",translate("IP Address").."(auto-nat)")
nat:value("stun","Stun")
nat:value("host",translate("DDNS"))
nat:value("off",translate("Off"))
nat.default = "off"

addr = s:option(Value,"ext_sip_ip_more",translate("Address"))
addr:depends("ext_sip_ip","ip")
addr.datatype="abc_ip4addr"
addr.margin = "32px"

function addr.cfgvalue(...)
	local t =  m.uci:get("profile_sip",current_section, "ext_sip_ip")
	local v = m.uci:get("profile_sip",current_section, "ext_sip_ip_more")
	return t=="ip" and v or ""
end

addr = s:option(Value,"ext_sip_ip_more_ip_stun",translate("Stun Server Address"))
addr:depends("ext_sip_ip","stun")
addr.datatype="abc_ip4addr_domain"
addr.margin = "32px"

function addr.cfgvalue(...)
	local t =  m.uci:get("profile_sip",current_section, "ext_sip_ip")
	local v = m.uci:get("profile_sip",current_section, "ext_sip_ip_more")
	return t=="stun" and v or ""
end

function addr.write(self, section, value)
	m.uci:set("profile_sip",section,"ext_sip_ip_more", value)
end

addr = s:option(Value,"ext_sip_ip_more_domain",translate("Domain"))
addr:depends("ext_sip_ip","host")
addr.datatype="domain"
addr.margin = "32px"

function addr.cfgvalue(...)
	local t =  m.uci:get("profile_sip",current_section, "ext_sip_ip")
	local v = m.uci:get("profile_sip",current_section, "ext_sip_ip_more")
	return t=="host" and v or ""
end

function addr.write(self, section, value)
	m.uci:set("profile_sip",section,"ext_sip_ip_more", value)
end
-- maxchannels = s:option(Value,"max_channels",translate("Max Proceeding"))
-- maxchannels.default = "24"
-- maxchannels.rmempty = false
-- maxchannels.datatype = "uinteger"

-- anonymous = s:option(ListValue,"anonymous",translate("Anonymous"))
-- anonymous.default = "off"
-- anonymous:value("on",translate("On"))
-- anonymous:value("off",translate("Off"))

-- holdmusic = s:option(ListValue,"hold_music",translate("Hold Music"))
-- holdmusic.default = "on"
-- holdmusic:value("on",translate("On"))
-- holdmusic:value("off",translate("Off"))

dtmf = s:option(ListValue,"dtmf",translate("DTMF Type"))
dtmf.default = "rfc2833"
dtmf:value("info","SIP INFO")
dtmf:value("rfc2833","RFC2833")
dtmf:value("inband","Inband")

rfc2833pt = s:option(Value,"rfc2833_pt",translate("RFC2833-PT"))
rfc2833pt:depends("dtmf","rfc2833")
rfc2833pt.default = "101"
rfc2833pt.datatype = "range(1,127)"

prack = s:option(ListValue,"prack","PRACK")
prack.default = "off"
prack:value("on",translate("On"))
prack:value("off",translate("Off"))

session_timer = s:option(ListValue,"session_timer",translate("Session Timer"))
session_timer:value("on",translate("On"))
session_timer:value("off",translate("Off"))

function session_timer.cfgvalue(...)
	local v =  m.uci:get("profile_sip",this_section,"session_timeout")
	
	if v and tonumber(v) >= 90 then
		return "on"
	else
		return "off"
	end
end

session_timeout = s:option(Value,"session_timeout",translate("Session Timeout(s)"))
session_timeout:depends("session_timer","on")
session_timeout.default = "1800"
session_timeout.datatype = "range(90,99999)"
session_timeout.rmempty = false
session_timeout.margin = "30px"

function session_timeout.validate(self, value)
	local flag = m:formvalue("cbid.profile_sip."..this_section..".session_timer")
	
	if flag and "on" == flag then
		return Value.validate(self,value)
	else
		m.uci:delete("profile_sip",this_section,"session_timeout")
		return value or ""
	end
end

incodecnego = s:option(ListValue,"inbound_codec_negotiation",translate("Inbound Codec Negotiation Priority"))
incodecnego:value("generous",translate("Remote"))
incodecnego:value("greedy",translate("Local"))
incodecnego:value("scrooge",translate("Local Force"))
incodecnego.rmempty = false

incodecprofile = s:option(ListValue,"inbound_codec_prefs",translate("Inbound Codec Profile"))
incodecprofile.rmempty = false
outcodecprofile = s:option(ListValue,"outbound_codec_prefs",translate("Outbound Codec Profile"))
outcodecprofile.rmempty = false
local profile = uci:get_all("profile_codec")
for i=1,32 do
	for k,v in pairs(profile) do
		if v.index and v.name then
			if tonumber(v.index) == i then
				incodecprofile:value(v.index,v.index.."-< "..v.name.." >")
				outcodecprofile:value(v.index,v.index.."-< "..v.name.." >")
				break
			end
		else
			uci:delete("profile_codec",k)
			uci:save("profile_codec")
		end
	end
end
local continue_param = "profile-sip-profile-edit-"..this_section.."-"..arg[2]
if arg[3] then
	continue_param = continue_param .. ";" .. arg[3]
end
incodecprofile:value("addnew_profile_codec/"..continue_param,translate("< Add New ...>"))
outcodecprofile:value("addnew_profile_codec/"..continue_param,translate("< Add New ...>"))

function incodecprofile.cfgvalue(...)
	local v = m.uci:get("profile_sip",current_section, "inbound_codec_prefs")
	if v and v:match("^addnew") then
		m.uci:revert("profile_sip",current_section, "inbound_codec_prefs")
		v = m.uci:get("profile_sip",current_section, "inbound_codec_prefs")
	end
	return v
end

function outcodecprofile.cfgvalue(...)
	local v = m.uci:get("profile_sip",current_section, "outbound_codec_prefs")
	if v and v:match("^addnew") then
		m.uci:revert("profile_sip",current_section, "outbound_codec_prefs")
		v = m.uci:get("profile_sip",current_section, "outbound_codec_prefs")
	end
	return v
end

bypass_media = s:option(ListValue,"bypass_media",translate("Bypass Media(SIP to SIP)"))
bypass_media.rmempty = false
bypass_media.default = "off"
bypass_media:value("off",translate("Off"))
bypass_media:value("on",translate("On"))

heartbeat = s:option(ListValue,"heartbeat",translate("Detect Extension is Online"))
heartbeat.rmempty = false
heartbeat.default = "off"
heartbeat:value("off",translate("Off"))
heartbeat:value("on",translate("On"))

ping = s:option(Value,"ping",translate("Detect Period(s)"))
ping:depends("heartbeat","on")
ping.margin = "32px"
ping.default = 30
ping.datatype = "range(5,99999)"
ping.margin="30px"

auc = s:option(ListValue,"allow_unknown_call",translate("Allow Unknown Call"))
auc.rmempty = false
auc.default = "off"
auc:value("off",translate("Off"))
auc:value("on",translate("On"))

authacl = s:option(Value,"auth_acl",translate("Inbound Source Filter"))
authacl.datatype = "cidr"
authacl.default = "0.0.0.0/0"

dscp = s:option(ListValue,"qos","QoS")
dscp:value("off",translate("Off"))
dscp:value("on",translate("On"))

local dscp_name={"CS0","CS1","AF11","AF12","AF13","CS2","AF21","AF22","AF23","CS3","AF31","AF32","AF33","CS4","AF41","AF42","AF43","CS5","EF","CS6","CS7"}
local dscp_value={"0","8","10","12","14","16","18","20","22","24","26","28","30","32","34","36","38","40","46","48","56"}
dscpsip = s:option(ListValue,"dscp_sip",translate("SIP Message DSCP Value"))
dscpsip:depends("qos","on")
dscpsip.margin="30px"
dscprtp = s:option(ListValue,"dscp_rtp","RTP DSCP Value")
dscprtp:depends("qos","on")
dscprtp.margin="30px"
for k,v in pairs(dscp_value) do
	dscpsip:value(v,dscp_name[k].." / "..v)
	dscprtp:value(v,dscp_name[k].." / "..v)
end
dscpsip.default="46"
dscprtp.default="46"

-- faxprofile = s:option(ListValue,"faxprofile",translate("FAX Profile"))
-- faxprofile.rmempty = false
-- local faxp = uci:get_all("profile_fax")
-- for i=1,32 do
-- 	for k,v in pairs(faxp) do
-- 		if v["index"] and v["name"] then
-- 			if tonumber(v["index"]) == i then
-- 				faxprofile:value(v["index"],v["index"].."-< "..v["name"].." >")
-- 				break
-- 			end
-- 		else
-- 			uci:delete("profile_fax",k)
-- 			uci:save("profile_fax")
-- 		end
-- 	end
-- end
-- local continue_param = "profile-sip-"..arg[1].."-"..arg[2]
-- if arg[3] then
-- 	continue_param = continue_param .. ";" .. arg[3]
-- end
-- faxprofile:value("addnew_profile_fax/"..continue_param,translate("< Add New ...>"))

return m
