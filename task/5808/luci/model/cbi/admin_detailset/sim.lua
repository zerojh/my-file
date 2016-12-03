
local uci = require "luci.model.uci".cursor()
local tmp_tb = uci:get_all("endpoint_mobile") or {}
local currsection

m = Map("endpoint_mobile","配置 / SIM卡")

if next(tmp_tb) then
	for k,v in pairs(tmp_tb) do
		if v.slot_type and (v.slot_type == "1-GSM" or v.slot_type == "1-LTE") then
			currsection = k
			break
		end
	end
end

if currsection then
	s = m:section(NamedSection,currsection)
	s.addremove = false

	--##### Status #####------
	option = s:option(ListValue,"status","启用SIM卡")
	option:value("Disabled",translate("Disable"))
	option:value("Enabled",translate("Enable"))
end

return m
