--[[

]]--
local dsp = require "luci.dispatcher"
local uci = require "luci.model.uci".cursor()

uci:check_cfg("endpoint_routegroup")
uci:check_cfg("endpoint_ringgroup")
uci:check_cfg("endpoint_siptrunk")
uci:check_cfg("endpoint_sipphone")
uci:check_cfg("endpoint_fxso")
uci:check_cfg("endpoint_mobile")
uci:check_cfg("profile_manipl")
uci:check_cfg("profile_number")
uci:check_cfg("profile_time")
uci:check_cfg("ivr")
uci:check_cfg("route")

local from_sip_trunk_tb = uci:get_all("endpoint_siptrunk") or {}
local from_sip_phone_tb = uci:get_all("endpoint_sipphone") or {}
local from_fxso_tb = uci:get_all("endpoint_fxso") or {}
local from_mobile_tb = uci:get_all("endpoint_mobile") or {}
local from_ring_group_tb = uci:get_all("endpoint_ringgroup") or {}
local from_route_group_tb = uci:get_all("endpoint_routegroup") or {}
local from_ivr_tb = uci:get_all("ivr") or {}
local profile = uci:get_all("route") or {}

local current_user = dsp.context.authuser
local number_access = uci:get("user",current_user.."_web","profile_number")
local time_access = uci:get("user",current_user.."_web","profile_time")
local manipl_access = uci:get("user",current_user.."_web","profile_manipl")

arg[1] = arg[1] or ""
arg[2] = arg[2] or ""
local current_section = arg[1]
if arg[2] == "edit" then
    m = Map("route",translate("Call Control / Route / Edit"))
else
    m = Map("route",translate("Call Control / Route / New"))
    m.addnew = true
    m.new_section = arg[1]
end

m.redirect = dsp.build_url("admin","callcontrol","route")

if not m.uci:get(arg[1]) == "route" then
	luci.http.redirect(m.redirect)
end

s = m:section(NamedSection,arg[1],"route","")
m.currsection = s
s.addremove = false
s.anonymous = true

index = s:option(ListValue,"index",translate("Priority"))
index.rmempty = false
local this_index = uci:get("route",arg[1],"index")
for i=32,1,-1 do
	local flag = true
	for k,v in pairs(profile) do
		if v.index and tonumber(v.index) == i then
			flag = false
			break
		end
	end
	if flag == true or i == tonumber(this_index) then
		index:value(i,i)
	end
end
--
--
name = s:option(Value,"name",translate("Name"))
name.rmempty = false
name.datatype = "cfgname"

s = m:section(NamedSection,arg[1],"route",translate("Condition"))

from = s:option(ListValue,"from",translate("Source"))
--@ from sip
local dest_sip_deps_list = {}

local custom_from = s:option(DynListValue,"custom_from",translate("Custom Source"))
custom_from:depends("from","-1")

for i=1,32 do
	for k,v in pairs(from_sip_trunk_tb) do
		if v.index and v.name and v.status and v.status == "Enabled" then
			if tonumber(v.index) == i then
				from:value("SIPT-"..v.index,translate("SIP Trunk").." / "..v.name)
				custom_from:value("SIPT-"..v.index,translate("SIP Trunk").." / "..v.name)
				break
			end
		else
			uci:delete("endpoint_siptrunk",k)
		end
	end
end
for i=1,32 do
	for k,v in pairs(from_sip_phone_tb) do
		if v.index and v.name and v.user then
			if tonumber(v.index) == i then
				from:value("SIPP-"..v.index,translate("SIP Extension").." / "..v.name.." / "..v.user)
				custom_from:value("SIPP-"..v.index,translate("SIP Extension").." / "..v.name.." / "..v.user)
				table.insert(dest_sip_deps_list,{from=("SIPP-"..v.index)})
				--table.insert(dest_sip_deps_list,{custom_from=("SIPP-"..v.index)})
				break
			end
		else
			uci:delete("endpoint_sipphone",k)
		end
	end
end
--@ from fxs
if luci.version.license and luci.version.license.fxs then--check fxs license
	for k,v in pairs(from_fxso_tb) do
		if v.index and v.slot_type and v.status and v.status == "Enabled" then
			local slot,slot_type = v.slot_type:match("(%d+)-(%u+)")
			if slot and slot_type == "FXS" then
				from:value((slot_type.."-"..v.index.."-1"), translate("FXS Extension"))
				custom_from:value((slot_type.."-"..v.index.."-1"), translate("FXS Extension"))
				table.insert(dest_sip_deps_list,{from=(slot_type.."-"..v.index.."-1")})
				--table.insert(dest_sip_deps_list,{custom_from=(slot_type.."-"..v.index)})
				break
			end
		end
	end
