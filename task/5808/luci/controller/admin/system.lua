module("luci.controller.admin.system", package.seeall)

function index()
	if luci.http.getenv("SERVER_PORT") == 8345 or luci.http.getenv("SERVER_PORT") == 8848 then
		entry({"admin","system"},firstchild(),"System",30).dependent=false
		entry({"admin","system","setting"},cbi("admin_system/setting"),_("Setting"),1)
		entry({"admin","system","clock_status"},call("action_clock_status"))
		entry({"admin","system","security"},call("security"),_("User Manager"),2)
		entry({"admin","system","provision"},cbi("admin_system/provision"),_("Provision"),3)
		entry({"admin","system","operationlog"},call("operation_log"),_("Operation Log"),4)
		entry({"admin","system","servicelog"},call("service_log"),_("Service Log"),5)
		entry({"admin","system","changeslog"},call("changes_log"),_("Config Changes Log"),6)
		entry({"admin","system","backup_upgrade"},call("action_flashops"),_("Backup/Restore/Upgrade"),7)
		if luci.version.license and luci.version.license.gsm then
			entry({"admin","system","gsm_tools"},call("action_gsm_tools"),_("GSM Tools"),9)
		end
		entry({"admin","system","Voice"},call("action_tone"),_("Voice"),10)
		entry({"admin","system","cmd"},call("webcmd"),_("Command Line"),11)
		entry({"admin","system","diagnostics"},call("system_diagnostics"),_("Diagnostics"),12)
		entry({"admin", "system", "tr069"},cbi("admin_system/tr069"),_("TR069"),13)
		entry({"admin", "system", "cloud"},cbi("admin_system/cloud"),_("Cloud Server"),14)
		entry({"admin","system","get_ap_list"},call("wifi_list"))
		entry({"admin","system","upgrade_progress"},call("get_upgrade_progress"))
		entry({"admin","system","reboot"},call("action_reboot"),_("Reboot"),20)
	elseif luci.http.getenv("SERVER_PORT") == 80 then
		entry({"admin","system"})
		entry({"admin","system","reboot"},call("action_reboot"),_("Reboot"))
		entry({"admin","system","backup_upgrade"},call("action_flashops"),_("Backup/Restore/Upgrade"))
		entry({"admin","system","upgrade_progress"},call("get_upgrade_progress"))
	end
end
function get_upgrade_progress()
	local fs=require "nixio.fs"
	if fs.access("/tmp/update_state") then
		local s=fs.readfile("/tmp/update_state") or "unknown"
		if s:match("update_progress") then
			luci.http.prepare_content("text/plain")
			luci.http.write("upgrading")
		else
			luci.http.prepare_content("text/plain")
			luci.http.write(s)
		end
	elseif fs.access("/tmp/upgrading_flag") and not fs.access("/tmp/fs-apply-status") then
		luci.http.prepare_content("text/plain")
		luci.http.write("upgrading")
	elseif fs.access("/tmp/upgrading_flag") and fs.access("/tmp/fs-apply-status") then
		luci.http.prepare_content("text/plain")
		luci.http.write("applying")
	elseif fs.access("/etc/gsm_1_upgrading") or fs.access("/tmp/gsm_upgrading") then
		require "ESL"
		local con = ESL.ESLconnection("127.0.0.1","8021","ClueCon")
		if 1 == con:connected() then
			local s = con:api("gsm updatemodule 1 query"):getBody()
			local result,total_size,transmit_size=s:match("result:([0-9a-zA-Z_]+), total size:(%d+), transmit size:(%d+)")
			if total_size and transmit_size then
				if "LOAD_STEP_LOAD_SUCC" == result or "LOAD_STEP_LOAD_FAIL" == result then
					--/etc/下的标志是gsmopen控制的，升级成功后，gsmopen会把etc下的清掉，web上可能会出现卡在99%的情况，因为web请求进度时，该标志可能没了，尤其是当存在多个web用户同时在该页面时,
					--所以新增一个/tmp/下的标志来辅助
					fs.writefile("/tmp/rm_gsm_upgrading_flag.sh","sleep 3 && rm /tmp/gsm_upgrading\n".."rm /tmp/rm_gsm_upgrading_flag.sh")
					os.execute("sh /tmp/rm_gsm_upgrading_flag.sh&")
				end
				luci.http.prepare_content("text/plain")
				luci.http.write(result.."/"..transmit_size.."/"..total_size)
			else
				luci.http.prepare_content("text/plain")
				luci.http.write("LOAD_STEP_LOAD_FAIL/0/0")
			end
			con:disconnect()
		else
			luci.http.prepare_content("text/plain")
			luci.http.write("LOAD_STEP_LOAD_FAIL/0/0")
		end
	else
		local size=fs.stat("/tmp/latest_upload_file","size")
		luci.http.prepare_content("text/plain")
		luci.http.write(tostring(size or 0))
	end
end
function check_ready_status(m,ssid)
	require "ESL"
	local fxso = true
	local gsm = true
	local wifi = true
	local con = ESL.ESLconnection("127.0.0.1","8021","ClueCon")
	if 1 == con:connected() then
		if m:match("fxso") then
			local s = con:api("ftdm driver fxso status 0"):getBody()
			if s:match("state%s*:%s*OFFLINE") then
				fxso = false
			end
		end
		if m:match("gsm") then
			local s = con:api("gsm dump 1"):getBody()
			if not s:match("simpin_state%s*=%s*SIMPIN_READY") then
				gsm = false
			end
		end
		con:disconnect()
	end
	if m:match("wifi") then
		local s = luci.util.exec("iwlist wlan0 scanning")
		if not string.find(s,ssid) then
			wifi = false
		end
	end
	return fxso,gsm,wifi
