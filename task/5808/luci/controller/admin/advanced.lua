module("luci.controller.admin.advanced",package.seeall)

local util = require "luci.util"
local fs = require "nixio.fs"
local exe = require "os".execute

function index()
	if luci.http.getenv("SERVER_PORT") == 80 or luci.http.getenv("SERVER_PORT") == 443 or luci.http.getenv("SERVER_PORT") == 8848 then
		entry({"admin","advanced"},firstchild(),"高级",84).index = true
		entry({"admin","advanced","backup_restore"},call("action_backup_restore"),"备份/恢复",10).leaf = true
		entry({"admin","advanced","diagnostics"},call("action_diagnostics"),"检测",20).leaf = true
		entry({"admin","advanced","reboot"},call("action_reboot"),"重启",30).leaf = true

		entry({"admin","advanced","detectstatus"},call("detect_status"))
	end
end

function detect_status()
	local status = nixio.fs.readfile("/tmp/detect_status")
	--local status = "test"

	if status then
		luci.http.write(status)
	else
		luci.http.write("No data\n")
	end
end

function start_diagnostics(string)
	local ubus_get_addr = require "luci.model.network".ubus_get_addr
	local uci = require "luci.model.uci".cursor()
	local access_mode = uci:get("network_tmp","network","access_mode") or "wired_dhcp"
	local write_str = "access_mode:"..access_mode.."; "
	local request_str = string
	local ipaddr,netmask,gateway,dns = ubus_get_addr("wan")
	local dns_tb = util.split(dns," ") or {}

	exe("rm /tmp/detect_status")

	if request_str:match("(%%ipaddr%%)") then
		write_str = write_str.."ipaddr:"
		fs.writefile("/tmp/detect_status",write_str)

		if ipaddr and ipaddr ~= "" and ipaddr ~= "0.0.0.0" then
			local num = 0
			while num < 3 do
				local result = util.exec("ping -c 5 -W 1 2>&1 "..ipaddr.." | grep 'loss'")
				result = result:match("(%d+)%%")
				if result and result ~= "" and result ~= "100" then
					break
				end
				num = num + 1
			end
			if num == 3 then
				write_str = write_str.."fail; "
				fs.writefile("/tmp/detect_status",write_str)
				return
			else
				write_str = write_str.."success; "
				fs.writefile("/tmp/detect_status",write_str)
			end
		else
			write_str = write_str.."fail; "
			fs.writefile("/tmp/detect_status",write_str)
			return
		end
	end

	if request_str:match("(%%gateway%%)") then
		write_str = write_str.."gateway:"
		fs.writefile("/tmp/detect_status",write_str)

		if gateway and gateway ~= "" and gateway ~= "0.0.0.0" then
			local num = 0

			while num < 3 do
				local result = util.exec("ping -c 5 -W 1 2>&1 "..gateway.." | grep 'loss'")
				result = result:match("(%d+)%%")
				if result and result ~= "" and result ~= "100" then
					break
				end
				num = num + 1
			end
			if num == 3 then
				write_str = write_str.."fail; "
				fs.writefile("/tmp/detect_status",write_str)
				return
			else
				write_str = write_str.."success; "
				fs.writefile("/tmp/detect_status",write_str)
			end
		else
			write_str = write_str.."fail; "
			fs.writefile("/tmp/detect_status",write_str)
			return
		end
	end

	if request_str:match("(%%dns%%)") then
		write_str = write_str.."dns:"
		fs.writefile("/tmp/detect_status",write_str)

		if dns_tb and next(dns_tb) then
			local loop_num = 0
			for k,v in pairs(dns_tb) do
				if v and v ~= "" then
					local result = util.exec("ping -c 5 -W 1 2>&1 "..v.." | grep 'loss'")
					result = result:match("(%d+)%%")
					if result and result ~= "" and result ~= "100" then
						write_str = write_str.."success; "
						fs.writefile("/tmp/detect_status",write_str)
						break
					end
				end
				loop_num = loop_num + 1
			end
			if loop_num == #dns_tb then
				write_str = write_str.."fail; "
				fs.writefile("/tmp/detect_status",write_str)
				return
			end
		else
			write_str = write_str.."fail; "
			fs.writefile("/tmp/detect_status",write_str)
			return
		end
	end

	if request_str:match("(%%baidu%%)") then
		local num = 0

		write_str = write_str.."baidu:"
		fs.writefile("/tmp/detect_status",write_str)
		while num < 3 do
			local result = util.exec("ping -c 5 -W 1 2>&1 www.baidu.com | grep 'loss'")
			result = result:match("(%d+)%%")
			if result and result ~= "" and result ~= "100" then
				break
			end
			num = num + 1
		end
		if num == 3 then
			write_str = write_str.."fail; "
			fs.writefile("/tmp/detect_status",write_str)
			return
		else
			write_str = write_str.."success; "
			fs.writefile("/tmp/detect_status",write_str)
		end
	end

	if request_str:match("(%%siptrunk.*%%)") then
		write_str = write_str.."siptrunk-connect:"
		fs.writefile("/tmp/detect_status",write_str)

		local tmp_tb = uci:get_all("endpoint_siptrunk") or {}
		local status
		if tmp_tb and next(tmp_tb) then
			for k,v in pairs(tmp_tb) do
				if v.index and v.index == "1" then
					status = v.status
					break
				end
			end
		end
		if status and status == "Enabled" then
			local num = 0
			local continue = true
			
			while num < 3 do
				local str = util.exec("fs_cli -x 'sofia status gateway 2_1' | sed -n '/Address/p' | tr '\n' '#'")
				local trunk_ipaddr = str:match("Address%s+([^#]*)#")
				if trunk_ipaddr and trunk_ipadddr ~= "" and trunk_ipaddr ~= "0.0.0.0" then
					local result = util.exec("ping -c 5 -W 1 2>&1 "..trunk_ipaddr.." | grep 'loss'")
					result = result:match("(%d+)%%")
					if result and result ~= "" and result ~= "100" then
						break
					end
				else
					exe("sleep 2");
				end
				num = num + 1
			end
			if num == 3 then
				write_str = write_str.."fail; siptrunk-register:"
				continue = false
			else
				write_str = write_str.."success; siptrunk-register:"
				continue = true
			end
			
			if continue then
				fs.writefile("/tmp/detect_status",write_str)
				num = 0

				while num < 10 do
					str = util.exec("fs_cli -x 'sofia status gateway 2_1' | sed -n '/^State/p' | tr '\n' '#'")
					trunk_status = str:match("State%s+([%u_]+)")
					if trunk_status == "REGED" then
						break
					end
					num = num + 1
					exe("sleep 1")
				end
				if num == 10 then
					write_str = write_str.."fail; "
				else
					write_str = write_str.."success; "
				end
			else
				write_str = write_str.."fail; "
			end
		else
			write_str = write_str.."fail; siptrunk-register:fail; "
		end
		fs.writefile("/tmp/detect_status",write_str)
	end

	if request_str:match("(%%sim%%)") then
		write_str = write_str.."sim:"
		fs.writefile("/tmp/detect_status",write_str)

		local tmp_tb = uci:get_all("endpoint_mobile") or {}
		local status
		if next(tmp_tb) then
			for k,v in pairs(tmp_tb) do
				if v.slot_type and (v.slot_type == "1-GSM" or v.slot_type == "1-LTE") then
					status = v.status
					break
				end
			end
		end
		if status and status == "Enabled" then
			local num = 0
			local chan_ready = ""
			local simpin_state = ""
			local not_registered = ""
			while num < 5 do
				local tmp_str = util.exec("fs_cli -x 'gsm dump 1' | sed -n '/^chan_ready/p;/simpin_state/p;/^not_registered/p' | tr '\n' '#'")
				chan_ready = tmp_str:match("chan_ready = ([^#]+)#") or ""
				simpin_state = tmp_str:match("simpin_state = ([^#]+)#") or ""
				not_registered = tmp_str:match("not_registered = (%d+)") or ""
				if chan_ready == "1" and simpin_state == "SIMPIN_READY" and not_registered == "0" then
					break
				end
				num = num + 1
				exe("sleep 1")
			end
			if chan_ready ~= "1" then
				write_str = write_str.."fail,no_device; "
			else
				if simpin_state ~= "SIMPIN_READY" then
					write_str = write_str.."fail,no_card; "
				else
					if not_registered ~= "0" then
						write_str = write_str.."fail,not_registered; "
					else
						write_str = write_str.."success; "
					end
				end
			end
		else
			write_str = write_str.."fail,disabled; "
		end
		fs.writefile("/tmp/detect_status",write_str)
	end

	if request_str:match("(%%dDns%%)") then
		write_str = write_str.."dDns:"
		fs.writefile("/tmp/detect_status",write_str)

		if uci:get("ddns","myddns_ipv4","enabled") == "1" then
			local num = 0
			while num < 15 do
				local result = util.exec("tail /tmp/log/ddns/myddns_ipv4.log")
				local ddns_status_flag

				if not fs.access("/usr/bin/wget") and not fs.access("/usr/bin/curl") then
					ddns_status_flag = false
				elseif result:match("local ip =: '%d+%.%d+%.%d+%.%d+' detected via web at '.+'\n%s*%*%*%*%*%*%* WAITING =: %d+ seconds %(Check Interval%) before continue\n$") or result:match("local ip =: '%d+%.%d+%.%d+%.%d+' detected on network 'wan'\n%s*%*%*%*%*%*%* WAITING =: %d+ seconds %(Check Interval%) before continue\n$")then
					local time = result:match("WAITING =: (%d+) seconds %(Check Interval%) before continue\n$")
					local local_ip = result:match("resolved ip =: '(%d+%.%d+%.%d+%.%d+)'")
					if local_ip and time then
						ddns_status_flag = true
					end
				elseif string.find(result,"DDNS Provider answered") then
					local answer = result:match("DDNS Provider answered %[(.+)%]") or ""
					if "good" == answer or "nochg" == answer or answer:match("good %d+%.%d+%.%d+%.%d+") or answer:match("nochg %d+%.%d+%.%d+%.%d+") then
						ddns_status_flag = true
					end
				else
					ddns_status_flag = false
				end

				if ddns_status_flag then
					break
				end
				num = num + 1
				exe("sleep 1")
			end
			if num == 15 then
				write_str = write_str.."fail; "
			else
				write_str = write_str.."success; "
			end

			local ddns_addr = uci:get("ddns","myddns_ipv4","domain")
			if ddns_addr then
				local num = 0
				while num < 3 do
					local result = util.exec("ping -c 5 -W 1 2>&1 "..ddns_addr.." | grep 'loss'")
					result = result:match("(%d+)%%")
					if result and result ~= "" and result ~= "100" then
						break
					end
					num = num + 1
				end
				if num == 3 then
					write_str = write_str.."fail; "
				else
					write_str = write_str.."success; "
				end
			else
				write_str = write_str.."fail; "
			end
		else
			write_str = write_str.."fail; "
		end
		fs.writefile("/tmp/detect_status",write_str)
	end

	if request_str:match("(%%l2tp%%)") then
		write_str = write_str.."l2tp:"
		fs.writefile("/tmp/detect_status",write_str)

		if uci:get("xl2tpd","main","enabled") == "1" then
			local num = 0
			while num < 5 do
				local str = util.exec("tail -n 1 /ramlog/l2tpc_log | grep '^login:'")
				if str ~= "" then
					break
				end
				num = num + 1
				exe("sleep 1")
			end
			if num == 5 then
				write_str = write_str.."fail; "
			else
				write_str = write_str.."success; "
			end
		end
		fs.writefile("/tmp/detect_status",write_str)
	end

	if request_str:match("(%%pptp%%)") then
		write_str = write_str.."pptp:"
		fs.writefile("/tmp/detect_status",write_str)

		if uci:get("pptpc","main","enabled") == "1" then
			local num = 0
			while num < 5 do
				local str = util.exec("tail -n 1 /ramlog/pptpc_log | grep '^login:'")
				if str ~= "" then
					break
				end
				num = num + 1
				exe("sleep 1")
			end
			if num == 5 then
				write_str = write_str.."fail; "
			else
				write_str = write_str.."success; "
			end
		end
		fs.writefile("/tmp/detect_status",write_str)
	end

	if request_str:match("(%%openvpn%%)") then
		write_str = write_str.."openvpn:"
		fs.writefile("/tmp/detect_status",write_str)

		if uci:get("openvpn","custom_config","enabled") == "1" then
			local num = 0
			while num < 5 do
				local str = util.exec("tail -n 1 /ramlog/openvpnc_log | grep '^login:'")
				if str ~= "" then
					break
				end
				num = num + 1
				exe("sleep 1")
			end
			if num == 5 then
				write_str = write_str.."fail; "
			else
				write_str = write_str.."success; "
			end
			fs.writefile("/tmp/detect_status",write_str)
		end
		fs.writefile("/tmp/detect_status",write_str)
	end