end
--@ from fxo
if luci.version.license and luci.version.license.fxo then--check fxo license
	for k,v in pairs(from_fxso_tb) do
		if v.index and v.slot_type and v.status and v.status == "Enabled" then
			local slot,slot_type = v.slot_type:match("(%d+)-(%u+)")
			if slot and slot_type == "FXO" then
				if luci.version.license.fxo > 1 then
					from:value("FXO-"..v.index.."-1", translate("FXO Trunk").." / "..translate("Port").." 0")
					from:value("FXO-"..v.index.."-2", translate("FXO Trunk").." / "..translate("Port").." 1")
					custom_from:value(("FXO-"..v.index.."-1"), translate("FXO Trunk").." / "..translate("Port").." 0")
					custom_from:value(("FXO-"..v.index.."-2"), translate("FXO Trunk").." / "..translate("Port").." 1")
					table.insert(dest_sip_deps_list,{from=("FXO-"..v.index.."-1")})
					table.insert(dest_sip_deps_list,{from=("FXO-"..v.index.."-2")})
				else
					from:value((slot_type.."-"..v.index.."-2"), translate("FXO Trunk"))
					custom_from:value((slot_type.."-"..v.index.."-2"), translate("FXO Trunk"))
					table.insert(dest_sip_deps_list,{from=(slot_type.."-"..v.index.."-2")})
					--table.insert(dest_sip_deps_list,{custom_from=(slot_type.."-"..v.index)})
				end
				break			
			end
		end
	end
end
--@ from gsm/volte
if luci.version.license and (luci.version.license.gsm or luci.version.license.volte) then--check gsm license
	for k,v in pairs(from_mobile_tb) do
		if v.index and v.slot_type and v.status and v.status == "Enabled" then
			local slot,slot_type = v.slot_type:match("(%d+)-(%u+)")
			if slot and slot_type == "GSM" then
				from:value((slot_type.."-"..v.index), (translate("GSM Trunk")))
				custom_from:value((slot_type.."-"..v.index), (translate("GSM Trunk")))
				table.insert(dest_sip_deps_list,{from=(slot_type.."-"..v.index)})
				--table.insert(dest_sip_deps_list,{custom_from=(slot_type.."-"..v.index)})
				break
			elseif slot and slot_type == "VOLTE" then
				from:value((slot_type.."-"..v.index), (translate("VoLTE Trunk")))
				custom_from:value((slot_type.."-"..v.index), (translate("VoLTE Trunk")))
				table.insert(dest_sip_deps_list,{from=(slot_type.."-"..v.index)})
				--table.insert(dest_sip_deps_list,{custom_from=(slot_type.."-"..v.index)})
				break
			end
		end
	end
end

--@ anywhere
from:value("-1",translate("Custom"))
from:value("0",translate("Any"))
table.insert(dest_sip_deps_list,{from="0"})
table.insert(dest_sip_deps_list,{from="-1"})

number_profile = s:option(ListValue,"numberProfile",translate("Number Profile"))
local numprofile_tb = uci:get_all("profile_number") or {}
number_profile:value("0",translate("Off"))
number_profile.default = "0"
for i=1,32 do
	for k,v in pairs(numprofile_tb) do
		if v.index and v.name then
			if tonumber(v.index) == i then
				number_profile:value(v.index,v.index.."-< "..v.name.." >")
				--break
			end
		else
			uci:delete("profile_number",k)
			uci:save("profile_number")
		end
	end
end

local caller_number_prefix = s:option(Value,"caller_num_prefix",translate("Caller Number Prefix"))
caller_number_prefix.datatype = "regular_simple"
--caller_number_prefix.datatype = [[ or("regular","digitmap") ]]
caller_number_prefix:depends("numberProfile","0")

local called_number_prefix = s:option(Value,"called_num_prefix",translate("Called Number Prefix"))
called_number_prefix.datatype = "regular_simple"
--called_number_prefix.datatype = [[ or("regular","digitmap") ]]
called_number_prefix:depends("numberProfile","0")

local continue_param = "callcontrol-route-"..arg[1].."-"..arg[2]
if arg[3] then
	continue_param = continue_param .. ";" .. arg[3]
