module("luci.controller.admin.wizard",package.seeall)

local fs_server = require "luci.scripts.fs_server"
local util = require "luci.util"
local fs = require "nixio.fs"
local exe = require "os".execute
local sys = require "luci.sys"
local ds = require "luci.dispatcher"

function index()
	local page
	page = node("admin","wizard")
	page.target = firstchild()
	page.title = ("配置向导")
	page.order = 100
	page.index = true

	entry({"admin","wizard","wizard"},template("admin_wizard/wizard"),"配置向导",1).leaf = true
	entry({"admin","wizard","network"},cbi("admin_wizard/net_access"),"网络",2).leaf = true
	entry({"admin","wizard","siptrunk"},cbi("admin_wizard/siptrunk"),"SIP中继",3).leaf = true
	entry({"admin","wizard","ddns"},cbi("admin_wizard/ddns"),"DDNS",4).leaf = true
	entry({"admin","wizard","pptp"},cbi("admin_wizard/pptp_client"),"PPTP",5).leaf = true
	entry({"admin","wizard","l2tp"},cbi("admin_wizard/l2tp_client"),"L2TP",6).leaf = true
	entry({"admin","wizard","openvpn"},call("action_openvpn"),"OpenVPN",7).leaf = true

	entry({"admin","wizard","firstdetect"},template("admin_wizard/first_detect"),"一检",21).leaf = true
	--entry({"admin","wizard","seconddetect"},template("admin_wizard/second_detect"),"二检",22).leaf = true
	entry({"admin","wizard","diagnostics"},call("action_diagnostics"),"诊断",23).leaf = true

	entry({"admin","wizard","wifilist"},call("action_get_wireless"))
	entry({"admin","wizard","8"},call("first_detect_status"))
	entry({"admin","wizard","9"},call("action_first_detect"))
	entry({"admin","wizard","status2"},call("second_detect_status"))
	entry({"admin","wizard","detect2"},call("action_second_detect"))
	entry({"admin","wizard","status"},call("detect_status"))
end

function action_get_wireless()
	if luci.http.formvalue("action") == "refresh" then
		local status = util.exec("ifconfig | grep 'ra0'")
		if status == "" then
			util.exec("ifconfig ra0 up;ifconfig | grep 'ra0'")
		end

		wireless_tb = fs_server.get_wifi_list("refresh") or {}

		if status == "" then
			util.exec("ifconfig ra0 down")
		end

		luci.http.prepare_content("application/json")
		luci.http.write_json(wireless_tb)
	end
	return
end

function first_detect_status()
	local status = nixio.fs.readfile("/tmp/detect_status")

	if status then
		luci.http.write(status)
	else
		luci.http.write("No data\n")
	end
end

