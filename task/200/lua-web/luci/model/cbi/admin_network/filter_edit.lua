--[[
@file ip_filter_edit.lua
@brief config web for ip_filter_edit
@version 1.0
@author lamont
@date 2015.04.18
]]--

local dsp = require "luci.dispatcher"
local uci = require "luci.model.uci".cursor()

arg[1] = arg[1] or ""
arg[2] = arg[2] or ""

if arg[2] == "edit" then
    m = Map("firewall",translate("Network / Firewall / Filter Rules / Edit"))
else
    m = Map("firewall",translate("Network / Firewall / Filter Rules / New"))
    m.addnew = true
    m.new_section = arg[1]
end

m.redirect = dsp.build_url("admin","network","firewall")

s = m:section(NamedSection,arg[1],"rule","")
m.currsection = s
s.addremove = false
s.anonymous = true

local this_index = uci:get("firewall",arg[1],"index")
local profile = uci:get_all("firewall") or {}
local MAX_FIREWALL_RULE = tonumber(uci:get("profile_param","global","max_firewall_rule") or "32")

if arg[2] == "edit" then
	index = s:option(DummyValue,"index",translate("Index"))
else
	index = s:option(ListValue,"index",translate("Index"))
	index.rmempty = false
	for i=1,MAX_FIREWALL_RULE do
		local flag = true
		for k,v in pairs(profile) do
			if v["index"] and v[".type"] == "rule" and tonumber(v["index"]) == i then
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

protocol = s:option(ListValue,"proto",translate("Protocol"))
protocol.rmempty = false
protocol.default = "tcp"
protocol:value("all",translate("Any"))
protocol:value("tcp","TCP")
protocol:value("udp","UDP")
protocol:value("tcp udp","TCP/UDP")

src_ip = s:option(Value,"src_ip",translate("LAN IP"))
src_ip.datatype = "ip4addrrange"

src_port = s:option(Value,"src_port",translate("LAN Port"))
src_port.datatype = "portrange"

src_mac = s:option(Value,"src_mac",translate("LAN MAC"))
src_mac.placeholder = "00:00:00:00:00:00"
src_mac.datatype = "unicast_macaddr"

dest_ip = s:option(Value,"dest_ip",translate("WAN IP"))
dest_ip.datatype = "ip4addrrange"

dest_port = s:option(Value,"dest_port",translate("WAN Port"))
dest_port.datatype = "portrange"

action = s:option(ListValue,"target",translate("Action"))
action:value("ACCEPT",translate("Accept"))
action:value("REJECT",translate("Reject"))

function action.write(self,section,value)
	local tmp = m:formvalue("cbid.firewall."..arg[1]..".target")

	m.uci:set("firewall",arg[1],"target",tmp)
	m.uci:set("firewall",arg[1],"src","lan")
	m.uci:set("firewall",arg[1],"dest","wan")
end

return m
