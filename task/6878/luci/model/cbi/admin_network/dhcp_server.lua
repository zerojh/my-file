--[[
@file dhcp setting.lua
@brief config web for dhcp setting
@version 1.0
@author harlan
@date 2015.02.11
]]--

local dsp = require "luci.dispatcher"
local uci = require "luci.model.uci".cursor()
local bit = require "bit"
local util = require "luci.util"

m = Map("dhcp",translate("Network / DHCP Server"))

s = m:section(NamedSection,"lan","dhcp")
m.currsection = s
s.addremove = false
s.anonymous = true

disabled = s:option(ListValue,"ignore",translate("DHCP Server"))
if m.uci:get("network_tmp","network","network_mode") == "bridge" then
		disabled:value("1",translate("Disabled"))
else
	disabled:value("0",translate("Enable"))
	disabled:value("1",translate("Disable"))
end
function disabled.cfgvalue(...)
	local tmp = m.uci:get("dhcp","lan","ignore") or "0"

	return tmp
end

local lan_ip = m.uci:get("network_tmp","network","lan_ipaddr") or "192.168.11.1"
local lan_netmask = m.uci:get("network_tmp","network","lan_netmask") or "255.255.255.0"
--local lan_ip_prefix = ""
local tmp_ip = util.split(lan_ip,".")
local tmp_netmask = util.split(lan_netmask,".")
local dhcp_ip_pool = bit.band(tmp_ip[1],tmp_netmask[1]).."."..bit.band(tmp_ip[2],tmp_netmask[2]).."."..bit.band(tmp_ip[3],tmp_netmask[3]).."."..bit.band(tmp_ip[4],tmp_netmask[4])

function number2ip(param)
	local ret_ip = ""
	local tmp_a = param
	local tmp_b = param
	local index = 0
	
	repeat
		index = index + 1
		tmp_a = tmp_b % 256
		tmp_b = math.floor(tmp_b / 256)
		if index == 1 then
			ret_ip = tmp_a
		else
			ret_ip = tmp_a.."."..ret_ip
		end
	until (tmp_b < 256)

	if index == 1 then
		ret_ip = "0.0."..tmp_b.."."..ret_ip
	elseif index == 2 then
		ret_ip = "0."..tmp_b.."."..ret_ip
	elseif index == 3 then
		ret_ip = tmp_b.."."..ret_ip
	end

	return ret_ip
end

function ip2number(param)
	local ret_number = 0

	if param then
		local param_tb = util.split(param,".")
		for i=1,4,1 do
			ret_number = ret_number + tonumber(param_tb[i])*(256^(4-i))
		end
	end

	return ret_number
end

function ipaddip(param1,param2)
	local ret_ip = ""

	if param1 and param2 then
		local param_tb1 = util.split(param1,".")
		local param_tb2 = util.split(param2,".")
		local num_add = 0

		for i=4,1,-1 do
			if i == 4 then
				ret_ip = (tonumber(param_tb1[i]) + tonumber(param_tb2[i]) + num_add) % 256
			else
				ret_ip = ((tonumber(param_tb1[i]) + tonumber(param_tb2[i]) + num_add) % 256).."."..ret_ip
			end
			num_add = math.floor((tonumber(param_tb1[i]) + tonumber(param_tb2[i]) + num_add) / 256)
		end
	end
	
	return ret_ip
end

function parseip2number(param1,param2)
	local ret_number = 0

	if param1 and param2 then
		local param_tb1 = util.split(param1,".")
		local param_tb2 = util.split(param2,".")

		for i=1,4,1 do
			ret_number = ret_number + (tonumber(param_tb1[i]) - tonumber(param_tb2[i]))*(256^(4-i))
		end
	end
	
	return ret_number
end

start_addr = s:option(Value,"start",translate("Start Address"))
start_addr.placeholder = ipaddip(dhcp_ip_pool,number2ip(1))
start_addr.datatype = "dhcp_startaddress("..lan_ip..","..lan_netmask..")"
start_addr.rmempty = false
start_addr:depends("ignore","0")
function start_addr.cfgvalue(...)
	local start = m.uci:get("dhcp","lan","start") or "1"--offset
	local start_number = bit.bor(bit.band(bit.bnot(ip2number(lan_netmask)),start),ip2number(dhcp_ip_pool))
	
	local ret_str = number2ip(start_number)

	return ret_str
end
function start_addr.write(self,section,value)
	local value = m:formvalue("cbid.dhcp.lan.start")
	
	if value then
		m.uci:set("dhcp","lan","start",parseip2number(value,dhcp_ip_pool))
	end
end

