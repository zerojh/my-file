local dsp = require "luci.dispatcher"
local uci = require "luci.model.uci".cursor()

arg[1] = arg[1] or ""
arg[2] = arg[2] or ""

uci:check_cfg("profile_sip")
uci:check_cfg("endpoint_sipphone")
uci:check_cfg("endpoint_siptrunk")
uci:check_cfg("endpoint_fxso")
uci:check_cfg("endpoint_mobile")
uci:check_cfg("profile_time")

local current_section = arg[1]

if arg[2] == "edit" then
    m = Map("endpoint_sipphone",translate("Extension / SIP / Edit"))
else
    m = Map("endpoint_sipphone",translate("Extension / SIP / New"))
    m.addnew = true
    m.new_section = arg[1]
end

m.redirect = dsp.build_url("admin","extension","sip")

if not m.uci:get(arg[1]) == "sip" then
	luci.http.redirect(m.redirect)
end

s = m:section(NamedSection,arg[1],"sip","")
m.currsection = s
s.addremove = false
s.anonymous = true

local this_index = uci:get("endpoint_sipphone",arg[1],"index")
local profile = uci:get_all("endpoint_sipphone")

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

--#uniqueness 
user = s:option(Value,"user",translate("Extension"))
user.rmempty = false
local str = ""
--# sip_extension
for k,v in pairs(profile) do
    if  v.index ~= this_index and v.user then
    	str = str..v.user.."&"
    end
end
--# fxs /fxo
local fxso_profile = uci:get_all("endpoint_fxso") or {}
for k,v in pairs(fxso_profile) do
	if v.number_1 then
		str = str..v.number_1.."&"
	end
	if v.number_2 then
		str = str..v.number_2.."&"
	end
end
--# gsm / cdma
local mobile_profile = uci:get_all("endpoint_mobile") or {}
for k,v in pairs(mobile_profile) do
	if v.number then
		str = str..v.number.."&"
	end
end
--# ringgroup 
local ringgroup_profile = uci:get_all("endpoint_ringgroup") or {}
for k,v in pairs(ringgroup_profile) do
	if v.number then
		str = str..v.number.."&"
	end
end

str = "extension("..str..")"
user.datatype = str

pw = s:option(Value,"password",translate("Password"))
pw.password = true

did = s:option(Value,"did",translate("DID"))
did.datatype = "phonenumber"

from = s:option(ListValue,"from",translate("Register Source"))
from:value("any",translate("Any"))
from:value("specified",translate("Specified"))

ip = s:option(Value,"ip",translate("Register Source Filter"))
ip.datatype = "cidr"
ip.rmempty = false
ip:depends("from","specified")
ip.margin = "32px"

function ip.validate(self, value)
	if "specified" == m:get(arg[1],"from") then
		return AbstractValue.validate(self, value)
	else
		return ""
	end
end

--@ Extension service settings
call_waiting = s:option(ListValue,"waiting",translate("Call Waiting"))
call_waiting.default = "Deactivate"
call_waiting:value("Deactivate",translate("Off"))
call_waiting:value("Activate",translate("On"))

call_notdisturb = s:option(ListValue,"notdisturb",translate("Do Not Disturb"))
call_notdisturb.default = "Deactivate"
call_notdisturb:value("Deactivate",translate("Off"))
call_notdisturb:value("Activate",translate("On"))

--@ get table of forward dst
local forward_extension_dst = {}
local forward_trunk_dst = {}

if luci.version.license and luci.version.license.fxs then--check fxs license
	for k,v in pairs(uci:get_all("endpoint_fxso")) do
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
	for k,v in pairs(uci:get_all("endpoint_sipphone")) do
		if v.index and v.name and tonumber(v.index) == i and "Enabled" == v.status and v.user then
			table.insert(forward_extension_dst,{index=v.user,name=translate("SIP Extension").." / "..v.name.." / "..v.user})
			break
		end
	end
end