end
if "admin" == current_user or (number_access and number_access:match("edit")) then
	number_profile:value("addnew_profile_number/"..continue_param,translate("< Add New ...>"))
end

function number_profile.cfgvalue(...)
	local v = m.uci:get("route",current_section, "numberProfile")
	if v and v:match("^addnew") then
		m.uci:revert("route",current_section, "numberProfile")
		v = m.uci:get("route",current_section, "numberProfile")
	end
	return v
end

time_profile = s:option(ListValue,"timeProfile",translate("Time Profile"))
local timeprofile_tb = uci:get_all("profile_time") or {}
time_profile:value("0",translate("Any"))
time_profile.default = "0"
for i=1,32 do
for k,v in pairs(timeprofile_tb) do
	if v.index and v.name then
		if tonumber(v.index) == i then
			time_profile:value(v.index,v.index.."-< "..v.name.." >")
		end
	else
		uci:delete("profile_time",k)
		uci:save("profile_time")
	end
end
end

function time_profile.cfgvalue(...)
	local v = m.uci:get("route",current_section, "timeProfile")
	if v and v:match("^addnew") then
		m.uci:revert("route",current_section, "timeProfile")
		v = m.uci:get("route",current_section, "timeProfile")
	end
	return v or "0"
end

local continue_param = "callcontrol-route-"..arg[1].."-"..arg[2]
if arg[3] then
	continue_param = continue_param .. ";" .. arg[3]
end
if "admin" == current_user or (time_access and time_access:match("edit")) then
	time_profile:value("addnew_profile_time/"..continue_param,translate("< Add New ...>"))
end

s = m:section(NamedSection,arg[1],"route",translate("Action"))

number_manipulation = s:option(ListValue,"successNumberManipulation",translate("Manipulation"))
local numbermanipulation_tb = uci:get_all("profile_manipl") or {}
number_manipulation:value("0",translate("Off"))
number_manipulation.default = "0"
for i=1,32 do
for k,v in pairs(numbermanipulation_tb) do
	if v.index and v.name then
		if tonumber(v.index) == i then
			number_manipulation:value(v.index,v.index.."-< "..v.name.." >")
		end
	else
		uci:delete("profile_manipl",k)
		uci:save("profile_manipl")
	end
end
end

local continue_param = "callcontrol-route-"..arg[1].."-"..arg[2]
if arg[3] then
	continue_param = continue_param .. ";" .. arg[3]
end

if "admin" == current_user or (manipl_access and manipl_access:match("edit")) then
	number_manipulation:value("addnew_profile_manipl/"..continue_param,translate("< Add New ...>"))
end

function number_manipulation.cfgvalue(...)
	local v = m.uci:get("route",current_section, "successNumberManipulation")
	if v and v:match("^addnew") then
		m.uci:revert("route",current_section, "successNumberManipulation")
		v = m.uci:get("route",current_section, "successNumberManipulation")
	end
	return v or "0"
end

successDestination = s:option(ListValue,"successDestination",translate("Destination"))
successDestination.rmempty = false
--@ to sip
for i=1,32 do
	for k,v in pairs(from_sip_trunk_tb) do
		if v.index and tonumber(v.index) == i and v.name and v.status and v.status == "Enabled" then
			successDestination:value("SIPT-"..v.index,translate("SIP Trunk").." / "..v.name, dest_sip_deps_list)
			break
		end
	end
end
for i=1,32 do
	for k,v in pairs(from_sip_phone_tb) do
		if v.index and tonumber(v.index) == i and v.name and v.user then
			successDestination:value("SIPP-"..v.index,translate("SIP Extension").." / "..v.name.." / "..v.user)
			break
		end
	end
end
--@ to fxs
if luci.version.license and luci.version.license.fxs then--check fxs license
	for k,v in pairs(from_fxso_tb) do
		if v.index and v.slot_type and v.status and v.status == "Enabled" then
			local slot,slot_type = v.slot_type:match("(%d+)-(%u+)")
			if slot and slot_type == "FXS" then
				if luci.version.license.fxs > 1 then
					successDestination:value(("FXS-"..v.index.."-0"), translate("FXS Extension").." / "..v.number_1)
					successDestination:value(("FXS-"..v.index.."-1"), translate("FXS Extension").." / "..v.number_2)
				else
					successDestination:value(("FXS-"..v.index.."-0"), (translate("FXS Extension")))
				end
				break
			end
		end
	end
