module("luci.controller.admin.network", package.seeall)

function index()
	local uci = require("luci.model.uci").cursor()
	local util = require "luci.util"
	local fs = require "luci.fs"
	local page
	local drv_str = util.exec("lsmod | sed -n '/^rt2x00/p;/^rt2860v2_ap/p;/^rt2860v2_sta/p;'")
	drv_str = drv_str:match("(rt2860v2_ap)") or drv_str:match("(rt2860v2_sta)") or drv_str:match("(rt2x00)") or ""

	page = node("admin","network")
	page.target = firstchild()
	page.title = _("Network")
	page.order = 40
	page.index = true
	entry({"admin","network","setting"}, cbi("admin_network/setting"), _("Setting"), 10).leaf = true
	
	if drv_str == "rt2860v2_ap" then
		entry({"admin", "network", "wlan"}, alias("admin","network","wlan","wlan_config"), _("WLAN"),20)
		entry({"admin","network","wlan","wlan_config"},call("action_wlan"),_("WLAN Config"),20)
		entry({"admin","network","wlan","wlan_config","edit"},cbi("admin_network/wlan_edit"),nil,21).leaf = true
		entry({"admin","network","wps"},call("action_wps"))
	end
	
	--@ LTE License
	if luci.version.license and luci.version.license.lte then
		entry({"admin","network","lte"},cbi("admin_network/wan_lte_edit"),_("LTE"),30)
		entry({"admin","network","uplink"},cbi("admin_network/uplink_edit"),_("Uplink Config"),40)
	end
	
	entry({"admin","network","access_control"}, cbi("admin_network/access_control"), _("Access Control"), 50).leaf = true
	entry({"admin","network","firewall"}, call("firewall"), _("Firewall"), 60)
	entry({"admin","network","firewall","filter"},cbi("admin_network/filter_edit"),nil,60).leaf = true
	entry({"admin","network","dhcp_server"}, cbi("admin_network/dhcp_server"), _("DHCP Server"), 70).leaf = true
	entry({"admin","network","port_map"},call("port_map"),_("Port Mapping"),80)
	entry({"admin","network","port_map","port_map"},cbi("admin_network/port_map_edit"),nil,80).leaf = true
	entry({"admin","network","dmz"}, cbi("admin_network/dmz"), _("DMZ Setting"), 90).leaf = true
	entry({"admin","network","diagnostics"},call("action_tcpdump"), _("Diagnostics"), 100).leaf = true
	entry({"admin","network","ddns"},cbi("admin_network/ddns_config"), _("DDNS"), 110).leaf = true

	entry({"admin","network","static_route"}, call("static_route_list"),_("Static Route"),120)
	entry({"admin","network","static_route","static_route"}, cbi("admin_network/static_route_edit"),nil,120).leaf = true
	entry({"admin","network","diag_ping"}, call("diag_ping"), nil).leaf = true
	entry({"admin","network","diag_nslookup"}, call("diag_nslookup"), nil).leaf = true
	entry({"admin","network","diag_traceroute"}, call("diag_traceroute"), nil).leaf = true
	entry({"admin","network","upnpc"},cbi("admin_network/upnpc"),_("UPnP Client"),130).leaf = true
	entry({"admin","network","vpn"}, alias("admin","network","vpn","pptp"),_("VPN Client"),140)
	entry({"admin","network","vpn","pptp"},cbi("admin_network/pptp_client_edit"),_("PPTP"),140)
	entry({"admin","network","vpn","l2tp"},cbi("admin_network/l2tp_client_edit"),_("L2TP"),141).leaf = true
	entry({"admin","network","vpn","openvpn"},call("action_openvpn"),_("OpenVPN"),142)
	entry({"admin","network","hosts"},call("action_hosts"),_("Hosts"),150).leaf = true
	entry({"admin","network","mount"},alias("admin","network","mount","mount"),160,_("Mount"))
	entry({"admin","network","mount","mount"},call("action_mount"),_("Mount"),160).leaf = true
	entry({"admin","network","mount","mount_edit"},template("action_network/mount_edit"),_("Config"),160).leaf = true
end