if luci.version.license and luci.version.license.fxo then--check fxo license
	for k,v in pairs(uci:get_all("endpoint_fxso")) do
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
	for k,v in pairs(uci:get_all("endpoint_mobile")) do
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
--@ Forward uncondition
call_forward_uncondition = s:option(ListValue,"forward_uncondition",translate("Call Forward Unconditional"))
call_forward_uncondition.default = "Deactivate"
call_forward_uncondition:value("Deactivate",translate("Off"))
for k,v in pairs(forward_extension_dst) do
	call_forward_uncondition:value(v.index,v.name)
end
for k,v in pairs(forward_trunk_dst) do
	call_forward_uncondition:value(v.index,v.name)
end
if #forward_trunk_dst > 0 then
	local forward_dst_uncondition = s:option(Value,"forward_uncondition_dst",translate("Dest Number"))
	forward_dst_uncondition.margin = "30px"
	forward_dst_uncondition.datatype = "phonenumber"
	forward_dst_uncondition.rmempty = "false"
	for k,v in pairs(forward_trunk_dst) do
		forward_dst_uncondition:depends("forward_uncondition",v.index)
	end

	function forward_dst_uncondition.validate(self, value)
		local tmp = string.sub((m:get(arg[1],"forward_uncondition") or ""),1,3)
		if  tmp == "FXO" or tmp == "SIP" or tmp == "gsm" then
			return Value.validate(self, value)
		else 
			m:del(arg[1],"forward_uncondition_dst")
			return value or ""
		end
	end
end
--@ Unregister uncondition
call_forward_unregister = s:option(ListValue,"forward_unregister",translate("Call Forward Unregister"))
call_forward_unregister:depends({waiting="Deactivate",forward_uncondition="Deactivate"})
call_forward_unregister.default = "Deactivate"
call_forward_unregister:value("Deactivate",translate("Off"))
for k,v in pairs(forward_extension_dst) do
	call_forward_unregister:value(v.index,v.name)
end
for k,v in pairs(forward_trunk_dst) do
	call_forward_unregister:value(v.index,v.name)
end
if #forward_trunk_dst > 0 then
	local forward_dst_unregister = s:option(Value,"forward_unregister_dst",translate("Dest Number"))
	forward_dst_unregister.margin = "30px"
	forward_dst_unregister.datatype = "phonenumber"
	forward_dst_unregister.rmempty = "false"
	for k,v in pairs(forward_trunk_dst) do
		forward_dst_unregister:depends("forward_unregister",v.index)
	end

	function forward_dst_unregister.validate(self, value)
		local tmp = string.sub((m:get(arg[1],"forward_unregister") or ""),1,3)
		if  tmp == "FXO" or tmp == "SIP" or tmp == "gsm" then
			return Value.validate(self, value)
		else 
			m:del(arg[1],"forward_unregister_dst")
			return value or ""
		end
	end
end
--@ Forward busy
call_forward_busy = s:option(ListValue,"forward_busy",translate("Call Forward Busy"))
call_forward_busy:depends({waiting="Deactivate",forward_uncondition="Deactivate"})
call_forward_busy.default = "Deactivate"
call_forward_busy:value("Deactivate",translate("Off"))
for k,v in pairs(forward_extension_dst) do
	call_forward_busy:value(v.index,v.name)
end
for k,v in pairs(forward_trunk_dst) do
	call_forward_busy:value(v.index,v.name)
end

if #forward_trunk_dst > 0 then
	local forward_dst_busy = s:option(Value,"forward_busy_dst",translate("Dest Number"))
	forward_dst_busy.margin = "30px"
	forward_dst_busy.datatype = "phonenumber"
	forward_dst_busy.rmempty = "false"
	for k,v in pairs(forward_trunk_dst) do
		forward_dst_busy:depends("forward_busy",v.index)
	end

	function forward_dst_busy.validate(self, value)
		local tmp = string.sub((m:get(arg[1],"forward_busy") or ""),1,3)
		if  tmp == "FXO" or tmp == "SIP" or tmp == "gsm" then
			return Value.validate(self, value)
		else 
			m:del(arg[1],"forward_busy_dst")
			return value or ""
		end
	end
