module("luci.controller.admin.status", package.seeall)

function index()
	if luci.http.getenv("SERVER_PORT") == 8345 or luci.http.getenv("SERVER_PORT") == 8848 then
		entry({"admin", "status"}, alias("admin", "status", "overview"), _("Status"), 20).index = true
		entry({"admin", "status", "overview"}, template("admin_status/index"), _("Overview"), 1)
		entry({"admin", "status", "sipstatus"}, template("admin_status/sipstatus"), _("SIP"), 2)
		entry({"admin", "status", "pstnstatus"}, template("admin_status/pstnstatus"), _("PSTN"), 3)
		entry({"admin","status","client_list"},call("client_list"),_("DHCP Client List"),4).leaf = true

		entry({"admin", "status", "vpn"},alias("admin","status","vpn","l2tp_client"),_("VPN"),5)
		entry({"admin", "status", "vpn","l2tp_client"},template("admin_status/l2tp_c_list"),_("L2TP Client"),40).leaf = true 
		entry({"admin", "status", "vpn","pptp_client"},template("admin_status/pptp_c_list"),_("PPTP Client"),50).leaf = true 
		entry({"admin", "status", "vpn","openvpn_client"},template("admin_status/openvpn_c_list"),_("OpenVPN Client"),60).leaf = true 
		-- AJAX request.
		entry({"admin", "status", "get_l2tp_client"},call("action_get_l2tp_client"),nil).leaf = true
		entry({"admin", "status", "get_pptp_client"},call("action_get_pptp_client"),nil).leaf = true
		entry({"admin", "status", "get_openvpn_client"},call("action_get_openvpn_client"),nil).leaf = true
		entry({"admin", "status", "wifi"}, template("admin_status/ap_list"),_("Wireless AP List"),6)
		entry({"admin", "status", "currentcall"}, template("admin_status/currentcall"), _("Current Call"), 7)
		entry({"admin", "status", "cdr"}, call("action_cdrs"), _("CDRs"), 8)
		entry({"admin", "status", "service"}, template("admin_status/service"),_("Service"),9)
		entry({"admin", "status", "about"}, template("admin_status/about"),_("About"),10)
		page = entry({"admin","status","getcdrs"},call("action_get_cdrs"),nil)
		page.leaf = true
	end
end

