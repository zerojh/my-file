module("luci.controller.admin.network", package.seeall)

function index()
	local uci = require("luci.model.uci").cursor()
	local util = require "luci.util"
	local fs  = require "luci.fs"
	local page

	page = node("admin", "network")
	page.target = firstchild()
	page.title  = _("Network")
	page.order  = 40
	page.index  = true

	--# WAN / VWAN / GPON
	entry({"admin", "network", "wan"}, alias("admin","network","wan","wan_config"), _("WAN"),1)
	entry({"admin","network","wan","wan_config"},cbi("admin_network/wan_config_edit"),_("WAN Config"),10)
	entry({"admin","network","wan","wan_subinterface_config"},call("action_wan_subinterface"),_("WAN Subinterface Config"),20)
	entry({"admin","network","wan","wan_subinterface_config","edit"},cbi("admin_network/wan_subinterface_edit"),nil,20).leaf = true
	if fs.access("/proc/wan_at") and util.exec("cat /proc/wan_at"):match("4") then --@ Check Pon exist
		entry({"admin","network","wan","gpon"},call("action_gpon"),_("GPON"),30)
	end

	--# LAN / VLAN
	entry({"admin", "network", "vlan"}, alias("admin","network","vlan","lan_config"),_("LAN/VLAN"),2)
	entry({"admin","network","vlan","lan_config"},cbi("admin_network/lan_edit"),_("LAN Config"),10)	
	entry({"admin","network","vlan","vlan_config"},call("action_vlan"),_("VLAN Config"),20)
	entry({"admin","network","vlan","vlan_config","edit"},cbi("admin_network/vlan_edit"),nil,10).leaf = true
	entry({"admin","network","vlan","port_config"},call("action_port"),_("Port Config"),30)

	--# LTE
	if fs.access("/dev/ttyUSB0") then--@ Check 4G exist
		entry({"admin", "network", "lte"}, alias("admin","network","lte","lte"),_("LTE/Uplink"),3)
			entry({"admin","network","lte","lte"},cbi("admin_network/wan_lte_edit"),_("LTE"),10)
			entry({"admin","network","lte","uplink"},cbi("admin_network/uplink_edit"),_("Uplink Config"),20)
	end

	--# WLAN
	if fs.access("/sys/class/net/ra0") then--@ Check wifi exist
		entry({"admin", "network", "wlan"}, alias("admin","network","wlan","wlan_config"), _("WLAN"),4)
		entry({"admin","network","wlan","wlan_config"},call("action_wlan"),_("WLAN Config"),10)
		entry({"admin","network","wlan","wlan_config","edit"},cbi("admin_network/wlan_edit"),nil,20).leaf = true
		entry({"admin","network","wlan","wds_config"},call("action_wds"),_("WDS Config"),20)
		entry({"admin","network","wlan","wds_config","edit"},cbi("admin_network/wds_edit"),nil,20).leaf = true
		entry({"admin","network","wps"},call("action_wps"))
	end

	--# DHCP
	entry({"admin", "network", "dhcp"},alias("admin", "network", "dhcp", "server"),_("DHCP"),5)
	entry({"admin","network","dhcp","server"},call("action_dhcp_server"),_("DHCP Server"),10)
	entry({"admin","network","dhcp","server","edit"},cbi("admin_network/dhcp_edit"),nil,10).leaf = true
	entry({"admin","network","dhcp","static"},cbi("admin_network/static_edit"),_("Static IP Addressing"),20)

	--# VPN
	entry({"admin", "network", "vpn"}, alias("admin","network","vpn","ipsec"),_("VPN"),6)
	entry({"admin","network","vpn","ipsec"},call("action_ipsec"),_("IPSEC"),10)
	entry({"admin","network","vpn","ipsec","edit"},cbi("admin_network/ipsec_edit"),nil,10).leaf = true
	entry({"admin","network","vpn","l2tp_server"},call("action_l2tp_server"),_("L2TP Server"),20)
	entry({"admin","network","vpn","l2tp_server","edit"},cbi("admin_network/l2tp_server_edit"),nil,10).leaf = true
	entry({"admin","network","vpn","l2tp_client"},cbi("admin_network/l2tp_client_edit"),_("L2TP Client"),30)

	entry({"admin","network","vpn","pptp_server"},call("action_pptp_server"),_("PPTP Server"),40)
	entry({"admin","network","vpn","pptp_server","edit"},cbi("admin_network/pptp_server_edit"),nil,10).leaf = true
	entry({"admin","network","vpn","pptp_client"},cbi("admin_network/pptp_client_edit"),_("PPTP Client"),50)
	
	entry({"admin","network","vpn","gre"},call("action_gre"),_("GRE"),60)
	entry({"admin","network","vpn","gre","edit"},cbi("admin_network/gre_edit"),nil,10).leaf = true

	entry({"admin","network","vpn","autovpn"},call("autovpn"),_("Auto VPN"),70)
		
	--# Route Table
	entry({"admin","network","route"},alias("admin","network","route","static"),_("Route Table"),7)
	entry({"admin","network","route","static"},call("action_route_static"),_("Static Route"),10)
	entry({"admin","network","route","static","edit"},cbi("admin_network/static_route_edit"),nil,10).leaf = true
	entry({"admin","network","route","policy"},call("action_route_strategy"),_("Policy Route"),20)
	entry({"admin","network","route","policy","edit"},cbi("admin_network/policy_route_edit"),nil,20).leaf = true

	--# DMZ/Port Mapping
	entry({"admin","network","dmz_port"},alias("admin","network","dmz_port","port_map"),_("DMZ/Port Mapping"),8)
	entry({"admin","network","dmz_port","port_map"},call("port_map"),_("Port Mapping"),10)
	entry({"admin","network","dmz_port","port_map","edit"},cbi("admin_network/port_map_edit"),nil,10).leaf = true
	entry({"admin", "network","dmz_port", "dmz"}, cbi("admin_network/dmz"), _("DMZ Setting"), 20)

	--# QoS
	entry({"admin","network","qos"},call("action_qos"),_("QoS"),9)
	entry({"admin","network","qos","edit"},cbi("admin_network/qos_edit"),nil,10).leaf = true
		
	--# UPnP
	--entry({"admin","network","upnp"},call("action_upnp"),_("UPnP"),10)

	--# DDNS
	entry({"admin","network","ddns"},cbi("admin_network/ddns_config"), _("DDNS"), 11)

	--# NAT
	entry({"admin","network","nat"},alias("admin","network","nat","rule"),_("NAT"),12)
	entry({"admin","network","nat","rule"},call("action_nat"), _("NAT Rule"),10)
	entry({"admin","network","nat","rule","edit"},cbi("admin_network/nat_edit"),nil,10).leaf = true
		--entry({"admin", "network", "nat","alg"}, cbi("admin_network/alg_edit"), _("ALG Config"),20)
	entry({"admin","network","alg"},cbi("admin_network/alg_edit"),_("ALG"),13)
	--# Net U-disk
	entry({"admin","network","udisk"},call("action_udisk"),_("Net U-Disk"),14)
	
	--# diagnostics
	entry({"admin", "network", "diagnostics"},call("action_tcpdump"), _("Diagnostics"), 15)
	entry({"admin", "network", "diag_ping"}, call("diag_ping"), nil)
	entry({"admin", "network", "diag_nslookup"}, call("diag_nslookup"), nil)
	entry({"admin", "network", "diag_traceroute"}, call("diag_traceroute"), nil)
end
function change_interface_view(param)
	local ret_str = ""
	local i18n = require "luci.i18n"
	
	if not param then
		ret_str = i18n.translate("NONE")
	elseif param == "lan" or param == "wan" then
		ret_str = string.upper(param)
	elseif param:match("^vwan") then
		--@ vwan
		local uci = require "luci.model.uci".cursor()
		local tmp_cfg = uci:get_all("network") or {}
		
		for k,v in pairs(tmp_cfg) do
			if v['.type'] == "interface" and k == param then
				ret_str = v.name or ""
				break
			end				
		end
	elseif param == "ppp1723" then
		ret_str = "PPTP"
	elseif param == "ppp1701" then
		ret_str = "L2TP"
	else
		--@ vlan
		ret_str = param
	end

	return ret_str
end
	
