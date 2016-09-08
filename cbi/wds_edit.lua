local ds = require "luci.dispatcher"
local uci = require "luci.model.uci".cursor()
local fs_server = require "luci.scripts.fs_server"
local fs = require "luci.fs"

local this_section = arg[1] or ""
local this_edit = arg[2] or ""

local dev_name = ""
if fs.access("/lib/modules/3.14.18/rt2860v2_ap.ko") then
	dev_name = "ra0"
else
	dev_name = "radio0"
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

local profile = uci:get_all("wireless")
if this_edit == "edit" then
	index = s:option(DummyValue,"index",translate("Index"))
else
	index = s:option(ListValue,"index",translate("Index"))
	for i=1,4 do
		local flag = true
		for k,v in pairs(profile) do
			if v['.type'] == "wifi-iface" and string.find(v.ifname,"wds") and v.index and tonumber(v.index) == i then
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

