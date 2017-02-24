
local api = freeswitch.API()
local uci = require "uci".cursor()

local bridge_str = argv[1]
local forwarding_type = argv[2]
--local fw_uncondition_tb = {}
local fw_uncondition_tb = {["1001"]={{["1"]="1002"}}}
--local fw_uncondition_tb = {["1001"]={{["1"]="1002",["2"]="1"},{["1"]="1002",["2"]="2"},{["1"]="1003",["2"]="3"}}}
local fw_unregister_tb = {}
local fw_userbusy_tb = {}
local fw_noreply_tb = {}
local fw_noreplay_timeout_tb = {}
local fw_tb = {}
local endpoint_interface = {}
local time_tb = {["1"]={["wday"]="12345",["date"]={["1485878400"]="1485964800"},["time"]={["0"]="86399"}}}
--local time_tb = {["1"]={["wday"]="12345",["date"]={["1485878400"]="1485964800",["1486051200"]="1486137600"},["time"]={["0"]="86399"}}}
--local time_tb = {["1"]={["wday"]="12345",["date"]={["1485878400"]="1485964800",["1486051200"]="1486137600"},["time"]={["0"]="86399"}},["2"]={["wday"]="126",["date"]={["1486224000"]="1486310400",["1486396800"]="1486483200"},["time"]={["0"]="43199",["54000"]="82799"}},["3"]={["wday"]="345",["date"]={["1486569600"]="1486656000",["1486742400"]="1486828800"},["time"]={["0"]="86399"}}}
--@ endpoint_fxso or endpoint_sipphone
local sipuser_reg_query = {}

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

if forwarding_type == "uncondition" then
	fw_tb = fw_uncondition_tb[destidx]
elseif forwarding_type == "unregister" then
	fw_tb = fw_unregister_tb[destidx]
elseif forwarding_type == "userbusy" then
	fw_tb = fw_busy_tb[destidx]
elseif forwarding == "noreply" then
	fw_tb = fw_noreply_tb[destidx]
else
	session:hangup()
	return
end

if forwarding_type == "noreplay" then
	session:setVariable("call_timeout", fw_noreply_timeout_tb[destidx] or "20")
	session:setVariable("bridge_answer_timeout", fw_noreply_timeout_tb[destidx] or "20")
else
	session:setVariable("call_timeout", "55")
	session:setVariable("bridge_answer_timeout", "55")
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
	local fw_proxy_media_flag = false
	local fw_bypass_media_flag = false
	local last_hangup_flag = true

	for k,v in pairs(fw_tb) do
		local destination,time,number = v[1],v[2],v[3]
		local flag = false
		if not time then
			flag = true
		end

		if flag then
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
				local tmp_string = api:executeString("eval ${user_data("..destination.."@${domain} param dial_string)}")
				if tmp_string:match("user/") then
					tmp_string = tmp_string:match("(user/%d+)")
					if tmp_string then
						dial_string = tmp_string.."@"
					end
				elseif tmp_string:match("freedtm") then
				end
			end

			if call_forwarding_str and check_channel_idle_state(call_forwarding_str) then
				local bridge_session = freeswitch.Session(call_forwarding_str,session)
				if bridge_session:ready() then
					freeswitch.bridge(session,bridge_session)
				end

				local hangup_cause = bridge_session:getVariable("hangup_cause")
				if (hangup_cause == "USER_BUSY" or hangup_cause == "TIMEOUT" or hangup_cause == "NO_ANSWER" or hangup_cause == "NO_USER_RESPONSE" or hangup_cause == "ALLOTTED_TIMEOUT") and intercept == "false" then
					--@ continue
					last_hangup_flag = false
				elseif hangup_cause == "PICKED_OFF" then
					return
				else
					last_hangup_flag = true
					break
				end
			end
		end
	end
end