function action_wan_subinterface()
	local uci = require "luci.model.uci".cursor()
	local ds = require "luci.dispatcher"
	local i18n = require "luci.i18n"
	local MAX_EXTENSION = tonumber(uci:get("profile_param","global","max_vwan") or '8')
	
	function get_available_section_name()
		local interface_name = "vwan"

		for i=1,MAX_EXTENSION do
			if (not uci:get_all("network","vwan"..i)) or (not uci:get("network","vwan"..i,"index")) then
				return interface_name..i
			end
		end
	end

	local del_target = luci.http.formvaluetable("Delete")
	if del_target then
		--@ delete 'switch_vlan' section and 'interface' vlan and rule
		for k,v in pairs(del_target) do
			local cfg,section = k:match("([a-z0-9A-Z_]+)%.(%w+).x")
			if cfg and section then
				local del_interface_section
				local del_switch_vlan_section
				local del_rule_section
				local profile_network = uci:get_all("network") or {}
				local tmp_lookup = 10 + tonumber(section:match("([0-9]+)"))
				
				for k,v in pairs(profile_network) do
					if v['.type'] == "switch_vlan" and v.wan_sub_link == section then
						del_switch_vlan_section = k
					end
					if v['.type'] == "interface" and v.wan_sub_link == section then
						del_interface_section = k
					end
					if v['.type'] == "rule" and v.lookup and tonumber(v.lookup) == tmp_lookup then
						del_rule_section = k
					end
				end
				
				if del_switch_vlan_section then
					uci:delete("network",del_switch_vlan_section)
				end
				if del_interface_section then
					uci:delete("network",del_interface_section)
				end
				if del_rule_section then
					uci:delete("network",del_rule_section)
				end
			end
		end
		--@ delete this section
		uci:delete_section(del_target)		
	end

	if luci.http.formvalue("New") then
		local created = uci:section("network","interface",get_available_section_name())
		uci:save("network")
		luci.http.redirect(ds.build_url("admin","network","wan","wan_subinterface_config","edit",created,"add"))
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

	local th = {"Index","Name","Network Mode","Protocol","Gateway","DNS","VLANID","Binding Ports"}
	local colgroup = {"5%","13%","10%","7%","15%","20%","7%","13%","10%"}
	local content = {}
	local edit = {}
	local delchk = {}
	local uci_cfg = {}
	local more_info = {}
	--local status = {}
	local addnewable = true
	local cnt = 0

	local tmp_cfg = uci:get_all("network") or {}
	
	for i=1,MAX_EXTENSION do
		for k,v in pairs(tmp_cfg) do
			if v.index and v.name and v['.type'] == "interface" and k:match("^vwan") then
				if i == tonumber(v.index) then
					cnt = cnt + 1
					local tmp = {}
					tmp[1] = v.index
					tmp[2] = v.name
					tmp[3] = i18n.translate(v.type and "Bridge" or "route")
					tmp[4] = string.upper(v.proto or "")
					tmp[5] = v.gateway or ""
					tmp[6] = v.peerdns == "1" and "AUTO" or table.concat(v.dns or {}," / ")
					
					tmp[7] = v.vlanid or ""
					tmp[8] = v.bindinglan or ""
					--tmp[9] = i18n.translate(v.disabled == "0" and "Enabled" or "Disabled")
					more_info[cnt] = ""
					if v.tmp_vlanipaddr then
						more_info[cnt] = more_info[cnt] .. i18n.translate("LAN Side") .. "<br>"
						more_info[cnt] = more_info[cnt] .. "&nbsp;&nbsp;&nbsp;&nbsp;" .. i18n.translate("VLAN IP Address")..": "..v.tmp_vlanipaddr .. "<br>"
					end
					if v.vlan_sub_link then
						more_info[cnt] = more_info[cnt] .. "&nbsp;&nbsp;&nbsp;&nbsp;" .. i18n.translate("VLAN Netmask")..": "..uci:get("network."..v.vlan_sub_link..".netmask") .. "<br>"
					end
					more_info[cnt] = more_info[cnt] .. i18n.translate("WAN Side") .. "<br>"
					if v.metric then
						more_info[cnt] = more_info[cnt] .. "&nbsp;&nbsp;&nbsp;&nbsp;" .. i18n.translate("Metric")..": "..v.metric .. "<br>"
					end
					if v.ipaddr then
						more_info[cnt] = more_info[cnt] .. "&nbsp;&nbsp;&nbsp;&nbsp;" .. i18n.translate("IP Address")..": "..v.ipaddr .. "<br>"
					end
					if v.netmask then
						more_info[cnt] = more_info[cnt] .. "&nbsp;&nbsp;&nbsp;&nbsp;" .. i18n.translate("Netmask")..": "..v.netmask .. "<br>"
					end
					if v.username then
						more_info[cnt] = more_info[cnt] .. "&nbsp;&nbsp;&nbsp;&nbsp;" .. i18n.translate("Username")..": "..v.username .. "<br>"
					end
					if v.service then
						more_info[cnt] = more_info[cnt] .. "&nbsp;&nbsp;&nbsp;&nbsp;" .. i18n.translate("Server Name")..": "..v.service .. "<br>"
					end
					if v.mtu then
						more_info[cnt] = more_info[cnt] .. "&nbsp;&nbsp;&nbsp;&nbsp;" .. i18n.translate("MTU")..": "..v.mtu .. "<br>"
					end
					
					edit[cnt] = ds.build_url("admin","network","wan","wan_subinterface_config","edit",k,"edit")
					uci_cfg[cnt] = "network." .. k
					--status[cnt] = v.disabled == "0" and "Enabled" or "Disabled"
					delchk[cnt] = uci:check_cfg_deps("network",k,"sip_profile")
					table.insert(content,tmp)
	 			end
	 		end
	 	end
	 end
	if MAX_EXTENSION == cnt then
		addnewable = false
	end
	luci.template.render("cbi/configlist",{
		colgroup = colgroup,
		th = th,
		content = content,
		more_info = more_info,
		edit = edit,
		delchk = delchk,
		uci_cfg = uci_cfg,
		--status = status,
		addnewable = addnewable,
		})
end

function firmware_verify(srcfilename)
	require("dpr")
	local hdr = dpr.getldhdr(srcfilename)
	local model = dpr.getproduct()
	if hdr and ("gnu_jffs" == hdr.type or "gnu_uImage" == hdr.type or "gnu_rootfs" == hdr.type) and hdr.product == model then
		return true
	else
		return false
	end
end

function firmware_upgrade(file)
	require "dpr"
	require "ini"
	local util = require "luci.util"
	local dstfile = "/tmp/jffs2_fs.tar.gz"
	local http_str = "curl -G --interface eth1.2012 -k --connect-timeout 20 http://10.251.251.1/cgi-bin/main.cgi?cmd_id=21 -d action=1"
	local ret = true
	local err
	local upgrade_type
	local hdr = dpr.getldhdr(file)

	if hdr and hdr.type then
		upgrade_type = hdr.type
	end
	
	if upgrade_type then
		if upgrade_type == "gnu_jffs" then
			dstfile = "/tmp/".."jffs2_fs.tar.gz"
			http_str = http_str.." -d update_type=0"
		elseif upgrade_type == "gnu_uImage" then
			dstfile = "/tmp/".."uImage"
			http_str = http_str.." -d update_type=1"
		elseif upgrade_type == "gnu_rootfs" then
			dstfile = "/tmp/".."rootfs.squashfs"
			http_str = http_str.." -d update_type=2"
		end
	else
		return false,"Upgrade type Error!"
	end
	
	hdr = dpr.unpackld(file, dstfile)
	if nil == hdr then
		return false,"Unpack ld file failed!"
	end

	--@ call Post file API
	local ret_cmd = util.exec("curl -G --interface eth1.2012 -k --connect-timeout 20 --form upload=@"..dstfile.." http://10.251.251.1/cgi-bin/main.cgi")
	if ret_cmd and ret_cmd:match("^0") then
		--@ call upgrade API 
		ret_cmd = util.exec(http_str)
		if ret_cmd and ret_cmd:match("^0") then
			--@ success
			ret = true
		else
			ret = false
			err = "Call upgrade API failed!"
		end
	else
		ret = false
		err = "Call post file API failed!"
	end
	
	return ret,err
end

function action_gpon()
	local fs_server = require "luci.scripts.fs_server"
	local util = require "luci.util"
	local fs = require "luci.fs"
	local destfile = "/tmp/"
	local upgrade_err
	
	local fp
	luci.http.setfilehandler(
		function(meta, chunk, eof)
			if not fp then
				if meta and meta.file then
					destfile = destfile..meta.file
					fp = io.open(destfile,"w")
				end
			end
			if chunk then
				fp:write(chunk)
			end
			if eof and fp then
				fp:close()
				fp = nil

				--@ check ld file
				if firmware_verify(destfile) then
					local ret,err = firmware_upgrade(destfile)
					if err then
						upgrade_err = err
					end
				else
					upgrade_err = "not acception,Please check upgrade file!"
				end

				--@ del
				util.exec("rm "..destfile)
			end
		end
	)
	
	if luci.http.formvalue("register") then
		--@ Register
		local ponPassword = luci.http.formvalue("pon_passwd")
		local loid = luci.http.formvalue("loid")
		local loidPassword = luci.http.formvalue("loid_passwd")

		if ponPassword and loid and loidPassword then
			--@ special interface for gpon 
			local ret_str = util.exec("curl -G --interface eth1.2012 -k --connect-timeout 5 http://10.251.251.1/cgi-bin/main.cgi?cmd_id=5 -d action=1 -d ponPassword="..ponPassword.." -d gpon_loid="..loid.." -d gpon_password="..loidPassword)

		end
		
		luci.template.render("admin_network/wan_gpon")
	elseif luci.http.formvalue("upgrade") then
		--@ upgrade 
		local result = "Success"
		
		if upgrade_err then
			result = "failed,"..upgrade_err
		end
		
		luci.template.render("admin_network/wan_gpon",{result=result})
	elseif luci.http.formvalue("status") then
		local ret_info = {}
		ret_info = fs_server.get_gpon_onu_status()
		
		luci.http.prepare_content("application/json")
		luci.http.write_json(ret_info)
	else
		luci.template.render("admin_network/wan_gpon")
	end
end

function action_wps()
	local util = require "luci.util"
	local action_type = luci.http.formvalue("action_type")
	local pin_code = luci.http.formvalue("pin_code")

	if not luci.http.formvalue("status") then
		if action_type == "pin" then
			--@ pin code set wps
			luci.util.exec("iwpriv ra0 set WscPinCode="..pin_code)
			luci.util.exec("iwpriv ra0 set WscMode=1")
			luci.util.exec("iwpriv ra0 set WscGetConf=1")
		else
			--@ pbc set wps
			luci.util.exec("iwpriv ra0 set WscMode=2")
			luci.util.exec("iwpriv ra0 set WscGetConf=1")
		end
		luci.util.exec("iwpriv ra0 show WscPeerList && dmesg -c")		
	end
	
	local ret_status = luci.util.exec("iwpriv ra0 show WscPeerList && dmesg -c"):match("ra0%s*WscStatus:%s*([0-9]+)")
	
	luci.http.prepare_content("application/json")
	luci.http.write_json({ status = ret_status})