end
function wifi_list()
	require "luci.sys"
	local s = luci.sys.exec("iwlist wlan0 scanning")
	local wifi_list = {}
	local start_pos,end_pos = string.find(s,"- Address:")
	local end_pos = string.find(s,"- Address:",end_pos) or string.len(s)
	
	while start_pos and end_pos do
		local wifi_str = string.sub(s,start_pos,end_pos)
		local t = {}
		t.ssid = wifi_str:match("ESSID:\"(.-)\"\n") or ""
		if wifi_str:match("Encryption key:off") then
			t.encrypt = "none"
			t.encrypt_alias = "NONE"
		elseif wifi_str:match("IE: IEEE 802.11i/WPA2 Version 1") then
			t.encrypt = "psk2"
			t.encrypt_alias = "WPA2+PSK"
		elseif wifi_str:match("IE: WPA Version 1") then
			t.encrypt = "psk"
			t.encrypt_alias = "WPA+PSK"
		else
			t.encrypt = "wpa"
			t.encrypt_alias = "WPA"
		end
		table.insert(wifi_list,t)
		start_pos = end_pos
		end_pos,_ = string.find(s,"- Address:",start_pos+5)
		if not end_pos then
			if tonumber(start_pos) ~= tonumber(string.len(s)) then
				end_pos = string.len(s)
			end
		end
	end
	-- local t={}
	-- t.ssid="test_uc0"
	-- t.encrypt="wpa2"
	-- t.encrypt_alias="WPA2+PSK"
	-- table.insert(wifi_list,t)
	luci.http.prepare_content("application/json")
	luci.http.write_json(wifi_list)
end

function get_diagnostics(m)
	local uci = require "luci.model.uci".cursor()
	local i18n = require "luci.i18n"
	local fs  = require "luci.fs"
	local s = ""

	if m:match("fxso") then
		local result=uci:get("tooltest","fxso","status") or ""
		s = s..i18n.translate("FXS/FXO Status").." : "..i18n.translate(result)
		if result:match("[A-Z%-]+/[A-Z%-]+") then
			local fxs_dtmf_recv=uci:get("tooltest","fxso","fxs_dtmf_recv") or ""
			local fxo_dtmf_recv=uci:get("tooltest","fxso","fxo_dtmf_recv") or ""
			s = s.." "..i18n.translate("Verification DTMF Result").." : "..fxs_dtmf_recv.."/"..fxo_dtmf_recv.." "..i18n.translate("Duration").." : "..uci:get("tooltest","fxso","duration").."s\n"
		else
			s = s.."\n"
		end
	end
	if m:match("gsm") then
		local ip=uci:get("tooltest","gsm","ip")
		local dtmf_recv=uci:get("tooltest","gsm","dtmf_recv")
		if ip then
			s = s..i18n.translate("LTE Status").." : "..i18n.translate((uci:get("tooltest","gsm","status") or ""))
		else
			s = s..i18n.translate("GSM Status").." : "..i18n.translate((uci:get("tooltest","gsm","status") or ""))
		end
		if "OK" == uci:get("tooltest","gsm","status") then
			if ip then
				s=s.." IP:"..ip
			elseif dtmf_recv then
				s=s.." "..i18n.translate("Verification DTMF Result").." : "..dtmf_recv
			end
			s = s.." "..i18n.translate("Duration").." : "..uci:get("tooltest","gsm","duration").."s\n"
		else
			s = s.."\n"
		end
	end
	if m:match("wifi") then
		s = s..i18n.translate("WIFI Status").." : "..i18n.translate((uci:get("tooltest","wifi","status") or ""))
		if "OK" == uci:get("tooltest","wifi","status") then
			s = s.."  AP("..(uci:get("tooltest","wifi","ssid") or "NULL").."),IP : "..(uci:get("tooltest","wifi","ip") or "NULL")..", "..i18n.translate("Netmask").." : "..(uci:get("tooltest","wifi","netmask") or "NULL")..", "..i18n.translate("Gateway").." : "..(uci:get("tooltest","wifi","gateway") or "NULL").." "..i18n.translate("Duration").." : "..uci:get("tooltest","wifi","duration").."s\n"
		else
			s = s.."\n"
		end
	end
	if fs.access("/tmp/tooltest_working") then
		return s
	else
		s = i18n.translate("Local Time").." : "..os.date("%Y-%m-%d %H:%M:%S",os.time()).."\n\n"..s	
		s = i18n.translate("Firmware Version").." : "..luci.version.firmware_ver.."\n"..s
		s = i18n.translate("Hardware ID").." : "..luci.version.hard_id.."\n"..s
		s = i18n.translate("Device SN").." : "..luci.version.sn.."\n"..s
		s = i18n.translate("Device Model").." : "..luci.version.model.."\n"..s
		os.execute("rm /tmp/tooltest_options")
		return s..i18n.translate("Diagnostics Finish !").."\n"
	end
end
function system_diagnostics()
	require "ESL"
	local sys = require "luci.sys"
	local fs  = require "luci.fs"
	local util = require "luci.util"
	local i18n = require "luci.i18n"
 	local uci = require "luci.model.uci".cursor()

	local test_status = "stop"
	local test_options = fs.readfile("/tmp/tooltest_options") or "fxso,gsm,wifi"

	if "1" == luci.http.formvalue("status") then
		luci.http.prepare_content("text/plain")
		luci.http.write(get_diagnostics(test_options))
	elseif "start" == luci.http.formvalue("action") then
		local test_mod = luci.http.formvalue("mod")
		local ap,ssid,encrypt,pass
		if test_mod:match("wifi") then
			ap = luci.http.formvalue("ap") or "unknown"
			ssid,encrypt=ap:match("^(.+)%%([wpa2sknone]+)$")
			pass = luci.http.formvalue("pass") or ""
		end
		fxso,gsm,wifi = check_ready_status(test_mod,ssid or "unknown")
		if fxso and gsm and wifi then
			fs.writefile("/tmp/tooltest_options",test_mod)
			if test_mod:match("wifi") then
				os.execute("lua /usr/lib/lua/luci/scripts/system_diagnostics.lua "..test_mod.." "..ssid.." "..encrypt.." "..pass.." &")
			else
				os.execute("lua /usr/lib/lua/luci/scripts/system_diagnostics.lua "..test_mod.." &")
			end
			luci.http.prepare_content("text/plain")
			luci.http.write("start succ")
		else
			local str = ""
			str = str..(fxso and "" or i18n.translate("Please connect FXS and FXO with telephone line !") .."\n")
			str = str..(gsm and "" or i18n.translate("Please insert SIM card !").."\n")
			str = str..(wifi and "" or i18n.translatef("Can not found AP with SSID(%s)",ssid or "NULL").."\n")
			luci.http.prepare_content("text/plain")
			luci.http.write(str)
		end	
	elseif "stop" == luci.http.formvalue("action") then
		os.execute("rm /tmp/tooltest_working && rm /tmp/tooltest_options")
		uci:set("tooltest","fxso","status","Stop")
		uci:set("tooltest","gsm","status","Stop")
		uci:set("tooltest","wifi","status","Stop")
		uci:commit("tooltest")
		luci.http.prepare_content("text/plain")
		luci.http.write("stop")
	else
		if fs.access("/tmp/tooltest_working") then
			test_status = "test_working"
		end
		local fxo_online=util.exec("fs_cli -x \"ftdm driver fxso status 0\" | grep ONLINE")
		if fxo_online == "" then
			fxo_online=false
		end
		local sim_ready=util.exec("fs_cli -x \"gsm dump 1\" | grep SIMPIN_READY")
		if sim_ready == "" then
			sim_ready=false
		end
		luci.template.render("admin_system/diagnostics",{fxo_online=fxo_online,sim_ready=sim_ready,test_status=test_status,test_options=test_options})
	end