function action_get_l2tp_client()
	local util = require "luci.util"
	local param = luci.http.formvalue("action")
	local history_start = tonumber(luci.http.formvalue("starth"))
	local history_reqnum = tonumber(luci.http.formvalue("reqnumh"))
	local history_errnum = tonumber(luci.http.formvalue("errnumh"))
	local info = {}
	local live_cont = {}
	local hist_cont = {}

	if param == "default" then
		-- l2tp client live show.
		local ppp_name = "ppp1701"
		local ret_cmd = util.exec("ifconfig "..ppp_name)
		if ret_cmd ~= "" then
			local ifconfig_tbl = util.split(ret_cmd, "\n\n")
			local login_rec = util.exec("tail -n 1 /ramlog/l2tpc_log")
			if login_rec:match("^login:") then
				-- '\004' means EOF.
				local login_rec_tbl = util.split(login_rec, '\004')

				local index = 1
				local tmp = {}
				local pattern = "(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)"
				-- index, username, local_ip, remote_ip, server_ip, rx, tx, login_time, conn_time.
				for _, v in pairs(ifconfig_tbl) do
					if v and v:match("^"..ppp_name) then
						tmp[1] = index
						tmp[6] = v:match("RX bytes:([0-9]+)") or "0"
						tmp[7] = v:match("TX bytes:([0-9]+)") or "0"
					end
				end
				for _, v in pairs(login_rec_tbl) do
					tmp[2] = v:match("user:(.-),") or ""
					tmp[3] = v:match("local ip:(%d+%.%d+%.%d+%.%d+)") or ""
					tmp[4] = v:match("gateway:(%d+%.%d+%.%d+%.%d+)") or ""
					tmp[5] = v:match("server:(%d+%.%d+%.%d+%.%d+)") or v:match("server:(.-/%d+%.%d+%.%d+%.%d+)") or ""
					tmp[8] = ""
					tmp[9] = "0"

					local log_time = v:match("login date:(.*)")
					local year,month,day,hour,min,sec = log_time:match("(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")
					if year and month and day and hour and min and sec then
						local t_stamp = os.time({year=year,month=month,day=day,hour=hour,min=min,sec=sec})
						if t_stamp then
							tmp[8] = log_time
							tmp[9] = os.time() - t_stamp
						end
					end
				end
				table.insert(live_cont, tmp)
				info["live_cont"] = live_cont
			end
		end
	end

	-- l2tp client connection history show.
	local exist_num = history_start -1
	local logsum = util.exec("cat /ramlog/l2tpc_log| tr '\n' '|' | sed 's/log\\(in:[^|]*|\\)log\\(out:[^|]*|\\)/\\n\\1\\2\\n/g' | grep '^in:' | wc -l")
	local log_start = logsum - exist_num - history_reqnum - history_errnum + 1
	local log_end = logsum - exist_num - history_errnum
	local history
	local history_tbl = {}
	local history_tbl_r = {}
	local tmp = {}
	local flag = 0
	local index = history_start

	local pattern = "(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)"
	local year1,month1,day1,hour1,min1,sec1
	local year2,month2,day2,hour2,min2,sec2
	local t1,t2

	if log_start <= 0 then
		log_start = 1
	end
	if log_end > 0 then
		history = util.exec("cat /ramlog/l2tpc_log| tr '\n' '|' | sed 's/log\\(in:[^|]*|\\)log\\(out:[^|]*|\\)/\\n\\1\\2\\n/g' | grep '^in:' | sed -n '"..log_start..","..log_end.."p'")
		history_tbl = util.split(history,"\n")
		for i=1, #history_tbl do
			table.insert(history_tbl_r,table.remove(history_tbl))
		end
		for _,v in pairs(history_tbl_r) do
			if v ~= "" then
				t1 = v:match("in:.*login date:(.-)|") or ""
				t2 = v:match("out:.*login_time:(.-)|") or ""
				year1,month1,day1,hour1,min1,sec1 = t1:match(pattern)
				year2,month2,day2,hour2,min2,sec2 = t2:match(pattern)
				if year1 and month1 and day1 and hour1 and min1 and sec1 and year2 and month2 and day2 and hour2 and min2 and sec2 then
					local t1_stamp = os.time({year=year1,month=month1,day=day1,hour=hour1,min=min1,sec=sec1})
					local t2_stamp = os.time({year=year2,month=month2,day=day2,hour=hour2,min=min2,sec=sec2})
					if t1_stamp and t2_stamp then
						local ret = math.abs(t1_stamp - t2_stamp)
						if ret <= 1 then
							tmp[1] = index
							tmp[2] = v:match("user:(.-),") or ""
							tmp[3] = v:match("local ip:(%d+%.%d+%.%d+%.%d+)") or ""
							tmp[4] = v:match("gateway:(%d+%.%d+%.%d+%.%d+)") or ""
							tmp[5] = v:match("server:(%d+%.%d+%.%d+%.%d+)") or v:match("server:(.-/%d+%.%d+%.%d+%.%d+)") or ""
							tmp[6] = v:match("rcvd_bytes:(%d+)") or "0"
							tmp[7] = v:match("sent_bytes:(%d+)") or "0"
							tmp[8] = t1
							tmp[9] = v:match("connect_time:(%d+)") or "0"
							table.insert(hist_cont, tmp)
							index = index + 1
							tmp = {}
						else
							history_errnum = history_errnum + 1
						end
					else
						history_errnum = history_errnum + 1
					end
				else
					history_errnum = history_errnum + 1
				end
			end
		end
		info["hist_cont"] = hist_cont
	end
	
	info["errnum"] = history_errnum
	
	luci.http.prepare_content("application/json")
	luci.http.write_json(info)
end