end

function action_diagnostics()
	local uci = require "luci.model.uci".cursor()

	if luci.http.formvalue("action") == "start" then
		local str = luci.http.formvalue("string") or ""
		fs.writefile("/tmp/detect_option",str)
		util.exec("touch /tmp/detect_working")

		start_diagnostics(str)
		util.exec("rm /tmp/detect_working")

		return
	else
		local status = "test_stop"
		local detecting_str = ""
		local ddns = uci:get("ddns","myddns_ipv4","enabled") == "1" and "1" or "0"
		local l2tp = uci:get("xl2tpd","main","enabled") == "1" and "1" or "0"
		local pptp = uci:get("pptpc","main","enabled") == "1" and "1" or "0"
		local openvpn = uci:get("openvpn","custom_config","enabled") == "1" and "1" or "0"
		local siptrunk = "0"
		local sim = "0"
		local tmp_tb = uci:get_all("endpoint_siptrunk") or {}
		if tmp_tb and next(tmp_tb) then
			for k,v in pairs(tmp_tb) do
				if v.index and v.index == "1" then
					siptrunk = v.status == "Enabled" and "1" or "0"
					break
				end
			end
		end
		tmp_tb = uci:get_all("endpoint_mobile") or {}
		if tmp_tb and next(tmp_tb) then
			for k,v in pairs(tmp_tb) do
				if v.index and v.index == "2" then
					sim = v.status == "Enabled" and "1" or "0"
					break
				end
			end
		end
		if fs.access("/tmp/detect_working") then
			status = "test_working"
			detecting_str = fs.readfile("/tmp/detect_option")
		end

		luci.template.render("admin_advanced/detect", {
			status = status,
			siptrunk = siptrunk,
			ddns = ddns,
			pptp = pptp,
			l2tp = l2tp,
			openvpn = openvpn,
			sim = sim,
			detecting_str = detecting_str
		})
	end
