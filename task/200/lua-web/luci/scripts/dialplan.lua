require "mxml"
require "uci"
require "luci.util"
local fs = require "nixio.fs"

local cfgfilelist = {"system","route","profile_codec","profile_time","profile_number","profile_manipl","profile_sip","endpoint_fxso","endpoint_siptrunk","endpoint_sipphone","endpoint_ringgroup","endpoint_routegroup","endpoint_mobile","ivr"}
for k,v in ipairs(cfgfilelist) do
	os.execute("cp /etc/config/"..v.." /tmp/config")
end
local uci = uci.cursor("/tmp/config","/tmp/state")
local interface = uci:get("system","main","interface") or ""
local route_cfg = uci:get_all("route") or {}
local time_profile_cfg = uci:get_all("profile_time") or {}
local number_profile_cfg = uci:get_all("profile_number") or {}
local number_manipulation_cfg = uci:get_all("profile_manipl") or {}
local sip_profile = uci:get_all("profile_sip") or {}
local sip_trunk = uci:get_all("endpoint_siptrunk") or {}
local sip_extension = uci:get_all("endpoint_sipphone") or {}
local fxso_endpoint = uci:get_all("endpoint_fxso") or {}
local mobile_endpoint = uci:get_all("endpoint_mobile") or {}
local ringgroup = uci:get_all("endpoint_ringgroup") or {}
local routegroup = uci:get_all("endpoint_routegroup") or {}
local ivr = uci:get_all("ivr") or {}

local pairs = pairs
local tostring = tostring
local condition = {}
local condition_flag
local action = {}
local action_flag
local g_current_extension
local group_bridge_exp = ""
local conf_dir = "/etc/freeswitch/conf/dialplan/public"
local scripts_dir = "/etc/freeswitch/scripts"
local fail_xml_dir = "/etc/freeswitch/conf/dialplan/failroute"
local sip_param_scripts = "/usr/lib/lua/luci/scripts/set_sip_param.lua"
local chan_name_uci_cfg_scripts = "/etc/freeswitch/scripts/set_chan_name_by_uci_cfg.lua"

function sip_code_to_cause_string(cause_str)
	local cause_tbl = { ["200"] = "NORMAL_CLEARING",
						["400"] = "NORMAL_TEMPORARY_FAILURE",
						["401"] = "CALL_REJECTED",
						["402"] = "CALL_REJECTED",
						["403"] = "CALL_REJECTED",
						["404"] = "UNALLOCATED_NUMBER,NO_ROUTE_DESTINATION",
						["405"] = "SERVICE_UNAVAILABLE",
						["406"] = "SERVICE_NOT_IMPLEMENTED",
						["407"] = "CALL_REJECTED",
						["408"] = "RECOVERY_ON_TIMER_EXPIRE",
						["410"] = "NUMBER_CHANGED",
						["413"] = "INTERWORKING",
						["414"] = "INTERWORKING",
						["415"] = "SERVICE_NOT_IMPLEMENTED",
						["416"] = "INTERWORKING",
						["420"] = "INTERWORKING",
						["421"] = "INTERWORKING",
						["423"] = "INTERWORKING",
						["480"] = "NO_USER_RESPONSE",
						["481"] = "NORMAL_TEMPORARY_FAILURE",
						["482"] = "EXCHANGE_ROUTING_ERROR",
						["483"] = "EXCHANGE_ROUTING_ERROR",
						["484"] = "INVALID_NUMBER_FORMAT",
						["485"] = "NO_ROUTE_DESTINATION",
						["486"] = "USER_BUSY",
						["487"] = "SWITCH_CAUSE_ORIGINATOR_CANCEL",
						["488"] = "INCOMPATIBLE_DESTINATION",
						["500"] = "NORMAL_TEMPORARY_FAILURE",
						["501"] = "SERVICE_NOT_IMPLEMENTED",
						["502"] = "NETWORK_OUT_OF_ORDER",
						["503"] = "NORMAL_TEMPORARY_FAILURE",
						["504"] = "RECOVERY_ON_TIMER_EXPIRE",
						["505"] = "INTERWORKING",
						["513"] = "INTERWORKING",
						["600"] = "USER_BUSY",
						["603"] = "CALL_REJECTED",
						["604"] = "NO_ROUTE_DESTINATION",
						["606"] = "INCOMPATIBLE_DESTINATION",
						}

	local str = cause_str
	local cause = luci.util.split(cause_str,",")

	for k,v in ipairs(cause) do
		if cause_tbl[v] then
			str = string.gsub(str,v,cause_tbl[v])
		end
	end

	return str
end

function get_codec_string()
	local codec_string_by_profile = {}
	local codec_string_by_trunk = {}
	local codec = uci:get_all("profile_codec") or {}
	local sip_profile = uci:get_all("profile_sip") or {}
	local sip_trunk = uci:get_all("endpoint_siptrunk") or {}

	for k,v in pairs(sip_profile) do
		for i,j in pairs(codec) do
			if v.index and v.outbound_codec_prefs and j.index and v.outbound_codec_prefs == j.index and j.code then
				codec_string_by_profile[v.index] = table.concat(j.code,",")
			end
		end
	end

	for k,v in pairs(sip_trunk) do
		if v.index and v.profile then
			codec_string_by_trunk[v.index] = codec_string_by_profile[v.profile] or ""
		end
	end

	return codec_string_by_trunk,codec_string_by_profile
end

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

--@ ADD a XML condition tag to parent_node
function add_condition(parent_node,field,expression)
	condition_flag = condition_flag + 1
	condition[condition_flag] = mxml.newnode(parent_node,"condition")
	if field == "wday" or field == "time-of-day" or field == "date-time" then
		mxml.setattr(condition[condition_flag],field,expression)
	elseif field and expression then
		mxml.setattr(condition[condition_flag],"field",field)
		mxml.setattr(condition[condition_flag],"expression",expression)
	end
