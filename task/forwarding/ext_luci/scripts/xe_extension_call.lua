require "mxml"
require "uci"
require "luci.util"

local fs = require "nixio.fs"
local base64 = require "luci.base64"

local cfgfilelist = {"system","profile_codec","profile_sip","endpoint_fxso","endpoint_siptrunk","endpoint_sipphone","endpoint_ringgroup","endpoint_mobile","callcontrol","profile_time"}
for k,v in ipairs(cfgfilelist) do
	os.execute("cp /etc/config/"..v.." /tmp/config")
end

local uci = uci.cursor("/tmp/config","/tmp/state")
local interface = uci:get("system","main","interface") or ""

local fxso_cfg = uci:get_all("endpoint_fxso") or {}
local codec_cfg = uci:get_all("profile_codec") or {"PCMA","PCMU"}
local ringgroup = uci:get_all("endpoint_ringgroup") or {}
local mobile_cfg = uci:get_all("endpoint_mobile") or {}
local sipphone_cfg = uci:get_all("endpoint_sipphone") or {}
local siptrunk_cfg = uci:get_all("endpoint_siptrunk") or {}
local sip_profile_cfg = uci:get_all("profile_sip") or {}
local callcontrol_cfg = uci:get_all("callcontrol","route")
local number_profile_cfg = uci:get_all("profile_number") or {}
local time_cfg = uci:get_all("profile_time") or {}

--[[
local did_call_00 = "/tmp/etc/freeswitch/conf/dialplan/public/00_did_call.xml"
local extension_call_00 = "/tmp/etc/freeswitch/conf/dialplan/public/00_extension_call.xml"
local extension_call_01 = "/tmp/etc/freeswitch/conf/dialplan/public/01_extension_call.xml"
local extension_call_z99 = "/tmp/etc/freeswitch/conf/dialplan/public/z_99_extension_call.xml"
local extension_users_xml = "/tmp/etc/freeswitch/conf/directory/default/users.xml"
local extension_service_script = "/usr/lib/lua/luci/scripts/Extension-Service.lua"
local extension_followme_script = "/usr/lib/lua/luci/scripts/Followme.lua"
local extension_callout_check_00 = "/tmp/etc/freeswitch/conf/dialplan/public/00_callout_check.xml"

local fs_scripts_dir = "/tmp/etc/freeswitch/scripts"
local sip_extension_dir = "/tmp/etc/freeswitch/conf/directory/default"
local pstn_extension_dir = "/tmp/etc/freeswitch/conf/dialplan/extension"
]]--
local did_call_00 = "/etc/freeswitch/conf/dialplan/public/00_did_call.xml"
local extension_call_00 = "/etc/freeswitch/conf/dialplan/public/00_extension_call.xml"
local extension_call_01 = "/etc/freeswitch/conf/dialplan/public/01_extension_call.xml"
local extension_call_z99 = "/etc/freeswitch/conf/dialplan/public/z_99_extension_call.xml"
local extension_users_xml = "/etc/freeswitch/conf/directory/default/users.xml"
local extension_service_script = "/usr/lib/lua/luci/scripts/Extension-Service.lua"
local extension_followme_script = "/usr/lib/lua/luci/scripts/Followme.lua"
local extension_callout_check_00 = "/etc/freeswitch/conf/dialplan/public/00_callout_check.xml"

local fs_scripts_dir = "/etc/freeswitch/scripts"
local sip_extension_dir = "/etc/freeswitch/conf/directory/default"
local pstn_extension_dir = "/etc/freeswitch/conf/dialplan/extension"

local local_sip_fxs_dest = ""
local local_ringgroup_dest = ""

local DID_table = {}
local default_dest_number_table = {}
local local_port_reg_dest_to_trunk_tbl = {}
local local_port_reg_dest_to_sipsrv_tbl = {}
local local_port_reg_dest_to_extension_tbl = {}

local ext_callout_chk_table = {}

--@ delete old xml file
os.execute("rm "..did_call_00.." "..extension_call_00.." "..extension_call_z99.." "..extension_callout_check_00)

if fs.access(pstn_extension_dir) then
	os.execute("rm "..pstn_extension_dir.."/*.xml")
else
	os.execute("mkdir "..pstn_extension_dir)
end

if fs.access(extension_users_xml) then
	os.execute("rm "..extension_users_xml)
else
	os.execute("mkdir -p "..sip_extension_dir)
end

--@ CREATE EXTENSION USERS XML
local users_root = mxml:newxml()
local users_include = mxml.newnode(users_root,"include")

local codec = {}
local sip_ex_tb = ""
local fxs_ex_tb = ""

local fm_ex_tb = {forward_uncondition="",forward_unregister="",forward_busy="",forward_noreply="",forward_noreply_timeout=""}
local fm_sipuser_reg_query = ""
local fm_profile_time_tb = ""

local profile_interface = {}
local endpoint_interface = ""

for k,v in pairs(sip_profile_cfg) do
	for i,j in pairs(codec_cfg) do
		if v.index and v.outbound_codec_prefs and j.index and v.outbound_codec_prefs == j.index and j.code then
			codec[v.index] = table.concat(j.code,",") or "PCMA,PCMU"
		end
	end
	if v.index and v.localinterface then
		profile_interface[v.index] = v.localinterface
	end
end

for k,v in pairs(sipphone_cfg) do
	if v.user then
		sip_ex_tb = sip_ex_tb .. "[\""..v.user.."\"]={[\"reg_query\"]=\"sofia status profile "..v.profile.." reg "..v.user.."\","
		fm_sipuser_reg_query = fm_sipuser_reg_query .. "[\""..v.user.."\"]=\"sofia status profile "..v.profile.." reg "..v.user.."\","
		if v.waiting then
			sip_ex_tb = sip_ex_tb .. "[\"waiting\"]=\""..v.waiting.."\","
		end
		if v.notdisturb then
			sip_ex_tb = sip_ex_tb .. "[\"notdisturb\"]=\""..v.notdisturb.."\","
		end

		local forward_option_tb = {"forward_uncondition","forward_unregister","forward_busy","forward_noreply"}
		for _,forward_option in ipairs(forward_option_tb) do
			if v[forward_option] then
				local forward_tb
				if v[forward_option] == "Deactivate" then
					forward_tb = {}
					table.insert(forward_tb, v[forward_option])
				elseif v[forward_option] == "Followme" then
					forward_tb = v.followme
				elseif v[forward_option] == "Custom" then
					forward_tb = v["custom_"..forward_option]
				end
				if forward_tb and type(forward_tb) == "table" and next(forward_tb) then
					if forward[1] == "" or forward[1] == "Deactivate" then
						sip_ex_tb = sip_ex_tb .. "[\""..forward_option.."\"]=\"Deactivate\","
					else
						local tmp_str = ""
						sip_ex_tb = sip_ex_tb .. "[\""..forward_option.."\"]=\"Activate\","
						for _,val in ipairs(forward_tb) do
							local dest,time,number = val:match("([^:]+)::([^:]*)::([^:]+)")
							if not dest or not time or not number then
								dest,time = val:match("([^:]+)::([^:]+)")
								if not dest then
									dest = val
								end
							end
							if dest and time and number then
								tmp_str = tmp_str .. "{\""..dest.."\""..",\""..time.."\",\""..number.."\"},"
							elseif dest and time then
								tmp_str = tmp_str .. "{\""..dest.."\""..",\""..time.."\"},"
							elseif dest then
								tmp_str = tmp_str .. "{\""..dest.."\"},"
							end
						end
						if tmp_str ~= "" then
							fm_ex_tb[forward_option] = fm_ex_tb[forward_option] .."[\""..v.user.."\"]={"..tmp_str.."},"
						end
						tmp_str = nil
					end
				end
			end
		end
		if v["forward_noreply"] and v["forward_noreply_timeout"] then
			fm_ex_tb["forward_noreply_timeout"] = fm_ex_tb["forward_noreply_timeout"] .. "[\""..v.user.."\"]=\""..v["forward_noreply_timeout"].."\","
		end
		sip_ex_tb = sip_ex_tb .. "},"
	end
	if v.user and v.profile then
		endpoint_interface = endpoint_interface .. "[\""..v.user.."\"]=\""..(profile_interface[v.profile] or "").."\","
	end