function action_get_pptp_client()
	local util = require "luci.util"
	local param = luci.http.formvalue("action")
	local history_start = tonumber(luci.http.formvalue("starth"))
	local history_reqnum = tonumber(luci.http.formvalue("reqnumh"))
	local history_errnum = tonumber(luci.http.formvalue("errnumh"))
	local info = {}
	local live_cont = {}
	local hist_cont = {}

	if param == "default" then
		-- pptp client live show.
		local ppp_name = "ppp1723"
		local ret_cmd = util.exec("ifconfig "..ppp_name)
		if ret_cmd ~= "" then
			local ifconfig_tbl = util.split(ret_cmd, "\n\n")
			local login_rec = util.exec("tail -n 1 /ramlog/pptpc_log")
			if login_rec:match("^login:") then
				-- '\004' means EOF.
				local login_rec_tbl = util.split(login_rec, '\004')

				local index = 1
				local tmp = {}
				local pattern = "(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)"
				-- index, username, local_ip, remote_ip, server_ip, rx, tx, login_time, conn_time.
				for _, v in pairs(ifconfig_tbl) do
					if v and v:match("^"..ppp_name) then
						tmp[1] = index
						tmp[6] = v:match("RX bytes:([0-9]+)") or "0"
						tmp[7] = v:match("TX bytes:([0-9]+)") or "0"
					end
				end
				for _, v in pairs(login_rec_tbl) do
					tmp[2] = v:match("user:(.-),") or ""
					tmp[3] = v:match("local ip:(%d+%.%d+%.%d+%.%d+)") or ""
					tmp[4] = v:match("gateway:(%d+%.%d+%.%d+%.%d+)") or ""
					tmp[5] = v:match("server:(%d+%.%d+%.%d+%.%d+)") or v:match("server:(.-/%d+%.%d+%.%d+%.%d+)") or ""
					tmp[8] = ""
					tmp[9] = "0"

					local log_time = v:match("login date:(.*)")
					local year,month,day,hour,min,sec = log_time:match("(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")
					if year and month and day and hour and min and sec then
						local t_stamp = os.time({year=year,month=month,day=day,hour=hour,min=min,sec=sec})
						if t_stamp ~= nil then
							tmp[8] = log_time
							tmp[9] = os.time() - t_stamp
						end
					end
				end
				table.insert(live_cont, tmp)
				info["live_cont"] = live_cont
			end
		end
	end

	-- pptp client connection history show.
	local exist_num = history_start -1
	local logsum = util.exec("cat /ramlog/pptpc_log| tr '\n' '|' | sed 's/log\\(in:[^|]*|\\)log\\(out:[^|]*|\\)/\\n\\1\\2\\n/g' | grep '^in:' | wc -l")
	local log_start = logsum - exist_num - history_reqnum - history_errnum + 1
	local log_end = logsum - exist_num - history_errnum
	local history
	local history_tbl = {}
	local history_tbl_r = {}
	local tmp = {}
	local flag = 0
	local index = history_start

	local pattern = "(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)"
	local year1,month1,day1,hour1,min1,sec1
	local year2,month2,day2,hour2,min2,sec2
	local t1,t2

	if log_start <= 0 then
		log_start = 1
	end
	if log_end > 0 then
		history = util.exec("cat /ramlog/pptpc_log| tr '\n' '|' | sed 's/log\\(in:[^|]*|\\)log\\(out:[^|]*|\\)/\\n\\1\\2\\n/g' | grep '^in:' | sed -n '"..log_start..","..log_end.."p'")
		history_tbl = util.split(history,"\n")
		for i=1, #history_tbl do
			table.insert(history_tbl_r,table.remove(history_tbl))
		end
		for _,v in pairs(history_tbl_r) do
			if v ~= "" then
				t1 = v:match("in:.*login date:(.-)|") or ""
				t2 = v:match("out:.*login_time:(.-)|") or ""
				year1,month1,day1,hour1,min1,sec1 = t1:match(pattern)
				year2,month2,day2,hour2,min2,sec2 = t2:match(pattern)
				if year1 and month1 and day1 and hour1 and min1 and sec1 and year2 and month2 and day2 and hour2 and min2 and sec2 then
					local t1_stamp = os.time({year=year1,month=month1,day=day1,hour=hour1,min=min1,sec=sec1})
					local t2_stamp = os.time({year=year2,month=month2,day=day2,hour=hour2,min=min2,sec=sec2})
					if t1_stamp and t2_stamp then
						local ret = math.abs(t1_stamp - t2_stamp)
						if ret <= 1 then
							tmp[1] = index
							tmp[2] = v:match("user:(.-),") or ""
							tmp[3] = v:match("local ip:(%d+%.%d+%.%d+%.%d+)") or ""
							tmp[4] = v:match("gateway:(%d+%.%d+%.%d+%.%d+)") or ""
							tmp[5] = v:match("server:(%d+%.%d+%.%d+%.%d+)") or v:match("server:(.-/%d+%.%d+%.%d+%.%d+)") or ""
							tmp[6] = v:match("rcvd_bytes:(%d+)") or "0"
							tmp[7] = v:match("sent_bytes:(%d+)") or "0"
							tmp[8] = t1
							tmp[9] = v:match("connect_time:(%d+)") or "0"
							table.insert(hist_cont, tmp)
							index = index + 1
							tmp = {}
						else
							history_errnum = history_errnum + 1
						end
					else
						history_errnum = history_errnum + 1
					end
				else
					history_errnum = history_errnum + 1
				end
			end
		end
		info["hist_cont"] = hist_cont
	end
	
	info["errnum"] = history_errnum
	
	luci.http.prepare_content("application/json")
	luci.http.write_json(info)
end

