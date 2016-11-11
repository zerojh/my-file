local uci = require "luci.model.uci".cursor()
local dsp = require "luci.dispatcher"

m = Map("network_tmp","第一阶段：上网设置")
m:chain("network")
m:chain("firewall")
m:chain("wireless")
m.pageaction = false

if luci.http.formvalue("cbi.cancel") then
	m.redirect = dsp.build_url("admin","wizard","1")
elseif luci.http.formvalue("cbi.save") then
	m.redirect = dsp.build_url("admin","wizard","3")
end

--@ first
s = m:section(NamedSection,"network","setting")

--#### Description #####----
option = s:option(DummyValue,"_description")
option.template = "admin_wizard/description"
option.data = {}
table.insert(option.data,"本设备提供五种上网方式．")
table.insert(option.data,"")
table.insert(option.data,"有线上网方式有＂动态IP＂、＂静态IP＂和＂PPPOE＂．")
table.insert(option.data,"无线上网方式有＂动态IP＂和＂静态IP＂．")

local section_firewall

for k,v in pairs(m.uci:get_all("firewall") or {}) do
	if v['.type'] == "defaults" then
		section_firewall = k
		break
	end
end

--####access mode#####----
option = s:option(ListValue,"access_mode","请选择网络接入方式")
option.rmempty = false
option:value("wan_dhcp","有线动态IP")
option:value("wan_static","有线静态IP")
option:value("wan_pppoe","PPPoE")
option:value("wlan_dhcp","无线动态IP")
option:value("wlan_static","无线静态IP")

function option.write(self, section, value)
	local tmp = m:formvalue("cbid.network_tmp.network.access_mode") or "wan_dhcp"

	if tmp == "wan_dhcp" or tmp == "wan_static" or tmp == "wan_pppoe"then
		m.uci:set("network_tmp","network","network_mode","route")
		m.uci:set("network_tmp","network","wan_proto",string.sub(tmp,5))
		m.uci:set("wireless","wifi0","mode","ap")
		m.uci:set("firewall",section_firewall,"enabled","1")
	elseif tmp == "wlan_dhcp" or tmp == "wlan_static" then
		m.uci:set("network_tmp","network","network_mode","client")
		m.uci:set("network_tmp","network","wlan_proto",string.sub(tmp,6))
		m.uci:set("wireless","wifi0","mode","sta")
		m.uci:set("firewall",section_firewall,"enabled","0")
	end

	m.uci:set("network_tmp","network","access_mode",tmp)
end

--@ WAN Static IP {
--####wan static ip addr####----
option = s:option(Value,"wan_ipaddr","IP地址")
option.datatype = "wan_addr"
option.rmempty = false
option:depends("access_mode","wan_static")
function option.validate(self, value)
	local tmp = m:formvalue("cbid.network_tmp.network.access_mode")
	
	if  tmp == "wan_static" then
		return Value.validate(self, value)
	else
		m.uci:delete("network_tmp","network","wan_ipaddr")
		m.uci:delete("network","wan","ipaddr")
		return value or ""
	end
end

--####wan static netmask####----
option = s:option(Value,"wan_netmask","子网掩码")
option.rmempty = false
option:depends("access_mode","wan_static")
option.datatype = "netmask"
option.default = "255.255.255.0"
option:value("255.0.0.0","255.0.0.0")
option:value("255.255.0.0","255.255.0.0")
option:value("255.255.255.0","255.255.255.0")
function option.validate(self,value)
	local tmp = m:formvalue("cbid.network_tmp.network.access_mode")

	if tmp == "wan_static" then
		return Value.validate(self,value)
	else
		m.uci:delete("network_tmp","network","wan_netmask")
		m.uci:delete("network","wan","netmask")
		return value or ""
	end
end

--####wan static gateway####----
option = s:option(Value,"wan_gateway","默认网关")
option.datatype = "wan_gateway"
option.rmempty = false
option:depends("access_mode","wan_static")

function option.validate(self, value)
	local tmp = m:formvalue("cbid.network_tmp.network.access_mode")
	
	if  tmp == "wan_static"  then
		return Value.validate(self, value)
	else
		m.uci:delete("network_tmp","network","wan_gateway")
		m.uci:delete("network","wan","gateway")
		return value or ""
	end
end

--@ } END static IP