end

for k,v in pairs(fxso_cfg) do
	if v['.type'] == 'fxs' and v.index then
		fxs_ex_tb = fxs_ex_tb .. "[\""..v.index.."\"]={"
		if v.waiting_1 then
			fxs_ex_tb = fxs_ex_tb .. "[\"waiting_1\"]=\""..v.waiting_1.."\","
		end
		if v.notdisturb_1 then
			fxs_ex_tb = fxs_ex_tb .. "[\"notdisturb_1\"]=\""..v.notdisturb_1.."\","
		end
		if v.waiting_2 then
			fxs_ex_tb = fxs_ex_tb .. "[\"waiting_2\"]=\""..v.waiting_2.."\","
		end
		if v.notdisturb_2 then
			fxs_ex_tb = fxs_ex_tb .. "[\"notdisturb_2\"]=\""..v.notdisturb_2.."\","
		end

		local forward_option_tb = {"forward_uncondition","forward_busy","forward_noreply"}
		local port_tb = {"1","2"}
		for _,port_index in ipairs(port_tb) do
			for _,forward_option in ipairs(forward_option_tb) do
				local port_forward_option = forward_option.."_"..port_index
				if v[port_forward_option] then
					if type(v[port_forward_option]) == "string" then
						local tmp_tb = {}
						table.insert(tmp_tb, v[port_forward_option])
						v[port_forward_option] = tmp_tb
					end
					if type(v[port_forward_option]) == "table" and next(v[port_forward_option]) then
						if v[port_forward_option][1] == "" or v[port_forward_option][1] == "Deactivate" then
							fxs_ex_tb = fxs_ex_tb .. "[\""..port_forward_option.."\"]=\"Deactivate\","
						else
							local tmp_str = ""
							fxs_ex_tb = fxs_ex_tb .. "[\""..port_forward_option.."\"]=\"Activate\","
							for _,val in ipairs(v[port_forward_option]) do
								local dest,time,number = val:match("([^:]*)::([^:]*)::([^:]*)")
								if not dest or not time or not number then
									dest,time = val:match("([^:]*)::([^:]*)")
									if not dest then
										dest = val
									end
								end
								if dest and time and number then
									tmp_str = tmp_str .. "{\""..dest.."\""..",\""..time.."\",\""..number.."\"},"
								elseif dest and time then
									tmp_str = tmp_str .. "{\""..dest.."\""..",\""..time.."\"},"
								elseif dest then
									tmp_str = tmp_str .. "{\""..dest.."\"},"
								end
							end
							if tmp_str ~= "" then
								fm_ex_tb[forward_option] = fm_ex_tb[forward_option] .."[\""..v.index.."/"..port_index.."\"]={"..tmp_str.."},"
							end
							tmp_str = nil
						end
					end
				end
			end
			if v["forward_noreply_"..port_index] and v["forward_noreply_timeout_"..port_index] then
				fm_ex_tb["forward_noreply_timeout"] = fm_ex_tb["forward_noreply_timeout"] .. "[\""..v.index.."/"..port_index.."\"]=\""..v["forward_noreply_timeout_"..port_index].."\","
			end
		end
		fxs_ex_tb = fxs_ex_tb .. "},"
	end
end

for k,v in pairs(siptrunk_cfg) do
	if v.index and v.profile then
		endpoint_interface = endpoint_interface .. "[\""..v.profile.."_"..v.index.."\"]=\""..(profile_interface[v.profile] or "").."\","
	end
end

for k,v in pairs(time_cfg) do
	if v.index and (v.weekday or v.date_options or v.time_options) then
		fm_profile_time_tb = fm_profile_time_tb .."[\""..v.index.."\"]={"
		if v.weekday then
			fm_profile_time_tb = fm_profile_time_tb .."[\"wday\"]=\""
			local tmp_str = v.weekday
			local wday_str = ""
			if tmp_str:match("Sun") then
				wday_str = wday_str.."1"
			end
			if tmp_str:match("Mon") then
				wday_str = wday_str.."2"
			end
			if tmp_str:match("Tue") then
				wday_str = wday_str.."3"
			end
			if tmp_str:match("Wed") then
				wday_str = wday_str.."4"
			end
			if tmp_str:match("Thu") then
				wday_str = wday_str.."5"
			end
			if tmp_str:match("Fri") then
				wday_str = wday_str.."6"
			end
			if tmp_str:match("Sat") then
				wday_str = wday_str.."7"
			end
			fm_profile_time_tb = fm_profile_time_tb ..wday_str.."\","
		end
		if v.date_options and next(v.date_options) then
			fm_profile_time_tb = fm_profile_time_tb .."[\"date\"]={"
			local date_str = ""
			for _,date_option in pairs(v.date_options) do
				date_str = date_str.."\""..date_option.."\","
			end
			fm_profile_time_tb = fm_profile_time_tb ..date_str.."},"
		end
		if v.time_options and next(v.time_options) then
			fm_profile_time_tb = fm_profile_time_tb .."[\"time\"]={"
			local time_str = ""
			for _,time_option in pairs(v.time_options) do
				time_str = time_str.."\""..time_option.."\","
			end
			fm_profile_time_tb = fm_profile_time_tb ..time_str.."},"
		end
		fm_profile_time_tb = fm_profile_time_tb.. "},"
	end
end

