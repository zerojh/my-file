local uci = require "luci.model.uci".cursor()
local uci_tmp = require "luci.model.uci".cursor("/tmp/config")
local dsp = require "luci.dispatcher"
local flag = uci_tmp:get("wizard","globals","network") or "1"
local fs = require "nixio.fs"
local fs_server = require "luci.scripts.fs_server"
local sys = require "luci.sys"

--@ init network_tmp from network,wireless
if not fs.access("/etc/config/network_tmp") then
	require "luci.model.network".profile_network_init()
end

m = Map("network_tmp","上网设置")
m:chain("network")
m:chain("firewall")
m:chain("wireless")
m.pageaction = false

if luci.http.formvalue("cbi.cancel") then
	m.redirect = dsp.build_url("admin","wizard")
elseif luci.http.formvalue("cbi.save") then
	flag = "1"
	uci_tmp:set("wizard","globals","network","1")
	uci_tmp:save("wizard")
	uci_tmp:commit("wizard")
	m.redirect = dsp.build_url("admin","wizard","siptrunk")
end

--@ first
s = m:section(NamedSection,"network","setting")

--#### Description #####----
option = s:option(DummyValue,"_description")
option.template = "admin_wizard/description"
option.data = {}
table.insert(option.data,"本设备提供五种上网方式．")
table.insert(option.data,"")
table.insert(option.data,"有线上网方式有＂<span style='color:#b94a48;'>动态IP</span>＂、＂<span style='color:#b94a48;'>静态IP</span>＂和＂<span style='color:#b94a48;'>PPPOE</span>＂．")
table.insert(option.data,"无线上网方式有＂<span style='color:#b94a48;'>动态IP</span>＂和＂<span style='color:#b94a48;'>静态IP</span>＂．")

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
function option.cfgvalue(self, section)
	if flag == "1" then
		return AbstractValue.cfgvalue(self, section)
	else
		return nil
	end
end
function option.write(self, section, value)
	if value == "wan_dhcp" or value == "wan_static" or value == "wan_pppoe" then
		m.uci:set("network_tmp","network","network_mode","route")
		m.uci:set("network_tmp","network","wan_proto",string.sub(value,5))
		if m.uci:get("wireless","wifi0","mode") == "sta" then
			m.uci:set("wireless","wifi0","ssid","DC1000")
			m.uci:set("wireless","wifi0","encryption","none")
			m.uci:delete("wireless","wifi0","key")
		end
		m.uci:set("wireless","wifi0","mode","ap")
		m.uci:set("firewall",section_firewall,"enabled","1")
	elseif value == "wlan_dhcp" or value == "wlan_static" then
		m.uci:set("network_tmp","network","network_mode","client")
		m.uci:set("network_tmp","network","wan_proto",string.sub(value,6))
		m.uci:set("wireless","wifi0","mode","sta")
		m.uci:set("firewall",section_firewall,"enabled","0")
	end

	m.uci:set("network_tmp","network","access_mode",value)
end

