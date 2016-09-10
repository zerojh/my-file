module("luci.controller.admin.status", package.seeall)

function index()
	entry({"admin", "status"}, alias("admin", "status", "overview"), _("Status"), 20).index = true
	entry({"admin", "status", "overview"}, template("admin_status/index"), _("Overview"), 1)
	entry({"admin", "status", "sipstatus"}, template("admin_status/sipstatus"), _("SIP"), 2)
	entry({"admin", "status", "pstnstatus"}, template("admin_status/pstnstatus"), _("PSTN"), 3)
	entry({"admin","status","client_list"},call("client_list"),_("DHCP Client List"),4).leaf = true

	entry({"admin", "status", "vpn"},alias("admin","status","vpn","pptp_client"),_("VPN"),5)
	--entry({"admin", "status", "vpn","l2tp_client"},call("action_l2tp_client"),_("L2TP Client"),40).leaf = true 
	entry({"admin", "status", "vpn","l2tp_client"},template("admin_status/l2tp_c_list"),_("L2TP Client"),40).leaf = true 
	entry({"admin", "status", "vpn","pptp_client"},call("action_pptp_client"),_("PPTP Client"),50).leaf = true 
	entry({"admin", "status", "vpn","openvpn_client"},template("admin_status/openvpn_c_list"),_("OpenVPN Client"),60).leaf = true 
	-- AJAX request.
	entry({"admin", "status", "vpn","more","l2tp_client"},call("action_l2tp_client_more"),"More",10).dependent = false
	entry({"admin", "status", "vpn","more","pptp_client"},call("action_pptp_client_more"),"More",10).dependent = false

	entry({"admin", "status", "currentcall"}, template("admin_status/currentcall"), _("Current Call"), 5)
	entry({"admin", "status", "cdr"}, call("action_cdrs"), _("CDRs"), 6)
	entry({"admin", "status", "service"}, template("admin_status/service"),_("Service"),7)
	entry({"admin", "status", "about"}, template("admin_status/about"),_("About"),8)
	page = entry({"admin","status","getcdrs"},call("action_get_cdrs"),nil)
	page.leaf = true
end

function change_packets_view(packets)
	local ret_str = ""

	if packets then
		if tonumber(packets) > 1024*1024*1024 then
			ret_str = string.format("%.2f",tonumber(packets)/(1024*1024*1024)).."GB"
		elseif tonumber(packets) > 1024*1024 then
			ret_str = string.format("%.2f",tonumber(packets)/(1024*1024)).."MB"
		elseif tonumber(packets) > 1024 then
			ret_str = string.format("%.2f",tonumber(packets)/1024).."KB"
		else
			ret_str = packets.."B"
		end
	end
	
	return ret_str
end

