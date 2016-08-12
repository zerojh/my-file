local timeout =  10 * 1000
local repeat_loops = 3
local enable_extension = false
local max_fail_times = 3

local service_tb = {"1,Trunks,SIPT-2_1/1001","none,Trunks,SIPT-2_1/1001","2,Extensions,1005"}
local api = freeswitch.API()
local uci = require "uci".cursor()
local read_codec = ""
local ringgroup_tb = uci:get_all("endpoint_ringgroup") or {}

local sound_dir = "/etc/freeswitch/sounds/en/us/callie"
local sound_welcome = sound_dir.."/welcome."
local sound_no_user = sound_dir.."/no_user."

local chan_name = session:getVariable("chan_name")
local global_trunk_bridge_str 

if uci:get("callcontrol","voice","lang") == "cn" then
	sound_dir = "/etc/freeswitch/sounds/zh/cn/callie"
	sound_welcome = sound_dir.."/welcome."
	sound_no_user = sound_dir.."/no_user."
end

for k,v in pairs(uci:get_all("ivr")) do
	if v['.type'] == "ivr" then
		timeout = tonumber(v.timeout) * 1000
		repeat_loops = tonumber(v.repeat_loops)
		if v.enable_extension then
			enable_extension = true
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

function server_for_extension(digit)
	local ret_number = api:executeString("eval ${user_data("..digit.."@${domain} attr id)}")
	if ret_number == digit then
		session:setVariable("ringback",sound_dir.."/waiting_music")
		session:setVariable("my_dst_number",digit)
		session:setVariable("my_ivr_transfer_str","T-"..digit.." XML extension")
		return true
	else
		return false
	end
end

function get_destination_number(param)
	local read_codec = "PCMA"

	if chan_name:match("^sofia/") then
		read_codec = session:getVariable("rtp_use_codec_name")
	end
	
	session:sleep(500)
	local digits = session:playAndGetDigits(1,15,3,5000,"#",sound_dir.."/dial_tone."..read_codec,"","\\d+");
	
	if digits and digits ~= "" then
		session:consoleLog("debug","--GET DIGTIS:"..digits);
		session:setVariable("my_dst_number",digits)
		session:setVariable("my_ivr_bridge_str",param.."/"..digits)
	else
		session:hangup()	
	end
end

function server_for_menu_step_0()
	if max_fail_times <= 0 then
		--@ timeout actions
		if not server_for_menu_step_1("timeout") then
			session:hangup("NO_ROUTE_DESTINATION")
		end

		return 
	end
	local ret
	local digits = session:playAndGetDigits(1,1,repeat_loops,timeout,"",sound_welcome..read_codec,"","[0-9*#]");
	
	if digits and digits ~= "" then	
		session:consoleLog("debug","--GET DIGTIS:"..digits);
		ret = server_for_menu_step_1(digits)

		if enable_extension == true then
			if ret == false then
				--@ to sip trunk 
				if global_trunk_bridge_str then
					local tmp_dtmf = session:getDigits(15,"#",4000)
					if tmp_dtmf and tmp_dtmf ~= "" then
						session:setVariable("my_dst_number",digits..tmp_dtmf)
						session:setVariable("my_ivr_bridge_str",global_trunk_bridge_str.."/"..digits..tmp_dtmf)
						return true
					end
				else
					while true do
						local tmp_dtmf = session:getDigits(15,"#",4000)
						
						if tmp_dtmf and tmp_dtmf ~= "" then
							
							ret = server_for_extension(digits..tmp_dtmf)
							if ret == true then
								return 
							end
						end
						--@ fail count + 1
						session:execute("playback",sound_no_user..read_codec)
						session:sleep(1500)
						max_fail_times = max_fail_times - 1
						break
					end
					
					--@ continue to top
					server_for_menu_step_0()
				end
			end
		else
			if ret == false then
				--@ to sip trunk
				if global_trunk_bridge_str then
					session:consoleLog("debug","My 1")
					local tmp_dtmf = session:getDigits(15,"#",4000)
					session:consoleLog("debug","My 2 tmp_dtmf: "..tmp_dtmf)
					if tmp_dtmf and tmp_dtmf ~= "" then
						session:consoleLog("debug","My 3")
						session:setVariable("my_dst_number",digits..tmp_dtmf)
						session:setVariable("my_ivr_bridge_str",global_trunk_bridge_str.."/"..digits..tmp_dtmf)
						return true
					end
				else
					--@ fail count + 1
					session:execute("playback",sound_no_user..read_codec)
					session:sleep(1500)
					max_fail_times = max_fail_times - 1
					--@ continue to top
					server_for_menu_step_0()
				end
			end
		end
	else
		--@ timeout actions
		if not server_for_menu_step_1("timeout") then
			session:hangup("NO_ROUTE_DESTINATION")
		end
		
		return	
	end
end