end
--@ to fxo
if luci.version.license and luci.version.license.fxo then--check fxo license
	for k,v in pairs(from_fxso_tb) do
		if v.index and v.slot_type and v.status and v.status == "Enabled" then
			local slot,slot_type = v.slot_type:match("(%d+)-(%u+)")
			if slot and slot_type == "FXO" then
				if luci.version.license.fxo > 1 then
					successDestination:value(("FXO-"..v.index.."-0"), translate("FXO Trunk").." / "..translate("Port").." 0")
					successDestination:value(("FXO-"..v.index.."-1"), translate("FXO Trunk").." / "..translate("Port").." 1")
				else
					successDestination:value(("FXO-"..v.index.."-1"), (translate("FXO Trunk")))
				end
				break
			end
		end
	end
end
--@ to gsm/volte
if luci.version.license and (luci.version.license.gsm or luci.version.license.volte) then--check gsm/volte license
	for k,v in pairs(from_mobile_tb) do
		if v.index and v.slot_type and v.status and v.status == "Enabled" then
			local slot,slot_type = v.slot_type:match("(%d+)-(%u+)")
			if slot and slot_type == "GSM" then
				successDestination:value((slot_type.."-"..v.index), (translate("GSM Trunk")))
				break
			elseif slot and slot_type == "VOLTE" then
				successDestination:value((slot_type.."-"..v.index), (translate("VoLTE Trunk")))
				break
			end
		end
	end
end
--@ to ring group
for i=1,32 do
	for k,v in pairs(from_ring_group_tb) do
		if v.index and tonumber(v.index) == i and v.name then
			successDestination:value("RING-"..v.index,translate("Ring Group").." / "..v.name)
			break
		end
	end
end
--@ to route group 
for i=1,32 do
	for k,v in pairs(from_route_group_tb) do
		if v.index and tonumber(v.index) == i and v.name then
			successDestination:value("ROUTE-"..v.index,translate("Route Group").." / "..v.name)
			break
		end
	end
end
--@ to IVR
for k,v in pairs(from_ivr_tb) do
	if "ivr" == v['.type'] then
		if v.status == "Enabled" then
			successDestination:value("IVR",translate("IVR"))
		end
		break
	end
end
successDestination:value("Extension-1",translate("Local Extension"))
--@ hangup
successDestination:value("Hangup-1",translate("Hangup"))

failoverflag = s:option(Flag,"failoverflag",translate("Failover Action"))
failoverflag.rmempty = false

failcondition = s:option(MultiValue,"failCondition",translate("Condition"))
failcondition:depends("failoverflag","1")
failcondition.widget = "checkbox"
failcondition.margin = "32px"
local condition_tb = {"Busy","Timeout","Unavailable"}

for k,v in ipairs(condition_tb) do
	failcondition:value(v,translate(v))
end

timeout = s:option(Value,"timeout",translate("Timeout Len(s)"))
timeout:depends("failCondition".."2","Timeout")
timeout.default = "20"
timeout.margin = "32px"
timeout.rmempty = false
timeout.datatype = "max(60)"

function timeout.validate(self, value)
	local tmp_flag =  m.uci:get("route",arg[1],"failCondition")

	if tmp_flag and tmp_flag:match("Timeout") then
		return Value.validate(self,value)
	else
		return value or ""
	end
end

failcausecode = s:option(Value,"causecode",translate("Other Condition Code"))
failcausecode.margin = "32px"
failcausecode:depends("failoverflag","1")

number_change = s:option(ListValue,"failNumberManipulation",translate("Manipulation"))
number_change:depends("failoverflag","1")
number_change.margin = "32px"
number_change:value("0",translate("Off"))
number_change.default = "0"
for i=1,32 do
for _,v in pairs(numbermanipulation_tb) do
	if v.index and v.name and tonumber(v.index) == i then
		number_change:value(v.index,v.index.."-< "..v.name.." >")
	end
end
end

local continue_param = "callcontrol-route-"..arg[1].."-"..arg[2]
if arg[3] then
	continue_param = continue_param .. ";" .. arg[3]
end

if "admin" == current_user or (manipl_access and manipl_access:match("edit")) then
	number_change:value("addnew_profile_manipl/"..continue_param,translate("< Add New ...>"))
end

function number_change.cfgvalue(...)
	local v = m.uci:get("route",current_section, "failNumberManipulation")
	if v and v:match("^addnew") then
		m.uci:revert("route",current_section, "failNumberManipulation")
		v = m.uci:get("route",current_section, "failNumberManipulation")
	end
	return v or "0"
