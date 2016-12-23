
local os = require "os"
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

	if pstn_type:match("(GSM)") and slot_id == "1" and state ~= "" and signal ~= "" and date ~= "" then
		if state == "OK" and signal ~= "0" then
			os.execute("lock /tmp/service_state_log_lock; echo 'Date:"..date..", Service:SIM, State:"..state.."("..signal..")' >> /ramlog/service_state_log; lock -u /tmp/service_state_log_lock;")
		else
			os.execute("lock /tmp/service_state_log_lock; echo 'Date:"..date..", Service:SIM, State:"..state.."' >> /ramlog/service_state_log; lock -u /tmp/service_state_log_lock;")
		end
	end
end