function firewall()
	local MAX_RULE = 32
	local uci = require "luci.model.uci".cursor()
	local ds = require "luci.dispatcher"
	local i18n = require "luci.i18n"

	uci:check_cfg("firewall")

	local del_target = luci.http.formvaluetable("Delete")
	if next(del_target) then
		uci:delete_section(del_target)
	end

	local firewall = uci:get_all("firewall") or {}
	local network_mode = uci:get("network_tmp","network","network_mode") or "route"
	local enabled_cfg
	local enabled_flag
	local zone_lan
	local default_action
	
	for k,v in pairs(firewall) do
		if v['.type'] == "defaults" then
			enabled_cfg = k
			enabled_flag = v.enabled or "0"
		elseif v['.type'] == "zone" and v.name == "lan" then
			zone_lan = k
			default_action = v.lan_forward or v.forward or "ACCEPT"
		end
	end

	if "save" == luci.http.formvalue("action") then
		enabled_flag = luci.http.formvalue("firewall.enabled") or "0"
		default_action = luci.http.formvalue("firewall.default_action") or "ACCEPT"
		uci:set("firewall",enabled_cfg,"enabled",enabled_flag)
		uci:set("firewall",zone_lan,"lan_forward",default_action)
		uci:save("firewall")
	end

	if luci.http.formvalue("New") then
		local created = uci:section("firewall","rule")
		uci:save("firewall")
		luci.http.redirect(ds.build_url("admin","network","firewall","filter",created,"add"))
		return
	end

	local th = {"Index","Name","Protocol","LAN IP/Port/MAC","WAN IP/Port","Action"}
	local colgroup = {"5%","10%","10%","34%","28%","6%","7%"}
	local content = {}
	local edit = {}
	local delchk = {}
	local uci_cfg = {}
	local addnewable = true
	local cnt = 0

	local firewall_cfg = uci:get_all("firewall") or {}
	
	for i=1,MAX_RULE do
		for k,v in pairs(firewall_cfg) do
			if v.index and v.name and "rule" == v['.type'] and i == tonumber(v.index) then
				cnt = cnt + 1
				local tmp = {}
				tmp[1] = v.index
				tmp[2] = v.name
				if not v.proto or v.proto == "all" then
					tmp[3] = i18n.translate("Any")
				elseif v.proto == "tcp udp" then
					tmp[3] = i18n.translate("tcp").."/"..i18n.translate("udp")
				else
					tmp[3] = i18n.translate(v.proto)
				end
				tmp[4] = (v.src_ip or "*").."/"..(v.src_port or "*").."/"..(v.src_mac or "*")
				tmp[5] = (v.dest_ip or "*").."/"..(v.dest_port or "*")
				tmp[6] = v.target == "ACCEPT" and i18n.translate("Accept") or i18n.translate("Reject")
				
				edit[cnt] = ds.build_url("admin","network","firewall","filter",k,"edit")
				--delchk[cnt] = uci:check_cfg_deps("endpoint_sipphone",k,"route.endpoint")
				uci_cfg[cnt] = "firewall." .. k
				table.insert(content,tmp)
			end
		end
	end
	if MAX_RULE == cnt then
		addnewable = false
	end
	luci.template.render("admin_network/firewall",{
		title = i18n.translate("Filter Rules"),
		network_mode = network_mode,
		enable = enabled_flag,
		default_action = default_action,
		colgroup = colgroup,
		th = th,
		content = content,
		edit = edit,
		delchk = delchk,
		uci_cfg = uci_cfg,
		addnewable = addnewable,
		})
end

function port_map()
	local MAX_RULE = 32
	local uci = require "luci.model.uci".cursor()
	local ds = require "luci.dispatcher"
	local i18n = require "luci.i18n"

	uci:check_cfg("firewall")

	local del_target = luci.http.formvaluetable("Delete")
	if next(del_target) then
		uci:delete_section(del_target)
	end

	if luci.http.formvalue("New") then
		local created = uci:section("firewall","redirect")
		uci:save("firewall")
		luci.http.redirect(ds.build_url("admin","network","port_map","port_map",created,"add"))
		return
	end
	
	--@ Enable/Disable
	local status_target = luci.http.formvaluetable("Status")
	if status_target and "table" == type(status_target) then
		for k,v in pairs(status_target) do
			local state,cfg,section = k:match("([A-Za-z]+)%.([a-zA-Z_]+)%.(%w+).x")
			if cfg and section and state then
				uci:set(cfg,section,"enabled",state == "Enabled" and "1" or "0")
				uci:save(cfg)
			end
		end
	end

	local th = {"Index","Name","WAN Port","Protocol","LAN IP","LAN Port","Status"}
	local colgroup = {"5%","10%","15%","20%","20%","15%","7%","8%"}
	local content = {}
	local edit = {}
	local delchk = {}
	local uci_cfg = {}
	local status = {}
	local addnewable = true
	local cnt = 0
	local firewall_cfg = uci:get_all("firewall") or {}
	for i=1,MAX_RULE do
		for k,v in pairs(firewall_cfg) do
			if v.index and v.name and v['.type'] == "redirect" and v.src_dport and i == tonumber(v.index)then
				cnt = cnt + 1
				local tmp = {}
				tmp[1] = v.index
				tmp[2] = v.name
				tmp[3] = v.src_dport or ""
				tmp[4] = string.upper(v.proto or "")
				tmp[5] = v.dest_ip or ""
				tmp[6] = v.dest_port or ""
				tmp[7] = v.enabled and i18n.translate(v.enabled == "1" and "Enabled" or "Disabled") or i18n.translate("Enabled")
				
				edit[cnt] = ds.build_url("admin","network","port_map","port_map",k,"edit")
				uci_cfg[cnt] = "firewall." .. k
				status[cnt] = v.enabled and (v.enabled == "1" and "Enabled" or "Disabled") or "Enabled"
				table.insert(content,tmp)
			end
		end
	end
	if MAX_RULE == cnt then
		addnewable = false
	end
	luci.template.render("cbi/configlist",{
		title = i18n.translate("Network / Port Mapping"),
		colgroup = colgroup,
		th = th,
		content = content,
		edit = edit,
		status = status,
		delchk = delchk,
		uci_cfg = uci_cfg,
		addnewable = addnewable,
		})