local cmd_str = ""
sip_ex_tb=string.gsub(sip_ex_tb,"/","\\/")
fxs_ex_tb=string.gsub(fxs_ex_tb,"/","\\/")
endpoint_interface=string.gsub(endpoint_interface,"/","\\/")
fm_ex_tb.forward_uncondition=string.gsub(fm_ex_tb.forward_uncondition,"/","\\/")
fm_ex_tb.forward_unregister=string.gsub(fm_ex_tb.forward_unregister,"/","\\/")
fm_ex_tb.forward_busy=string.gsub(fm_ex_tb.forward_busy,"/","\\/")
fm_ex_tb.forward_noreply=string.gsub(fm_ex_tb.forward_noreply,"/","\\/")
fm_ex_tb.forward_noreply_timeout=string.gsub(fm_ex_tb.forward_noreply_timeout,"/","\\/")
fm_sipuser_reg_query=string.gsub(fm_sipuser_reg_query,"/","\\/")
fm_profile_time_tb=string.gsub(fm_profile_time_tb,"/","\\/")
cmd_str = cmd_str.."sed -i 's/^local sip_ex_tb = {.*}/local sip_ex_tb = {"..sip_ex_tb.."}/g' "..extension_service_script..";"
cmd_str = cmd_str.."sed -i 's/^local fxs_ex_tb = {.*}/local fxs_ex_tb = {"..fxs_ex_tb.."}/g' "..extension_service_script..";"
cmd_str = cmd_str.."sed -i 's/^local endpoint_interface = {.*}/local endpoint_interface = {"..endpoint_interface.."}/g' "..extension_service_script..";"
cmd_str = cmd_str.."cp "..extension_service_script.." "..fs_scripts_dir..";"
cmd_str = cmd_str.."sed -i 's/^local forward_uncondition_tb = {.*}/local forward_uncondition_tb = {"..fm_ex_tb.forward_uncondition.."}/g' "..extension_followme_script..";"
cmd_str = cmd_str.."sed -i 's/^local forward_unregister_tb = {.*}/local forward_unregister_tb = {"..fm_ex_tb.forward_unregister.."}/g' "..extension_followme_script..";"
cmd_str = cmd_str.."sed -i 's/^local forward_busy_tb = {.*}/local forward_busy_tb = {"..fm_ex_tb.forward_busy.."}/g' "..extension_followme_script..";"
cmd_str = cmd_str.."sed -i 's/^local forward_noreply_tb = {.*}/local forward_noreply_tb = {"..fm_ex_tb.forward_noreply.."}/g' "..extension_followme_script..";"
cmd_str = cmd_str.."sed -i 's/^local forward_noreply_timeout_tb = {.*}/local forward_noreply_timeout_tb = {"..fm_ex_tb.forward_noreply_timeout.."}/g' "..extension_followme_script..";"
cmd_str = cmd_str.."sed -i 's/^local sipuser_reg_query = {.*}/local sipuser_reg_query = {"..fm_sipuser_reg_query.."}/g' "..extension_followme_script..";"
cmd_str = cmd_str.."sed -i 's/^local endpoint_interface = {.*}/local endpoint_interface = {"..endpoint_interface.."}/g' "..extension_followme_script..";"
cmd_str = cmd_str.."sed -i 's/^local profile_time_tb = {.*}/local profile_time_tb = {"..fm_profile_time_tb.."}/g' "..extension_followme_script..";"
cmd_str = cmd_str.."cp "..extension_followme_script.." "..fs_scripts_dir..";"
os.execute(cmd_str)

local fm_ex_tb = {forward_uncondition="",forward_unregister="",forward_busy="",forward_noreply="",forward_noreply_timeout=""}
local fm_sipuser_reg_query = ""

function add_action(parent_node,app,data)
	if parent_node and app then
		local action = mxml.newnode(parent_node,"action")
		mxml.setattr(action,"application",app)
		if data then
			mxml.setattr(action,"data",data)
		end
	end
end
function add_anti_action(parent_node,app,data)
	if parent_node and app then
		local action = mxml.newnode(parent_node,"anti-action")
		mxml.setattr(action,"application",app)
		if data then
			mxml.setattr(action,"data",data)
		end
	end
end
function add_to_destnum_list(src,dst)
	if not src or "" == src then
		return dst
	end
	local num = string.gsub(src,"+","\\+")
	num = string.gsub(num,"*","\\*")
	if not dst or dst == "" then
		dst = "^"..num.."[*#]{0,1}$"
	elseif not string.find(dst,"^"..num.."$") then
		dst = dst.."|^"..num.."[*#]{0,1}$"
	end

	return dst
end
function add_condition(parent_node,field,expression)
	local condition = mxml.newnode(parent_node,"condition")
	if field == "wday" or field == "time-of-day" or field == "date-time" then
		mxml.setattr(condition,field,expression)
	elseif field and expression then
		mxml.setattr(condition,"field",field)
		mxml.setattr(condition,"expression",expression)
	end
	return condition
end
function number_regular_parse(parent_node,field,value)
	function string_val_parse(value)
		if value:match("^[0-9a-zA-Z]+$") then
			return "^"..value 
		elseif value:match("^[0-9a-zA-Z|]+$") then
			return "^".."("..value..")"
		else
			return value
		end
	end
	if value and "string" == type(value) then
		return add_condition(parent_node,field,string_val_parse(value))
	elseif value and "table" == type(value) then
		local result_str
		for k,v in ipairs(value) do
			if "" ~= v then
				result_str=(result_str and (result_str.."|") or "")..string_val_parse(v)
			end
		end
		return add_condition(parent_node,field,result_str)
	end
end
function number_length_parse(value)
	local tmp = luci.util.split(value,"|")
	local exp = ""
	for _,v2 in pairs(tmp) do
		if v2 ~= "" then
			if exp == "" then
				exp = tostring("^(\\d{")..string.gsub(v2,"-",",")..tostring("})$")
			else
				exp = exp.."|"..tostring("^(\\d{")..string.gsub(v2,"-",",")..tostring("})$")
			end
		end
	end
	return exp
end
function callin_number_condition(parent_node,value)
	local condition
	for k,v in pairs(number_profile_cfg) do
		if v.index == value then
			if v.callerlength then
				condition = add_condition(parent_node,"caller_id_number",number_length_parse(v.callerlength))
			end
			if v.caller then
				condition = number_regular_parse(parent_node,"caller_id_number",v.caller)
			end
			break
		end
	end
	return condition
end
function callout_number_condition(parent_node,value)
	local condition
	for k,v in pairs(number_profile_cfg) do
		if v.index == value then
			if v.calledlength then
				condition = add_condition(parent_node,"destination_number",number_length_parse(v.calledlength))
			end
			if v.called then
				condition = number_regular_parse(parent_node,"destination_number",v.called)
			end
			break
		end
	end
	return condition
