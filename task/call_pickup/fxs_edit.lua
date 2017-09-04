--[[

]]--
local dsp = require "luci.dispatcher"
local uci = require "luci.model.uci".cursor()

arg[1] = arg[1] or ""
arg[2] = arg[2] or ""

uci:check_cfg("profile_fxso")
uci:check_cfg("endpoint_mobile")
uci:check_cfg("endpoint_sipphone")
uci:check_cfg("endpoint_siptrunk")
uci:check_cfg("profile_number")
uci:check_cfg("feature_code")

local current_user = dsp.context.authuser
local number_access = uci:get("user",current_user.."_web","profile_number")
local profile_access = uci:get("user",current_user.."_web","profile_fxso")
local numprofile_tb = uci:get_all("profile_number") or {}

local current_section=arg[1]
if arg[2] == "edit" then
	m = Map("endpoint_fxso",translate("Extension / FXS / Edit"))
else
	m = Map("endpoint_fxso",translate("Extension / FXS / New"))
    m.addnew = true
    m.new_section = arg[1]
end

local continue_param = "extension-fxs-"..arg[1].."-"..arg[2]
if arg[3] then
	continue_param = continue_param .. ";" .. arg[3]
end

function m.insertprofile(self,param)
	local profile,exparam = param:match("([a-z_]+)/(.+)")
	local map = Map(profile)
	local section = map:section(TypedSection,"fxs")
	local created = TypedSection.create(section,nil)
	map.uci:save(profile)
	if "profile_fxso" == profile then
		luci.http.redirect(dsp.build_url("admin","profile","fxso","fxs",created,"add",exparam))
	else
		luci.http.redirect(dsp.build_url("admin","profile","number","number",created,"add",exparam))
	end
	return
end

m.redirect = dsp.build_url("admin","extension","fxs")

if not m.uci:get(arg[1]) == "fxs" then
	luci.http.redirect(m.redirect)
end

s = m:section(NamedSection,arg[1],"fxs","")
m.currsection = s
s.addremove = false
s.anonymous = true

local this_index = uci:get("endpoint_fxso",arg[1],"index")
local sip_profile = uci:get_all("endpoint_sipphone") or {}
local fxso_profile = uci:get_all("endpoint_fxso") or {}
local mobile_profile = uci:get_all("endpoint_mobile") or {}
local ringgroup_profile = uci:get_all("endpoint_ringgroup") or {}
local feature_code = uci:get_all("feature_code") or {}
local exist_extension = ""
local exist_did = ""
--# sip_extension
for k,v in pairs(sip_profile) do
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
for k,v in pairs(fxso_profile) do
	--# fxs
	if v['.type'] == "fxs" and v.index and v.index ~= this_index and luci.version.license and luci.version.license.fxs then
		if v.number_1 then
			exist_extension = exist_extension..v.number_1.."&"
		end
		if v.number_2 and luci.version.license.fxs > 1 then
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
		if v.did_2 and luci.version.license.fxs > 1 then
			if "table" == type(v.did_2) then
				for i,j in pairs(v.did_2) do
					exist_did = exist_did..j.."&"
				end
			else
				exist_did = exist_did..v.did_2.."&"
			end
		end
	end

	if v['.type'] == "fxo" and luci.version.license and luci.version.license.fxo then
		if v.number_1 and luci.version.license.fxo > 1 then
			exist_extension = exist_extension..v.number_1.."&"
		end
		if v.number_2 then
			exist_extension = exist_extension..v.number_2.."&"
		end		
	end
end
--# gsm / cdma / volte
if luci.version.license and (luci.version.license.gsm or luci.version.license.volte) then
	for k,v in pairs(mobile_profile) do
		if v.number then
			exist_extension = exist_extension..v.number.."&"
		end
	end
end
--# ringgroup 
for k,v in pairs(ringgroup_profile) do
	if v.number then
		exist_extension = exist_extension..v.number.."&"
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

for k,v in pairs(feature_code) do
	exist_did=exist_did..v.code.."&"..v.code.."#&"
end

--port 1
number_1 = s:option(Value,"number_1",translate("Extension"))
--number_1.datatype = "phonenumber"
number_1.datatype = "extension("..exist_extension..")"
number_1.rmempty = false

did_1 = s:option(DynamicList,"did_1",translate("DID"))
did_1.datatype = "did("..exist_did..")"

local server_list = {}

for i=1,32 do
	for k,v in pairs(uci:get_all("endpoint_siptrunk") or {}) do
		if v.index and tonumber(v.index) == i and "Enabled" == v.status and v.index and v.name then
			table.insert(server_list, {index=v.index, name=translate("SIP Trunk").." / "..v.name})
			break
		end
	end