end

function diag_command(cmd)
	local addr = luci.http.formvalue("addr")
	if addr and addr:match("^[a-zA-Z0-9%-%.:_]+$") then
		luci.http.prepare_content("text/plain")
		local util = io.popen(cmd % addr)
		if util then
			while true do
				local ln = util:read("*l")
				if not ln then break end
				luci.http.write(ln)
				luci.http.write("\n")
			end
			util:close()
		end
		return
	end
	luci.http.status(500, "Bad address")
end

function diag_ping()
	diag_command("ping -c 5 -W 1 %q 2>&1")
end

function diag_traceroute()
	diag_command("traceroute -q 1 -w 1 -n %q 2>&1")
end

function diag_nslookup()
	diag_command("nslookup %q 2>&1")
end

function action_wps()
	local util = require "luci.util"
	local action_type = luci.http.formvalue("action_type")
	local pin_code = luci.http.formvalue("pin_code")
	local fs = require "luci.fs"
	local dev_name = ""
	local drv_str = util.exec("lsmod | sed -n '/^rt2x00/p;/^rt2860v2_ap/p;/^rt2860v2_sta/p;'")
	drv_str = drv_str:match("(rt2860v2_ap)") or drv_str:match("(rt2860v2_sta)") or drv_str:match("(rt2x00)") or ""

	if drv_str == "rt2860v2_ap" or drv_str == "rt2860v2_sta" then
		dev_name = "ra0"
	else
		dev_name = "radio0"
	end

	if not luci.http.formvalue("status") then
		if action_type == "pin" then
			--@ pin code set wps
			util.exec("iwpriv "..dev_name.." set WscPinCode="..pin_code)
			util.exec("iwpriv "..dev_name.." set WscMode=1")
			util.exec("iwpriv "..dev_name.." set WscGetConf=1")
		else
			--@ pbc set wps
			util.exec("iwpriv "..dev_name.." set WscMode=2")
			util.exec("iwpriv "..dev_name.." set WscGetConf=1")
		end
		util.exec("iwpriv "..dev_name.." show WscPeerList")		
	end
	
	local ret_status = util.exec("iwpriv "..dev_name.." show WscPeerList"):match(dev_name.."%s*WscStatus:%s*([0-9]+)")
	
	luci.http.prepare_content("application/json")
	luci.http.write_json({ status = ret_status})
end

