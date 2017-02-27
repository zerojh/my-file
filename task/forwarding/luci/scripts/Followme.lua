
local api = freeswitch.API()
local uci = require "uci".cursor()

local now_epoch = os.time()
local now_time_tb = os.date("*t",now_epoch) or {}
local now_minute = tonumber(now_time_tb.hour) * 60 + tonumber(now_time_tb.min)

local bridge_str = argv[1]
local forwarding_type = argv[2]
local forwarding_uncondition_tb = {["1001"]={{"1006","aa"},{"1007","bb"}}}
local forwarding_unregister_tb = {["1001"]={{"1006","aa"},{"1007","bb"}}}
local forwarding_busy_tb = {["1001"]={{"1006","aa"},{"1007","bb"}}}
local forwarding_noreply = {["1001"]={{"1006","aa"},{"1007","bb"}}}
local forwarding_noreply_timeout_tb = {["1001"]="20"}
local sipuser_reg_query = {["1006"]="sofia status profile 1 reg 1006",["1007"]="sofia status profile 1 reg 1007"}
local endpoint_interface = {}
--@ endpoint_fxso or endpoint_sipphone

local profile_time_tb = {}
local profile_time_check_tb = {}
profile_time_tb["aa"] = {wday="12345",date={"2017-02-10~2017-02-11","2017-02-18~2017-02-24"},time={"00:30~12:30","12:31~20:59"}}
profile_time_tb["bb"] = {wday="123",date={"2017-02-10~2017-02-11"},time={"00:30~12:30","12:31~20:59"}}

if not bridge_str or not forwarding_type then
	--@ Error Log
	return
end

local bridge_type = bridge_str:match("([a-z]+)/.*")
local destidx
if bridge_type == "freedtm" then
	session:hangup()
	return
elseif bridge_str:match("user/")  then
	local user = bridge_str:match("user/([0-9]+)@")
	if user then
		destidx = user
	else
		session:hangup()
		return
	end
end

local current_forwarding_tb = {}
if forwarding_type == "uncondition" then
	current_forwarding_tb = forwarding_uncondition_tb[destidx]
elseif forwarding_type == "unregister" then
	current_forwarding_tb = forwarding_unregister_tb[destidx]
elseif forwarding_type == "userbusy" then
	current_forwarding_tb = forwarding_busy_tb[destidx]
else
	current_forwarding_tb = forwarding_noreply_tb[destidx]
end

if forwarding_type == "noreply" then
	session:setVariable("call_timeout", forwarding_noreply_timeout_tb[destidx] or "20")
	session:setVariable("bridge_answer_timeout", forwarding_noreply_timeout_tb[destidx] or "20")
else
	session:setVariable("call_timeout", "55")
	session:setVariable("bridge_answer_timeout", "55")
end

-- check date
function check_date(idx,tb)
	local ret = true

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
	local last_hangup_flag = true

	for k,v in pairs(current_forwarding_tb) do
		local destination,time,number = v[1],v[2],v[3]
		local continue_flag = false
		local last_hangup_flag = false
		if not time then
			last_hangup_flag = true
		elseif check_date(time, profile_time_tb[time]) == "true" then
			continue_flag = true
		end

		if continue_flag or last_hangup_flag then
			local tmp_str = string.sub(destination,1,3)
			local dial_string
			if tmp_str == "FXO"  then
				local slot,port,dst = destination:match("FXO/([0-9]+)/([0-9]+)/([0-9]+)")
				session:setVariable("dest_chan_name","FXO")
				session:setVariable("bypass_media","false")
				session:setVariable("proxy_media","false")
				dial_string = "freetdm/"..slot.."/"..port.."/"..dst
			elseif tmp_str == "SIP" then
				local gw_name,dst = destination:match("SIPT%-([0-9%_]+)/([0-9]+)")
				if gw_name and dst then
					session:setVariable("dest_chan_name",get_siptrunk_uci_name(gw_name))
					if false then
						-- userbusy, noreply
						if from:match("^sofia/") then
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
					dial_string = "sofia/gateway/"..gw_name.."/"..dst
				end
			elseif tmp_str == "gsm" then
				local gsm_name,dst = destination:match("gsmopen/([0-9a-zA-Z%-]+)/([0-9]+)")
				if gsm_name and dst then
					session:setVariable("dest_chan_name","GSM")
					session:setVariable("bypass_media","false")
					session:setVariable("proxy_media","false")
					dial_string = "gsmopen/"..gsm_name.."/"..dst
				end
			else
				local tmp_string = api:executeString("eval ${user_data("..destination.."@${domain} param dial_string)}") or ""
				local domain = api:executeString("eval ${domain}") or ""
				if tmp_string:match("user/") then
					call_forwarding_str = tmp_string:match("(user/%d+)").."@"..domain
					session:setVariable("dest_chan_name","SIP Extension/"..destination)
				elseif tmp_string:match("freedtm") then
					local callee_number = session:getvariable("my_dst_number") or ""
					call_forwarding_str = tmp_string:match("(freetdm/%d+/%d+/)")..callee_number
					session:setVariable("dest_chan_name","FXS")
				end
			end

			if call_forwarding_str and check_channel_idle_state(call_forwarding_str) then
				local bridge_session = freeswitch.Session(call_forwarding_str,session)
				if bridge_session:ready() then
					freeswitch.bridge(session,bridge_session)
				end

				local hangup_cause = bridge_session:getVariable("hangup_cause")
				hangup_cause = ("" == hangup_cause) and bridge_session:hangupCause() or hangup_cause
				if not (hangup_cause == "USER_BUSY" or hangup_cause == "TIMEOUT" or hangup_cause == "NO_ANSWER" or hangup_cause == "NO_USER_RESPONSE" or hangup_cause == "ALLOTTED_TIMEOUT") then
					last_hangup_flag = true
				end
			end

			if last_hangup_flag then
				break
			end
		end
	end
end
