
local util = require "luci.util"
local wifi_list_dir = "/tmp/wlan0_wifi_list"
local fs = require "luci.fs"

--local ret_str = util.exec("iwlist wlan0 scanning|sed '1d'|tr '\n' ','|tr -d ' '|sed 's/,Cell/\\nCell/g'")
--local ret_str = util.exec("cat wifi_list_old.txt|sed '1d'|tr '\n' ','|tr -d ' '|sed 's/,Cell/\\nCell/g'")
print(ret_str)

local tmp_tb = luci.util.split(ret_str,"\n")

--@ refresh
if fs.access(wifi_list_dir) then
	util.exec("rm "..wifi_list_dir)
end
util.exec("touch "..wifi_list_dir)
local _file = io.open(wifi_list_dir,"w+")

local tmp_tb = luci.util.split(ret_str,"\n")
for k,v in pairs(tmp_tb or {}) do
	if v and v:match("^Cell") then
		local channel = v:match("Channel:(%d+),") or ""
		local ssid = v:match("ESSID:\"(.-)\"") or ""
		local bssid = v:match("Address:(%w%w:%w%w:%w%w:%w%w:%w%w:%w%w)") or ""
		local signal = v:match("Signallevel=(%-%d+dBm)") or ""
		local security = ""
		if v:match("Encryptionkey:off") then
			security = "NONE"
		elseif v:match("IE:IEEE802.11i/WPA2Version1") then
			security = "WPA2PSK"
		elseif v:match("IE:WPAVersion1") then
			security = "WPA1PSK"
		else
			security = "WPA1PSK"
		end

		if channel ~= "" and ssid ~= "" and bssid ~= "" and signal ~= "" and security ~= "" then
			--print(channel,ssid,bssid,security,signal)
			_file:write(channel..","..ssid..","..bssid..","..security..","..signal.."\n")
		end

	end
end

if _file then
	_file:close()
end