function action_wlan()
	local MAX_EXTENSION = 4
	local uci = require "luci.model.uci".cursor()
	local util = require "luci.util"
	local ds = require "luci.dispatcher"
	local i18n = require "luci.i18n"
	local fs = require "luci.fs"
	local dev_name = ""
	local ra_name = ""
	local drv_str = util.exec("lsmod | sed -n '/^rt2x00/p;/^rt2860v2_ap/p;/^rt2860v2_sta/p;'")
	drv_str = drv_str:match("(rt2860v2_ap)") or drv_str:match("(rt2860v2_sta)") or drv_str:match("(rt2x00)") or ""

	if drv_str == "rt2860v2_ap" or drv_str == "rt2860v2_sta" then
		dev_name = "ra0"
		ra_name = "ra"
	else
		dev_name = "radio0"
		ra_name = "radio"
	end

	uci:check_cfg("wireless")

	local g_channel = uci:get("wireless",dev_name,"channel") or "auto"
	local g_bandwidth = uci:get("wireless",dev_name,"htmode") or "HT20/HT40"
	local g_hwmode = uci:get("wireless",dev_name,"hwmode") or "11bgn"
	local g_txpower = uci:get("wireless",dev_name,"txpower") or "100"
	local g_isolate = uci:get("wireless",dev_name,"btw_isolate") or uci:get("wireless",dev_name,"isolate") or "0"
	local g_disabled = uci:get("wireless",dev_name,"disabled") or "0"
	local g_wps = uci:get("wireless",dev_name,"wps") or "off"
	
	--@ service save
	if luci.http.formvalue("save") then
		g_channel = luci.http.formvalue("channel")
		g_bandwidth = luci.http.formvalue("bandwidth")
		g_hwmode = luci.http.formvalue("hwmode")
		g_txpower = luci.http.formvalue("txpower")
		g_isolate = luci.http.formvalue("isolate")
		g_disabled = luci.http.formvalue("disabled")
		g_wps = luci.http.formvalue("wps")
		
		uci:set("wireless",dev_name,"channel",g_channel)
		uci:set("wireless",dev_name,"htmode",g_bandwidth)
		uci:set("wireless",dev_name,"hwmode",g_hwmode)
		uci:set("wireless",dev_name,"txpower",g_txpower)
		uci:set("wireless",dev_name,"btw_isolate",g_isolate)
		uci:set("wireless",dev_name,"disabled",g_disabled)
		uci:set("wireless",dev_name,"wps",g_wps)
		
		uci:save("wireless")
	end
	
	local del_target = luci.http.formvaluetable("Delete")
	if del_target then
		uci:delete_section(del_target)
	end

	if luci.http.formvalue("New") then
		local created = uci:section("wireless","wifi-iface")
		uci:save("wireless")
		luci.http.redirect(ds.build_url("admin","network","wlan","wlan_config","edit",created,"add"))
		return
	end
	
	--@ Enable/Disable
	local status_target = luci.http.formvaluetable("Status")
	if status_target and "table" == type(status_target) then
		for k,v in pairs(status_target) do
			local state,cfg,section = k:match("([A-Za-z]+)%.([a-zA-Z_]+)%.(%w+).x")
			if cfg and section and state then
				uci:set(cfg,section,"disabled",state == "Enabled" and "0" or "1")
				uci:save(cfg)
			end
		end
	end

	local th = {"Index","SSID","Encryption","Isolation (within SSID)","WMM","Status"}
	local colgroup = {"10%","25%","12%","20%","12%","11%","10%"}
	local content = {}
	local edit = {}
	local delchk = {}
	local uci_cfg = {}
	local status = {}
	local addnewable = true
	local cnt = 0

	local tmp_cfg = uci:get_all("wireless") or {}
	local wds_status = false
	
	for i=1,MAX_EXTENSION do
		for k,v in pairs(tmp_cfg) do
			if v.index and v['.type'] == "wifi-iface" and v.ssid then
				if i == tonumber(v.index) then
					cnt = cnt + 1
					local tmp = {}
					tmp[1] = v.index
					tmp[2] = v.ssid
					tmp[3] = v.encryption == "none" and i18n.translate("NONE") or (v.encryption == "psk" and "WPA+PSK" or "WPA2+PSK")
					tmp[4] = i18n.translate(v.isolate == "0" and "Disabled" or "Enabled")
					tmp[5] = i18n.translate(v.wmm == "0" and "Off" or "On")
					tmp[6] = i18n.translate(v.disabled == "1" and "Disabled" or "Enabled")
					
					edit[cnt] = ds.build_url("admin","network","wlan","wlan_config","edit",k,"edit")
					uci_cfg[cnt] = "wireless." .. k
					if cnt ~= 1 then
						delchk[cnt] = wds_status == true and "alert('"..i18n.translatef("Can not delete, it is being used in <%s> !",tostring(i18n.translate("WDS Config"))).."');return false" or "return true"
					end
					status[cnt] = v.disabled == "1" and "Disabled" or "Enabled"
					table.insert(content,tmp)
				end
			end
		end
	 end
	if MAX_EXTENSION == cnt then
		addnewable = false
	end
	luci.template.render("admin_network/wlan",{
		colgroup = colgroup,
		th = th,
		content = content,
		edit = edit,
		delchk = delchk,
		uci_cfg = uci_cfg,
		status = status,
		channel = g_channel,
		txpower = g_txpower,
		bandwidth = g_bandwidth,
		hwmode = g_hwmode,
		isolate = g_isolate,
		disabled = g_disabled,
		wps = g_wps,
		addnewable = addnewable,
		})
end

