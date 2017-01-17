local fs = require "nixio.fs"
local util = require "luci.util"
local uci = require "luci.model.uci".cursor()
local uci_tmp = require "luci.model.uci".cursor("/tmp/config")
local dsp = require "luci.dispatcher"
local flag = uci_tmp:get("wizard","globals","l2tp") or "1"

if not fs.access("/etc/config/vpnselect") then
	util.exec("touch /etc/config/vpnselect")
	if not uci:get("vpnselect","vpnselect") then
		uci:section("vpnselect","select","vpnselect")
		uci:save("vpnselect")
		uci:commit("vpnselect")
	end
end

uci:check_cfg("xl2tpd")

m = Map("xl2tpd","L2TP客户端")
m.pageaction = false
m:chain("openvpn")
m:chain("pptpc")
m:chain("profile_sip")
m:chain("vpnselect")

if luci.http.formvalue("cbi.cancel") then
	m.redirect = dsp.build_url("admin","wizard","vpn")
elseif luci.http.formvalue("cbi.save") then
	flag = "1"
	uci_tmp:set("wizard","globals","l2tp","1")
	uci_tmp:save("wizard")
	uci_tmp:commit("wizard")
	m.redirect = dsp.build_url("admin","wizard","changes")
end

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

--#### Description #####----
option = s:option(DummyValue,"_description")
option.template = "admin_wizard/description"
option.data = {}
table.insert(option.data,"此处可选择是否启动L2TP客户端．")
table.insert(option.data,"")

--#### Enabled #####----
option = s:option(ListValue,"enabled","启动L2TP服务")
option:value("0",translate("Disable"))
option:value("1",translate("Enable"))
function option.cfgvalue(self, section)
	if flag == "1" then
		return AbstractValue.cfgvalue(self, section)
	else
		return nil
	end
end
function option.write(self,section,value)
	m.uci:set("xl2tpd","main","enabled",value)
	m.uci:set("qos","qos_l2tp1","enabled",(uci:get("xl2tpd","l2tpd","enabled") == "1" or value == "1" ) and "1" or "0")
	m.uci:set("qos","qos_l2tp2","enabled",(uci:get("xl2tpd","l2tpd","enabled") == "1" or value == "1" ) and "1" or "0")
end
function option.validate(self, value)
	if value == "1" then
		m.uci:set("pptpc","main","enabled","0")
		m.uci:set("openvpn","custom_config","enabled","0")
		m.uci:set("vpnselect","vpnselect","vpntype","l2tp")
		if profile_wan_section then
			m.uci:set("profile_sip",profile_wan_section,"localinterface","L2TP")
		end
	elseif value == "0" then
		local last_vpn_type = m.uci:get("vpnselect","vpnselect","vpntype") or uci_tmp:get("vpnselect","vpnselect","vpntype")
		if not last_vpn_type or last_vpn_type == "l2tp" then
			m.uci:set("vpnselect","vpnselect","vpntype","disabled")
			if profile_wan_section then
				m.uci:set("profile_sip",profile_wan_section,"localinterface","WAN")
			end
		end
	end

	if not m.uci:get("xl2tpd","main","defaultroute") then
		m.uci:set("xl2tpd","main","defaultroute","0")
	end

	return Value.validate(self, value)
end

--#### server #####----
option = s:option(Value,"server","服务器地址")
option:depends("enabled","1")
option.rmempty = false
option.datatype = "abc_ip4addr_domain"
function option.cfgvalue(self, section)
	if flag == "1" then
		return AbstractValue.cfgvalue(self, section)
	else
		return nil
	end
end
function option.validate(self, value)
	if value then
		return Value.validate(self,value)
	else
		return ""
	end
end

--#### username #####----
option = s:option(Value,"username","用户名")
option:depends("enabled","1")
option.rmempty = false
option.datatype = "notempty"
function option.cfgvalue(self, section)
	if flag == "1" then
		return AbstractValue.cfgvalue(self, section)
	else
		return nil
	end
end
function option.validate(self, value)
	if value then
		return Value.validate(self,value)
	else
		return ""
	end
end

--#### password #####----
option = s:option(Value,"password","密码")
option:depends("enabled","1")
option.password = true
option.rmempty = false
option.datatype = "password"
option.datatype = "length(3,32)"
function option.cfgvalue(self, section)
	if flag == "1" then
		return AbstractValue.cfgvalue(self, section)
	else
		return nil
	end
end
function option.validate(self, value)
	if value then
		return Value.validate(self,value)
	else
		return ""
	end
end

option = s:option(DummyValue,"_footer")
option.template = "admin_wizard/footer"

return m
