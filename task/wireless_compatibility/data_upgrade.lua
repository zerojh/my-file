local uci = require "luci.model.uci".cursor()
local fs = require "luci.fs"
local util = require "luci.util"
local dpr = require "dpr"

function compatibility_check_callcontrol_param()
	uci:check_cfg("callcontrol")
	local sys_cfg = uci:get_all("system","main")
	local route_cfg = uci:get_all("callcontrol","route")
	local voice_cfg = uci:get_all("callcontrol","voice")

	if not route_cfg then
		uci:create_section("callcontrol","route","route",{localcall=(sys_cfg.localcall or "1")})
	else
		if sys_cfg.localcall then
			uci:set("callcontrol","route","localcall",sys_cfg.localcall)
		end
	end
	uci:delete("system","main","localcall")

	if not voice_cfg then
		uci:create_section("callcontrol","voice","voice",{nortp=(sys_cfg.nortp or "0"),lang=(sys_cfg.lang or "en"),rtp_start_port=(sys_cfg.rtp_start_port or "16000"),rtp_end_port=(sys_cfg.rtp_end_port or "16200")})
	else
		if sys_cfg.nortp and (not voice_cfg.nortp) then
			uci:set("callcontrol","voice","nortp",sys_cfg.nortp)
		end
		if sys_cfg.lang and (not voice_cfg.lang) then
			uci:set("callcontrol","voice","lang",sys_cfg.lang)
		end
		if sys_cfg.rtp_start_port and (not voice_cfg.rtp_start_port) then
			uci:set("callcontrol","voice","rtp_start_port",sys_cfg.rtp_start_port)
		end
		if sys_cfg.rtp_end_port and (not voice_cfg.rtp_end_port) then
			uci:set("callcontrol","voice","rtp_end_port",sys_cfg.rtp_end_port)
		end
	end
	uci:delete("system","main","nortp")
	uci:delete("system","main","lang")
	uci:delete("system","main","rtp_start_port")
	uci:delete("system","main","rtp_end_port")
	uci:commit("system")
	uci:commit("callcontrol")
end

function compatibility_check_sip_profile()
	uci:check_cfg("profile_sip")
	local s = uci:get_all("profile_sip") or {}

	for k,v in pairs(s) do
		uci:delete("profile_sip",k,"max_channels")
	end
	uci:save("profile_sip")
	uci:commit("profile_sip")
end

function compatibility_check_fax()
	uci:check_cfg("fax")
	local fax = uci:get_all("fax")
	local option = {}

	if not fax.main then
		option = {mode="t30",local_detect="false"}
		uci:create_section("fax","fax","main",option)
	end
end

function compatibility_check_telnet()
	uci:check_cfg("telnet")
	local tel_cfg = uci:get_all("telnet","telnet")
	local sys_cfg = uci:get_all("system","telnet")
	if not tel_cfg then
		uci:create_section("telnet","telnet","telnet",{action=sys_cfg.action or "on",port=sys_cfg.port or "23"})
		uci:commit("telnet")
	else
		uci:set("system","telnet","action",tel_cfg.action or "on")
		uci:set("system","telnet","port",tel_cfg.port or "23")
		uci:commit("system")
	end
end

function compatibility_check_fxo()
	uci:check_cfg("profile_fxso")
	local fxso = uci:get_all("profile_fxso")
	for k,v in pairs(fxso) do
		if "fxo" == v['.type'] then
			if v.enablecallerid then
				if "off" == v.enablecallerid then
					uci:set("profile_fxso",k,"detectcid_opt","0")
				end
				uci:delete("profile_fxso",k,"enablecallerid")
			end
		end
	end
	uci:commit("profile_fxso")
end

function compatibility_check_system_param()
	local model = string.upper(dpr.getproduct() or "")
	local uci_interface=uci:get("system","main","interface")

	if not uci_interface then
		uci_interface=model:match("%-(%w+)$") or "1G1S1O"
		if uci_interface then
			uci:set("system","main","interface",uci_interface)
			uci:commit("system")
		end
	elseif model:match("%-(%w+)$") then
		local interface_tmp = model:match("%-(%w+)$")
		if string.upper(interface_tmp) ~= string.upper(uci_interface) then
			uci:set("system","main","interface",interface_tmp)
			uci:commit("system")
		end
	end