function action_get_openvpn_client()
	local util = require "luci.util"
	local param = luci.http.formvalue("action")
	local history_start = tonumber(luci.http.formvalue("starth"))
	local history_reqnum = tonumber(luci.http.formvalue("reqnumh"))
	local info = {}
	local live_cont = {}
	local hist_cont = {}

	if param == "default" then
		-- openvpn client live show.
		local ppp_name = "tun0"
		local ret_cmd = util.exec("ifconfig "..ppp_name)
		if ret_cmd ~= "" then 
			local ifconfig_tbl = util.split(ret_cmd, "\n\n")
			local login_rec = util.exec("tail -n 1 /ramlog/openvpnc_log")
			if login_rec:match("^login:") then
				-- '\004' means EOF.
				local login_rec_tbl = util.split(login_rec, '\004')
				local ppp_name = "tun0"

				local index = 1
				local tmp = {}
				-- index, username, local_ip, remote_ip, server_ip, rx, tx, login_time, conn_time.
				for _, v in pairs(ifconfig_tbl) do
					if v and v:match("^"..ppp_name) then
						tmp[1] = index
						tmp[6] = v:match("RX bytes:([0-9]+)") or "0"
						tmp[7] = v:match("TX bytes:([0-9]+)") or "0"
					end
				end
				for _, v in pairs(login_rec_tbl) do
					tmp[2] = v:match("proto:(tcp)") or v:match("proto:(udp)") or ""
					tmp[3] = v:match("local_ip:(%d+%.%d+%.%d+%.%d+)") or ""
					tmp[4] = v:match("gateway:(%d+%.%d+%.%d+%.%d+)") or ""
					tmp[5] = v:match("server_ip:(%d+%.%d+%.%d+%.%d+)") or v:match("server_ip:(.-/%d+%.%d+%.%d+%.%d+)") or ""
					tmp[8] = ""
					tmp[9] = "0"
					local login_time = v:match("login_time:(%d+)") or ""
					if login_time ~= "" then
						tmp[8] = os.date("%Y-%m-%d %H:%M:%S",login_time)
						tmp[9] = os.time() - tonumber(login_time)
					end
				end
				table.insert(live_cont, tmp)
				info["live_cont"] = live_cont
			end
		end
	end

	-- openvpn client connection history show.
	local exist_num = history_start -1
	local logout_sum = util.exec("grep 'logout' /ramlog/openvpnc_log|wc -l")
	local log_start = logout_sum - exist_num - history_reqnum+ 1
	local log_end = logout_sum - exist_num
	local history
	local history_tbl = {}
	local history_tbl_r = {}
	local tmp = {}
	local index = history_start

	if log_start <= 0 then
		log_start = 1
	end
	if log_end > 0 then
		history = util.exec("grep 'logout' /ramlog/openvpnc_log|sed -n '"..log_start..","..log_end.."p'")
		history_tbl = util.split(history,"\n")
		for i=1, #history_tbl do
			table.insert(history_tbl_r,table.remove(history_tbl))
		end
		for _,v in pairs(history_tbl_r) do
			if v ~= "" then
				tmp[1] = index
				tmp[2] = v:match("proto:(tcp)") or v:match("proto:(udp)") or ""
				tmp[3] = v:match("local_ip:(%d+%.%d+%.%d+%.%d+)") or ""
				tmp[4] = v:match("gateway:(%d+%.%d+%.%d+%.%d+)") or ""
				tmp[5] = v:match("server_ip:(%d+%.%d+%.%d+%.%d+)") or v:match("server_ip:(.-/%d+%.%d+%.%d+%.%d+)") or ""
				tmp[6] = v:match("rcvd_bytes:(%d+)") or "0"
				tmp[7] = v:match("sent_bytes:(%d+)") or "0"
				tmp[8] = ""
				tmp[9] = "0"
				local login_time = v:match("login_time:(%d+)") or ""
				local logout_time = v:match("logout_time:(%d+)") or ""
				if login_time ~= "" and logout_time ~= "" then
					tmp[8] = os.date("%Y-%m-%d %H:%M:%S",login_time)
					tmp[9] = tonumber(logout_time) - tonumber(login_time)
				end
				table.insert(hist_cont, tmp)
				tmp = {}
				index = index + 1
			end
		end
		info["hist_cont"] = hist_cont
	end
	
	luci.http.prepare_content("application/json")
	luci.http.write_json(info)
end