end

function action_wlan()
	local MAX_EXTENSION = 4
	local uci = require "luci.model.uci".cursor()
	local ds = require "luci.dispatcher"
	local i18n = require "luci.i18n"

	uci:check_cfg("wireless")

	local g_channel = uci:get("wireless","ra0","channel")
	local g_bandwidth = uci:get("wireless","ra0","htmode")
	local g_hwmode = uci:get("wireless","ra0","hwmode") or "11bgn"
	local g_txpower = uci:get("wireless","ra0","txpower") or "100"
	local g_isolate = uci:get("wireless","ra0","isolate")
	local g_disabled = uci:get("wireless","ra0","disabled") or "0"
	local g_wps = uci:get("wireless","ra0","wps") or "off"
	
	--@ service save
	if luci.http.formvalue("save") then
		g_channel = luci.http.formvalue("channel")
		g_bandwidth = luci.http.formvalue("bandwidth")
		g_hwmode = luci.http.formvalue("hwmode") 
		g_txpower = luci.http.formvalue("txpower")
		g_isolate = luci.http.formvalue("isolate")
		g_disabled = luci.http.formvalue("disabled")
		g_wps = luci.http.formvalue("wps")
		
		uci:set("wireless","ra0","channel",g_channel)
		uci:set("wireless","ra0","htmode",g_bandwidth)
		uci:set("wireless","ra0","hwmode",g_hwmode)
		uci:set("wireless","ra0","txpower",g_txpower)
		uci:set("wireless","ra0","isolate",g_isolate)
		uci:set("wireless","ra0","wps",g_wps)

		local tmp_cfg = uci:get_all("wireless") or {}
		for k,v in pairs(tmp_cfg) do
			if v['.type'] == "wifi-device" then
				uci:set("wireless",k,"disabled",g_disabled)
			end
		end
		
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

	local th = {"Index","SSID","Encryption","Interface","Isolation","WMM","Status"}
	local colgroup = {"5%","25%","15%","15%","10%","10%","10%","10%"}
	local content = {}
	local edit = {}
	local delchk = {}
	local uci_cfg = {}
	local status = {}
	local addnewable = true
	local cnt = 0

	local tmp_cfg = uci:get_all("wireless") or {}
	
	for i=1,MAX_EXTENSION do
		for k,v in pairs(tmp_cfg) do
			if v.index and v['.type'] == "wifi-iface" and v.ssid then
				if i == tonumber(v.index) then
					cnt = cnt + 1
					local tmp = {}
					tmp[1] = v.index
					tmp[2] = v.ssid
					tmp[3] = v.encryption == "none" and i18n.translate("NONE") or (v.encryption == "psk" and "WPA+PSK" or "WPA2+PSK")
					tmp[4] = v.network == "lan" and "LAN" or v.network
					tmp[5] = i18n.translate(v.isolate == "0" and "Disabled" or "Enabled")
					tmp[6] = i18n.translate(v.wmm == "0" and "Off" or "On")
					tmp[7] = i18n.translate(v.disabled == "1" and "Disabled" or "Enabled")
					
					edit[cnt] = ds.build_url("admin","network","wlan","wlan_config","edit",k,"edit")
					uci_cfg[cnt] = "wireless." .. k
					if cnt ~= 1 then
						delchk[cnt] = ""
					end
					status[cnt] = v.disabled == "1" and "Disabled" or "Enabled"
					table.insert(content,tmp)
	 			end
	 		elseif v['.type'] == "wifi-iface" and not v.index then
	 			--uci:delete("wireless",k)
	 			--uci:save("wireless")
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
function action_wds()
	local MAX_EXTENSION = 4
	local uci = require "luci.model.uci".cursor()
	local ds = require "luci.dispatcher"
	local i18n = require "luci.i18n"
	local fs_server = require "luci.scripts.fs_server"
	
	uci:check_cfg("wireless")

	local g_wds_mode = uci:get("wireless","ra0","wdsmode") or "disable"
	local g_server_ssid = uci:get("wireless","wifi0","ssid")
	local g_server_network = string.upper(uci:get("wireless","wifi0","network") or "")
	
	--@ service 
	if luci.http.formvalue("save") then
		g_wds_mode = luci.http.formvalue("wdsmode")
		uci:set("wireless","ra0","wdsmode",g_wds_mode)
		uci:save("wireless")
	end
	
	local del_target = luci.http.formvaluetable("Delete")
	if del_target then
		uci:delete_section(del_target)
	end

	if luci.http.formvalue("New") then
		local created = uci:section("wireless","wifi-iface")
		uci:save("wireless")
		luci.http.redirect(ds.build_url("admin","network","wlan","wds_config","edit",created,"add"))
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

	local th = {"Index","SSID","Encryption","Physical Mode","Status"}
	local colgroup = {"5%","30%","15%","25%","15%","10%"}
	local content = {}
	local edit = {}
	local delchk = {}
	local uci_cfg = {}
	local status = {}
	local addnewable = true
	local cnt = 0

	local tmp_cfg = uci:get_all("wireless") or {}
	local wifi_list = fs_server.get_wifi_list()
	
	function change_encryption_view(param)
		local ret_str = ""

		if param == "aes" then
			ret_str = "AES"
		elseif param == "psk" then
			ret_str = "WPA+PSK"
		elseif param == "psk2" then
			ret_str = "WPA2+PSK"
		elseif param == "none" then
			ret_str = i18n.translate("NONE")
		end
		
		return ret_str
	end

	function change_view(param)
		local ret_str = param
		
		for k,v in pairs(wifi_list) do
			if v.bssid == param then
				ret_str = v.ssid
				break
			end
		end

		return ret_str
	end
	
	for i=1,MAX_EXTENSION do
		for k,v in pairs(tmp_cfg) do
			if v.index and v['.type'] == "wifi-iface" and v.wdsphymode then
				if i == tonumber(v.index) then
					cnt = cnt + 1
					local tmp = {}
					tmp[1] = v.index
					tmp[2] = g_wds_mode == "lazy" and "" or (change_view(v.wdspeermac or ""))
					tmp[3] = change_encryption_view(v.wdsencryptype or "")
					tmp[4] = v.wdsphymode or ""
					tmp[5] = i18n.translate(v.disabled == "1" and "Disabled" or "Enabled")
					
					edit[cnt] = ds.build_url("admin","network","wlan","wds_config","edit",k,"edit")
					uci_cfg[cnt] = "wireless." .. k
					status[cnt] = v.disabled == "1" and "Disabled" or "Enabled"
					table.insert(content,tmp)
	 			end
	 		end
	 	end
	 end
	if MAX_EXTENSION == cnt or g_wds_mode == "disable" then
		addnewable = false
	end
	luci.template.render("admin_network/wds",{
		colgroup = colgroup,
		th = th,
		content = content,
		edit = edit,
		delchk = delchk,
		uci_cfg = uci_cfg,
		status = status,
		wds_mode = g_wds_mode,
		server_ssid = g_server_ssid,
		server_network = g_server_network,
		addnewable = addnewable,
		})
end
function action_vlan()
	local uci = require "luci.model.uci".cursor()
	local ds = require "luci.dispatcher"
	local i18n = require "luci.i18n"
	local MAX_EXTENSION = tonumber(uci:get("profile_param","global","max_vlan") or '15')
	
	function get_available_section_name()
		local interface_name = "vlan"

		for i=0,MAX_EXTENSION do
			if (not uci:get_all("network","vlan"..i)) or (not uci:get("network","vlan"..i,"name")) then
				return interface_name..i
			end
		end
	end
	
	local del_target = luci.http.formvaluetable("Delete")
	if del_target then
		--@ first delete switch_vlan section
		for k,v in pairs(del_target) do
			local cfg,section = k:match("([a-z0-9A-Z_]+)%.(%w+).x")
			if cfg and section then
				local tmp_index = uci:get(cfg,section,"switch_vlan_id") --get the id
				local del_section
				local profile_network = uci:get_all("network") or {}
				
				for k,v in pairs(profile_network) do
					--@ option vlan : is the index of this section,and link to switch_vlan_id
					if v['.type'] == "switch_vlan" and v.vlan == tmp_index then
						del_section = k
						break
					end
				end
				
				if del_section then
					uci:delete("network",del_section)
				end
			end
		end
		--@ delete this section
		uci:delete_section(del_target)
	end

	if luci.http.formvalue("New") then
		local created = uci:section("network","interface",get_available_section_name())
		uci:save("network")
		luci.http.redirect(ds.build_url("admin","network","vlan","vlan_config","edit",created,"add"))
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

	local th = {"Name","IP Address","Netmask","Ports","VLANID","Binding WAN"}
	local colgroup = {"10%","20%","20%","20%","10%","10","10%"}
	local content = {}
	local edit = {}
	local delchk = {}
	local uci_cfg = {}
	--local status = {}
	local addnewable = true
	local cnt = 0

	local tmp_cfg = uci:get_all("network") or {}
	
	for i=0,MAX_EXTENSION do
		for k,v in pairs(tmp_cfg) do
			if v.name and v['.type'] == "interface" and k:match("^vlan") then
				if i == tonumber(k:match("([0-9]+)")) then
					cnt = cnt + 1
					local tmp = {}
					tmp[1] = v.name or ""
					tmp[2] = v.ipaddr or ""
					tmp[3] = v.netmask or ""
					tmp[4] = v.bindport or ""
					tmp[5] = v.vlanid or ""
					tmp[6] = v.wan_sub_link and (uci:get("network",v.wan_sub_link,"name") or "") or i18n.translate("NONE")
					--tmp[7] = i18n.translate(v.disabled == "0" and "Enabled" or "Disabled")

					if not v.wan_sub_link then
						edit[cnt] = ds.build_url("admin","network","vlan","vlan_config","edit",k,"edit")
					end
					
					uci_cfg[cnt] = "network." .. k
					delchk[cnt] = uci:check_cfg_deps("network",k,"dhcp.wireless")
					if v.wan_sub_link then
						--status[cnt] = ""
					else
						--status[cnt] = v.disabled == "0" and "Enabled" or "Disabled"
					end
					
					table.insert(content,tmp)
	 			end
	 		elseif v['.type'] == "interface" and k:match("^vlan") and not v.name then
	 			--uci:delete("network",k)
	 			--uci:save("network")
	 		end
	 	end
	 end
	if MAX_EXTENSION == cnt then
		addnewable = false
	end
	luci.template.render("cbi/configlist",{
		colgroup = colgroup,
		th = th,
		content = content,
		edit = edit,
		delchk = delchk,
		uci_cfg = uci_cfg,
		--status = status,
		addnewable = addnewable,
		})