end

function compatibility_check_featurecode_descriptioin()
	uci:check_cfg("feature_code")
	local fc = uci:get_all("feature_code")
	for k,v in pairs(fc) do
		if v.description and "Enable call_waiting service" == v.description then
			uci:set("feature_code",k,"description","Enable Call Waiting service")
		end
		if v.description and "Disable call_waiting service" == v.description then
			uci:set("feature_code",k,"description","Disable Call Waiting service")
		end
		if v.name and "Call Forward Unconditional Activate" == v.name then
			uci:set("feature_code",k,"name","Call Forwarding Uncondition Activate")
		end
		if v.description and "Enable Unconditional call_forward service.Example:*72*8000,set the call_forward number is 8000." == v.description then
			uci:set("feature_code",k,"description","Enable Call Forwarding Uncondition service.Example:*72*8000,set the call forwarding number to 8000.")
		end
		if v.name and "Call Forward Unconditional Deactivate" == v.name then
			uci:set("feature_code",k,"name","Call Forwarding Uncondition Deactivate")
		end
		if v.description and "Disable Unconditional call_forward service" == v.description then
			uci:set("feature_code",k,"description","Disable Call Forwarding Uncondition service")
		end
		if v.name and "Call Forward Busy Activate" == v.name then
			uci:set("feature_code",k,"name","Call Forwarding Busy Activate")
		end
		if v.description and "Enable USER_BUSY call_forward service.Example:*90*8000,set the call_forward number is 8000." == v.description then
			uci:set("feature_code",k,"description","Enable Call Forwarding Busy service.Example:*90*8000,set the call forwarding number to 8000.")
		end
		if v.name and "Call Forward Busy Deactivate" == v.name then
			uci:set("feature_code",k,"name","Call Forwarding Busy Deactivate")
		end
		if v.description and "Disable USER_BUSY call_forward service" == v.description then
			uci:set("feature_code",k,"description","Disable Call Forwarding Busy service")
		end
		if v.name and "Call Forward No Reply Activate" == v.name then
			uci:set("feature_code",k,"name","Call Forwarding No Reply Activate")
		end
		if v.description and "Enable NO_REPLY call_forward service.Example:*92*8000,set the call_forward number is 8000." == v.description then
			uci:set("feature_code",k,"description","Enable Call Forwarding No Reply service.Example:*92*8000,set the call forwarding number to 8000.")
		end
		if v.name and "Call Forward No Reply Deactivate" == v.name then
			uci:set("feature_code",k,"name","Call Forwarding No Reply Deactivate")
		end
		if v.description and "Disable NO_REPLY call_forward service" == v.description then
			uci:set("feature_code",k,"description","Disable Call Forwarding No Reply service")
		end
		if v.name and "Do Not Disturb Activate" == v.name then
			uci:set("feature_code",k,"name","DND Activate")
		end
		if v.description and "Enable DND service" == v.description then
			uci:set("feature_code",k,"description","Enable Do Not Disturb service")
		end
		if v.name and "Do Not Disturb Deactivate" == v.name then
			uci:set("feature_code",k,"name","DND Deactivate")
		end
		if v.description and "Disable DND service" == v.description then
			uci:set("feature_code",k,"description","Disable Do Not Disturb service")
		end
	end
	uci:commit("feature_code")
end

function compatibility_upnpc()
	if not fs.access("/etc/config/upnpc") then
		uci:check_cfg("upnpc")
		uci:create_section("upnpc","upnpc","service",{})
		uci:commit("upnpc")
	end
	if not fs.access("/usr/bin/upnpc") then
		os.execute("ln -s /usr/lib/lua/luci/scripts/upnpc-static /usr/bin/upnpc")
	elseif fs.access("/usr/bin/upnpc") and not fs.readlink("/usr/bin/upnpc") then
		os.execute("rm /usr/bin/upnpc && ln -s /usr/lib/lua/luci/scripts/upnpc-static /usr/bin/upnpc")
	end

	if fs.access("/etc/init.d/upnpc") and util.exec("cmp /usr/lib/lua/luci/scripts/upnpc /etc/init.d/upnpc") ~= "" then
		--@ copy upnpc script
		os.execute("cp /usr/lib/lua/luci/scripts/upnpc /etc/init.d && chmod 777 /etc/init.d/upnpc && /etc/init.d/upnpc enable")
	end