end

--@ for failed extension ,add normal action to parent_node
function add_failed_action(parent_node,app,data)
	if parent_node and app then
		local action = mxml.newnode(parent_node,"action")
		mxml.setattr(action,"application",app)
		if data then
			mxml.setattr(action,"data",data)
		end
	end
end

--@ ADD a XML action tag to parent_node
function add_action(parent_node,app,data)
	if not parent_node then
		condition_flag = condition_flag + 1
		condition[condition_flag] = mxml.newnode(g_current_extension,"condition")
		parent_node = condition[condition_flag]
	end
	action_flag = action_flag + 1
	action[action_flag] = mxml.newnode(parent_node,"action")
	mxml.setattr(action[action_flag],"application",app)
	if data then
		mxml.setattr(action[action_flag],"data",data)
	end
end

--@ set fail action 
function add_fail_action_settings(parent_node,fail_condition,time_out,cause_code)
	--@ failed action settings
	if fail_condition ~= "" or cause_code ~= "" then
		if not parent_node then
			condition_flag = condition_flag + 1
			condition[condition_flag] = mxml.newnode(g_current_extension,"condition")
			parent_node = condition[condition_flag]
		end
		
		local exp = ""
		if string.find(fail_condition,"Busy") then
			exp = exp.."USER_BUSY,NO_USER_RESPONSE,NO_ANSWER"
		end
		if string.find(fail_condition,"Timeout") then
			exp = add_to_list(exp,"TIMEOUT,NO_ANSWER,NO_USER_RESPONSE,ALLOTTED_TIMEOUT",",")
			if time_out ~= "" then
				add_action(parent_node,"set","call_timeout="..time_out)
				add_action(parent_node,"set","bridge_answer_timeout="..time_out)
				add_action(parent_node,"export","progress_timeout="..time_out)
				add_action(parent_node,"export","originate_timeout="..time_out)
			end
		end
		if string.find(fail_condition,"Unavailable") then
			exp = add_to_list(exp,"USER_NOT_REGISTERED,NORMAL_CIRCUIT_CONGESTION,GATEWAY_DOWN,SWITCH_CONGESTION,NO_USER_RESPONSE,REQUESTED_CHAN_UNAVAIL,NORMAL_TEMPORARY_FAILURE",",")
		end
		if string.find(fail_condition,"NoAnswer") then
			exp = add_to_list(exp,"NO_ANSWER,NO_USER_RESPONSE,ALLOTTED_TIMEOUT",",")
		end
		if cause_code ~= "" then
			cause_code = string.gsub(cause_code," ",",")
			cause_code = string.gsub(cause_code,"|",",")
			exp = add_to_list(exp,cause_code,",")
		end

		if "" ~= exp then
			exp = sip_code_to_cause_string(exp)
			add_action(parent_node,"set","continue_on_fail="..exp)
		end		
	end
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
		add_condition(parent_node,field,string_val_parse(value))
	elseif value and "table" == type(value) then
		local result_str
		for k,v in ipairs(value) do
			if "" ~= v then
				result_str=(result_str and (result_str.."|") or "")..string_val_parse(v)
			end
		end
		add_condition(parent_node,field,result_str)
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
function number_condition(parent_node,value)
	for k,v in pairs(number_profile_cfg) do
		if v.index == value then
			--@ caller
			--@ callerlength
			if v.callerlength then
				add_condition(parent_node,"caller_id_number",number_length_parse(v.callerlength))
			end
			--@ caller prefix
			if v.caller then
				number_regular_parse(parent_node,"caller_id_number",v.caller)
			end

			--@ called
			--@ calledlength
			if v.calledlength then
				add_condition(parent_node,"destination_number",number_length_parse(v.calledlength))
			end
			--@ called prefix
			if v.called then
				number_regular_parse(parent_node,"destination_number",v.called)
			end
			break
		end
	end
end

function time_condition(parent_node,value)
	for k,v in pairs(time_profile_cfg) do
		if v.index == value then
			--@ <condition regex="all|any|xor" >
			--@		<regex date-time="" >
			--@       <regex time-of-day="" >
			--@ </condition>
			--@ date-time
			if v.date_options then
				local start_date
				local end_date
				local condition_regex = mxml.newnode(parent_node,"condition")
				mxml.setattr(condition_regex,"regex","any")

				if type(v.date_options) == "table" then
					for _,v2 in ipairs(v.date_options) do
						if v2 ~= "" then
							local _regex = mxml.newnode(condition_regex,"regex")
							start_date,end_date = v2:match("([0-9%-]+)~([0-9%-]+)")
							
							start_date = start_date.." 00:00"
							end_date = end_date.." 24:00"
							
							mxml.setattr(_regex,"date-time",start_date.."~"..end_date)
						end
					end
				else
					local _regex = mxml.newnode(condition_regex,"regex")
					start_date,end_date = v.date_options:match("([0-9%-]+)~([0-9%-]+)")
					
					start_date = start_date.." 00:00"
					end_date = end_date.." 24:00"
					
					mxml.setattr(_regex,"date-time",start_date.."~"..end_date)
				end
			end

			--@ time-of-day
			if v.time_options then
				local condition_regex = mxml.newnode(parent_node,"condition")
				mxml.setattr(condition_regex,"regex","any")

				if type(v.time_options) == "table" then
					for _,v2 in pairs(v.time_options) do
						if v2 ~= "" then
							local _regex = mxml.newnode(condition_regex,"regex")
							mxml.setattr(_regex,"time-of-day",string.gsub(v2,"~","-"))
						end
					end	
				else
					local _regex = mxml.newnode(condition_regex,"regex")
					mxml.setattr(_regex,"time-of-day",string.gsub(v.time_options,"~","-"))
				end
			end
			
			--@ wday
			if v.weekday then
				local exp
				for w in string.gmatch(v.weekday,"%a+") do
					exp = exp and (exp..","..string.lower(w)) or (string.lower(w))
				end
				add_condition(parent_node,"wday",exp)
			end
		end
	end
