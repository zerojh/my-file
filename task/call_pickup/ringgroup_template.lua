--@ Bridge to a RingGroup
local uci = require "uci".cursor()
local api = freeswitch.API()
local grp_id = 0
local strategy = "sequence"
local ringtime = 25

local bind_transfer_dtmf = ""
local attended_transfer_dtmf = ""

local bridge_members_tb = {}
local bridge_channel_tb = {}
local bridge_members_unconditional_forward_tb = {}
local bridge_members_busy_forward_tb = {}
local bridge_members_unregister_forward_tb = {}
local codec_list = {}
local sipuser_reg_query = {}
local extension_call_pickup = {}
local max_count = #bridge_members_tb
local processed_flag

local src_chan_name = session:getVariable("chan_name")
local fail_cause_bak = session:getVariable("continue_on_fail") or ""
session:setVariable("continue_on_fail","ALLOTTED_TIMEOUT") --if sip ext reply 183, need set continue_on_fail to go to next 

function split(str, pat, max, regex)
	pat = pat or "\n"
	max = max or #str

	local t = {}
	local c = 1

	if #str == 0 then
		return {""}
	end

	if #pat == 0 then
		return nil
	end

	if max == 0 then
		return str
	end

	repeat
		local s, e = str:find(pat, c, not regex)
		max = max - 1
		if s and max < 0 then
			t[#t+1] = str:sub(c)
		else
			t[#t+1] = str:sub(c, s and s - 1)
		end
		c = e and e + 1 or #str + 1
	until not s or max < 0

	return t
end

function compare_codec_param(idx,log_prefix)
	if src_chan_name:match("^sofia/") then
		local caller_codec = session:getVariable("ep_codec_string")
		local caller_codec_tbl = split(caller_codec,",")
		for k = #caller_codec_tbl,1,-1 do
			local codec = caller_codec_tbl[k]:match("^(%w+)@") or "NULL"
			if not string.find(codec_list[idx],codec) then
				table.remove(caller_codec_tbl,k)
			end
		end
		local codec_string = table.concat(caller_codec_tbl,",")
		session:consoleLog("info",log_prefix.." compare codec: caller["..caller_codec.."] vs called["..codec_list[idx].."]")
		session:consoleLog("info",log_prefix.." compare result: "..codec_string)
		return codec_string
	else
		return codec_list[idx]
	end
end

function set_fax_param(pstn_app,sip_app)
	session:execute(pstn_app,"execute_on_fax_end=myfax_fax_stop")
	session:execute(pstn_app,"execute_on_fax_detect=myfax_fax_start request peer")

	session:execute(sip_app,"fax_enable_t30_request=true")
	session:execute(sip_app,"sip_execute_on_t30=myfax_fax_start t30 self")

	session:execute(sip_app,"fax_enable_t38_request=true")
	session:execute(sip_app,"sip_execute_on_image=myfax_fax_start t38 self")
end

--@ check 
function check_channel_idle_state(bridge_param)
	if bridge_param and bridge_param:match("^freetdm/") then
		local slot,port = bridge_param:match("^freetdm/([0-9]+)/([1|2])")
		local cmd_str
		if slot and port then
			cmd_str = "ftdm channel_idle "..(tonumber(slot)-1).." "..(tonumber(port)-1)
		end

		if cmd_str then
			local reply_str = api:executeString(cmd_str)
			if reply_str and string.find(reply_str,"true") then
				return "idle"
			else
				return "busy"
			end
		end
	elseif bridge_param and bridge_param:match("user/") then
		local user_number = bridge_param:match("user/([0-9a-zA-Z]+)") or ""
		if "1" == api:executeString("hash select/currentcall/"..user_number) then
			return "busy"
		end

		local ret = api:executeString(sipuser_reg_query[user_number] or "")
		if ret and ret:match("User:%s*"..user_number) then
			return "idle"
		else
			return "unregister"
		end
	end
end

function check_src_dest_is_match(src_chan_name,dst_chan_name,error_prefix)
	if (not src_chan_name) or (not dst_chan_name) then
		return false
	end

	if (src_chan_name:match("FreeTDM") and dst_chan_name:match("user/")) or (src_chan_name:match("sofia") and dst_chan_name:match("freetdm")) or src_chan_name:match("sofia/gateway") then
		return true
	elseif src_chan_name:match("FreeTDM") and dst_chan_name:match("freetdm") then
		local src_slot,src_port = src_chan_name:match("FreeTDM/(%d+):(%d+)")
		local dst_slot,dst_port = dst_chan_name:match("^freetdm/([0-9]+)/([1|2])")
		if src_slot == dst_slot and src_port == dst_port then
			session:consoleLog("notice",error_prefix.." target member is same with caller, ignore...")
			return false
		else
			return true
		end
	elseif src_chan_name:match("sofia") and dst_chan_name:match("user") then
		local src_extension = src_chan_name:match("sofia/user/([0-9a-zA-Z]+)/") or "unknown"
		local dst_extension = dst_chan_name:match("user/([0-9a-zA-Z]+)") or "unknown"
		if src_extension == dst_extension then
			session:consoleLog("notice",error_prefix.." target member is same with caller, ignore...")
			return false
		else
			return true
		end
	end
end

--@ Bridge by strategy
if session:ready() then
	--@ set for pickup
	session:execute("hash","insert/callgroup/"..grp_id.."/${uuid}")
	local last_hangup_flag = true
	local all_avail = true
	local old_timeout
	local domain_name = session:getVariable("domain_name")
	local intercept = "false"
	
	--@ set ringtime
	if ringtime ~= "0" then
		old_timeout = session:getVariable("call_timeout")
		session:setVariable("call_timeout",ringtime)
		session:setVariable("bridge_answer_timeout",ringtime)
		session:execute("export","originate_timeout="..ringtime)
		session:execute("export","progress_timeout="..ringtime)
	end
	
	session:execute("set","force_transfer_context=public")
	session:execute("export","force_transfer_context=public")
	session:execute("set","sip_redirect_context=public")
	session:execute("export","sip_redirect_context=public")
	if "" ~= bind_meta_app then
		session:execute("bind_meta_app",bind_transfer_dtmf.." b is execute_extension::blind_transfer XML transfer")
	end
	if "" ~= attended_transfer_dtmf then
		session:execute("bind_meta_app",attended_transfer_dtmf.." b ib execute_extension::att_xfer XML transfer")
	end

	if strategy == "simultaneous" then
		local bridge_exp = ""
		local my_dst_number = session:getVariable("my_dst_number") or ""
		local in_bridge_flag = {}
		local multi_target_call = false
		local hash_member = {}
		for k,v in pairs(bridge_members_tb) do
			local selected_member = v
			local target = selected_member
			local target_status
			local log_prefix = src_chan_name.." -> RingGroup/"..grp_id.."/"..strategy.."->index:"..k.."/"..max_count.." ["..selected_member.."]"
			local log_prefix_forward = log_prefix
			if bridge_members_unconditional_forward_tb[selected_member] then
				target = bridge_members_unconditional_forward_tb[selected_member]
				target_status = check_channel_idle_state(target)
				log_prefix_forward = log_prefix.." [unconditional forward]->"..target
				session:consoleLog("info",log_prefix_forward..",status:"..target_status)
			else
				target_status = check_channel_idle_state(target)
				if "busy" == target_status and bridge_members_busy_forward_tb[selected_member] then
					target = bridge_members_busy_forward_tb[selected_member]
					target_status = check_channel_idle_state(target)
					log_prefix_forward = log_prefix.." [busy forward]->"..target
					session:consoleLog("info",log_prefix_forward..",status:"..target_status)
				elseif "unregister" == target_status and bridge_members_unregister_forward_tb[selected_member] then
					target = bridge_members_unregister_forward_tb[selected_member]
					target_status = check_channel_idle_state(target)
					log_prefix_forward = log_prefix.." [unregister forward]->"..target
					session:consoleLog("info",log_prefix_forward..",status:"..target_status)
				else
					session:consoleLog("debug",log_prefix.." ,status:"..target_status)
				end
			end

			if check_src_dest_is_match(src_chan_name,target,log_prefix_forward) and "idle" == target_status and (not in_bridge_flag[target]) then
				if target:match("^freetdm/") then
					local slot,port,called_number = target:match("^freetdm/([0-9]+)/([1|2])/([0-9]+)")
					if slot and port and called_number then
						if extension_call_pickup[called_number] ~= "off" then
							session:execute("hash","insert/callgroup/U-"..called_number.."/${uuid}")
							hash_member[#hash_member+1] = called_number
						end
						if bridge_exp == "" then
							bridge_exp = "freetdm/"..slot.."/"..port.."/"..my_dst_number
						else
							bridge_exp = bridge_exp..",".."freetdm/"..slot.."/"..port.."/"..my_dst_number
						end
					end
				else
					local extension_number = target:match("user/([0-9a-zA-Z]+)")
					local bypass_media_var = "[^^#absolute_codec_string="..compare_codec_param(extension_number,log_prefix).."]"

					if bridge_exp == "" then
						bridge_exp = bypass_media_var.."user/"..extension_number.."@"..domain_name
					else
						multi_target_call = true
						bridge_exp = bridge_exp..","..bypass_media_var.."user/"..target:match("user/([0-9a-zA-Z]+)").."@"..domain_name
					end
				end
				in_bridge_flag[target] = true
			end
		end

		--session:setVariable("my_group_bridge_str",bridge_exp)--@ bridge_str
		--@ 20150117 harlan
		--@ bridge in lua scritps for ringgroup
		if "" ~= bridge_exp then
			if multi_target_call then
				session:setVariable("multi_target_call","true")
			end
			session:consoleLog("info",src_chan_name.." -> RingGroup/"..grp_id.."/"..strategy.." ready to call "..bridge_exp)
			local bridge_session = freeswitch.Session(bridge_exp,session)
			session:setVariable("dest_chan_name","Ringgroup/"..grp_id)
			freeswitch.bridge(session,bridge_session)
			processed_flag=true
		end

		if next(hash_member) then
			for _,v in pairs(hash_member) do
				session:execute("hash","insert/callgroup/U-"..v.."/${uuid}")
			end
		end
	elseif "random" == strategy or "sequence" == strategy or "loop_sequence" == strategy then
		local max_index = max_count
		local index = 1
		local count = 1

		if "random" == strategy then
			local current_time = os.time()
			index = tonumber(current_time % max_index) + 1
		elseif "loop_sequence" == strategy then
			local reply_str = api:executeString("hash select/ringgroup/"..grp_id)
			if reply_str == "" then
				index = 1
			else
				index = tonumber(reply_str)
			end
			if (index + 1) > max_index then
				session:execute("hash","insert/ringgroup/"..grp_id.."/1")
			else
				session:execute("hash","insert/ringgroup/"..grp_id.."/"..(index + 1))
			end
		end

		for i=0,max_count do
			if count <= max_index then
				local selected_member = bridge_members_tb[index]
				local target = selected_member
				local target_status
				local log_prefix = src_chan_name.." -> RingGroup/"..grp_id.."/"..strategy.."->index:"..index.."/"..max_count.." ["..selected_member.."]"
				local log_prefix_forward = log_prefix

				if bridge_members_unconditional_forward_tb[selected_member] then
					target = bridge_members_unconditional_forward_tb[selected_member]
					target_status = check_channel_idle_state(target)
					log_prefix_forward = log_prefix.." [unconditional forward]->"..target
					session:consoleLog("info",log_prefix.." [unconditional forward]->"..target..",status:"..target_status)
				else
					target_status = check_channel_idle_state(target)
					if "busy" == target_status and bridge_members_busy_forward_tb[selected_member] then
						target = bridge_members_busy_forward_tb[selected_member]
						target_status = check_channel_idle_state(target)
						log_prefix_forward = log_prefix.." [busy forward]->"..target
						session:consoleLog("info",log_prefix_forward..",status:"..target_status)
					elseif "unregister" == target_status and bridge_members_unregister_forward_tb[selected_member] then
						target = bridge_members_unregister_forward_tb[selected_member]
						target_status = check_channel_idle_state(target)
						log_prefix_forward = log_prefix.." [unregister forward]->"..target
						session:consoleLog("info",log_prefix_forward..",status:"..target_status)
					else
						session:consoleLog("debug",log_prefix.." ,status:"..target_status)
					end
				end

				if check_src_dest_is_match(src_chan_name,target,log_prefix_forward) and "idle" == target_status then
					local extension_number
					local bridge_exp
					
					if target:match("user/") then
						extension_number = target:match("user/([0-9a-zA-Z]+)") or "unknown"
						--@ set fax for fxso/sip
						if src_chan_name:match("^FreeTDM/") then
							set_fax_param("set","export")
						end
						bridge_exp = target.."@"..domain_name
						if codec_list[extension_number] then
							session:execute("export","nolocal:absolute_codec_string="..compare_codec_param(extension_number,log_prefix))
						end
						session:execute("limit","hash sofia_extension max_call 8 !USER_BUSY")
						session:execute("export","nolocal:session_in_hangup_hook=true")
						session:execute("export","nolocal:api_on_answer=hash insert/currentcall/"..extension_number.."/1")
						session:execute("export","nolocal:api_hangup_hook=hash delete/currentcall/"..extension_number)
						session:execute("export","nolocal:api_reporting_hook=hash delete/currentcall/"..extension_number)
					else
						local tmp_slot,tmp_port
						tmp_slot,tmp_port,extension_number = target:match("^freetdm/([0-9]+)/([1|2])/([0-9]+)")
						local my_dst_number = session:getVariable("my_dst_number") or ""
						bridge_exp = "freetdm/"..tmp_slot.."/"..tmp_port.."/"..my_dst_number
						--@ set fax for fxso/sip
						if src_chan_name:match("^sofia/") then
							set_fax_param("export","set")
						end
					end

					if extension_number and bridge_exp then
						--@ check my_dst_number
						if session:getVariable("my_dst_number") == "IVRDIAL" then
							session:setVariable("my_dst_number",extension_number)
						end
						
						if extension_call_pickup[extension_number] ~= "off" then
							session:execute("hash","insert/callgroup/U-"..extension_number.."/${uuid}")
						end
						session:setVariable("dest_chan_name",bridge_channel_tb[index])
						--#refresh channel var
						session:execute("unset","last_bridge_hangup_cause")
						session:execute("unset","hangup_cause")
						session:setVariable("continue_on_fail","ALLOTTED_TIMEOUT")
						session:consoleLog("info",log_prefix.." ready to call "..bridge_exp)

						local bridge_session = freeswitch.Session(bridge_exp,session)
						freeswitch.bridge(session,bridge_session)
						processed_flag=true

						if extension_call_pickup[extension_number] ~= "off" then
							session:execute("hash","delete/callgroup/U-"..extension_number)
						end
						local hangup_cause = bridge_session:getVariable("hangup_cause")
						hangup_cause = ("" == hangup_cause) and bridge_session:hangupCause() or hangup_cause
						intercept = session:getVariable("intercept") or "false"
						freeswitch.consoleLog("notice",log_prefix.." "..target.." --HANGUP_CAUSE--[["..(hangup_cause or "nil").."]]---")
						if (hangup_cause == "USER_BUSY" or hangup_cause == "TIMEOUT" or hangup_cause == "NO_ANSWER" or hangup_cause == "NO_USER_RESPONSE" or hangup_cause == "ALLOTTED_TIMEOUT") and intercept == "false" then
							--@ continue
							last_hangup_flag = false
						elseif hangup_cause == "PICKED_OFF" or intercept == "true" then
							return
						else
							last_hangup_flag = true
							break
						end
					end
				
					--@ next one
					if index == max_index then
						index = 1
						count = count + 1
					else
						index = index + 1
						count = count + 1
					end
				else
					--@ next one
					if index == max_index then
						index = 1
						count = count + 1
					else
						index = index + 1
						count = count + 1
					end
				end
			else
				all_avail = false
				break
			end
		end
	end
end
--@ reset old call_timeout
if old_timeout then
	session:setVariable("call_timeout",old_timeout)
	session:setVariable("bridge_answer_timeout",old_timeout)
	session:execute("export","originate_timeout="..old_timeout)
	session:execute("export","progress_timeout="..old_timeout)
end
if "" ~= fail_cause_bak then
	session:setVariable("continue_on_fail",fail_cause_bak)
end
local transfer_name_on_fail = session:getVariable("transfer_name_on_fail")
local blind_transfer_val = session:getVariable("blind_transfer_val") or "false"
local att_transfer_val = session:getVariable("att_transfer_val") or "false"
local redirect_transfer_val = session:getVariable("redirect_transfer_val") or "false"
-- transfer, give up fail continue and hangup
if blind_transfer_val ~= "true" and att_transfer_val ~= "true" and redirect_transfer_val ~= "true" then
	if transfer_name_on_fail and (last_hangup_flag == false or (not all_avail and fail_cause_bak:match("REQUESTED_CHAN_UNAVAIL"))) then
		session:consoleLog("info",src_chan_name.." can not find available dest in ringgrp["..grp_id.."],ready tranfer to "..transfer_name_on_fail)
		session:execute("transfer",transfer_name_on_fail.." XML failroute")
	else
		if processed_flag then
			return
		end
		if src_chan_name:match("^sofia") then
			session:preAnswer()
		else
			session:answer()
		end
		local sound_dir = "/etc/freeswitch/sounds/en/us/callie"

		if uci:get("callcontrol","voice","lang") == "en" then
		    sound_dir = "/etc/freeswitch/sounds/en/us/callie"
		else
			sound_dir = "/etc/freeswitch/sounds/zh/cn/callie"
		end
		local read_codec = session:getVariable("read_codec")

		if read_codec ~= "PCMA" and read_codec ~= "PCMU" and read_codec ~= "G723" and read_codec ~= "G729" then
			read_codec = "PCMA"
	    end
		
		session:sleep(500)

		for i=1,2 do
			session:execute("playback",sound_dir.."/line_busy."..read_codec)
			session:sleep(1000)
		end

		session:hangup("REQUESTED_CHAN_UNAVAIL")
	end
end