end

reg_1 = s:option(ListValue,"port_1_reg",translate("Register to SIP Server"))
reg_1.default = "off"
reg_1:value("off",translate("Off"))
reg_1:value("on",translate("On"))

reg_1_master_server = s:option(ListValue,"port_1_server_1",translate("Master Server"))
reg_1_master_server:depends("port_1_reg","on")
reg_1_master_server.margin = "30px"
for k,v in ipairs(server_list) do
	if 1 == k then
		reg_1_master_server.default = v.index
	end
	reg_1_master_server:value(v.index,v.name)
end
if 0 == #server_list then
	reg_1_master_server:value("0",translate("Not Config"))
end

reg_1_slave_server = s:option(ListValue,"port_1_server_2",translate("Slave Server"))
reg_1_slave_server:depends("port_1_reg","on")
reg_1_slave_server.margin = "30px"
for k,v in ipairs(server_list) do
	if 2 == k then
		reg_1_slave_server.default = v.index
	end
	reg_1_slave_server:value(v.index,v.name)
end
reg_1_slave_server:value("0",translate("Not Config"))
reg_1_slave_server.default="0"

username_1 = s:option(Value,"username_1",translate("Username"))
username_1:depends("port_1_reg","on")
username_1.margin="30px"

authuser_1 = s:option(Value,"authuser_1",translate("Auth Username"))
authuser_1:depends("port_1_reg","on")
authuser_1.margin="30px"

password_1 = s:option(Value,"port_1_password",translate("Password"))
password_1.password = true
password_1:depends("port_1_reg","on")
password_1.margin="30px"

regurl_1 = s:option(ListValue,"reg_url_with_transport_1",translate("Specify Transport Protocol on Register URL"))
regurl_1:depends("port_1_reg","on")
regurl_1.margin="30px"
regurl_1:value("off",translate("Off"))
regurl_1:value("on",translate("On"))

expiresec_1 = s:option(Value,"expire_seconds_1",translate("Expire Seconds"))
expiresec_1:depends("port_1_reg","on")
expiresec_1.default = "1800"
expiresec_1.rmempty = false
expiresec_1.datatype = "min(5)"
expiresec_1.margin="30px"
function expiresec_1.validate(self, value)
	if "on" == m:get(arg[1],"port_1_reg") then
		return AbstractValue.validate(self, value)
	else
		m:del(arg[1],"expire_seconds_1")
		return value or ""
	end
end

retrysec_1 = s:option(Value,"retry_seconds_1",translate("Retry Seconds"))
retrysec_1:depends("port_1_reg","on")
retrysec_1.default = "60"
retrysec_1.rmempty = false
retrysec_1.datatype = "range(5,99999)"
retrysec_1.margin="30px"
function retrysec_1.validate(self, value)
	if "on" == m:get(arg[1],"port_1_reg") then
		return AbstractValue.validate(self, value)
	else
		m:del(arg[1],"retry_seconds_1")
		return value or ""
	end
end

hotline_1 = s:option(ListValue,"hotline_1",translate("Hot Line"))
hotline_1:value("off",translate("Off"))
hotline_1:value("on",translate("On"))

hotline_1_num = s:option(Value,"hotline_1_number",translate("Number"))
hotline_1_num.margin="30px"
hotline_1_num:depends("hotline_1","on")
hotline_1_num.datatype="phonenumber"

hotline_1_time = s:option(ListValue,"hotline_1_time",translate("Delay"))
hotline_1_time:value("10",translate("Immediately"))
hotline_1_time:value("1000",translatef("%d Second",1))
hotline_1_time:value("2000",translatef("%d Second",2))
hotline_1_time:value("3000",translatef("%d Second",3))
hotline_1_time:value("4000",translatef("%d Second",4))
hotline_1_time:value("5000",translatef("%d Second",5))
hotline_1_time.margin="30px"
hotline_1_time:depends("hotline_1","on")

call_pickup_1 = s:option(ListValue, "call_pickup_1", translate("Call Pickup"))
call_pickup_1.default = "ringgrp"
call_pickup_1:value("off",translate("Off"))
call_pickup_1:value("ringgrp",translate("Ring Group"))
call_pickup_1:value("extension",translate("Local Extension"))

--@ Extension service settings
call_waiting_1 = s:option(ListValue,"waiting_1",translate("Call Waiting"))
call_waiting_1.default = "Deactivate"
call_waiting_1:value("Deactivate",translate("Off"))
call_waiting_1:value("Activate",translate("On"))