function action_l2tp_client_more()
	local util = require "luci.util"
	local param = luci.http.formvalue("action")
	local info = {}
	local live_cont = {}
	local hist_cont = {}

	if param == "auto" then
		-- l2tp client live show.
		local num_l2tp_log = util.exec("cat /ramlog/l2tpc_log | wc -l")
		num_l2tp_log = tonumber(num_l2tp_log)
		if num_l2tp_log and num_l2tp_log % 2 == 1 then
			local ppp_name = "ppp1701"
			local ret_cmd = util.exec("ifconfig "..ppp_name)
			local ifconfig_tbl = util.split(ret_cmd, "\n\n")

			local login_rec = util.exec("tail -n 1 /ramlog/l2tpc_log")
			-- '\004' means EOF.
			local login_rec_tbl = util.split(login_rec, '\004')

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
				tmp[2] = v:match("user:(.-),") or ""
				tmp[3] = v:match("local ip:(.-),") or ""
				tmp[4] = v:match("gateway:(.-),") or ""
				tmp[5] = v:match("server:(.-),") or ""
				tmp[7] = v:match("login date:(.*)") or ""
				local year,month,day,hour,min,sec = tmp[7]:match(pattern)
				tmp[8] = os.time() - os.time({year=year,month=month,day=day,hour=hour,min=min,sec=sec})
			end
			table.insert(live_cont, tmp)
			info["live_cont"] = live_cont
		end
		
		-- l2tp client connection history show.
		local first_num = 10
		local history
		if num_l2tp_log and 1 == num_l2tp_log % 2 then
			if first_num > (num_l2tp_log - 1) / 2 then
				first_num = (num_l2tp_log - 1) / 2
				history_num = first_num * 2
			else
				history_num = first_num * 2
			end
			local starti = num_l2tp_log - history_num
			if starti < 1 then
				starti = 1
			end
			history = util.exec("sed -n '"..starti..","..(num_l2tp_log-1).."p' /ramlog/l2tpc_log")
			history_num = history_num / 2
		else
			if first_num > num_l2tp_log / 2 then
				first_num = num_l2tp_log / 2
				history_num = first_num * 2
			else
				history_num = first_num * 2
			end
			history = util.exec("tail -n "..history_num.." /ramlog/l2tpc_log")
			history_num = history_num / 2
		end

		if history_num then
			local history_tbl = util.split(history, "\n")
			local insert_pos = 1
			local index = 1
			local list_sum = history_num + insert_pos - 1
			local tmp = {}
			local flag = 0
			for k, v in pairs(history_tbl) do
				if v and v:match("^login:") then
					tmp[1] = list_sum + insert_pos - index
					tmp[2] = v:match("user:(.-),") or ""
					tmp[3] = v:match("local ip:(.-),") or ""
					tmp[4] = v:match("gateway:(.-),") or ""
					tmp[5] = v:match("server:(.-),") or ""
					tmp[7] = v:match("login date:(.*)") or ""
					flag = flag + 1
				end
				if v and v:match("^logout:") then
					tmp[6] = change_packets_view(v:match("rcvd_bytes:(.-),") or "0").."/"..change_packets_view(v:match("sent_bytes:(.-),") or "0")
					tmp[8] = v:match("connect_time:(.-),") or ""
					flag = flag + 1
				end
				if 2 == flag then
					table.insert(hist_cont, insert_pos, tmp)
					tmp = {}
					flag = 0
					index = index + 1
				end
			end
			info["hist_cont"] = hist_cont
		end
		
	end
	luci.http.prepare_content("application/json")
	luci.http.write_json(info)
end

--[[
function action_l2tp_client_more()
	local util = require "luci.util"
	local request_uri = luci.http.getenv("REQUEST_URI")
	local exist_history_num, exist_num = request_uri:match("?h=([0-9]-)?s=([0-9]-)$")
	local one_more = 10

	local sum = util.exec("cat /ramlog/l2tpc_log | wc -l")
	local endi
	if 1 == sum % 2 then
		endi = tonumber(sum) - 1 - (tonumber(exist_history_num) * 2)
	else
		endi = tonumber(sum) - (tonumber(exist_history_num) * 2)
	end
	if 0 == endi then
		luci.http.write("<script>$('#showmoreconn').hide()</script>")
		return
	end
	local starti = endi - (one_more * 2) + 1;
	if starti <=0 then
		starti = 1
	end

	local history = util.exec("cat /ramlog/l2tpc_log | sed -n '"..starti..","..endi.."p'")
	local history_num = (endi - starti + 1) / 2
	local history_tbl = util.split(history, "\n")

	local index = exist_num + history_num
	local tbl_index = history_num
	local long_str_tbl = {}
	local tmp = {}
	local flag = 0
	for k, v in pairs(history_tbl) do
		if v and v:match("^login:") then
			local tmp2

			tmp[1] = "<tr id='row-"..index.."' "

			if 1 == index % 2 then
				tmp[2] = "class='cbi-rowstyle-odd'>"
			else
				tmp[2] = "class='cbi-rowstyle-even'>"
			end

			tmp[3] = "<td>"..index.."</td>"

			tmp2 = v:match("user:(.-),") or ""
			tmp[4] = "<td>"..tmp2.."</td>"

			tmp2 = v:match("local ip:(.-),") or ""
			tmp[5] = "<td>"..tmp2.."</td>"

			tmp2 = v:match("gateway:(.-),") or ""
			tmp[6] = "<td>"..tmp2.."</td>"

			tmp2 = v:match("server:(.-),") or ""
			tmp[7] = "<td>"..tmp2.."</td>"

			tmp2 = v:match("login date:(.*)") or ""
			tmp[10] = "<td>"..tmp2.."</td>"

			flag = flag + 1
		end
		if v and v:match("^logout:") then
			local tmp2

			tmp2 = change_packets_view(v:match("rcvd_bytes:(.-),") or "0")
			tmp[8] = "<td>"..tmp2.." / "

			tmp2 = change_packets_view(v:match("sent_bytes:(.-),") or "0")
			tmp[9] = tmp2.."</td>"

			tmp2 = v:match("connect_time:(.-),") or ""
			tmp[11] = "<td id='sectohuman-"..index.."' class='sectohuman' colspan='2'>"..tmp2.."</td>"

			flag = flag + 1
		end
		if 2 == flag then
			local long_str = ""
			for i, v in ipairs(tmp) do
				long_str = long_str..v
			end
			long_str_tbl[tbl_index] = long_str
			index = index - 1
			tbl_index = tbl_index - 1
			tmp = {}
			flag = 0
		end
	end

	for i, v in ipairs(long_str_tbl) do
		luci.http.write(v)
	end

	luci.http.write("<script>refresh_time_more("..(exist_num+1)..")</script>")

	if 1 == starti then
		luci.http.write("<script>$('#showmoreconn').hide()</script>")
		luci.http.write("<script>$('.the-end').show();</script>")
	end
end
]]--