end

local syn_result = ""

function web_rpc_syn_cb(ret, ...)
	local fs  = require "luci.fs"
	for i,v in ipairs(arg) do
		syn_result = syn_result .. tostring(v)
	end
	if string.find(syn_result,"succ") and fs.access("/tmp/upgrading_flag") then
		os.execute("rm /tmp/upgrading_flag && echo upgrade >>/tmp/require_reboot && sleep 2 && killall logread")
	else
		os.execute("rm /tmp/upgrading_flag && touch /tmp/upgraded_fail_flag && sleep 2 && killall logread")
	end
	os.execute("cat /tmp/upgrade_log_raw | awk '{$4=null;$5=null;$6=null;$7=null;$8=null;$9=null;print}' >/tmp/upgrade_log")
	os.execute("sed -i 's/freeswitch/SwitchCore/g' /tmp/upgrade_log")
	os.execute("sed -i 's/luci/Web/g' /tmp/upgrade_log")
end

function web_rpc_syn(timeout, server, method, filetype, file, cb)
	require("dpr")
	local ch = dpr.newrpc(server, "cli", "cli")
	local time = 0
	ch:addparam("command", method)

	if number == type(timeout) then
		time = timeout
	else
		time = tonumber(timeout)*1000
	end
   	ch:addparam("argv", filetype)
   	ch:addparam("argv", file)

	ch:call(time, true, cb)