call_notdisturb_1 = s:option(ListValue,"notdisturb_1",translate("Do Not Disturb"))
call_notdisturb_1.default = "Deactivate"
call_notdisturb_1:value("Deactivate",translate("Off"))
call_notdisturb_1:value("Activate",translate("On"))

--@ get table of forward dst
local forward_extension_dst = {}
local forward_trunk_dst = {}

if luci.version.license and luci.version.license.fxo then--check fxo license
	for k,v in pairs(uci:get_all("endpoint_fxso") or {}) do
		if "fxo" == v['.type'] then
			if v.index and "Enabled" == v.status then
				if luci.version.license.fxo > 1 then
					table.insert(forward_trunk_dst,{index="FXO/"..v.index.."/1",name=translate("FXO Trunk").." / "..translate("Port").." 0"})
					table.insert(forward_trunk_dst,{index="FXO/"..v.index.."/2",name=translate("FXO Trunk").." / "..translate("Port").." 1"})
				else
					table.insert(forward_trunk_dst,{index="FXO/"..v.index.."/2",name=translate("FXO Trunk")})
				end
			end
		end
	end
end

for i=1,32 do
	for k,v in pairs(uci:get_all("endpoint_sipphone") or {}) do
		if v.index and tonumber(v.index) == i and "Enabled" == v.status and v.user and v.name then
			table.insert(forward_extension_dst,{index=v.user,name=translate("SIP Extension").." / "..v.name.." / "..v.user})
			break
		end
	end
end

for k,v in pairs(uci:get_all("endpoint_mobile") or {}) do
	if "Enabled" == v.status and v.slot_type and v.slot_type:match("GSM$") then
		table.insert(forward_trunk_dst,{index="gsmopen/"..v.slot_type,name=translate("GSM Trunk")})
		break
	end
	if "Enabled" == v.status and v.slot_type and v.slot_type:match("CDMA$") and v.name then
		table.insert(forward_trunk_dst,{index="gsmopen/"..v.slot_type,name=translate("CDMA Trunk")})
		break
	end
	if "Enabled" == v.status and v.slot_type and v.slot_type:match("VOLTE$") and v.name then
		table.insert(forward_trunk_dst,{index="gsmopen/"..v.slot_type,name=translate("VoLTE Trunk")})
		break
	end
end

for i=1,32 do
	for k,v in pairs(uci:get_all("endpoint_siptrunk") or {}) do
		if v.index and tonumber(v.index) == i and "Enabled" == v.status and v.index and v.name and v.profile then
			table.insert(forward_trunk_dst,{index="SIPT-"..v.profile.."_"..v.index,name=translate("SIP Trunk").." / "..v.name})
			break
		end
	end
end

--@ Forward uncondition
call_forward_uncondition_1 = s:option(ListValue,"forward_uncondition_1",translate("Call Forward Unconditional"))
call_forward_uncondition_1.default = "Deactivate"
call_forward_uncondition_1:value("Deactivate",translate("Off"))
for k,v in ipairs(forward_extension_dst) do
	call_forward_uncondition_1:value(v.index,v.name)
end
for k,v in ipairs(forward_trunk_dst) do
	call_forward_uncondition_1:value(v.index,v.name)
end
if #forward_trunk_dst > 0 then
	local forward_dst_uncondition_1 = s:option(Value,"forward_uncondition_dst_1",translate("Dest Number"))
	forward_dst_uncondition_1.margin = "30px"
	forward_dst_uncondition_1.datatype = "phonenumber"
	forward_dst_uncondition_1.rmempty = "false"
	for k,v in pairs(forward_trunk_dst) do
		forward_dst_uncondition_1:depends("forward_uncondition_1",v.index)
	end

	function forward_dst_uncondition_1.validate(self, value)
		local tmp = string.sub((m:get(arg[1],"forward_uncondition_1") or ""),1,3)
		if  tmp == "FXO" or tmp == "SIP" or tmp == "gsm" then
			return Value.validate(self, value)
		else 
			m:del(arg[1],"forward_uncondition_dst_1")
			return value or ""
		end
	end
end
--@ Forward busy
call_forward_busy_1 = s:option(ListValue,"forward_busy_1",translate("Call Forward Busy"))
call_forward_busy_1:depends({waiting_1="Deactivate",forward_uncondition_1="Deactivate"})
call_forward_busy_1.default = "Deactivate"
call_forward_busy_1:value("Deactivate",translate("Off"))
for k,v in ipairs(forward_extension_dst) do
	call_forward_busy_1:value(v.index,v.name)
