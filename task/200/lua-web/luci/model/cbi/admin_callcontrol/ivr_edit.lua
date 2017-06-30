local dsp = require "luci.dispatcher"
local uci = require "luci.model.uci".cursor()

uci:check_cfg("ivr")
uci:check_cfg("endpoint_fxso")
uci:check_cfg("endpoint_mobile")
uci:check_cfg("endpoint_sipphone")
uci:check_cfg("endpoint_siptrunk")
uci:check_cfg("endpoint_ringgroup")

local endpoint_sipphone = uci:get_all("endpoint_sipphone") or {}
local endpoint_siptrunk = uci:get_all("endpoint_siptrunk") or {}
local endpoint_fxso = uci:get_all("endpoint_fxso") or {}
local endpoint_mobile = uci:get_all("endpoint_mobile") or {}
local endpoint_ringgroup = uci:get_all("endpoint_ringgroup") or {}
local interface = uci:get("system","main","interface") or ""
local MAX_SIP_EXTENSION = tonumber(uci:get("profile_param","global","max_sip_extension") or "32")
local MAX_SIP_TRUNK = tonumber(uci:get("profile_param","global","max_sip_trunk") or "32")
local MAX_RINGGRP = tonumber(uci:get("profile_param","global","max_ringgroup") or "32")

m = Map("ivr",translate("Call Control / IVR"))

s = m:section(TypedSection,"ivr", translate(""))
m.currsection = s
s.addremove = false
s.anonymous = true

status = s:option(ListValue,"status",translate("Status"))
status:value("Enabled",translate("Enable"))
status:value("Disabled",translate("Disable"))

timeout = s:option(Value,"timeout",translate("Timeout"))
timeout.rmempty = false
timeout.default = 10
timeout.datatype = "range(1,20)"

enable_extension = s:option(Flag,"enable_extension",translate("Enable Direct Extension"))

repeat_loops = s:option(Value,"repeat_loops",translate("Repeat Loops"))
repeat_loops.rmempty = false
repeat_loops.default = 3
repeat_loops.datatype = "range(1,5)"

s = m:section(TypedSection,"menu",translate("Menu"))
s.addremove = true
s.anonymous = true
s.useable = true
s.template = "cbi/ivrmenu"

local extension_tb = {}
local extension_tb_translate = {}
local trunk_tb = {}
local trunk_tb_translate = {}
local ringgroup_tb = {}
local ringgroup_tb_translate = {}

for i=1,MAX_SIP_TRUNK do
	for k,v in pairs(endpoint_siptrunk) do
		if v.index and tonumber(v.index) == i and "Enabled" == v.status and v.index and v.name and v.profile then
			table.insert(trunk_tb,"Trunks,SIPT-"..v.profile.."_"..v.index)
			table.insert(trunk_tb_translate,translate("SIP Trunk").." / "..v.name..((v.register and "on" == v.register) and (" / "..(v.auth_username or v.username or "")) or ""))
			break
		end
		for m,n in pairs(endpoint_fxso) do
			if "fxs" == n['.type'] and n.number_1 and n.slot_type and n.port_1_reg and "on" == n.port_1_reg and (v.index == n.port_1_server_1 or v.index == n.port_1_server_2) then
				table.insert(trunk_tb,"Trunks,SIPT-"..v.profile.."_"..v.index.."-"..n.slot_type.."-1-"..n.number_1)
				table.insert(trunk_tb_translate,translate("SIP Trunk").." / "..v.name.." / (FXS/"..n.number_1..")")
			end
			if "fxo" == n['.type'] and n.number_2 and n.slot_type and n.port_2_reg and "on" == n.port_2_reg and (v.index == n.port_2_server_1 or v.index == n.port_2_server_2) then
				table.insert(trunk_tb,"Trunks,SIPT-"..v.profile.."_"..v.index.."-"..n.slot_type.."-2-"..n.number_2)
				table.insert(trunk_tb_translate,translate("SIP Trunk").." / "..v.name.." / (FXO/"..n.number_2..")")
			end
		end
		for m,n in pairs(endpoint_mobile) do
			if n.number and n.slot_type and (n.slot_type:match("GSM") or n.slot_type:match("VOLTE")) and n.port_reg and "on" == n.port_reg and (v.index == n.port_server_1 or v.index == n.port_server_2) then
				table.insert(trunk_tb,"Trunks,SIPT-"..v.profile.."_"..v.index.."-"..n.slot_type.."-"..n.number)
				if n.slot_type:match("GSM") then
					table.insert(trunk_tb_translate,translate("SIP Trunk").." / "..v.name.." / (GSM/"..n.number..")")
				elseif n.slot_type:match("VOLTE") then
					table.insert(trunk_tb_translate,translate("SIP Trunk").." / "..v.name.." / (VoLTE/"..n.number..")")
				end
			end
		end
	end
end


