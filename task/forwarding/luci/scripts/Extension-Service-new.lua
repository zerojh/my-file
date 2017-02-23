
local api = freeswitch.API()
local uci = require "uci".cursor()

local bridge_str = argv[1]
local sip_ex_tb = {}
local fxs_ex_tb = {}
local endpoint_interface = {}
--@ endpoint_fxso or endpoint_sipphone
local call_waiting_status = "Deactivate"
local call_notdisturb_status = "Deactivate"
local call_forward_unregister_status = "Deactivate"
local call_forward_uncondition_status = "Deactivate"
local call_forward_busy_status = "Deactivate"
local call_forward_noreply_status = "Deactivate"
--local call_foread_noreply_timeout = "20"
local sip_extension_reg_status_query=""

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

--@ extension_service
local bridge_type = bridge_str:match("([a-z]+)/.*")
if bridge_type == "freetdm" then
	local slot,port = bridge_str:match("freetdm/([0-9]+)/([0-9]+)/")
	if fxs_ex_tb[slot] then
		if port == "1" then
			call_waiting_status = fxs_ex_tb[slot]["waiting_1"] or "Deactivate"
			call_notdisturb_status = fxs_ex_tb[slot]["notdisturb_1"] or "Deactivate"
			call_forward_uncondition_status = fxs_ex_tb[slot]["forward_uncondition_1"] or "Deactivate"
			call_forward_busy_status = fxs_ex_tb[slot]["forward_busy_1"] or "Deactivate"
			call_forward_noreply_status = fxs_ex_tb[slot]["forward_noreply_1"] or "Deactivate"
			--call_foread_noreply_timeout = fxs_ex_tb[slot]["forward_noreply_timeout_1"] or "20"
		else
			call_waiting_status = fxs_ex_tb[slot]["waiting_2"] or "Deactivate"
			call_notdisturb_status = fxs_ex_tb[slot]["notdisturb_2"] or "Deactivate"
			call_forward_uncondition_status = fxs_ex_tb[slot]["forward_uncondition_2"] or "Deactivate"
			call_forward_busy_status = fxs_ex_tb[slot]["forward_busy_2"] or "Deactivate"
			call_forward_noreply_status = fxs_ex_tb[slot]["forward_noreply_2"] or "Deactivate"
			--call_foread_noreply_timeout = fxs_ex_tb[slot]["forward_noreply_timeout_2"] or "20"
		end
	end
elseif bridge_str:match("user/")  then
	local user = bridge_str:match("user/([0-9]+)@")
	if sip_ex_tb[user] then
		call_waiting_status = sip_ex_tb[user]["waiting"] or "Deactivate"
		call_notdisturb_status = sip_ex_tb[user]["notdisturb"] or "Deactivate"
		--sip_extension_reg_status_query = sip_ex_tb[user]["reg_query"] or ""
		call_forward_uncondition_status = sip_ex_tb[user]["forward_uncondition"] or "Deactivate"
		call_forward_unregister_status = sip_ex_tb[user]["forward_unregister"] or "Deactivate"
		call_forward_busy_status = sip_ex_tb[user]["forward_busy"] or "Deactivate"
		call_forward_noreply_status = sip_ex_tb[user]["forward_noreply"] or "Deactivate"
		--call_foread_noreply_timeout = sip_ex_tb[user]["forward_noreply_timeout"] or "20"
	end
end

for k,v in pairs(uci:get_all("feature_code")) do
	if v.index == "12" and v.status == "Enabled" and v.code then
		bind_transfer_dtmf = string.sub(v.code,2,string.len(v.code))
	elseif v.index == "13" and v.status == "Enabled" and v.code then
		attended_transfer_dtmf = string.sub(v.code,2,string.len(v.code))
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