function action_first_detect()
	local ubus_get_addr = require "luci.model.network".ubus_get_addr
	local uci = require "luci.model.uci".cursor()
	local access_mode = uci:get("network_tmp","network","access_mode") or "wired_static"
	local wan_ipaddr,wan_netmask,wan_gateway,wan_dns =  ubus_get_addr("wan")
	local wan_dns_tb = util.split(wan_dns," ") or {}
	local str_suc = "OK="

	util.exec("rm /tmp/detect_status")

	-- ping local ipaddr
	if wan_ipaddr and wan_ipaddr ~= "" and wan_ipaddr ~= "0.0.0.0" then
		local result = util.exec("ping -c 5 -W 1 2>&1 "..wan_ipaddr.." | grep 'loss'")
		result = result:match("(%d+)%%")
		if result and result ~= "" and result ~= "100" then
			str_suc = str_suc.."ipaddr"
			fs.writefile("/tmp/detect_status","Access Mode="..access_mode..","..str_suc.."\n")
		else
			fs.writefile("/tmp/detect_status","Access Mode="..access_mode..",Error=ipaddr\n")
			return
		end
	else
		fs.writefile("/tmp/detect_status","Access Mode="..access_mode..",Error=ipaddr\n")
		return
	end

	-- ping gateway
	if wan_gateway and wan_gateway ~= "" and wan_gateway ~= "0.0.0.0" then
		local result = util.exec("ping -c 5 -W 1 2>&1 "..wan_gateway.." | grep 'loss'")
		result = result:match("(%d+)%%")
		if result and result ~= "" and result ~= "100" then
			str_suc = str_suc..",gateway"
			fs.writefile("/tmp/detect_status","Access Mode="..access_mode..","..str_suc.."\n")
		else
			fs.writefile("/tmp/detect_status","Access Mode="..access_mode..",Error=gateway\n")
			return
		end
	else
		fs.writefile("/tmp/detect_status","Access Mode="..access_mode..",Error=gateway\n")
		return
	end

	-- ping dns
	if wan_dns_tb and next(wan_dns_tb) then
		local loop_num = 0
		for k,v in pairs(wan_dns_tb) do
			if v and v ~= "" then
				local result = util.exec("ping -c 5 -W 1 2>&1 "..v.." | grep 'loss'")
				result = result:match("(%d+)%%")
				if result and result ~= "" and result ~= "100" then
					str_suc = str_suc..",dns"
					fs.writefile("/tmp/detect_status","Access Mode="..access_mode..","..str_suc.."\n")
					break
				end
			end
			loop_num = loop_num + 1
		end
		if loop_num == #wan_dns_tb then
			fs.writefile("/tmp/detect_status","Access Mode="..access_mode..",Error=dns\n")
			return
		end
	else
		fs.writefile("/tmp/detect_status","Access Mode="..access_mode..",Error=dns\n")
		return
	end

	-- ping baidu
	local result = util.exec("ping -c 5 -W 1 2>&1 www.baidu.com | grep 'loss'")
	result = result:match("(%d+)%%")
	if result and result ~= "" and result ~= "100" then
		str_suc = str_suc..",baidu"
		fs.writefile("/tmp/detect_status","Access Mode="..access_mode..",Finish\n")
	else
		fs.writefile("/tmp/detect_status","Access Mode="..access_mode..",Error=baidu\n")
	end
end

function second_detect_status()
	local status = nixio.fs.readfile("/tmp/detect_status2")

	if status then
		luci.http.write(status)
	else
		luci.http.write("No data\n")
	end
end