function action_l2tp_client()
	local util = require "luci.util"

	local live_cont = {}
	local hist_cont = {}

	-- l2tp client live show.
	local live_num = 0
	local num_l2tp_log = util.exec("cat /ramlog/l2tpc_log | wc -l")
	num_l2tp_log = tonumber(num_l2tp_log)
	if num_l2tp_log and num_l2tp_log % 2 == 1 then
		local ppp_name = "ppp1701"
		local ret_cmd = util.exec("ifconfig "..ppp_name)
		local ifconfig_tbl = util.split(ret_cmd, "\n\n")

		local login_rec = util.exec("tail -n 1 /ramlog/l2tpc_log")
		-- '\004' means EOF.
		local login_rec_tbl = util.split(login_rec, '\004')

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
			tmp[2] = v:match("user:(.-),") or ""
			tmp[3] = v:match("local ip:(.-),") or ""
			tmp[4] = v:match("gateway:(.-),") or ""
			tmp[5] = v:match("server:(.-),") or ""
			tmp[7] = v:match("login date:(.*)") or ""
			local year,month,day,hour,min,sec = tmp[7]:match(pattern)
			tmp[8] = os.time() - os.time({year=year,month=month,day=day,hour=hour,min=min,sec=sec})
		end
		table.insert(live_cont, tmp)
		live_num = live_num + 1
	end
	
	-- l2tp client connection history show.
	local first_num = 10
	local history
	if num_l2tp_log and 1 == num_l2tp_log % 2 then
		if first_num > (num_l2tp_log - 1) / 2 then
			first_num = (num_l2tp_log - 1) / 2
			history_num = first_num * 2
		else
			history_num = first_num * 2
		end
		local starti = num_l2tp_log - history_num
		if starti < 1 then
			starti = 1
		end
		history = util.exec("sed -n '"..starti..","..(num_l2tp_log-1).."p' /ramlog/l2tpc_log")
		history_num = history_num / 2
	else
		if first_num > num_l2tp_log / 2 then
			first_num = num_l2tp_log / 2
			history_num = first_num * 2
		else
			history_num = first_num * 2
		end
		history = util.exec("tail -n "..history_num.." /ramlog/l2tpc_log")
		history_num = history_num / 2
	end

	if history_num then
		local history_tbl = util.split(history, "\n")
		local insert_pos = 1
		local index = 1
		local list_sum = history_num + insert_pos - 1
		local tmp = {}
		local flag = 0
		for k, v in pairs(history_tbl) do
			if v and v:match("^login:") then
				tmp[1] = list_sum + insert_pos - index
				tmp[2] = v:match("user:(.-),") or ""
				tmp[3] = v:match("local ip:(.-),") or ""
				tmp[4] = v:match("gateway:(.-),") or ""
				tmp[5] = v:match("server:(.-),") or ""
				tmp[7] = v:match("login date:(.*)") or ""
				flag = flag + 1
			end
			if v and v:match("^logout:") then
				tmp[6] = change_packets_view(v:match("rcvd_bytes:(.-),") or "0").."/"..change_packets_view(v:match("sent_bytes:(.-),") or "0")
				tmp[8] = v:match("connect_time:(.-),") or ""
				flag = flag + 1
			end
			if 2 == flag then
				table.insert(hist_cont, insert_pos, tmp)
				tmp = {}
				flag = 0
				index = index + 1
			end
		end
	end

	luci.template.render("admin_status/l2tp_c_list",{
		live_cont = live_cont,
		hist_cont = hist_cont,
		live_num = live_num,
	})