end

function action_gsm_tools()
	require "ESL"
	local uci = require "luci.model.uci".cursor()

	local imei_avail_flag = false
	local imei = "000000000000000"
	local imei_result = ""

	local con = ESL.ESLconnection("127.0.0.1","8021","ClueCon")

	if luci.http.formvalue("new_imei") and luci.http.formvalue("imei_modify_btn") then
		local new_imei = luci.http.formvalue("new_imei")
		if con:connected() == 1 and new_imei:match("^%d+$") and 15 == string.len(new_imei) then
			local str = con:api("gsm modify_imei 1 "..new_imei):getBody()
			if str:match("OK") then
				imei_result = "Modify IMEI Success !"
			else
				imei_result = "Modify IMEI Fail !"
			end
		end
	end

	if con:connected() == 1 then
		local str = con:api("gsm dump 1"):getBody()
		if str and string.find(str,"dev_state = DEV_READY") and string.find(str,"chan_ready = 1") then
			imei_avail_flag = true
			imei = str:match("imei%s*=%s*(%d+)")
		end
		con:disconnect()
	end

	if luci.http.formvalue("bcch") and luci.http.formvalue("bcch_save_btn") then
		local bcch = luci.http.formvalue("bcch")
		local gsm = uci:get_all("endpoint_mobile")
		for k,v in pairs(gsm) do
			if v and "1-GSM" == v.slot_type then
				uci:set("endpoint_mobile",k,"bcch",bcch or "default")
				uci:save("endpoint_mobile")
			end
		end
	end

	local fs = require "luci.scripts.fs_server"
	bcch = fs.bcch_list(1) or {}

	luci.template.render("admin_system/gsm_tools",{
		imei_avail_flag = imei_avail_flag,
		imei = imei,
		result = imei_result,
		bcch = bcch,
		})
end

function action_tone()
	local sys = require "luci.sys"
	local fs  = require "luci.fs"
	local ds = require "luci.dispatcher"
	local uci = require "luci.model.uci".cursor()
	local fs_server = require "luci.scripts.fs_server"
	local result = "Fail"
	local destfile = "/tmp/welcome.wav"

	local fp
	luci.http.setfilehandler(
		function(meta, chunk, eof)
			if not fp then
				if meta and meta.name then
					fp = io.open(destfile,"w")	
				end
			end
			if chunk then
				fp:write(chunk)
			end
			if eof and fp then
				fp:close()
				fp = nil
				local lang = uci:get("callcontrol","voice","lang") or "en"
				result = fs_server.set_audio_file(lang)
				if result:match("Fail") then
					os.execute("rm "..destfile)
				end
			end
		end
	)

	if luci.http.formvalue("upload") then
		local upload = luci.http.formvalue("welcome")

		if upload and #upload > 0 then
			luci.template.render("admin_system/tone", {
			result = result,
			status = "true"
		})
		end
	else
		luci.template.render("admin_system/tone", {
			result = "",
			status = "false"
		})		
	end
end
function security()
	if "save" == luci.http.formvalue("action") then
		local user = luci.http.formvalue("user")
		local oldpw = luci.http.formvalue("oldpw")
		local msg = ""
		if "root" ~= user and luci.sys.user.checkpasswd(user,oldpw) then
			local v1 = luci.http.formvalue("newpw_1")
			local v2 = luci.http.formvalue("newpw_2")

			if v1 and v2 and #v1 > 0 and #v2 > 0 then
				if v1 == v2 then
					if luci.sys.user.setpasswd(user, v1) == 0 then
						msg = "Password successfully changed!"
						os.execute("rm /tmp/luci-sessions/*")
					else
						msg = "Unknown Error, password not changed!"
					end
				else
					msg = "Given password confirmation did not match, password not changed!"
				end
			end
		else
			msg = "Username or old password error, password not changed !"
		end
		luci.template.render("admin_system/security",{message = msg})
	else
		luci.template.render("admin_system/security")
	end
end

function action_clock_status()
	local set = tonumber(luci.http.formvalue("set"))
	if set ~= nil and set > 0 then
		local date = os.date("*t", set)
		if date then
			-- prevent session timeoutby updating mtime
			nixio.fs.utimes(luci.sauth.sessionpath .. "/" .. luci.dispatcher.context.authsession, set, set)

			luci.sys.call("date -s '%04d-%02d-%02d %02d:%02d:%02d' && hwclock -w -u" %{
				date.year, date.month, date.day, date.hour, date.min, date.sec
			})

			require "ESL"
			local con = ESL.ESLconnection("127.0.0.1","8021","ClueCon")
			if 1 == con:connected() then
				con:bgapi("fsctl sync_clock")
				con:disconnect()
			end
		end
	end

	luci.http.prepare_content("application/json")
	luci.http.write_json({ timestring = os.date("%Y-%m-%d %X") })
end

function operation_log()
	if luci.http.formvalue("export") then
		local sys = require "luci.sys"
		local req_from = (luci.http.getenv("REMOTE_ADDR") or "") ..":".. (luci.http.getenv("REMOTE_PORT") or "")
		local localip = luci.http.getenv("SERVER_ADDR")
		local log_str = req_from.." | ".."Export /admin/system/operationlog"
		log.web_operation_log("Info",log_str)

		local destfile = "/tmp/operationlog.tar.gz"
		sys.call("tar -cz /ramlog/weblog -f "..destfile)
		local reader = luci.ltn12.source.file(io.open(destfile,"r"))
		luci.http.header('Content-Disposition', 'attachment; filename="OperationLog-%s-%s-%s.tar.gz"' % {
			luci.sys.hostname(), localip, os.date("%Y-%m-%d")})
		luci.http.prepare_content("application/gzip")
		luci.ltn12.pump.all(reader, luci.http.write)
		fs.unlink(destfile)
	else
		luci.template.render("admin_system/weblog")
	end
