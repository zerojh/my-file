
local api = freeswitch.API()
local uci = require "uci".cursor()

local now_epoch = os.time()
local now_time_tb = os.date("*t",now_epoch) or {}
local now_minute = tonumber(now_time_tb.hour) * 60 + tonumber(now_time_tb.min)

local bridge_str = argv[1]
local forward_type = argv[2]
local forward_uncondition_tb = {}
local forward_unregister_tb = {}
local forward_busy_tb = {}
local forward_noreply_tb = {}
local forward_noreply_timeout_tb = {}
local sipuser_reg_query = {}
local endpoint_interface = {}
--@ endpoint_fxso or endpoint_sipphone

local profile_time_tb = {}
local profile_time_check_tb = {}

if not bridge_str or not forward_type then
	--@ Error Log
	return
end

local bridge_type = bridge_str:match("([a-z]+)/.*")
local destidx
if bridge_type == "freetdm" then
	local slot_port = bridge_str:match("freetdm/([0-9]+/[0-9]+)/")
	if slot_port then
		destidx = slot_port
	else
		session:hangup()
		return
	end
elseif bridge_str:match("user/")  then
	local user = bridge_str:match("user/([0-9]+)@")
	if user then
		destidx = user
	else
		session:hangup()
		return
	end
end

local current_forward_tb = {}
if forward_type == "uncondition" then
	current_forward_tb = forward_uncondition_tb[destidx]
elseif forward_type == "unregister" then
	current_forward_tb = forward_unregister_tb[destidx]
elseif forward_type == "userbusy" then
	current_forward_tb = forward_busy_tb[destidx]
else
	current_forward_tb = forward_noreply_tb[destidx]
end

if forward_type == "noreply" then
	session:setVariable("call_timeout", forward_noreply_timeout_tb[destidx] or "20")
	session:setVariable("bridge_answer_timeout", forward_noreply_timeout_tb[destidx] or "20")
else
	session:setVariable("call_timeout", "55")
	session:setVariable("bridge_answer_timeout", "55")
end

