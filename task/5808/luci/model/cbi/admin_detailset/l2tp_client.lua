local fs = require "nixio.fs"
local util = require "luci.util"
local uci = require "luci.model.uci".cursor()
local uci_tmp = require "luci.model.uci".cursor("/tmp/config")

if not fs.access("/etc/config/vpnselect") then
	util.exec("touch /etc/config/vpnselect")
end

if not uci:get("vpnselect","vpnselect") then
	uci:section("vpnselect","select","vpnselect")
	uci:save("vpnselect")
	uci:commit("vpnselect")
end

uci:check_cfg("xl2tpd")

m = Map("xl2tpd",translate(""), translate(""))
m:chain("pptpc")
m:chain("openvpn")
m:chain("profile_sip")
m:chain("vpnselect")

local profile_wan_section
local tmp_tb = uci:get_all("profile_sip") or {}
if next(tmp_tb) then
	for k,v in pairs(tmp_tb) do
		if v.index and v.index == "2" then
			profile_wan_section = k
		end
	end
end

s = m:section(TypedSection,"l2tpc","")
s.addremove = false
s.anonymous = true
s.useable = false

status = s:option(ListValue,"enabled","启动L2TP服务")
status:value("0",translate("Disable"))
status:value("1",translate("Enable"))

function status.write(self,section,value)
	m.uci:set("xl2tpd","main","enabled",value)
	m.uci:set("qos","qos_l2tp1","enabled",(uci:get("xl2tpd","l2tpd","enabled") == "1" or value == "1" ) and "1" or "0")
	m.uci:set("qos","qos_l2tp2","enabled",(uci:get("xl2tpd","l2tpd","enabled") == "1" or value == "1" ) and "1" or "0")
end
function status.validate(self, value)
	if value == "1" then
		m.uci:set("pptpc","main","enabled","0")
		m.uci:set("openvpn","custom_config","enabled","0")
		m.uci:set("vpnselect","vpnselect","vpntype","l2tp")
		if profile_wan_section then
			m.uci:set("profile_sip",profile_wan_section,"localinterface","L2TP")
		end
	elseif value == "0" then
		m.uci:set("vpnselect","vpnselect","vpntype","disabled")
		if profile_wan_section then
			m.uci:set("profile_sip",profile_wan_section,"localinterface","WAN")
		end
	end
	return Value.validate(self, value)
end

option = s:option(ListValue,"defaultroute","默认路由")
option:depends("enabled","1")
option.rmempty = false
option:value("0",translate("Disable"))
option:value("1",translate("Enable"))
option.default = "0"
function option.validate(self, value)
	if value then
		return Value.validate(self,value)
	else
		return ""
	end
end

option = s:option(Value,"server","服务器地址")
option:depends("enabled","1")
option.rmempty = false
option.datatype = "abc_ip4addr_domain"
function option.validate(self, value)
	if value then
		return Value.validate(self,value)
	else
		return ""
	end
end

option = s:option(Value,"username","用户名")
option:depends("enabled","1")
option.rmempty = false
option.datatype = "notempty"
function option.validate(self, value)
	if value then
		return Value.validate(self,value)
	else
		return ""
	end
end

option = s:option(Value,"password","密码")
option:depends("enabled","1")
option.password = true
option.rmempty = false
option.datatype = "password"
option.datatype = "length(3,32)"
function option.validate(self, value)
	if value then
		return Value.validate(self,value)
	else
		return ""
	end
end

return m