end
function action_port()
	local uci = require "luci.model.uci".cursor()

	--@ save
	if luci.http.formvalue("save") then
		local port_value_tb = luci.http.formvaluetable("port") or {}

		for k,v in pairs(port_value_tb) do
			if k and v then			
				local section,option = k:match("^([a-zA-Z0-9]+)\.([a-zA-Z0-9]+)$")
				if section and option then	
					uci:set("network",section,option,v)
				end
			end
		end

		--@save
		uci:save("network")
	end
	
	luci.template.render("admin_network/port")
end

function number2ip(param)
	local ret_ip = ""
	local tmp_a = param
	local tmp_b = param
	local index = 0
	
	repeat
		index = index + 1
		tmp_a = tmp_b % 256
		tmp_b = math.floor(tmp_b / 256)
		if index == 1 then
			ret_ip = tmp_a
		else
			ret_ip = tmp_a.."."..ret_ip
		end
	until (tmp_b < 256)

	if index == 1 then
		ret_ip = "0.0."..tmp_b.."."..ret_ip
	elseif index == 2 then
		ret_ip = "0."..tmp_b.."."..ret_ip
	elseif index == 3 then
		ret_ip = tmp_b.."."..ret_ip
	end

	return ret_ip
end
function ipaddip(param1,param2)
	local ret_ip = ""
	local util = require "luci.util"
	
	if param1 and param2 then
		local param_tb1 = util.split(param1,".")
		local param_tb2 = util.split(param2,".")
		local num_add = 0

		for i=4,1,-1 do
			if i == 4 then
				ret_ip = (tonumber(param_tb1[i]) + tonumber(param_tb2[i]) + num_add) % 256
			else
				ret_ip = ((tonumber(param_tb1[i]) + tonumber(param_tb2[i]) + num_add) % 256).."."..ret_ip
			end
			num_add = math.floor((tonumber(param_tb1[i]) + tonumber(param_tb2[i]) + num_add) / 256)
		end
	end
	
	return ret_ip
end

function action_dhcp_server()
	local uci = require "luci.model.uci".cursor()
	local ds = require "luci.dispatcher"
	local i18n = require "luci.i18n"
	local util = require "luci.util"
	local MAX_EXTENSION = tonumber(uci:get("profile_param","global","max_default") or '16')
	
	uci:check_cfg("dhcp")

	local del_target = luci.http.formvaluetable("Delete")
	if del_target then
		uci:delete_section(del_target)
	end

	if luci.http.formvalue("New") then
		local created = uci:section("dhcp","dhcp")
		uci:save("dhcp")
		luci.http.redirect(ds.build_url("admin","network","dhcp","server","edit",created,"add"))
		return
	end
	
	--@ Enable/Disable
	local status_target = luci.http.formvaluetable("Status")
	if status_target and "table" == type(status_target) then
		for k,v in pairs(status_target) do
			local state,cfg,section = k:match("([A-Za-z]+)%.([a-zA-Z_]+)%.(%w+).x")
			if cfg and section and state then
				uci:set(cfg,section,"ignore",state == "Enabled" and "0" or "1")
				uci:save(cfg)
			end
		end
	end
	
	local th = {"Index","Interface","Address Pool","Gateway","DNS","Leasetime(Hour)","Status"}
	local colgroup = {"6%","6%","25%","15%","19%","10%","9%","10%"}
	local content = {}
	local edit = {}
	local delchk = {}
	local uci_cfg = {}
	local status = {}
	local addnewable = true
	local cnt = 0

	local profile = uci:get_all("dhcp") or {}
	local network_profile = uci:get_all("network") or {}
	local dhcp_ip_pool = {}
	
	for k,v in pairs(network_profile) do
		if v['.type'] == "interface" and (k:match("^vlan") or k == "lan") and v.ipaddr and v.netmask then
			local tmp_ip = util.split(v.ipaddr,".")
			local tmp_netmask = util.split(v.netmask,".")
			dhcp_ip_pool[k] = bit.band(tmp_ip[1],tmp_netmask[1]).."."..bit.band(tmp_ip[2],tmp_netmask[2]).."."..bit.band(tmp_ip[3],tmp_netmask[3]).."."..bit.band(tmp_ip[4],tmp_netmask[4])
		end
	end

	for i=1,MAX_EXTENSION do
		for k,v in pairs(profile) do
			if v['.type'] == "dhcp" and v.index and i == tonumber(v.index) then
				cnt = cnt + 1
				local tmp = {}
				tmp[1] = v.index
				tmp[2] = v.interface == "lan" and "LAN" or (v.interface or "")

				if v.start and v.limit and dhcp_ip_pool[v.interface] then
					tmp[3] = ipaddip(dhcp_ip_pool[v.interface],number2ip(tonumber(v.start))).." ~ "..ipaddip(dhcp_ip_pool[v.interface],number2ip(tonumber(v.start)+tonumber(v.limit)-1))
				else
					tmp[3] = ""
				end
				
				if v.dhcp_option then
					for k,v in pairs(v.dhcp_option) do
						if v:match("^3,") then
							tmp[4] = v:match("^3,([0-9%.]+)")
						end
						if v:match("^6,") then
							tmp[5] = v:match("^6,([0-9%.,]+)")
						end
					end
				end
				
				tmp[4] = tmp[4] or ""
				tmp[5] = tmp[5] or ""
				tmp[6] = v.leasetime and v.leasetime:match("([0-9]+)") or ""
				tmp[7] = i18n.translate(v.ignore == "0" and "Enabled" or "Disabled")
				
				edit[cnt] = ds.build_url("admin","network","dhcp","server","edit",k,"edit")
				uci_cfg[cnt] = "dhcp." .. k
				status[cnt] = v.ignore == "0" and "Enabled" or "Disabled"
				table.insert(content,tmp)
				break
	 		elseif v['.type'] == "dhcp" and not v.index then
	 			--uci:delete("dhcp",k)
	 			--uci:save("dhcp")
	 		end
	 	end
	end

	local full_flag = true
	
	for k,v in pairs(network_profile) do
		if k == "lan" or (v['.type'] == "interface" and k:match("^vlan([0-9]+)") and v.ipaddr) then
			local tmp_flag = true
			
			for k2,v2 in pairs(profile) do
				if v2['.type'] == "dhcp" and v2.interface == k then
					tmp_flag = false
					break
				end
			end
			if tmp_flag then
				full_flag = false
				break
			end
		end
	end
	
	if MAX_EXTENSION == cnt or full_flag then
		addnewable = false
	end
	luci.template.render("cbi/configlist",{
		colgroup = colgroup,
		th = th,
		content = content,
		edit = edit,
		delchk = delchk,
		uci_cfg = uci_cfg,
		status = status,
		addnewable = addnewable,
		})
end

function action_ipsec()
	local uci = require "luci.model.uci".cursor()
	local ds = require "luci.dispatcher"
	local i18n = require "luci.i18n"

	uci:check_cfg("ipsec")

	local del_target = luci.http.formvaluetable("Delete")
	if del_target then
		uci:delete_section(del_target)
	end

	if luci.http.formvalue("New") then
		local created = uci:section("ipsec","net2net")
		uci:save("ipsec")
		luci.http.redirect(ds.build_url("admin","network","vpn","ipsec","edit",created,"add","net2net"))
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
	
	luci.template.render("admin_network/vpn_ipsec")
