local fs = require "luci.fs"
local ds = require "luci.dispatcher"
local i18n = require "luci.i18n"
local util = require "luci.util"

local detect_data = "/tmp/dhcp.onlines"
local time_now = tonumber(os.time())
local online_num = 0
local content = {}

if fs.access(detect_data) then
	local data = io.open(detect_data,"r")
	if data then
		local index = 1
		local wifi_user = util.exec("iwpriv ra0 show stasecinfo") or ""
		local a,b = string.find(wifi_user,"MAC")
		if a and b then
			a,b = string.find(wifi_user,"\n",a)
			if a and b then
				wifi_user = string.sub(wifi_user,a+1) or ""
			else
				wifi_user = ""
			end
		else
			wifi_user = ""
		end

		for line in data:lines() do
			local tmp = {}
			local parse_tb = luci.util.split(line," ")
			if parse_tb[6] and parse_tb[6] == "Online" and (0 == tonumber(parse_tb[1]) or tonumber(parse_tb[1]) > time_now) then -- Hide the result which expired.
				tmp[1] = index
				tmp[2] = parse_tb[4] or ""
				tmp[3] = string.upper(parse_tb[2] or "")
				tmp[4] = parse_tb[3] or ""
				if tmp[3] ~= "" and wifi_user:match(tmp[3]) then
					tmp[5] = "WiFi"
				else
					tmp[5] = "LAN"
				end
				index = index + 1
				print(tmp[1],tmp[2],tmp[3],tmp[4],tmp[5])
				table.insert(content, tmp)
			end
		end
		online_num = #content
	end
end

print(online_num)