end
function generate_extension_xml(param)
	local xml = mxml:newxml()
	local include = mxml.newnode(xml,"include")

	if param.callin_blacklist then
		local extension = mxml.newnode(include,"extension")
		mxml.setattr(extension,"name",param.number.."_call_in_blacklist_check")
		mxml.setattr(extension,"continue","true")
		add_condition(extension,"destination_number","^"..param.number.."[*#]{0,1}$")
		local condition = callin_number_condition(extension,param.callin_blacklist)
		add_action(condition,"set","my_bridge_channel="..param.bridge_channel)
		add_action(condition,"log","ERR Extension "..param.number.." can not call in ! (Blacklist Matched)")
		add_action(condition,"hangup","INVALID_NUMBER_FORMAT")
	elseif param.callin_whitelist then
		local extension = mxml.newnode(include,"extension")
		mxml.setattr(extension,"name",param.number.."_call_in_whitelist_check")
		mxml.setattr(extension,"continue","true")
		local condition = callin_number_condition(extension,param.callin_whitelist)
		mxml.setattr(condition,"require-nested","true")
		add_condition(condition,"destination_number","^"..param.number.."[*#]{0,1}$")
		add_anti_action(condition,"set","my_bridge_channel="..param.bridge_channel)
		add_anti_action(condition,"log","ERR Extension "..param.number.." can not call in ! (Whitelist Not Matched)")
		add_anti_action(condition,"hangup","INVALID_NUMBER_FORMAT")
	end

	local extension = mxml.newnode(include,"extension")
	mxml.setattr(extension,"name",param.number)

	local condition = add_condition(extension,"destination_number","^"..param.number.."[*#]{0,1}$")

	if "FXS" == param.slot_type or "SIPP" == param.slot_type then
		add_action(condition,"set","my_exten_bridge_param="..param.bridge_data)
		add_action(condition,"set","my_callwaiting_number="..param.number)
		add_action(condition,"set","my_bridge_channel="..param.bridge_channel)
		add_action(condition,"export","sip_contact_user="..param.number)
		add_action(condition,"transfer","ExtensionService XML extension-service")
	else
		add_action(condition,"set","destination_number=${my_dst_number}")
		add_action(condition,"set","dest_chan_name="..param.bridge_channel)
		add_action(condition,"lua","check_line_is_busy.lua "..param.bridge_data)
		add_action(condition,"ring_ready")
		add_action(condition,"bridge",param.bridge_data)
		
		local condition_transfer = mxml.newnode(extension,"condition")
		mxml.setattr(condition_transfer,"field","${transfer_name_on_fail}")
		mxml.setattr(condition_transfer,"expression","^FAIL")
		mxml.setattr(condition_transfer,"break","never")
		
		add_action(condition_transfer,"transfer","${transfer_name_on_fail} XML failroute")--@ when you set channel_var continue_on_fail,it will transfer the failed_hextension
	end

	mxml.savefile(xml,pstn_extension_dir.."/"..param.number..".xml")
	mxml.release(xml)
end

function get_sip_trunk_name_list()
	local list = {}
	local name = {}
	local trunk = uci:get_all("endpoint_siptrunk")

	for k,v in pairs(trunk) do
		if v.index and v.profile and "Enabled" == v.status and v.name then
			list[v.index] = v.profile.."_"..v.index
			name[v.index] = v.name
		end
	end

	return list,name
end

