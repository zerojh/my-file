local uci = require "luci.model.uci".cursor()

local network_mode = uci:get("network","globals","network_mode")
if not network_mode then
	network_mode = "route"
	uci:set("network","globals","network_mode",network_mode)
	uci:save("network")
end

m = Map("network",translate(""), translate(""))

--@ WAN Config {------
if network_mode == "route" then
	s = m:section(NamedSection,"wan","interface")

	option = s:option(DummyValue,"_wan",translate("WAN"))

	--####wan proto#####----
	option = s:option(ListValue,"proto",translate("Protocol"))
	option.margin = "30px"
	option:value("dhcp",translate("DHCP"))
	option:value("static",translate("Static address"))
	option:value("pppoe",translate("PPPOE"))

	--@ WAN Static IP {
	--####wan static ip addr####----
	option = s:option(Value,"ipaddr",translate("IP Address"))
	option.margin = "30px"
	option.datatype = "wan_addr"
	option.rmempty = false
	option:depends("proto","static")
	function option.validate(self, value)
		local proto = m:formvalue("cbid.network.wan.proto")
		
		if  proto == "static" then
			return Value.validate(self, value)
		else
			m.uci:delete("network","wan","ipaddr")
			return value or ""
		end
	end

	--####wan static netmask####----
	option = s:option(Value,"netmask",translate("Netmask"))
	option.margin = "30px"
	option.rmempty = false
	option:depends("proto","static")
	option.datatype = "netmask"
	option.default = "255.255.255.0"
	option:value("255.0.0.0","255.0.0.0")
	option:value("255.255.0.0","255.255.0.0")
	option:value("255.255.255.0","255.255.255.0")
	function option.validate(self,value)
		local wan_proto = m:formvalue("cbid.network.wan.proto")

		if wan_proto == "static" then
			return Value.validate(self,value)
		else
			m.uci:delete("network","wan","netmask")
			return value or ""
		end
	end

	--####wan static gateway####----
	option = s:option(Value,"gateway",translate("Default Gateway"))
	option.margin = "30px"
	option.datatype = "wan_gateway"
	option.rmempty = false
	option:depends("proto","static")

	function option.validate(self, value)
		local wan_proto = m:formvalue("cbid.network.wan.proto")
		
		if wan_proto == "static"  then
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
	option.margin = "30px"
	option.rmempty = false
	option:depends("proto","pppoe")
	function option.validate(self, value)
		local wan_proto = m:formvalue("cbid.network.wan.proto")

		if  wan_proto == "pppoe" then
			return Value.validate(self, value)
		else
			m.uci:delete("network","wan","username")
			return value or ""
		end
	end

	--####wan pppoe password####----
	option = s:option(Value,"password",translate("Password"))
	option.password = true
	option.margin = "30px"
	option.rmempty = false
	option:depends("proto","pppoe")
	function option.validate(self,value)
		local wan_proto = m:formvalue("cbid.network.wan.proto")

		if wan_proto == "pppoe" then
			return Value.validate(self,value)
		else
			m.uci:delete("network","wan","password")
			return value or ""
		end
	end

	--####wan pppoe service####----
	option = s:option(Value,"service",translate("Server Name"))
	option.margin = "30px"
	option:depends("proto","pppoe")
	function option.validate(self,value)
		local wan_proto = m:formvalue("cbid.network.wan.proto")

		if wan_proto == "pppoe" then
			return Value.validate(self,value)
		else
			m.uci:delete("network","wan","service")
			return value or ""
		end
	end
	--@ } END PPPOE

	--####wan auto dns####----
	option = s:option(Flag,"peerdns",translate("Obtain DNS server address automatically"))
	option.margin = "30px"
	option.rmempty = false
	option:depends("proto","dhcp")
	option:depends("proto","pppoe")
	option.default = option.enabled

	--####wan static dns####----
	option = s:option(DynamicList, "dns",translate("Use custom DNS server"))
	option:depends("peerdns","")
	option.margin = "30px"
	option.datatype = "abc_ip4addr"
	option.cast     = "string"
	option.addremove = false
	option.max = 2

	function option.cfgvalue(...)
		return m.uci:get("network","wan","dns") or ""
	end

	function option.parse(self, section, value)
		local value = m:formvalue("cbid.network.wan.dns")

		if value then
			m.uci:set("network","wan","dns",value)
		else
			m.uci:delete("network","wan","dns")
		end
	end

	rp = s:option(Flag,"rebind_protection",translate("Disable Private Internets(RFC2918) DNS responses"))
	rp.margin = "30px"

	function rp.cfgvalue(...)
		return m.uci:get("dhcp", "dnsmasq", "rebind_protection") or "0"
	end

	function rp.parse(self, section, value)
		local v = m:formvalue("cbid.network.wan.rebind_protection")

		m.uci:set("dhcp", "dnsmasq", "rebind_protection", v or "0")
		m.uci:save("dhcp")
	end

	--####wan mtu####----
	option = s:option(Value,"wan_mtu",translate("MTU"))
	option.margin = "30px"
	option.placeholder = "1500"
	option.datatype    = "range(576,1500)"
end
--@ } END WAN Config-----