end

failDestination = s:option(ListValue,"failDestination",translate("Destination"))
failDestination:depends("failoverflag","1")
failDestination.margin = "32px"
--@ to sip
for i=1,32 do
	for k,v in pairs(from_sip_trunk_tb) do
		if v.index and tonumber(v.index) == i and v.name and v.status and v.status == "Enabled" then
			failDestination:value("SIPT-"..v.index,translate("SIP Trunk").." / "..v.name,dest_sip_deps_list)
			break
		end
	end
end
for i=1,32 do
	for k,v in pairs(from_sip_phone_tb) do
		if v.index and tonumber(v.index) == i and v.name and v.user then
			failDestination:value("SIPP-"..v.index,translate("SIP Extension").." / "..v.name.." / "..v.user)
			break
		end
	end
end
--@ to fxs
if luci.version.license and luci.version.license.fxs then--check fxo license
	for k,v in pairs(from_fxso_tb) do
		if v.index and v.slot_type and v.status and v.status == "Enabled" then
			local slot,slot_type = v.slot_type:match("(%d+)-(%u+)")
			if slot and slot_type == "FXS" then
				if luci.version.license.fxs > 1 then
					failDestination:value(("FXS-"..v.index.."-0"), translate("FXS Extension").." / "..v.number_1)
					failDestination:value(("FXS-"..v.index.."-1"), translate("FXS Extension").." / "..v.number_2)
				else
					failDestination:value(("FXS-"..v.index.."-0"), (translate("FXS Extension")))
				end
				break
			end
		end
	end
end
--@ to fxo
if luci.version.license and luci.version.license.fxo then--check fxo license
	for k,v in pairs(from_fxso_tb) do
		if v.index and v.slot_type and v.status and v.status == "Enabled" then
			local slot,slot_type = v.slot_type:match("(%d+)-(%u+)")
			if slot and slot_type == "FXO" then
				if luci.version.license.fxo > 1 then
					failDestination:value(("FXO-"..v.index.."-0"), translate("FXO Trunk").." / "..translate("Port").." 0")
					failDestination:value(("FXO-"..v.index.."-1"), translate("FXO Trunk").." / "..translate("Port").." 1")
				else
					failDestination:value(("FXO-"..v.index.."-1"), (translate("FXO Trunk")))
				end
				break
			end
		end
	end
end
--@ to gsm/volte
if luci.version.license and (luci.version.license.gsm or luci.version.license.volte) then--check fxo license
	for k,v in pairs(from_mobile_tb) do
		if v.index and v.slot_type and v.status and v.status == "Enabled" then
			local slot,slot_type = v.slot_type:match("(%d+)-(%u+)")
			if slot and slot_type == "GSM" then
				failDestination:value((slot_type.."-"..v.index), (translate("GSM Trunk")))
				break
			elseif slot and slot_type == "VOLTE" then
				failDestination:value((slot_type.."-"..v.index), (translate("VoLTE Trunk")))
				break
			end
		end
	end
end
--@ to ring group
for i=1,32 do
	for k,v in pairs(from_ring_group_tb) do
		if v.index and tonumber(v.index) == i and v.name then
			failDestination:value("RING-"..v.index,translate("Ring Group").." / "..v.name)
			break
		end
	end
end
--@ to route group 
for i=1,32 do
	for k,v in pairs(from_route_group_tb) do
		if v.index and tonumber(v.index) == i and v.name then
			failDestination:value("ROUTE-"..v.index,translate("Route Group").." / "..v.name)
			break
		end
	end
end
--@ to ivr
for k,v in pairs(from_ivr_tb) do
	if "ivr" == v['.type'] then
		if v.status == "Enabled" then
			failDestination:value("IVR",translate("IVR"))	
		end
		break
	end
end

--[[
s = m:section(NamedSection,arg[1],"route",translate("Tone"))

progress_tone = s:option(ListValue,"progressTone",translate("Callfail Tone"))
local progress_tone_tb = {"Default_cn","Default_hk","Default_us"}
for k,v in pairs(progress_tone_tb) do
	progress_tone:value(k,v)
end

callfail_tone = s:option(ListValue,"callfailTone",translate("Progress Tone"))
local callfail_tone_tb = {"Default","Userbusy_en","Depend on cause code"}
for k,v in pairs(callfail_tone_tb) do
	callfail_tone:value(k,v)
end
]]--

return m