end

function get_fs_sofia_profile_tb(str_profile)
	local status_cmd = {}
	local start_index = string.find(str_profile,"=\n")
	local end_index = string.find(str_profile,"\n",start_index+2)
	local total_len = string.find(str_profile,"\n=",start_index)

	while  start_index < total_len and end_index <= total_len do
		local current_line = string.sub(str_profile,start_index+2,end_index)
		if not string.find(current_line,"::") then
			local profile_name = current_line:match("^%s+(.*)%s+profile.*@[0-9.:]+%s*")
			table.insert(status_cmd,"sofia status profile "..(profile_name or ""))
			table.insert(status_cmd,"sofia status profile "..(profile_name or "").." reg")
		else
			local gw_name = current_line:match("^%s*.*::(.*)%s+gateway")
			table.insert(status_cmd,"sofia status gateway "..(gw_name or ""))
		end
		start_index = string.find(str_profile,"\n",end_index)
		end_index = string.find(str_profile,"\n",start_index+1)
	end
	return status_cmd
end
function get_fs_status(file)
	if not file then
		return
	end

	require "ESL"
	local sys = require "luci.sys"
	local fs = require("nixio.fs")
	local con = ESL.ESLconnection("127.0.0.1","8021","ClueCon")

	if con:connected() ~= 1 then
		sys.call("echo connect fs fail >> "..file)
		return
	end

	function record_cmd_result(cmd,file)
		local str = con:api(cmd):getBody()
		fs.writefile(file..".tmp","\n>>>>>"..cmd.." >>>>\n"..str.."\n<<<< "..cmd.." end <<<<<<\n")
		sys.call("cat "..file..".tmp".." >> "..file)
	end

	local str = con:api("sofia status"):getBody()
	fs.writefile(file..".tmp",str)
	sys.call("cat "..file..".tmp".." >> "..file)

	local sofia_status_cmd = get_fs_sofia_profile_tb(str)
	for k,v in ipairs(sofia_status_cmd) do
		record_cmd_result(v,file)
	end

	local cmd_list={"nat_map status","gsm dump list","gsm oper","gsm bcch","ftdm dump 1 1","ftdm dump 1 2","ftdm driver devmngt","ftdm driver fxso status","ftdm driver config","c300dsp 1001 1","gsm AT 1 AT+CGMR","gsm AT 1 AT+CGSN","gsm AT 1 ATI"}
	for k,v in ipairs(cmd_list) do
		record_cmd_result(v,file)
	end
end

function service_log()
	if luci.http.formvalue("export") then
		local sys = require "luci.sys"
		local dpr = require "dpr"
		local nixio = require "nixio"
		local util = require "luci.util"

		local req_from = (luci.http.getenv("REMOTE_ADDR") or "") ..":".. (luci.http.getenv("REMOTE_PORT") or "")
		local localip = luci.http.getenv("SERVER_ADDR")
		local log_str = req_from.." | ".."Export /admin/system/servicelog"
		log.web_operation_log("Info",log_str)

		local model	= dpr.getproduct() or ""
		local sn = dpr.getdevicesn() or ""
		local hard_id =	nixio.fs.access("/bin/readflashid") and util.exec("readflashid") or (dpr.gethardwareid() or "")
		local mac = util.exec("readmac") or ""
		local dsp = util.exec("readdspkey") and nixio.fs.access("/tmp/mtkauth.dat") and (26 == nixio.fs.stat("/tmp/mtkauth.dat","size"))

		local dev_info = "device model:"..model.."\n"
		dev_info = dev_info.."sn:"..sn.."\n"
		dev_info = dev_info.."hard id:"..hard_id.."\n"
		dev_info = dev_info.."mac:"..mac.."\n"
		dev_info = dev_info.."dsp:"..(dsp and "OK" or "FAULT").."\n"

		nixio.fs.writefile("/tmp/running_log",dev_info)


		local destfile_gz = "/tmp/servicelog.tar.gz"
		local destfile_ld = "/tmp/servicelog.ld"
		local cmd_gen_runing_log = "date >> /tmp/running_log && uptime >> /tmp/running_log && cat /proc/bootversion >> /tmp/running_log && cat /proc/kernelversion >> /tmp/running_log && cat /etc/provision/control.conf >> /tmp/running_log"
		cmd_gen_runing_log = cmd_gen_runing_log .. " && ps >> /tmp/running_log && top -b -n1 >> /tmp/running_log && netstat -alpn >> /tmp/running_log "
		cmd_gen_runing_log = cmd_gen_runing_log .. " && ifconfig >> /tmp/running_log && iwinfo >> /tmp/running_log && dmesg >> /tmp/running_log "
		cmd_gen_runing_log = cmd_gen_runing_log .. " && df >> /tmp/running_log && free >> /tmp/running_log && cat /proc/meminfo >> /tmp/running_log && cat /proc/slabinfo >> /tmp/running_log "
		cmd_gen_runing_log = cmd_gen_runing_log .. " && cat /proc/net/arp >> /tmp/running_log && cat /proc/net/nf_conntrack >> /tmp/running_log && iptables -nvL >> /tmp/running_log && iptables -nvL -t nat >> /tmp/running_log && uci changes >> /tmp/running_log "

		sys.call(cmd_gen_runing_log)
		get_fs_status("/tmp/running_log")

		sys.call("tar -c /tmp/upnpc_* /ramlog/ /etc/log/ /etc/coredump.log /etc/config/ /etc/openvpn/ /etc/ppp/ /etc/xl2tpd/ /tmp/etc/ /tmp/dhcp.leases /etc/firewall.user /tmp/log/ddns /tmp/log/freeswitch.xml.fsxml /tmp/web_command_history_* /etc/freeswitch/conf /etc/freeswitch/scripts /etc/freeswitch/cdr /etc/freeswitch/sms /tmp/running_log /tmp/upgrade_log /tmp/fs-apply-status /tmp/fsdb/ -f "..destfile_gz)
		pack_to_ld(destfile_gz,destfile_ld)
		local reader = luci.ltn12.source.file(io.open(destfile_ld,"r"))
		luci.http.header('Content-Disposition', 'attachment; filename="ServiceLog-%s-%s-%s.ld"' % {
			luci.sys.hostname(), localip, os.date("%Y-%m-%d")})
		luci.http.prepare_content("application/gzip")
		luci.ltn12.pump.all(reader, luci.http.write)
		fs.unlink(destfile_ld)
	elseif "1" == luci.http.formvalue("status") then
		require "luci.log"
		local log = luci.log.get_service_log()
		luci.http.prepare_content("application/json")
		luci.http.write_json(log)
	else
		luci.template.render("admin_system/servicelog")
	end