if session:ready() then
	local blind_transfer_val = session:getVariable("blind_transfer_val") or "false"
	if blind_transfer_val == "true" then
		session:execute("set","ringback=${hold_music}")
	end

	session:execute("set","force_transfer_context=public")
	session:execute("export","force_transfer_context=public")
	session:execute("set","sip_redirect_context=public")
	session:execute("export","sip_redirect_context=public")

	session:setVariable("call_bypass_media_flag","false")
	session:setVariable("call_fw_uncond_bypass_media_flag","false")
	session:setVariable("call_fw_busy_bypass_media_flag","false")
	session:setVariable("call_fw_noreply_bypass_media_flag","false")

	session:setVariable("call_proxy_media_flag","false")
	session:setVariable("call_fw_uncond_proxy_media_flag","false")
	session:setVariable("call_fw_busy_proxy_media_flag","false")
	session:setVariable("call_fw_noreply_proxy_media_flag","false")

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
	local from = session:getVariable("chan_name")
	if bridge_str:match("freetdm/") and from:match("^sofia/") then
		session:execute("set","hangup_after_bridge=true")
		
		session:execute("export","execute_on_fax_end=myfax_fax_stop")
		session:execute("export","execute_on_fax_detect=myfax_fax_start request peer")
		
		session:execute("set","fax_enable_t38_request=true")
		session:execute("set","sip_execute_on_image=myfax_fax_start t38 self")

		session:execute("set","fax_enable_t30_request=true")
		session:execute("set","sip_execute_on_t30=myfax_fax_start t30 self")
	elseif bridge_str:match("user/")  and from:match("^FreeTDM") then
		session:execute("set","hangup_after_bridge=true")
		
		session:execute("set","execute_on_fax_end=myfax_fax_stop")
		session:execute("set","execute_on_fax_detect=myfax_fax_start request peer")
		
		session:execute("export","fax_enable_t38_request=true")
		session:execute("export","sip_execute_on_image=myfax_fax_start t38 self")

		session:execute("export","fax_enable_t30_request=true")
		session:execute("export","sip_execute_on_t30=myfax_fax_start t30 self")
	elseif bridge_str:match("user/") and from:match("^sofia") then
		local from_name = from:match("^sofia/gateway/([0-9%_]+)/") or from:match("^sofia/user/(%d+)") or "unknown"
		local bridge_name = bridge_str:match("user/(%d+)") or "unknown"
		if endpoint_interface[from_name] == endpoint_interface[bridge_name] and "LAN" == endpoint_interface[from_name] then
			session:setVariable("call_bypass_media_flag","true")
			session:setVariable("call_proxy_media_flag","false")
		else
			session:setVariable("call_proxy_media_flag","true")
		end
	end


	--@ set call_timeout for forward_noreply
	if call_forward_noreply_status === "Activate" then
		session:setVariable("my_fail_fw_noreply_flag","true")
		if not session:getVariable("call_timeout") then
			session:setVariable("call_timeout",call_foread_noreply_timeout)
			session:setVariable("bridge_answer_timeout",call_foread_noreply_timeout)
		end
	end
	--@ END
	
	--@ service of call_notdisturb 
	if call_notdisturb_status == "Activate" then
		session:consoleLog("info","ROUTING:service of call_notdisturb")	

		local tmp = session:getVariable("transfer_name_on_fail")
		if tmp and fail_route_cause_str and string.find(fail_route_cause_str,"USER_BUSY") then
			session:consoleLog("info","ROUTING:service of call_failed_routing - ["..tmp.."]")	
			session:setVariable("my_fail_transfer_str_failroute","T-"..tmp.." XML failroute")
		else
			session:consoleLog("info","ROUTING:Last Extension-Service")
			session:setVariable("hangup_cause","USER_BUSY")
			session:execute("lua","check_line_is_busy.lua")
			session:hangup("USER_BUSY")
		end
		--@ HERE IS ROUTING END
	else
		--@ take the first service,call_forward_uncondition
		if "Activate" == call_forward_uncondition_status then
			session:consoleLog("info","ROUTING:service of call_forward_uncondition")
			session:setVariable("my_fail_fw_uncondition_flag","true")
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

			if channel_state_ret == "unregister" then
				session:consoleLog("info","ROUTING:service of call_forward_unregister")
				session:setVariable("my_fail_fw_unregister_flag","true")
			elseif channel_state_ret == "true" then
				--@ Normal bridge action
				session:setVariable("my_success_bridge_str","T-"..bridge_str)
			elseif channel_state_ret == "calling" and call_waiting_status == "Activate" then
				--@ Here is for SIP callwaiting
				session:setVariable("my_fail_transfer_str_callwaiting","T-".."SIPWAITING${my_callwaiting_number} XML callwaiting")
				session:setVariable("my_callwaiting_bridge_str",bridge_str)
			elseif channel_state_ret == "waiting" and call_waiting_status == "Activate" then
				--@ CALL WAITING
				--@ Here is for FXS waiting
				--@ set callwaiting music
				if uci:get("callcontrol","voice","lang") == "en" then
					session:setVariable("my_callwaiting_music","/etc/freeswitch/sounds/en/us/callie/busy_waiting")
				else
					session:setVariable("my_callwaiting_music","/etc/freeswitch/sounds/zh/cn/callie/busy_waiting")
				end
				--@ set callwaiting bridge_str
				session:setVariable("my_callwaiting_bridge_str",bridge_str)
				session:setVariable("my_fail_transfer_str_callwaiting","T-".."FXSWAITING${my_callwaiting_number} XML callwaiting")
				--@ END
			end
			--@ END

			--@ USER_BUSY
			if "Activate" == call_forward_busy_status then
				if continue_on_fail_str == "" then
					continue_on_fail_str = "USER_BUSY"
				end
				session:setVariable("continue_on_fail",continue_on_fail_str)
				session:setVariable("my_fail_fw_userbusy_flag","true")
			end
			--@ END

			--@ NO_ANSWER or NO_USER_RESPONSE
			if call_forward_noreply_status == "Activate" then
				if continue_on_fail_str == "" then
					continue_on_fail_str = "NO_ANSWER,NO_USER_RESPONSE"
				else
					continue_on_fail_str = continue_on_fail_str..",NO_ANSWER,NO_USER_RESPONSE"
				end
				session:setVariable("continue_on_fail",continue_on_fail_str)
				session:setVariable("my_fail_fw_noreply_flag","true")
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
				
				session:consoleLog("debug","ROUTING:service of call_failed_routing - ["..tmp.."]")
				session:setVariable("my_fail_transfer_str_failroute","T-"..tmp.." XML failroute")
			elseif channel_state_ret == "unregister" and call_forward_unregister_value == "Deactivate" then
				session:consoleLog("err","Extension not registered ! Ready to hangup !")
				session:hangup("USER_NOT_REGISTERED")
			end
			--@ END
		end	
	end
	session:execute("transfer","ExtensionServiceBridge XML extension-service")
end
