local fs = require "nixio.fs"
local util = require "luci.util"
local bit = require "bit"
local uci = require "luci.model.uci".cursor()

m = Map("network",translate(""), translate(""))

s = m:section(NamedSection,"wan","interface")

if fs.access("/proc/gpon_exist") and util.exec("cat /proc/gpon_exist"):match("1") then
	wan_switch = s:option(ListValue, "wan_switch", translate("WAN/GPON Switch"))
	wan_switch.default = "off"
	wan_switch.rmempty = false
	wan_switch:value("on", translate("GPON"))
	wan_switch:value("off", translate("WAN"))
end

opt = s:option(ListValue,"proto",translate("Protocol"))
opt.rmempty = false
opt.default = "dhcp"
opt:value("static",translate("static"))
opt:value("dhcp",translate("DHCP"))
opt:value("pppoe",translate("PPPoE"))

--@ WAN Static IP {
--####wan static ip addr####----
option = s:option(Value,"ipaddr",translate("IP Address"))
--option.margin = "30px"
option.rmempty = false
option:depends("proto","static")
local profile = uci:get_all("network") or {}
local add_list = ""

for k,v in pairs(profile) do
	if v['.type'] == "interface" and (k:match("^vwan") or k:match("^vlan") or k == "lan") and v.proto == "static" and v.ipaddr and v.netmask then
		local tmp_ip = util.split(v.ipaddr,".")
		local tmp_netmask = util.split(v.netmask,".")
		local tmp_subnet = bit.band(tmp_ip[1],tmp_netmask[1]).."."..bit.band(tmp_ip[2],tmp_netmask[2]).."."..bit.band(tmp_ip[3],tmp_netmask[3]).."."..bit.band(tmp_ip[4],tmp_netmask[4])
		add_list = add_list..tmp_subnet.."&"
	end
end
option.datatype = "ip4addr_dif(wan,"..add_list..")"

function option.validate(self, value)
	local tmp = m:formvalue("cbid.network.wan.proto")
	 
	if tmp == "static" then
		local tmp_netmask = m:formvalue("cbid.network.wan.netmask")
		self.datatype = "ip4addr_dif("..tmp_netmask..","..add_list..")"
		
		return Value.validate(self, value)
	else 
		m.uci:delete("network","wan","ipaddr")
		return value or ""
	end
end	

--####wan static netmask####----
option = s:option(Value,"netmask",translate("Netmask"))
--option.margin = "30px"
option.rmempty = false
option:depends("proto","static")
option.datatype = "netmask"
option.default = "255.255.255.0"
option:value("255.0.0.0","255.0.0.0")
option:value("255.255.0.0","255.255.0.0")
option:value("255.255.255.0","255.255.255.0")
function option.validate(self,value)
	local pro = m:formvalue("cbid.network.wan.proto")

	if pro == "static" then
		return Value.validate(self,value)
	else
		m.uci:delete("network","wan","netmask")
		return value or ""
	end
end

--####wan static gateway####----
option = s:option(Value,"gateway",translate("Default Gateway"))
--option.margin = "30px"
option.datatype = "wan_gateway(nil,wan)"
option.rmempty = false
option:depends("proto","static")

function option.validate(self, value)
	local tmp = m:formvalue("cbid.network.wan.proto")
	
	if tmp == "static" then
		local tmp_ip = m:formvalue("cbid.network.wan.ipaddr")
		local tmp_netmask = m:formvalue("cbid.network.wan.netmask")
		self.datatype = "wan_gateway("..tmp_ip.."&"..tmp_netmask..",wan)"
		
		return Value.validate(self, value)
	else 
		m.uci:delete("network","wan","gateway")
		return value or ""
	end
end	
--@ } END static IP

--@ PPPOE {
--####wan pppoe username####----
option = s:option(Value,"username",translate("Username"))
--option.margin = "30px"
option.rmempty = false
option:depends("proto","pppoe")
function option.validate(self, value)
	local tmp = m:formvalue("cbid.network.wan.proto")

	if tmp == "pppoe" then
		return Value.validate(self, value)
	else 
		m.uci:delete("network","wan","username")
		return value or ""
	end
end	

--####wan pppoe password####----
option = s:option(Value,"password",translate("Password"))
option.password = true
--option.margin = "30px"
option.rmempty = false
option:depends("proto","pppoe")
function option.validate(self,value)
	local tmp = m:formvalue("cbid.network.wan.proto")

	if tmp == "pppoe" then
		return Value.validate(self,value)
	else
		m.uci:delete("network","wan","password")
		return value or ""
	end
end

--####wan pppoe service####----
option = s:option(Value,"service",translate("Server Name"))
--option.margin = "30px"
option:depends("proto","pppoe")
function option.validate(self,value)
	local tmp = m:formvalue("cbid.network.wan.proto")

	if tmp == "pppoe" then
		return Value.validate(self,value)
	else
		m.uci:delete("network","wan","service")
		return value or ""
	end
end

--@ } END PPPOE

--####wan mtu####----
option = s:option(Value,"mtu",translate("MTU"))
--option.margin = "30px"
--option.placeholder = "1500"
option.datatype = "mtu(nil,wan)"
function option.validate(self,value)
	local tmp = m:formvalue("cbid.network.wan.proto")
	
	if tmp == "pppoe" then
		self.datatype = "mtu(pppoe,wan)"
	else
		self.datatype = "mtu(nil,wan)"
	end

	return Value.validate(self,value)
end

--####wan auto dns####----
option = s:option(Flag,"peerdns",translate("Obtain DNS server address automatically"))
--option.margin = "30px"
option.rmempty = false
option:depends("proto","dhcp")
option:depends("proto","pppoe")
option.default = option.enabled

--####wan static dns####----
option = s:option(DynamicList, "dns",translate("Use custom DNS server"))
option:depends("peerdns","")
--option.margin = "30px"
option.datatype = "abc_ip4addr"
option.cast     = "string"
option.addremove = false
option.max = 2

function option.cfgvalue(...)
	return m.uci:get("network","wan","dns") or ""
end

function option.write(self, section, value)
	local value = m:formvalue("cbid.network.wan.dns")

	if value then
		m.uci:set("network","wan","dns",value)
	else
		m.uci:delete("network","wan","dns")
	end
end
--@ } END WAN Config-----

return m
