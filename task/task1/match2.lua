
function action_get_pptp_client()
	local util = require "luci.util"
	local param = luci.http.formvalue("action")
	local history_start = luci.http.formvalue("starth")
	local history_num = luci.http.formvalue("numh")
	local info = {}
	local live_cont = {}
	local hist_cont = {}

	if param == "default" then
		-- pptp client live show.
		local login_rec = util.exec("tail -n 1 /ramlog/pptpc_log")
		if login_rec:match("^login:") then
			-- '\004' means EOF.
			local login_rec_tbl = util.split(login_rec, '\004')
			local ppp_name = "ppp1723"
			local ret_cmd = util.exec("ifconfig "..ppp_name)
			local ifconfig_tbl = util.split(ret_cmd, "\n\n")

			local index = 1
			local tmp = {}
			local pattern = "(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)"
			-- index, username, local_ip, remote_ip, server_ip, rx, tx, login_time, conn_time.
			for k, v in pairs(ifconfig_tbl) do
				if v and v:match("^"..ppp_name) then
					tmp[1] = index
					tmp[6] = change_packets_view(v:match("RX bytes:([0-9]+)") or "0").." / "..change_packets_view(v:match("TX bytes:([0-9]+)") or "0")
				end
			end
			for k, v in pairs(login_rec_tbl) do
				tmp[2] = v:match("user:(.-)[,%s]") or ""
				tmp[3] = v:match("local ip:(%d+%.%d+%.%d+%.%d+)") or ""
				tmp[4] = v:match("gateway:(%d+%.%d+%.%d+%.%d+)") or ""
				tmp[5] = v:match("server:(%d+%.%d+%.%d+%.%d+)") or v:match("server:(.-/%d+%.%d+%.%d+%.%d+)") or ""
				tmp[7] = v:match("login date:(.*)") or ""
				local year,month,day,hour,min,sec = tmp[7]:match(pattern)
				tmp[8] = os.time() - os.time({year=year,month=month,day=day,hour=hour,min=min,sec=sec})
			end
			table.insert(live_cont, tmp)
			info["live_cont"] = live_cont
		end
	end

	-- pptp client connection history show.
	local exist_num = history_start -1
	local logout_sum = util.exec("grep -n 'logout' /ramlog/pptpc_log|wc -l")
	local log_start = logout_sum - exist_num - history_num+ 1
	local log_end = logout_sum - exist_num
	local history
	local history_tbl = {}
	local history_tbl_r = {}
	local tmp = {}
	local flag = 0
	local index = history_start

	if log_start <= 0 then
		log_start = 1
	end
	if log_end > 0 then
		history = util.exec("grep -n 'logout' /ramlog/pptpc_log|sed -n '"..log_start..","..log_end.."p'|awk -F : '{print $1}'")
		history_tbl = util.split(history,"\n")
		for i=1, #history_tbl do
			table.insert(history_tbl_r,table.remove(history_tbl))
		end
		for i,j in pairs(history_tbl_r) do
			local value = tonumber(j)
			if value ~= nil then
				local inout = util.exec("sed -n '"..(value-1)..","..value.."p' /ramlog/pptpc_log")
				local inout_tbl = util.split(inout,"\n")
				for k,v in pairs(inout_tbl) do
					if v and v:match("^login:") then
						tmp[1] = index
						tmp[2] = v:match("user:(.-)[,%s]") or ""
						tmp[3] = v:match("local ip:(%d+%.%d+%.%d+%.%d+)") or ""
						tmp[4] = v:match("gateway:(%d+%.%d+%.%d+%.%d+)") or ""
						tmp[5] = v:match("server:(%d+%.%d+%.%d+%.%d+)") or v:match("server:(.-/%d+%.%d+%.%d+%.%d+)") or ""
						tmp[7] = v:match("login date:(.*)") or ""
						flag = flag + 1
					end
					if v and v:match("^logout:") then
						tmp[6] = change_packets_view(v:match("rcvd_bytes:(.-),") or "0").."/"..change_packets_view(v:match("sent_bytes:(.-),") or "0")
						tmp[8] = v:match("connect_time:(%d+)") or ""
						flag = flag + 1
					end
					if 2 == flag then
						table.insert(hist_cont, tmp)
						tmp = {}
						flag = 0
						index = index + 1
					end
				end
			end
		end
		info["hist_cont"] = hist_cont
	end
	
	luci.http.prepare_content("application/json")
	luci.http.write_json(info)
end
