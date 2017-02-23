
local api = freeswitch.API()
local uci = require "uci".cursor()

local bridge_str = argv[1]
local sip_ex_tb = {}
local fxs_ex_tb = {}
local endpoint_interface = {}
local fw_ex_tb = {}
--@ endpoint_fxso or endpoint_sipphone

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
	session:setVariable("call_bypass_media_flag","false")
	session:setVariable("call_fw_uncond_bypass_media_flag","false")
	session:setVariable("call_fw_busy_bypass_media_flag","false")
	session:setVariable("call_fw_noreply_bypass_media_flag","false")

	session:setVariable("call_proxy_media_flag","false")
	session:setVariable("call_fw_uncond_proxy_media_flag","false")
	session:setVariable("call_fw_busy_proxy_media_flag","false")
	session:setVariable("call_fw_noreply_proxy_media_flag","false")

	for k,v in pairs(fw_ex_tb) do
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
				if false then
					-- userbusy, noreply
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
				end
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
	end
end