function server_for_menu_step_1(digit)	
	for k,v in pairs(service_tb) do
		local dtmf,service_name,param = v:match("([a-z0-9%*#]+),(.*),(.*)")
		session:consoleLog("debug","--server_for_menu_step_1:"..dtmf.." vs "..digit.." "..service_name.." "..param);

		if dtmf == "none" then
			if param:match("^FXO/") then
				local slot,port = param:match("FXO/([0-9]+)/([0-9]+)")
				global_trunk_bridge_str = "T-freetdm/"..slot.."/"..port
			elseif param:match("^gsmopen/") then
				local slot_name = param:match("gsmopen/([0-9A-Z%-]+)")
				global_trunk_bridge_str = "T-gsmopen/"..slot_name
			elseif param:match("^SIPT") then
				local gw_name = param:match("SIPT%-([0-9%_%-FXSOGMCD]+)/")
				global_trunk_bridge_str = "T-sofia/gateway/"..gw_name
				session:setVariable("ringback",sound_dir.."/waiting_music")
			end
		end
		
		if dtmf == digit then

			if service_name == "Extensions" then
				local bridge_exp = api:executeString("eval ${user_data("..param.."@${domain} param dial_string)}")

				session:setVariable("my_exten_bridge_param",tostring(string.gsub(bridge_exp,"digits","my_dst_number")))
				session:setVariable("my_dst_number",param)
				session:setVariable("ringback",sound_dir.."/waiting_music")
				session:setVariable("my_ivr_transfer_str","T-"..param.." XML extension")
				return true
			elseif service_name == "Trunks" then
				if param:match("^FXO/") then
					local slot,port = param:match("FXO/([0-9]+)/([12])")
					local dst = param:match(".*/.*/.*/([0-9]+)")

					session:setVariable("my_ivr_bridge_channel","FXO")
					if dst then
						session:setVariable("my_dst_number",dst)
						session:setVariable("my_ivr_bridge_str","T-freetdm/"..slot.."/"..port.."/"..dst)
					else
						session:setVariable("my_ivr_bridge_str","T-freetdm/"..slot.."/"..port)
						get_destination_number("T-freetdm/"..slot.."/"..port)
					end
				elseif param:match("^gsmopen/") then
					local slot_name = param:match("gsmopen/([0-9A-Z%-]+)")
					local dst = param:match(".*/.*/([0-9]+)")

					session:setVariable("my_ivr_bridge_channel","GSM")
					if dst then
						session:setVariable("my_dst_number",dst)
						session:setVariable("my_ivr_bridge_str","T-gsmopen/"..slot_name.."/"..dst)
					else
						session:setVariable("my_ivr_bridge_str","T-gsmopen/"..slot_name)
						get_destination_number("T-gsmopen/"..slot_name)
					end
				elseif param:match("^SIPT") then
					session:consoleLog("debug","--SIPT:");
					local gw_name = param:match("SIPT%-([0-9%_%-FXSOGMCD]+)/")
					local dst = param:match("SIPT%-.*/([0-9]+)")
					
					session:setVariable("my_ivr_bridge_channel",get_siptrunk_uci_name(gw_name))
					session:setVariable("ringback",sound_dir.."/waiting_music")
					if dst then
						session:setVariable("my_dst_number",dst)
						session:setVariable("my_ivr_bridge_str","T-sofia/gateway/"..gw_name.."/"..dst)
					else
						session:setVariable("my_ivr_bridge_str","T-sofia/gateway/"..gw_name)
						get_destination_number("T-sofia/gateway/"..gw_name)
					end
				end
				return true
			elseif service_name == "Ringgroup" then
				--@ transfer to ringgroup contact
				local index,strategy = param:match("([0-9]+)/(.*)")	
				if index and strategy then
					for k2,v2 in pairs(ringgroup_tb) do
						if v2.index == index then
							session:setVariable("ringback",sound_dir.."/waiting_music")
							session:setVariable("my_ringgroup_strategy",strategy)
							session:setVariable("my_ringgroup_index",index)
							session:setVariable("my_ringgroup_ringtime",v2.ringtime or 25)
							session:setVariable("my_ivr_transfer_str","T-RingGroupService XML ringgroup")
							return true
						end
					end
				end

				return false
			else
				return false
			end
		end
	end
	return false
end

session:preAnswer()

if chan_name and chan_name:match("^gsmopen") then
	session:sleep(4000)
end

session:answer()

if session:ready() == true then
	session:setAutoHangup(false);
	session:execute("unset","my_ivr_transfer_str")
	session:execute("unset","my_ivr_bridge_str")
	session:execute("unset","my_fail_transfer_str_failroute")
	
	read_codec = session:getVariable("read_codec")
	if read_codec ~= "PCMA" and read_codec ~= "PCMU" and read_codec ~= "G723" and read_codec ~= "G729" then
		read_codec = "PCMA"
	end

	local f = io.open(sound_welcome..read_codec)
	if f then
		f:close()
	else
		sound_welcome = string.gsub(sound_welcome,"welcome.","welcome_default.")
	end
	
	local fail_route_cause_str = session:getVariable("fail_route_cause")
	if not fail_route_cause_str then
		fail_route_cause_str = session:getVariable("continue_on_fail")
		if fail_route_cause_str then
			session:setVariable("fail_route_cause",fail_route_cause_str)
		end
	end	

	--@ FAIL ROUTE
	local continue_on_fail_str
	local tmp = session:getVariable("transfer_name_on_fail")
	if tmp and fail_route_cause_str and string.find(fail_route_cause_str,"USER_BUSY") then
		continue_on_fail_str = fail_route_cause_str
		session:setVariable("continue_on_fail",continue_on_fail_str)

		session:consoleLog("debug","ROUTING:service of call_failed_routing - ["..tmp.."]")
		session:setVariable("my_fail_transfer_str_failroute","T-"..tmp.." XML failroute")
	end		
	
	session:sleep(500)
	server_for_menu_step_0()
end