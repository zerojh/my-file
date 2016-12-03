local uci = require "luci.model.uci".cursor()
local uci_tmp = require "luci.model.uci".cursor("/tmp/config")
local tmp_tb = uci:get_all("endpoint_mobile") or {}
local dsp = require "luci.dispatcher"
local flag = uci_tmp:get("wizard","globals","sim") or "1"
local currsection

m = Map("endpoint_mobile","SIM卡")
m.pageaction = false

if luci.http.formvalue("cbi.cancel") then
	m.redirect = dsp.build_url("admin","wizard","siptrunk")
elseif luci.http.formvalue("cbi.save") then
	flag = "1"
	uci_tmp:set("wizard","globals","sim","1")
	uci_tmp:save("wizard")
	uci_tmp:commit("wizard")
	if uci:get("wireless","wifi0","mode") ~= "sta" then
		m.redirect = dsp.build_url("admin","wizard","ap")
	else
		m.redirect = dsp.build_url("admin","wizard","ddns")
	end
end

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

	--#### Description #####----
	option = s:option(DummyValue,"_description")
	option.template = "admin_wizard/description"
	option.data = {}
	table.insert(option.data,"此处可选择是否使用SIM卡．")
	table.insert(option.data,"")

	--##### Status #####------
	option = s:option(ListValue,"status","启用SIM卡")
	option:value("Disabled",translate("Disable"))
	option:value("Enabled",translate("Enable"))
	function option.cfgvalue(self, section)
		if flag == "1" then
			return AbstractValue.cfgvalue(self, section)
		else
			return nil
		end
	end

	option = s:option(DummyValue,"_footer")
	option.template = "admin_wizard/footer"
end

return m