end

function pack_to_ld(srcfilename,destfilename)
	require("dpr")
	require("ini")

	local ini = INI.load("/etc/provision/control.conf")

	local hdr = {}
	hdr.product = dpr.getproduct() or "uc100-unknown"
	hdr.version = ini['firmware']['version']
	hdr.type = "config"

	if hdr.product and hdr.product:match("^%w+%-") then
		hdr.product=hdr.product:match("^(%w+)%-")
	end

	dpr.packld(srcfilename,destfilename,hdr)
end

function unpackld(srcfilename,destfilename)
	require("dpr")
	local fs  = require "luci.fs"

	if srcfilename and fs.access(srcfilename) then
		dpr.unpackld(srcfilename,destfilename)
	end
end

function reset_to_default_setting(param)
	local rst_list = ""
	for k,v in pairs(param) do
		rst_list = rst_list..k
	end
	os.execute("lua /usr/lib/lua/luci/scripts/reset_default_config.lua "..rst_list)
	os.execute("sync && sleep 1")
	os.execute("reboot -f")
end
function check_backup_available()
	if "" == luci.version.model or "" == luci.version.sn then
		return false
	end
	return true
end
function check_service_status()
	local ps = luci.util.exec("ps")
	local provision = false
	local freeswitch = false

	if string.find(ps,"/bin/provision") then
		provision = true
	end

	if string.find(ps,"/bin/freeswitch") then
		freeswitch = true
	end

	return provision,freeswitch
