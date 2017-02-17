
--[[
local os = require "os"
local subclass = event:getHeader("Event-Subclass")

--os.execute("lock /tmp/service_state_log_lock; echo 'Date:"..date..", Service:Siptrunk, State:"..state.."' >> /ramlog/service_state_log; lock -u /tmp/service_state_log_lock;")

if subclass == "sofia::register" then
	local str = event:serialize()
	freeswitch.consoleLog("info", "str:\n"..str.."\n")
elseif subclass == "sofia::unregister" then
	local str = event:serialize()
	freeswitch.consoleLog("info", "str:\n"..str.."\n")
end
]]--
local str = event:serialize()
freeswitch.consoleLog("info", "str:\n"..str.."\n")