-- check date
function check_date(idx,tb)
	local ret = true

	if not tb then
		return "false"
	else
		if not profile_time_check_tb[idx] then
			if ret and tb.wday then
				local wday = tb.wday
				if not wday:match(now_time_tb.wday) then
					ret = false
				end
			end

			if ret and tb.date then
				local check_flag = false
				for k,v in pairs(tb.date) do
					if v then
						local min_y,min_m,min_d,max_y,max_m,max_d = v:match("(%d+)-(%d+)-(%d+)~(%d+)-(%d+)-(%d+)")
						if min_y then
							local min_epoch = os.time({year=min_y, month=min_m, day=min_d, hour="0", min="0", sec="0"})
							local max_epoch = os.time({year=max_y, month=max_m, day=max_d, hour="23", min="59", sec="59"})
							if now_epoch >= min_epoch and now_epoch <= max_epoch then
								check_flag = true
								break
							end
						end
					end
				end
				ret = check_flag
			end

			if ret and tb.time then
				local check_flag = false
				for k,v in pairs(tb.time) do
					if v then
						local min_h,min_m,max_h,max_m = v:match("(%d+):(%d+)~(%d+):(%d+)")
						if min_h then
							local min_minute = tonumber(min_h) * 60 + tonumber(min_m)
							local max_minute = tonumber(max_h) * 60 + tonumber(max_m)
							if now_minute >= min_minute and now_minute <= max_minute then
								check_flag = true
								break
							end
						end
					end
				end
				ret = check_flag
			end
			profile_time_check_tb[idx] = tostring(ret)
		end
	end

	return profile_time_check_tb[idx]
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
		--@ sip trunk
		elseif bridge_param:match("sofia/") then
			local gw_number = bridge_param:match("sofia/gateway/([0-9%_]+)") or ""

			local reply_str = api:executeString("sofia status gateway "..gw_number)
			if reply_str and reply_str:match("Status%s*UP") then
				return true
			else
				return false
			end
		--@ sip extension
		elseif bridge_param:match("user/") then
			local user_number = bridge_param:match("user/([0-9a-zA-Z]+)") or ""
			if "1" == api:executeString("hash select/currentcall/"..user_number) then
				return false
			end

			local ret = api:executeString(sipuser_reg_query[user_number] or "")
			if ret and ret:match("User:%s*"..user_number) then
				return true
			else
				return false
			end
		else
			return false
		end

		if cmd_str then
			local reply_str = api:executeString(cmd_str)
			if reply_str and string.find(reply_str,"true") then
				return true
			else
				return false
			end
		end
	end
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
	local last_hangup_flag = false

	session:setVariable("my_fail_fw_uncondition_flag","false")
	session:setVariable("my_fail_fw_unregister_flag","false")
	session:setVariable("my_fail_fw_userbusy_flag","false")
	session:setVariable("my_fail_fw_noreply_flag","false")

	for k,v in pairs(current_forward_tb) do
		local destination,time,number = v[1],v[2],v[3]
		local continue_flag = false
		if not time or time == "" then
			freeswitch.consoleLog("info", "The destination can be called in any time: "..destination)
			last_hangup_flag = true
		elseif check_date(time, profile_time_tb[time]) == "true" then
			continue_flag = true
			freeswitch.consoleLog("info", "The destination can be called during this time: "..destination)
		else
			freeswitch.consoleLog("info", "The destination can not be called during this time: "..destination)
		end

		if continue_flag or last_hangup_flag then
			local tmp_str = string.sub(destination,1,3)
			local call_forward_str

			if tmp_str == "FXO"  then
				local slot,port = destination:match("FXO/([0-9]+)/([0-9]+)")
				if slot and port and number then
					call_forward_str = "freetdm/"..slot.."/"..port.."/"..number
					if check_channel_idle_state(call_forward_str) then
						session:setVariable("dest_chan_name","FXO")
						session:setVariable("bypass_media","false")
						session:setVariable("proxy_media","false")
					else
						freeswitch.consoleLog("info","channel "..call_forward_str.." is not idle")
						call_forward_str = nil
					end
				else
					freeswitch.consoleLog("debug","FXO dial_string error: freedtm/"..(slot or "unknown").."/"..(port or "unknown").."/"..(number or "unknown"))
				end
			elseif tmp_str == "SIP" then
				local gw_name = destination:match("SIPT%-([0-9%_]+)")
				if gw_name and number then
					call_forward_str = "sofia/gateway/"..gw_name.."/"..number
					if check_channel_idle_state(call_forward_str) then
						session:setVariable("dest_chan_name","SIP Trunk/"..get_siptrunk_uci_name(gw_name))
						if forward_type == "userbusy" or forward_type == "noreply" then
							-- userbusy, noreply
							local from = session:getVariable("chan_name")
							if from:match("^sofia/") then
								local from_name = from:match("^sofia/gateway/(.*)/") or from:match("^sofia/user/(%d+)") or "unknown"
								if endpoint_interface[from_name] == endpoint_interface[gw_name] and "LAN" == endpoint_interface[from_name] then
									session:setVariable("bypass_media","true")
									session:setVariable("proxy_media","false")
								else
									session:setVariable("bypass_media","false")
									session:setVariable("proxy_media","true")
								end
							else
								session:setVariable("bypass_media","false")
								session:setVariable("proxy_media","false")
							end
						end
					else
						freeswitch.consoleLog("info","channel "..call_forward_str.." is not idle")
						call_forward_str = nil
					end
				else
					freeswitch.consoleLog("debug","SIP trunk dial_string error: sofia/gateway/"..(gw_name or "unknown").."/"..(number or "unknown"))
				end
			elseif tmp_str == "gsm" then
				local gsm_name = destination:match("gsmopen/([0-9a-zA-Z%-]+)")
				if gsm_name and number then
					call_forward_str = "gsmopen/"..gsm_name.."/"..number
					if check_channel_idle_state(call_forward_str) then
						session:setVariable("dest_chan_name","GSM")
						session:setVariable("bypass_media","false")
						session:setVariable("proxy_media","false")
					else
						freeswitch.consoleLog("info","channel "..call_forward_str.." is not idle")
						call_forward_str = nil
					end
				else
					freeswitch.consoleLog("debug","GSM dial_string error: gsmopen/"..(gsm_name or "unknown").."/"..(number or "unknown"))
				end
			else
				local tmp_string = api:executeString("eval ${user_data("..destination.."@${domain} param dial_string)}") or ""
				local domain = api:executeString("eval ${domain}") or ""
				if tmp_string:match("user/") then
					call_forward_str = tmp_string:match("(user/%d+)").."@"..domain
				elseif tmp_string:match("freetdm") then
					local callee_number = session:getVariable("my_dst_number") or ""
					call_forward_str = tmp_string:match("(freetdm/%d+/%d+/)")..callee_number
				end

				if call_forward_str and check_channel_idle_state(call_forward_str) then
					if tmp_string:match("user/") then
						session:setVariable("dest_chan_name","SIP Extension/"..destination)
					else
						session:setVariable("dest_chan_name","FXS")
					end
				elseif call_forward_str then
					freeswitch.consoleLog("info","channel "..call_forward_str.." is not idle")
					call_forward_str = nil
				end
			end

			if call_forward_str then
				session:execute("unset","last_bridge_hangup_cause")
				session:execute("unset","hangup_cause")
				session:execute("lua","set_sip_param.lua "..call_forward_str)

				local bridge_session = freeswitch.Session(call_forward_str,session)
				if bridge_session:ready() then
					freeswitch.bridge(session,bridge_session)
				end

				local hangup_cause = bridge_session:getVariable("hangup_cause")
				hangup_cause = ("" == hangup_cause) and bridge_session:hangupCause() or hangup_cause
				freeswitch.consoleLog("debug", "hangup_cause: "..(hangup_cause or "UNKNOWN"))
				if hangup_cause == "NORMAL_CLEARING" or hangup_cause == "SUCCESS" then
					last_hangup_flag = true
				end
			end

			if last_hangup_flag then
				break
			end
		end
	end
	local last_bridge_hangup_cause = session:getVariable("last_bridge_hangup_cause")
	if not last_bridge_hangup_cause then
		session:setVariable("last_bridge_hangup_cause","NO_ROUTE_DESTINATION")
	end
	session:execute("lua","continue_by_hangup_cause.lua Extension")
end