s = m:section(NamedSection,"lan","interface")
--@ LAN Config { -------
option = s:option(DummyValue,"_lan",translate("LAN"))

if network_mode == "bridge" then
	--@ only for bridge model
	option = s:option(ListValue,"proto",translate("Protocol"))
	option.margin = "30px"
	option:value("static",translate("Static address"))
	option:value("dhcp",translate("DHCP"))
	option:value("pppoe",translate("PPPOE"))
	--@ only for bridge model
end

--####lan static ip addr####----
option = s:option(Value,"ipaddr",translate("IP Address"))
option.margin = "30px"
option.rmempty = false
option.datatype = "lan_addr"
option.default = "192.168.11.1"
if network_mode == "bridge" then
	option:depends("proto","static")
end

function option.validate(self, value)
	local lan_proto = m:formvalue("cbid.network.lan.proto")
	
	if lan_proto == "static" or network_mode == "route" or network_mode == "client" then
		return Value.validate(self, value)
	else
		m.uci:delete("network","lan","ipaddr")
		return value or ""
	end
end

--####lan static netmask####----
option = s:option(Value,"netmask",translate("Netmask"))
option.margin = "30px"
option.datatype = "netmask"
option.rmempty = false
option.default = "255.255.255.0"
option:value("255.0.0.0","255.0.0.0")
option:value("255.255.0.0","255.255.0.0")
option:value("255.255.255.0","255.255.255.0")
if network_mode == "bridge" then
	option:depends("proto","static")
end

function option.validate(self,value)
	local lan_proto = m:formvalue("cbid.network.lan.proto")

	if lan_proto == "static" or network_mode == "route" or network_mode == "client" then
		return Value.validate(self,value)
	else
		m.uci:delete("network","lan","netmask")
		return value or ""
	end
end
	
if network_mode == "bridge" then
	--####bridge model lan pppoe username####----
	option = s:option(Value,"username",translate("Username"))
	option.margin = "30px"
	option.rmempty = false
	option:depends("proto","pppoe")
	function option.validate(self, value)
		local lan_proto = m:formvalue("cbid.network.lan.proto")
		
		if lan_proto == "pppoe" then
			return Value.validate(self, value)
		else
			m.uci:delete("network","lan","username")
			return value or ""
		end
	end

	--####bridge model lan pppoe password####----
	option = s:option(Value,"password",translate("Password"))
	option.password = true
	option.margin = "30px"
	option.rmempty = false
	option:depends("proto","pppoe")
	function option.validate(self,value)
		local lan_proto = m:formvalue("cbid.network.lan.proto")

		if lan_proto == "pppoe" then
			return Value.validate(self,value)
		else
			m.uci:delete("network","lan","password")
			return value or ""
		end
	end

	--####bridge model lan pppoe service####----
	option = s:option(Value,"service",translate("Server Name"))
	option.margin = "30px"
	option:depends("proto","pppoe")
	function option.validate(self,value)
		local lan_proto = m:formvalue("cbid.network.lan.proto")

		if lan_proto == "pppoe" then
			return Value.validate(self,value)
		else
			m.uci:delete("network","lan","service")
			return value or ""
		end
	end

	--####lan static gateway####----
	option = s:option(Value,"gateway",translate("Default Gateway"))
	option.margin = "30px"
	option.datatype = "lan_gateway"
	option.rmempty = false
	option:depends("proto","static")

	function option.validate(self, value)
		local lan_proto = m:formvalue("cbid.network.lan.proto")
		
		if lan_proto == "static" then
			return Value.validate(self, value)
		else
			m.uci:delete("network","lan","gateway")
			return value or ""
		end
	end

	--####lan auto dns####----
	option = s:option(Flag,"peerdns",translate("Obtain DNS server address automatically"))
	option.margin = "30px"
	option:depends("proto","dhcp")
	option:depends("proto","pppoe")
	option.rmempty = false
	option.default = option.enabled

	function option.validate(self,value)
		local lan_proto = m:formvalue("cbid.network.lan.proto")

		if lan_proto == "dhcp" or lan_proto == "pppoe" then
			return Value.validate(self,value)
		else
			m.uci:delete("network","lan","peerdns")
			return value or ""
		end
	end
	
	--####lan static dns####----
	option = s:option(DynamicList, "dns",translate("Use custom DNS server"))
	option:depends("peerdns","")
	option.margin = "30px"
	option.datatype = "abc_ip4addr"
	option.cast     = "string"
	option.addremove = false
	option.max = 2

	function option.cfgvalue(...)
		return m.uci:get("network","lan","dns") or ""
	end

	function option.parse(self, section, value)
		local value = m:formvalue("cbid.network.lan.dns")

		if value then
			m.uci:set("network","lan","dns",value)
		else
			m.uci:delete("network","lan","dns")
		end
	end

	lan_rp = s:option(Flag,"rebind_protection",translate("Disable Private Internets(RFC2918) DNS responses"))
	lan_rp.margin = "30px"

	function lan_rp.cfgvalue(...)
		return m.uci:get("dhcp", "dnsmasq", "rebind_protection") or "0"
	end

	function lan_rp.parse(self, section, value)
		local value = m:formvalue("cbid.network.lan.rebind_protection")
		if "bridge" == mod then
			m.uci:set("dhcp", "dnsmasq", "rebind_protection", v or "0")
			m.uci:save("dhcp")
		end
	end

	--####lan mtu####----
	option = s:option(Value,"mtu",translate("MTU"))
	option.margin = "30px"
	option.placeholder = "1500"
	option.datatype    = "range(576,1500)"
end
--@ } END LAN Config -------

return m
