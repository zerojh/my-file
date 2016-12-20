
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
	local pstn_type = event:getHeader("type")
	local state = event:getHeader("line_state") or ""
	local date = event:getHeader("Event-Date-Local")
	if pstn_type:match("(GSM)") and state ~= "" then
		os.execute("lock /tmp/service_state_log_lock; echo 'Date:"..date..", Service:SIM, State:"..state.."' >> /ramlog/service_state_log; lock -u /tmp/service_state_log_lock;")
		freeswitch.consoleLog("pstn_type:"..pstn_type..", line_state:"..state.."\n")
	end
end