end

function compatibility_ringback()
	require "mxml"
	local lang = uci:get("oem","general","lang")
	local val = ""
	local var_xml = "/etc/freeswitch/conf/vars.xml"

	if lang == "cn" then
		val = "/etc/freeswitch/sounds/zh/cn/callie/waiting_music"
	else
		val = "/etc/freeswitch/sounds/en/us/callie/waiting_music"
	end

	if fs.access(var_xml) then
		local root = mxml.parsefile(var_xml)
		if root then
			local hold_music = mxml.find(root,"include","X-PRE-PROCESS","data","hold_music=local_stream://moh")
			if hold_music then
				mxml.setattr(hold_music,"data","hold_music="..val)
			end

			mxml.savefile(root,var_xml)
			mxml.release(root)
		end
	end
end

function compatibility_ddns()
	local ddns_dinstar = uci:get_all("ddns","dinstar_ddns")
	if not ddns_dinstar then
		uci:create_section("ddns","service","dinstar_ddns",{enabled="1",use_https="1",cacert="IGNORE",interface="wan",ip_source="web",ip_url="http://ddns.oray.com/checkip",domain="0000-0000-0000-0000",update_url="http://dstardns.com:8080/nic/update?domain=[DOMAIN]&ip=[IP]&key=[KEY]"})
		uci:commit("ddns")
	end
	local pddns_cli = uci:get_all("ddns","pddns_client")
	if not pddns_client then
		uci:create_section("ddns","pddns","pddns_client",{interval="20",dns_domain=".dstardns.com",dns_server="@ns1.dstardns.com"})
		uci:commit("ddns")
	end
end

function compatibility_vpn()
	local firewall_vpn=false
	-- local function include_callback(s)
	-- 	if s.path == "/etc/firewall.vpn" or s.path == "/etc/firewall.vpn.reload" or s.path == "/var/run/firewall.vpn.l2tp" then
	-- 		firewall_vpn = true
	-- 	end
	-- 	if s.path == "/etc/firewall.vpn" then
	-- 		if s.reload == "1" then
	-- 			uci:delete("firewall",s[".name"],"reload")
	-- 			uci:commit("firewall")
	-- 		end
	-- 	end
	-- end
	-- uci:foreach("firewall","include",include_callback)
	--foreach have some problem in some device, will cause Segmentation fault, so we use k,v in pairs instead 
	for k,v in pairs(uci:get_all("firewall") or {}) do
		if "include" == v[".type"] then
			if v.path == "/etc/firewall.vpn" or v.path == "/etc/firewall.vpn.reload" or v.path == "/var/run/firewall.vpn.l2tp" then
				firewall_vpn = true
			end
			if v.path == "/etc/firewall.vpn" then
				if v.reload == "1" then
					uci:delete("firewall",s[".name"],"reload")
					uci:commit("firewall")
				end
			end
		end
	end

	if not firewall_vpn then
		uci:create_section("firewall","include",nil,{path="/etc/firewall.vpn"})
		uci:create_section("firewall","include",nil,{path="/etc/firewall.vpn.reload",reload="1"})
		uci:create_section("firewall","include",nil,{path="/var/run/firewall.vpn.l2tp"})
		uci:commit("firewall")
	end

	local s = util.exec("cat /etc/crontabs/root | grep ipsec")
	if #s == 0 then
		util.exec("echo */1 * * * * /etc/ipsec_check_status.sh & >>/etc/crontabs/root")
	end
end

function compatibility_check_mwan3()
	if uci:get_all("mwan3") then
		uci:set("mwan3","wan","reliability","1")
		uci:commit("mwan3")
	end
	for k,v in pairs(uci:get_all("firewall") or {}) do
		if "zone" == v[".type"] and "wan" == v.name then
			uci:set_list("firewall",k,"network",{"wan","wan2","wan6"})
			uci:commit("firewall")
		end
	end
	--foreach have some problem in some device, will cause Segmentation fault, so we use k,v in pairs instead 
	--local function zone_callback(s)
	--	if "wan"==s.name then
	--		uci:set_list("firewall",s[".name"],"network",{"wan","wan2","wan6"})
	--		uci:commit("firewall")
	--	end
	--end
	--uci:foreach("firewall","zone",zone_callback)
