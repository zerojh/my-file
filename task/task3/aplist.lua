
local util = require "luci.util"
local wifi_list_dir = "/tmp/ra0_wifi_list"
local fs = require "luci.fs"

--local ret_str = luci.util.exec("iwpriv ra0 set SiteSurvey=")
--ret_str = luci.util.exec("iwpriv ra0 get_site_survey")
ret_str = luci.util.exec("cat wifi_list.txt")

--@ refresh
--util.exec("rm "..wifi_list_dir)
--util.exec("touch "..wifi_list_dir)
local _file = io.open(wifi_list_dir,"w+")
local channel_regex="([0-9]+)"
local ssid_regex="([a-zA-Z0-9%.%-%_/]+)
local bssid_regex="(%w%w:%w%w:%w%w:%w%w:%w%w:%w%w)"
local security_regex="([a-zA-Z0-9%/]+)"
local signal_regex="([0-9]+)"

local tmp_tb = luci.util.split(ret_str,"\n")
for k,v in pairs(tmp_tb or {}) do
	if v and v:match("^[0-9]") then
		local wifi_tb = {}

		wifi_tb.channel,wifi_tb.ssid,wifi_tb.bssid,wifi_tb.security,wifi_tb.signal = v:match("^"%s+([a-zA-Z0-9%.%-%_/]+)%s+(%w%w:%w%w:%w%w:%w%w:%w%w:%w%w)%s+([a-zA-Z0-9%/]+)%s+([0-9]+)%s*") 
		if wifi_tb.channel then
			_file:write(wifi_tb.channel..","..wifi_tb.ssid..","..wifi_tb.bssid..","..wifi_tb.security..","..wifi_tb.signal.."\n")
		end

	end
end

if _file then
	_file:close()
end
