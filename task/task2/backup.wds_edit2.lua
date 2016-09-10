local dsp = require "luci.dispatcher"
local uci = require "luci.model.uci".cursor()
local fs_server = require "luci.scripts.fs_server"
local fs = require "luci.fs"

local this_section = arg[1] or ""
local this_edit = arg[2] or ""
local wifi_list = fs_server.get_wifi_list()

local dev_name = ""
if fs.access("/lib/modules/3.14.18/rt2860v2_ap.ko") then
	dev_name = "ra0"
else
	dev_name = "radio0"
end

local profile = uci:get_all("wireless")
local ssid_table = {}
local wds_table = {}
for k,v in pairs(profile) do
	if v['.type'] == "wifi-iface" and v.ifname and string.find(v.ifname,"ra") then
		ssid_table[v.ifname] = v.ssid
	end
	if v['.type'] == "wifi-iface" and v.ifname and string.find(v.ifname,"wds") then
		wds_table[v.ifname] = v.index
	end
end

uci:check_cfg("wireless")

if this_edit == "edit" then
	m = Map("wireless",translate("WDS / Edit"))
else
	m = Map("wireless",translate("WDS / New"))
	m.addnew = true
	m.new_section = this_section
end

m.redirect = dsp.build_url("admin","network","wlan","wds_config")

if not m.uci:get(this_section) == "wifi-iface" then
	luci.http.redirect(m.redirect)
end

s = m:section(NamedSection,this_section,"wifi-iface","")
m.currsection = s
s.addremove = false
s.anonymous = true

--@ index
if this_edit == "edit" then
	option = s:option(DummyValue,"index",translate("Index"))
else
	option = s:option(ListValue,"index",translate("Index"))
	for i=1,4 do
		local flag = true
		for k,v in pairs(wds_table) do
			if v and tonumber(v) == i then
				flag = false
				break
			end
		end
		if flag == true then
			option:value(i,i)
		end
	end
end
--@ end index

--@ status
option = s:option(ListValue,"disabled",translate("Status"))
option.rmempty = false
option:value("0",translate("Enable"))
option:value("1",translate("Disable"))
--@ end status


--@ local ssid
option = s:option(DummyValue,"_local","Local SSID")

--# ssid
option = s:option(ListValue,"ifname",translate("SSID"))
option.margin = "30px"
if this_edit == "edit" then
	local wds_str = uci:get("wireless",this_section,"ifname")
	local wifi_str = "ra"..wds_str:match("wds(%d+)")
	option:value(wds_str, ssid_table[wifi_str])
end
for k,v in pairs(ssid_table) do
	local wds_str = "wds"..k:match("ra(%d+)")
	if not wds_table[wds_str] then
		option:value(wds_str, v)
	end
end



--@ end local ssid

--@ default value
option = s:option(DummyValue,"tmp_no_useful",translate(""))
function option.parse(self,section,value)
	if this_edit == "edit" then
		--@ nothing
	else
	--[[
		local tmp_index = m:formvalue("cbid.wireless."..this_section..".index")

		--@ set default option
		m.uci:set("wireless",this_section,"network","lan")
	]]--
	end
end
--@ end default value

return m