function generate_pstn_extension_data()
	if not fxso_cfg then
		return
	end

	local srv_name,sipt_name = get_sip_trunk_name_list()

	for k,v in pairs(fxso_cfg) do
		if v.index and v.number_1 and "" ~= v.number_1 and v.status and v.status == "Enabled" and ((interface:match("S") and v[".type"] == "fxs") or (interface:match("2O") and v[".type"] == "fxo")) then
			local param = {}
			param.number = v.number_1
			param.bridge_data = "freetdm/"..v.index.."/1/${my_dst_number}"
			
			if string.find(v.slot_type,"FXS") then
				local callgroup_user = mxml.newnode(users_include,"user")
				mxml.setattr(callgroup_user,"id",v.number_1)
				local callgroup_params = mxml.newnode(callgroup_user,"params")
				local callgroup_param = mxml.newnode(callgroup_params,"param")
				mxml.setattr(callgroup_param,"name","dial_string")
				mxml.setattr(callgroup_param,"value","freetdm/"..v.index.."/1/${digits}")
				local channel_name = mxml.newnode(callgroup_params,"param")
				mxml.setattr(channel_name,"name","channel_name")
				if interface:match("1S") then
					mxml.setattr(channel_name,"value","FXS")
					param.bridge_channel = "FXS"
				else
					mxml.setattr(channel_name,"value","FXS Extension/"..v.number_1)
					param.bridge_channel = "FXS Extension/"..v.number_1
				end
				param.slot_type = "FXS"	
			else
				param.slot_type = "FXO"
				param.bridge_channel = "FXO Trunk/Port 0"
			end
			
			if v.port_1_reg and "on" == v.port_1_reg then
				local_port_reg_dest_to_sipsrv_tbl[v.number_1] = {name1="",name2="",master=nil,slave=nil,from="^FreeTDM/"..v.index.."/1|^FreeTDM/"..v.index..":1"}
				
				if v.port_1_server_1 and "0" ~= v.port_1_server_1 and srv_name[v.port_1_server_1] then
					local_port_reg_dest_to_sipsrv_tbl[v.number_1]["name1"] = sipt_name[v.port_1_server_1] or ""
					local_port_reg_dest_to_sipsrv_tbl[v.number_1]["master"] = srv_name[v.port_1_server_1].."-"..v.slot_type.."-1-"..v.number_1
				end
				if v.port_1_server_2 and "0" ~= v.port_1_server_2 and srv_name[v.port_1_server_2] then
					local_port_reg_dest_to_sipsrv_tbl[v.number_1]["name2"] = sipt_name[v.port_1_server_2] or ""
					local_port_reg_dest_to_sipsrv_tbl[v.number_1]["slave"] = srv_name[v.port_1_server_2].."-"..v.slot_type.."-1-"..v.number_1
				end
			end

			if "blacklist" == v.callin_filter_1 then
				param.callin_blacklist = v.callin_filter_blacklist_1
			elseif "whitelist" == v.callin_filter_1 then
				param.callin_whitelist = v.callin_filter_whitelist_1
			end

			if "blacklist" == v.callout_filter_1 then
				local tmp = {chan_name="^FreeTDM/"..v.index.."/1|^FreeTDM/"..v.index..":1",number=v.number_1,filter="blacklist",blacklist=v.callout_filter_blacklist_1}
				table.insert(ext_callout_chk_table,tmp)
			elseif "whitelist" == v.callout_filter_1 then
				local tmp = {chan_name="^FreeTDM/"..v.index.."/1|^FreeTDM/"..v.index..":1",number=v.number_1,filter="whitelist",whitelist=v.callout_filter_whitelist_1}
				table.insert(ext_callout_chk_table,tmp)
			end
			generate_extension_xml(param)
		end

		if v.index and v.number_2 and "" ~= v.number_2 and v.status and v.status == "Enabled" and (interface:match("O") or interface:match("2S")) then
			local param = {}
			param.number = v.number_2
			param.bridge_data = "freetdm/"..v.index.."/2/${my_dst_number}"
			
			if string.find(v.slot_type,"FXS") then
				local callgroup_user = mxml.newnode(users_include,"user")
				mxml.setattr(callgroup_user,"id",v.number_2)
				local callgroup_params = mxml.newnode(callgroup_user,"params")
				local callgroup_param = mxml.newnode(callgroup_params,"param")
				mxml.setattr(callgroup_param,"name","dial_string")
				mxml.setattr(callgroup_param,"value","freetdm/"..v.index.."/2/${digits}")
				local channel_name = mxml.newnode(callgroup_params,"param")
				mxml.setattr(channel_name,"name","channel_name")
				mxml.setattr(channel_name,"value","FXS Extension/"..v.number_2)

				param.slot_type = "FXS"
				param.bridge_channel = "FXS Extension/"..v.number_2
			else
				param.slot_type = "FXO"
				if interface:match("1O") then
					param.bridge_channel = "FXO"
				else
					param.bridge_channel = "FXO Trunk/Port 1"
				end
			end
			
			if v.port_2_reg and "on" == v.port_2_reg then
				local_port_reg_dest_to_sipsrv_tbl[v.number_2] = {name1="",name2="",master=nil,slave=nil,from="^FreeTDM/"..v.index.."/2|^FreeTDM/"..v.index..":2"}
				if v.port_2_server_1 and "0" ~= v.port_2_server_1 and srv_name[v.port_2_server_1] then
					local_port_reg_dest_to_sipsrv_tbl[v.number_2]["name1"] = sipt_name[v.port_2_server_1] or ""
					local_port_reg_dest_to_sipsrv_tbl[v.number_2]["master"] = srv_name[v.port_2_server_1].."-"..v.slot_type.."-2-"..v.number_2
				end
				if v.port_2_server_2 and "0" ~= v.port_2_server_2 and srv_name[v.port_2_server_2] then
					local_port_reg_dest_to_sipsrv_tbl[v.number_2]["name2"] = sipt_name[v.port_2_server_2] or ""
					local_port_reg_dest_to_sipsrv_tbl[v.number_2]["slave"] = srv_name[v.port_2_server_2].."-"..v.slot_type.."-2-"..v.number_2
				end
			end

			if "blacklist" == v.callin_filter_2 then
				param.callin_blacklist = v.callin_filter_blacklist_2
			elseif "whitelist" == v.callin_filter_2 then
				param.callin_whitelist = v.callin_filter_whitelist_2
			end

			if "blacklist" == v.callout_filter_2 then
				local tmp = {chan_name="^FreeTDM/"..v.index.."/2|^FreeTDM/"..v.index..":2",number=v.number_2,filter="blacklist",blacklist=v.callout_filter_blacklist_2}
				table.insert(ext_callout_chk_table,tmp)
			elseif "whitelist" == v.callout_filter_2 then
				local tmp = {chan_name="^FreeTDM/"..v.index.."/2|^FreeTDM/"..v.index..":2",number=v.number_2,filter="whitelist",whitelist=v.callout_filter_whitelist_2}
				table.insert(ext_callout_chk_table,tmp)
			end
			generate_extension_xml(param)
		end
		if v.slot_type:match("%d+%-FXS") and v.status == "Enabled" and interface:match("S") then
			if interface:match("1S") then
				local_sip_fxs_dest = add_to_destnum_list(v.number_1,local_sip_fxs_dest)
				if v.did_1 then
					DID_table[v.did_1] = v.number_1
				end
			else
				local_sip_fxs_dest = add_to_destnum_list(v.number_1,local_sip_fxs_dest)
				local_sip_fxs_dest = add_to_destnum_list(v.number_2,local_sip_fxs_dest)
				if v.did_1 then
					DID_table[v.did_1] = v.number_1
				end
				if v.did_2 then
					DID_table[v.did_2] = v.number_2
				end
			end
		end
		default_dest_number_table[tonumber(v.index)] = ""
	end
	if interface:match("G") then
		for k,v in pairs(mobile_cfg) do
			if v.slot_type and v.number and v.number ~= "" and v.slot_type and v.slot_type:match("GSM$") and v.status and v.status == "Enabled" then
				local param = {}
				param.number = v.number
				param.bridge_data = "gsmopen/"..v.slot_type.."/${my_dst_number}"
				param.bridge_channel = "GSM"
				param.slot_type = "mobile"
				
				generate_extension_xml(param)

				default_dest_number_table[tonumber(v.index)] = ""

				if v.port_reg and "on" == v.port_reg then
					local_port_reg_dest_to_sipsrv_tbl[v.number] = {name1="",name2="",master=nil,slave=nil,from="^gsmopen/"..v.slot_type}
					if v.port_server_1 and "0" ~= v.port_server_1 and srv_name[v.port_server_1] then
						local_port_reg_dest_to_sipsrv_tbl[v.number]["name1"] = sipt_name[v.port_server_1] or ""
						local_port_reg_dest_to_sipsrv_tbl[v.number]["master"] = srv_name[v.port_server_1].."-"..v.slot_type.."-"..v.number
					end
					if v.port_server_2 and "0" ~= v.port_server_2 and srv_name[v.port_server_2] then
						local_port_reg_dest_to_sipsrv_tbl[v.number]["name2"] = sipt_name[v.port_server_2] or ""
						local_port_reg_dest_to_sipsrv_tbl[v.number]["slave"] = srv_name[v.port_server_2].."-"..v.slot_type.."-"..v.number
					end
				end
			end
		end
	end
end
function netmask2num(val)
	local bit = require "bit"
	if val and "0.0.0.0" ~= val then
		if val:match("^%d+%.%d+%.%d+%.%d+$") then
			return val.."/"..32
		elseif val:match("^%d+%.%d+%.%d+%.%d+/%d+$") then
			return val
		elseif val:match("%d+%.%d+%.%d+%.%d+/%d+%.%d+%.%d+%.%d+$") then
			local addr = "0.0.0.0"
			local x = {}
			local cnt = 0
			addr,x[1],x[2],x[3],x[4] = val:match("^(%d+%.%d+%.%d+%.%d+)/(%d+)%.(%d+)%.(%d+)%.(%d+)$")
			for i=1,4 do
				for j=0,7 do
					local b = bit.band(tonumber(x[i]),bit.rshift(128,j))
					if 0 ~= b then
						cnt = cnt + 1
					else
						return addr.."/"..cnt
					end
				end
			end
		end
	else
		return "0.0.0.0/0"
	end
