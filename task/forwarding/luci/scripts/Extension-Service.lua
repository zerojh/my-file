--@ Extension service
--@ Version 1.0.0.1
--@ Date 2014.10.11
local api = freeswitch.API()
local uci = require "uci".cursor()

local bridge_str = argv[1]
local sip_ex_tb = {}
local fxs_ex_tb = {}
local endpoint_interface = {}
--@ endpoint_fxso or endpoint_sipphone
local call_waiting_status = "Deactivate"
local call_notdisturb_status = "Deactivate"
local call_forward_unregister_value = "Deactivate"
local call_forward_uncondition_value = "Deactivate"
local call_forward_busy_value = "Deactivate"
local call_forward_noreply_value = "Deactivate"
local call_foread_noreply_timeout = "20"
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
				call_foread_noreply_timeout = fxs_ex_tb[slot]["forward_noreply_timeout_1"] or "20"
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
				call_foread_noreply_timeout = fxs_ex_tb[slot]["forward_noreply_timeout_2"] or "20"
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
			call_foread_noreply_timeout = sip_ex_tb[user]["forward_noreply_timeout"] or "20"
		end
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

--@ get sip trunk uci name
function get_siptrunk_uci_name(param)
	local uci_tb = uci:get_all("endpoint_siptrunk") or {}
	local ret_name = "unknown"
	
	for k,v in pairs(uci_tb) do
		if v.name and v.profile and v.index and v.profile.."_"..v.index == param then
			ret_name = v.name
		end
	end

	return ret_name
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
	if call_forward_noreply_value ~= "Deactivate" then
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
		if "Deactivate" ~= call_forward_uncondition_value then
			session:consoleLog("info","ROUTING:service of call_forward_uncondition - ["..call_forward_uncondition_value.."]")

			local tmp_str = string.sub(call_forward_uncondition_value,1,3)
			if tmp_str == "FXO" then
				local slot,port,dst = call_forward_uncondition_value:match("FXO/([0-9]+)/([0-9]+)/([0-9]+)")
				if slot and port and dst then
					session:setVariable("my_fail_bridge_str_uncondition","T-freetdm/"..slot.."/"..port.."/"..dst)
					session:setVariable("my_fail_bridge_channel_uncondition","FXO")
				end
			elseif tmp_str == "SIP" then
				local gw_name,dst = call_forward_uncondition_value:match("SIPT%-([0-9%_]+)/([0-9]+)")
				if gw_name and dst then
					session:setVariable("my_fail_bridge_channel_uncondition",get_siptrunk_uci_name(gw_name))
					--@ judge whether from SIP
					-- if from:match("^sofia/") then
					-- 	local from_name = from:match("^sofia/gateway/(.*)/") or from:match("^sofia/user/(%d+)") or "unknown"
					-- 	if endpoint_interface[from_name] == endpoint_interface[gw_name] and "LAN" == endpoint_interface[from_name] then
					-- 		session:setVariable("call_fw_uncond_bypass_media_flag","true")
					-- 		session:setVariable("call_fw_uncond_proxy_media_flag","false")
					-- 	else
					-- 		session:setVariable("call_fw_uncond_bypass_media_flag","false")
					-- 		session:setVariable("call_fw_uncond_proxy_media_flag","true")
					-- 	end
					-- else
					-- 	session:setVariable("call_fw_unocnd_bypass_media_flag","false")
					-- 	session:setVariable("call_fw_unocnd_proxy_media_flag","false")
					-- end
					session:setVariable("my_fail_bridge_str_uncondition","T-sofia/gateway/"..gw_name.."/"..dst)
				end
			elseif tmp_str == "gsm" then
				local gsm_name,dst = call_forward_uncondition_value:match("gsmopen/([0-9a-zA-Z%-]+)/([0-9]+)")
				if gsm_name and dst then
					session:setVariable("my_fail_bridge_str_uncondition","T-gsmopen/"..gsm_name.."/"..dst)
					session:setVariable("my_fail_bridge_channel_uncondition","GSM")
				end
			else
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

			if channel_state_ret == "unregister" then
				session:consoleLog("info","ROUTING:service of call_forward_unregister - ["..call_forward_unregister_value.."]")

				local tmp_str = string.sub(call_forward_unregister_value,1,3)
				if tmp_str == "FXO" then
					local slot,port,dst = call_forward_unregister_value:match("FXO/([0-9]+)/([0-9]+)/([0-9]+)")
					if slot and port and dst then
						session:setVariable("my_fail_bridge_str_unregister","T-freetdm/"..slot.."/"..port.."/"..dst)
						session:setVariable("my_fail_bridge_channel_unregister","FXO")
					end
				elseif tmp_str == "SIP" then
					local gw_name,dst = call_forward_unregister_value:match("SIPT%-([0-9%_]+)/([0-9]+)")
					if gw_name and dst then
						session:setVariable("my_fail_bridge_channel_unregister",get_siptrunk_uci_name(gw_name))
						session:setVariable("my_fail_bridge_str_unregister","T-sofia/gateway/"..gw_name.."/"..dst)
					end
				elseif tmp_str == "gsm" then
					local gsm_name,dst = call_forward_unregister_value:match("gsmopen/([0-9a-zA-Z%-]+)/([0-9]+)")
					if gsm_name and dst then
						session:setVariable("my_fail_bridge_str_unregister","T-gsmopen/"..gsm_name.."/"..dst)
						session:setVariable("my_fail_bridge_channel_unregister","GSM")
					end
				elseif call_forward_unregister_value ~= "Deactivate" then
					local ret_number = api:executeString("eval ${user_data("..call_forward_unregister_value.."@${domain} attr id)}")
					if ret_number == call_forward_unregister_value then
						session:setVariable("my_fail_transfer_str_unregister","T-"..call_forward_unregister_value.." XML extension")
					else
						session:setVariable("my_fail_transfer_str_unregister","T-"..call_forward_unregister_value.." XML public")
					end
				end
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
			if "Deactivate" ~= call_forward_busy_value then
				if continue_on_fail_str == "" then
					continue_on_fail_str = "USER_BUSY"
				end
				session:setVariable("continue_on_fail",continue_on_fail_str)

				local tmp_str = string.sub(call_forward_busy_value,1,3)
				if tmp_str == "FXO" then
					local slot,port,dst = call_forward_busy_value:match("FXO/([0-9]+)/([0-9]+)/([0-9]+)")
					if slot and port and dst then
						session:setVariable("my_fail_bridge_str_userbusy","T-freetdm/"..slot.."/"..port.."/"..dst)
						session:setVariable("my_fail_bridge_channel_userbusy","FXO")
					end
				elseif tmp_str == "SIP" then
					local gw_name,dst = call_forward_busy_value:match("SIPT%-([0-9%_]+)/([0-9]+)")
					if gw_name and dst then
						session:setVariable("my_fail_bridge_channel_userbusy",get_siptrunk_uci_name(gw_name))
						if from:match("^sofia/") then
							if endpoint_interface[from_name] == endpoint_interface[gw_name] and "LAN" == endpoint_interface[from_name] then
								session:setVariable("call_fw_busy_bypass_media_flag","true")
								session:setVariable("call_fw_busy_proxy_media_flag","false")
							else
								session:setVariable("call_fw_busy_bypass_media_flag","false")
								session:setVariable("call_fw_busy_proxy_media_flag","true")
							end
						else
							session:setVariable("call_fw_busy_bypass_media_flag","false")
							session:setVariable("call_fw_busy_proxy_media_flag","false")
						end
						session:setVariable("my_fail_bridge_str_userbusy","T-sofia/gateway/"..gw_name.."/"..dst)
					end
				elseif tmp_str == "gsm" then
					local gsm_name,dst = call_forward_busy_value:match("gsmopen/([0-9a-zA-Z%-]+)/([0-9]+)")
					if gsm_name and dst then
						session:setVariable("my_fail_bridge_str_userbusy","T-gsmopen/"..gsm_name.."/"..dst)
						session:setVariable("my_fail_bridge_channel_userbusy","GSM")
					end
				else
					local ret_number = api:executeString("eval ${user_data("..call_forward_busy_value.."@${domain} attr id)}")
					if ret_number == call_forward_busy_value then
						session:setVariable("my_fail_transfer_str_userbusy","T-"..call_forward_busy_value.." XML extension")
					else
						session:setVariable("my_fail_transfer_str_userbusy","T-"..call_forward_busy_value.." XML public")
					end
				end
			end
			--@ END

			--@ NO_ANSWER or NO_USER_RESPONSE
			if call_forward_noreply_value ~= "Deactivate" then
				if continue_on_fail_str == "" then
					continue_on_fail_str = "NO_ANSWER,NO_USER_RESPONSE"
				else
					continue_on_fail_str = continue_on_fail_str..",NO_ANSWER,NO_USER_RESPONSE"
				end
				session:setVariable("continue_on_fail",continue_on_fail_str)

				local tmp_str = string.sub(call_forward_noreply_value,1,3)
				if tmp_str == "FXO" then
					local slot,port,dst = call_forward_noreply_value:match("FXO/([0-9]+)/([0-9]+)/([0-9]+)")
					if slot and port and dst then
						session:setVariable("my_fail_bridge_str_noreply","T-freetdm/"..slot.."/"..port.."/"..dst)
						session:setVariable("my_fail_bridge_channel_noreply","FXO")
					end
				elseif tmp_str == "SIP" then
					local gw_name,dst = call_forward_noreply_value:match("SIPT%-([0-9%_]+)/([0-9]+)")
					if gw_name and dst then
						--# set dest_chan_name
						session:setVariable("my_fail_bridge_channel_noreply",get_siptrunk_uci_name(gw_name))
						if from:match("^sofia/") then
							if endpoint_interface[from_name] == endpoint_interface[gw_name] and "LAN" == endpoint_interface[from_name] then
								session:setVariable("call_fw_noreply_bypass_media_flag","true")
								session:setVariable("call_fw_noreply_proxy_media_flag","false")
							else
								session:setVariable("call_fw_noreply_bypass_media_flag","false")
								session:setVariable("call_fw_noreply_proxy_media_flag","true")
							end
						else
							session:setVariable("call_fw_noreply_bypass_media_flag","false")
							session:setVariable("call_fw_noreply_proxy_media_flag","false")
						end
						session:setVariable("my_fail_bridge_str_noreply","T-sofia/gateway/"..gw_name.."/"..dst)
					end
				elseif tmp_str == "gsm" then
					local gsm_name,dst = call_forward_noreply_value:match("gsmopen/([0-9a-zA-Z%-]+)/([0-9]+)")
					if gsm_name and dst then
						session:setVariable("my_fail_bridge_str_noreply","T-gsmopen/"..gsm_name.."/"..dst)
						session:setVariable("my_fail_bridge_channel_noreply","GSM")
					end
				else
					local ret_number = api:executeString("eval ${user_data("..call_forward_noreply_value.."@${domain} attr id)}")
					if ret_number == call_forward_noreply_value then
						session:setVariable("my_fail_transfer_str_noreply","T-"..call_forward_noreply_value.." XML extension")
					else
						session:setVariable("my_fail_transfer_str_noreply","T-"..call_forward_noreply_value.." XML public")
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