end
--@ Forward noreply
call_forward_noreply = s:option(ListValue,"forward_noreply",translate("Call Forward No Reply"))
call_forward_noreply:depends("forward_uncondition","Deactivate")
call_forward_noreply.default = "Deactivate"
call_forward_noreply:value("Deactivate",translate("Off"))
for k,v in pairs(forward_extension_dst) do
	call_forward_noreply:value(v.index,v.name)
end
for k,v in pairs(forward_trunk_dst) do
	call_forward_noreply:value(v.index,v.name)
end

if #forward_trunk_dst > 0 then
	local forward_dst_noreply = s:option(Value,"forward_noreply_dst",translate("Dest Number"))
	forward_dst_noreply.margin = "30px"
	forward_dst_noreply.datatype = "phonenumber"
	forward_dst_noreply.rmempty = "false"
	for k,v in pairs(forward_trunk_dst) do
		forward_dst_noreply:depends("forward_noreply",v.index)
	end

	function forward_dst_noreply.validate(self, value)
		local tmp = string.sub((m:get(arg[1],"forward_noreply") or ""),1,3)
		if  tmp == "FXO" or tmp == "SIP" or tmp == "gsm" then
			return Value.validate(self, value)
		else 
			m:del(arg[1],"forward_noreply_dst")
			return value or ""
		end
	end	
end

local forward_noreply_timeout = s:option(Value,"forward_noreply_timeout",translate("Call Timeout(s)"))
forward_noreply_timeout.default = "20"
forward_noreply_timeout.margin = "30px"
forward_noreply_timeout.datatype = "range(1,3600)"
forward_noreply_timeout.rmempty = "false"
for k,v in pairs(forward_extension_dst) do
	forward_noreply_timeout:depends("forward_noreply",v.index)
end
for k,v in pairs(forward_trunk_dst) do
	forward_noreply_timeout:depends("forward_noreply",v.index)
end

function forward_noreply_timeout.validate(self, value)
	local tmp = m:get(arg[1],"forward_noreply")
	if tmp == "Deactivate" then
		m:del(arg[1],"forward_noreply_timeout")
		return value or ""	
	else 
		return Value.validate(self, value)
	end
end	

nat = s:option(ListValue,"nat",translate("NAT"))
nat.rmempty = false
nat:value("on",translate("On"))
nat:value("off",translate("Off"))
nat.default="off"

in_filter = s:option(ListValue,"callin_filter",translate("Call In Filter"))
in_filter:value("off",translate("Off"))
in_filter:value("blacklist",translate("Black List"))
in_filter:value("whitelist",translate("White List"))

in_filter_blacklist = s:option(ListValue,"callin_filter_blacklist",translate("Call In Black List"))
in_filter_blacklist:depends("callin_filter","blacklist")
in_filter_blacklist.margin = "32px"
local numprofile_tb = uci:get_all("profile_number")
for i=1,32 do
	for k,v in pairs(numprofile_tb) do
		if v.index and v.name then
			if tonumber(v.index) == i then
				in_filter_blacklist:value(v.index,v.index.."-< "..v.name.." >")
			end
		else
			uci:delete("profile_number",k)
			uci:save("profile_number")
		end
	end
end
local continue_param = "extension-sip-"..arg[1].."-"..arg[2]
if arg[3] then
	continue_param = continue_param .. ";" .. arg[3]
end
in_filter_blacklist:value("addnew_profile_number/"..continue_param,translate("< Add New ...>"))
function in_filter_blacklist.cfgvalue(...)
	local v = m.uci:get("endpoint_sipphone",current_section, "callin_filter_blacklist")
	if v and v:match("^addnew") then
		m.uci:revert("endpoint_sipphone",current_section, "callin_filter_blacklist")
		v = m.uci:get("endpoint_sipphone",current_section, "callin_filter_blacklist")
	end
	return v
end