end

function changes_log()
	if luci.http.formvalue("export") then
		local sys = require "luci.sys"
		local req_from = (luci.http.getenv("REMOTE_ADDR") or "") ..":".. (luci.http.getenv("REMOTE_PORT") or "")
		local localip = luci.http.getenv("SERVER_ADDR")
		local log_str = req_from.." | ".."Export /admin/system/changeslog"
		log.web_operation_log("Info",log_str)

		local destfile = "/tmp/changeslog.tar.gz"
		sys.call("tar -cz /etc/log/uci_changes_log* -f "..destfile)
		local reader = luci.ltn12.source.file(io.open(destfile,"r"))
		luci.http.header('Content-Disposition', 'attachment; filename="ChangesLog-%s-%s-%s.tar.gz"' % {
			luci.sys.hostname(), localip, os.date("%Y-%m-%d")})
		luci.http.prepare_content("application/gzip")
		luci.ltn12.pump.all(reader, luci.http.write)
		fs.unlink(destfile)
	else
		local fs = require "nixio.fs"
		local changeslog=fs.readfile("/etc/log/uci_changes_log")
		if fs.access("/etc/log/uci_changes_log.0") then
			changeslog=changeslog..fs.readfile("/etc/log/uci_changes_log.0")
		end
		luci.template.render("admin_system/changeslog",{changeslog=(changeslog or luci.i18n.translate("Config Changes Log is empty !"))})
	end
end

function get_siptrunk_bgname(index)
	local uci = require "luci.model.uci".cursor()
	for k,v in pairs(uci:get_all("endpoint_siptrunk")) do
		if v.index and v.profile and v.index == index then
			return v.profile.."_"..v.index
		end
	end
end

function record_webcmd_history(addr,cmd,res)
	local fs = require "luci.fs"
	local h = fs.readfile("/tmp/web_command_history_"..addr) or ""
	local nh = h..os.date("%Y-%m-%d %X").."  "..cmd.."\n\n"..res.."\n\n"
	fs.writefile("/tmp/web_command_history_"..addr,nh)
end

function webcmd()
	local cmd = luci.http.formvalue("cmd")
	if cmd then
		require "ESL"
		local fs  = require "luci.fs"
		local uci = require "luci.model.uci".cursor()
		local con
		local r = ""
		local fscmd = true

		local sipt = cmd:match("^%s*sip%s+status%s+trunk%s+(%d+)")
		if sipt then
			cmd = "sofia status gateway "..get_siptrunk_bgname(sipt)
		elseif cmd:match("^%s*sip%s+") then
			cmd = string.gsub(cmd,"sip ","sofia ")
		elseif cmd:match("^%s*fxs%s+config%s*$") then
			cmd = "ftdm driver config 0 0"
		elseif cmd:match("^%s*fxo%s+config%s*$") then
			cmd = "ftdm driver config 0 1"
		elseif cmd:match("^%s*fxs%s+status%s*$") then
			cmd = "ftdm dump 1 1"
		elseif cmd:match("^%s*fxo%s+status%s*$") then
			cmd = "ftdm dump 1 2"
		elseif cmd:match("^%s*gsm%s+status%s*$") then
			cmd = "gsm dump 1"
		elseif cmd:match("^%s*last%s+apply%s+status%s*$") then
			fscmd = false
			r = fs.readfile("/tmp/fs-apply-status")
		elseif cmd:match("^%s*shutdown") or cmd:match("^%s*version") or cmd:match("^%s*help") or cmd:match("^%s*system") then
			fscmd = false
			r = "-ERR "..cmd.." command not found!"
		end

		if fscmd then
			con = ESL.ESLconnection("127.0.0.1","8021","ClueCon")
		end

		if fscmd and 1 == con:connected() then
			r = con:api(cmd):getBody();
			con:disconnect()
		elseif fscmd then
			r = "Execute Fail!\n"
		end
		record_webcmd_history(luci.http.getenv("REMOTE_ADDR") or "",cmd,r)
		luci.http.prepare_content("text/plain")
		luci.http.write(r.."\n")
	else
		luci.template.render("admin_system/cmd")
	end
end

function action_syslog()
	local syslog = luci.sys.syslog()
	luci.template.render("admin_system/syslog", {syslog=syslog})
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

function get_patch_list()
	require "ini"
	local fs = require("luci.fs")
	local uci = require "luci.model.uci".cursor()
	local patch = {}
	local ini = INI.load("/etc/provision/control.conf")

	if uci:get("patch","main","version") ~= ini['firmware']['version'] then
		return {}
	end

	for i=1,100 do
		if fs.access("/usr/lib/lua/patch/"..i) then
			local t = {}
			t.index = i
			t.description = fs.readfile("/usr/lib/lua/patch/"..i.."/readme") or ""
			t.status = uci:get("patch",i,"status") or "disabled"
			table.insert(patch,t)
		else
			return patch
		end
	end
	return patch
end

function patch_active(id)
	local fs = require("luci.fs")
	local nixio = require "nixio"
	local uci = require "luci.model.uci".cursor()
	for i=1,id do
		if "enabled" ~= uci:get("patch",i,"status") then
			local flag
			local path = "/usr/lib/lua/patch/"..i
			if fs.access(path.."/"..i..".patch") then
				os.execute("cd /usr/lib/lua/luci && patch -p1 < "..path.."/"..i..".patch")
				flag = true
			end
			if fs.access(path.."/active") then
				local r = fs.readfile(path.."/active")
				if r:match("^#!/bin/sh") then
					os.execute("sh "..path.."/active")
				else
					os.execute("lua "..path.."/active")
				end
				flag = true
			end
			if flag then
				uci:create_section("patch","patch",i,{status="enabled"})
			else
				uci:set("patch",i,"status","disabled")
				break
			end
		end
	end
	uci:commit("patch")