end
function action_l2tp_server()
	local uci = require "luci.model.uci".cursor()
	local ds = require "luci.dispatcher"
	local i18n = require "luci.i18n"
	local MAX_EXTENSION = tonumber(uci:get("profile_param","global","max_vpn_l2tp") or '32')
	
	uci:check_cfg("xl2tpd")
	uci:check_cfg("ipsec")
	
	local l2tp_profile = uci:get_all("xl2tpd") or {}
	local ipsec_profile = uci:get_all("ipsec") or {}
	local l2tpd_section
	local ipsec_section
	local g_enabled = "0"
	--local g_locals = ""
	local g_start_ip = ""
	local g_stop_ip = ""
	--local g_ipsec_locals = ""
	local g_ipsec_password = ""
	local g_ipsec_disabled = "0"
	
	for k,v in pairs(l2tp_profile) do
		if v['.type'] == "l2tpd" then
			l2tpd_section = k 
			g_enabled = v.enabled or "0"
			--g_locals = v.locals or ""
			g_start_ip = v.start_ip or ""
			g_stop_ip = v.locals or ""
			break
		end
	end

	for k,v in pairs(ipsec_profile) do
		if v['.type'] == "l2tp" then
			ipsec_section = k
			--g_ipsec_locals = v.interface or ""
			g_ipsec_password = v.password or ""
			g_ipsec_disabled = v.enabled or "0"
			break
		end
	end
	
	--@ service 
	if luci.http.formvalue("save") then
		g_enabled = luci.http.formvalue("enabled")
		g_start_ip = luci.http.formvalue("start_ip")
		g_stop_ip = luci.http.formvalue("stop_ip")
		--g_ipsec_locals = luci.http.formvalue("interface")
		g_ipsec_password = luci.http.formvalue("ipsec_password")
		g_ipsec_disabled = luci.http.formvalue("ipsec_disabled")
		
		if l2tpd_section then
			uci:set("xl2tpd",l2tpd_section,"enabled",g_enabled)
			if g_start_ip then
				uci:set("xl2tpd",l2tpd_section,"start_ip",g_start_ip)
			end
			if g_stop_ip then
				local prefix_str = g_stop_ip:match("^([0-9%.]+)%.[0-9]+$")
				local subfix_str = g_stop_ip:match("^[0-9]+%.[0-9]+%.[0-9]+%.([0-9]+)$")

				if prefix_str and subfix_str then
					uci:set("xl2tpd",l2tpd_section,"stop_ip",prefix_str.."."..tostring(tonumber(subfix_str)-1))
				end
				--uci:set("xl2tpd",l2tpd_section,"stop_ip",tostring(g_stop_ip:match("^([0-9%.]+)%.[0-9]+$")).."."..tostring(tonumber(g_stop_ip:match("^[0-9]+%.[0-9]+%.[0-9]+%.([0-9]+)$"))-1))
				uci:set("xl2tpd",l2tpd_section,"locals",g_stop_ip)
			end

			uci:set("qos","qos_l2tp1","enabled",(uci:get("xl2tpd","main","enabled") == "1" or g_enabled == "1" ) and "1" or "0")
			uci:set("qos","qos_l2tp2","enabled",(uci:get("xl2tpd","main","enabled") == "1" or g_enabled == "1" ) and "1" or "0")

			uci:save("qos")
			uci:save("xl2tpd")
		end
		
		if ipsec_section then
			uci:set("ipsec",ipsec_section,"enabled",g_ipsec_disabled)
			if g_ipsec_disabled == "1" then
				--if g_ipsec_locals then
					--uci:set("ipsec",ipsec_section,"interface",g_ipsec_locals)
				--end
				if g_ipsec_password then
					uci:set("ipsec",ipsec_section,"password",g_ipsec_password)
				end
			end
			
			uci:save("ipsec")
		end
	end
	
	local del_target = luci.http.formvaluetable("Delete")
	if del_target then
		uci:delete_section(del_target)
	end

	if luci.http.formvalue("New") then
		local created = uci:section("xl2tpd","user")
		uci:save("xl2tpd")
		luci.http.redirect(ds.build_url("admin","network","vpn","l2tp_server","edit",created,"add"))
		return
	end
	
	--@ Enable/Disable
	local status_target = luci.http.formvaluetable("Status")
	if status_target and "table" == type(status_target) then
		for k,v in pairs(status_target) do
			local state,cfg,section = k:match("([A-Za-z]+)%.([a-zA-Z0-9_]+)%.(%w+).x")
			if cfg and section and state then
				uci:set(cfg,section,"enabled",state == "Enabled" and "1" or "0")
				uci:save(cfg)
			end
		end
	end

	local th = {"Index","Username","Description","Status"}
	local colgroup = {"6%","20%","57%","7%","10%"}
	local content = {}
	local edit = {}
	local delchk = {}
	local uci_cfg = {}
	local status = {}
	local addnewable = true
	local cnt = 0

	local tmp_cfg = uci:get_all("xl2tpd") or {}
	
	for i=1,MAX_EXTENSION do
		for k,v in pairs(tmp_cfg) do
			if v.index and v['.type'] == "user" then
				if i == tonumber(v.index) then
					cnt = cnt + 1
					local tmp = {}
					tmp[1] = v.index
					tmp[2] = v.username or ""
					tmp[3] = v.description or ""
					tmp[4] = i18n.translate(v.enabled == "1" and "Enabled" or "Disabled")
					
					edit[cnt] = ds.build_url("admin","network","vpn","l2tp_server","edit",k,"edit")
					uci_cfg[cnt] = "xl2tpd." .. k
					status[cnt] = v.enabled == "1" and "Enabled" or "Disabled"
					table.insert(content,tmp)
	 			end
	 		elseif v['.type'] == "user" and not v.index then
	 			--uci:delete("xl2tpd",k)
	 			--uci:save("xl2tpd")
	 		end
	 	end
	 end
	if MAX_EXTENSION == cnt then
		addnewable = false
	end
	luci.template.render("admin_network/vpn_l2tp",{
		colgroup = colgroup,
		th = th,
		content = content,
		edit = edit,
		delchk = delchk,
		uci_cfg = uci_cfg,
		status = status,
		enabled = g_enabled,
		start_ip = g_start_ip,
		stop_ip = g_stop_ip,
		--ipsec_locals = g_ipsec_locals,
		ipsec_password = g_ipsec_password,
		ipsec_disabled = g_ipsec_disabled,
		addnewable = addnewable,
		})
end

function action_pptp_server()
	local uci = require "luci.model.uci".cursor()
	local ds = require "luci.dispatcher"
	local i18n = require "luci.i18n"
	local util = require "luci.util"
	local MAX_EXTENSION = tonumber(uci:get("profile_param","global","max_vpn_pptp") or '32')
	
	uci:check_cfg("pptpd")

	local g_enabled = uci:get("pptpd","pptpd","enabled") or ""
	local g_mppe = uci:get("pptpd","pptpd","mppe") or "1"
	local g_localip = uci:get("pptpd","pptpd","localip") or ""
	local g_remoteip = uci:get("pptpd","pptpd","remoteip") or ""
	local start_ip = ""
	local end_ip = ""

	local tmp_1,tmp_2,tmp_3,tmp_4,tmp_5 = g_remoteip:match("^([0-9]+)%.([0-9]+)%.([0-9]+)%.([0-9]+)%-([0-9]+)$")
	if tmp_1 and tmp_2 and tmp_3 and tmp_4 and tmp_5 then
		start_ip = tmp_1.."."..tmp_2.."."..tmp_3.."."..tmp_4
		end_ip = tmp_1.."."..tmp_2.."."..tmp_3.."."..tmp_5
	end
	
	--@ service 
	if luci.http.formvalue("save") then
		g_enabled = luci.http.formvalue("enabled") or ""
		g_mppe = luci.http.formvalue("mppe") or "1"
		g_localip = luci.http.formvalue("localip")
		start_ip = luci.http.formvalue("start_ip")
		end_ip = luci.http.formvalue("end_ip")

		if start_ip and end_ip then
			g_remoteip = start_ip.."-"..(end_ip:match("%.([0-9]+)$") or "254")
		end
		
		uci:set("pptpd","pptpd","enabled",g_enabled)
		uci:set("pptpd","pptpd","mppe",g_mppe)
		uci:set("pptpd","pptpd","localip",g_localip)
		uci:set("pptpd","pptpd","remoteip",g_remoteip)
		
		--@ qos
		uci:set("qos","qos_pptp1","enabled",(uci:get("pptpc","main","enabled") == "1" or g_enabled == "1") and "1" or "0")
		uci:set("qos","qos_pptp2","enabled",(uci:get("pptpc","main","enabled") == "1" or g_enabled == "1") and "1" or "0")

		uci:save("qos")
		uci:save("pptpd")
	end
	
	local del_target = luci.http.formvaluetable("Delete")
	if del_target then
		uci:delete_section(del_target)
	end

	if luci.http.formvalue("New") then
		local created = uci:section("pptpd","login")
		uci:save("pptpd")
		luci.http.redirect(ds.build_url("admin","network","vpn","pptp_server","edit",created,"add"))
		return
	end
	
	--@ Enable/Disable
--	local status_target = luci.http.formvaluetable("Status")
--	if status_target and "table" == type(status_target) then
--		for k,v in pairs(status_target) do
--			local state,cfg,section = k:match("([A-Za-z]+)%.([a-zA-Z0-9_]+)%.(%w+).x")
--			if cfg and section and state then
--				uci:set(cfg,section,"enabled",state == "Enabled" and "1" or "0")
--				uci:save(cfg)
--			end
--		end
--	end

	local th = {"Index","Username","Description"}
	local colgroup = {"6%","27%","57%","10%"}
	local content = {}
	local edit = {}
	local delchk = {}
	local uci_cfg = {}
	local status = {}
	local addnewable = true
	local cnt = 0

	local tmp_cfg = uci:get_all("pptpd") or {}
	
	for i=1,MAX_EXTENSION do
		for k,v in pairs(tmp_cfg) do
			if v.index and v['.type'] == "login" then
				if i == tonumber(v.index) then
					cnt = cnt + 1
					local tmp = {}
					tmp[1] = v.index
					tmp[2] = v.username or ""
					tmp[3] = v.description or ""
					--tmp[4] = i18n.translate(v.enabled == "1" and "Enabled" or "Disabled")
					
					edit[cnt] = ds.build_url("admin","network","vpn","pptp_server","edit",k,"edit")
					uci_cfg[cnt] = "pptpd." .. k
					--status[cnt] = v.enabled == "1" and "Enabled" or "Disabled"
					table.insert(content,tmp)
	 			end
	 		elseif v['.type'] == "login" and not v.index then
	 			--uci:delete("xl2tpd",k)
	 			--uci:save("xl2tpd")
	 		end
	 	end
	 end
	if MAX_EXTENSION == cnt then
		addnewable = false
	end
	luci.template.render("admin_network/vpn_pptp",{
		colgroup = colgroup,
		th = th,
		content = content,
		edit = edit,
		delchk = delchk,
		uci_cfg = uci_cfg,
		status = status,
		enabled = g_enabled,
		mppe = g_mppe,
		localip = g_localip,
		start_ip = start_ip,
		end_ip = end_ip,
		addnewable = addnewable,
		})