in_filter_whitelist = s:option(ListValue,"callin_filter_whitelist",translate("Call In White List"))
in_filter_whitelist:depends("callin_filter","whitelist")
in_filter_whitelist.margin = "32px"
local numprofile_tb = uci:get_all("profile_number")
for i=1,32 do
	for k,v in pairs(numprofile_tb) do
		if v.index and v.name then
			if tonumber(v.index) == i then
				in_filter_whitelist:value(v.index,v.index.."-< "..v.name.." >")
			end
		else
			uci:delete("profile_number",k)
			uci:save("profile_number")
		end
	end
end
local continue_param = "extension-sip-"..arg[1].."-"..arg[2]
if arg[3] then
	continue_param = continue_param .. ";" .. arg[3]
end
in_filter_whitelist:value("addnew_profile_number/"..continue_param,translate("< Add New ...>"))

function in_filter_whitelist.cfgvalue(...)
	local v = m.uci:get("endpoint_sipphone",current_section, "callin_filter_whitelist")
	if v and v:match("^addnew") then
		m.uci:revert("endpoint_sipphone",current_section, "callin_filter_whitelist")
		v = m.uci:get("endpoint_sipphone",current_section, "callin_filter_whitelist")
	end
	return v
end

out_filter = s:option(ListValue,"callout_filter",translate("Call Out Filter"))
out_filter:value("off",translate("Off"))
out_filter:value("blacklist",translate("Black List"))
out_filter:value("whitelist",translate("White List"))

out_filter_blacklist = s:option(ListValue,"callout_filter_blacklist",translate("Call Out Black List"))
out_filter_blacklist:depends("callout_filter","blacklist")
out_filter_blacklist.margin = "32px"
local numprofile_tb = uci:get_all("profile_number")
for i=1,32 do
	for k,v in pairs(numprofile_tb) do
		if v.index and v.name then
			if tonumber(v.index) == i then
				out_filter_blacklist:value(v.index,v.index.."-< "..v.name.." >")
			end
		else
			uci:delete("profile_number",k)
			uci:save("profile_number")
		end
	end
end
local continue_param = "extension-sip-"..arg[1].."-"..arg[2]
if arg[3] then
	continue_param = continue_param .. ";" .. arg[3]
end
out_filter_blacklist:value("addnew_profile_number/"..continue_param,translate("< Add New ...>"))
function out_filter_blacklist.cfgvalue(...)
	local v = m.uci:get("endpoint_sipphone",current_section, "callout_filter_blacklist")
	if v and v:match("^addnew") then
		m.uci:revert("endpoint_sipphone",current_section, "callout_filter_blacklist")
		v = m.uci:get("endpoint_sipphone",current_section, "callout_filter_blacklist")
	end
	return v
end

out_filter_whitelist = s:option(ListValue,"callout_filter_whitelist",translate("Call Out White List"))
out_filter_whitelist:depends("callout_filter","whitelist")
out_filter_whitelist.margin = "32px"
local numprofile_tb = uci:get_all("profile_number")
for i=1,32 do
	for k,v in pairs(numprofile_tb) do
		if v.index and v.name then
			if tonumber(v.index) == i then
				out_filter_whitelist:value(v.index,v.index.."-< "..v.name.." >")
			end
		else
			uci:delete("profile_number",k)
			uci:save("profile_number")
		end
	end
end
local continue_param = "extension-sip-"..arg[1].."-"..arg[2]
if arg[3] then
	continue_param = continue_param .. ";" .. arg[3]
end
out_filter_whitelist:value("addnew_profile_number/"..continue_param,translate("< Add New ...>"))
function out_filter_whitelist.cfgvalue(...)
	local v = m.uci:get("endpoint_sipphone",current_section, "callout_filter_whitelist")
	if v and v:match("^addnew") then
		m.uci:revert("endpoint_sipphone",current_section, "callout_filter_whitelist")
		v = m.uci:get("endpoint_sipphone",current_section, "callout_filter_whitelist")
	end
	return v
