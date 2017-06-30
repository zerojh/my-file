--[[
@file port_map_edit.lua
@brief config web for Port Mapping
@version 1.0
@author harlan
@date 2015.02.11
]]--

local dsp = require "luci.dispatcher"
local uci = require "luci.model.uci".cursor()

this_section = arg[1] or ""
arg[2] = arg[2] or ""

if arg[2] == "edit" then
    m = Map("firewall",translate("Network / Port Mapping / Edit"))
else
    m = Map("firewall",translate("Network / Port Mapping / New"))
    m.addnew = true
    m.new_section = this_section
end

m.redirect = dsp.build_url("admin","network","port_map")


s = m:section(NamedSection,this_section,"redirect","")
m.currsection = s
s.addremove = false
s.anonymous = true

local this_index = uci:get("firewall",this_section,"index")
local profile = uci:get_all("firewall") or {}
local MAX_FIREWALL_REDIRECT = tonumber(uci:get("profile_param","global","max_firewall_redirect") or "32")

if arg[2] == "edit" then
	index = s:option(DummyValue,"index",translate("Index"))
else
	index = s:option(ListValue,"index",translate("Index"))
	index.rmempty = false
	for i=1,MAX_FIREWALL_REDIRECT do
		local flag = true
		for k,v in pairs(profile) do
			if v["index"] and v['.type'] == "redirect" and tonumber(v["index"]) == i then
				flag = false
				break
			end
		end

		if flag == true then
			index:value(i,i)
		end
	end
end

name = s:option(Value,"name",translate("Name"))
name.rmempty = false
name.datatype = "cfgname"

wan_port = s:option(Value,"src_dport",translate("WAN Port"))
wan_port.rmempty = false
local str = ""
local sip_profile = uci:get_all("profile_sip") or {}
--@ diff with sip
for k,v in pairs(sip_profile) do
    if v["localport"] then
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
	if v.index and v.name and v['.type'] == "redirect" and k ~= this_section and v.src_dport then
		str = str..v.src_dport.."&"
	end
end
--@ diff with rtp
str = str..(uci:get("callcontrol","voice","rtp_start_port") or "16000").."-"..(uci:get("callcontrol","voice","rtp_end_port") or "16200").."&"
--@ diff fs esl port
str = str.."8021"
wan_port.datatype = "dif_portrange("..str..")"

proto = s:option(ListValue,"proto",translate("Protocol"))
proto.rmempty = false
proto:value("tcp","TCP")
proto:value("udp","UDP")
proto:value("tcp udp","TCP/UDP")

function proto.parse(self, section, value)
	local value = m:formvalue("cbid.firewall."..this_section..".proto")

	m.uci:set("firewall", this_section, "proto", (value or ""))
	m.uci:set("firewall", this_section, "src" , "wan")
	m.uci:set("firewall", this_section, "dest", "lan")
end

lan_ip = s:option(Value,"dest_ip",translate("LAN IP"))
lan_ip.rmempty = false
lan_ip.datatype = "abc_ip4addr"

lan_port = s:option(Value,"dest_port",translate("LAN Port"))
--lan_port.rmempty = false
lan_port.datatype = "portrange"

status = s:option(ListValue,"enabled",translate("Status"))
status.rmempty = false
status:value("1",translate("Enable"))
status:value("0",translate("Disable"))

return m