end

function action_gre()
	local uci = require "luci.model.uci".cursor()
	local ds = require "luci.dispatcher"
	local i18n = require "luci.i18n"
	local MAX_EXTENSION = tonumber(uci:get("profile_param","global","max_vpn_gre") or '10')
	
	uci:check_cfg("gre")

	local gre_profile = uci:get_all("gre") or {}
	local g_enabled = "0"
	local g_section

	for k,v in pairs(gre_profile) do
		if v['.type'] == "default" then
			g_enabled = v.enabled or "0"
			g_section = k
			break
		end
	end

	--@ global switch 
	if luci.http.formvalue("save") then
		g_enabled = luci.http.formvalue("enabled") or "0"
		
		if g_section then
			uci:set("gre",g_section,"enabled",g_enabled)
			uci:save("gre")
		end
	end
	
	local del_target = luci.http.formvaluetable("Delete")
	if del_target then
		uci:delete_section(del_target)
	end

	if luci.http.formvalue("New") then
		local created = uci:section("gre","gre")
		uci:save("gre")
		luci.http.redirect(ds.build_url("admin","network","vpn","gre","edit",created,"add"))
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

	local th = {"Tunnel Index","IP Address/Netmask","Tunnel Source Interface","Tunnel Destination Address","Status"}
	local colgroup = {"10%","26%","22%","22%","10%","10%"}
	local content = {}
	local edit = {}
	local delchk = {}
	local uci_cfg = {}
	local status = {}
	local addnewable = true
	local cnt = 0

	local tmp_cfg = uci:get_all("gre") or {}
	
	for i=1,MAX_EXTENSION do
		for k,v in pairs(tmp_cfg) do
			if v['.type'] == "gre" and v.interface then
				if i == tonumber(v.interface) then
					cnt = cnt + 1
					local tmp = {}
					tmp[1] = v.interface
					tmp[2] = v.ipaddr or ""
					tmp[3] = change_interface_view(v.iface)
					tmp[4] = v.remote or ""
					tmp[5] = i18n.translate(v.enabled == "1" and "Enabled" or "Disabled")
					
					edit[cnt] = ds.build_url("admin","network","vpn","gre","edit",k,"edit")
					uci_cfg[cnt] = "gre." .. k
					status[cnt] = v.enabled == "1" and "Enabled" or "Disabled"
					table.insert(content,tmp)
	 			end
	 		elseif v['.type'] == "gre" and not v.interface then
	 			--uci:delete("gre",k)
	 			--uci:save("gre")
	 		end
	 	end
	 end
	if MAX_EXTENSION == cnt then
		addnewable = false
	end
	luci.template.render("admin_network/vpn_gre",{
		colgroup = colgroup,
		th = th,
		content = content,
		edit = edit,
		delchk = delchk,
		uci_cfg = uci_cfg,
		status = status,
		addnewable = addnewable,
		enabled = g_enabled,
		})
end
function autovpn()
	local fs = require "nixio.fs"
	local uci = require "luci.model.uci".cursor()
	local util = require "luci.util"
	local content=""
	local status="0"
	local dns="8.8.8.8"
	uci:check_cfg("autovpn")
	uci:check_cfg("domainlist_tmp")

	if luci.http.formvalue("status") then
		if uci:get("autovpn","default") then
			uci:set("autovpn","default","enabled",luci.http.formvalue("status"))
			uci:set("autovpn","default","dns_server",luci.http.formvalue("dns"))
			uci:save("autovpn")
		else
			local tmp={}
			tmp.ipset="vpn"
			tmp.rule_pref="5"
			tmp.rtable="210"
			tmp.timeout="3600"
			uci:section("autovpn","autovpn","default",tmp)
			uci:commit("autovpn")
			uci:set("autovpn","default","enabled",luci.http.formvalue("status"))
			uci:set("autovpn","default","dns_server",luci.http.formvalue("dns"))
			uci:save("autovpn")
		end
		local domain_tmp = luci.http.formvalue("domain_list")
		local domain_tb = util.split(domain_tmp,"\n")
		uci:set_list("domainlist_tmp","domain_list","domain",domain_tb)
		uci:save("domainlist_tmp")
	end
	if uci:get("domainlist_tmp","domain_list","domain") then
		local t = uci:get("domainlist_tmp","domain_list","domain")
		content = table.concat(t,"\n")
	else
		content = fs.readfile("/etc/config/domainlist") or ""
		uci:section("domainlist_tmp","domain","domain_list",{})
		uci:commit("domainlist_tmp")
		uci:set_list("domainlist_tmp","domain_list","domain",util.split(content,"\n"))
		uci:commit("domainlist_tmp")
	end

	status=uci:get("autovpn","default","enabled") or "0"
	dns=uci:get("autovpn","default","dns_server") or "0"
	
	luci.template.render("admin_network/vpn_domainlist",{
		status=status,
		dns=dns,
		content=content,
		})
end
function action_route_static()
	local uci = require "luci.model.uci".cursor()
	local ds = require "luci.dispatcher"
	local i18n = require "luci.i18n"
	local MAX_EXTENSION = tonumber(uci:get("profile_param","global","max_route") or '32')
	
	local del_target = luci.http.formvaluetable("Delete")
	if del_target then
		uci:delete_section(del_target)
	end

	if luci.http.formvalue("New") then
		local created = uci:section("network","route")
		uci:save("network")
		luci.http.redirect(ds.build_url("admin","network","route","static","edit",created,"add"))
		return
	end

	local th = {"Index","Target IP","Netmask","Next Hop","Interface","Description"}
	local colgroup = {"10%","15%","15%","15%","15%","20%","10%"}
	local content = {}
	local edit = {}
	local delchk = {}
	local uci_cfg = {}
	local addnewable = true
	local cnt = 0

	local tmp_cfg = uci:get_all("network") or {}

	for i=1,MAX_EXTENSION do
		for k,v in pairs(tmp_cfg) do
			if v.index and v['.type'] == "route" then
				if i == tonumber(v.index) then
					cnt = cnt + 1
					local tmp = {}
					tmp[1] = v.index or ""
					tmp[2] = v.target or ""
					tmp[3] = v.netmask or ""
					tmp[4] = v.gateway or ""
					tmp[5] = change_interface_view(v.interface)
					tmp[6] = v.description or ""

					edit[cnt] = ds.build_url("admin","network","route","static","edit",k,"edit")
					uci_cfg[cnt] = "network." .. k
					table.insert(content,tmp)
	 			end
	 		elseif v['.type'] == "route" and not v.index then
	 			uci:delete("network",k)
	 			--uci:save("network")
	 		end
	 	end
	 end
	if MAX_EXTENSION == cnt then
		addnewable = false
	end
	luci.template.render("cbi/configlist",{
		colgroup = colgroup,
		th = th,
		content = content,
		edit = edit,
		delchk = delchk,
		uci_cfg = uci_cfg,
		addnewable = addnewable,
		})