end
function backup()
	local sys = require "luci.sys"
	local fs  = require "luci.fs"
	local bkp_list = luci.http.formvaluetable("backup")
	local localip = luci.http.getenv("SERVER_ADDR")
	local backup_cmd  = "tar -czT %s -f "
	local filelist = "/tmp/luci-backup-list.%d" % os.time()
	local filetar = filelist..".tar.gz"
	local finalbackup = filelist..".config"
	local cfg_backup_cmd = " "

	if bkp_list.system then
		cfg_backup_cmd = cfg_backup_cmd.."find /etc/config/system -type f ;"
		cfg_backup_cmd = cfg_backup_cmd.."find /etc/config/cloud -type f ;"
		cfg_backup_cmd = cfg_backup_cmd.."find /etc/config/easycwmp -type f ;"
		cfg_backup_cmd = cfg_backup_cmd.."find /etc/provision/provision.conf -type f ;"
		cfg_backup_cmd = cfg_backup_cmd.."find /etc/logsrv/mod_log.conf -type f ;"
		cfg_backup_cmd = cfg_backup_cmd.."find /etc/passwd -type f ;"
		cfg_backup_cmd = cfg_backup_cmd.."find /etc/config/luci -type f;"
		cfg_backup_cmd = cfg_backup_cmd.."find /etc/freeswitch/sounds/zh/cn/callie/welcome.* -type f;"
		cfg_backup_cmd = cfg_backup_cmd.."find /etc/freeswitch/sounds/en/us/callie/welcome.* -type f;"
	end
	if bkp_list.network then
		cfg_backup_cmd = cfg_backup_cmd.."find /etc/config/lucid -type f ;"
		cfg_backup_cmd = cfg_backup_cmd.."find /etc/config/telnet -type f ;"
		cfg_backup_cmd = cfg_backup_cmd.."find /etc/config/dropbear -type f ;"
		cfg_backup_cmd = cfg_backup_cmd.."find /etc/config/network -type f ;"
		cfg_backup_cmd = cfg_backup_cmd.."find /etc/config/wireless -type f ;"
		cfg_backup_cmd = cfg_backup_cmd.."find /etc/config/dhcp -type f ;"
		cfg_backup_cmd = cfg_backup_cmd.."find /etc/config/ddns -type f ;"
		cfg_backup_cmd = cfg_backup_cmd.."find /etc/config/mwan3 -type f ;"
		cfg_backup_cmd = cfg_backup_cmd.."find /etc/config/static_route -type f ;"
		cfg_backup_cmd = cfg_backup_cmd.."find /etc/config/upnpc -type f ;"
		cfg_backup_cmd = cfg_backup_cmd.."find /etc/config/firewall -type f ;"
		cfg_backup_cmd = cfg_backup_cmd.."find /etc/config/openvpn -type f ;"
		cfg_backup_cmd = cfg_backup_cmd.."find /etc/config/pptpc -type f ;"
		cfg_backup_cmd = cfg_backup_cmd.."find /etc/config/xl2tpd -type f ;"
		cfg_backup_cmd = cfg_backup_cmd.."find /etc/openvpn/my-vpn.conf -type f ;"
	end
	if bkp_list.service then
		cfg_backup_cmd = cfg_backup_cmd.."find /etc/config -name 'profile_*' -type f ;"
		cfg_backup_cmd = cfg_backup_cmd.."find /etc/config -name 'endpoint_*' -type f ;"

		cfg_backup_cmd = cfg_backup_cmd.."find /etc/config/callcontrol -type f ;"
		cfg_backup_cmd = cfg_backup_cmd.."find /etc/config/route -type f ;"
		cfg_backup_cmd = cfg_backup_cmd.."find /etc/config/fax -type f ;"
		cfg_backup_cmd = cfg_backup_cmd.."find /etc/config/feature_code -type f ;"
		cfg_backup_cmd = cfg_backup_cmd.."find /etc/config/ivr -type f ;"
	end
	if cfg_backup_cmd ~= " " then
		sys.call("( "..cfg_backup_cmd.." ) | sort -u > %s" % filelist)
		sys.call(backup_cmd:format(filelist)..filetar)

		if fs.access(filetar) then
			pack_to_ld(filetar,finalbackup)
			local reader = luci.ltn12.source.file(io.open(finalbackup,"r"))
			luci.http.header('Content-Disposition', 'attachment; filename="backup-%s-%s-%s.config"' % {luci.sys.hostname(), localip, os.date("%Y-%m-%d")})
			luci.http.prepare_content("application/ld")
			luci.ltn12.pump.all(reader, luci.http.write)
			fs.unlink(finalbackup)
		end
	end