end

function compatibility_check_dhcp()
	uci:set("dhcp","lan","force","1")
	uci:commit("dhcp")
end

function featurecode_check()
	local flag = true
	uci:check_cfg("feature_code")
	local fc = uci:get_all("feature_code")
	for k, v in pairs(fc) do
		if "23" == v.index then
			flag = false
		end
	end
	if flag then
		uci:create_section("feature_code","feature_code",nil,{index="23",name="WAN Access Control",code="*160*",description="*160*1# - Allow HTTP WAN access, *160*0# - Deny HTTP WAN access",status="Enabled"})
		uci:save("feature_code")
		uci:commit("feature_code")
	end
end
function compatibility_check_network_route()
	local openvpn = uci:get_all("network","openvpn")
	if not openvpn then
		uci:create_section("network","interface","openvpn",{ifname="tun0",disabled="0"})
		uci:save("network")
		uci:commit("network")
	end
end
function move_uci_changes_log()
	if not fs.access("/etc/log/uci_changes_log") and fs.access("/ramlog/uci_changes_log") then
		os.execute("mkdir /etc/log >>/dev/null 2>&1 && mv /ramlog/uci_changes_log /etc/log/uci_changes_log")
		if fs.access("/ramlog/uci_changes_log.0") then
			os.execute("mv /ramlog/uci_changes_log.0 /etc/log/uci_changes_log.0")
		end
	end
end

function compatibility_check_smsroute_data()
	local smsr=uci:get_all("profile_smsroute") or {}
	local flag
	for k,v in pairs(smsr) do
		if v.from == "GSM-2" then
			uci:set("profile_smsroute",k,"from","SMS-2")
			flag=true
		end
		if v.dest == "GSM-2" then
			uci:set("profile_smsroute",k,"dest","SMS-2")
			flag=true
		end
	end
	if flag then
		uci:commit("profile_smsroute")
	end
end

function compatibility_check_route_data()
	local route=uci:get_all("route") or {}
	local flag
	for k,v in pairs(route) do
		if v.from == "FXS-1" then
			uci:set("route",k,"from","FXS-1-1")
			flag=true
		end
		if v.successDestination == "FXS-1" then
			uci:set("route",k,"successDestination","FXS-1-0")
			flag=true
		end
		if v.failDestination == "FXS-1" then
			uci:set("route",k,"failDestination","FXS-1-0")
			flag=true
		end
		if v.from == "FXO-1" then
			uci:set("route",k,"from","FXO-1-2")
			flag=true
		end
		if v.successDestination == "FXO-1" then
			uci:set("route",k,"successDestination","FXO-1-1")
			flag=true
		end
		if v.failDestination == "FXO-1" then
			uci:set("route",k,"failDestination","FXO-1-1")
			flag=true
		end
		if v.custom_from and next(v.custom_from) then
			local v_t = {}
			local v_flag
			for i,j in pairs(v.custom_from) do
				if j == "FXS-1" then
					table.insert(v_t,"FXS-1-1")
					v_flag=true
				elseif j == "FXO-1" then
					table.insert(v_t,"FXO-1-2")
					v_flag=true
				else
					table.insert(v_t,j)
				end
			end
			if v_flag then
				uci:set_list("route",k,"custom_from",v_t)
				flag=true
			end
		end
	end
	if flag then
		uci:commit("route")
	end
end

function compatibility_check_mobile_endpoint()
	local mobile=uci:get_all("endpoint_mobile") or {}
	local flag
	for k,v in pairs(mobile) do
		if "2g" == v.lte_mode or "3g" == v.lte_mode then
			uci:set("endpoint_mobile",k,"lte_mode","2g-3g")
			flag = true
		end
	end
	if flag then
		uci:commit("endpoint_mobile")
	end
end