--@ PPPOE {
--####wan pppoe username####----
option = s:option(Value,"wan_username","用户名")
option.rmempty = false
option:depends("access_mode","wan_pppoe")
function option.validate(self, value)
	local tmp = m:formvalue("cbid.network_tmp.network.access_mode")

	if tmp == "wan_pppoe" then
		return Value.validate(self, value)
	else
		m.uci:delete("network_tmp","network","wan_username")
		m.uci:delete("network","wan","username")
		return value or ""
	end
end

--####wan pppoe password####----
option = s:option(Value,"wan_password","密码")
option.password = true
option.rmempty = false
option:depends("access_mode","wan_pppoe")
function option.validate(self,value)
	local tmp = m:formvalue("cbid.network_tmp.network.access_mode")

	if tmp == "wan_pppoe" then
		return Value.validate(self,value)
	else
		m.uci:delete("network_tmp","network","wan_password")
		m.uci:delete("network","wan","password")
		return value or ""
	end
end

--####wan pppoe service####----
option = s:option(Value,"wan_service","服务器名称")
option:depends("access_mode","wan_pppoe")
function option.validate(self,value)
	local tmp = m:formvalue("cbid.network_tmp.network.access_mode")

	if tmp == "wan_pppoe" then
		return Value.validate(self,value)
	else
		m.uci:delete("network_tmp","network","wan_service")
		m.uci:delete("network","wan","service")
		return value or ""
	end
end
--@ } END PPPOE

--####wan auto dns####----
option = s:option(Flag,"wan_peerdns","自动获取DNS服务器地址")
option.rmempty = false
option:depends("access_mode","wan_dhcp")
option:depends("access_mode","wan_pppoe")
option.default = option.enabled

--####wan static dns####----
option = s:option(DynamicList,"wan_dns","使用自定义的DNS服务器")
option.datatype = "abc_ip4addr"
option.cast     = "string"
option.addremove = false
option.max = 2
option:depends({access_mode="wan_dhcp",wan_peerdns=""})
option:depends({access_mode="wan_pppoe",wan_peerdns=""})
option:depends("access_mode","wan_static")

function option.cfgvalue(...)
	return m.uci:get("network_tmp","network","wan_dns") or ""
end

function option.parse(self, section, value)
	local value = m:formvalue("cbid.network_tmp.network.wan_dns")

	if value then
		m.uci:set("network_tmp","network","wan_dns",value)
	else
		m.uci:delete("network_tmp","network","wan_dns")
		m.uci:delete("network","wan","dns")
	end
end

--@ } END WAN Config-----

option = s:option(Value,"wifi_ssid","可接入WIFI列表")
option.rmempty = false
option.datatype = "uni_ssid"
option.template = "admin_wizard/net_access/ssid"
option:depends("access_mode","wlan_dhcp")
option:depends("access_mode","wlan_static")
function option.cfgvalue(...)
	return m.uci:get("wireless","wifi0","ssid") or ""
end
function option.validate(self, value)
	local access_mode = m:formvalue("cbid.network_tmp.network.access_mode") or ""

	if access_mode == "wlan_dhcp" or access_mode == "wlan_static" then
		return Value.validate(self, value)
	else
		m.uci:delete("wireless","wifi0","ssid")
		m.uci:delete("wireless","wifi0","encryption")
		m.uci:delete("wireless","wifi0","key")
		return value or ""
	end
end
function option.write(self,section,value)
	local access_mode = m:formvalue("cbid.network_tmp.network.access_mode") or ""

	if access_mode == "wlan_dhcp" or access_mode == "wlan_static" then
		return m.uci:set("wireless","wifi0","ssid",value or "")
	else
		return m.uci:delete("wireless","wifi0","ssid")
	end
end

option = s:option(Value,"wifi_key","WIFI密码")
option.datatype = "wifi_password"
option.password = true
option:depends("access_mode","wlan_dhcp")
option:depends("access_mode","wlan_static")
function option.cfgvalue(...)
	local key = m.uci:get("wireless","wifi0","key")

	return key or ""
