
local util = require "luci.util"
local wifi_list_dir = "ra0_wifi_list"
local fs = require "luci.fs"

--local ret_str = luci.util.exec("iwpriv ra0 set SiteSurvey=")
--ret_str = luci.util.exec("iwpriv ra0 get_site_survey")
local ret_str = util.exec("cat wifi_list.txt")

--@ refresh
if fs.access(wifi_list_dir) then
    util.exec("rm "..wifi_list_dir)
end
util.exec("touch "..wifi_list_dir)
local _file = io.open(wifi_list_dir,"w+")
local ch_reg="([0-9]+)"
local ss_reg="([a-zA-Z0-9%.%-%_/]+)"
local bss_reg="(%w%w:%w%w:%w%w:%w%w:%w%w:%w%w)"
local sec_reg="([a-zA-Z0-9%/]+)"
local sig_reg="([0-9]+)"
local wps_reg="(%u+)"

local tmp_tb = luci.util.split(ret_str,"\n")
for k,v in pairs(tmp_tb or {}) do
	if v and v:match("^[0-9]") then
		local channel = ""
		local ssid = ""
		local bssid = ""
		local security = ""
		local signal = ""
        local wps = ""

		--wifi_tb.channel,wifi_tb.ssid,wifi_tb.bssid,wifi_tb.security,wifi_tb.signal = v:match("^"%s+([a-zA-Z0-9%.%-%_/]+)%s+(%w%w:%w%w:%w%w:%w%w:%w%w:%w%w)%s+([a-zA-Z0-9%/]+)%s+([0-9]+)%s*") 
		channel,ssid,bssid,security,signal,wps = v:match("^"..ch_reg.."%s+"..ss_reg.."%s+"..bss_reg.."%s+"..sec_reg.."%s+"..sig_reg.."%s+[0-9a-zA-Z/]+%s+%u+%s+%a+%s+"..wps_reg.."%s*")
		if channel then
			print(channel,ssid,bssid,security,signal,wps)
            _file.write(channel..","..ssid..","..bssid..","..security..','..signal..','..wps)
		end

	end
end

if _file then
	_file:close()
end