end

function number_manipulation_action(parent_node,value)
	if not parent_node then
		condition_flag = condition_flag + 1
		condition[condition_flag] = mxml.newnode(g_current_extension,"condition")
		parent_node = condition[condition_flag]
	end
	for k,v in pairs(number_manipulation_cfg) do
		if v.index == value then
			local exp = ""
			--@ caller number change
			exp = "number_manipulation.lua".." 0 ".."${caller_id_number} "..(v.CallerDelPrefix or "nil").." "..(v.CallerDelSuffix or "nil").." "..(v.CallerAddPrefix or "nil").." "..(v.CallerAddSuffix or "nil").." "..(v.CallerReplace or "nil")
			add_action(parent_node,"lua",exp)

			--@ called number change
			exp = "number_manipulation.lua".." 1 ".."${destination_number} "..(v.CalledDelPrefix or "nil").." "..(v.CalledDelSuffix or "nil").." "..(v.CalledAddPrefix or "nil").." "..(v.CalledAddSuffix or "nil").." "..(v.CalledReplace or "nil")
			add_action(parent_node,"lua",exp)
			break
		end
	end
end

--@ rm the old xml
if fs.access(conf_dir) then
	os.execute("rm "..conf_dir.."/r_*.xml")
else
	os.execute("mkdir /etc/freeswitch/conf/dialplan/public")
end

if fs.access(fail_xml_dir) then
	os.execute("rm "..fail_xml_dir.."/Fail-*.xml")
else
	os.execute("mkdir "..fail_xml_dir)
end

function get_profile_progress_time()
	local profile_progress_time = {}
	for k,v in pairs(uci:get_all("profile_sip") or {}) do
		if v.index then
			profile_progress_time[v.index] = v.progress_timeout or 55
		end
	end
	return profile_progress_time
end

function get_sip_trunk_param_list()
	local list_index = {}
	local list_name = {}
	local list_progress_time = {}
	
	local trunk = uci:get_all("endpoint_siptrunk") or {}
	local profile_progress_time = get_profile_progress_time()
	for k,v in pairs(trunk) do
		if v.index and v.profile and "Enabled" == v.status and v.name then
			list_index[v.index] = v.profile.."_"..v.index
			list_name[v.index] = v.name
			list_progress_time[v.index] = profile_progress_time[v.profile] or 55
		end
	end

	return list_index,list_name,list_progress_time
end

function set_endpoint_param_scripts()
	local profile_interface = {}
	local profile_bypass_media = {}
	local endpoint_interface = ""
	local codec = ""
	local endpoint_list = ""
	local reg_info = ""
	local bypass_media = ""

	local codec_by_siptrunk,codec_by_profile = get_codec_string()

	for k,v in pairs(sip_profile) do
		if v.index and v.localinterface then
			profile_interface[v.index] = v.localinterface
			if v.bypass_media and "on" == v.bypass_media then
				profile_bypass_media[v.index] = "on"
			end
		end
	end

	for k,v in pairs(sip_extension) do
		if v.user and v.profile and v.name then
			endpoint_list = endpoint_list .. "[\""..v.user.."\"]=\""..(v.name or "").."\","
			endpoint_interface = endpoint_interface .. "[\""..v.user.."\"]=\""..(profile_interface[v.profile] or "").."\","
			codec = codec .. "[\""..v.user.."\"]=\""..(codec_by_profile[v.profile] or "").."\","
			if profile_bypass_media[v.profile] then
				bypass_media = bypass_media .. "[\""..v.user.."\"]=\"on\","
			end
		end
	end

	for k,v in pairs(sip_trunk) do
		if v.index and v.profile and v.name then
			endpoint_list = endpoint_list .. "[\""..v.profile.."_"..v.index.."\"]=\""..(v.name or "").."\","
			endpoint_interface = endpoint_interface .. "[\""..v.profile.."_"..v.index.."\"]=\""..(profile_interface[v.profile] or "").."\","
			codec = codec .. "[\""..v.profile.."_"..v.index.."\"]=\""..(codec_by_siptrunk[v.index] or "").."\","
			if v.register and "on" == v.register then
				local reg_info_tmp="[\"reg\"]=\"on\","
				if "caller" == v.from_username then
					reg_info_tmp=reg_info_tmp.."[\"from_username\"]=\"caller\""
				else
					reg_info_tmp=reg_info_tmp.."[\"from_username\"]=\""..(v.username or "unknown").."\","
				end
				reg_info = reg_info .. "[\""..v.profile.."_"..v.index.."\"]={"..reg_info_tmp.."},"
			end
			if profile_bypass_media[v.profile] then
				bypass_media = bypass_media .. "[\""..v.profile.."_"..v.index.."\"]=\"on\","
			end
		end
	end

	if interface and interface:match("2[SsOo]") then
		for k,v in pairs(fxso_endpoint) do
			if "fxs" == v[".type"] and interface:match("2S") and v.number_1 and v.number_2 then
				endpoint_list = endpoint_list .. "[\"FreeTDM\\/1:1\"]=\"FXS Extension\\/"..v.number_1.."\","
				endpoint_list = endpoint_list .. "[\"FreeTDM\\/1:2\"]=\"FXS Extension\\/"..v.number_2.."\","
			elseif "fxo" == v[".type"] and interface:match("2O") and v.index then
				endpoint_list = endpoint_list .. "[\"FreeTDM\\/1:1\"]=\"FXO Trunk\\/Port 0\","
				endpoint_list = endpoint_list .. "[\"FreeTDM\\/1:2\"]=\"FXO Trunk\\/Port 1\","
			end
		end
	else
		endpoint_list = endpoint_list .. "[\"FreeTDM\\/1:1\"]=\"FXS Extension\","
		endpoint_list = endpoint_list .. "[\"FreeTDM\\/1:2\"]=\"FXO Trunk\","
	end
	os.execute("sed -i 's/^local endpoint_interface = {.*}/local endpoint_interface = {"..endpoint_interface.."}/g' "..sip_param_scripts)
	os.execute("sed -i 's/^local codec_list = {.*}/local codec_list = {"..codec.."}/g' "..sip_param_scripts)
	os.execute("sed -i 's/^local reg_info = {.*}/local reg_info = {"..reg_info.."}/g' "..sip_param_scripts)
	os.execute("sed -i 's/^local bypass_media = {.*}/local bypass_media = {"..bypass_media.."}/g' "..sip_param_scripts)
	os.execute("cp "..sip_param_scripts.." "..scripts_dir)

	os.execute("sed -i 's/^local endpoint_list = {.*}/local endpoint_list = {"..endpoint_list.."}/g' "..chan_name_uci_cfg_scripts)