end
function option.validate(self, value)
	local access_mode = m:formvalue("cbid.network_tmp.network.access_mode") or ""
	local encryption = m:formvalue("cbid.network_tmp.network.encryption") or "psk2"

	if access_mode == "wlan_dhcp" or access_mode == "wlan_static" then
		m.uci:set("wireless","wifi0","encryption",encryption)
		if encryption ~= "none" and value ~= "" then
			return Value.validate(self, value)
		else
			m.uci:delete("wireless","wifi0","key")
			return value or ""
		end
	else
		m.uci:delete("wireless","wifi0","encryption")
		m.uci:delete("wireless","wifi0","key")
		return value or ""
	end
end
function option.write(self,section,value)
	local access_mode = m:formvalue("cbid.network_tmp.network.access_mode") or ""
	local encryption = m:formvalue("cbid.network_tmp.network.encryption") or "psk2"

	if (access_mode == "wlan_dhcp" or access_mode == "wlan_static") and encryption and encryption ~= "none" then
		return m.uci:set("wireless","wifi0","key",value)
	else
		return m.uci:delete("wireless","wifi0","key")
	end
end

option = s:option(Value,"wlan_ipaddr","IP地址")
option.rmempty = false
option.datatype = "ip4addr"
option:depends("access_mode","wlan_static")
function option.validate(self, value)
	local tmp = m:formvalue("cbid.network_tmp.network.access_mode")
	
	if tmp == "wlan_static" then
		return Value.validate(self, value)
	else
		m.uci:delete("network_tmp","network","wlan_ipaddr")
		m.uci:delete("network","wlan","ipaddr")
		return value or ""
	end
end

option = s:option(Value,"wlan_netmask","子网掩码")
option.rmempty = false
option:depends("access_mode","wlan_static")
option.datatype = "netmask"
option.default = "255.255.255.0"
option:value("255.0.0.0","255.0.0.0")
option:value("255.255.0.0","255.255.0.0")
option:value("255.255.255.0","255.255.255.0")
function option.validate(self,value)
	local tmp = m:formvalue("cbid.network_tmp.network.access_mode")

	if tmp == "wlan_static" then
		return Value.validate(self,value)
	else
		m.uci:delete("network_tmp","network","wlan_netmask")
		m.uci:delete("network","wlan","netmask")
		return value or ""
	end
end

option = s:option(Value,"wlan_gateway","默认网关")
option.datatype = "wlan_gateway"
option.rmempty = false
option:depends("access_mode","wlan_static")

function option.validate(self, value)
	local tmp = m:formvalue("cbid.network_tmp.network.access_mode")
	
	if tmp == "wlan_static"  then
		return Value.validate(self, value)
	else
		m.uci:delete("network_tmp","network","wlan_gateway")
		m.uci:delete("network","wlan","gateway")
		return value or ""
	end
end

option = s:option(Flag,"wlan_peerdns","自动获取DNS服务器地址")
option.rmempty = false
option:depends("access_mode","wlan_dhcp")
option:depends("access_mode","wlan_pppoe")
option.default = option.enabled

option = s:option(DynamicList, "wlan_dns","使用自定义的DNS服务器")
option.datatype = "abc_ip4addr"
option.cast     = "string"
option.addremove = false
option.max = 2
option:depends({access_mode="wlan_dhcp",wlan_peerdns=""})
option:depends({access_mode="wlan_pppoe",wlan_peerdns=""})
option:depends("access_mode","wlan_static")

function option.cfgvalue(...)
	return m.uci:get("network_tmp","network","wlan_dns") or ""
end

function option.parse(self, section, value)
	local value = m:formvalue("cbid.network_tmp.network.wlan_dns")

	if value then
		m.uci:set("network_tmp","network","wlan_dns",value)
	else
		m.uci:delete("network_tmp","network","wlan_dns")
		m.uci:delete("network","wlan","dns")
	end
end

option = s:option(DummyValue,"_footer")
option.template = "admin_wizard/footer"

return m