end

function action_pptp_client_more()
	local util = require "luci.util"
	local request_uri = luci.http.getenv("REQUEST_URI")
	local exist_history_num, exist_num = request_uri:match("?h=([0-9]-)?s=([0-9]-)$")
	local one_more = 10

	local sum = util.exec("cat /ramlog/pptpc_log | wc -l")
	local endi
	if 1 == sum % 2 then
		endi = tonumber(sum) - 1 - (tonumber(exist_history_num) * 2)
	else
		endi = tonumber(sum) - (tonumber(exist_history_num) * 2)
	end
	if 0 == endi then
		luci.http.write("<script>$('#showmoreconn').hide()</script>")
		return
	end
	local starti = endi - (one_more * 2) + 1;
	if starti <=0 then
		starti = 1
	end

	local history = util.exec("cat /ramlog/pptpc_log | sed -n '"..starti..","..endi.."p'")
	local history_num = (endi - starti + 1) / 2
	local history_tbl = util.split(history, "\n")

	local index = exist_num + history_num
	local tbl_index = history_num
	local long_str_tbl = {}
	local tmp = {}
	local flag = 0
	for k, v in pairs(history_tbl) do
		if v and v:match("^login:") then
			local tmp2

			tmp[1] = "<tr id='row-"..index.."' "

			if 1 == index % 2 then
				tmp[2] = "class='cbi-rowstyle-odd'>"
			else
				tmp[2] = "class='cbi-rowstyle-even'>"
			end

			tmp[3] = "<td>"..index.."</td>"

			tmp2 = v:match("user:(.-),") or ""
			tmp[4] = "<td>"..tmp2.."</td>"

			tmp2 = v:match("local ip:(.-),") or ""
			tmp[5] = "<td>"..tmp2.."</td>"

			tmp2 = v:match("gateway:(.-),") or ""
			tmp[6] = "<td>"..tmp2.."</td>"

			tmp2 = v:match("server:(.-),") or ""
			tmp[7] = "<td>"..tmp2.."</td>"

			tmp2 = v:match("login date:(.*)") or ""
			tmp[10] = "<td>"..tmp2.."</td>"

			flag = flag + 1
		end
		if v and v:match("^logout:") then
			local tmp2

			tmp2 = change_packets_view(v:match("rcvd_bytes:(.-),") or "0")
			tmp[8] = "<td>"..tmp2.." / "

			tmp2 = change_packets_view(v:match("sent_bytes:(.-),") or "0")
			tmp[9] = tmp2.."</td>"

			tmp2 = v:match("connect_time:(.-),") or ""
			tmp[11] = "<td id='sectohuman-"..index.."' class='sectohuman' colspan='2'>"..tmp2.."</td>"

			flag = flag + 1
		end
		if 2 == flag then
			local long_str = ""
			for i, v in ipairs(tmp) do
				long_str = long_str..v
			end
			long_str_tbl[tbl_index] = long_str
			index = index - 1
			tbl_index = tbl_index - 1
			tmp = {}
			flag = 0
		end
	end

	for i, v in ipairs(long_str_tbl) do
		luci.http.write(v)
	end

	luci.http.write("<script>refresh_time_more("..(exist_num+1)..")</script>")
	if 1 == starti then
		luci.http.write("<script>$('#showmoreconn').hide()</script>")
		luci.http.write("<script>$('.the-end').show();</script>")
	end