end
for k,v in ipairs(forward_trunk_dst) do
	call_forward_busy_1:value(v.index,v.name)
end

if #forward_trunk_dst > 0 then
	local forward_dst_busy_1 = s:option(Value,"forward_busy_dst_1",translate("Dest Number"))
	forward_dst_busy_1.margin = "30px"
	forward_dst_busy_1.datatype = "phonenumber"
	forward_dst_busy_1.rmempty = "false"
	for k,v in pairs(forward_trunk_dst) do
		forward_dst_busy_1:depends("forward_busy_1",v.index)
	end

	function forward_dst_busy_1.validate(self, value)
		local tmp = string.sub((m:get(arg[1],"forward_busy_1") or ""),1,3)
		if  tmp == "FXO" or tmp == "SIP" or tmp == "gsm" then
			return Value.validate(self, value)
		else 
			m:del(arg[1],"forward_busy_dst_1")
			return value or ""
		end
	end
end

--@ Forward noreply
call_forward_noreply_1 = s:option(ListValue,"forward_noreply_1",translate("Call Forward No Reply"))
call_forward_noreply_1:depends("forward_uncondition_1","Deactivate")
call_forward_noreply_1.default = "Deactivate"
call_forward_noreply_1:value("Deactivate",translate("Off"))
for k,v in ipairs(forward_extension_dst) do
	call_forward_noreply_1:value(v.index,v.name)
end
for k,v in ipairs(forward_trunk_dst) do
	call_forward_noreply_1:value(v.index,v.name)
end

if #forward_trunk_dst > 0 then
	local forward_dst_noreply_1 = s:option(Value,"forward_noreply_dst_1",translate("Dest Number"))
	forward_dst_noreply_1.margin = "30px"
	forward_dst_noreply_1.datatype = "phonenumber"
	forward_dst_noreply_1.rmempty = "false"
	for k,v in pairs(forward_trunk_dst) do
		forward_dst_noreply_1:depends("forward_noreply_1",v.index)
	end

	function forward_dst_noreply_1.validate(self, value)
		local tmp = string.sub((m:get(arg[1],"forward_noreply_1") or ""),1,3)
		if  tmp == "FXO" or tmp == "SIP" or tmp == "gsm" then
			return Value.validate(self, value)
		else 
			m:del(arg[1],"forward_noreply_dst_1")
			return value or ""
		end
	end
end

local forward_noreply_timeout_1 = s:option(Value,"forward_noreply_timeout_1",translate("Call Timeout(s)"))
forward_noreply_timeout_1.default = "20"
forward_noreply_timeout_1.margin = "30px"
forward_noreply_timeout_1.datatype = "range(1,3600)"
forward_noreply_timeout_1.rmempty = "false"
for k,v in pairs(forward_extension_dst) do
	forward_noreply_timeout_1:depends("forward_noreply_1",v.index)
end
for k,v in pairs(forward_trunk_dst) do
	forward_noreply_timeout_1:depends("forward_noreply_1",v.index)
end

function forward_noreply_timeout_1.validate(self, value)
	local tmp = m:get(arg[1],"forward_noreply_1")
	if tmp == "Deactivate" then
		m:del(arg[1],"forward_noreply_timeout_1")
		return value or ""	
	else 
		return Value.validate(self, value)
	end
end	

dsp_input_gain_1 = s:option(ListValue,"dsp_input_gain_1",translate("Input Gain"))
dsp_input_gain_1.rmempty = false
dsp_input_gain_1.default = 0
dsp_output_gain_1 = s:option(ListValue,"dsp_output_gain_1",translate("Output Gain"))
dsp_output_gain_1.rmempty = false
dsp_output_gain_1.default = 0
for i=-10,10 do
	if i > 0 then
		dsp_input_gain_1:value(i,"+"..i.." dB")
		dsp_output_gain_1:value(i,"+"..i.." dB")
	else
		dsp_input_gain_1:value(i,i.." dB")
		dsp_output_gain_1:value(i,i.." dB")	
	end
end

work_mode = s:option(ListValue,"work_mode",translate("Work Mode"))
work_mode.default = 0
work_mode:value("0",translate("Voice"))
work_mode:value("1",translate("POS"))

in_filter = s:option(ListValue,"callin_filter_1",translate("Call In Filter"))
in_filter:value("off",translate("Off"))
in_filter:value("blacklist",translate("Black List"))
in_filter:value("whitelist",translate("White List"))