end

function patch_deactive(id)
	local fs = require("luci.fs")
	local nixio = require "nixio"
	local uci = require "luci.model.uci".cursor()
	local max = tonumber(luci.util.exec("ls /usr/lib/lua/patch | wc -l") or 100)
	for i=max,id,-1 do
		if "enabled" == uci:get("patch",i,"status") then
			local flag
			local path = "/usr/lib/lua/patch/"..i
			if fs.access(path.."/"..i..".patch") then
				os.execute("cd /usr/lib/lua/luci && patch -R -p1 < "..path.."/"..i..".patch")
				flag = true
			end
			if fs.access(path.."/deactive") then
				local r = fs.readfile(path.."/deactive")
				if r:match("^#!/bin/sh") then
					os.execute("sh "..path.."/deactive")
				else
					os.execute("lua "..path.."/deactive")
				end
				flag = true
			end
			if flag then
				uci:set("patch",i,"status","disabled")
				uci:commit("patch")
			else
				return false
			end
		end
	end
	return true
end

function patch_delete(id)
	local fs = require("luci.fs")
	local nixio = require "nixio"
	local uci = require "luci.model.uci".cursor()
	local max = tonumber(luci.util.exec("ls /usr/lib/lua/patch | wc -l") or 100)
	if patch_deactive(id) then
		local rm_list = ""
		for i=id,max do
			rm_list=rm_list..i.." "
			uci:delete("patch",i)
		end
		uci:commit("patch")
		os.execute("cd /usr/lib/lua/patch && rm -rf "..rm_list)
	end
end

function patch_id_extract(t)
	if "table" == type(t) then
		for k,v in pairs(t) do
			return k:match("^%d+$") or k:match("(%d+)%.[xy]") or 0
		end
	end
	return 0
end

function patch_file_verify(srcfilename)
	require "ini"
	require("dpr")
	local fs = require("luci.fs")
	local uci = require "luci.model.uci".cursor()
	local hdr = dpr.getldhdr(srcfilename)
	local model = dpr.getproduct() or "unknown"
	local ini = INI.load("/etc/provision/control.conf")

	if model and model:match("(%w+)%-") then
		model=model:match("(%w+)%-")
	end
	if hdr and "patch" == hdr.type and hdr.product == model and hdr.rely == ini['firmware']['version'] then
		local patch_ver = tonumber(hdr.version:match("%d$")) - tonumber(hdr.rely:match("%d$"))
		if ini['firmware']['version'] == uci:get("patch","main","version") and fs.access("/usr/lib/lua/patch/"..patch_ver) then
			-- if device exist patch 10, and upload patch version < 10, will fail
			return false
		end
		unpackld(srcfilename,"/tmp/patch.tar.gz")
		if not fs.access("/usr/lib/lua/patch") then
			os.execute("mkdir -p /usr/lib/lua/patch")
		end
		os.execute('rm -rf /usr/lib/lua/patch/* && tar -zxf /tmp/patch.tar.gz -C /usr/lib/lua/patch')
		if not uci:get_all("patch") or not uci:get_all("patch","main") then
			os.execute("touch /etc/config/patch")
			uci:create_section("patch","patch","main",{version=hdr.rely})
		else
			if hdr.rely ~= uci:get("patch","main","version") then
				os.execute("echo > /etc/config/patch")
				uci:create_section("patch","patch","main",{version=hdr.rely})
			end
		end
		uci:commit("patch")
		return true
	elseif hdr and "patch" == hdr.type and "unknown" == model and "0.0.0.0" == hdr.version and "0.0.0.0" == hdr.rely then
		--model info lost in license, handle it by speciall patch
		dpr.unpackld(srcfilename,"/tmp/patch.tar.gz")
		if not nixio.fs.access("/usr/lib/lua/patch") then
			os.execute("mkdir -p /usr/lib/lua/patch")
		end
		os.execute('tar -zxf /tmp/patch.tar.gz -C /usr/lib/lua/patch')
		local r = nixio.fs.readfile("/usr/lib/lua/patch/fix_license/active")
		if r:match("^#!/bin/sh") then
			os.execute("sh /usr/lib/lua/patch/fix_license/active")
		else
			os.execute("lua /usr/lib/lua/patch/fix_license/active")
		end
		return true
	else
		return false
	end
end

--@ reset to default settings
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
	local dprproxy = false

	if string.find(ps,"/bin/provision") then
		provision = true
	end

	if string.find(ps,"/bin/dprproxy") then
		dprproxy = true
	end

	if string.find(ps,"/bin/freeswitch") then
		freeswitch = true
	end

	return provision,dprproxy,freeswitch
end

