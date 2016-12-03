module("luci.controller.admin.affair",package.seeall)

function index()
	if luci.http.getenv("SERVER_PORT") == 80 or luci.http.getenv("SERVER_PORT") == 8848 then
		entry({"admin","affair"},alias("admin","affair","overview"),"状态",81).index = true
		--entry({"admin","affair","overview"},call("action_overview"),"总览",10).leaf = true
		entry({"admin","affair","overview"},template("admin_affair/index_empty"),"总览",11).leaf = true
	end
end

function action_overview()
	local ubus_get_addr = require "luci.model.network".ubus_get_addr
	local sqlite = require "luci.scripts.sqlite3_service"
	local util = require "luci.util"
	local uci = require "luci.model.uci".cursor()

	local net_info = {}
	local str 
	net_info.access_mode = uci:get("network_tmp","network","access_mode") or "未知"
	if net_info.access_mode == "wlan_dhcp" or net_info.access_mode == "wlan_static" then
		str = util.exec("ifconfig ra0 | grep 'RX bytes'")
	else
		str = util.exec("ifconfig eth0.2 | grep 'RX bytes'")
	end
	net_info.ipaddr,net_info.netmask,net_info.gateway,net_info.dns =  ubus_get_addr("wan")
	net_info.rx = str:match("RX bytes:(%d+)") or "0"
	net_info.tx = str:match("TX bytes:(%d+)") or "0"

	local wifi_info = {}
	wifi_info.mode = uci:get("wireless","wifi0","mode") or ""
	if wifi_info.mode == "sta" then
		local tmp_str = util.exec("iwpriv ra0 connStatus")
		wifi_info.status = tmp_str
	else
		wifi_info.status = uci:get("wireless","wifi0","disabled") or "0"
		wifi_info.ssid = uci:get("wireless","wifi0","ssid") or ""
	end

	local siptrunk_info = {}
	local tmp_tb = uci:get_all("endpoint_siptrunk") or {}
	local section
	if tmp_tb and next(tmp_tb) then
		for k,v in pairs(tmp_tb) do
			if v.index and v.index == "1" then
				section = k
				break
			end
		end
	end
	if section and uci:get("endpoint_siptrunk",section,"status") == "Enabled" then
		local str = util.exec("fs_cli -x 'sofia status gateway 2_1' | sed -n '/^Username/p;/^State/p' | tr '\n' '#'")
		siptrunk_info.register = str:match("State%s+([%u_]+)") or ""
		siptrunk_info.number = str:match("Username%s+(%d+)") or "-"
	end

	local ddns_info = {}
	ddns_info.e = uci:get("ddns","myddns_ipv4","enabled")
	if ddns_info.e and ddns_info.e == "1" then
		ddns_info.status = util.exec("tail /tmp/log/ddns/myddns_ipv4.log")
		local str = util.exec("tail /tmp/log/ddns/myddns_ipv4.log")
		if string.find(str,"DDNS Provider answered") then
			local answer = str:match("DDNS Provider answered %[(.+)%]") or ""
			if "good" == answer or "nochg" == answer or answer:match("good %d+%.%d+%.%d+%.%d+") or answer:match("nochg %d+%.%d+%.%d+%.%d+") then
				ddns_info.status = "连接成功"
			end
		else
			ddns_info.status = "连接失败"
		end
	else
		ddns_info.status = "已禁用"
	end
	ddns_info.domain = uci:get("ddns","myddns_ipv4","domain") or "-"

	local vpn_info = {}
	vpn_info.l2tp_e = uci:get("xl2tpd","main","enabled")
	vpn_info.pptp_e = uci:get("pptpc","main","enabled")
	vpn_info.openvpn_e = uci:get("openvpn","custom_config","enabled")
	if vpn_info.l2tp_e == "1" then
		local str = util.exec("tail -n 1 /ramlog/l2tpc_log")
		vpn_info.l2tp_s = str:match("^(login:)")
	end
	if vpn_info.pptp_e == "1" then
		local str = util.exec("tail -n 1 /ramlog/pptpc_log")
		vpn_info.pptp_s = str:match("^(login:)")
	end
	if vpn_info.openvpn_e == "1" then
		local str = util.exec("tail -n 1 /ramlog/openvpnc_log")
		vpn_info.openvpn_s = str:match("^(login:)")
	end

	local sim_info = {}
	local tmp_tb = uci:get_all("endpoint_mobile") or {}
	if next(tmp_tb) then
		for k,v in pairs(tmp_tb) do
			if v.slot == "1-GSM" then
				local tmp_str = util.exec("fs_cli -x 'gsm dump 1' | sed -n '/simpin_state/p;/^not_registered/p' | tr '\n' '#'")
				local simpin_state = tmp_str:match("simpin_state = ([^#]+)#")
				local not_register = tmp_str:match("not_registered = (%d+)")
				if simpin_state ~= "SIMPIN_READY" then
					sim_info.status = "no_card"
				elseif not_register ~= "0" then
					sim_info.status = "not_registered"
				else
					sim_info.status = "registered"
				end
			end
		end
	end
	if section then
		sim_info.e = uci:get("endpoint_mobile",section,"status")
		sim_info.slot = uci:get("endpoint_mobile",section,"slot")
		if sim_info.e == "Enabled" then
			local ret_tb = sqlite.sqlite3_execute("/tmp/fsdb/core.db","select * from pstn")
		end
	end

	if luci.http.formvalue("status") == "1" then
		local rv = {
			net_info = net_info,
			siptrunk_info = siptrunk_info,
			ddns_info = ddns_info,
			vpn_info = vpn_info
		}

		luci.http.prepare_content("application/json")
		luci.http.write_json(rv)

		return
	else
		luci.template.render("admin_affair/index",{
			net_info = net_info,
			siptrunk_info = siptrunk_info,
			ddns_info = ddns_info,
			vpn_info = vpn_info
		})
	end
end
