
local util = require "luci.util"
local wifi_list_dir = "/tmp/ra0_wifi_list"
local fs = require "luci.fs"

local ret_str = util.exec("iwpriv ra0 set SiteSurvey=")
ret_str = util.exec("iwpriv ra0 get_site_survey")
--local ret_str = util.exec("cat wifi_list.txt")

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

local tmp_tb = luci.util.split(ret_str,"\n")
for k,v in pairs(tmp_tb or {}) do
	if v and v:match("^[0-9]") then
		local channel = ""
		local ssid = ""
		local bssid = ""
		local security = ""
		local signal = ""

		--channel,ssid,bssid,security,signal,wps = v:match("^"..ch_reg.."%s+"..ss_reg.."%s+"..bss_reg.."%s+"..sec_reg.."%s+"..sig_reg.."%s+[0-9a-zA-Z/]+%s+%u+%s+%a+%s+"..wps_reg.."%s*")
		channel,ssid,bssid,security,signal = v:match("^"..ch_reg.."%s+"..ss_reg.."%s+"..bss_reg.."%s+"..sec_reg.."%s+"..sig_reg.."%s*")
		if channel then
			signal = signal.."%"
			print(channel,ssid,bssid,security,signal)
			--_file.write(channel..","..ssid..","..bssid..","..security..','..signal..','..wps)
			_file:write(channel..","..ssid..","..bssid..","..security..","..signal.."\n")
		end

	end
end

if _file then
	_file:close()
end
