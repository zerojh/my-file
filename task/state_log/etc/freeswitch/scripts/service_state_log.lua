function file_exist(filename)
	local file = io.open(filename,"rb")

	if file then
		file:close()
	end

	return file ~= nil
end

function exe(cmd)
	local pp   = io.popen(cmd)
	local data = pp:read("*a")
	pp:close()

	return data
end

local event_name = event:getHeader("Event-Name")
if event_name == "CUSTOM" then
	local subclass = event:getHeader("Event-Subclass")
	if subclass == "sofia::register" then
		-- Extension register to local sip server.
		local date = event:getHeader("Event-Date-Local") or "unknown"
		local username = event:getHeader("username")
		username = username and "SIP Extension/"..username or "unknown"
		local state = "register"

		local str = "str:\n"
		str = str.."date, username, state\n"
		str = str..date..", "..username..", "..state.."\n"
		freeswitch.consoleLog("info", str)
	elseif subclass == "sofia::unregister" then
		-- Extension unregister from local sip server.
		local date = event:getHeader("Event-Date-Local") or "unknown"
		local username = event:getHeader("username")
		username = username and "SIP Extension/"..username or "unknown"
		local state = "unregister"

		local str = "str:\n"
		str = str.."date, username, state\n"
		str = str..date..", "..username..", "..state.."\n"
		freeswitch.consoleLog("info", str)
	elseif subclass == "sofia::gateway_state_record" then
		-- SIP trunk, FXS, FXO register(unregister) to remote sip server.
		local date = event:getHeader("Event-Date-Local") or "unknown"
		local name = event:getHeader("Gateway") or "unknown"
		local state = event:getHeader("State") or "unknown"

		local str = "str:\n"
		str = str.."date, gateway, state\n"
		str = str..date..", "..name..", "..state.."\n"
		freeswitch.consoleLog("info", str)
	elseif subclass == "pstn::dev_update_event" then
		local endpoint = event:getHeader("endpoint") or ""
		if endpoint == "gsmopen" then
			local date = event:getHeader("Event-Date-Local") or ""
			local pstn_type = event:getHeader("type") or ""
			local slot_id = event:getHeader("slot_id") or ""
			local state = event:getHeader("line_state") or ""
			local signal = event:getHeader("signal") or ""
			local write_flag = false

			if pstn_type:match("(GSM)") and slot_id == "1" and state ~= "" and state ~= "SIMPIN_ERROR" and signal ~= "" and date ~= "" then
				if not file_exist("/tmp/cur_gsm_state") then
					write_flag = true
				else
					local last_state = exe("cat /tmp/cur_gsm_state")

					if not last_state or state == "OK" or (state ~= "OK" and not last_state:match(state)) then
						write_flag = true
					else
						write_flag = false
					end
				end

				if write_flag then
					if state == "OK" and signal ~= "0" then
						local str = "str:\n"
						str = str.."date, state, signal\n"
						str = str..date..", "..state..", "..signal.."\n"
						freeswitch.consoleLog("info", str)
						--os.execute("lock /tmp/service_state_log_lock; echo 'Date:"..date..", Service:SIM, State:OK("..signal..")' >> /ramlog/service_state_log; echo '"..state.."' > /tmp/cur_gsm_state; lock -u /tmp/service_state_log_lock;")
					elseif state ~= "OK" then
						local str = "str:\n"
						str = str.."date, state\n"
						str = str..date..", "..state.."\n"
						freeswitch.consoleLog("info", str)
						--os.execute("lock /tmp/service_state_log_lock; echo 'Date:"..date..", Service:SIM, State:"..state.."' >> /ramlog/service_state_log; echo '"..state.."' > /tmp/cur_gsm_state; lock -u /tmp/service_state_log_lock;")
					end
				end
			end
		elseif endpoint == "freetdm" then
			local date = event:getHeader("Event-Date-Local") or ""
			local eptype = event:getHeader("type") or "unknown"
			local slot_id = event:getHeader("slot_id") or "unknown"
			local port_id = event:getHeader("port_id") or "unknown"
			local hook_state = event:getHeader("hook_state") or "unknown"
			local usable = event:getHeader("usable") or "unknown"

			if eptype == "FXS" then
				local str = "str:\n"
				str = str.."date, eptype, slot_id, port_id, hook_state\n"
				str = str..date..", "..eptype..", "..slot_id..", "..port_id..", "..hook_state.."\n"
				freeswitch.consoleLog("info", str)
			elseif eptype == "FXO" then
				local str = "str:\n"
				str = str.."date, eptype, slot_id, port_id, hook_state, usable\n"
				str = str..date..", "..eptype..", "..slot_id..", "..port_id..", "..hook_state..", "..usable.."\n"
				freeswitch.consoleLog("info", str)
			end
		end
	end
elseif event_name == "CHANNEL_HANGUP_COMPLETE" and event:getHeader("variable_source_chan_name") then
	-- call record.
	local date = event:getHeader("Event-Date-Local") or ""
	local caller_name = event:getHeader("variable_source_chan_name") or "unknown"
	local caller_number = event:getHeader("Caller-Caller-ID-Number") or "unknown"
	local callee_name = event:getHeader("variable_dest_chan_name") or "unknown"
	local callee_number = event:getHeader("variable_destination_number") or event:getHeader("Caller-Destination-Number") or "unknown"
	local hangup_cause = event:getHeader("Hangup-Cause") or "unknown"
	local start_epoch = event:getHeader("variable_start_epoch") or "0"
	local end_epoch = event:getHeader("variable_end_epoch") or "0"
	local billsec = event:getHeader("variable_billsec") or "0"

	local str = "str:\n"
	str = str.."date, caller_name, caller_number, callee_name, callee_number, hangup_cause, start_epoch, end_epoch, billsec\n"
	str = str..date..", "..caller_name..", "..caller_number..", "..callee_name..", "..callee_number..", "..hangup_cause..", "..start_epoch..", "..end_epoch..", "..billsec.."\n"
	freeswitch.consoleLog("info", str)
end

--[[
local os = require "os"
--os.execute("lock /tmp/service_state_log_lock; echo 'Date:"..date..", Service:Siptrunk, State:"..state.."' >> /ramlog/service_state_log; lock -u /tmp/service_state_log_lock;")
]]--

