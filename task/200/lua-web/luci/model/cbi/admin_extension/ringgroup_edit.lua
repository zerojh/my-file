--[[

]]--
local dsp = require "luci.dispatcher"
local uci = require "luci.model.uci".cursor()

arg[1] = arg[1] or ""
arg[2] = arg[2] or ""

uci:check_cfg("endpoint_fxso")
uci:check_cfg("endpoint_sipphone")
uci:check_cfg("endpoint_ringgroup")
uci:check_cfg("endpoint_mobile")
uci:check_cfg("feature_code")

local this_index = uci:get("endpoint_ringgroup",arg[1],"index")
local endpoint_ringgroup = uci:get_all("endpoint_ringgroup") or {}
local endpoint_fxso = uci:get_all("endpoint_fxso") or {}
local endpoint_sipphone = uci:get_all("endpoint_sipphone") or {}
local endpoint_mobile = uci:get_all("endpoint_mobile") or {}
local feature_code = uci:get_all("feature_code") or {}
local MAX_RINGGRP = tonumber(uci:get("profile_param","global","max_ringgroup") or '32')
local MAX_SIP_EXTENSION = tonumber(uci:get("profile_param","global","max_sip_extension") or '256')

if arg[2] == "edit" then
	m = Map("endpoint_ringgroup",translate("Extension / Ring Group / Edit"))
else
	m = Map("endpoint_ringgroup",translate("Extension / Ring Group / New"))
	m.addnew = true
	m.new_section = arg[1]
end

m.redirect = dsp.build_url("admin","extension","ringgroup")

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
	for i=1,MAX_RINGGRP do
		local flag = true
		for k,v in pairs(endpoint_ringgroup) do
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

members_select = s:option(DynListValue,"members_select",translate("Members Select"))
members_select.rmempty = false
local members_alias_tb = {}
local members_value_tb = {}
--fxs
for k,v in pairs(endpoint_fxso) do
	local slot,slot_type = v.slot_type:match("^(%d+)%-(%u+)")
	if v.index and slot and "FXS" == slot_type and v.number_1 and v.status == "Enabled" then
		table.insert(members_alias_tb,translate("FXS Extension"))
		table.insert(members_value_tb,"FXS-"..v.index.."/0")
	end
end
for i=1,MAX_SIP_EXTENSION do
	for k,v in pairs(endpoint_sipphone) do
		if v.index and tonumber(v.index) == i and v.name and v.user and v.status == "Enabled" then
			table.insert(members_alias_tb,translate("SIP Extension").." / "..v.name.." / "..v.user)
			table.insert(members_value_tb,"SIPP-"..v.index)

		end
	end
end
for k,v in ipairs(members_alias_tb) do
	local is_exsit = false
	
	for k2,v2 in pairs(endpoint_ringgroup) do
		if v2.members_select and k2 ~= arg[1] then
			for k3,v3 in pairs(v2.members_select) do
				if v3 == members_value_tb[k] then
					is_exsit = true
					break
				end
			end
		end
	end
	
	if not is_exsit then
		members_select:value(members_value_tb[k],v)
	end
end

--strategy
strategy = s:option(ListValue,"strategy",translate("Strategy"))
local strategy_tb = {"sequence","loop_sequence","simultaneous","random"}
for _,v in ipairs(strategy_tb) do
	strategy:value(v,translate(v))
end

local exist_extension = ""
local exist_did = ""
--# sip_extension
for k,v in pairs(endpoint_sipphone) do
	if v.user then
		exist_extension = exist_extension..v.user.."&"
	end
	if v.did then
		if "table" == type(v.did) then
			for i,j in pairs(v.did) do
				exist_did = exist_did..j.."&"
			end
		else
			exist_did = exist_did..v.did.."&"
		end
	end
end
--# fxs /fxo
for k,v in pairs(endpoint_fxso) do
	if v.number_1 then
		exist_extension = exist_extension..v.number_1.."&"
	end
	if v.number_2 then
		exist_extension = exist_extension..v.number_2.."&"
	end
	if v.did_1 then
		if "table" == type(v.did_1) then
			for i,j in pairs(v.did_1) do
				exist_did = exist_did..j.."&"
			end
		else
			exist_did = exist_did..v.did_1.."&"
		end
	end
	if v.did_2 then
		if "table" == type(v.did_2) then
			for i,j in pairs(v.did_2) do
				exist_did = exist_did..j.."&"
			end
		else
			exist_did = exist_did..v.did_2.."&"
		end
	end
end
--# gsm / cdma / volte
if luci.version.license and (luci.version.license.gsm or luci.version.license.volte) then
	for k,v in pairs(endpoint_mobile) do
		if v.number then
			exist_extension = exist_extension..v.number.."&"
		end
	end
end
--# ringgroup 
for k,v in pairs(endpoint_ringgroup) do
	if v.number and v.index ~= this_index then
		exist_extension = exist_extension..v.number.."&"
	end
	if v.did and v.index ~= this_index then
		if "table" == type(v.did) then
			for i,j in pairs(v.did) do
				exist_did = exist_did..j.."&"
			end
		else
			exist_did = exist_did..v.did.."&"
		end
	end
end

for k,v in pairs(feature_code) do
	exist_did=exist_did..v.code.."&"..v.code.."#&"
end

number = s:option(Value,"number",translate("Ring Group Number"))
number.datatype = "extension("..exist_extension..")"

did = s:option(Value,"did",translate("DID"))
did.datatype = "did("..exist_did..")"

time = s:option(Value,"ringtime",translate("Ring Time(5s~200s)"))
time.rmempty = false
time.datatype = "range(5,200)"
time.default = "25"
			
return m
