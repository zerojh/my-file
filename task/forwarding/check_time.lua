
local time_tb = {["aa"]={["wday"]="123457",["date"]={"2017-02-10~2017-02-11","2017-02-18~2017-02-24"},["time"]={"00:30~12:30","12:31~20:59"}}}
local time_check_tb = {}

local now_epoch = os.time()
local now_tb = os.date("*t",now_epoch) or {}
local now_minute = tonumber(now_tb.hour) * 60 + tonumber(now_tb.min)
--print(now_epoch)
function check_time(idx,tb)
	local ret = true

	if not time_check_tb[idx] then
		if ret and tb["wday"] then
			local wday = tb["wday"]
			if not wday:match(now_tb.wday) then
				ret = false
			end
		end

		if ret and tb["date"] then
			local check_flag = false
			for k,v in pairs(tb["date"]) do
				if v then
					local min_y,min_m,min_d,max_y,max_m,max_d = v:match("(%d+)-(%d+)-(%d+)~(%d+)-(%d+)-(%d+)")
					if min_y then
						local min_epoch = os.time({year=min_y, month=min_m, day=min_d, hour="0", min="0", sec="0"})
						local max_epoch = os.time({year=max_y, month=max_m, day=max_d, hour="23", min="59", sec="59"})
						if now_epoch >= min_epoch and now_epoch <= max_epoch then
							check_flag = true
							break
						end
					end
				end
			end
			ret = check_flag
		end

		if ret and tb["time"] then
			local check_flag = false
			for k,v in pairs(tb["time"]) do
				if v then
					local min_h,min_m,max_h,max_m = v:match("(%d+):(%d+)~(%d+):(%d+)")
					if min_h then
						local min_minute = tonumber(min_h) * 60 + tonumber(min_m)
						local max_minute = tonumber(max_h) * 60 + tonumber(max_m)
						if now_minute >= min_minute and now_minute <= max_minute then
							check_flag = true
							break
						end
					end
				end
			end
			ret = check_flag
		end

		if ret then
			time_check_tb[idx] = 1
		else
			time_check_tb[idx] = 0
		end
	end

	return time_check_tb[idx]
end

local tmp_idx = "aa"
local tmp_tb = time_tb[tmp_idx]
print(check_time(tmp_idx, tmp_tb))
print(check_time(tmp_idx, tmp_tb))
