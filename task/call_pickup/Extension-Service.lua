--@ Extension service
--@ Version 1.0.0.1
--@ Date 2014.10.11
local api = freeswitch.API()
local uci = require "uci".cursor()

local bridge_str = argv[1]
local sip_ex_tb = {}
local fxs_ex_tb = {}
local interface = ""
local voice_lang = ""
local fxs_chan_name = {}
local sip_trunk_name = {}
local endpoint_interface = {}
local endpoint_progress_time = {}
local extension_call_pickup = {}
local bind_transfer_dtmf = ""
local attended_transfer_dtmf = ""

--@ endpoint_fxso or endpoint_sipphone
local call_waiting_status = "Deactivate"
local call_notdisturb_status = "Deactivate"
local call_forward_unregister_value = "Deactivate"
local call_forward_uncondition_value = "Deactivate"
local call_forward_busy_value = "Deactivate"
local call_forward_noreply_value = "Deactivate"
local call_forward_noreply_timeout = "20"
local sip_extension_reg_status_query=""
local call_progress_time = 55
local call_forward_unregister_progress_time = 55
local call_forward_uncondition_progress_time = 55
local call_forward_busy_progress_time = 55
local call_forward_noreply_progress_time = 55
--@ feature_code
local bind_transfer_dtmf = ""
local attended_transfer_dtmf = ""

if not bridge_str then
	--@ Error Log
	return
end

if "IVRDIAL" == session:getVariable("my_dst_number") then
	session:setVariable("my_dst_number","")
end

local src_chan_name = session:getVariable("chan_name")
local destination_number = session:getVariable("destination_number")
local current_extension_number = session:getVariable("my_callwaiting_number")
local destination_display = destination_number
if destination_number ~= current_extension_number then
	destination_display = destination_number.."->"..current_extension_number
end
local cdr_dest_chan_name = session:getVariable("my_bridge_channel") or bridge_str or "null"

--@ extension_service
local bridge_type = bridge_str:match("([a-z]+)/.*")
if bridge_type == "freetdm" then
	local slot,port = bridge_str:match("freetdm/([0-9]+)/([0-9]+)/")
	if fxs_ex_tb[slot] then
		if port == "1" then
			call_waiting_status = fxs_ex_tb[slot]["waiting_1"] or "Deactivate"
			call_notdisturb_status = fxs_ex_tb[slot]["notdisturb_1"] or "Deactivate"
			if fxs_ex_tb[slot]["forward_uncondition_dst_1"] then
				call_forward_uncondition_value = fxs_ex_tb[slot]["forward_uncondition_1"].."/"..fxs_ex_tb[slot]["forward_uncondition_dst_1"]
			else
				call_forward_uncondition_value = fxs_ex_tb[slot]["forward_uncondition_1"] or "Deactivate"
			end
			if fxs_ex_tb[slot]["forward_busy_dst_1"] then
				call_forward_busy_value = fxs_ex_tb[slot]["forward_busy_1"].."/"..fxs_ex_tb[slot]["forward_busy_dst_1"]
			elseif fxs_ex_tb[slot]["forward_busy_1"] then
				call_forward_busy_value = fxs_ex_tb[slot]["forward_busy_1"] or "Deactivate"
			end
			if fxs_ex_tb[slot]["forward_noreply_dst_1"] then
				call_forward_noreply_value = fxs_ex_tb[slot]["forward_noreply_1"].."/"..fxs_ex_tb[slot]["forward_noreply_dst_1"]
			else
				call_forward_noreply_value = fxs_ex_tb[slot]["forward_noreply_1"] or "Deactivate"
			end
			if fxs_ex_tb[slot]["forward_noreply_timeout_1"] then
				call_forward_noreply_timeout = fxs_ex_tb[slot]["forward_noreply_timeout_1"] or "20"
			end
			if endpoint_progress_time["fxs_"..slot.."_1"] then
				call_progress_time = endpoint_progress_time["fxs_"..slot.."_1"]
			end
		else
			call_waiting_status = fxs_ex_tb[slot]["waiting_2"] or "Deactivate"
			call_notdisturb_status = fxs_ex_tb[slot]["notdisturb_2"] or "Deactivate"
			if fxs_ex_tb[slot]["forward_uncondition_dst_2"] then
				call_forward_uncondition_value = fxs_ex_tb[slot]["forward_uncondition_2"].."/"..fxs_ex_tb[slot]["forward_uncondition_dst_2"]
			else
				call_forward_uncondition_value = fxs_ex_tb[slot]["forward_uncondition_2"] or "Deactivate"
			end
			if fxs_ex_tb[slot]["forward_busy_dst_2"] then
				call_forward_busy_value = fxs_ex_tb[slot]["forward_busy_2"].."/"..fxs_ex_tb[slot]["forward_busy_dst_2"]
			elseif fxs_ex_tb[slot]["forward_busy_2"] then
				call_forward_busy_value = fxs_ex_tb[slot]["forward_busy_2"] or "Deactivate"
			end
			if fxs_ex_tb[slot]["forward_noreply_dst_2"] then
				call_forward_noreply_value = fxs_ex_tb[slot]["forward_noreply_2"].."/"..fxs_ex_tb[slot]["forward_noreply_dst_2"]
			else
				call_forward_noreply_value = fxs_ex_tb[slot]["forward_noreply_2"] or "Deactivate"
			end
			if fxs_ex_tb[slot]["forward_noreply_timeout_2"] then
				call_forward_noreply_timeout = fxs_ex_tb[slot]["forward_noreply_timeout_2"] or "20"
			end
			if endpoint_progress_time["fxs_"..slot.."_2"] then
				call_progress_time = endpoint_progress_time["fxs_"..slot.."_2"]
			end
		end
	end