function action_second_detect()
	local uci = require "luci.model.uci".cursor()
	local write_str = ""

	exe("rm /tmp/detect_status2")

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
		local str = util.exec("fs_cli -x 'sofia status gateway 2_1' | sed -n '/Address/p;/^State/p' | tr '\n' '#'")
		local ipaddr = str:match("Address%s+(%d+%.%d+%.%d+%.%d+)")
		local trunk_status = str:match("State%s+([%u_]+)")
		local ping_result = util.exec("ping -c 5 -W 1 2>&1 "..ipaddr.." | grep 'loss'")
		local loss_num = ping_result:match("(%d+)%%")

		if loss_num and loss_num ~= "" and loss_num ~= "100" then
			local num = 0
			write_str = write_str.."siptrunk-connect:success; "
			fs.writefile("/tmp/detect_status2",write_str.."\n")

			while num < 5 do
				if trunk_status == "REGED" then
					break
				else
					num = num + 1
					if num ~= 5 then
						str = util.exec("fs_cli -x 'sofia status gateway 2_1' | sed -n '/Address/p;/^State/p' | tr '\n' '#'")
						trunk_status = str:match("State%s+([%u_]+)")
						exe("sleep 1")
					end
				end
			end
			if num == 5 then
				write_str = write_str.."siptrunk-register:fail; "
			else
				write_str = write_str.."siptrunk-register:success; "
			end
		else
			write_str = write_str.."siptrunk-connect:fail; siptrunk-register:fail; "
		end

		fs.writefile("/tmp/detect_status2",write_str.."\n")
	end

	if uci:get("ddns","myddns_ipv4","enabled") == "1" then
		local num = 0
		while num < 5 do
			local result = util.exec("tail /tmp/log/ddns/myddns_ipv4.log")
			if string.find(result,"DDNS Provider answered") then
				local answer = result:match("DDNS Provider answered %[(.+)%]") or ""
				if "good" == answer or "nochg" == answer or answer:match("good %d+%.%d+%.%d+%.%d+") or answer:match("nochg %d+%.%d+%.%d+%.%d+") then
					break
				end
			end
			num = num + 1
			if num ~= 5 then
				result = util.exec("tail /tmp/log/ddns/myddns_ipv4.log")
			end
		end
		if num == 5 then
			write_str = write_str.."ddns:fail; "
		else
			write_str = write_str.."ddns:success; "
		end
	end

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
			write_str = write_str.."l2tp:fail; "
		else
			write_str = write_str.."l2tp:success; "
		end
		fs.writefile("/tmp/detect_status2",write_str.."\n")
	end

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
			write_str = write_str.."pptp:fail; "
		else
			write_str = write_str.."pptp:success; "
		end
		fs.writefile("/tmp/detect_status2",write_str.."\n")
	end

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
			write_str = write_str.."openvpn:fail; "
		else
			write_str = write_str.."openvpn:success; "
		end
		fs.writefile("/tmp/detect_status2",write_str.."\n")
	end

	local tmp_tb = uci:get_all("endpoint_mobile")
	local status = nil
	if tmp_tb then
		for k,v in pairs(tmp_tb) do
			if v.index then
				status = v.status
				break
			end
		end
	end
	if status and status == "Enabled" then
	end
end

