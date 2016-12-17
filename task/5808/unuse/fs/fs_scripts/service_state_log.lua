
local os = require "os"
local subclass = event:getHeader("Event-Subclass")

if subclass == "sofia::gateway_state_record" then
	local date = event:getHeader("Event-Date-Local")
	local name = event:getHeader("Gateway")
	local state = event:getHeader("State")

	if name == "2_1" then
		os.execute("lock /tmp/service_state_log_lock; echo 'Date:"..date..", Service:Siptrunk, State:"..state.."' >> /ramlog/service_state_log; lock -u /tmp/service_state_log_lock;")
	end
elseif subclass == "pstn::dev_create_event" then
	local str = event:serialize()

	freeswitch.consoleLog("INFO", "str:\n"..str.."\n")
end