function start_addr.validate(self,value)
	local tmp = m:formvalue("cbid.dhcp.lan.disabled")
	
	if tmp == "0" then
		return Value.validate(self, value)
	else
		return value or ""
	end
end

--@ limit is the number 
end_addr = s:option(Value,"limit",translate("End Address"))
end_addr.placeholder = ipaddip(dhcp_ip_pool,number2ip(100))
end_addr.datatype = "dhcp_endaddress("..lan_ip..","..lan_netmask..")"
end_addr.rmempty = false
end_addr:depends("ignore","0")
function end_addr.cfgvalue(...)
	local limit = m.uci:get("dhcp","lan","limit") or "99"
	local start = m.uci:get("dhcp","lan","start")or "1"
	local start_number = bit.bor(bit.band(bit.bnot(ip2number(lan_netmask)),start),ip2number(dhcp_ip_pool))
	local max_number = ip2number(dhcp_ip_pool) + bit.band(bit.bnot(ip2number(lan_netmask)),ip2number("255.255.255.255")) - 1
	local ret_str = ""
	
	if (tonumber(limit)+start_number) >= max_number then
		ret_str = number2ip(max_number)
	else
		ret_str = number2ip(bit.bor(bit.band(bit.bnot(ip2number(lan_netmask)),start+limit-1),ip2number(dhcp_ip_pool)))
	end
	
	return ret_str
end
function end_addr.write(self,section,value)
	local value = m:formvalue("cbid.dhcp.lan.limit")

	if value then
		local tmp_start = m.uci:get("dhcp","lan","start")

		if tmp_start then
			m.uci:set("dhcp","lan","limit",parseip2number(value,dhcp_ip_pool)-tonumber(tmp_start)+1)
		end
	end
end
function end_addr.validate(self,value)
	local tmp = m:formvalue("cbid.dhcp.lan.disabled")
	
	if tmp == "0" then
		return Value.validate(self, value)
	else
		return value or ""
	end
end

leasetime = s:option(Value,"leasetime",translate("Leasetime (Hour/Minute/Second)"))
leasetime.template = "admin_network/leasetime"
leasetime:depends("ignore", "0")
function leasetime.cfgvalue(...)
	local tmp_lease = m.uci:get("dhcp","lan","leasetime") or "infinite"

	if tmp_lease == "infinite" then
		return "0", "0", "0"
	end

	if tmp_lease:match("(%d+)h") then
		local hour = tmp_lease:match("(%d+)h")
		return hour, "0", "0"
	elseif tmp_lease:match("(%d+)m") then
		local min = tonumber(tmp_lease:match("(%d+)m"))
		local hour = math.modf(min / 60)
		min = min % 60
		return hour, min, "0"
	elseif tmp_lease:match("(%d+)s") then
		local sec = tonumber(tmp_lease:match("(%d+)s"))
		local hour = math.modf(sec / 3600)
		local min = math.modf(sec / 60) - hour * 60
		sec = sec % 60
		return hour , min, sec
	else
		return "0", "0", "0"
	end
	return "0", "0", "0"
end

function leasetime.parse(self, section, value)
	local hour = tonumber(m:formvalue("cbid.dhcp.lan.leasetime_h") or "0")
	local min = tonumber(m:formvalue("cbid.dhcp.lan.leasetime_m") or "0")
	local sec = tonumber(m:formvalue("cbid.dhcp.lan.leasetime_s") or "0")
	local val

	if sec == 0  and min == 0 and hour == 0 then
		val = "infinite"
	elseif sec == 0 and min == 0 and hour ~= 0 then
		val = hour.."h"
	elseif sec == 0 and min ~= 0 then
		val = hour * 60 + min
		val = val.."m"
	else
		val = hour * 3600 + min * 60 + sec
		val = val.."s"
	end
	m.uci:set("dhcp","lan","leasetime",val)
end

gateway = s:option(Value,"dhcp_option_gw",translate("Gateway"))
gateway.datatype = "dhcp_gateway("..lan_ip..","..lan_netmask..")"
gateway:depends("ignore","0")
function gateway.cfgvalue(...)
	local tmp = m.uci:get_list("dhcp", "lan", "dhcp_option")
	local ret_gw
	
	if tmp then
		for k,v in pairs(tmp) do
			if v:match("^3,") then
				ret_gw = v:match("^3,([0-9%.]+)")
				break
			end
		end
	end
	
	return ret_gw or ""
end