function action_openvpn()
	local uci = require "luci.model.uci".cursor()
	local uci_tmp = require "luci.model.uci".cursor("/tmp/config")
	local destfile = "/tmp/my-vpn.conf.latest"
	local flag = uci_tmp:get("wizard","globals","openvpn") or "1"

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
			end
		end
	)

	if luci.http.formvalue("save") then
		local status = luci.http.formvalue("status")
		if status then
			uci:set("openvpn","custom_config","enabled",status)
		end

		local key = luci.http.formvalue("key")
		if key and #key > 0 then
			uci:set("openvpn","custom_config","key_change","0"==uci:get("openvpn","custom_config","key_change") and "1" or "0")
		end

		uci:set("openvpn","custom_config","defaultroute","0")
		uci:save("openvpn")
		uci_tmp:set("wizard","globals","openvpn","1")
		uci_tmp:save("wizard")
		uci_tmp:commit("wizard")

		luci.http.redirect(ds.build_url("admin","status","overview"))
		return
	elseif luci.http.formvalue("cancel") then
		luci.http.redirect(ds.build_url("admin","wizard","l2tp"))
	else
		luci.template.render("admin_wizard/openvpn",{
			status = flag == "1" and uci:get("openvpn","custom_config","enabled") or "0"
		})
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
	local access_mode = uci:get("network_tmp","network","access_mode") or "wired_static"
	local wan_ipaddr,wan_netmask,wan_gateway,wan_dns =  ubus_get_addr("wan")
	local wan_dns_tb = util.split(wan_dns," ") or {}
	local write_str = "access_mode:"..access_mode.."; "
	local request_str = string

	if request_str:match("(%%ipaddr%%)") then
		write_str = write_str.."ipaddr:"
		fs.writefile("/tmp/detect_status",write_str)

		if wan_ipaddr and wan_ipaddr ~= "" and wan_ipaddr ~= "0.0.0.0" then
			local result = util.exec("ping -c 5 -W 1 2>&1 "..wan_ipaddr.." | grep 'loss'")
			result = result:match("(%d+)%%")
			if result and result ~= "" and result ~= "100" then
				write_str = write_str.."success; "
				fs.writefile("/tmp/detect_status",write_str)
			else
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

	if request_str:match("(%%gateway%%)") then
		write_str = write_str.."gateway:"
		fs.writefile("/tmp/detect_status",write_str)

		if wan_gateway and wan_gateway ~= "" and wan_gateway ~= "0.0.0.0" then
			local result = util.exec("ping -c 5 -W 1 2>&1 "..wan_gateway.." | grep 'loss'")
			result = result:match("(%d+)%%")
			if result and result ~= "" and result ~= "100" then
				write_str = write_str.."success; "
				fs.writefile("/tmp/detect_status",write_str)
			else
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

	if request_str:match("(%%dns%%)") then
		write_str = write_str.."dns:"
		fs.writefile("/tmp/detect_status",write_str)

		if wan_dns_tb and next(wan_dns_tb) then
			local loop_num = 0
			for k,v in pairs(wan_dns_tb) do
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
			if loop_num == #wan_dns_tb then
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
		write_str = write_str.."baidu:"
		fs.writefile("/tmp/detect_status",write_str)

		local result = util.exec("ping -c 5 -W 1 2>&1 www.baidu.com | grep 'loss'")
		result = result:match("(%d+)%%")
		if result and result ~= "" and result ~= "100" then
			write_str = write_str.."success; "
			fs.writefile("/tmp/detect_status",write_str)
		else
			write_str = write_str.."fail; "
			fs.writefile("/tmp/detect_status",write_str)
			return
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
			local str = util.exec("fs_cli -x 'sofia status gateway 2_1' | sed -n '/Address/p;/^State/p' | tr '\n' '#'")
			local ipaddr = str:match("Address%s+(%d+%.%d+%.%d+%.%d+)")
			local trunk_status = str:match("State%s+([%u_]+)")
			local ping_result = util.exec("ping -c 5 -W 1 2>&1 "..ipaddr.." | grep 'loss'")
			local loss_num = ping_result:match("(%d+)%%")

			if loss_num and loss_num ~= "" and loss_num ~= "100" then
				local num = 0
				write_str = write_str.."success; siptrunk-register:"
				fs.writefile("/tmp/detect_status",write_str)

				while num < 5 do
					if trunk_status == "REGED" then
						break
					else
						num = num + 1
						if num ~= 5 then
							str = util.exec("fs_cli -x 'sofia status gateway 2_1' | sed -n '/Address/p;/^State/p' | tr '\n' '#'")
							trunk_status = str:match("State%s+([%u_]+)")
							exe("sleep 1")
						end
					end
				end
				if num == 5 then
					write_str = write_str.."fail; "
				else
					write_str = write_str.."success; "
				end
			else
				write_str = write_str.."fail; siptrunk-register:fail; "
			end
		end
		fs.writefile("/tmp/detect_status",write_str)
	end

	if request_str:match("(%%dDns%%)") then
		write_str = write_str.."dDns:"
		fs.writefile("/tmp/detect_status",write_str)

		if uci:get("ddns","myddns_ipv4","enabled") == "1" then
			local num = 0
			while num < 5 do
				local result = util.exec("tail /tmp/log/ddns/myddns_ipv4.log")
				if string.find(result,"DDNS Provider answered") then
					local answer = result:match("DDNS Provider answered %[(.+)%]") or ""
					if "good" == answer or "nochg" == answer or answer:match("good %d+%.%d+%.%d+%.%d+") or answer:match("nochg %d+%.%d+%.%d+%.%d+") then
						break
					end
				end
				num = num + 1
				if num ~= 5 then
					result = util.exec("tail /tmp/log/ddns/myddns_ipv4.log")
				end
			end
			if num == 5 then
				write_str = write_str.."fail; "
			else
				write_str = write_str.."success; "
			end
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

	if request_str:match("(%%sim%%)") then
		write_str = write_str.."sim:"
		write_str = write_str.."success; "
		fs.writefile("/tmp/detect_status",write_str)
		exe("sleep 3")
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

		luci.template.render("admin_wizard/detect", {
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