function action_tcpdump()
	local sys = require "luci.sys"
	local fs  = require "luci.fs"
	local util = require "luci.util"
	local uci = require "luci.model.uci".cursor()

	if luci.http.formvalue("diag_tcpdump_start") then
		local tcpdump_cmd
		if "custom" == luci.http.formvalue("cbid.diag.set") then
			local src_ip = luci.http.formvalue("src-ip")
			local src_port = luci.http.formvalue("src-port")
			local dst_ip = luci.http.formvalue("dst-ip")
			local dst_port = luci.http.formvalue("dst-port")
			local logic = luci.http.formvalue("cbid.condition.logic") or "or"
			local proto
			local proto_t
			local interface = luci.http.formvalue("cbid.interface.set")

			src_ip = "" ~= src_ip and "src host "..string.gsub(src_ip,"|","||")
			src_port = "" ~= src_port and " src port "..string.gsub(src_port,"|","||")
			dst_ip = "" ~= dst_ip and " dst host "..string.gsub(dst_ip,"|","||")
			dst_port = "" ~= dst_port and " dst port "..string.gsub(dst_port,"|","||")

			local proto_list = luci.http.formvaluetable("cbid.proto")
			for k,v in pairs(proto_list) do
				if "rtp" == k or "rtcp" == k then
					proto_t = proto_t and (proto_t.." -T "..k) or (" -T "..k)
				else
					proto = proto and (proto.." or "..k) or k
				end
			end

			--@ get tcpdump_cmd_str
			tcpdump_cmd = src_ip
			tcpdump_cmd = (src_port and tcpdump_cmd) and (tcpdump_cmd.." "..logic.." "..src_port) or src_port or tcpdump_cmd
			tcpdump_cmd = (dst_ip and tcpdump_cmd) and (tcpdump_cmd.." "..logic.." "..dst_ip) or dst_ip or tcpdump_cmd
			tcpdump_cmd = (dst_port and tcpdump_cmd) and (tcpdump_cmd.." "..logic.." "..dst_port) or dst_port or tcpdump_cmd
			tcpdump_cmd = (proto and tcpdump_cmd) and (tcpdump_cmd .. " "..logic.." (" ..proto..")") or (proto and "("..proto..")") or tcpdump_cmd

			local tcpdump_header = ""
			if interface == "wan" then
				tcpdump_header = "tcpdump -U -C 10 -W 1 -s 0 -i eth0.2 "
			elseif interface == "lan" then
				tcpdump_header = "tcpdump -U -C 10 -W 1 -s 0 -i br-lan "
			elseif interface == "wlan" then
				tcpdump_header = "tcpdump -U -C 10 -W 1 -s 0 -i wlan0 "
			else
				tcpdump_header = "tcpdump -U -C 10 -W 1 -s 0 -i any "
			end

			tcpdump_cmd = tcpdump_header.."'"..(tcpdump_cmd or "").."'"..(proto_t or "").." -w /tmp/package.pcap &"
			os.execute(tcpdump_cmd)
		elseif "voice" == luci.http.formvalue("cbid.diag.set") then
			require "ESL"
			local sip_profile = uci:get_all("profile_sip") or {}
			local port
			for k,v in pairs(sip_profile) do
				if v.index and v.localport then
					port = port and (port.." or "..v.localport) or v.localport
				end
			end

			local portrange = (uci:get_all("callcontrol","voice","rtp_start_port") or "16000") .. "-" .. (uci:get_all("callcontrol","voice","rtp_end_port") or "16200")
			local con = ESL.ESLconnection("127.0.0.1","8021","ClueCon")
			if 1 == con:connected() then
				con:api("c300dsp 450 9") --旧方法通过fs_cli执行，不一定能成功
				os.execute("touch /tmp/voice_capture_flag && tcpdump -U -C 10 -W 1 -s 0 -i any "..(port and ("port "..port.." or ") or "").." portrange "..portrange.." -w /tmp/rtp_capture.pcap &")
			end
			con:disconnect()
		else
		end
	elseif luci.http.formvalue("diag_tcpdump_end") then
		--@ stop tcpdump
		os.execute("killall tcpdump")
		local localip = luci.http.getenv("SERVER_ADDR")
		local capture_file = "/tmp/package.pcap"
		if fs.access(capture_file) then
			luci.http.header('Content-Disposition', 'attachment; filename="network_capture-%s-%s-%s.pcap"' % {
				luci.sys.hostname(), localip, os.date("%Y-%m-%d %X")})
			luci.http.prepare_content("application/octet-stream")
			luci.ltn12.pump.all(luci.ltn12.source.file(io.open(capture_file)), luci.http.write)
			fs.unlink(capture_file)
		end
		--# for dsp only
		if fs.access("/tmp/voice_capture_flag") or fs.access("/tmp/rtp_capture.pcap") then
			require "ESL"
			local destfile_gz = "/tmp/voice_capture.tar.gz"
			os.execute("rm /tmp/voice_capture_flag")
			--@ stop capture
			local con = ESL.ESLconnection("127.0.0.1","8021","ClueCon")
			if 1 == con:connected() then
				con:api("c300dsp 451 9")
			end
			con:disconnect()
			sys.call("tar -c /tmp/pcm_send_* /tmp/pcm_recv_* /tmp/rtp_capture.pcap -f "..destfile_gz)
			local reader = luci.ltn12.source.file(io.open(destfile_gz,"r"))
			luci.http.header('Content-Disposition', 'attachment; filename="voice_capture-%s-%s-%s.tar.gz"' % {luci.sys.hostname(), localip, os.date("%Y-%m-%d %X")})
			luci.http.prepare_content("application/gzip")
			luci.ltn12.pump.all(reader, luci.http.write)
			fs.unlink(destfile_gz)
			os.execute("(rm /tmp/pcm_send_* && rm /tmp/pcm_recv_* && rm /tmp/rtp_capture.pcap )&")
		end
	else
		--@ Whether tcpdump exists
		if fs.access("/usr/bin/tcpdump") then
			--@ Whether tcpdump command running
			if fs.access("/tmp/voice_capture_flag") then
				luci.template.render("admin_network/diagnostics",{capture_status = "voice_working"})
			else
				local ps = util.exec("ps")
				if string.find(ps,"tcpdump") then
					luci.template.render("admin_network/diagnostics",{capture_status = "custom_working"})
				else
					luci.template.render("admin_network/diagnostics",{capture_status = "stop"})
				end
			end
		else
			luci.template.render("admin_network/diagnostics",{capture_status = "fault"})
		end
	end
end