elseif bridge_str:match("user/")  then
	local user = bridge_str:match("user/([0-9]+)@")
	if sip_ex_tb[user] then
		call_waiting_status = sip_ex_tb[user]["waiting"] or "Deactivate"
		call_notdisturb_status = sip_ex_tb[user]["notdisturb"] or "Deactivate"
		sip_extension_reg_status_query = sip_ex_tb[user]["reg_query"] or ""
		if sip_ex_tb[user]["forward_uncondition_dst"] then
			call_forward_uncondition_value = sip_ex_tb[user]["forward_uncondition"].."/"..sip_ex_tb[user]["forward_uncondition_dst"]
		else
			call_forward_uncondition_value = sip_ex_tb[user]["forward_uncondition"] or "Deactivate"
		end
		if sip_ex_tb[user]["forward_unregister_dst"] then
			call_forward_unregister_value = sip_ex_tb[user]["forward_unregister"].."/"..sip_ex_tb[user]["forward_unregister_dst"]
		else
			call_forward_unregister_value = sip_ex_tb[user]["forward_unregister"] or "Deactivate"
		end
		if sip_ex_tb[user]["forward_busy_dst"] then
			call_forward_busy_value = sip_ex_tb[user]["forward_busy"].."/"..sip_ex_tb[user]["forward_busy_dst"]
		elseif sip_ex_tb[user]["forward_busy"] then
			call_forward_busy_value = sip_ex_tb[user]["forward_busy"] or "Deactivate"
		end
		if sip_ex_tb[user]["forward_noreply_dst"] then
			call_forward_noreply_value = sip_ex_tb[user]["forward_noreply"].."/"..sip_ex_tb[user]["forward_noreply_dst"]
		else
			call_forward_noreply_value = sip_ex_tb[user]["forward_noreply"] or "Deactivate"
		end	
		if sip_ex_tb[user]["forward_noreply_timeout"] then
			call_forward_noreply_timeout = sip_ex_tb[user]["forward_noreply_timeout"] or "20"
		end
		if endpoint_progress_time[user] then
			call_progress_time = endpoint_progress_time[user]
		end
	end
end