function gateway.parse(self, section, value)
	local gw = m:formvalue("cbid.dhcp.lan.dhcp_option_gw")
	local dns1 = m:formvalue("cbid.dhcp.lan.dhcp_option_dns1")
	local dns2 = m:formvalue("cbid.dhcp.lan.dhcp_option_dns2")
	local list_tb = {}
	local flag = false

	--if gw and dns1 and dns2 then
	if gw and gw ~= "" then
		table.insert(list_tb,"3,"..gw)
		flag = true
	end
	if dns1 ~= "" or dns2 ~= "" then
		local tmp
		
		if dns1 and dns1 ~= "" then
			tmp = "6,"..dns1
		end
		if dns2 and dns2 ~= "" then
			if tmp then
				tmp = tmp..","..dns2
			else
				tmp = "6,"..dns2
			end
		end

		if tmp then
			table.insert(list_tb,tmp)
			flag = true
		end
	end

	if flag then
		m.uci:set_list("dhcp", "lan", "dhcp_option", list_tb)
	else
		m.uci:delete("dhcp", "lan", "dhcp_option")
	end
	--end
end

-- domain = s:option(Value,"domain",translate("Domain"))
-- domain:depends("disabled","0")
-- function domain.cfgvalue(...)
-- 	return m.uci:get("dhcp", "dnsmasq", "domain") or ""
-- end

-- function domain.parse(self, section, value)
-- 	local value = m:formvalue("cbid.dhcp.lan.domain")

-- 	if value then
-- 		m.uci:set("dhcp", "dnsmasq", "domain", value)
-- 	end
-- end

main_dns = s:option(Value,"dhcp_option_dns1",translate("Master DNS"))
main_dns.datatype = "abc_ip4addr"
main_dns:depends("ignore","0")
function main_dns.cfgvalue(...)
	local tmp = m.uci:get_list("dhcp", "lan", "dhcp_option")
	local ret_dns
	
	if tmp then
		for k,v in pairs(tmp) do
			if v:match("^6,") then
				ret_dns = v:match("^6,([0-9%.]+)")
				break
			end
		end
	end
	
	return ret_dns or ""
end

function main_dns.parse(self, section, value)
	local gw = m:formvalue("cbid.dhcp.lan.dhcp_option_gw")
	local dns1 = m:formvalue("cbid.dhcp.lan.dhcp_option_dns1")
	local dns2 = m:formvalue("cbid.dhcp.lan.dhcp_option_dns2")
	local list_tb = {}
	local flag = false

	--if gw and dns1 and dns2 then
	--if dns1 and dns2 then
	if gw and gw ~= "" then
		table.insert(list_tb,"3,"..gw)
		flag = true
	end
	if (dns1 and dns1 ~= "") or (dns2 and dns2 ~= "") then
		local tmp
		
		if dns1 and dns1 ~= "" then
			tmp = "6,"..dns1
		end
		if dns2 and dns2 ~= "" then
			if tmp then
				tmp = tmp..","..dns2
			else
				tmp = "6,"..dns2
			end
		end

		if tmp then
			table.insert(list_tb,tmp)
			flag = true
		end
	end

	if flag then
		m.uci:set("dhcp", "lan", "dhcp_option", list_tb)
	else
		m.uci:delete("dhcp", "lan", "dhcp_option")
	end
	--end
end

slave_dns = s:option(Value,"dhcp_option_dns2",translate("Slave DNS"))
slave_dns.datatype = "abc_ip4addr"
slave_dns:depends("ignore","0")
function slave_dns.cfgvalue(...)
	local tmp = m.uci:get_list("dhcp", "lan", "dhcp_option")
	local ret_dns
	
	if tmp then
		for k,v in pairs(tmp) do
			if v:match("^6,") then
				ret_dns = v:match("^6,[0-9%.]+,([0-9%.]+)")
				break
			end
		end
	end
	
	return ret_dns or ""
end

function slave_dns.parse(self, section, value)
	local gw = m:formvalue("cbid.dhcp.lan.dhcp_option_gw")
	local dns1 = m:formvalue("cbid.dhcp.lan.dhcp_option_dns1")
	local dns2 = m:formvalue("cbid.dhcp.lan.dhcp_option_dns2")
	local list_tb = {}
	local flag = false

	--if gw and dns1 and dns2 then
	--if gw and dns1 and dns2 then
	if gw and gw ~= "" then
		table.insert(list_tb,"3,"..gw)
		flag = true
	end
	if dns1 ~= "" or dns2 ~= "" then
		local tmp
		
		if dns1 and dns1 ~= "" then
			tmp = "6,"..dns1
		end
		if dns2 and dns2 ~= "" then
			if tmp then
				tmp = tmp..","..dns2
			else
				tmp = "6,"..dns2
			end
		end

		if tmp then
			table.insert(list_tb,tmp)
			flag = true
		end
	end

	if flag then
		m.uci:set("dhcp", "lan", "dhcp_option", list_tb)
	else
		m.uci:delete("dhcp", "lan", "dhcp_option")
	end
	--end
end

return m

