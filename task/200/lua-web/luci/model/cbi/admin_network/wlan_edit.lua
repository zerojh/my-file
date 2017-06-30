--[[

]]--
local dsp = require "luci.dispatcher"
local uci = require "luci.model.uci".cursor()
local fs = require "luci.fs"

this_section = arg[1] or ""
this_edit = arg[2] or ""

if this_edit == "edit" then
    m = Map("wireless",translate("WLAN / Edit"))
else
    m = Map("wireless",translate("WLAN / New"))
    m.addnew = true
    m.new_section = this_section
end

m.redirect = dsp.build_url("admin","network","wlan","wlan_config")

if not m.uci:get(this_section) == "wifi-iface" then
	luci.http.redirect(m.redirect)
end

s = m:section(NamedSection,this_section,"wifi-iface","")
m.currsection = s
s.addremove = false
s.anonymous = true

local profile = uci:get_all("wireless") or {}
local MAX_WLAN_WIFI = tonumber(uci:get("profile_param","global","max_wlan_wifi") or "4")

if this_edit == "edit" then
	index = s:option(DummyValue,"index",translate("Index"))
else
	index = s:option(ListValue,"index",translate("Index"))
	for i=1,MAX_WLAN_WIFI do
		local flag = true
		for k,v in pairs(profile) do
			if v['.type'] == "wifi-iface" and v.ssid and v.index and tonumber(v.index) == i then
				flag = false
				break
			end
		end
		if flag == true then
			index:value(i,i)
		end
	end
end

ssid = s:option(Value,"ssid",translate("SSID"))
ssid.rmempty = false
local name_list_str = ""
for k,v in pairs(profile) do
	if string.match(v['.name'],"(wifi)") and k ~= this_section and v.index and v.ssid then
		name_list_str = name_list_str..v.ssid.."&"
	end
end
if name_list_str == "" then
	ssid.datatype = "uni_ssid"
else
	ssid.datatype = "multi_ssid("..name_list_str..")"
end

option = s:option(ListValue,"encryption",translate("Encryption"))
option.default = "psk2"
option:value("psk","WPA+PSK")
option:value("psk2","WPA2+PSK")
option:value("none",translate("NONE"))

option = s:option(Value,"key",translate("Password"))
option.rmempty = false
option.datatype = "wifi_password"
option.password = true
option:depends("encryption","psk")
option:depends("encryption","psk2")
function option.cfgvalue(...)
	local key = m.uci:get("wireless",this_section,"key")

	return key or ""
end
function option.validate(self,value)
	local tmp = m:formvalue("cbid.wireless."..this_section..".encryption")
	
	if tmp ~= "none" then
		return Value.validate(self,value)
	else
		m.uci:delete("wireless",this_section,"key")
		return value or ""
	end
end

option = s:option(ListValue,"wmm",translate("Wireless Multimedia Extensions"))
option.default = "0"
option:value("0",translate("Off"))
option:value("1",translate("On"))

option = s:option(ListValue,"within_isolate",translate("Isolation (within SSID)"))
option.default = "0"
option:value("0",translate("Disable"))
option:value("1",translate("Enable"))

function option.parse(self,section,value)
	local value=m:formvalue("cbid.wireless."..this_section..".within_isolate")
	m.uci:set("wireless",this_section,"within_isolate",value)
	if this_edit ~= "edit" then
		local tmp_index = m:formvalue("cbid.wireless."..this_section..".index")
		--@ set default option
		m.uci:set("wireless",this_section,"device","ra0")
		m.uci:set("wireless",this_section,"ifname","ra"..(tonumber(tmp_index)-1))
		m.uci:set("wireless",this_section,"mode","ap")
	end
end
--@ wps only for ra0/radio0
if this_section == "wifi0" then
	--@ WPS button
	if uci:get("wireless","ra0","disabled") == "0" and uci:get("wireless","ra0","wps") == "on" and uci:get("wireless","ra0","wdsmode") ~= "bridge" then
		option = s:option(DummyValue,"_wps_cfg",translate("WPS PIN Code"))
		option.template = "admin_network/wps"
	end
end

status = s:option(ListValue,"disabled",translate("Status"))
status.rmempty = false
status:value("0",translate("Enable"))
status:value("1",translate("Disable"))

return m