--@ Extranet {
option = s:option(DummyValue,"_external","外网配置")
--####Extranet WIFI####----
option = s:option(Value,"wifi_ssid","可接入WIFI列表")
option.margin = "30px"
option.rmempty = false
option.datatype = "uni_ssid"
option.template = "admin_wizard/ssid"
option:depends("access_mode","wlan_dhcp")
option:depends("access_mode","wlan_static")
function option.cfgvalue(self, section)
	if flag == "1" then
		return m.uci:get("wireless","wifi0","ssid")
	else
		return nil
	end
end
function option.validate(self, value)
	if value then
		return Value.validate(self, value)
	else
		return ""
	end
end
function option.write(self,section,value)
	return m.uci:set("wireless","wifi0","ssid",value or "")
end

option = s:option(ListValue,"wifi_encryption","WIFI加密方式")
option.margin = "30px"
option.default = "psk2"
option:value("psk","WPA+PSK")
option:value("psk2","WPA2+PSK")
option:value("wep","WEP")
option:value("none","无")
option:depends("access_mode","wlan_dhcp")
option:depends("access_mode","wlan_static")
function option.cfgvalue(self, section)
	if flag == "1" then
		return m.uci:get("wireless","wifi0","encryption")
	else
		return nil
	end
end
function option.validate(self,value)
	if value then
		if value == "none" then
			m.uci:delete("wireless","wifi0","key")
		end
		if value ~= "wep" and m.uci:get("wireless","wifi0","wep") then
			m.uci:delete("wireless","wifi0","wep")
		end
		return Value.validate(self,value)
	else
		return ""
	end
end
function option.write(self,section,value)
	return m.uci:set("wireless","wifi0","encryption",value or "psk2")
end

option = s:option(Value,"wifi_key","WIFI密码")
option.margin = "30px"
option.datatype = "wifi_password"
option.rmempty = false
option.password = true
option:depends({access_mode="wlan_dhcp",wifi_encryption="psk"})
option:depends({access_mode="wlan_dhcp",wifi_encryption="psk2"})
option:depends({access_mode="wlan_static",wifi_encryption="psk"})
option:depends({access_mode="wlan_static",wifi_encryption="psk2"})
function option.cfgvalue(self, section)
	if flag == "1" then
		local encrypt = m.uci:get("wireless","wifi0","encryption") or "psk2"
		if encryption ~= "none" then
			return m.uci:get("wireless","wifi0","key")
		else
			return nil
		end
	else
		return nil
	end
end
function option.validate(self,value)
	if value then
		return value or ""
	else
		return ""
	end
end
function option.write(self,section,value)
	return m.uci:set("wireless","wifi0","key",value or "")
end

--# wifi wep encryption
option = s:option(ListValue,"wifi_wep",translate(" "))
option.margin = "30px"
option:depends({access_mode="wlan_dhcp",wifi_encryption="wep"})
option:depends({access_mode="wlan_static",wifi_encryption="wep"})
option:value("64bit","64bit")
option:value("128bit","128bit")
function option.cfgvalue(self, section)
	if flag == "1" then
		return m.uci:get("wireless","wifi0","wep")
	else
		return nil
	end
end
function option.validate(self, value)
	if value then
		return Value.validate(self, value)
	else
		return ""
	end
end
function option.write(self,section,value)
	return m.uci:set("wireless","wifi0","wep",value or "")
end

--# wifi wep key
option = s:option(Value,"wifi_wep_key","WIFI密码")
option.margin = "30px"
option.rmempty = false
option:depends("wifi_encryption","wep")
option.datatype = "wep_password"
option.password = true
function option.cfgvalue(...)
	if flag == "1" then
		local tmp = m.uci:get("wireless","wifi0","encryption")
		local key = m.uci:get("wireless","wifi0","key")
		
		if tmp == "wep" and key and key:match("^[0-9a-fA-F]+$") then
			local ret_key = ""
			local i = 1

			while string.byte(key,i) do
				ret_key = ret_key..string.format("%c","0x"..string.sub(key,i,i+1))
				i = i + 2
			end
			
			return ret_key
		else
			return key or ""
		end
	end
end
function option.write(self, section, value)
	local tmp = m:formvalue("cbid.network_tmp.network.wifi_encryption")
	local wep_type = m:formvalue("cbid.network_tmp.network.wifi_wep")

	if tmp == "wep" then
		if wep_type == "64bit" then
			local ret_str = sys.exec("echo -n '"..(value or "").."' | hexdump -e '5/1 \"%02x\"'")
			m.uci:set("wireless","wifi0","key",ret_str or "")
		else
			local ret_str = sys.exec("echo -n '"..(value or "").."' | hexdump -e '13/1 \"%02x\"'")
			m.uci:set("wireless","wifi0","key",ret_str or "")
		end
	end
end
function option.validate(self,value)
	local tmp = m:formvalue("cbid.network_tmp.network.wifi_encryption")
	
	if value and tmp == "wep" then
		return Value.validate(self,value)
	else
		return value or ""
	end
end

--####Extranet static ip addr####----
option = s:option(Value,"wan_ipaddr","外网IP地址")
option.margin = "30px"
option.datatype = "wan_addr"
option.rmempty = false
option:depends("access_mode","wan_static")
option:depends("access_mode","wlan_static")
function option.cfgvalue(self, section)
	if flag == "1" then
		return AbstractValue.cfgvalue(self, section)
	else
		return nil
	end
end
function option.validate(self, value)
	local tmp = m:formvalue("cbid.network_tmp.network.access_mode")
	
	if tmp == "wan_static" or tmp == "wlan_static" then
		return Value.validate(self, value)
	else
		m.uci:delete("network_tmp","network","wan_ipaddr")
		m.uci:delete("network","wan","ipaddr")
		return value or ""
	end
end

--####Extranet static netmask####----
option = s:option(Value,"wan_netmask","外网子网掩码")
option.margin = "30px"
option.rmempty = false
option:depends("access_mode","wan_static")
option:depends("access_mode","wlan_static")
option.datatype = "netmask"
option.default = "255.255.255.0"
option:value("255.0.0.0","255.0.0.0")
option:value("255.255.0.0","255.255.0.0")
option:value("255.255.255.0","255.255.255.0")
function option.cfgvalue(self, section)
	if flag == "1" then
		return AbstractValue.cfgvalue(self, section)
	else
		return nil
	end
end
function option.validate(self,value)
	local tmp = m:formvalue("cbid.network_tmp.network.access_mode")

	if tmp == "wan_static" or tmp == "wlan_static" then
		return Value.validate(self,value)
	else
		m.uci:delete("network_tmp","network","wan_netmask")
		m.uci:delete("network","wan","netmask")
		return value or ""
	end
end

--####Extranet static gateway####----
option = s:option(Value,"wan_gateway","外网默认网关")
option.margin = "30px"
option.datatype = "wan_gateway"
option.rmempty = false
option:depends("access_mode","wan_static")
option:depends("access_mode","wlan_static")
function option.cfgvalue(self, section)
	if flag == "1" then
		return AbstractValue.cfgvalue(self, section)
	else
		return nil
	end
end
function option.validate(self, value)
	local tmp = m:formvalue("cbid.network_tmp.network.access_mode")
	
	if tmp == "wan_static" or tmp == "wlan_static" then
		return Value.validate(self, value)
	else
		m.uci:delete("network_tmp","network","wan_gateway")
		m.uci:delete("network","wan","gateway")
		return value or ""
	end
end

--@ PPPOE {
--####wan pppoe username####----
option = s:option(Value,"wan_username","用户名")
option.margin = "30px"
option.rmempty = false
option:depends("access_mode","wan_pppoe")
function option.cfgvalue(self, section)
	if flag == "1" then
		return AbstractValue.cfgvalue(self, section)
	else
		return nil
	end
end
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
option.margin = "30px"
option.password = true
option.rmempty = false
option:depends("access_mode","wan_pppoe")
function option.cfgvalue(self, section)
	if flag == "1" then
		return AbstractValue.cfgvalue(self, section)
	else
		return nil
	end
end
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
option.margin = "30px"
option:depends("access_mode","wan_pppoe")
function option.cfgvalue(self, section)
	if flag == "1" then
		return AbstractValue.cfgvalue(self, section)
	else
		return nil
	end
end
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
option.margin = "30px"
option:depends("access_mode","wan_dhcp")
option:depends("access_mode","wan_pppoe")
option:depends("access_mode","wlan_dhcp")
option.default = option.enabled
function option.cfgvalue(self, section)
	if flag == "1" then
		return AbstractValue.cfgvalue(self, section)
	else
		return nil
	end
end

--####wan static dns####----
option = s:option(DynamicList,"wan_dns","使用自定义的DNS服务器")
option.margin = "30px"
option.datatype = "abc_ip4addr"
option.cast     = "string"
option.addremove = false
option.max = 2
option:depends({access_mode="wan_dhcp",wan_peerdns=""})
option:depends({access_mode="wan_pppoe",wan_peerdns=""})
option:depends({access_mode="wlan_dhcp",wan_peerdns=""})
option:depends("access_mode","wan_static")
option:depends("access_mode","wlan_static")

function option.cfgvalue(self, section)
	if flag == "1" then
		return m.uci:get("network_tmp","network","wan_dns")
	else
		return ""
	end
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

--@ LAN {
option = s:option(DummyValue,"_internal","内网配置")
--####lan ip addr####----
option = s:option(Value,"lan_ipaddr","内网IP地址")
option.margin = "30px"
option.rmempty = false
option.datatype = "lan_addr"
option.default = "192.168.11.1"
function option.cfgvalue(self, section)
	if flag == "1" then
		return AbstractValue.cfgvalue(self, section)
	else
		return nil
	end
end

--####lan netmask####----
option = s:option(Value,"lan_netmask","内网子网掩码")
option.margin = "30px"
option.datatype = "netmask"
option.rmempty = false
option.default = "255.255.255.0"
option:value("255.0.0.0","255.0.0.0")
option:value("255.255.0.0","255.255.0.0")
option:value("255.255.255.0","255.255.255.0")
function option.cfgvalue(self, section)
	if flag == "1" then
		return AbstractValue.cfgvalue(self, section)
	else
		return nil
	end
end

--@ } END LAN

option = s:option(DummyValue,"_footer")
option.template = "admin_wizard/footer"

return m