end
function action_route_strategy()
	local uci = require "luci.model.uci".cursor()
	local ds = require "luci.dispatcher"
	local i18n = require "luci.i18n"
	local MAX_EXTENSION = tonumber(uci:get("profile_param","global","max_route") or '32')
	
	uci:check_cfg("mwan3")


	local del_target = luci.http.formvaluetable("Delete")
	if del_target then
		--@ first delete these sections
		--[[
		for k,v in pairs(del_target) do
			local cfg,section = k:match("([a-z0-9A-Z_]+)%.(%w+).x")
			if cfg and section then
				local del_policy = uci:get(cfg,section,"use_policy")
				local del_member = uci:get(cfg,del_policy,"use_member")
				local del_interface = uci:get(cfg,del_member,"interface")

				if del_policy then
					uci:delete("mwan3",del_policy)
				end
				if del_member then
					uci:delete("mwan3",del_member)
				end
				if del_interface then
					uci:delete("mwan3",del_interface)
				end
			end
		end
		]]--
		--@ delete this section
		uci:delete_section(del_target)
	end
	
	if luci.http.formvalue("New") then
		local created = uci:section("mwan3","rule")
		uci:save("mwan3")
		luci.http.redirect(ds.build_url("admin","network","route","policy","edit",created,"add"))
		return
	end
	

	local th = {"Index","Protocol","Source IP","Source Port","Dest IP","Dest Port","Interface"}
	local colgroup = {"5%","7%","23%","12%","23%","12%","8%","10%"}
	local content = {}
	local edit = {}
	local delchk = {}
	local uci_cfg = {}
	local addnewable = true
	local cnt = 0

	local tmp_cfg = uci:get_all("mwan3") or {}

	function get_ifname_from_cfg(param)
		local ret_str = ""
		
		if param == "wan" then
			ret_str = "WAN"
		else
			ret_str = uci:get("network",param,"name") or param or ""
		end

		return ret_str
	end
	
	for i=1,MAX_EXTENSION do
		for k,v in pairs(tmp_cfg) do
			if v.index and v['.type'] == "rule" then
				if i == tonumber(v.index) then
					cnt = cnt + 1
					local tmp = {}
					tmp[1] = v.index or ""
					tmp[2] = string.upper(v.proto) or ""
					tmp[3] = v.src_ip or ""
					tmp[4] = v.src_port or ""
					tmp[5] = v.dest_ip or ""
					tmp[6] = v.dest_port or ""
					local tmp_str = v.use_policy and v.use_policy:match("_([a-z0-9]+)") or ""
					tmp[7] = get_ifname_from_cfg(tmp_str)

					edit[cnt] = ds.build_url("admin","network","route","policy","edit",k,"edit")
					uci_cfg[cnt] = "mwan3." .. k
					table.insert(content,tmp)
	 			end
	 		elseif v['.type'] == "rule" and not v.index then
	 			--uci:delete("mwan3",k)
	 			--uci:save("mwan3")
	 		end
	 	end
	 end
	if MAX_EXTENSION == cnt then
		addnewable = false
	end
	luci.template.render("cbi/configlist",{
		title = i18n.translate("Policy Route List"),
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
	local uci = require "luci.model.uci".cursor()
	local ds = require "luci.dispatcher"
	local i18n = require "luci.i18n"
	local MAX_EXTENSION = tonumber(uci:get("profile_param","global","max_default") or '32')
	
	uci:check_cfg("firewall")

	local del_target = luci.http.formvaluetable("Delete")
	if del_target then
		uci:delete_section(del_target)
	end

	if luci.http.formvalue("New") then
		local created = uci:section("firewall","redirect")
		uci:save("firewall")
		luci.http.redirect(ds.build_url("admin","network","dmz_port","port_map","edit",created,"add"))
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
	
	local th = {"Index","Name","Protocol","WAN Port","LAN IP","LAN Port","Status"}
	local colgroup = {"5%","10%","10%","20%","20%","18%","7%","10%"}
	local content = {}
	local edit = {}
	local delchk = {}
	local uci_cfg = {}
	local status = {}
	local addnewable = true
	local cnt = 0

	local firewall_cfg = uci:get_all("firewall") or {}
	
	for i=1,MAX_EXTENSION do
		for k,v in pairs(firewall_cfg) do
			if v.index and v.name and v['.type'] == "redirect" and v.src_dport and not v.target then
				if i == tonumber(v.index) then
					cnt = cnt + 1
					local tmp = {}
					tmp[1] = v.index
					tmp[2] = v.name
					tmp[3] = string.upper(v.proto or "")
					tmp[4] = v.src_dport or ""
					tmp[5] = v.dest_ip or ""
					tmp[6] = v.dest_port or ""
					tmp[7] = i18n.translate(v.enabled == "1" and "Enabled" or "Disabled")
					
					edit[cnt] = ds.build_url("admin","network","dmz_port","port_map","edit",k,"edit")
					uci_cfg[cnt] = "firewall." .. k
					status[cnt] = v.enabled == "1" and "Enabled" or "Disabled"
					table.insert(content,tmp)
	 			end
	 		elseif v['.type'] == "redirect" and not v.index and not v.name then
	 			--uci:delete("firewall",k)
	 			--uci:save("firewall")
	 		end
	 	end
	 end
	if MAX_EXTENSION == cnt then
		addnewable = false
	end
	luci.template.render("cbi/configlist",{
		colgroup = colgroup,
		th = th,
		content = content,
		edit = edit,
		delchk = delchk,
		uci_cfg = uci_cfg,
		status = status,
		addnewable = addnewable,
		})
end
function action_qos()
	local uci = require "luci.model.uci".cursor()
	local ds = require "luci.dispatcher"
	local i18n = require "luci.i18n"
	local qos_global_cfg = {}
	local MAX_EXTENSION = tonumber(uci:get("profile_param","global","max_default") or '32')
	
	if uci:get_all("qos","setup") then
		qos_global_cfg = uci:get_all("qos","setup")
	end

	--@ service 
	if luci.http.formvalue("save") then
		local http_qos_tb = luci.http.formvaluetable("qos") or {}
		for k,v in pairs(http_qos_tb) do
			if k and v then
				qos_global_cfg[k] = v
				uci:set("qos","setup",k,v)
			end
		end
		uci:save("qos")
	end
	
	local del_target = luci.http.formvaluetable("Delete")
	if del_target then
		uci:delete_section(del_target)
	end

	if luci.http.formvalue("New") then
		local created = uci:section("qos","rule")
		uci:save("qos")
		luci.http.redirect(ds.build_url("admin","network","qos","edit",created,"add"))
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
	
	local th = {"Index","IP Address Field","Packet Length","DSCP Match","Direction","Queue","DSCP Remark","Status"}
	local colgroup = {"6%","25%","12%","10%","10%","9%","11%","8%","9%"}
	local content = {}
	local edit = {}
	local delchk = {}
	local uci_cfg = {}
	local status = {}
	local more_info = {}
	local addnewable = true
	local cnt = 0

	function change_view(param)
		local ret_str = ""
		
		if param == "up_down" then
			ret_str = i18n.translate("Bidirectional")
		elseif param == "down" then
			ret_str = i18n.translate("Download")
		elseif param == "up" then
			ret_str = i18n.translate("Upload")
		end

		return ret_str
	end
	
	local qos_cfg = uci:get_all("qos") or {}

	for i=1,MAX_EXTENSION do
		for k,v in pairs(qos_cfg) do
			if v.index and i == tonumber(v.index) then
				cnt = cnt + 1
				local tmp = {}
				
				tmp[1] = v.index or ""
				tmp[2] = v.iprange or v.ipaddr or ""
				tmp[3] = v.packet_length or ""
				tmp[4] = v.dscp_value or i18n.translate("NONE")
				tmp[5] = change_view(v.direct or "")
				tmp[6] = v.target or ""
				tmp[7] = v.remark_dscp or i18n.translate("NONE")
				tmp[8] = i18n.translate(v.enabled == "0" and "Disabled" or "Enabled")
				
				edit[cnt] = ds.build_url("admin","network","qos","edit",k,"edit")
				uci_cfg[cnt] = "qos." .. k
				status[cnt] = v.enabled == "0" and "Disabled" or "Enabled"
				more_info[cnt] = i18n.translate("Protocol")..": "..string.upper(v.proto or "all").."<br>"
				if v.proto == "tcp" or v.proto == "udp" then
					if v.src_port then
						more_info[cnt] = more_info[cnt]..i18n.translate("Source Port")..": "..v.src_port.."<br>"
					end
					if v.dest_port then
						more_info[cnt] = more_info[cnt]..i18n.translate("Destination Port")..": "..v.dest_port.."<br>"
					end
				end
					
				table.insert(content,tmp)
	 		end
	 	end
	 end
	if MAX_EXTENSION == cnt then
		addnewable = false
	end
	luci.template.render("admin_network/qos",{
		colgroup = colgroup,
		th = th,
		content = content,
		edit = edit,
		delchk = delchk,
		uci_cfg = uci_cfg,
		status = status,
		addnewable = addnewable,
		more_info = more_info,
		qos_cfg = qos_global_cfg,
		
		})
end
function action_upnp()
end
function action_nat()
	local uci = require "luci.model.uci".cursor()
	local ds = require "luci.dispatcher"
	local i18n = require "luci.i18n"
	local MAX_EXTENSION = tonumber(uci:get("profile_param","global","max_nat") or '10')
	
	uci:check_cfg("firewall")

	--@ Enable/Disable
	local status_target = luci.http.formvaluetable("Status")
	if status_target and "table" == type(status_target) then
		for k,v in pairs(status_target) do
			local state,cfg,section = k:match("([A-Za-z]+)%.([a-zA-Z_]+)%.(%w+).x")
			if cfg and section and state then
				--@ set SNAT
				if "Enabled" == state and uci:get(cfg,section,"src_ip") and uci:get(cfg,section,"src_dip") then
					uci:set(cfg,section,"enabled","1")
				else
					uci:set(cfg,section,"enabled","0")
				end
				--@ set DNAT
				local dnat_index = uci:get(cfg,section,"index")
				if dnat_index then
					for k2,v2 in pairs(uci:get_all("firewall") or {}) do
						if v2['.type'] == "redirect" and v2.target == "DNAT" and v2.index == dnat_index then
							if "Enabled" == state and v2.dest_ip and v2.src_dip then
								uci:set(cfg,k2,"enabled","1")
							else
								uci:set(cfg,k2,"enabled","0")
							end
							break
						end
					end
				end
				
				uci:save(cfg)
			end
		end
	end
	
	local th = {"Index","Name","Internal Address","External Address","Description","Status"}
	local colgroup = {"5%","10%","20%","20%","25%","10%","10%"}
	local content = {}
	local edit = {}
	local uci_cfg = {}
	local status = {}
	local addnewable = true
	local cnt = 0

	local firewall_cfg = uci:get_all("firewall") or {}

	--@ Only get target is SNAT ,type is redirect for NAT Config
	--@ the target is DNAT attach to SNAT
	for i=1,MAX_EXTENSION do
		for k,v in pairs(firewall_cfg) do
			if v.index and v['.type'] == "redirect" and v.target == "SNAT" then
				if i == tonumber(v.index) then
					cnt = cnt + 1
					local tmp = {}
					tmp[1] = v.index or ""
					tmp[2] = v.name and v.name:match("^SNAT([a-zA-Z0-9%.%-_]+)") or ""
					tmp[3] = v.src_ip or ""
					tmp[4] = v.src_dip or ""
					tmp[5] = v.description or ""
					tmp[6] = i18n.translate(v.enabled == "1" and "Enabled" or "Disabled")

					edit[cnt] = ds.build_url("admin","network","nat","rule","edit",k,"edit")
					uci_cfg[cnt] = "firewall." .. k
					status[cnt] = v.enabled == "1" and "Enabled" or "Disabled"
					table.insert(content,tmp)
	 			end
	 		elseif not v.index and v['.type'] == "redirect" then
	 			--uci:delete("firewall",k)
	 			--uci:save("firewall")
	 		end
	 	end
	 end
	if MAX_EXTENSION == cnt then
		addnewable = false
	end
	luci.template.render("cbi/configlist",{
		colgroup = colgroup,
		th = th,
		content = content,
		edit = edit,
		uci_cfg = uci_cfg,
		status = status,
		addnewable = addnewable,
		})
end

function parse_dir(param)
	local util = require "luci.util"
	local ret_tb = {}

	if param then
		local ret_cmd = util.exec("ls -lahrS "..param)
		local tmp_tb = util.split(ret_cmd,"\n") or {}

		local bk_dir = {}
		bk_dir.file_name = ".."
		bk_dir.file_type = "directory"
		bk_dir.mtime = "-"
		bk_dir.size = "-"
		bk_dir.path = "-"

		table.insert(ret_tb,bk_dir)
		
		for _,v in ipairs(tmp_tb) do
			if v then
				local temp = {}
				
				local mode,size,mtime,name = v:match("^([a-zA-Z%-]+)%s*[0-9]+%s*[a-zA-Z]+%s*[a-zA-Z]+%s*([0-9a-zA-Z%.]+)%s*([a-zA-Z]+%s*[0-9]+%s*[0-9:]+)%s*(.+)")
				if mode and size and mtime and name and name ~= ".." and name ~= "." then
					temp.file_name = name 
					temp.file_type = mode:match("^.") == "d" and "directory" or "file"
					temp.size = size
					temp.mtime = mtime
					temp.path = param.."/"..name
					
					table.insert(ret_tb,temp)
				end
			end
		end
	end
	
	return ret_tb
end

function parse_usbdisk_size(cmd_param)
	local util = require "luci.util"
	local ret_tsize = 0
	local ret_rsize = 0

	if cmd_param then
		local ret_cmd = util.exec(cmd_param)
		_,ret_tsize,_,ret_rsize,_,_ = ret_cmd:match("^([a-z%/0-9]+)%s*([a-zA-Z0-9%.]+)%s*([a-zA-Z0-9%.]+)%s*([a-zA-Z0-9%.]+)%s*([0-9%.%%]+)%s*([a-z%/]+)")
	end

	return ret_tsize,ret_rsize
end

function action_udisk()
	local fs = require "luci.fs"
	local sys = require "luci.sys"
	local util = require "luci.util"
	local file_content = {}
	--@ default u-disk dir
	local cur_dir = "/usbdisk"
	local tmp_file = "/usbdisk"
	local file_name = ""
	local upload_file
	local refresh_flag = true
	
	--@ get upload file
	local fp
	luci.http.setfilehandler(
		function(meta, chunk, eof)
			if not fp then
				if meta and meta.name then
					tmp_file = tmp_file.."/"..(os.tmpname():match("tmp/(.+)$"))
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
				--@ mv to cur_dir
				util.exec("mv "..tmp_file.." "..(luci.http.formvalue("cur_dir") or cur_dir).."/"..file_name)
			end
		end
	)

	cur_dir = luci.http.formvalue("cur_dir") or cur_dir
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
			local reader = luci.ltn12.source.file(io.open(cur_dir.."/"..download_filename,"r"))
			luci.http.header('Content-Disposition', 'attachment; filename="'..download_filename..'"')
			local tmp = download_filename:match("%.([a-zA-Z0-9]+)$") or ""
			local content_type = content_type_list[tmp] or "application/octet-stream"
			
			luci.http.prepare_content(content_type)
			luci.ltn12.pump.all(reader, luci.http.write)
			fs.unlink(download_filename)	
		end
	--@ new folder
	elseif luci.http.formvalue("folder_name") then
		local folder_name = luci.http.formvalue("folder_name") -- http formvalue
		
		if folder_name then
			util.exec("mkdir '"..cur_dir.."/"..folder_name.."'")
		end
		
	--@ file upload
	elseif luci.http.formvalue("file_upload") then
		--@ get upload file by trunk		
		local upload_file = luci.http.formvalue("upload")
		if upload_file and #upload_file > 0 then

		end
	--@ change directory
	elseif luci.http.formvalue("change_dir") then
		--@ can not move out "/usbdisk"
		cur_dir = util.exec("cd '"..cur_dir.."/"..luci.http.formvalue("change_dir").."' && pwd"):match("(.+)\n$")
		if not cur_dir:match("^/usbdisk") then
			cur_dir = "/usbdisk"
		end
	--@ goto new directory
	elseif luci.http.formvalue("goto_dir") then
		--@
		cur_dir = luci.http.formvalue("goto_dir")
		if not cur_dir:match("^/usbdisk") then
			cur_dir = "/usbdisk"
		end
	--@ file delete
	elseif luci.http.formvalue("file_delete") then
		local file_name = luci.http.formvalue("file_delete")

		if file_name then
			util.exec("rm -fr '"..cur_dir.."/"..file_name.."'")
		end
	--@ safe_popup
	elseif luci.http.formvalue("safe_popup") then
		util.exec("umount /usbdisk")
		cur_dir = "/usbdisk"
	else
		--@ first in ,do nothing
	end

	if refresh_flag then
		--@ render to html
		file_content = parse_dir(cur_dir)
		local total_size,available_size = parse_usbdisk_size("df -h | grep usbdisk")
		local _,max_size = parse_usbdisk_size("df | grep usbdisk")
		max_size = (max_size or 0) * 1024
		
		luci.template.render("admin_network/udisk",{
			cur_dir = cur_dir,
			file_content = file_content,
			total_size = total_size,
			available_size = available_size,
			max_size = max_size,
		})
	end
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

			tcpdump_cmd = (src_port and tcpdump_cmd) and (tcpdump_cmd.." and "..src_port) or src_port or tcpdump_cmd

			tcpdump_cmd = (dst_ip and tcpdump_cmd) and (tcpdump_cmd.." and "..dst_ip) or dst_ip or tcpdump_cmd

			tcpdump_cmd = (dst_port and tcpdump_cmd) and (tcpdump_cmd.." and "..dst_port) or dst_port or tcpdump_cmd

			tcpdump_cmd = (proto and tcpdump_cmd) and (tcpdump_cmd .. " and (" ..proto..")") or (proto and "("..proto..")") or tcpdump_cmd

			local tcpdump_header = ""

			--@ ubg1000 changed interface
			if interface and interface ~= "all" then
				if uci:get_all("network",interface) then
					if uci:get("network",interface,"type") then
						tcpdump_header = "tcpdump -U -C 10 -W 1 -s 0 -i br-"..interface.." "
					else
						if interface == "wan" then
							tcpdump_header = "tcpdump -U -C 10 -W 1 -s 0 -i eth1 "
						elseif interface:match("wan2") then
							tcpdump_header = "tcpdump -U -C 10 -W 1 -s 0 -i 3g-wan2 "
						elseif interface:match("^vlan") and uci:get("network",interface,"vlanid") then
							tcpdump_header = "tcpdump -U -C 10 -W 1 -s 0 -i eth0."..uci:get("network",interface,"vlanid").." "
						elseif interface:match("^vwan") and uci:get("network",interface,"vlanid")  then
							tcpdump_header = "tcpdump -U -C 10 -W 1 -s 0 -i eth1."..uci:get("network",interface,"vlanid").." "
						else	
							--@ error
							tcpdump_header = "tcpdump -U -C 10 -W 1 -s 0 -i any "
						end
					end
				else
					--@ no this interface
					tcpdump_header = "tcpdump -U -C 10 -W 1 -s 0 -i any "
				end
			else
				tcpdump_header = "tcpdump -U -C 10 -W 1 -s 0 -i any "
			end
			
			tcpdump_cmd = tcpdump_header.."'"..(tcpdump_cmd or "").."'"..(proto_t or "").. " -w /tmp/package.pcap &"
			os.execute(tcpdump_cmd)
		
		elseif "voice" == luci.http.formvalue("cbid.diag.set") then
			local sip_profile = uci:get_all("profile_sip") or {}
			local port
			for k,v in pairs(sip_profile) do
				if v.index and v.localport then
					port = port and (port.." or "..v.localport) or v.localport
				end
			end

			local portrange = (uci:get_all("callcontrol","voice","rtp_start_port") or "16000") .. "-" .. (uci:get_all("callcontrol","voice","rtp_end_port") or "16200")
			local ret_str = util.exec("fs_cli -x 'c300dsp 450 9'")
			if ret_str:match("succussly") then
				os.execute("touch /tmp/voice_capture_flag && tcpdump -C 10 -W 1 -s 0 "..(port and ("port "..port.." or ") or "").." portrange "..portrange.." -w /tmp/rtp_capture.pcap &")
			end
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
			local destfile_gz = "/tmp/voice_capture.tar.gz"
			
			os.execute("rm /tmp/voice_capture_flag")
			--@ stop capture
			os.execute("fs_cli -x 'c300dsp 451 9'")

			--@
			sys.call("tar -c /tmp/pcm_send_* /tmp/pcm_recv_* /tmp/rtp_capture.pcap -f "..destfile_gz)
			local reader = luci.ltn12.source.file(io.open(destfile_gz,"r"))
			luci.http.header('Content-Disposition', 'attachment; filename="voice_capture-%s-%s-%s.tar.gz"' % {
				luci.sys.hostname(), localip, os.date("%Y-%m-%d %X")})
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
function diag_nslookup()
	diag_command("nslookup %q 2>&1")
end
function diag_traceroute()
	diag_command("traceroute -q 1 -w 1 -n %q 2>&1")
end