--@*******************************************
--#函数描述:web界面主菜单网络下静态路由子菜单的页面
--@*******************************************
function static_route_list()
	local MAX_RULE = 10
	local uci = require "luci.model.uci".cursor()
	local ds = require "luci.dispatcher"
	local i18n = require "luci.i18n"

	uci:check_cfg("static_route")

	--点击删除就删除这个导航网页
	local del_target = luci.http.formvaluetable("Delete")
	if next(del_target) then
		uci:delete_section(del_target,"")
	end

	--点击新建就新建一个导航网页
	if luci.http.formvalue("New") then
		local created = uci:section("static_route","route")
		uci:save("static_route")
		luci.http.redirect(ds.build_url("admin","network","static_route","static_route",created,"add"))
		return
	end

	--@启动
	local enable_target = luci.http.formvaluetable("Enable")
	if next(enable_target) then
		for k,v in pairs(enable_target) do
			local cfg,section = k:match("([a-z_]+)%.(%w+).x")
			if cfg and section then
				if nil == uci:get("network" , "wan" , "ifname") and "wan" == uci:get(cfg,section,"interface") then
					uci:set(cfg,section,"status","Disabled")
					uci:save(cfg)
				else
					uci:set(cfg,section,"status","Enabled")
					uci:save(cfg)
				end
			end
		end
	end

	--@禁止
	local disable_target = luci.http.formvaluetable("Disable")
	if next(disable_target) then
		for k,v in pairs(disable_target) do
			local cfg,section = k:match("([a-z_]+)%.(%w+).x")
			if cfg and section then
				uci:set(cfg,section,"status","Disabled")
				uci:save(cfg)
			end
		end
	end

	local th = {"Index","Name","Target IP","Netmask","Gateway","Interface","Status"}
	local colgroup = {"8%","8%","18%","18%","18%","13%","7%","10%"}
	local content = {}
	local edit = {}
	local delchk = {}
	local uci_cfg = {}
	local status ={}
	local addnewable = true
	local cnt = 0
	local network_route=uci:get_all("static_route") or {}
	local interface_name={["wan"]="WAN",["lan"]="LAN",["wan2"]="LTE",["openvpn"]="OpenVPN",["ppp1701"]="L2TP",["ppp1723"]="PPTP"}
		
	for i=1,MAX_RULE do
		for k,v in pairs(network_route) do
			if v['.type'] == "route" and v.index and i == tonumber(v.index) and v.name then
				cnt = cnt + 1
				local tmp = {}
				tmp[1] = v.index
				tmp[2] = v.name
				tmp[3] = v.target or ""
				tmp[4] = v.netmask or ""
				tmp[5] = v.gateway or ""
				tmp[6] = interface_name[v.interface or "unknown"] or "Error"
				tmp[7] = i18n.translate(v.status or "")
				status[cnt] = v.status
				edit[cnt] = ds.build_url("admin","network","static_route","static_route",k,"edit")
				--delchk[cnt] = uci:check_cfg_deps("static_route",k,"route.endpoint")
				uci_cfg[cnt] = "static_route." .. k
				table.insert(content,tmp)
			end
		end
	end
	if MAX_RULE == cnt then
		addnewable = false
	end
	luci.template.render("admin_network/static_route",{
		title = i18n.translate("Network / Static Route"),
		colgroup = colgroup,
		th = th,
		content = content,
		edit = edit,
		delchk = delchk,
		uci_cfg=uci_cfg,
		addnewable = addnewable,
		status = status,
		})
end

function action_openvpn()
	local sys = require "luci.sys"
	local fs  = require "luci.fs"
	local ds = require "luci.dispatcher"
	local uci = require "luci.model.uci".cursor()
	local fs_server = require "luci.scripts.fs_server"
	local destfile = "/tmp/my-vpn.conf.latest"

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

	local status = luci.http.formvalue("status")
	if status then
		uci:set("openvpn","custom_config","enabled",status)
		uci:save("openvpn")
	end

	local defaultroute = luci.http.formvalue("defaultroute")
	if defaultroute then
		uci:set("openvpn","custom_config","defaultroute",defaultroute)
		uci:save("openvpn")
	end

	status = uci:get("openvpn","custom_config","enabled")
	defaultroute = uci:get("openvpn","custom_config","defaultroute")

	if luci.http.formvalue("key") then
		local key = luci.http.formvalue("key")
		if key and #key > 0 then
			uci:set("openvpn","custom_config","key_change","0"==uci:get("openvpn","custom_config","key_change") and "1" or "0")
			uci:save("openvpn")
			luci.template.render("admin_network/openvpn",{
				result = "upload succ",
				status = status,
				defaultroute = defaultroute,
			})
		else
			luci.template.render("admin_network/openvpn",{
				status = uci:get("openvpn","custom_config","enabled"),
				defaultroute = defaultroute,
			})
		end
	else
		luci.template.render("admin_network/openvpn",{
			status = status,
			defaultroute = defaultroute,
		})
	end
end

function action_hosts()
	local fs = require "nixio.fs"
	local uci = require "luci.model.uci".cursor()
	local util = require "luci.util"
	local content=""
	uci:check_cfg("hosts")

	if luci.http.formvalue("status") then
		if uci:get("hosts","default") then
			uci:set("hosts","default","enabled",luci.http.formvalue("status"))
		else
			local tmp={}
			uci:section("hosts","hosts","default",{})
			uci:commit("hosts")
			uci:set("hosts","default","enabled",luci.http.formvalue("status"))
		end
		local data = luci.http.formvalue("hosts_list")
		uci:set_list("hosts","default","hosts", util.split(data,"\n"))
		uci:save("hosts")
	end
	content = table.concat((uci:get("hosts","default","hosts") or {}),"\n")
	status=uci:get("hosts","default","enabled") or "0"
	
	luci.template.render("admin_network/hosts",{
		status=status,
		content=content,
		})
end