end

function action_pptp_client()
	local util = require "luci.util"

	local content = {}

	-- pptp client live show.
	local index = 1
	local live_num = 0
	local num_pptp_log = util.exec("cat /ramlog/pptpc_log | wc -l")
	num_pptp_log = tonumber(num_pptp_log)
	if num_pptp_log and num_pptp_log % 2 == 1 then
		local ppp_name = "ppp1723"
		local ret_cmd = util.exec("ifconfig "..ppp_name)
		local ifconfig_tbl = util.split(ret_cmd, "\n\n")

		local login_rec = util.exec("tail -n 1 /ramlog/pptpc_log")
		-- '\004' means EOF.
		local login_rec_tbl = util.split(login_rec, '\004')

		local tmp = {}
		-- index, username, local_ip, remote_ip, server_ip, rx, tx, login_time, conn_time.
		for k, v in pairs(ifconfig_tbl) do
			if v and v:match("^"..ppp_name) then
				tmp[1] = index
				tmp[6] = change_packets_view(v:match("RX bytes:([0-9]+)") or "0").." / "..change_packets_view(v:match("TX bytes:([0-9]+)") or "0")
			end
		end
		local pattern = "(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)"
		for k, v in pairs(login_rec_tbl) do
			tmp[2] = v:match("user:(.-),") or ""
			tmp[3] = v:match("local ip:(.-),") or ""
			tmp[4] = v:match("gateway:(.-),") or ""
			tmp[5] = v:match("server:(.-),") or ""
			tmp[7] = v:match("login date:(.*)") or ""
			local year,month,day,hour,min,sec = tmp[7]:match(pattern)
			tmp[8] = os.time() - os.time({year=year,month=month,day=day,hour=hour,min=min,sec=sec})
		end
		table.insert(content, tmp)
		index = index + 1
	end
	live_num = index - 1

	-- pptp client connection history show.
	local first_num = 10
	local history
	if num_pptp_log and 1 == num_pptp_log % 2 then
		if first_num > (num_pptp_log - 1) / 2 then
			first_num = (num_pptp_log - 1) / 2
			history_num = first_num * 2
		else
			history_num = first_num * 2
		end
		local starti = num_pptp_log - history_num
		if starti < 1 then
			starti = 1
		end
		history = util.exec("sed -n '"..starti..","..(num_pptp_log-1).."p' /ramlog/pptpc_log")
		history_num = history_num / 2
	else
		if first_num > num_pptp_log / 2 then
			first_num = num_pptp_log / 2
			history_num = first_num * 2
		else
			history_num = first_num * 2
		end
		history = util.exec("tail -n "..history_num.." /ramlog/pptpc_log")
		history_num = history_num / 2
	end

	if history_num then
		local history_tbl = util.split(history, "\n")
		local insert_pos = index
		local list_sum = history_num + insert_pos - 1
		local tmp = {}
		local flag = 0
		for k, v in pairs(history_tbl) do
			if v and v:match("^login:") then
				tmp[1] = list_sum + insert_pos - index
				tmp[2] = v:match("user:(.-),") or ""
				tmp[3] = v:match("local ip:(.-),") or ""
				tmp[4] = v:match("gateway:(.-),") or ""
				tmp[5] = v:match("server:(.-),") or ""
				tmp[7] = v:match("login date:(.*)") or ""
				flag = flag + 1
			end
			if v and v:match("^logout:") then
				tmp[6] = change_packets_view(v:match("rcvd_bytes:(.-),") or "0").." / "..change_packets_view(v:match("sent_bytes:(.-),") or "0")
				tmp[8] = v:match("connect_time:(.-),") or ""
				flag = flag + 1
			end
			if 2 == flag then
				table.insert(content, insert_pos, tmp)
				tmp = {}
				flag = 0
				index = index + 1
			end
		end
	end

	luci.template.render("admin_status/pptp_c_list",{
		content = content,
		live_num = live_num,
	})
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