end
function generate_sip_extension_data()
	if not sipphone_cfg then
		return
	end

	for k,v in pairs(sipphone_cfg) do
		if v.user and v.index then
			local user = mxml.newnode(users_include,"user")
			mxml.setattr(user,"id",v.user)

			local params = mxml.newnode(user,"params")

			local param = mxml.newnode(params,"param")
			if v.password and "" ~= v.password then
				mxml.setattr(param,"name","password-base64")
				mxml.setattr(param,"value",base64.enc(v.password))
			else
				mxml.setattr(param,"name","allow-empty-password")
				mxml.setattr(param,"value","on")
			end

			param = mxml.newnode(params,"param")
			mxml.setattr(param,"name","dial_string")
			mxml.setattr(param,"value","{sip_contact_user=${caller_id_number}}user/"..v.user.."@$${domain}")

			param = mxml.newnode(params,"param")
			mxml.setattr(param,"name","channel_name")
			mxml.setattr(param,"value","SIP Extension/"..(v.name or "unknown"))
				
			param = mxml.newnode(params,"param")
			mxml.setattr(param,"name","auth-profile")
			mxml.setattr(param,"value",v.profile or "")

			if v.from and "any" ~= v.from and v.ip then
				param = mxml.newnode(params,"param")
				mxml.setattr(param,"name","auth-acl")
				mxml.setattr(param,"value",netmask2num(v.ip))
			end

			if "Enabled" ~= v.status then
				param = mxml.newnode(params,"param")
				mxml.setattr(param,"name","sip-forbid-register")
				mxml.setattr(param,"value","on")
			else		
				--@ for feature_code service	
				local param = {}
				param.slot_type = "SIPP"
				param.number = v.user
				param.bridge_data = "{sip_contact_user=${ani}}user/"..v.user.."@${domain_name}"
				param.bridge_channel = "SIP Extension/"..(v.name or "unknown")

				if "blacklist" == v.callin_filter then
					param.callin_blacklist = v.callin_filter_blacklist
				elseif "whitelist" == v.callin_filter then
					param.callin_whitelist = v.callin_filter_whitelist
				end

			if "blacklist" == v.callout_filter then
				local tmp = {chan_name="sofia/user/"..v.user.."/",number=v.user,filter="blacklist",blacklist=v.callout_filter_blacklist}
				table.insert(ext_callout_chk_table,tmp)
			elseif "whitelist" == v.callout_filter then
				local tmp = {chan_name="sofia/user/"..v.user.."/",number=v.user,filter="whitelist",whitelist=v.callout_filter_whitelist}
				table.insert(ext_callout_chk_table,tmp)
			end

				generate_extension_xml(param)
				local_sip_fxs_dest = add_to_destnum_list(v.user,local_sip_fxs_dest)
			end

			if v.nat and "on" == v.nat then
				local variables = mxml.newnode(user,"variables")
				local variable = mxml.newnode(variables,"variable")
				mxml.setattr(variable,"name","sip-force-contact")
				mxml.setattr(variable,"value","NDLB-connectile-dysfunction")
			end

			if v.did and "" ~= v.did then
				DID_table[v.did] = v.user
			end
		end
	end
end

function set_default_extension_nouser()
	if fs.access(extension_call_01) then
		local root = mxml.parsefile(extension_call_01)
		if root then
			local condition_node = mxml.find(root,"include/extension/","condition","field","destination_number")
			mxml.setattr(condition_node,"expression","^NO USER$")
			mxml.savefile(root,extension_call_01)
			mxml.release(root)
		end
	end
end

function generate_00_extension_callout_blacklist_check_xml()
	if next(ext_callout_chk_table) then
		local xml = mxml:newxml()
		local include = mxml.newnode(xml,"include")

		for k,v in ipairs(ext_callout_chk_table) do
			local extension = mxml.newnode(include,"extension")
			if "blacklist" == v.filter then
				mxml.setattr(extension,"name",v.number.."_call_out_blacklist_check")
				add_condition(extension,"chan_name",v.chan_name)
				local condition = callout_number_condition(extension,v.blacklist)
				add_action(condition,"log","ERR Extension "..v.number.." can not call out ! (Blacklist Matched)")
				add_action(condition,"hangup","INVALID_NUMBER_FORMAT")
			else
				mxml.setattr(extension,"name",v.number.."_call_out_whitelist_check")
				mxml.setattr(extension,"continue","true")
				add_condition(extension,"chan_name",v.chan_name)
				local condition = callout_number_condition(extension,v.whitelist)
				add_anti_action(condition,"log","ERR Extension "..v.number.." can not call out ! (Whitelist Not Matched)")
				add_anti_action(condition,"hangup","INVALID_NUMBER_FORMAT")
			end
		end
		mxml.savefile(xml,extension_callout_check_00)
		mxml.release(xml)
	end
end

function generate_00_did_call_xml()
	local extension,condition,action

	if (not next(DID_table)) and (not ringgroup) then
		return
	end

	local xml = mxml:newxml()
	local include = mxml.newnode(xml,"include")

	-- DID
	if next(DID_table) then
		extension = mxml.newnode(include,"extension")
		mxml.setattr(extension,"name","DID")

		for k,v in pairs(DID_table) do
			local dest = string.gsub(k,"+","\\+")
			dest = string.gsub(dest,"*","\\*")
			condition = mxml.newnode(extension,"condition")
			mxml.setattr(condition,"field","destination_number")
			mxml.setattr(condition,"expression","^"..dest.."[*#]{0,1}$")
			mxml.setattr(condition,"break","on-true")

			action = mxml.newnode(condition,"action")
			mxml.setattr(action,"application","set")
			mxml.setattr(action,"data","my_dst_number=${destination_number}")

			action = mxml.newnode(condition,"action")
			mxml.setattr(action,"application","transfer")
			mxml.setattr(action,"data",v.." XML extension")
		end
	end
	-- DID end
	if ringgroup then
		for k,v in pairs(ringgroup) do
			if v.index and v.strategy and v.did and v.did ~= "" then
				if not extension then
					extension = mxml.newnode(include,"extension")
					mxml.setattr(extension,"name","DID")
				end
				local tmp_condition = mxml.newnode(extension,"condition")
				local dest = string.gsub(v.did,"+","\\+")
				dest = string.gsub(dest,"*","\\*")
				mxml.setattr(tmp_condition,"field","destination_number")
				mxml.setattr(tmp_condition,"expression","^"..dest.."[*#]{0,1}$")
				mxml.setattr(tmp_condition,"break","on-true")

				add_action(tmp_condition,"limit","hash RingGroup"..v.index.." RingGroup"..v.index.." 1/2 !USER_BUSY")
				add_action(tmp_condition,"lua","RingGroup-"..v.index..".lua "..v.strategy.." "..v.index.." "..(v.ringtime or "0"))
			end
		end
	end
	-- Ring Group End
	mxml.savefile(xml,did_call_00)
	mxml.release(xml)
end