function action_cdrs()
	local fs  = require "luci.fs"
	local sys = require "luci.sys"
	local sqlite = require "luci.scripts.sqlite3_service"
	
	if luci.http.formvalue("export") then
		local cdr_info = ""
		local cdrs_file = "/tmp/CDRs"
		local localip = luci.http.getenv("SERVER_ADDR")
		local first_flag = true
		local ret_tb = {}
		
		ret_tb = sqlite.sqlite3_execute("/etc/freeswitch/cdr","select * from cdr order by created_time")

		--write into file
		local _file = io.open("/tmp/cdrs.xls","w+")
		if _file then
			local title_flag = true
			for k,v in pairs(ret_tb) do
				cdr_info = ""
				if title_flag then
					for k2,v2 in pairs(v) do
						cdr_info = cdr_info..k2.."\t"
					end
					title_flag = false
					_file:write(cdr_info.."\n")
				end
				cdr_info = ""
				for k2,v2 in pairs(v) do
					cdr_info = cdr_info..v2.."\t"
				end
				_file:write(cdr_info.."\n")
			end
			_file:close()
		end

		sys.call("tar -cz /tmp/cdrs.xls -f "..cdrs_file)
		local reader = luci.ltn12.source.file(io.open(cdrs_file,"r"))
		luci.http.header('Content-Disposition', 'attachment; filename="CDRs-%s-%s-%s.tar.gz"' % {luci.sys.hostname(), localip, os.date("%Y-%m-%d")})
		luci.http.prepare_content("application/gzip")
		luci.ltn12.pump.all(reader, luci.http.write)
		fs.unlink(cdrs_file)	
		fs.unlink("/tmp/cdrs.xls")
	elseif luci.http.formvalue("empty") then
		local ret_tb = sqlite.sqlite3_execute("/etc/freeswitch/cdr","delete from cdr")	
		luci.template.render("admin_status/cdr")
	else
		luci.template.render("admin_status/cdr")
	end
end
function action_get_cdrs()
	require "luci.util"
	local sqlite = require "luci.scripts.sqlite3_service"
	local str = luci.http.formvalue("cmd")
	local page = luci.http.formvalue("page")
	local cdr_info = {}
	local sql_condition = ""
	local sql_limit = ""
	local sql_cmd = ""
	
	if page then
		sql_limit = " order by created_time desc limit "..tostring((tonumber(page)-1)*100)..",100"
	end

	if str ~= " " then
		local list = luci.util.split(str,",")
		for i,j in pairs(list) do
			if j ~= "" then
				if sql_condition == "" then
					sql_condition = j
				else
					sql_condition = sql_condition.." and "..j
				end
			end
		end
	end

	if sql_condition == "" then
		sql_cmd = "select * from cdr"..sql_limit
	else
		sql_cmd = "select * from cdr where "..sql_condition..sql_limit
	end
	
	cdr_info = sqlite.sqlite3_execute("/etc/freeswitch/cdr",sql_cmd)

	for k,v in pairs(cdr_info) do
		if v.start_epoch then
			v.start_epoch = os.date("%Y-%m-%d %H:%M:%S", v.start_epoch)
		end
		if v.end_epoch then
			v.end_epoch = os.date("%m-%d %H:%M:%S", v.end_epoch)
		end
	end	
	luci.http.prepare_content("application/json")
	luci.http.write_json(cdr_info)
	return
end
function client_list()
	local uci = require "luci.model.uci".cursor()
	local fs = require "luci.fs"
	local ds = require "luci.dispatcher"
	local i18n = require "luci.i18n"

	local th = {"ID","Client Name","MAC Address","IP Address","Expiration","Status"}
	local colgroup = {"6%","28%","16%","17%","18%","15%"}
	local content = {}
	local leases_file = "/tmp/dhcp.leases"
	local detect_data = "/tmp/dhcp.onlines"
	local time_now=tonumber(os.time())

	if fs.access(leases_file) then
		local data = io.open(detect_data,"r") or io.open("leases_file")
		local index = 1
		if data then
			for line in data:lines() do
				local tmp = {}
				local parse_tb = luci.util.split(line," ")
				if 0 == tonumber(parse_tb[1]) or tonumber(parse_tb[1]) > time_now then -- Hide the result which expired.
					tmp[1] = index
					tmp[2] = parse_tb[4] or ""
					tmp[3] = string.upper(parse_tb[2] or "")
					tmp[4] = parse_tb[3] or ""
					if 0 == tonumber(parse_tb[1]) then
						tmp[5] = i18n.translate("Never Expires")
					else
						tmp[5] = os.date("%Y-%m-%d %H:%M:%S",parse_tb[1])
					end
					tmp[6] = i18n.translate(parse_tb[6] or "Offline")
					index = index + 1
					table.insert(content,tmp)
				end
			end
		end
	end
	luci.template.render("cbi/configlist",{
		title = i18n.translate("Status / DHCP Client List"),
		colgroup = colgroup,
		th = th,
		content = content,
		addnewable = false,
		})
end