in_filter_blacklist = s:option(ListValue,"callin_filter_blacklist_1",translate("Call In Black List"))
in_filter_blacklist:depends("callin_filter_1","blacklist")
in_filter_blacklist.margin = "32px"

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
if "admin" == current_user or (number_access and number_access:match("edit")) then
	in_filter_blacklist:value("addnew_profile_number/"..continue_param,translate("< Add New ...>"))
	function in_filter_blacklist.cfgvalue(...)
		local v = m.uci:get("endpoint_fxso",current_section, "callin_filter_blacklist_1")
		if v and v:match("^addnew") then
			m.uci:revert("endpoint_fxso",current_section, "callin_filter_blacklist_1")
			v = m.uci:get("endpoint_fxso",current_section, "callin_filter_blacklist_1")
		end
		return v
	end
end

in_filter_whitelist = s:option(ListValue,"callin_filter_whitelist_1",translate("Call In White List"))
in_filter_whitelist:depends("callin_filter_1","whitelist")
in_filter_whitelist.margin = "32px"

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
if "admin" == current_user or (number_access and number_access:match("edit")) then
	in_filter_whitelist:value("addnew_profile_number/"..continue_param,translate("< Add New ...>"))
	function in_filter_whitelist.cfgvalue(...)
		local v = m.uci:get("endpoint_fxso",current_section, "callin_filter_whitelist_1")
		if v and v:match("^addnew") then
			m.uci:revert("endpoint_fxso",current_section, "callin_filter_whitelist_1")
			v = m.uci:get("endpoint_fxso",current_section, "callin_filter_whitelist_1")
		end
		return v
	end
end

out_filter = s:option(ListValue,"callout_filter_1",translate("Call Out Filter"))
out_filter:value("off",translate("Off"))
out_filter:value("blacklist",translate("Black List"))
out_filter:value("whitelist",translate("White List"))

out_filter_blacklist = s:option(ListValue,"callout_filter_blacklist_1",translate("Call Out Black List"))
out_filter_blacklist:depends("callout_filter_1","blacklist")
out_filter_blacklist.margin = "32px"

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

if "admin" == current_user or (number_access and number_access:match("edit")) then
	out_filter_blacklist:value("addnew_profile_number/"..continue_param,translate("< Add New ...>"))
	function out_filter_blacklist.cfgvalue(...)
		local v = m.uci:get("endpoint_fxso",current_section, "callout_filter_blacklist_1")
		if v and v:match("^addnew") then
			m.uci:revert("endpoint_fxso",current_section, "callout_filter_blacklist_1")
			v = m.uci:get("endpoint_fxso",current_section, "callout_filter_blacklist_1")
		end
		return v
	end
end

out_filter_whitelist = s:option(ListValue,"callout_filter_whitelist_1",translate("Call Out White List"))
out_filter_whitelist:depends("callout_filter_1","whitelist")
out_filter_whitelist.margin = "32px"

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
if "admin" == current_user or (number_access and number_access:match("edit")) then
	out_filter_whitelist:value("addnew_profile_number/"..continue_param,translate("< Add New ...>"))
	function out_filter_whitelist.cfgvalue(...)
		local v = m.uci:get("endpoint_fxso",current_section, "callout_filter_whitelist_1")
		if v and v:match("^addnew") then
			m.uci:revert("endpoint_fxso",current_section, "callout_filter_whitelist_1")
			v = m.uci:get("endpoint_fxso",current_section, "callout_filter_whitelist_1")
		end
		return v
	end
end
profile = s:option(ListValue,"profile",translate("FXS Profile"))

profile.rmempty = false
local profile_tb = uci:get_all("profile_fxso") or {}
for i=1,32 do
	for k,v in pairs(profile_tb) do
		if v.index and v.name then
			if tonumber(v.index) == i and "fxs" == v['.type'] then
				profile:value(v.index,v.index.."-< "..v.name.." >")
				break
			end
		else
			uci:delete("profile_fxso",k)
			uci:save("profile_fxso")
		end
	end
end
if "admin" == current_user or (profile_access and profile_access:match("edit")) then
	profile:value("addnew_profile_fxso/"..continue_param,translate("< Add New ...>"))
	function profile.cfgvalue(...)
		local v = m.uci:get("endpoint_fxso",current_section, "profile")
		if v and v:match("^addnew") then
			m.uci:revert("endpoint_fxso",current_section, "profile")
			v = m.uci:get("endpoint_fxso",current_section, "profile")
		end
		return v
	end
end
slot_status = s:option(ListValue,"status",translate("Status"))
slot_status.rmempty = false
slot_status:value("Enabled",translate("Enable"))
slot_status:value("Disabled",translate("Disable"))

return m