function get_all_enabled_extension()
	local str

	for k,v in pairs(fxso_cfg) do
		if "0-FXS" == v.slot_type and "Enabled" == v.status then
			str = str and (str.."|^FreeTDM/1:1/") or "^FreeTDM/1:1/"
			break
		end
	end
	for k,v in pairs(sipphone_cfg) do
		if v.index and v.user and "Enabled" == v.status then
			str = str and (str.."|^sofia/user/"..v.user .."[/@]") or "^sofia/user/"..v.user.."[/@]"
		end
	end

	return str or "NONE"
end

function generate_local_ringgroup_dest()
	if ringgroup then
		for k, v in pairs(ringgroup) do
			if v.index and v.strategy and v.number and "" ~= v.number then
				local_ringgroup_dest = add_to_destnum_list(v.number, local_ringgroup_dest)
				generate_ringgroup_xml(v)
			end
		end
	end
end

function generate_ringgroup_xml(param)
	local xml = mxml:newxml()
	local include = mxml.newnode(xml, "include")

	local extension = mxml.newnode(include, "extension")
	mxml.setattr(extension, "name", param.number)

	local condition = mxml.newnode(extension, "condition")
	mxml.setattr(condition, "field", "destination_number")
	mxml.setattr(condition, "expression", "^" .. param.number .. "[*#]{0,1}$")
	if #param.members_select <= 8 then
		add_action(condition,"limit","hash ringgrp-max "..param.index.." "..#param.members_select.." !USER_BUSY")
	else
		local flag
		for k,v in pairs(param.members_select) do
			if v:match("FXS") then
				flag = true
				break
			end
		end
		if flag then
			add_action(condition,"limit","hash ringgrp-max "..param.index.." 9 !USER_BUSY")
		else
			add_action(condition,"limit","hash ringgrp-max "..param.index.." 8 !USER_BUSY")
		end
	end
	add_action(condition, "lua", "RingGroup-"..param.index..".lua")
	mxml.savefile(xml, pstn_extension_dir.."/"..param.number..".xml")
	mxml.release(xml)
end

function generate_00_extension_call_xml()
	local extension,condition,action

	-- extension call to fxs
	if local_sip_fxs_dest and "" ~= local_sip_fxs_dest then
		local xml = mxml:newxml()
		local include = mxml.newnode(xml,"include")

		extension = mxml.newnode(include,"extension")
		mxml.setattr(extension,"name","local_extension")

		condition = mxml.newnode(extension,"condition")
		mxml.setattr(condition,"field","chan_name")
		mxml.setattr(condition,"expression",get_all_enabled_extension())

		condition = mxml.newnode(extension,"condition")
		mxml.setattr(condition,"field","destination_number")
		if "" ~= local_ringgroup_dest then
			mxml.setattr(condition,"expression",local_sip_fxs_dest.. "|" ..local_ringgroup_dest)
		else
			mxml.setattr(condition,"expression",local_sip_fxs_dest)
		end
		mxml.setattr(condition,"break","on-true")

		action = mxml.newnode(condition,"action")
		mxml.setattr(action,"application","set")
		mxml.setattr(action,"data","my_dst_number=${destination_number}")
		
		action = mxml.newnode(condition,"action")
		mxml.setattr(action,"application","transfer")
		mxml.setattr(action,"data","${destination_number} XML extension")

		mxml.savefile(xml,extension_call_00)
		mxml.release(xml)
	end
	-- extension call to fxs end
end

--@ refresh 01_inbound_call.xml
function generate_01_extension_call_xml()
	if fs.access(extension_call_01) then
		local root = mxml.parsefile(extension_call_01)
		if root then
			local condition_node = mxml.find(root,"include/extension/","condition","field","destination_number")
			local tmp_str = ""
			if condition_node then
				for k,v in ipairs(default_dest_number_table) do
					if v ~= "" then
						if tmp_str == "" then
							tmp_str = v
						else
							tmp_str = tmp_str.."|"..v
						end
					end
				end
				if tmp_str == "" then
					mxml.setattr(condition_node,"expression","^NO USER$")
				else
					mxml.setattr(condition_node,"expression",tmp_str)
				end
			end
			mxml.savefile(root,extension_call_01)
			mxml.release(root)
		end
	end
end

-- function generate_z_98_default_autodial_xml()
--	local xml = mxml:newxml()
--	local include = mxml.newnode(xml,"include")
--	local extension = mxml.newnode(include,"extension")
--	mxml.setattr(extension,"name","Default_Autodial")
	
--	local dst_condition = mxml.newnode(extension,"condition")
--	mxml.setattr(dst_condition,"field","destination_number")
--	mxml.setattr(dst_condition,"expression","^IVRDIAL$")

--	local chan_name_tb = {}
--	local to_ivr_chan_tb = {}
	
--	for k,v in pairs(fxso_cfg) do
--		if v.index and v.status == "Enabled" and v.slot_type and v.slot_type:match("FXO") then
--			--table.insert(chan_name_tb,"^FreeTDM/"..v.index..":1")
--			table.insert(chan_name_tb,"^FreeTDM/"..v.index..":2")
--		end
--	end
--	for k,v in pairs(mobile_cfg) do
--		if v.index and v.status == "Enabled" and v.slot_type then
--			table.insert(chan_name_tb,"^gsmopen/"..v.slot_type)
--		end
--	end
--	for k,v in pairs(route_cfg) do
--		if v.index and v.successDestination and v.successDestination:match("^IVR") and v.from then
--			if v.from == "-1" and v.custom_from and type(v.custom_from) == "table" then
--				for k2,v2 in pairs(v.custom_from) do
--					if v2:match("^FXO") then
--						local slot,port = v2:match("FXO%-([0-9]+)%-([0-9]+)")
--						if slot and port then
--							table.insert(to_ivr_chan_tb,"^FreeTDM/"..slot..":"..port)
--						end
--					elseif v2:match("^GSM|^CDMA") then
--						local name,slot = v2:match("([A-Z]+)%-([0-9]+)") 
--						if name and slot then
--							table.insert(to_ivr_chan_tb,"^gsmopen/"..(tonumber(slot)-1).."-"..name)		
--						end
--					else
--					end
--				end
--			elseif v.from:match("^FXO") then
--				local slot = v.from:match("FXO%-([0-9]+)")
--				if slot and v.from_channel_number then
--					if v.from_channel_number == "1" then
--						table.insert(to_ivr_chan_tb,"^FreeTDM/"..slot..":1")
--					elseif v.from_channel_number == "2" then
--						table.insert(to_ivr_chan_tb,"^FreeTDM/"..slot..":2")
--					else
--						table.insert(to_ivr_chan_tb,"^FreeTDM/"..slot..":1")
--						table.insert(to_ivr_chan_tb,"^FreeTDM/"..slot..":2")
--					end
--				end
--			elseif v.from:match("^GSM|^CDMA") then
--				local name,slot = v.from:match("([A-Z]+)%-([0-9]+)")
--				if name and slot then
--					table.insert(to_ivr_chan_tb,"^gsmopen/"..(tonumber(slot)-1).."-"..name)
--				end
--			else
--			end
--		end
--	end
--	local chan_name_str = ""
--	for k,v in pairs(chan_name_tb) do
--		local tmp_flag = true
		
--		for k2,v2 in pairs(to_ivr_chan_tb) do
--			if v == v2 then
--				tmp_flag = false
--				break
--			end
--		end

--		if tmp_flag then
--			if chan_name_str == "" then
--				chan_name_str = v
--			else
--				chan_name_str = chan_name_str.."|"..v
--			end
--		end
--	end

--	if chan_name_str ~= "" then
--		local chan_condition = mxml.newnode(extension,"condition")
--		mxml.setattr(chan_condition,"field","chan_name")
--		mxml.setattr(chan_condition,"expression",chan_name_str)

--		add_action(chan_condition,"lua","autodial.lua")
--		add_action(chan_condition,"transfer","${destination_number} XML public")

--		mxml.savefile(xml,autodial_call_z98)
--	end

--	mxml.release(xml)
-- end
function add_fax_param(parent_node,sip_app,pstn_app)
	local a = mxml.newnode(parent_node,"action")
	mxml.setattr(a,"application",pstn_app)
	mxml.setattr(a,"data","execute_on_fax_end=myfax_fax_stop")

	a = mxml.newnode(parent_node,"action")
	mxml.setattr(a,"application",pstn_app)
	mxml.setattr(a,"data","execute_on_fax_detect=myfax_fax_start request peer")

	a = mxml.newnode(parent_node,"action")
	mxml.setattr(a,"application",sip_app)
	mxml.setattr(a,"data","fax_enable_t30_request=true")

	a = mxml.newnode(parent_node,"action")
	mxml.setattr(a,"application",sip_app)
	mxml.setattr(a,"data","sip_execute_on_t30=myfax_fax_start t30 self")

	a = mxml.newnode(parent_node,"action")
	mxml.setattr(a,"application",sip_app)
	mxml.setattr(a,"data","fax_enable_t38_request=true")

	a = mxml.newnode(parent_node,"action")
	mxml.setattr(a,"application",sip_app)
	mxml.setattr(a,"data","sip_execute_on_image=myfax_fax_start t38 self")
end

function generate_r99_extension_call_xml()
	local extension,condition,action
	local xml = mxml:newxml()
	local include = mxml.newnode(xml,"include")

	for k,v in pairs(local_port_reg_dest_to_sipsrv_tbl) do
		if v.master or v.slave then
			extension = mxml.newnode(include,"extension")
			mxml.setattr(extension,"name","port_reg_call_out_"..k)

			condition = mxml.newnode(extension,"condition")
			mxml.setattr(condition,"field","chan_name")
			mxml.setattr(condition,"expression",v.from)
			mxml.setattr(condition,"break","on-true")

			action = mxml.newnode(condition,"action")
			mxml.setattr(action,"application","set")
			mxml.setattr(action,"data","continue_on_fail=GATEWAY_DOWN,NORMAL_TEMPORARY_FAILURE,UNALLOCATED_NUMBER")
			
			action = mxml.newnode(condition,"action")
			mxml.setattr(action,"application","set")
			mxml.setattr(action,"data","hangup_after_bridge=true")

			--action = mxml.newnode(condition,"action")
			--mxml.setattr(action,"application","set")
			--mxml.setattr(action,"data","effective_caller_id_number="..k)

			add_fax_param(condition,"export","set")
		end

		if v.master and #v.master > 0 and codec[v.master:match("^(%d+)")] then
			action = mxml.newnode(condition,"action")
			mxml.setattr(action,"application","set")
			mxml.setattr(action,"data","dest_chan_name="..v.name1)

			action = mxml.newnode(condition,"action")
			mxml.setattr(action,"application","lua")
			mxml.setattr(action,"data","check_destination_number.lua")

			action = mxml.newnode(condition,"action")
			mxml.setattr(action,"application","bridge")
			mxml.setattr(action,"data","{^^#absolute_codec_string="..codec[v.master:match("^(%d+)")].."}sofia/gateway/"..v.master.."/${destination_number}")
		end
		
		if v.slave and #v.slave > 0 and codec[v.slave:match("^(%d+)")] then
			action = mxml.newnode(condition,"action")
			mxml.setattr(action,"application","set")
			mxml.setattr(action,"data","dest_chan_name="..v.name2)

			action = mxml.newnode(condition,"action")
			mxml.setattr(action,"application","lua")
			mxml.setattr(action,"data","check_destination_number.lua")

			action = mxml.newnode(condition,"action")
			mxml.setattr(action,"application","bridge")
			mxml.setattr(action,"data","{^^#absolute_codec_string="..codec[v.slave:match("^(%d+)")].."}sofia/gateway/"..v.slave.."/${destination_number}")
		end
	end

	for k,v in pairs(local_port_reg_dest_to_sipsrv_tbl) do
		if v.master or v.slave then
			extension = mxml.newnode(include,"extension")
			mxml.setattr(extension,"name","port_reg_call_in_"..k)

			condition = mxml.newnode(extension,"condition")
			mxml.setattr(condition,"field","chan_name")
			if v.master and v.slave then
				mxml.setattr(condition,"expression","^sofia/gateway/"..v.master.."|^sofia/gateway/"..v.slave)
			elseif v.master then
				mxml.setattr(condition,"expression","^sofia/gateway/"..v.master)
			elseif v.slave then
				mxml.setattr(condition,"expression","^sofia/gateway/"..v.slave)
			end

			action = mxml.newnode(condition,"action")
			mxml.setattr(action,"application","set")
			mxml.setattr(action,"data","my_dst_number=${destination_number}")

			action = mxml.newnode(condition,"action")
			mxml.setattr(action,"application","set")
			mxml.setattr(action,"data","my_flag_from_sip_reg=true")
			
			action = mxml.newnode(condition,"action")
			mxml.setattr(action,"application","transfer")
			mxml.setattr(action,"data",k.." XML extension")
		end
	end
	mxml.savefile(xml,extension_call_z99)
	mxml.release(xml)
end
--@ init for 01_inbound_call.xml
for i=1,12 do
	local tmp_str = "^"..tostring(8000 + (i - 1)*2).."$|^"..tostring(8001 + (i - 1)*2).."$"
	table.insert(default_dest_number_table,tmp_str)
end

generate_pstn_extension_data()
generate_sip_extension_data()
mxml.savefile(users_root,extension_users_xml)
mxml.release(users_root)

generate_00_extension_callout_blacklist_check_xml()
generate_00_did_call_xml()
generate_r99_extension_call_xml()
--generate_z_98_default_autodial_xml()

if "0" == callcontrol_cfg.localcall then
	set_default_extension_nouser()
	return
end

generate_local_ringgroup_dest()

generate_00_extension_call_xml()
generate_01_extension_call_xml()