function ld_verify(srcfilename,ld_type,logfile)
	require("dpr")
	local uci = require "luci.model.uci".cursor()
	local hdr = dpr.getldhdr(srcfilename)
	local model = dpr.getproduct()
	if model:match("^(%w+)%-") then
		model=model:match("^(%w+)%-")
	end
	if logfile then
		os.execute("echo sys model:"..(model or "unknown").." >>"..logfile)
		if hdr then
			os.execute("echo file header: >>"..logfile)
			os.execute("echo type: "..(hdr.type or "unknown").." >>"..logfile)
			os.execute("echo version: "..(hdr.version or "unknown").." >>"..logfile)
			os.execute("echo rely: "..(hdr.rely or "").." >>"..logfile)
			os.execute("echo product: "..(hdr.product or "unknown").." >>"..logfile)
			os.execute("echo md5: "..(hdr.md5sum or "unknown").." >>"..logfile)
			os.execute("echo buildtime: "..(hdr.buildtime or "unknown").." >>"..logfile)
		else
			os.execute("echo read file header fail ! >>"..logfile)
			return false
		end
	end
	if hdr and ld_type ~= "gsm" and ld_type == hdr.type and string.lower(hdr.product) == string.lower(model) and hdr.version then
		if "kernel" == ld_type then
			local version=hdr.version:match("(%d+%.%d+)$") or "unknown"
			return true,version
		else
			return true
		end
	elseif hdr and ld_type == "gsm" and string.lower(hdr.product) == string.lower(model) and hdr.version then
		local upload_submodule=hdr.type and hdr.type:match("^gsm_(.+)")
		if upload_submodule then
			require "ESL"
			local con = ESL.ESLconnection("127.0.0.1","8021","ClueCon")
			local gsm_ver=""
			if 1 == con:connected() then
				local s = con:api("gsm dump 1"):getBody()
				local module_status = s and s:match("dev_state%s*=%s*DEV_([a-zA-Z0-9_]+)")
				if module_status and (module_status == "READY" or module_status == "FAULT") then
					local gsm_ver = s and s:match("\nversion%s*=%s*([0-9A-Z]+)") or "Unknown"
					local device_gsm_module=string.sub(gsm_ver,1,4)
					con:disconnect()
					if "Unknown" == gsm_ver or device_gsm_module == upload_submodule then
						return true
					else
						os.execute("echo gsm module type not match ! device gsm module type:"..device_gsm_module.." != upload type:"..(upload_submodule)..">>"..logfile)
					end
				else
					os.execute("echo gsm module current state not allow to upgrade ! current status:"..(module_status or "Error")..">>"..logfile)
				end
			else
				return false
			end
		else
			os.execute("echo get submodule value from upload file header fail ! upload file header type:"..hdr.type.." >>"..logfile)
			return false
		end
	else
		if logfile then
			if hdr.type ~= ld_type then
				os.execute("echo type not match ! select type:"..ld_type.." != upload type:"..(hdr.type or "unknown")..">>"..logfile)
			end
			if hdr.product ~= model then
				os.execute("echo product not match ! sys model:"..model.." != upload kernel:"..(hdr.product or "unknown")..">>"..logfile)
			end
		end
		return false
	end
end

function check_downgrade(file)
	require("dpr")
	local uci = require "luci.model.uci".cursor()
	local hdr = dpr.getldhdr(file)
	local model = dpr.getproduct()

	if hdr and "firmware" == hdr.type and hdr.product == model and hdr.version then
		local v1,v2 = hdr.version:match("(%d+)%.(%d+)$")
		if tonumber(v1) <= 2 and tonumber(v2) < 8 then
			os.execute("rm /usr/bin/upnpc")
		end
	end
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
function action_flashops()
	local sys = require "luci.sys"
	local fs  = require "luci.fs"
	local uci = require "luci.model.uci".cursor()
	local req_from = (luci.http.getenv("REMOTE_ADDR") or "") ..":".. (luci.http.getenv("REMOTE_PORT") or "")
	local fs_server = require "luci.scripts.fs_server"
	local restore_avail = check_backup_available()
	local provision_avail,dprproxy_avail,fs_avail = check_service_status()
	local mac = uci:get("network","lan","macaddr")
	local upgrade_fail_log=""
	local destfile = "/tmp/latest_upload_file"
	local result_str = ""
	local reboot_flag=false
	local gsm_upgrading=fs.access("/etc/gsm_1_upgrading") and fs.access("/tmp/gsm_upgrading")

	local fp
	luci.http.setfilehandler(
		function(meta, chunk, eof)
			if not fp then
				if meta and (meta.name == "archive" or meta.name == "software") then
					fp = io.open(destfile,"w")
					os.execute("/etc/init.d/cron stop >>/dev/null 2>&1 && rm /tmp/luci-indexcache >>/dev/null 2>&1 && rm /tmp/gsm_upgrading")
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
				elseif meta and "software" == meta.name and "system" == upgrade_type then
					check_downgrade(destfile)
					os.execute("touch /tmp/upgrading_flag")
					web_rpc_syn(50000, "provision", "cli-download", "firmware", destfile, web_rpc_syn_cb)
				elseif meta and "software" == meta.name and "kernel" == upgrade_type then
					os.execute("echo kernel file upload succ !> /tmp/upgrade_log")
					os.execute("echo file size:"..fs.stat(destfile,"size").." >>/tmp/upgrade_log")
					os.execute("echo file md5:`md5sum "..destfile.."` >>/tmp/upgrade_log")
					local flag,ver = ld_verify(destfile,"kernel","/tmp/upgrade_log")
					if flag and ver and "unknown" ~= ver then
						local tmpfile="/tmp/uc100_uImage."..ver
						unpackld(destfile,tmpfile)
						os.execute("killall -9 freeswitch")
						os.execute("touch /tmp/upgrading_flag")
						os.execute("echo run updateimage `md5sum "..tmpfile.."` >>/tmp/upgrade_log")
						fs.writefile("/tmp/reboot.sh","sleep 2 && reboot -f")
						os.execute("updateimage kernel "..tmpfile.." && (sh /tmp/reboot.sh&)")
					else
						syn_result = "Verify Kernel Fail !"
					end
				elseif meta and "software" == meta.name and "gsm" == upgrade_type then
					os.execute("/etc/init.d/cron start")
					os.execute("echo gsm module file upload succ !> /tmp/upgrade_log")
					os.execute("echo file size:"..fs.stat(destfile,"size").." >>/tmp/upgrade_log")
					os.execute("echo file md5:`md5sum "..destfile.."` >>/tmp/upgrade_log")
					local flag= ld_verify(destfile,"gsm","/tmp/upgrade_log")
					if flag then
						local tmpfile="/tmp/gsm_module.bin"
						unpackld(destfile,tmpfile)
						require "ESL"
						local con = ESL.ESLconnection("127.0.0.1","8021","ClueCon")
						if 1 == con:connected() then
							local s = con:api("gsm updatemodule 1 start "..tmpfile.." 256"):getBody()
							if s and s:match("success") then
								syn_result="succ"
								os.execute("touch /tmp/gsm_upgrading")
							else
								syn_result="fail"
							end
							con:disconnect()
						else
							syn_result="fail"
						end
					end
				end
			end
		end
	)

	local upgrade_type = luci.http.formvalue("upgrade_type")
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

		if upload and #upload > 0 then
			luci.template.render("admin_system/flashops", {
			step = "index",
			result = result_str,
			restore_avail = restore_avail,
			sys_upgrade_avail = provision_avail and dprproxy_avail,
			fs_avail = fs_avail,
		})
		end
	elseif luci.http.formvalue("upgrade") then
		local log_str = ""
		if upgrade_type == "system" then
			--system board
			if string.find(syn_result,"succ") then
				syn_result = "Upgrade Firmware Succ !"
				log_str = req_from.." | ".."UpgradeSysSucc /admin/system/backup_upgrade"
				upgrade_type = "system"
				os.execute("echo upgrade >>/tmp/require_reboot && rm "..destfile)
			else
				os.execute("rm /tmp/upgraded_fail_flag && rm "..destfile)
				syn_result = "Upgrade Firmware Fail !"
				log_str = req_from.." | ".."UpgradeSysFail /admin/system/backup_upgrade"
				upgrade_fail_log=fs.readfile("/tmp/upgrade_log") or ""
			end
			result_str = syn_result
			log.web_operation_log("Info",log_str)
		elseif upgrade_type == "kernel" then
			local s=fs.readfile("/tmp/update_state") or ""
			if not s:match("succ") or string.find(syn_result,"Fail") then
				syn_result = "Upgrade Kernel Fail !"
				log_str = req_from.." | ".."UpgradeKernelFail /admin/system/backup_upgrade"
				upgrade_fail_log=fs.readfile("/tmp/upgrade_log") or ""
			else
				syn_result="Upgrade Kernel Succ ! Device rebooting !"
				log_str = req_from.." | ".."UpgradeKernelSucc /admin/system/backup_upgrade"
				reboot_flag=true
			end
			result_str = syn_result
			log.web_operation_log("Info",log_str)
		elseif upgrade_type == "gsm" then
			if syn_result == "succ" then
				gsm_upgrading=true
			else
				result_str="GSM Module Start Upgrade Fail !"
				upgrade_fail_log=fs.readfile("/tmp/upgrade_log") or ""
			end
		else
			local verify_flag
			verify_flag = patch_file_verify(destfile,tmp_type)
			if verify_flag then
				result_str = "Upload Patch Succ !"
				log_str = req_from.." | ".."UploadPatchSucc /admin/system/backup_upgrade"	
				log.web_operation_log("Info",log_str)
			else
				result_str = "Upload succ but verify file fail !"
				log_str = req_from.." | ".."VerifyPatchFail /admin/system/backup_upgrade"	
				log.web_operation_log("Info",log_str)
			end
		end
		os.execute("rm "..destfile)
		luci.template.render("admin_system/flashops", {
		result = result_str,
		restore_avail = restore_avail,
		sys_upgrade_avail = provision_avail and dprproxy_avail,
		fs_avail = fs_avail,
		gsm_upgrading=gsm_upgrading,
		patch_list = get_patch_list(),
		upgrade_fail_log = upgrade_fail_log,
		})
		if reboot_flag then
			luci.sys.reboot()
		end
	elseif luci.http.formvalue("reset") then
		local rst_list = luci.http.formvaluetable("reset")
		local localip = luci.http.getenv("SERVER_ADDR")
		local log_str = req_from.." | ".."Reset /admin/system/backup_upgrade"
		log.web_operation_log("Info",log_str)

		luci.template.render("admin_system/applyreboot", {
			title = luci.i18n.translate("Erasing..."),
			msg   = luci.i18n.translate("The system is erasing the config data now and will reboot itself when finished."),
		})
		reset_to_default_setting(rst_list)
	else
		if next(luci.http.formvaluetable("Active")) then
			patch_active(patch_id_extract(luci.http.formvaluetable("Active")))
		elseif next(luci.http.formvaluetable("Deactive")) then
			patch_deactive(patch_id_extract(luci.http.formvaluetable("Deactive")))
		elseif next(luci.http.formvaluetable("Delete")) then
			patch_delete(patch_id_extract(luci.http.formvaluetable("Delete")))
		end

		luci.template.render("admin_system/flashops", {
			result = result_str,
			restore_avail = restore_avail,
			sys_upgrade_avail = provision_avail and dprproxy_avail,
			fs_avail = fs_avail,
			gsm_upgrading=gsm_upgrading,
			patch_list = get_patch_list(),
		})
	end