--@ check 
function check_channel_idle_state(bridge_param)
	if bridge_param then
		local cmd_str

		if bridge_param:match("^freetdm/") then
			local slot,port = bridge_param:match("^freetdm/([0-9]+)/([1|2])")
			cmd_str = "ftdm channel_idle "..(tonumber(slot)-1).." "..(tonumber(port)-1)
		elseif bridge_param:match("^gsmopen/") then
			local slot_name = bridge_param:match("^gsmopen/([a-zA-Z0-9%-_]+)")
			cmd_str = "gsm check_usable "..slot_name
		elseif bridge_param:match("user/") then
			local ex = bridge_param:match("user/([0-9a-zA-Z]+)@") or "unknown"
			local ret = api:executeString(sip_extension_reg_status_query or "")
			if not (ret and ret:match("User:%s*"..ex)) then
				return "unregister"
			end
			if "1" == api:executeString("hash select/currentcall/"..ex) then
				return "calling"
			else
				return "true"
			end
		elseif bridge_param:match("sofia/") then
			return "true"
		else
			return "false"
		end

		if cmd_str then
			local reply_str = api:executeString(cmd_str)
			if reply_str and string.find(reply_str,"true") then
				return "true"
			elseif reply_str and (reply_str:match("false\nDEV_READY\nUP\n1\n") and not string.find(reply_str,"online") and not string.find(reply_str,"offline")) then
				return "waiting"
			end 			
		end
	end

	return "false"
end

function check_src_dest_is_match(src_chan_name,dest_chan_name,error_prefix)
	--为了防止呼叫循环，这里对目的地和呼叫来源做判断
	--1、分机A设置呼转到B，B又设置了呼转到A
	--2、分机A设置呼转到B，B设置呼转到C，C又设置了呼转到A
	--3、A可以是主叫，也可以是其它呼入进来的第一个目的地
	local dest_type = string.sub(dest_chan_name,1,3)
	if dest_type == "FXO" then
		if src_chan_name and src_chan_name:match("FreeTDM") then
			local dest_slot,dest_port = dest_chan_name:match("FXO/([0-9]+)/([0-9]+)/")
			if dest_slot and dest_port then
				local src_slot,src_port = src_chan_name:match("FreeTDM/(%d+):(%d+)")
				if dest_slot == src_slot and dest_port == src_port then
					session:consoleLog("notice",error_prefix.." destination is same with caller, ignore...")
					return false
				else
					return dest_type
				end
			else
				session:consoleLog("notice",error_prefix.." destination is invalid, ignore...")
				return false
			end
		else
			return dest_type
		end
	elseif dest_type == "SIP" then
		if src_chan_name and src_chan_name:match("sofia/gateway/") then
			local dest_gw_name = dest_chan_name:match("SIPT%-([0-9%_]+)/")
			if dest_gw_name then
				local src_gw_name = src_chan_name:match("sofia/gateway/([0-9_]+)")
				if dest_gw_name == src_gw_name then
					session:consoleLog("notice",error_prefix.." destination is same with caller, ignore...")
					return false
				else
					return dest_type
				end
			else
				session:consoleLog("notice",error_prefix.." destination is invalid, ignore...")
				return false
			end
		else
			return dest_type
		end
	elseif dest_type == "gsm" then
		if src_chan_name and src_chan_name:match("gsmopen/") then
			local dest_gw_name = dest_chan_name:match("gsmopen/([0-9a-zA-Z%-]+)/")
			if dest_gw_name then
				local src_gw_name = src_chan_name:match("gsmopen/([0-9a-zA-Z%-]+)/")
				if dest_gw_name == src_gw_name then
					session:consoleLog("notice",error_prefix.." destination is same with caller, ignore...")
					return false
				else
					return dest_type
				end
			else
				session:consoleLog("notice",error_prefix.." destination is invalid, ignore...")
				return false
			end
		else
			return dest_type
		end
	else
		local processed_destination = session:getVariable("processed_destination") or "" --曾经经过的目的地
		if src_chan_name and src_chan_name:match("FreeTDM") then
			local src_chan_prefix = src_chan_name:match("(FreeTDM/%d+:%d/)") or "unknown"
			local src_chan_extension = fxs_chan_name[src_chan_prefix] or "unknown"
			if src_chan_extension == dest_chan_name then
				session:consoleLog("notice",error_prefix.." destination is same with caller, ignore...")
				return false
			elseif string.find(processed_destination,dest_chan_name) then
				session:consoleLog("notice",error_prefix.." destination is same with processed destination["..processed_destination.."], ignore...")
				return false
			else
				return dest_chan_name
			end
		else
			local src_chan_extension = src_chan_name:match("sofia/user/([0-9a-zA-Z]+)/") or "unknown"
			if src_chan_extension == dest_chan_name then
				session:consoleLog("notice",error_prefix.." destination is same with caller, ignore...")
				return false
			elseif string.find(processed_destination,dest_chan_name) then
				session:consoleLog("notice",error_prefix.." destination is same with processed destination["..processed_destination.."], ignore...")
				return false
			else
				return dest_chan_name
			end
		end
	end