function compatibility_check_wireless()
	local exe = require "os".execute
	local wireless = uci:get_all("wireless") or {}
	local flag
	local drv_str = util.exec("lsmod | sed -n '/^rt2x00/p;/^rt2860v2_ap/p;/^rt2860v2_sta/p;'")
	drv_str = drv_str:match("(rt2860v2_ap)") or drv_str:match("(rt2860v2_sta)") or drv_str:match("(rt2x00)") or ""

	if drv_str == "rt2x00" and wireless.ra0 then
		flag=true
		for k,v in pairs(wireless) do
			if v[".type"] == "wifi-device" and k == "ra0" then
				if v.type ~= "mac80211" then
					uci:set("wireless",k,"type","mac80211")
				end
				if v.isolate then
					uci:delete("wireless",k,"isolate")
				end
				if v.txpower then
					uci:delete("wireless",k,"txpower")
				end
				if v.wdsmode then
					uci:delete("wireless",k,"wdsmode")
				end
				if v.wps then
					uci:delete("wireless",k,"wps")
				end
				uci:save("wireless")
				exe("uci rename wireless."..k.."=radio0")
			elseif v[".type"] == "wifi-iface" and k == "wifi0" then
				if v.device ~= "radio0" then
					uci:set("wireless",k,"device","radio0")
				end
				if v.network ~= "lan" then
					uci:set("wireless",k,"network","lan")
				end
				if v.ifname then
					uci:delete("wireless",k,"ifname")
				end
				if v.index then
					uci:delete("wireless",k,"index")
				end
				if v.isolate then
					uci:delete("wireless",k,"isolate")
				end
			else
				uci:delete("wireless",k)
			end
		end
	elseif (drv_str == "rt2860v2_ap" or drv_str == "rt2860v2_sta") and wireless.radio0 then
		flag = true
		for k,v in pairs(wireless) do
			if v[".type"] == "wifi-device" and k == "radio0" then
				if v.type ~= "mt7620a" then
					uci:set("wireless",k,"type","mt7620a")
				end
				uci:save("wireless")
				exe("uci rename wireless."..k.."=ra0")
			elseif v[".type"] == "wifi-iface" and k:match("wifi%d+") then
				if v.device ~= "ra0" then
					uci:set("wireless",k,"device","ra0")
				end
				if not v.ifname then
					uci:set("wireless",k,"ifname","ra"..k:match("wifi(%d+)"))
				end
				if not v.index then
					uci:set("wireless",k,"index",(tonumber(k:match("wifi(%d+)"))+1))
				end
			else
				uci:delete("wireless",k)
			end
		end
	end
	if flag then
		uci:save("wireless")
		uci:commit("wireless")
	end
end

--由于以前程序的bug，导致备份的数据缺项或者有错误，又或者配置有所变化，旧的配置不再适用，那么在加载旧的配置时，需要做下兼容性检查
function compatibility_check()
	compatibility_check_system_param()
	compatibility_check_fax()
	compatibility_check_callcontrol_param()
	compatibility_check_telnet()
	compatibility_check_featurecode_descriptioin()
	compatibility_check_fxo()
	compatibility_upnpc()
	compatibility_ringback()
	compatibility_ddns()
	compatibility_check_sip_profile()
	compatibility_vpn()
	compatibility_check_mwan3()
	compatibility_check_dhcp()
	compatibility_check_network_route()
	compatibility_check_smsroute_data()
	compatibility_check_route_data()
	compatibility_check_mobile_endpoint()
	compatibility_check_wireless()
	if fs.access("/etc/freeswitch/conf/dialplan/public/00_test_product.xml") then
		os.execute("rm /etc/freeswitch/conf/dialplan/public/00_test_product.xml")
	end
	if fs.access("/etc/freeswitch/conf/dialplan/public/call_waiting.xml") then
		os.execute("rm /etc/freeswitch/conf/dialplan/public/call_waiting.xml")
	end
	if fs.access("/etc/freeswitch/conf/dialplan/public/IVR.xml") then
		os.execute("rm /etc/freeswitch/conf/dialplan/public/IVR.xml")
	end
	if fs.access("/etc/freeswitch/conf/dialplan/public/feature_code.xml") then
		os.execute("rm /etc/freeswitch/conf/dialplan/public/feature_code.xml")
	end

	featurecode_check()
	move_uci_changes_log()
end

compatibility_check()