function parse_dir(param)
	local util = require "luci.util"
	local ret_tb = {}

	if param then
		local ret_cmd = util.exec("ls -lahrS "..param)
		local tmp_tb = util.split(ret_cmd,"\n") or {}

		for _,v in ipairs(tmp_tb) do
			if v then
				local temp = {}
				
				local mode,size,mtime,name = v:match("^([a-zA-Z%-]+)%s*[0-9]+%s*[a-zA-Z]+%s*[a-zA-Z]+%s*([0-9a-zA-Z%.]+)%s*([a-zA-Z]+%s*[0-9]+%s*[0-9:]+)%s*(.+)")
				if mode and size and mtime and name and name ~= ".." and name ~= "." then
					temp.file_name = name
					temp.mtime = mtime
					temp.path = param.."/"..name
					temp.file_type = mode:match("^.") == "d" and "directory" or "file"
					if temp.file_type == "directory" then
						temp.size = util.exec("du -h -d 0 "..temp.path.." | awk '{print$1}'"):match("(.+)\n$") or "-"
					else
						temp.size = size
					end
					
					table.insert(ret_tb,temp)
				end
			end
		end
	end
	
	return ret_tb
end

function parse_mount_size(cmd_param)
	local util = require "luci.util"
	local ret_tsize = 0
	local ret_rsize = 0

	if cmd_param then
		local ret_cmd = util.exec(cmd_param)
		_,ret_tsize,_,ret_rsize,_,_ = ret_cmd:match("^(.+)%s+([a-zA-Z0-9%.]+)%s+([a-zA-Z0-9%.]+)%s+([a-zA-Z0-9%.]+)%s+([0-9%.%%]+)%s+([a-zA-z0-9%/]+)")
	end

	return ret_tsize,ret_rsize
end