end

if session:ready() then
    local blind_transfer_val = session:getVariable("blind_transfer_val") or "false"
    if blind_transfer_val == "true" then
            session:execute("set","ringback=${hold_music}")
    end
    
    session:execute("set","force_transfer_context=public")
    session:execute("export","force_transfer_context=public")
    session:execute("set","sip_redirect_context=public")
    session:execute("export","sip_redirect_context=public")

	session:setVariable("my_success_bridge_str","false")
	
	session:setVariable("my_fail_transfer_str_unregister","false")
	session:setVariable("my_fail_bridge_str_unregister","false")

	session:setVariable("my_fail_transfer_str_uncondition","false")
	session:setVariable("my_fail_bridge_str_uncondition","false")
	
	session:setVariable("my_fail_transfer_str_noreply","false")
	session:setVariable("my_fail_bridge_str_noreply","false")
	
	session:setVariable("my_fail_transfer_str_userbusy","false")
	session:setVariable("my_fail_bridge_str_userbusy","false")	
	
	session:setVariable("my_fail_transfer_str_failroute","false")
	--@ END 

	session:setVariable("dest_chan_name",session:getVariable("my_bridge_channel") or "Unknown")
	
	--@ Set Fail_route cause
	local hangup_real_cause
	local fail_route_cause_str = session:getVariable("fail_route_cause")
	if not fail_route_cause_str then
		fail_route_cause_str = session:getVariable("continue_on_fail")
		if fail_route_cause_str then
			session:setVariable("fail_route_cause",fail_route_cause_str)
		end
	end
	--@ END
	if bridge_str:match("freetdm/") and src_chan_name:match("^sofia/") then
		session:execute("set","hangup_after_bridge=true")
		
		session:execute("export","execute_on_fax_end=myfax_fax_stop")
		session:execute("export","execute_on_fax_detect=myfax_fax_start request peer")
		
		session:execute("set","fax_enable_t38_request=true")
		session:execute("set","sip_execute_on_image=myfax_fax_start t38 self")

		session:execute("set","fax_enable_t30_request=true")
		session:execute("set","sip_execute_on_t30=myfax_fax_start t30 self")
	elseif bridge_str:match("user/")  and src_chan_name:match("^FreeTDM") then
		session:execute("set","hangup_after_bridge=true")
		
		session:execute("set","execute_on_fax_end=myfax_fax_stop")
		session:execute("set","execute_on_fax_detect=myfax_fax_start request peer")
		
		session:execute("export","fax_enable_t38_request=true")
		session:execute("export","sip_execute_on_image=myfax_fax_start t38 self")

		session:execute("export","fax_enable_t30_request=true")
		session:execute("export","sip_execute_on_t30=myfax_fax_start t30 self")
	end

	--@ set call_timeout for forward_noreply
	if call_forward_noreply_value ~= "Deactivate" then
		call_progress_time = call_forward_noreply_timeout
	end
	--@ END
	
	--@ service of call_notdisturb 
	if call_notdisturb_status == "Activate" then
		local tmp = session:getVariable("transfer_name_on_fail")
		if tmp and fail_route_cause_str and string.find(fail_route_cause_str,"USER_BUSY") then
			session:consoleLog("info",src_chan_name.." -> Extension ["..destination_display.."] Service [DND] Enabled, setting transfer to failover route - ["..tmp.."]")
			session:setVariable("my_fail_transfer_str_failroute","T-"..tmp.." XML failroute")
		else
			session:consoleLog("err",src_chan_name.." -> Extension ["..destination_display.."] Service [DND] Enabled, ready to hangup...")
			session:setVariable("hangup_cause","USER_BUSY")
			session:execute("lua","check_line_is_busy.lua")
			session:hangup("USER_BUSY")
		end
		--@ HERE IS ROUTING END
	else
		--@ take the first service,call_forward_uncondition
		local uncondition_forward_succ = false
		if "Deactivate" ~= call_forward_uncondition_value then
			uncondition_forward_succ = check_src_dest_is_match(src_chan_name,call_forward_uncondition_value,src_chan_name.." -> Extension ["..destination_display.."] Service [Unconditional Forward->"..call_forward_uncondition_value.."] Enabled,")
		end
		if uncondition_forward_succ then
			session:consoleLog("info",src_chan_name.." -> Extension ["..destination_display.."] Service [Unconditional Forward->"..call_forward_uncondition_value.."] Enabled")
			local dest_type = string.sub(call_forward_uncondition_value,1,3)
			if dest_type == "FXO" then
				local slot,port,dst = call_forward_uncondition_value:match("FXO/([0-9]+)/([0-9]+)/([0-9]+)")
				if slot and port and dst then
					session:setVariable("my_fail_bridge_str_uncondition","T-freetdm/"..slot.."/"..port.."/"..dst)
					if interface:match("1O") then
						session:setVariable("my_fail_bridge_channel_uncondition",cdr_dest_chan_name.."->FXO")
					else
						session:setVariable("my_fail_bridge_channel_uncondition",cdr_dest_chan_name.."->FXO Trunk/Port "..(port-1))
					end
				end
			elseif dest_type == "SIP" then
				local gw_name,dst = call_forward_uncondition_value:match("SIPT%-([0-9%_]+)/([0-9]+)")
				if gw_name and dst then
					session:setVariable("my_fail_bridge_channel_uncondition",cdr_dest_chan_name.."->"..sip_trunk_name[gw_name])
					session:setVariable("call_forward_uncondition_progress_time",endpoint_progress_time[gw_name] or call_forward_uncondition_progress_time or 55)
					session:setVariable("my_fail_bridge_str_uncondition","T-sofia/gateway/"..gw_name.."/"..dst)
				end
			elseif dest_type == "gsm" then
				local gsm_name,dst = call_forward_uncondition_value:match("gsmopen/([0-9a-zA-Z%-]+)/([0-9]+)")
				if gsm_name and dst and gsm_name:match("VOLTE") then
					session:setVariable("my_fail_bridge_str_uncondition","T-gsmopen/"..gsm_name.."/"..dst)
					session:setVariable("my_fail_bridge_channel_uncondition",cdr_dest_chan_name.."->VOLTE")
				elseif gsm_name and dst then
					session:setVariable("my_fail_bridge_str_uncondition","T-gsmopen/"..gsm_name.."/"..dst)
					session:setVariable("my_fail_bridge_channel_uncondition",cdr_dest_chan_name.."->GSM")
				end
			else
				session:setVariable("call_forward_uncondition_progress_time",endpoint_progress_time[call_forward_uncondition_value] or call_forward_uncondition_progress_time or 55)
				local ret_number = api:executeString("eval ${user_data("..call_forward_uncondition_value.."@${domain} attr id)}")
				if ret_number == call_forward_uncondition_value then
					session:setVariable("my_fail_transfer_str_uncondition","T-"..call_forward_uncondition_value.." XML extension")
				else
					session:setVariable("my_fail_transfer_str_uncondition","T-"..call_forward_uncondition_value.." XML public")
				end
			end
		else
			--@ setting for dtmf
			local sip_user_agent = session:getVariable("sip_user_agent") or ""

			if session:getVariable("my_flag_from_sip_reg") ~= "true" or (not sip_user_agent:match("%/[0-9]+%.[0-9]+%.[0-9]+%.[0-9]+%s*[0-9]+%-[0-9]+%-[0-9]+%s*[0-9:]+")) then
				if bind_transfer_dtmf ~= "" then
					session:execute("bind_meta_app",bind_transfer_dtmf.." b is execute_extension::blind_transfer XML transfer")
				end
				if attended_transfer_dtmf ~= "" then
					session:execute("bind_meta_app",attended_transfer_dtmf.." b ib execute_extension::att_xfer XML transfer")
				end
			end
			--@ END

			local continue_on_fail_str = ""
			local channel_state_ret = check_channel_idle_state(bridge_str)

			if channel_state_ret == "unregister" and "Deactivate" ~= call_forward_unregister_value then
				local unregister_forward_succ = check_src_dest_is_match(src_chan_name,call_forward_unregister_value,src_chan_name.." -> Extension ["..destination_display.."] Service [Unregister Forward->"..call_forward_unregister_value.."] Enabled,")

				if unregister_forward_succ then
					session:consoleLog("info",src_chan_name.." -> Extension ["..destination_display.."] Service [Unregister Forward->"..call_forward_unregister_value.."] Enabled")
					local dest_type = string.sub(call_forward_unregister_value,1,3)
					if dest_type == "FXO" then
						local slot,port,dst = call_forward_unregister_value:match("FXO/([0-9]+)/([0-9]+)/([0-9]+)")
						if slot and port and dst then
							session:setVariable("my_fail_bridge_str_unregister","T-freetdm/"..slot.."/"..port.."/"..dst)
							if interface:match("1O") then
								session:setVariable("my_fail_bridge_channel_unregister",cdr_dest_chan_name.."->FXO")
							else
								session:setVariable("my_fail_bridge_channel_unregister",cdr_dest_chan_name.."->FXO Trunk/Port "..(port-1))
							end
						end
					elseif dest_type == "SIP" then
						local gw_name,dst = call_forward_unregister_value:match("SIPT%-([0-9%_]+)/([0-9]+)")
						if gw_name and dst then
							session:setVariable("call_forward_unregister_progress_time",endpoint_progress_time[gw_name] or call_forward_unregister_progress_time or 55)
							session:setVariable("my_fail_bridge_channel_unregister",cdr_dest_chan_name.."->"..sip_trunk_name[gw_name])
							session:setVariable("my_fail_bridge_str_unregister","T-sofia/gateway/"..gw_name.."/"..dst)
						end
					elseif dest_type == "gsm" then
						local gsm_name,dst = call_forward_unregister_value:match("gsmopen/([0-9a-zA-Z%-]+)/([0-9]+)")
						if gsm_name and dst and gsm_name:match("VOLTE") then
							session:setVariable("my_fail_bridge_str_unregister","T-gsmopen/"..gsm_name.."/"..dst)
							session:setVariable("my_fail_bridge_channel_unregister",cdr_dest_chan_name.."->VOLTE")
						elseif gsm_name and dst then
							session:setVariable("my_fail_bridge_str_unregister","T-gsmopen/"..gsm_name.."/"..dst)
							session:setVariable("my_fail_bridge_channel_unregister",cdr_dest_chan_name.."->GSM")
						end
					elseif call_forward_unregister_value ~= "Deactivate" then
						session:setVariable("call_forward_unregister_progress_time",endpoint_progress_time[call_forward_unregister_progress_time] or call_forward_unregister_progress_time or 55)
						local ret_number = api:executeString("eval ${user_data("..call_forward_unregister_value.."@${domain} attr id)}")
						if ret_number == call_forward_unregister_value then
							session:setVariable("my_fail_transfer_str_unregister","T-"..call_forward_unregister_value.." XML extension")
						else
							session:setVariable("my_fail_transfer_str_unregister","T-"..call_forward_unregister_value.." XML public")
						end
					end
				end
			elseif channel_state_ret == "true" and check_src_dest_is_match(src_chan_name,current_extension_number,src_chan_name.." call to Extension ["..destination_display.."],") then
				--@ Normal bridge action
				if extension_call_pickup[current_extension_number] ~= "off" then
					session:setVariable("prev_extension_number",current_extension_number)
					session:execute("hash","insert/callgroup/U-"..current_extension_number.."/${uuid}")
				end
				session:setVariable("my_success_bridge_str","T-"..bridge_str)
				session:setVariable("my_bridge_progress_timeout",call_progress_time)
			elseif channel_state_ret == "calling" and call_waiting_status == "Activate" then
				--@ Here is for SIP callwaiting
				session:setVariable("my_fail_transfer_str_callwaiting","T-".."SIPWAITING${my_callwaiting_number} XML callwaiting")
				session:setVariable("my_callwaiting_bridge_str",bridge_str)
			elseif channel_state_ret == "waiting" and call_waiting_status == "Activate" then
				--@ CALL WAITING
				--@ Here is for FXS waiting
				--@ set callwaiting music
				if voice_lang == "en" then
					session:setVariable("my_callwaiting_music","/etc/freeswitch/sounds/en/us/callie/busy_waiting")
				else
					session:setVariable("my_callwaiting_music","/etc/freeswitch/sounds/zh/cn/callie/busy_waiting")
				end
				session:setVariable("my_bridge_progress_timeout",call_progress_time)
				--@ set callwaiting bridge_str
				session:setVariable("my_callwaiting_bridge_str",bridge_str)
				session:setVariable("my_fail_transfer_str_callwaiting","T-".."FXSWAITING${my_callwaiting_number} XML callwaiting")
				--@ END
			end
			--@ END

			--@ USER_BUSY
			if "Deactivate" ~= call_forward_busy_value then
				local busy_forward_succ = check_src_dest_is_match(src_chan_name,call_forward_busy_value,src_chan_name.." -> Extension ["..destination_display.."] Service [Busy Forward->"..call_forward_busy_value.."] Enabled,")
				if busy_forward_succ then
					session:consoleLog("info",src_chan_name.." -> Extension ["..destination_display.."] Service [Busy Forward->"..call_forward_busy_value.."] Enabled")
					if continue_on_fail_str == "" then
						continue_on_fail_str = "USER_BUSY"
					end
					session:setVariable("continue_on_fail",continue_on_fail_str)

					local dest_type = string.sub(call_forward_busy_value,1,3)
					if dest_type == "FXO" then
						local slot,port,dst = call_forward_busy_value:match("FXO/([0-9]+)/([0-9]+)/([0-9]+)")
						if slot and port and dst then
							session:setVariable("my_fail_bridge_str_userbusy","T-freetdm/"..slot.."/"..port.."/"..dst)
							if interface:match("1O") then
								session:setVariable("my_fail_bridge_channel_userbusy",cdr_dest_chan_name.."->FXO")
							else
								session:setVariable("my_fail_bridge_channel_userbusy",cdr_dest_chan_name.."->FXO Trunk/Port "..(port-1))
							end
						end
					elseif dest_type == "SIP" then
						local gw_name,dst = call_forward_busy_value:match("SIPT%-([0-9%_]+)/([0-9]+)")
						if gw_name and dst then
							session:setVariable("call_forward_busy_progress_time",endpoint_progress_time[gw_name] or call_forward_busy_progress_time or 55)
							session:setVariable("my_fail_bridge_channel_userbusy",cdr_dest_chan_name.."->"..sip_trunk_name[gw_name])

							session:setVariable("my_fail_bridge_str_userbusy","T-sofia/gateway/"..gw_name.."/"..dst)
						end
					elseif dest_type == "gsm" then
						local gsm_name,dst = call_forward_busy_value:match("gsmopen/([0-9a-zA-Z%-]+)/([0-9]+)")
						if gsm_name and dst and gsm_name:match("VOLTE") then
							session:setVariable("my_fail_bridge_str_userbusy","T-gsmopen/"..gsm_name.."/"..dst)
							session:setVariable("my_fail_bridge_channel_userbusy",cdr_dest_chan_name.."->VOLTE")
						elseif gsm_name and dst then
							session:setVariable("my_fail_bridge_str_userbusy","T-gsmopen/"..gsm_name.."/"..dst)
							session:setVariable("my_fail_bridge_channel_userbusy",cdr_dest_chan_name.."->GSM")
						end
					else
						session:setVariable("call_forward_busy_progress_time",endpoint_progress_time[call_forward_busy_value] or call_forward_busy_progress_time or 55)
						local ret_number = api:executeString("eval ${user_data("..call_forward_busy_value.."@${domain} attr id)}")
						if ret_number == call_forward_busy_value then
							session:setVariable("my_fail_transfer_str_userbusy","T-"..call_forward_busy_value.." XML extension")
						else
							session:setVariable("my_fail_transfer_str_userbusy","T-"..call_forward_busy_value.." XML public")
						end
					end
				end
			end
			--@ END

			--@ NO_ANSWER or NO_USER_RESPONSE
			if call_forward_noreply_value ~= "Deactivate" then
				local noreply_forward_succ = check_src_dest_is_match(src_chan_name,call_forward_noreply_value,src_chan_name.." -> Extension ["..destination_display.."] Service [NoReply Forward->"..call_forward_noreply_value.."] Enabled,")
				if noreply_forward_succ then
					session:consoleLog("info",src_chan_name.." -> Extension ["..destination_display.."] Service [NoReply Forward->"..call_forward_noreply_value.."] Enabled")
					if continue_on_fail_str == "" then
						continue_on_fail_str = "NO_ANSWER,NO_USER_RESPONSE"
					else
						continue_on_fail_str = continue_on_fail_str..",NO_ANSWER,NO_USER_RESPONSE"
					end
					session:setVariable("continue_on_fail",continue_on_fail_str)

					local dest_type = string.sub(call_forward_noreply_value,1,3)
					if dest_type == "FXO" then
						local slot,port,dst = call_forward_noreply_value:match("FXO/([0-9]+)/([0-9]+)/([0-9]+)")
						if slot and port and dst then
							session:setVariable("my_fail_bridge_str_noreply","T-freetdm/"..slot.."/"..port.."/"..dst)
							if interface:match("1O") then
								session:setVariable("my_fail_bridge_channel_noreply",cdr_dest_chan_name.."->FXO")
							else
								session:setVariable("my_fail_bridge_channel_noreply",cdr_dest_chan_name.."->FXO Trunk/Port "..(port-1))
							end
						end
					elseif dest_type == "SIP" then
						local gw_name,dst = call_forward_noreply_value:match("SIPT%-([0-9%_]+)/([0-9]+)")
						if gw_name and dst then
							--# set dest_chan_name
							session:setVariable("my_fail_bridge_channel_noreply",cdr_dest_chan_name.."->"..sip_trunk_name[gw_name])
							session:setVariable("call_forward_noreply_progress_time",endpoint_progress_time[gw_name] or call_forward_noreply_progress_time or 55)
							session:setVariable("my_fail_bridge_str_noreply","T-sofia/gateway/"..gw_name.."/"..dst)
						end
					elseif dest_type == "gsm" then
						local gsm_name,dst = call_forward_noreply_value:match("gsmopen/([0-9a-zA-Z%-]+)/([0-9]+)")
						if gsm_name and dst and gsm_name:match("VOLTE") then
							session:setVariable("my_fail_bridge_str_noreply","T-gsmopen/"..gsm_name.."/"..dst)
							session:setVariable("my_fail_bridge_channel_noreply",cdr_dest_chan_name.."->VOLTE")
						elseif gsm_name and dst then
							session:setVariable("my_fail_bridge_str_noreply","T-gsmopen/"..gsm_name.."/"..dst)
							session:setVariable("my_fail_bridge_channel_noreply",cdr_dest_chan_name.."->GSM")
						end
					else
						session:setVariable("call_forward_noreply_progress_time",endpoint_progress_time[call_forward_noreply_value] or call_forward_noreply_progress_time or 55)
						local ret_number = api:executeString("eval ${user_data("..call_forward_noreply_value.."@${domain} attr id)}")
						if ret_number == call_forward_noreply_value then
							session:setVariable("my_fail_transfer_str_noreply","T-"..call_forward_noreply_value.." XML extension")
						else
							session:setVariable("my_fail_transfer_str_noreply","T-"..call_forward_noreply_value.." XML public")
						end
					end
				end
			end
			--@ END

			--@ FAIL ROUTE
			local tmp = session:getVariable("transfer_name_on_fail")
			if tmp and fail_route_cause_str then
				if continue_on_fail_str == "" then
					continue_on_fail_str = fail_route_cause_str
				else
					continue_on_fail_str = continue_on_fail_str..","..fail_route_cause_str
				end
				session:setVariable("continue_on_fail",continue_on_fail_str)
				session:consoleLog("info",src_chan_name.." -> Extension ["..destination_display.."], setting transfer to failover route - ["..tmp.."]")
				session:setVariable("my_fail_transfer_str_failroute","T-"..tmp.." XML failroute")
			elseif channel_state_ret == "unregister" and call_forward_unregister_value == "Deactivate" then
				session:consoleLog("err","Extension not registered ! Ready to hangup !")
				session:hangup("USER_NOT_REGISTERED")
			end
			--@ END
		end	
	end
	local processed_destination = session:getVariable("processed_destination") or ""
	--为防止呼叫循环，这里将每一个曾经过的目的地记录下来，方便下一个目的地进行匹配判断是否循环了
	if "" == processed_destination then
		processed_destination = (session:getVariable("my_callwaiting_number") or bridge_str)..";"
	else
		processed_destination = processed_destination..(session:getVariable("my_callwaiting_number") or bridge_str)
	end

	session:setVariable("processed_destination",processed_destination)

	session:execute("transfer","ExtensionServiceBridge XML extension-service")
end
