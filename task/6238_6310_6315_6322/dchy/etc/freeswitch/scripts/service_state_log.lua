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

local subclass = event:getHeader("Event-Subclass")

if subclass == "sofia::gateway_state_record" then
	local date = event:getHeader("Event-Date-Local") or ""
	local name = event:getHeader("Gateway") or ""
	local state = event:getHeader("State") or ""

	if name == "2_1" and date ~= "" and state ~= "" then
		os.execute("lock /tmp/service_state_log_lock; echo 'Date:"..date..", Service:Siptrunk, State:"..state.."' >> /ramlog/service_state_log; lock -u /tmp/service_state_log_lock;")
	end
elseif subclass == "pstn::dev_update_event" then
	local pstn_type = event:getHeader("type") or ""
	local slot_id = event:getHeader("slot_id") or ""
	local state = event:getHeader("line_state") or ""
	local signal = event:getHeader("signal") or ""
	local date = event:getHeader("Event-Date-Local") or ""
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
				os.execute("lock /tmp/service_state_log_lock; echo 'Date:"..date..", Service:SIM, State:OK("..signal..")' >> /ramlog/service_state_log; echo '"..state.."' > /tmp/cur_gsm_state; lock -u /tmp/service_state_log_lock;")
			elseif state ~= "OK" then
				os.execute("lock /tmp/service_state_log_lock; echo 'Date:"..date..", Service:SIM, State:"..state.."' >> /ramlog/service_state_log; echo '"..state.."' > /tmp/cur_gsm_state; lock -u /tmp/service_state_log_lock;")
			end
		end
	end
end

