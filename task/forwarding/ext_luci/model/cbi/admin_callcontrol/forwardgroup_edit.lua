local dsp = require "luci.dispatcher"
local uci = require "luci.model.uci".cursor()

arg[1] = arg[1] or ""
arg[2] = arg[2] or ""

uci:check_cfg("endpoint_sipphone")
uci:check_cfg("endpoint_siptrunk")
uci:check_cfg("endpoint_fxso")
uci:check_cfg("endpoint_mobile")
uci:check_cfg("profile_time")

if arg[2] == "edit" then
	m = Map("endpoint_forwardgroup",translate("Call Control / Call Forward Group / Edit"))
else
	m = Map("endpoint_forwardgroup",translate("Call Control / Call Forward Group / New"))
	m.addnew = true
	m.new_section = arg[1]
end

m.redirect = dsp.build_url("admin","callcontrol","forwardgroup")

if not m.uci:get(arg[1]) == "group" then
	luci.http.redirect(m.redirect)
end

s = m:section(NamedSection,arg[1],"group","")
m.currsection = s
s.addremove = false
s.anonymous = true

local this_index = uci:get("endpoint_forwardgroup",arg[1],"index")
local profile = uci:get_all("endpoint_forwardgroup")

if arg[2] == "edit" then
	index = s:option(DummyValue,"index",translate("Index"))
else
	index = s:option(ListValue,"index",translate("Index"))
	for i=1,32 do
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
end

name = s:option(Value,"name",translate("Name"))
name.rmempty = false
name.datatype = "cfgname"

--@ get table of forward dst
local forward_extension_dst = {}
local forward_trunk_dst = {}

if luci.version.license and luci.version.license.fxs then--check fxs license
	for k,v in pairs(uci:get_all("endpoint_fxso") or {}) do
		if "fxs" == v['.type'] and v.index and "Enabled" == v.status then
			if luci.version.license.fxs > 1 then
				table.insert(forward_extension_dst,{index=v.number_1,name=translate("FXS Extension").." / "..v.number_1})
				table.insert(forward_extension_dst,{index=v.number_2,name=translate("FXS Extension").." / "..v.number_2})
			else
				table.insert(forward_extension_dst,{index=v.number_1,name=translate("FXS Extension")})
			end
		end
	end
end

for i=1,32 do
	for k,v in pairs(uci:get_all("endpoint_sipphone") or {}) do
		if v.index and v.name and tonumber(v.index) == i and "Enabled" == v.status and v.user then
			table.insert(forward_extension_dst,{index=v.user,name=translate("SIP Extension").." / "..v.name.." / "..v.user})
			break
		end
	end
end

if luci.version.license and luci.version.license.fxo then--check fxo license
	for k,v in pairs(uci:get_all("endpoint_fxso") or {}) do
		if "fxo" == v['.type'] and v.index and "Enabled" == v.status then
			if luci.version.license.fxo > 1 then
				table.insert(forward_trunk_dst,{index="FXO/"..v.index.."/1",name=translate("FXO Trunk").." / "..translate("Port").." 0"})
				table.insert(forward_trunk_dst,{index="FXO/"..v.index.."/2",name=translate("FXO Trunk").." / "..translate("Port").." 1"})
			else
				table.insert(forward_trunk_dst,{index="FXO/"..v.index.."/2",name=translate("FXO Trunk")})
			end
		end
	end
end

for i=1,12 do
	for k,v in pairs(uci:get_all("endpoint_mobile") or {}) do
		if v.index and tonumber(v.index) == i and "Enabled" == v.status and v.slot_type and v.slot_type:match("GSM$") and v.name then
			table.insert(forward_trunk_dst,{index="gsmopen/"..v.slot_type,name=translate("GSM Trunk")})
			break
		end
	end
end

for i=1,12 do
	for k,v in pairs(uci:get_all("endpoint_mobile")) do
		if v.index and tonumber(v.index) == i and "Enabled" == v.status and v.slot_type and v.slot_type:match("CDMA$") and v.name then
			table.insert(forward_trunk_dst,{index="gsmopen/"..v.slot_type,name=translate("CDMA Trunk")})
			break
		end
	end
end

for i=1,32 do
	for k,v in pairs(uci:get_all("endpoint_siptrunk")) do
		if v.index and tonumber(v.index) == i and "Enabled" == v.status and v.index and v.name and v.profile then
			table.insert(forward_trunk_dst,{index="SIPT-"..v.profile.."_"..v.index,name=translate("SIP Trunk").." / "..v.name})
			break
		end
	end
end

local profile_time = uci:get_all("profile_time") or {}

call_forward_destination = s:option(CallForwarding, "destination", translate("Call Forward Destination / Time Profile"))
call_forward_destination.datatype = "phonenumber"
for k,v in pairs(forward_extension_dst) do
	call_forward_destination:s1_value(v.index, v.name)
end
for k,v in pairs(forward_trunk_dst) do
	call_forward_destination:s1_depvalue(v.index, v.name)
end
call_forward_destination:s2_value("",translate("Alaways"))
for k,v in pairs(profile_time) do
	if v.index and v.name then
		call_forward_destination:s2_value(v.index, v.name)
	end
end
local continue_param = "callcontrol-forwardgroup-"..arg[1].."-"..arg[2]
call_forward_destination:s2_value("addnew_profile_time/"..continue_param, translate("< Add New ...>"))

return m

