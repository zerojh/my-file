--[[
@file sip_add.lua
@brief config web for sip profile
@version 1.0
@author harlan
@date 2014.04.16
]]--

local dsp = require "luci.dispatcher"
local uci = require "luci.model.uci".cursor()

arg[1] = arg[1] or ""
arg[2] = arg[2] or ""

uci:check_cfg("profile_sip")
uci:check_cfg("profile_codec")

local current_user = dsp.context.authuser
local codec_access = uci:get("user",current_user.."_web","profile_codec")

if arg[2] == "edit" then
	m = Map("profile_sip",translate("Profile / SIP / Edit"))
else
	m = Map("profile_sip",translate("Profile / SIP / New"))
	m.addnew = true
	m.new_section = arg[1]
end

local current_section = arg[1]
if arg[3] then
	m.saveaction = false
	m.redirect = m:gen_redirect(arg[3])
else
	m.redirect = dsp.build_url("admin","profile","sip")
end

if not m.uci:get(arg[1]) == "sip" then
	luci.http.redirect(m.redirect)
end

s = m:section(NamedSection,arg[1],"sip","")
m.currsection = s
s.addremove = false
s.anonymous = true

local this_index = uci:get("profile_sip",arg[1],"index")
local profile = uci:get_all("profile_sip") or {}

if arg[2] == "edit" then
	index = s:option(DummyValue,"index",translate("Index"))
else
	index = s:option(ListValue,"index",translate("Index"))
	index.rmempty = false
	for i=1,8 do
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
name.datatype = "cfgname"

localinterface = s:option(ListValue,"localinterface",translate("Local Listening Interface"))
localinterface:value("WAN","WAN")
localinterface:value("LAN","LAN")
if luci.version.license and luci.version.license.lte then
	localinterface:value("LTE","LTE")
end
localinterface:value("OpenVPN","OpenVPN")
localinterface:value("L2TP","L2TP")
localinterface:value("PPTP","PPTP")

localport = s:option(Value,"localport",translate("Local Listening Port"))
localport.rmempty = false
localport.default = "5080"
local str = ""
for k,v in pairs(profile) do
	if v["index"] ~= this_index and v["localport"] then
		str = str..v["localport"].."&"
	end
end

str = str..(uci:get("system","telnet","port") or "").."&"
local addr = m.uci:get_list("lucid", "http", "address")
for k,v in ipairs(addr) do
	str = str..v.."&"
end
addr = m.uci:get_list("lucid", "https", "address")
for k,v in ipairs(addr) do
	str = str..v.."&"
end
str = str..(uci:get("dropbear","main","Port") or "").."&"
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
if uci:get("network_tmp","network","network_mode") == "route" or (not uci:get("network_tmp","network","network_mode") and uci:get("network","wan")) then
	nat:depends("localinterface","WAN")
end

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
addr.datatype="abc_ip4addr_domain_port"
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
	local v1 = uci:get("profile_sip",current_section,"session_timer") --旧设备上无该值，这里做下综合判断
	local v2 =  uci:get("profile_sip",current_section,"session_timeout")
	if (v1 and "on" == v1) or (not v1 and v2 and tonumber(v2) >= 90) then
		return "on"
	else
		return "off"
	end
end
session_timeout = s:option(Value,"session_timeout",translate("Session Timeout(s)"))
session_timeout:depends("session_timer","on")
session_timeout.default = "1800"
session_timeout.datatype = "min(90)"
session_timeout.rmempty = false
session_timeout.margin = "30px"
function session_timeout.validate(self, value)
	local flag =  m.uci:get("profile_sip",current_section,"session_timer")
	if flag and "on" == flag then
		return Value.validate(self,value)
	else
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
local profile = uci:get_all("profile_codec") or {}
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
local continue_param = "profile-sip-"..arg[1].."-"..arg[2]
if arg[3] then
	continue_param = continue_param .. ";" .. arg[3]
end

if "admin" == current_user or (codec_access and codec_access:match("edit")) then
	incodecprofile:value("addnew_profile_codec/"..continue_param,translate("< Add New ...>"))
	outcodecprofile:value("addnew_profile_codec/"..continue_param,translate("< Add New ...>"))
end

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
ping.datatype = "min(5)"
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
dscprtp = s:option(ListValue,"dscp_rtp",translate("RTP DSCP Value"))
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