for k,v in pairs(endpoint_fxso) do
	if v.index then
		if "fxs" == v['.type'] and "Enabled" == v.status and v.number_1 and interface:match("S") then
			table.insert(extension_tb,"Extensions,"..v.number_1)
			table.insert(extension_tb_translate,translate("FXS Extension").." / "..v.number_1)
			if interface:match("2S") and v.number_2 then
				table.insert(extension_tb,"Extensions,"..v.number_2)
				table.insert(extension_tb_translate,translate("FXS Extension").." / "..v.number_2)
			end
		elseif "fxo" == v['.type'] and "Enabled" == v.status and interface:match("O") then
			if interface:match("2O") then
				table.insert(trunk_tb,"Trunks,FXO/"..v.index.."/1")
				table.insert(trunk_tb_translate,translate("FXO Trunk").." / "..translate("Port").." 0")
				table.insert(trunk_tb,"Trunks,FXO/"..v.index.."/2")
				table.insert(trunk_tb_translate,translate("FXO Trunk").." / "..translate("Port").." 1")
			else
				table.insert(trunk_tb,"Trunks,FXO/"..v.index.."/2")
				table.insert(trunk_tb_translate,translate("FXO Trunk"))
			end
		end
	end
end

for i=1,MAX_SIP_EXTENSION do
	for k,v in pairs(endpoint_sipphone) do
		if v.index and tonumber(v.index) == i and "Enabled" == v.status and v.user then
			table.insert(extension_tb,"Extensions,"..v.user)
			table.insert(extension_tb_translate,translate("SIP Extension").." / "..v.name.." / "..v.user)
			break
		end
	end
end
--gsm/volte
for k,v in pairs(endpoint_mobile) do
	if v.slot_type then
		local slot,slot_type = v.slot_type:match("^(%d+)%-(%u+)")
		if v.index and v.name and ("GSM" == slot_type or "VOLTE" == slot_type) and v.status and v.status == "Enabled" then
			table.insert(trunk_tb,"Trunks,gsmopen/"..v.slot_type)
			if "GSM" == slot_type then
				table.insert(trunk_tb_translate,translate("GSM Trunk"))
			elseif "VOLTE" == slot_type then
				table.insert(trunk_tb_translate,translate("VoLTE Trunk"))
			end
		end
	end
end
--cdma

for i=1,MAX_RINGGRP do
	for k,v in pairs(endpoint_ringgroup) do
		if v.index and tonumber(v.index) == i and v.name and v.strategy then
			table.insert(ringgroup_tb,"Ringgroup,"..v.index.."/"..v.strategy)
			table.insert(ringgroup_tb_translate,translate("Ring Group").." / "..v.name)
			break
		end
	end
end

dtmf = s:option(ListValue,"dtmf",translate("DTMF"))
dtmf.style="width:100px;"
for i=0,9 do
	dtmf:value(i,i)
end
dtmf:value("*","*")
dtmf:value("#","#")
dtmf:value("none",translate("Others"))
dtmf:value("timeout",translate("Timeout"))
dtmf.datatype = "ivr_dtmf"

destination = s:option(ListValue,"destination",translate("Destination"))
destination.rmempty = false
for k,v in ipairs(extension_tb) do
	destination:value(v,extension_tb_translate[k])
end
for k,v in ipairs(trunk_tb) do
	destination:value(v,trunk_tb_translate[k])
end
for k,v in ipairs(ringgroup_tb) do
	destination:value(v,ringgroup_tb_translate[k])
end

dst_number = s:option(Value,"dst_number",translate("Destination Number"))
dst_number.datatype = "phonenumber"
for k,v in pairs(trunk_tb) do
	dst_number:depends("destination",v)
end

function dst_number.validate(self, val, section)
	local dest = m:get(section,"destination")
	if dest and (dest:match("^Extensions,") or dest:match("^Ring")) and not val then
		m:del(section,"dst_number")
		return true
	else
		return Value.validate(self, val)
	end
end

function s.create(self,section)
	local sid = TypedSection.create(self, section)
	local menu = uci:get_all("ivr") or {}
	local menu_list = ""
	local dest_list = ""
	local dtmf_tb = {'0','1','2','3','4','5','6','7','8','9',"*","#"}
	local dest_seled = false
	for k,v in pairs(menu) do
		if "menu" == v[".type"] and v.dtmf then
			menu_list = menu_list..v.dtmf..","
			if v.destination then
				dest_list = dest_list..v.destination..","
			end
		end
	end
	if sid then
		for k,v in ipairs(dtmf_tb) do
			if not menu_list:match(v..",") then
				m:set(sid, "dtmf", v)
				break
			end
		end
		for k,v in pairs(extension_tb) do
			if not dest_list:match(v..",") then
				m:set(sid,"destination",v)
				dest_seled = true
				break
			end
		end

		if not dest_seled then
			for k,v in pairs(trunk_tb) do
				if not dest_list:match(v..",") then
					m:set(sid,"destination",v)
					dest_seled = true
					break
				end
			end
		end

		if not dest_seled then
			for k,v in pairs(ringgroup_tb) do
				if not dest_list:match(v..",") then
					m:set(sid,"destination",v)
					dest_seled = true
					break
				end
			end
		end
	end
	return sid
end
return m