end
function action_backup_restore()
	local sys = require "luci.sys"
	local fs  = require "luci.fs"
	local uci = require "luci.model.uci".cursor()
	local req_from = (luci.http.getenv("REMOTE_ADDR") or "") ..":".. (luci.http.getenv("REMOTE_PORT") or "")
	local fs_server = require "luci.scripts.fs_server"
	local restore_avail = check_backup_available()
	local provision_avail, fs_avail = check_service_status()
	local mac = uci:get("network","lan","macaddr")
	local destfile = "/tmp/latest_upload_file"
	local result_str = ""
	local reboot_flag=false

	local fp
	luci.http.setfilehandler(
		function(meta, chunk, eof)
			if not fp then
				if meta and (meta.name == "archive" or meta.name == "software") then
					fp = io.open(destfile,"w")
					os.execute("/etc/init.d/cron stop >>/dev/null 2>&1 && rm /tmp/luci-indexcache >>/dev/null 2>&1 ")
				end
			end
			if chunk then
				fp:write(chunk)
			end
			if eof and fp then
				fp:close()
				fp = nil
				local upgrade_type = luci.http.formvalue("upgrade_type")
				fs.writefile("/tmp/last_upgrade_start_time",os.time())
				os.execute("rm /tmp/fs-apply-status")
				os.execute("logread -f | grep 'user.debug provision' > /tmp/upgrade_log_raw &")
				if meta and "archive" == meta.name then
					os.execute("rm /etc/config/network_tmp")
					web_rpc_syn(50000, "provision", "cli-download", "config", destfile, web_rpc_syn_cb)
				end
			end
		end
	)

	if luci.http.formvalue("backup") then
		log.web_operation_log("Info",req_from.." | ".."Backup /admin/system/backup_upgrade")
		backup()
	elseif luci.http.formvalue("restore") then
		local upload = luci.http.formvalue("archive")
		if string.find(syn_result,"succ") then
			local succ_detail = fs.readfile("/tmp/fs-apply-status")
			if string.find(succ_detail,"ApplyFail") then
				syn_result = "Restore config data succ but apply fail !"
			else
				syn_result = "Restore Succ !"
				os.execute("echo restore >>/tmp/require_reboot")
			end
			log_str = req_from.." | ".."RestoreSucc /admin/system/backup_upgrade"
		else
			syn_result = "Restore Fail !"
			log_str = req_from.." | ".."RestoreFail /admin/system/backup_upgrade"
		end
		result_str = syn_result

		uci:set("network","lan","macaddr",mac)
		uci:commit("network")
		os.execute("rm /etc/config/vpnselect -rf")

		if upload and #upload > 0 then
			luci.template.render("admin_advanced/flashops", {
			step = "index",
			result = result_str,
			restore_avail = restore_avail,
			provision_avail = provision_avail,
			fs_avail = fs_avail,
		})
		end
	elseif luci.http.formvalue("reset") then
		local rst_list = luci.http.formvaluetable("reset")
		local localip = luci.http.getenv("SERVER_ADDR")
		local log_str = req_from.." | ".."Reset /admin/system/backup_upgrade"
		log.web_operation_log("Info",log_str)

		luci.template.render("admin_advanced/applyreboot", {
			title = luci.i18n.translate("Erasing..."),
			msg   = luci.i18n.translate("The system is erasing the config data now and will reboot itself when finished."),
		})
		reset_to_default_setting(rst_list)
	else
		luci.template.render("admin_advanced/flashops", {
			result = result_str,
			restore_avail = restore_avail,
			provision_avail = provision_avail,
			fs_avail = fs_avail
		})
	end
end

function action_reboot()
	local dsp = require "luci.dispatcher"
	luci.http.redirect(dsp.build_url("admin","system","reboot"))
	return
end