end

function add_to_list(list,str,symbol)
	if "" == list or (not list) then
		return str
	else
		return list..symbol..str
	end
end

set_endpoint_param_scripts()

local sip_trunk_list,sip_trunk_name,sip_trunk_progress_time = get_sip_trunk_param_list()
local codec_list = get_codec_string()

function get_all_enabled_endpoint(include_siptrunk_flag)
	local str

	if interface and interface:match("[SO]") then
		for k,v in pairs(fxso_endpoint) do
			if "0-FXS" == v.slot_type and interface:match("S") and "Enabled" == v.status then
				str = str and (str.."|^FreeTDM/1:1/") or "^FreeTDM/1:1/"
				if interface:match("2S") then
					str = str.."|^FreeTDM/1:2/"
				end
			elseif "0-FXO" == v.slot_type and interface:match("O") and "Enabled" == v.status then
				str = str and (str.."|^FreeTDM/1:2/") or "^FreeTDM/1:2/"
				if interface:match("2O") then
					str = str.."|^FreeTDM/1:1/"
				end
			end
		end
	end
	if interface and (interface:match("G") or interface:match("V")) then
		for k,v in pairs(mobile_endpoint) do
			if "1-GSM" == v.slot_type and "Enabled" == v.status then
				str = str and (str.."|^gsmopen/1-GSM") or "^gsmopen/1-GSM"
			elseif "1-VOLTE" == v.slot_type and "Enabled" == v.status then
				str = str and (str.."|^gsmopen/1-VOLTE") or "^gsmopen/1-VOLTE"
			end
		end
	end
	if include_siptrunk_flag then
		for k,v in pairs(sip_trunk) do
			if v.index and v.profile and "Enabled" == v.status then
				local t = "^sofia/gateway/"..sip_trunk_list[v.index].."/|^sofia/gateway/"..sip_trunk_list[v.index].."-"
				str = str and (str.."|"..t) or t
			end
		end
	end
	for k,v in pairs(sip_extension) do
		if v.index and v.user and "Enabled" == v.status then
			str = str and (str.."|^sofia/user/"..v.user .."[/@]") or "^sofia/user/"..v.user.."[/@]"
		end
	end
	for k,v in pairs(sip_profile) do
		if v.index and "on" == v.allow_unknown_call then
			str = str and (str.."|^sofia/unknown/"..v.index.."/")
		end
	end

	return str or "NONE"
end

--@ Here is begining of parse dialplan
--@ get section by route_cfg file,the result is in v
--@ Create dialplan xml file from route one by one
--@ VERSION 1.0.0.1 dialplan
--@ TIME 2014-08-14
--@ VERSION 1.0.1.0 dialplan
--@ TIME 2015-06-11 lamont

local all_valid_src=get_all_enabled_endpoint(true)

