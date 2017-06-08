--[[

]]--
local dsp = require "luci.dispatcher"
local uci = require "luci.model.uci".cursor()

arg[1] = arg[1] or ""
arg[2] = arg[2] or ""

uci:check_cfg("endpoint_mobile")
uci:check_cfg("endpoint_fxso")
uci:check_cfg("endpoint_sipphone")
uci:check_cfg("endpoint_siptrunk")
uci:check_cfg("endpoint_routegroup")

if arg[2] == "edit" then
    m = Map("endpoint_routegroup",translate("Call Control / Route Group / Edit"))
else
    m = Map("endpoint_routegroup",translate("Call Control / Route Group / New"))
    m.addnew = true
    m.new_section = arg[1]
end

m.redirect = dsp.build_url("admin","callcontrol","routegroup")

if not m.uci:get(arg[1]) == "group" then
	luci.http.redirect(m.redirect)
end

s = m:section(NamedSection,arg[1],"group","")
s.addremove = false
s.anonymous = true

if arg[2] == "edit" then
	index = s:option(DummyValue,"index",translate("Index"))
else
	index = s:option(ListValue,"index",translate("Index"))
	index.rmempty = false
	local profile = uci:get_all("endpoint_routegroup") or {}
	for i=1,32 do
		local flag = true
		for k,v in pairs(profile) do
			if v.index and tonumber(v.index) == i then
				flag = false
				break
			end
		end
		if flag == true then
			index:value(i,i)
		end
	end
end

name = s:option(Value,"name",translate("Name"))
name.rmempty = false
name.datatype = "cfgname"

local endpoint_siptrunk = uci:get_all("endpoint_siptrunk") or {}
local endpoint_sipphone = uci:get_all("endpoint_sipphone") or {}
local endpoint_fxso = uci:get_all("endpoint_fxso") or {}
local endpoint_mobile = uci:get_all("endpoint_mobile") or {}

members_select = s:option(DynListValue,"members_select",translate("Members Select"))
members_select.rmempty = false
local members_tb = {}
local members_tb_display_name = {}
--@ sip trunk
for i=1,32 do
	for k,v in pairs(endpoint_siptrunk) do
		if v.index and tonumber(v.index) == i and v.name and v.status and v.status == "Enabled" then
			table.insert(members_tb,"SIPT-"..v.index)
			table.insert(members_tb_display_name,translate("SIP Trunk").." / "..v.name)
		end
	end
end
--@ sip extension
for i=1,32 do
	for k,v in pairs(endpoint_sipphone) do
		if v.index and tonumber(v.index) == i and v.name and v.status and v.status == "Enabled" then
			table.insert(members_tb,"SIPP-"..v.index)
			table.insert(members_tb_display_name,translate("SIP Extension").." / "..v.name.." / "..v.user)
		end
	end
end
--fxs
if luci.version.license and luci.version.license.fxs then--check fxs license
	for k,v in pairs(endpoint_fxso) do
		if v.slot_type then
			local slot,slot_type = v.slot_type:match("^(%d+)%-(%u+)")
			if v.index and slot and "FXS" == slot_type and v.number_1 and v.status == "Enabled" then
				if luci.version.license.fxs > 1 then
					table.insert(members_tb,"FXS-"..v.index.."/0")--@ -0
					table.insert(members_tb,"FXS-"..v.index.."/1")--@ -1
					table.insert(members_tb_display_name,translate("FXS Extension").." / "..v.number_1)
					table.insert(members_tb_display_name,translate("FXS Extension").." / "..v.number_2)
				else
					table.insert(members_tb,"FXS-"..v.index.."/0")--@ -0
					table.insert(members_tb_display_name,translate("FXS Extension"))
				end
			end
		end
	end
end
--fxo
if luci.version.license and luci.version.license.fxo then--check fxo license
	for k,v in pairs(endpoint_fxso) do
		if v.slot_type then
			local slot,slot_type = v.slot_type:match("^(%d+)%-(%u+)")
			if v.index and slot and "FXO" == slot_type and v.status and v.status == "Enabled" then
				if luci.version.license.fxo > 1 then
					table.insert(members_tb,"FXO-"..v.index.."/0")
					table.insert(members_tb_display_name,translate("FXO Trunk").." / "..translate("Port").." 0")
					table.insert(members_tb,"FXO-"..v.index.."/1")
					table.insert(members_tb_display_name,translate("FXO Trunk").." / "..translate("Port").." 1")
				else
					table.insert(members_tb,"FXO-"..v.index.."/1")--@ -1
					table.insert(members_tb_display_name,translate("FXO Trunk"))
				end
			end
		end
	end
end
--gsm/volte
if luci.version.license and (luci.version.license.gsm or luci.version.license.volte) then--check gsm/volte license
	for k,v in pairs(endpoint_mobile) do
		if v.slot_type then
			local slot,slot_type = v.slot_type:match("^(%d+)%-(%u+)")
			if v.index and "GSM" == slot_type and v.status and v.status == "Enabled" then
				table.insert(members_tb,"GSM-"..v.index)
				table.insert(members_tb_display_name,translate("GSM Trunk"))
			elseif v.index and "VOLTE" == slot_type and v.status and v.status == "Enabled" then
				table.insert(members_tb,"VOLTE-"..v.index)
				table.insert(members_tb_display_name,translate("VoLTE Trunk"))
			end
		end
	end
end

for k,v in ipairs(members_tb) do
	members_select:value(v,members_tb_display_name[k])
end

--strategy
strategy = s:option(ListValue,"strategy",translate("Strategy"))
local strategy_tb = {"sequence","loop_sequence","random"}
for _,v in pairs(strategy_tb) do
	strategy:value(v,translate(v))
end

--time = s:option(Value,"ringtime",translate("Ring Time(5s~60s)"))
--time.rmempty = false
--time.datatype = "range(5,60)"
--time.default = "25"

return m
