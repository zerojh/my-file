--[[

]]--
local dsp = require "luci.dispatcher"
local uci = require "luci.model.uci".cursor()
local fs = require "luci.fs"

local dev_name = ""
local if_name
if fs.access("/lib/modules/3.14.18/rt2860v2_ap.ko") then
    dev_name = "ra0"
    if_name = "ra"
else
    dev_name = "radio0"
    if_name = "radio"
end

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

local profile = uci:get_all("wireless")
if this_edit == "edit" then
	index = s:option(DummyValue,"index",translate("Index"))

else
	index = s:option(ListValue,"index",translate("Index"))
	for i=1,4 do
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

status = s:option(ListValue,"disabled",translate("Status"))
status.rmempty = false
status:value("0",translate("Enable"))
status:value("1",translate("Disable"))

ssid = s:option(Value,"ssid",translate("SSID"))
ssid.rmempty = false
local name_list_str = "*&"
for k,v in pairs(profile) do
	if v['.type'] == "wifi-iface" and k ~= this_section and v.index and v.ssid then
		name_list_str = name_list_str..v.ssid.."&"
	end
end
ssid.datatype = "username("..name_list_str..")"

option = s:option(ListValue,"network",translate("Interface Binding"))
option.rmempty = false
option:value("lan","LAN")
--@ add vlan
local network_profile = uci:get_all("network") or {}
for i=0,15 do
	for k,v in pairs(network_profile) do
		if v.name and v['.type'] == "interface" and k:match("^vlan([0-9]+)") and tonumber(k:match("^vlan([0-9]+)")) == i then
			option:value(k,k)
		end
	end
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

option = s:option(ListValue,"isolate",translate("Isolation"))
option.default = "0"
option:value("0",translate("Disable"))
option:value("1",translate("Enable"))

--@ wps only for ra0/radio0
if this_section == "wifi0" then
	--@ WPS button
	if uci:get("wireless",dev_name,"wdsmode") ~= "bridge" then
		option = s:option(DummyValue,"_wps_cfg",translate("WPS PIN Code"))
		option.template = "admin_network/wps"
	end
end

option = s:option(DummyValue,"tmp_no_useful",translate(""))
function option.parse(self,section,value)
	if this_edit == "edit" then
		--@ nothing
	else
		local tmp_index = m:formvalue("cbid.wireless."..this_section..".index")

		--@ set default option
		m.uci:set("wireless",this_section,"device",dev_name)
		m.uci:set("wireless",this_section,"ifname",if_name..(tonumber(tmp_index)-1))
		m.uci:set("wireless",this_section,"mode","ap")
	end
end

return m