for k,v in pairs(route_cfg) do
	if v.index and v.name then
		local xml = mxml:newxml()
		local is_to_fxso = false--for two ports are selected
		local continue_on_fail_set_flag = false
		local include = mxml.newnode(xml,"include")
		
		local extension = mxml.newnode(include,"extension")
		g_current_extension = extension
		mxml.setattr(extension,"name",(tonumber(v.index) < 10 and "0"..v.index or v.index))


		--@ init table condition and table action
		if condition[1] then
			for i=1,#condition do
				table.remove(condition,i)
			end
		end
		condition_flag = 0
		if action[1] then
			for i=1,#action do
				table.remove(action,i)
			end
		end
		action_flag = 0

		add_condition(extension,"${last_matched_route}","^(?!"..(tonumber(v.index) < 10 and "0"..v.index or v.index)..")")

	--@ ADD CONDITION
	--@ Begin to parse condition
		--@ set number condition
		if not v.numberProfile or "0" == v.numberProfile then
			number_regular_parse(extension,"caller_id_number",v.caller_num_prefix)
			number_regular_parse(extension,"destination_number",v.called_num_prefix)
		else
			number_condition(extension,v.numberProfile)
		end
		--@ set time condition
		if v.timeProfile and v.timeProfile ~= "0" then
			time_condition(extension,v.timeProfile)
		end
		--@ set call from condition
		if v.from and v.from ~= "0" and v.from ~= "-1" then
			--@ from SIP Trunk
			if v.from:match("^SIPT") then
				local idx = v.from:match("^SIPT%-(%d+)")
				if string.find(all_valid_src,"sofia/gateway/"..(sip_trunk_list[idx] or "").."/") then
					add_condition(extension,"chan_name","^sofia/gateway/"..(sip_trunk_list[idx] or "").."/|^sofia/gateway/"..(sip_trunk_list[idx] or "").."-")
				else
					add_condition(extension,"chan_name","sofia/gateway/"..(sip_trunk_list[idx] or "").." Disabled")
				end
			--@ END}
			elseif v.from:match("^SIPP") then
				local index = v.from:match("^SIPP%-(%d+)")
				for _,v2 in pairs(sip_extension) do
					if v2.index == index then
						if "Enabled" == v2.status then
							add_condition(extension,"chan_name","^sofia/user/"..v2.user.."[/@]")
						else
							add_condition(extension,"chan_name","sofia/user/"..v2.user.." Disabled")
						end
						break
					end
				end
			--@ from FXSO endpoint
			elseif v.from:match("^[FXS|FXO]+%-%d+%-%d+$") then
				local endpoint_type,slot,port=v.from:match("^([FXS|FXO]+)%-(%d+)%-(%d+)")
				--@ special for u200	
				if endpoint_type == "FXS" and interface:match("S") then
					if port == "1" and string.find(all_valid_src,"FreeTDM/1:1/") then
						add_condition(extension,"chan_name","^FreeTDM/1:1/")
					elseif port == "2" and interface:match("2S") and string.find(all_valid_src,"FreeTDM/1:2/") then
						add_condition(extension,"chan_name","^FreeTDM/1:2/")
					else
						add_condition(extension,"chan_name",v.from.." (FXS Port) Disabled")
					end
				elseif endpoint_type == "FXO" and interface:match("O") then
					if port == "2" and interface:match("O") and string.find(all_valid_src,"FreeTDM/1:2/") then
						add_condition(extension,"chan_name","^FreeTDM/1:2/")
					elseif port == "1" and interface:match("2O") and string.find(all_valid_src,"FreeTDM/1:2/") then
						add_condition(extension,"chan_name","^FreeTDM/1:1/")
					else
						add_condition(extension,"chan_name",v.from.." (FXO Port) Disabled")
					end
				end
			--@ from Mobile endpoint
			elseif v.from:match("^[GSM|CDMA|VOLTE]+%-%d+$") then
				local tmp_idx = v.from:match("^[GSM|CDMA|VOLTE]+%-(%d+)$")
				for k2,v2 in pairs(mobile_endpoint) do
					if v2.index == tmp_idx then
						if "Enabled" == v2.status then
							add_condition(extension,"chan_name","^gsmopen/"..v2.slot_type)
						else
							add_condition(extension,"chan_name","gsmopen/"..v2.slot_type.." Disabled")
						end
						break
					end
				end
			end
		--@ Custom source condition
		elseif v.from == "-1" then
			if v.custom_from and "table" == type(v.custom_from) then
				local from_sip_trunk
				local from_non_sip_trunk

				for k2,v2 in pairs(v.custom_from) do
					if v2:match("^FXS") and interface:match("S") then
						local slot,port=v2:match("(%d+)%-(%d+)")
						if port == "1" and string.find(all_valid_src,"FreeTDM/1:1/") then
							from_non_sip_trunk = add_to_list(from_non_sip_trunk,"^FreeTDM/1:1","|")
						elseif port == "2" and interface:match("2S") and string.find(all_valid_src,"FreeTDM/1:2/") then
							from_non_sip_trunk = add_to_list(from_non_sip_trunk,"^FreeTDM/1:2","|")
						end
					elseif v2:match("^FXO") and interface:match("O") then
						local slot,port=v2:match("(%d+)%-(%d+)")
						if port == "1" and interface:match("2O") and string.find(all_valid_src,"FreeTDM/1:1/") then
							from_non_sip_trunk = add_to_list(from_non_sip_trunk,"^FreeTDM/1:1","|")
						elseif port == "2" and string.find(all_valid_src,"FreeTDM/1:2/") then
							from_non_sip_trunk = add_to_list(from_non_sip_trunk,"^FreeTDM/1:2","|")
						end
					elseif v2:match("^GSM") or v2:match("^CDMA") or v2:match("^VOLTE") then
						local tmp_idx = v2:match("^[GSM|CDMA|VOLTE]+%-(%d+)$")
						for k3,v3 in pairs(mobile_endpoint) do
							if v3.index == tmp_idx and v3.slot_type and "Enabled" == v3.status then
								from_non_sip_trunk = add_to_list(from_non_sip_trunk,"^gsmopen/"..v3.slot_type,"|")
								break
							end
						end
					elseif v2:match("^SIPP") then
						local tmp_idx = v2:match("^SIPP%-(%d+)")
						
						for _,v3 in pairs(sip_extension) do
							if v3.index == tmp_idx and v3.user and "Enabled" == v3.status then
								from_non_sip_trunk = add_to_list(from_non_sip_trunk,"^sofia/user/"..v3.user.."[/@]","|")
								break
							end
						end
					elseif v2:match("^SIPT") then
						local tmp_idx = v2:match("^SIPT%-(%d+)")
						if string.find(all_valid_src,"sofia/gateway/"..(sip_trunk_list[tmp_idx] or "").."/") then
							from_sip_trunk = add_to_list(from_sip_trunk,"^sofia/gateway/"..(sip_trunk_list[tmp_idx] or "").."/|^sofia/gateway/"..(sip_trunk_list[tmp_idx] or "").."-","|")
						end
					end
				end
				if v.successDestination and v.successDestination:match("^SIPT") then
					if from_non_sip_trunk then
						add_condition(extension,"chan_name",from_non_sip_trunk)
						if from_non_sip_trunk:match("sofia/user/") then
							local idx = v.successDestination:match("^SIPT%-(%d+)$")
							add_action(condition[condition_flag],"lua","set_sip_param.lua ".."sofia/gateway/"..(sip_trunk_list[idx] or "unknown").."/${destination_number}")
						end
					else
						add_condition(extension,"chan_name","NO VALID SOURCE") -- forbidden call from siptrunk to siptrunk
					end
				else
					if from_sip_trunk and from_non_sip_trunk then
						add_condition(extension,"chan_name",from_sip_trunk.."|"..from_non_sip_trunk)
					else
						add_condition(extension,"chan_name",from_sip_trunk or from_non_sip_trunk)
					end
				end
			end
		elseif v.from == "0" then
			if v.successDestination and v.successDestination:match("^SIPT%-") then
				add_condition(extension,"chan_name",get_all_enabled_endpoint(false)) -- forbidden call from siptrunk to siptrunk
			else
				add_condition(extension,"chan_name",all_valid_src)
			end
		end	
	--@ END ADD CONDITION
	--@ END CONDITION

	--@ Begin to parse actions
	--@ ADD ACTION
	--@{ Failed bridge actions
		add_fail_action_settings(condition[condition_flag],v.failCondition or "",v.timeout or "",v.causecode or "")

		if v.failDestination then
			add_action(condition[condition_flag],"set","hangup_after_bridge=true")
			add_action(condition[condition_flag],"set","transfer_name_on_fail=".."FAIL-"..(tonumber(v.index) < 10 and ("0"..v.index) or v.index))--@ set failed continue transfer name "FAIL-"..index
		end
	--@ End}

	--@ { START:Success bridge action
		if v.successDestination then
			--@ set successdst number manipulation action
			add_action(condition[condition_flag],"set","last_matched_route="..(tonumber(v.index) < 10 and "0"..v.index or v.index))
			add_action(condition[condition_flag],"set","my_dst_number=${destination_number}")
			if v.successNumberManipulation and "0" ~= v.successnumberManipulation then
				number_manipulation_action(condition[condition_flag],v.successNumberManipulation)
			end
			if not v.successDestination:match("^IVR") and not v.successDestination:match("^SIPP") and not v.successDestination:match("^FXS") and not v.successDestination:match("^RING") then
				add_action(condition[condition_flag],"lua","check_destination_number.lua")
			end

			--@ to SIP Trunk
			if v.successDestination:match("^SIPT%-%d+$") then
				local exp = "" 
				local tmp_idx = v.successDestination:match("^SIPT%-(%d+)$")
				exp = "sofia/gateway/"..(sip_trunk_list[tmp_idx] or "unknown").."/${destination_number}"
				--@ set fax
				if v.from:match("^[FXS|FXO]+%-%d+$") or v.from == "0" then
					add_fax_param(condition[condition_flag],"export","set")
				end
				
				add_action(condition[condition_flag],"lua","set_sip_param.lua "..exp)
				add_action(condition[condition_flag],"set","dest_chan_name=".."SIP Trunk/"..(sip_trunk_name[tmp_idx] or "unknown"))
				if (not v.failCondition) or (v.failCondition and (not v.timeout)) then
					add_action(condition[condition_flag],"set","call_timeout="..sip_trunk_progress_time[tmp_idx])
					add_action(condition[condition_flag],"set","bridge_answer_timeout="..sip_trunk_progress_time[tmp_idx])
					add_action(condition[condition_flag],"export","progress_timeout="..sip_trunk_progress_time[tmp_idx])
					add_action(condition[condition_flag],"export","originate_timeout="..sip_trunk_progress_time[tmp_idx])
				end
				add_action(condition[condition_flag],"bridge",exp)
				--@ transfer to FAIL
				if v.failDestination then
					add_action(condition[condition_flag],"transfer","FAIL-"..(tonumber(v.index) < 10 and ("0"..v.index) or v.index).." XML failroute")
				end
			--@ to SIP Extension
			elseif v.successDestination:match("^SIPP%-%d+$") then
				local exp = "" 
				local index = v.successDestination:match("^SIPP%-(%d+)$")
				--@ set fax
				if v.from:match("^[FXS|FXO]+%-%d+%-%d+$") or v.from == "0" then
					add_fax_param(condition[condition_flag],"export","set")
				end
				
				for _,v2 in pairs(sip_extension) do
					if v2.index == index and v2.user then
						exp = v2.user.." XML extension"
						add_action(condition[condition_flag],"transfer",exp)
						break
					end
				end
			--@ to FXSO
			elseif v.successDestination:match("^[FXS|FXO]+%-%d+%-%d+$") then
				local exp = ""
				local tmp_type,tmp_idx,tmp_port = v.successDestination:match("^([FXSO]+)%-(%d+)%-(%d+)$")
				
				for k2,v2 in pairs(fxso_endpoint) do
					if v2['.type'] == string.lower(tmp_type) and v2.index == tmp_idx then
						if tmp_port == "0" and v2.number_1 and (("FXS" == tmp_type and interface:match("S")) or ("FXO" == tmp_type and interface:match("2O"))) then
							add_action(condition[condition_flag],"transfer",v2.number_1.." XML extension")
						elseif tmp_port == "1" and v2.number_2 and (("FXS" == tmp_type and interface:match("2S")) or ("FXO" == tmp_type and interface:match("O"))) then
							add_action(condition[condition_flag],"transfer",v2.number_2.." XML extension")
						end
						break
					end
				end
			--@ to GSM/CDMA/VOLTE
			elseif v.successDestination:match("^[GSM|CDMA|VOLTE]+%-%d+$") then
				local exp = ""
				local idx = v.successDestination:match("^[GSM|CDMA|VOLTE]+%-(%d+)$")
				for k2,v2 in pairs(mobile_endpoint) do
					if v2.index == idx and v2.number then
						exp = v2.number.." XML extension"
						add_action(condition[condition_flag],"transfer",exp)
						break
					end
				end
			--@ to route group
			elseif v.successDestination:match("^ROUTE%-%d+$")then
				local idx = v.successDestination:match("^ROUTE%-(%d+)$")
				for k2,v2 in pairs(routegroup) do
					if v2.index and v2.index == idx and v2.strategy then
						local cnt = 0
						local sipt_flag
						for k3,v3 in pairs(v2.members_select) do
							if v3:match("^SIPP") or v3:match("^FXS") or v3:match("^FXO") or v3:match("^GSM") or v3:match("^VOLTE") then
								cnt = cnt + 1
							elseif v3:match("^SIPT") then
								sipt_flag = true
							end
						end
						local cnt_max = ("1T1S1O" == interface) and 10 or 11
						if sipt_flag or cnt > cnt_max then
							cnt = cnt_max
						end
						add_action(condition[condition_flag],"limit","hash routegrp-max "..v2.index.." "..cnt.." !USER_BUSY")
						add_action(condition[condition_flag],"lua","RouteGroup-"..idx..".lua")
						add_action(condition[condition_flag],"set","dest_chan_name=${my_bridge_channel}")
						add_action(condition[condition_flag],"bridge","${my_group_bridge_str}")
						break
					end
				end
				if v.failDestination then
					add_action(condition[condition_flag],"transfer","FAIL-"..(tonumber(v.index) < 10 and ("0"..v.index) or v.index).." XML failroute")
				end
			--@ to Ring GROUP
			elseif v.successDestination:match("^RING%-%d+$") then
				local idx = v.successDestination:match("^RING%-(%d+)$")
				for k2,v2 in pairs(ringgroup) do
					if v2.index and v2.index == idx and v2.members_select then
						if #v2.members_select <= 8 then
							add_action(condition[condition_flag],"limit","hash ringgrp-max "..v2.index.." "..#v2.members_select.." !USER_BUSY")
						else
							local flag
							for k3,v3 in pairs(v2.members_select) do
								if v3:match("FXS") then
									flag = true
									break
								end
							end
							if flag then
								add_action(condition[condition_flag],"limit","hash ringgrp-max "..v2.index.." 9 !USER_BUSY")
							else
								add_action(condition[condition_flag],"limit","hash ringgrp-max "..v2.index.." 8 !USER_BUSY")
							end
						end
						add_action(condition[condition_flag],"lua","RingGroup-"..idx..".lua")
						break
					end
				end
			--@ to IVR
			elseif v.successDestination:match("^IVR") then
				for k2,v2 in pairs(ivr) do
					if "ivr" == v2['.type'] and v2.timeout and v2.repeat_loops then
						add_action(condition[condition_flag],"transfer","IVRService XML IVR")
					end
				end
			elseif v.successDestination:match("^Extension") then
				add_action(condition[condition_flag],"transfer","${destination_number} XML extension")
			elseif v.successDestination:match("^Hangup") then
				add_action(condition[condition_flag],"set","hangup_cause=USER_BUSY")
				add_action(condition[condition_flag],"hangup")
			end
		end
	--@ END: Success bridge action}

	--@ { START:CREATE a NEW extension for failed routing
		if v.failDestination and v.successDestination ~= "Hangup-1" then
			local fail_xml = mxml:newxml()
			local fail_include = mxml.newnode(fail_xml,"include")

			local failed_extension = mxml.newnode(fail_include,"extension")
			mxml.setattr(failed_extension,"name","FAIL-"..(tonumber(v.index) < 10 and ("0"..v.index) or v.index))

			local failed_condition = mxml.newnode(failed_extension,"condition")
			mxml.setattr(failed_condition,"field","destination_number")
			mxml.setattr(failed_condition,"expression","^FAIL-"..(tonumber(v.index) < 10 and ("0"..v.index) or v.index).."$")

			--@ delete channel_var continue_on_fail 
			add_failed_action(failed_condition,"unset","continue_on_fail")--@ need test
			add_failed_action(failed_condition,"unset","transfer_name_on_fail")--@ need test
			add_failed_action(failed_condition,"unset","my_group_bridge_str")

			--@ set faildst number manipulation action
			--@ NEED SOME WORKS
			if v.failNumberManipulation then
				for k2,v2 in pairs(number_manipulation_cfg) do
					if v2.index == v.failNumberManipulation then
						local exp = ""
						--@ caller number change
						exp = "number_manipulation.lua".." 0 ".."${caller_id_number} "..(v2.CallerDelPrefix or "nil").." "..(v2.CallerDelSuffix or "nil").." "..(v2.CallerAddPrefix or "nil").." "..(v2.CallerAddSuffix or "nil").." "..(v2.CallerReplace or "nil")
						add_failed_action(failed_condition,"lua",exp)

						--@ called number change
						exp = "number_manipulation.lua".." 1 ".."${my_dst_number} "..(v2.CalledDelPrefix or "nil").." "..(v2.CalledDelSuffix or "nil").." "..(v2.CalledAddPrefix or "nil").." "..(v2.CalledAddSuffix or "nil").." "..(v2.CalledReplace or "nil")
						add_failed_action(failed_condition,"lua",exp)
					end
				end
			end

			--@ to SIP Trunk
			if v.failDestination:match("^SIPT%-%d+$") then
				local exp = "" 
				local tmp_idx = v.failDestination:match("^SIPT%-(%d+)$")
				exp = "sofia/gateway/"..(sip_trunk_list[tmp_idx] or "unknown").."/${destination_number}"

				--@ set fax 
				if v.from:match("^[FXS|FXO|FXSO]+%-%d+$") or v.from == "0" then
					add_fax_param(failed_condition,"export","set")
				end
				add_failed_action(failed_condition,"lua","set_sip_param.lua "..exp)

				add_failed_action(failed_condition,"set","dest_chan_name=".."SIP Trunk/"..(sip_trunk_name[tmp_idx] or "unknown"))
				add_failed_action(failed_condition,"set","call_timeout="..sip_trunk_progress_time[tmp_idx])
				add_failed_action(failed_condition,"set","bridge_answer_timeout="..sip_trunk_progress_time[tmp_idx])
				add_failed_action(failed_condition,"export","progress_timeout="..sip_trunk_progress_time[tmp_idx])
				add_failed_action(failed_condition,"export","originate_timeout="..sip_trunk_progress_time[tmp_idx])
				add_failed_action(failed_condition,"bridge",exp)
			--@ to SIP Extension
			elseif v.failDestination:match("^SIPP%-%d+$") then
				local exp = "" 
				local index = v.failDestination:match("^SIPP%-(%d+)$")
				--@ set fax
				if v.from:match("^[FXS|FXO]+%-%d+$") or v.from == "0" then
					add_fax_param(failed_condition,"export","set")
				end

				for _,v2 in pairs(sip_extension) do
					if v2.index == index and v2.user then
						exp = v2.user.." XML extension"
						add_action(failed_condition,"transfer",exp)
						break
					end
				end
			--@ to FXSO
			elseif v.failDestination:match("^[FXS|FXO]+%-%d+$") then
				local exp = ""
				local tmp_type,tmp_idx,tmp_port = v.successDestination:match("^([FXSO]+)%-(%d+)%-(%d+)$")
				add_failed_action(failed_condition,"set","bypass_media=false")

				for k2,v2 in pairs(fxso_endpoint) do
					if v2['.type'] == string.lower(tmp_type) and v2.index == tmp_idx then
						if tmp_port == "0" and v2.number_1 and (("FXS" == tmp_type and interface:match("S")) or ("FXO" == tmp_type and interface:match("2O"))) then
							add_failed_action(failed_condition,"transfer",v2.number_1.." XML extension")
						elseif tmp_port == "1" and v2.number_2 and (("FXS" == tmp_type and interface:match("2S")) or ("FXO" == tmp_type and interface:match("O"))) then
							add_failed_action(failed_condition,"transfer",v2.number_2.." XML extension")
						end
						break
					end
				end
			--@ to GSM/CDMA/VOLTE
			elseif v.failDestination:match("^[GSM|CDMA|VOLTE]+%-%d+$") then
				local exp = "" 
				local tmp_idx = v.failDestination:match("^[GSM|CDMA|VOLTE]+%-(%d+)$")
				add_failed_action(failed_condition,"set","bypass_media=false")
				for k2,v2 in pairs(mobile_endpoint) do
					if v2.index and v2.index == tmp_idx and v2.number then
						exp = v2.number.." XML extension"
						add_failed_action(failed_condition,"transfer",exp)
						break
					end
				end
			--@ to Routegroup
			elseif v.failDestination:match("^ROUTE%-%d+$") then
				local tmp_idx = v.failDestination:match("^ROUTE%-(%d+)$")
				for k2,v2 in pairs(routegroup) do
					if v2.index and v2.index == tmp_idx and v2.strategy then
						local cnt = 0
						local sipt_flag
						for k3,v3 in pairs(v2.members_select) do
							if v3:match("^SIPP") or v3:match("^FXS") or v3:match("^FXO") or v3:match("^GSM") or v3:match("^VOLTE") then
								cnt = cnt + 1
							elseif v3:match("^SIPT") then
								sipt_flag = true
							end
						end
						local cnt_max = ("1T1S1O" == interface) and 10 or 11
						if sipt_flag or cnt > cnt_max then
							cnt = cnt_max
						end
						add_failed_action(failed_condition,"limit","hash routegrp-max "..v2.index.." "..cnt.." !USER_BUSY")
						add_failed_action(failed_condition,"lua","RouteGroup-"..tmp_idx..".lua")
						add_failed_action(failed_condition,"set","dest_chan_name=${my_bridge_channel}")
						add_failed_action(failed_condition,"bridge","${my_group_bridge_str}")
						break
					end
				end
			--@ to Ringgroup
			elseif v.failDestination:match("^RING%-%d+$") then
				local tmp_idx = v.failDestination:match("^RING%-(%d+)$")
				for k2,v2 in pairs(ringgroup) do
					if v2.index and v2.index == tmp_idx and v2.members_select then
						if #v2.members_select <= 8 then
							add_failed_action(failed_condition,"limit","hash ringgrp-max "..v2.index.." "..#v2.members_select.." !USER_BUSY")
						else
							local flag
							for k3,v3 in pairs(v2.members_select) do
								if v3:match("FXS") then
									flag = true
									break
								end
							end
							if flag then
								add_failed_action(failed_condition,"limit","hash ringgrp-max "..v2.index.." 9 !USER_BUSY")
							else
								add_failed_action(failed_condition,"limit","hash ringgrp-max "..v2.index.." 8 !USER_BUSY")
							end
						end
						add_failed_action(failed_condition,"lua","RingGroup-"..tmp_idx..".lua")
						break
					end
				end
			--@ to IVR
			elseif v.failDestination:match("^IVR") then
				for k2,v2 in pairs(ivr) do
					if "ivr" == v2['.type'] and v2.timeout and v2.repeat_loops then
						add_failed_action(failed_condition,"transfer","IVRService XML IVR")
						break
					end
				end
			elseif v.failDestination:match("^Extension") then
				--add_failed_action(failed_condition,"transfer","${my_dst_number} XML extension")--need get dst_number from chaneel_var	
			end

			mxml.savefile(fail_xml,fail_xml_dir.."/Fail-"..(tonumber(v.index) < 10 and ("0"..v.index) or v.index)..".xml")
			mxml.release(fail_xml)
		end
	--@  END:CREATE a NEW extension for failed routing}	

	--@ END ADD ACTION
	--@ END ACTION
		--save xml
		local xml_file
		if fs.access(conf_dir) and v.index then
			xml_file = conf_dir.."/r_"..(tonumber(v.index) < 10 and ("0"..v.index) or v.index)..".xml"
			mxml.savefile(xml,xml_file)
		else

		end

		mxml.release(xml)
	end
end