function action_mount()
	local fs = require "luci.fs"
	local sys = require "luci.sys"
	local util = require "luci.util"
	local translate = require "luci.i18n"
	local file_content = {}
	local dev_file = "/mnt/tmp"
	local root_path = "/mnt/tmp"
	local rel_path = ""
	local abs_path = ""
	local tmp_file = ""
	local upload_file
	local refresh_flag = true
	local error_info
	local writable = true
	
	--@ get upload file
	local fp
	luci.http.setfilehandler(
		function(meta, chunk, eof)
			if writable then
				if not fp then
					if meta and meta.name then
						tmp_file = os.tmpname()
						file_name = meta.file or "newfile"
						fp = io.open(tmp_file,"w")
					end
				end
				if chunk then
					fp:write(chunk)
				end
				if eof and fp then
					fp:close()
					fp = nil
					--@ mv to abs_path
					local save_path = root_path..(luci.http.formvalue("cur_dir") or rel_path)
					util.exec("mv "..tmp_file.." "..save_path.."/"..file_name)
				end
			end
		end
	)

	rel_path = luci.http.formvalue("cur_dir") or ""
	abs_path = root_path..rel_path
	--@ download
	if luci.http.formvalue("file_download") then
		local download_filename = luci.http.formvalue("file_download") -- http formvalue
		local content_type_list = {
			ai="application/postscript",
			aif="audio/x-aiff",
			aifc="audio/x-aiff",
			aiff="audio/x-aiff",
			asc="text/plain",
			au="audio/basic",
			avi="video/x-msvideo",
			bcpio="application/x-bcpio",
			bin="application/octet-stream",
			bmp="image/bmp",
			cdf="application/x-netcdf",
			class="application/octet-stream",
			cpio="application/x-cpio",
			cpt="application/mac-compactpro",
			csh="application/x-csh",
			css="text/css",
			dcr="application/x-director",
			dir="application/x-director",
			djv="image/vnd.djvu",
			djvu="image/vnd.djvu",
			dll="application/octet-stream",
			dms="application/octet-stream",
			doc="application/msword",
			dvi="application/x-dvi",
			dxr="application/x-director",
			eps="application/postscript",
			etx="text/x-setext",
			exe="application/octet-stream",
			ez="application/andrew-inset",
			gif="image/gif",
			gtar="application/x-gtar",
			hdf="application/x-hdf",
			hqx="application/mac-binhex40",
			htm="text/html",
			html="text/html",
			ice="x-conference/x-cooltalk",
			ief="image/ief",
			iges="model/iges",
			igs="model/iges",
			jpe="image/jpeg",
			jpeg="image/jpeg",
			jpg="image/jpeg",
			js="application/x-javascript",
			kar="audio/midi",
			latex="application/x-latex",
			lha="application/octet-stream",
			lzh="application/octet-stream",
			m3u="audio/x-mpegurl",
			man="application/x-troff-man",
			me="application/x-troff-me",
			mesh="model/mesh",
			mid="audio/midi",
			midi="audio/midi",
			mif="application/vnd.mif",
			mov="video/quicktime",
			movie="video/x-sgi-movie",
			mp2="udio/mpeg",
			mp3="audio/mpeg",
			mpe="video/mpeg",
			mpeg="video/mpeg",
			mpg="video/mpeg",
			mpga="audio/mpeg",
			ms="application/x-troff-ms",
			msh="model/mesh",
			mxu="video/vnd.mpegurl",
			nc="application/x-netcdf",
			oda="application/oda",
			pbm="image/x-portable-bitmap",
			pdb="chemical/x-pdb",
			pdf="application/pdf",
			pgm="image/x-portable-graymap",
			pgn="application/x-chess-pgn",
			png="image/png",
			pnm="image/x-portable-anymap",
			ppm="image/x-portable-pixmap",
			ppt="application/vnd.ms-powerpoint",
			ps="application/postscript",
			qt="video/quicktime",
			ra="audio/x-realaudio",
			ram="audio/x-pn-realaudio",
			ras="image/x-cmu-raster",
			rgb="image/x-rgb",
			rm="audio/x-pn-realaudio",
			roff="application/x-troff",
			rpm="audio/x-pn-realaudio-plugin",
			rtf="text/rtf",
			rtx="text/richtext",
			sgm="text/sgml",
			sgml="text/sgml",
			sh="application/x-sh",
			shar="application/x-shar",
			silo="model/mesh",
			sit="application/x-stuffit",
			skd="application/x-koan",
			skm="application/x-koan",
			skp="application/x-koan",
			skt="application/x-koan",
			smi="application/smil",
			smil="application/smil",
			snd="audio/basic",
			so="application/octet-stream",
			spl="application/x-futuresplash",
			src="application/x-wais-source",
			sv4cpio="application/x-sv4cpio",
			sv4crc="application/x-sv4crc",
			swf="application/x-shockwave-flash",
			t="application/x-troff",
			tar="application/x-tar",
			tcl="application/x-tcl",
			tex="application/x-tex",
			texi="application/x-texinfo",
			texinfo="application/x-texinfo",
			tif="image/tiff",
			tiff="image/tiff",
			tr="application/x-troff",
			tsv="text/tab-separated-values",
			txt="text/plain",
			ustar="application/x-ustar",
			vcd="application/x-cdlink",
			vrml="model/vrml",
			wav="audio/x-wav",
			wbmp="image/vnd.wap.wbmp",
			wbxml="application/vnd.wap.wbxml",
			wml="text/vnd.wap.wml",
			wmlc="application/vnd.wap.wmlc",
			wmls="text/vnd.wap.wmlscript",
			wmlsc="application/vnd.wap.wmlscriptc",
			wrl="model/vrml",
			xbm="image/x-xbitmap",
			xht="application/xhtml+xml",
			xhtml="application/xhtml+xml",
			xls="application/vnd.ms-excel",
			xml="text/xml",
			xpm="image/x-xpixmap",
			xsl="text/xml",
			xwd="image/x-xwindowdump",
			xyz="chemical/x-xyz",
			zip="application/zip"
		}

		refresh_flag = false
		if download_filename then
			local reader = luci.ltn12.source.file(io.open(abs_path.."/"..download_filename,"r"))
			luci.http.header('Content-Disposition', 'attachment; filename="'..download_filename..'"')
			local tmp = download_filename:match("%.([a-zA-Z0-9]+)$") or ""
			local content_type = content_type_list[tmp] or "application/octet-stream"
			
			luci.http.prepare_content(content_type)
			luci.ltn12.pump.all(reader, luci.http.write)
			fs.unlink(download_filename)
		end
	--@ new folder
	elseif luci.http.formvalue("folder_name") then
		if writable then
			local folder_name = luci.http.formvalue("folder_name") -- http formvalue
			
			if folder_name then
				util.exec("mkdir -p '"..abs_path.."/"..folder_name.."'")
			end
		end
	--@ file upload
	elseif luci.http.formvalue("file_upload") then
		--@ get upload file by trunk
		local upload_file = luci.http.formvalue("upload")
		if upload_file and #upload_file > 0 then

		end
	--@ change directory
	elseif luci.http.formvalue("change_dir") or luci.http.formvalue("goto_dir") then
		--@ can not move out "/mnt/tmp"
		if luci.http.formvalue("change_dir") then
			rel_path = rel_path.."/"..luci.http.formvalue("change_dir")
		else
			rel_path = luci.http.formvalue("goto_dir")
		end
		abs_path = root_path..rel_path
		abs_path = util.exec("cd '"..abs_path.."' && pwd"):match("(.+)\n$")
		if not abs_path or not abs_path:match("^"..root_path.."") then
			rel_path = ""
			abs_path = root_path
		else
			rel_path = abs_path:match("^"..root_path.."(.+)$")
			rel_path = rel_path or ""
		end
	--@ file delete
	elseif luci.http.formvalue("file_delete") then
		if writable then
			local file_name = luci.http.formvalue("file_delete")

			if file_name then
				util.exec("rm -rf '"..abs_path.."/"..file_name.."'")
			end
		end
	else
		--@ first in ,do nothing
	end

	if refresh_flag then
		--@ render to html
		file_content = parse_dir(abs_path)
		local total_size,available_size = parse_mount_size("df -h | grep "..dev_file)
		local _,max_size = parse_mount_size("df | grep "..dev_file)
		max_size = (max_size or 0) * 1024
		
		luci.template.render("admin_network/mount",{
			cur_dir = rel_path,
			file_content = file_content,
			total_size = total_size,
			available_size = available_size,
			max_size = max_size,
			error_info = error_info
		})
	end
end