end

pf = s:option(ListValue,"profile",translate("SIP Profile"))
pf.rmempty = false
local profile_tb = uci:get_all("profile_sip")
for i=1,32 do
	for k,v in pairs(profile_tb) do
		if v.index and v.name then
			if tonumber(v.index) == i then
				pf:value(v.index,v.index.."-< "..v.name.." >")
				break
			end
		else
			uci:delete("profile_sip",k)
			uci:save("profile_sip")
		end
	end
end
local continue_param = "extension-sip-"..arg[1].."-"..arg[2]
if arg[3] then
	continue_param = continue_param .. ";" .. arg[3]
end
pf:value("addnew_profile_sip/"..continue_param,translate("< Add New ...>"))
function pf.cfgvalue(...)
	local v = m.uci:get("endpoint_sipphone",current_section, "profile")
	if v and v:match("^addnew") then
		m.uci:revert("endpoint_sipphone",current_section, "profile")
		v = m.uci:get("endpoint_sipphone",current_section, "profile")
	end
	return v
end

status = s:option(ListValue,"status",translate("Status"))
status.rmempty = false
status:value("Enabled",translate("Enable"))
status:value("Disabled",translate("Disable"))

local profile_time = uci:get_all("profile_time") or {}

--@ test followme group
test_followme = s:option(CallForwarding, "test_followme", translate("Followme Group"))
test_followme.datatype = "phonenumber"
for k,v in pairs(forward_extension_dst) do
	test_followme:s1_value(v.index, v.name)
end
for k,v in pairs(forward_trunk_dst) do
	test_followme:s1_depvalue(v.index, v.name)
end
test_followme:s2_value("",translate("Alaways"))
for k,v in pairs(profile_time) do
	if v.index and v.name then
		test_followme:s2_value(v.index, v.name)
	end
end
local continue_param = "extension-sip-"..arg[1].."-"..arg[2]
test_followme:s2_value("addnew_profile_time/"..continue_param, translate("< Add New ...>"))

-- @ test uncondition
test_uncondition_select = s:option(ListValue,"test_uncondition_select", translate("Uncondition Select"))
test_uncondition_select.default = "Deactivate"
test_uncondition_select:value("Deactivate",translate("Off"))
test_uncondition_select:value("Followme",translate("Followme"))
test_uncondition_select:value("Custom", translate("Custom"))

test_uncondition = s:option(CallForwarding, "test_uncondition", translate("Call Forward Unconditional").." / "..translate("Time Profile"))
test_uncondition:depends("test_uncondition_select","Custom")
test_uncondition.datatype = "phonenumber"
for k,v in pairs(forward_extension_dst) do
	test_uncondition:s1_value(v.index, v.name)
end
for k,v in pairs(forward_trunk_dst) do
	test_uncondition:s1_depvalue(v.index, v.name)
end
test_uncondition:s2_value("",translate("Alaways"))
for k,v in pairs(profile_time) do
	if v.index and v.name then
		test_uncondition:s2_value(v.index, v.name)
	end
end
local continue_param = "extension-sip-"..arg[1].."-"..arg[2]
test_uncondition:s2_value("addnew_profile_time/"..continue_param, translate("< Add New ...>"))
-- @ end

-- @ test unregister
test_unregister_select = s:option(ListValue,"test_unregister_select", translate("Unregister Select"))
test_unregister_select.default = "Deactivate"
test_unregister_select:depends({waiting="Deactivate",test_uncondition_select="Deactivate"})
test_unregister_select:value("Deactivate",translate("Off"))
test_unregister_select:value("Followme",translate("Followme"))
test_unregister_select:value("Custom", translate("Custom"))

test_unregister = s:option(CallForwarding, "test_unregister", translate("Call Forward Unregister").." / "..translate("Time Profile"))
test_unregister:depends("test_unregister_select","Custom")
test_unregister.datatype = "phonenumber"
for k,v in pairs(forward_extension_dst) do
	test_unregister:s1_value(v.index, v.name)
