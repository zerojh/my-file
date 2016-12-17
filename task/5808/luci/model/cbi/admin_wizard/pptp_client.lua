local fs = require "nixio.fs"
local util = require "luci.util"
local uci = require "luci.model.uci".cursor()
local uci_tmp = require "luci.model.uci".cursor("/tmp/config")
local dsp = require "luci.dispatcher"
local flag = uci_tmp:get("wizard","globals","pptp") or "1"

if not fs.access("/etc/config/vpnselect") then
	util.exec("touch /etc/config/vpnselect")
end

if not uci:get("vpnselect","vpnselect") then
	uci:section("vpnselect","select","vpnselect")
	uci:save("vpnselect")
	uci:commit("vpnselect")
end

uci:check_cfg("pptpc")

m = Map("pptpc","PPTP客户端")
m.pageaction = false
m:chain("xl2tpd")
m:chain("openvpn")
m:chain("profile_sip")
m:chain("vpnselect")

if luci.http.formvalue("cbi.cancel") then
	m.redirect = dsp.build_url("admin","wizard","ddns")
elseif luci.http.formvalue("cbi.save") then
	flag = "1"
	uci_tmp:set("wizard","globals","pptp","1")
	uci_tmp:save("wizard")
	uci_tmp:commit("wizard")
	m.redirect = dsp.build_url("admin","uci","changes")
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

s = m:section(TypedSection,"pptpc","")
s.addremove = false
s.anonymous = true
s.useable = false

--#### Description #####----
option = s:option(DummyValue,"_description")
option.template = "admin_wizard/description"
option.data = {}
table.insert(option.data,"此处可选择是否启动PPTP客户端．")
table.insert(option.data,"")

--#### Enabled #####----
option = s:option(ListValue,"enabled","启动PPTP服务")
option:value("0",translate("Disable"))
option:value("1",translate("Enable"))
function option.cfgvalue(self, section)
	if flag == "1" then
		return AbstractValue.cfgvalue(self, section)
	else
		return nil
	end
end
function option.validate(self,value)
	if value == "1" then
		m.uci:set("xl2tpd","main","enabled","0")
		m.uci:set("openvpn","custom_config","enabled","0")
		m.uci:set("vpnselect","vpnselect","vpntype","pptp")
		if profile_wan_section then
			m.uci:set("profile_sip",profile_wan_section,"localinterface","PPTP")
		end
	elseif value == "0" then
		m.uci:set("vpnselect","vpnselect","vpntype","disabled")
		if profile_wan_section then
			m.uci:set("profile_sip",profile_wan_section,"localinterface","WAN")
		end
	end

	if not m.uci:get("pptpc","main","defaultroute") then
		m.uci:set("pptpc","main","defaultroute","0")
	end

	return Value.validate(self, value)
end
function option.write(self,section,value)
	m.uci:set("pptpc","main","enabled",value)
	m.uci:set("qos","qos_pptp1","enabled",(uci:get("pptpd","pptpd","enabled") == "1" or value == "1" ) and "1" or "0")
	m.uci:set("qos","qos_pptp2","enabled",(uci:get("pptpd","pptpd","enabled") == "1" or value == "1" ) and "1" or "0")
end

--#### Data Encryption #####----
option = s:option(ListValue,"mppe","数据加密")
option:depends("enabled","1")
option.rmempty = false
option:value("0",translate("Disable"))
option:value("1",translate("Enable"))
option.default = "1"
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