end

function action_passwd()
	local p1 = luci.http.formvalue("pwd1")
	local p2 = luci.http.formvalue("pwd2")
	local stat = nil

	if p1 or p2 then
		if p1 == p2 then
			stat = luci.sys.user.setpasswd("admin", p1)
		else
			stat = 10
		end
	end

	luci.template.render("admin_system/passwd", {stat=stat})
end

function action_reboot()
	local reboot = luci.http.formvalue("reboot")
	if reboot then
		local req_from = (luci.http.getenv("REMOTE_ADDR") or "")..":"..(luci.http.getenv("REMOTE_PORT") or "")
		
		luci.template.render("admin_system/applyreboot", {
			msg   = luci.i18n.translate("Please wait: Device rebooting..."),
		})
		log_str = req_from.." | ".."Reboot /admin/system/applyreboot"
		log.web_operation_log("Info",log_str)
		os.execute("sleep 2")
		luci.sys.reboot()
	else
		luci.template.render("admin_system/reboot", {reboot=reboot})
	end
end

function fork_exec(command)
	local pid = nixio.fork()
	if pid > 0 then
		return
	elseif pid == 0 then
		-- change to root dir
		nixio.chdir("/")
		-- patch stdin, out, err to /dev/null
		local null = nixio.open("/dev/null", "w+")
		if null then
			nixio.dup(null, nixio.stderr)
			nixio.dup(null, nixio.stdout)
			nixio.dup(null, nixio.stdin)
			if null:fileno() > 2 then
				null:close()
			end
		end
		-- replace with target command
		nixio.exec("/bin/sh", "-c", command)
	end
end

function ltn12_popen(command)
	local fdi, fdo = nixio.pipe()
	local pid = nixio.fork()
	if pid > 0 then
		fdo:close()
		local close
		return function()
			local buffer = fdi:read(2048)
			local wpid, stat = nixio.waitpid(pid,"nohang")
			if not close and wpid and stat == "exited" then
				close=true
			end

			if buffer and #buffer > 0 then
				return buffer
			elseif close then
				fdi:close()
				return nil
			end
		end
	elseif pid==0 then
		nixio.dup(fdo, nixio.stdout)
		fdi:close()
		fdo:close()
		nixio.exec("/bin/sh","-c",command)
	end
end
