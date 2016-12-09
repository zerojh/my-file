module("luci.controller.admin.affair",package.seeall)

function index()
	if luci.http.getenv("SERVER_PORT") == 80 or luci.http.getenv("SERVER_PORT") == 8848 then
		entry({"admin","affair"},alias("admin","affair","overview"),"状态",81).index = true
		entry({"admin","affair","overview"},call("action_overview"),"总览",10).leaf = true
		--entry({"admin","affair","overview"},template("admin_affair/index_empty"),"总览",11).leaf = true
	end
end

function action_overview()
	local ubus_get_addr = require "luci.model.network".ubus_get_addr
	local sqlite = require "luci.scripts.sqlite3_service"
	local util = require "luci.util"
	local fs = require "luci.fs"
	local i18n = require "luci.i18n"
	local uci = require "luci.model.uci".cursor()

	-- network
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

	-- wireless
	local wifi_info = {}
	wifi_info.mode = uci:get("wireless","wifi0","mode") or "ap"
	if wifi_info.mode == "sta" then
		local tmp_str = util.exec("iwpriv ra0 connStatus")
		wifi_info.status = tmp_str:match("connStatus:(Connected)") or tmp_str:match("connStatus:(Disconnected)") or ""
		wifi_info.ssid = uci:get("wireless","wifi0","ssid") or ""
		wifi_info.enc = uci:get("wireless","wifi0","encryption") or "none"
		if wifi_info.status == "Connected" and wifi_info.ssid ~= "" then
			local mac_addr = tmp_str:match("%[([^%]]+)%]")
			wifi_info.mac_addr = mac_addr
			mac_addr = string.lower(mac_addr)
			tmp_str = util.exec("iwpriv ra0 get_site_survey|grep '"..mac_addr.."'|awk '{print \"channel:\"$1\",signal:\"$5}'")
			wifi_info.channel = tmp_str:match("channel:(%d+)") or "-"
			wifi_info.signal = tmp_str:match("signal:(%d+)") or "-"
		else
			wifi_info.mac_addr = "-"
			wifi_info.channel = "-"
			wifi_info.signal = "-"
		end
	else
		local channel
		wifi_info.status = uci:get("wireless","wifi0","disabled") or "0"
		wifi_info.ssid = uci:get("wireless","wifi0","ssid") or ""
		wifi_info.enc = uci:get("wireless","wifi0","encryption") or "none"
		wifi_info.mac_addr = util.exec("ifconfig ra0|grep 'HWaddr'|awk '{print $5}'|tr '\n' ' '")
		wifi_info.channel = string.upper(uci:get("wireless","ra0","channel") or "-")
	end

	-- siptrunk
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

	-- ddns
	local ddns_info = {}
	local result = util.exec("tail /tmp/log/ddns/myddns_ipv4.log")
	ddns_info.domain = uci:get("ddns","myddns_ipv4","domain") or "未知"
	if "1" ~= uci:get("ddns" , "myddns_ipv4" , "enabled") then
		ddns_info.enable = "已禁用"
		ddns_info.status = ""
	else
		ddns_info.enable = "已开启"
		if not fs.access("/usr/bin/wget") and not fs.access("/usr/bin/curl") then
			ddns_info.status = i18n.translatef("DDNS kernel program missed, please upgrade system !")
		elseif string.find(result,"CRITICAL ERROR =: Private or invalid or no IP") then
			local ip = result:match("CRITICAL ERROR =: Private or invalid or no IP '([0-9%.]+)' given")
			ddns_info.status = i18n.translatef("Device Address '%s' is a private or invalid IP ! DDNS can not to be updated !",ip)
		elseif result:match("waiting =: 10 seconds for interfaces to fully come up\n$") then
			ddns_info.status = i18n.translatef("Ready to connect DDNS Provider...")
		elseif string.find(result,"bad address ") and not string.find(result,"via web") then
			local addr = result:match("bad address '(.+)'")
			ddns_info.status = i18n.translatef("Address '%s' can not be resolved, please check the address or DNS is correct !",addr)
		elseif string.find(result,"DETECT =: Local IP\n%s*transfer prog =:.+'.+' 2>/dev/null\n$") then
			local url = result:match("detected via web at '(.+)'\n$") or result:match("transfer prog =:.+'(.+)' 2>/dev/null\n$")
			ddns_info.status = i18n.translatef("Detecting external address via IP Check URL '%s'",url)
		elseif string.find(result,"ERROR =: detecting local IP %- retry") and (string.find(result,"detected via web") or string.find(result,"detected on network")) and not string.find(result,"DDNS Provider answered") and not string.find(result,"wget: bad address") then
			local retrycnt, retrytime = result:match("retry (%d)/5 in (%d+)")
			ddns_info = i18n.translatef("Detecting IP address").." - "..translatef("retry in %d seconds (%d)",retrytime,retrycnt)
		elseif result:match("local ip =: '%d+%.%d+%.%d+%.%d+' detected via web at '.+'\n%s*%*%*%*%*%*%* WAITING =: %d+ seconds %(Check Interval%) before continue\n$") or result:match("local ip =: '%d+%.%d+%.%d+%.%d+' detected on network 'wan'\n%s*%*%*%*%*%*%* WAITING =: %d+ seconds %(Check Interval%) before continue\n$")then
			local time = result:match("WAITING =: (%d+) seconds %(Check Interval%) before continue\n$")
			local local_ip = result:match("resolved ip =: '(%d+%.%d+%.%d+%.%d+)'")
			if local_ip and time then
				ddns_info.status = i18n.translatef("IP address doesn't change, will recheck in %s minutes !",time/60)
			end
		elseif ((string.find(result,"transfer prog =:.+'.+' 2>/dev/null\n$") and not string.find(result,"DDNS Provider answered"))) and not string.find(result,"wget: bad address") then
			local url = result:match("transfer prog =:.+'(.+)' 2>/dev/null\n$")
			ddns_info.status = i18n.translatef("Connecting to DDNS Provider by '%s'",url)
		elseif (string.find(result,"Connecting to ") and string.find(result,"error getting response: Connection reset by peer")) then
			local host = result:match("Connecting to (.+%))\n") or m.uci:get("ddns" , "myddns_ipv4" , "service_name") or ""
			local retrycnt, retrytime = result:match("retry (%d)/5 in (%d+)")
			if retrycnt and retrytime then
				ddns_info.status = i18n.translatef("Connecting to '%s' fail, connection reset by peer !",host).." - "..translatef("retry in %d seconds (%d)",retrytime,retrycnt)
			else
				ddns_info.status = i18n.translatef("Connecting to '%s' fail, connection reset by peer !",host)
			end
		elseif (string.find(result,"Connecting to ") and string.find(result,"server returned error: HTTP/1.1 404 Not Found")) then
			local host = result:match("Connecting to (.+%))\n") or m.uci:get("ddns" , "myddns_ipv4" , "service_name") or ""
			local retrycnt, retrytime = result:match("retry (%d)/5 in (%d+)")
			if retrycnt and retrytime then
				ddns_info.status = i18n.translatef("Connecting to '%s' fail, DDNS Provider returned error: HTTP/1.1 404 Not Found !",host).." - "..translatef("retry in %d seconds (%d)",retrytime,retrycnt)
			else
				ddns_info.status = i18n.translatef("Connecting to '%s' fail, DDNS Provider returned error: HTTP/1.1 404 Not Found !",host)
			end
		elseif string.find(result,"Error sending update to DDNS Provider") then
			local retrycnt, retrytime = result:match("retry (%d)/5 in (%d+)")
			if retrycnt and retrytime then
				ddns_info.status = i18n.translatef("Error sending update to DDNS Provider !").." - "..translatef("retry in %d seconds (%d)",retrytime,retrycnt)
			else
				ddns_info.status = i18n.translatef("Error sending update to DDNS Provider !")
			end
		elseif string.find(result,"DDNS Provider answered") then
			local answer = result:match("DDNS Provider answered %[(.+)%]") or ""
			if "badauth" == answer then
				ddns_info.status = i18n.translatef("Username or Password is not correct !")
			elseif "abuse" == answer then
				ddns_info.status = i18n.translatef("DDNS update fail because requests too frequently !")
			elseif "nohost" == answer or "notfqdn" == answer or "numhost" == answer then
				local d = m.uci:get("ddns" , "myddns_ipv4" , "domain") or ""
				ddns_info.status = i18n.translatef("Domain '%s' doesn't exit !",d)
			elseif "good 127.0.0.1" == answer or "badagent" == answer then
				ddns_info.status = i18n.translatef("Update url doesn't follow DDNS Provider's specifications !")
			elseif "good" == answer or "nochg" == answer or answer:match("good %d+%.%d+%.%d+%.%d+") or answer:match("nochg %d+%.%d+%.%d+%.%d+") then
				ddns_info.status = i18n.translatef("DDNS update success !")
			elseif "dnserr" == answer or "911" == answer then
				ddns_info.status = i18n.translatef("There is a problem [%s] on DDNS Provider !",answer)
			elseif "" ~= answer then
				ddns_info.status = i18n.translatef("DDNS Provider Answered! [%s]",answer)
			end
		elseif string.find(result,"nslookup: can't resolve") and not string.find(result,"START LOOP") then
			local host = result:match("nslookup: can't resolve '(.+)':") or ""
			local retrycnt, retrytime = result:match("retry (%d)/5 in (%d+)")
			if retrycnt and retrytime then
				ddns_info.status = i18n.translatef("Domain '%s' can not be resolved !",host).." - "..translatef("retry in %d seconds (%d)",retrytime,retrycnt)
			else
				ddns_info.status = i18n.translatef("Domain '%s' can not be resolved ! DDNS update fail !",host)
			end
		elseif string.find(result,"detected via web at") and string.find(result,"wget: bad address") then
			local web_url = result:match("detected via web at '(.+)'")
			ddns_info.status = i18n.translatef("Can not get external address via IP Check URL '%s' !",web_url)
		else
			ddns_info.status = ""
		end
	end

	-- vpn
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

	-- sim
	local sim_info = {}
	local tmp_tb = uci:get_all("endpoint_mobile") or {}
	local tmp_str = util.exec("fs_cli -x 'gsm dump 1' | sed -n '/^chan_ready/p;/simpin_state/p;/^not_registered/p;/^phone_num/p;/^opname/p;/^got_signal/p;' | tr '\n' '#'")
	sim_info.number = tmp_str:match("phone_num%s*=%s*([^#]+)#") or "未知"
	sim_info.carrier = tmp_str:match("opname%s*=%s*([^#]+)#") or "未知"
	sim_info.signal = tmp_str:match("got_signal%s*=%s*(%d+)#") or "0"
	if tmp_str:match("chan_ready%s*=%s*([^#]+)#") ~= "1" then
		sim_info.status = "no_device"
	elseif tmp_str:match("simpin_state%s*=%s*([^#]+)#") ~= "SIMPIN_READY" then
		sim_info.status = "no_card"
	elseif tmp_str:match("not_registered%s*=%s*([^#]+)#") ~= "0" then
		sim_info.status = "no_registered"
	else
		sim_info.status = "registered"
	end

	local simpin_state = tmp_str:match("simpin_state = ([^#]+)#")
	local not_register = tmp_str:match("not_registered = (%d+)")
	if simpin_state ~= "SIMPIN_READY" then
		sim_info.status = "no_card"
	elseif not_register ~= "0" then
		sim_info.status = "not_registered"
	else
		sim_info.status = "registered"
	end

	if luci.http.formvalue("status") == "1" then
		local rv = {
			net_info = net_info,
			wifi_info = wifi_info,
			siptrunk_info = siptrunk_info,
			ddns_info = ddns_info,
			vpn_info = vpn_info,
			sim_info = sim_info
		}

		luci.http.prepare_content("application/json")
		luci.http.write_json(rv)

		return
	else
		luci.template.render("admin_affair/index",{
			net_info = net_info,
			wifi_info = wifi_info,
			siptrunk_info = siptrunk_info,
			ddns_info = ddns_info,
			vpn_info = vpn_info,
			sim_info = sim_info
		})
	end
end