end
for k,v in pairs(forward_trunk_dst) do
	test_unregister:s1_depvalue(v.index, v.name)
end
test_unregister:s2_value("",translate("Alaways"))
for k,v in pairs(profile_time) do
	if v.index and v.name then
		test_unregister:s2_value(v.index, v.name)
	end
end
local continue_param = "extension-sip-"..arg[1].."-"..arg[2]
test_unregister:s2_value("addnew_profile_time/"..continue_param, translate("< Add New ...>"))
-- @ end

-- @ test userbusy
test_userbusy_select = s:option(ListValue,"test_userbusy_select", translate("Busy Select"))
test_userbusy_select.default = "Deactivate"
test_userbusy_select:depends({waiting="Deactivate",test_uncondition_select="Deactivate"})
test_userbusy_select:value("Deactivate",translate("Off"))
test_userbusy_select:value("Followme",translate("Followme"))
test_userbusy_select:value("Custom", translate("Custom"))

test_userbusy = s:option(CallForwarding, "test_userbusy", translate("Call Forward Busy").." / "..translate("Time Profile"))
test_userbusy:depends("test_userbusy_select","Custom")
test_userbusy.datatype = "phonenumber"
for k,v in pairs(forward_extension_dst) do
	test_userbusy:s1_value(v.index, v.name)
end
for k,v in pairs(forward_trunk_dst) do
	test_userbusy:s1_depvalue(v.index, v.name)
end
test_userbusy:s2_value("",translate("Alaways"))
for k,v in pairs(profile_time) do
	if v.index and v.name then
		test_userbusy:s2_value(v.index, v.name)
	end
end
local continue_param = "extension-sip-"..arg[1].."-"..arg[2]
test_userbusy:s2_value("addnew_profile_time/"..continue_param, translate("< Add New ...>"))
-- @ end

-- @ test noreply
test_noreply_select = s:option(ListValue,"test_noreply_select", translate("No reply Select"))
test_noreply_select.default = "Deactivate"
test_noreply_select:depends("test_uncondition_select","Deactivate")
test_noreply_select:value("Deactivate",translate("Off"))
test_noreply_select:value("Followme",translate("Followme"))
test_noreply_select:value("Custom", translate("Custom"))

test_noreply = s:option(CallForwarding, "test_noreply", translate("Call Forward No Reply").." / "..translate("Time Profile"))
test_noreply:depends("test_noreply_select","Custom")
test_noreply.datatype = "phonenumber"
for k,v in pairs(forward_extension_dst) do
	test_noreply:s1_value(v.index, v.name)
end
for k,v in pairs(forward_trunk_dst) do
	test_noreply:s1_depvalue(v.index, v.name)
end
test_noreply:s2_value("",translate("Alaways"))
for k,v in pairs(profile_time) do
	if v.index and v.name then
		test_noreply:s2_value(v.index, v.name)
	end
end
local continue_param = "extension-sip-"..arg[1].."-"..arg[2]
test_noreply:s2_value("addnew_profile_time/"..continue_param, translate("< Add New ...>"))
-- @ end

-- @ test noreply timeout
test_noreply_timeout = s:option(Value,"test_noreply_timeout",translate("Call Timeout(s)"))
test_noreply_timeout.default = "20"
test_noreply_timeout.margin = "30px"
test_noreply_timeout.datatype = "range(1,3600)"
test_noreply_timeout.rmempty = "false"
for k,v in pairs(forward_extension_dst) do
	test_noreply_timeout:depends("test_noreply",v.index)
end
for k,v in pairs(forward_trunk_dst) do
	test_noreply_timeout:depends("test_noreply",v.index)
end

function test_noreply_timeout.validate(self, value)
	local tmp = m:get(arg[1],"test_noreply")
	if not tmp or tmp == "Deactivate" or tmp == "" then
		m:del(arg[1],"test_noreply_timeout")
		return value or ""
	else
		return Value.validate(self, value)
	end
end
-- @ end

return m
