
local util = require "luci.util"
local fs = require "luci.fs"

local ret_wifi_list = {}
local wifi_list_dir = "/tmp/ra0_wifi_list"
luci.util.exec("iwpriv ra0 set SiteSurvey=")
local ret_str = luci.util.exec("iwpriv ra0 get_site_survey")

--@ refresh
util.exec("rm "..wifi_list_dir)
util.exec("touch "..wifi_list_dir)
local _file = io.open(wifi_list_dir,"w+")

local tmp_tb = luci.util.split(ret_str,"\n")
for k,v in pairs(tmp_tb or {}) do
	if v and v:match("^[0-9]") then
		local wifi_tb = {}

		--Ch  SSID                             BSSID               Security               Siganl(%)W-Mode  ExtCH  NT WPS DPID
		--1   lamont_test                      f8:a0:3d:59:0c:15   NONE                   0        11b/g/n NONE   In  NO     
		wifi_tb.channel,wifi_tb.ssid,wifi_tb.bssid,wifi_tb.security,wifi_tb.signal = v:match("^([0-9]+)%s*([a-zA-Z0-9%.%-%_/]+)%s*([a-fA-F0-9:]+)%s*([a-zA-Z0-9%/]+)%s*([0-9]+)%s*")

		table.insert(ret_wifi_list,wifi_tb)
		_file:write(wifi_tb.channel.." "..wifi_tb.ssid.." "..wifi_tb.bssid.." "..wifi_tb.security.." "..wifi_tb.signal.."\n")
	end
end

if _file then
	_file:close()
end
