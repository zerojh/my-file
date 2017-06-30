--@*******************************************
--文件描述:静态路由配置文件

--版本:V1.0
--@*******************************************

local dsp = require "luci.dispatcher"
local uci = require "luci.model.uci".cursor()
local bit = require "bit"
local util = require "luci.util"
	
this_section = arg[1] or ""
arg[2] = arg[2] or ""

if arg[2] == "edit" then
    m = Map("static_route",translate("Network / Static Route / Edit"))
else
    m = Map("static_route",translate("Network / Static Route / New"))
    m.addnew = true
    m.new_section = arg[1]
end

m.redirect = dsp.build_url("admin","network","static_route")

s = m:section(NamedSection,arg[1],"route","")
m.currsection = s
s.addremove = false
s.anonymous = true

local profile = uci:get_all("static_route") or {}
local MAX_STATIC_ROUTE = tonumber(uci:get("profile_param","global","max_static_route") or "10")

index = s:option(ListValue,"index",translate("Index"))
index.rmempty = false
for i=1,MAX_STATIC_ROUTE do
	local flag = true
	for k,v in pairs(profile) do
		if v.index and tonumber(v.index) == i and k ~= arg[1] then
			flag = false
			break
		end
	end

	if flag == true then
		index:value(i,i)
	end
end

--@*******************************************
--#功能模块:静态路由的名字

--#控件特性:文本框
--@*******************************************
name = s:option(Value,"name",translate("Name"))
name.rmempty = false
name.datatype = "cfgname"

--@*******************************************
--#功能模块:静态路由的目的网段

--#控件特性:文本框
--@*******************************************
target = s:option(Value,"target",translate("Target IP"))
target.rmempty = false
target.datatype = "ip4addr"

function target.parse(self,section,value)
	local tmp = m:formvalue("cbid.static_route."..this_section..".netmask")
	local tmp_val = m:formvalue("cbid.static_route."..this_section..".target")
	
	if tmp_val and tmp then
		local tmp_ip = util.split(tmp_val,".")
		local tmp_netmask = util.split(tmp,".")
		local real_ip = bit.band(tmp_ip[1],tmp_netmask[1]).."."..bit.band(tmp_ip[2],tmp_netmask[2]).."."..bit.band(tmp_ip[3],tmp_netmask[3]).."."..bit.band(tmp_ip[4],tmp_netmask[4])

		m.uci:set("static_route",this_section,"target",real_ip)
	end
end

--@*******************************************
--#功能模块:静态路由的目的网段

--#控件特性:文本框
--@*******************************************
netmask = s:option(Value,"netmask",translate("Netmask"))
netmask.rmempty = false
netmask.datatype = "netmask"
netmask.default = "255.255.255.0"
netmask:value("255.0.0.0","255.0.0.0")
netmask:value("255.255.0.0","255.255.0.0")
netmask:value("255.255.255.0","255.255.255.0")
netmask:value("255.255.255.255","255.255.255.255")

--@*******************************************
--#功能模块:静态路由的对端的网关

--#控件特性:文本框
--@*******************************************
gw = s:option(Value,"gateway",translate("Gateway"))
--gw.rmempty = false
gw.datatype = "abc_ip4addr"

--@*******************************************
--#功能模块:静态路由的网络接口

--#控件特性:下拉框
--@*******************************************
interface = s:option(ListValue,"interface",translate("Interface"))
if nil == m.uci:get("network" , "wan" , "ifname") then
	interface:value("lan","LAN")
elseif nil ~= m.uci:get("network" , "wan" , "ifname") then
	interface:value("wan","WAN")
	interface:value("lan","LAN")
end
if luci.version.license and luci.version.license.lte then
	interface:value("wan2","LTE")
elseif luci.version.license and luci.version.license.volte then
	interface:value("wan2","VoLTE")
end
interface:value("openvpn","OpenVPN")
interface:value("ppp1701","L2TP")
interface:value("ppp1723","PPTP")

--@*******************************************
--#功能模块:某条静态路由的状态

--#控件特性:下拉框
--@*******************************************
status = s:option(ListValue,"status",translate("Status"))
status.default = "disabled"
status:value("Enabled",translate("Enable"))
status:value("Disabled",translate("Disable"))


return m
