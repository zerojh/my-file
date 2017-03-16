module("luci.controller.admin.uci", package.seeall)

function index()
	local redir = luci.http.formvalue("redir", true) or
	luci.dispatcher.build_url(unpack(luci.dispatcher.context.request))

	entry({"admin", "uci"}, nil, _("Configuration"))
	entry({"admin", "uci", "changes"}, call("action_changes"), _("Changes"), 40).query = {redir=redir}
	entry({"admin", "uci", "revert"}, call("action_revert"), _("Revert"), 30).query = {redir=redir}
	entry({"admin", "uci", "saveapply"}, call("action_apply"), _("Save &#38; Apply"), 10).query = {redir=redir}
end

function action_changes()
	local uci = luci.model.uci.cursor()
	local changes = uci:changes()
	local network

	for r,tbl in pairs(changes) do
		if tbl.lan then
			if tbl.lan.proto or tbl.lan.ipaddr or tbl.lan.netmask then
				network = true
			end
		end
	end
	luci.template.render("admin_uci/changes", {
		changes = next(changes) and changes,
		network = network
	})
end

function add_to_dst(dst,src)
	if src then
		if not dst or "" == dst then
			dst = src..","
		end
		if not string.find(dst,src..",") then
			dst = dst .. src .. ","
		end
	end
	return dst
end

function get_profile_by_gw(gw_index)
	local uci = require "luci.model.uci".cursor()
	local trunk = uci:get_all("endpoint_siptrunk")

	for k,v in pairs(trunk) do
		if v.index and v.index == gw_index then
			return v.profile
		end
	end
	return ""
end

function action_apply()
	local path = luci.dispatcher.context.path
	local uci = luci.model.uci.cursor()
	local changes = uci:changes()
	local fs = require "nixio.fs"
	local reload = {}
	local luascripts = require "luci.scripts.luci_load_scripts"

	for r,tbl in pairs(changes) do
		--@ check unuseful and delete
		for s,o in pairs(tbl) do
			if o[".type"] and o[".type"] ~= "" and o['.type'] ~= "menu" then
				local cnt = 0
				for i,j in pairs(o) do
					if i and j then
						cnt = cnt + 1
						if cnt > 1 then
							break
						end
					end
				end
				
				if cnt < 2 then
					uci:delete(r,s)
					uci:save(r)
				end
			end
		end	
	end
	
	-- Collect files to be applied and commit changes
	for r, tbl in pairs(changes) do
		table.insert(reload, r)
	end

	local apply_param = {}
	--@ call lua scripts
	for r,tbl in pairs(changes) do

		if "profile_codec" == r then
			apply_param.sipprofile = "on"
			apply_param.extension = "on"
			apply_param.route = "on"
			local codec = uci:get_all("profile_codec")
			local sip_profile = uci:get_all("profile_sip")
			for s,o in pairs(tbl) do
				for k,v in pairs(codec) do
					if s == k then
						for i,j in pairs(sip_profile) do
							if v.index == j.inbound_codec_prefs or v.index == j.outbound_codec_prefs then
								apply_param.profile_changes = add_to_dst(apply_param.profile_changes,j.index)
							end
						end
					end
				end
			end
		--elseif "profile_fax" == r then
			--apply_param.sipprofile = "on"
			--apply_param.route = "on"
		elseif "profile_dialplan" == r then
			apply_param.fxso = "on"
		elseif "profile_sip" == r then
			apply_param.sipprofile = "on"
			apply_param.extension = "on"
			apply_param.route = "on"
			apply_param.firewall = "on"
			local sip_profile = uci:get_all("profile_sip")
			for s,o in pairs(tbl) do
				for k,v in pairs(sip_profile) do
					if s == k then
						apply_param.profile_changes = add_to_dst(apply_param.profile_changes,v.index)
					end
				end
			end
		elseif "endpoint_siptrunk" == r then
			apply_param.sipprofile = "on"
			apply_param.sipendpoint = "on"
			apply_param.route = "on"
			apply_param.routegrp = "on"
			apply_param.extension = "on"
			local sip_profile = uci:get_all("profile_sip")
			local sip_trunk = uci:get_all("endpoint_siptrunk")
			for s,o in pairs(tbl) do
				for k,v in pairs(sip_trunk) do
					if s == k then
						for i,j in pairs(sip_profile) do
							if v.profile == j.index then
								apply_param.profile_changes = add_to_dst(apply_param.profile_changes,j.index)
								apply_param.endpoint_changes = add_to_dst(apply_param.endpoint_changes,v.index)
							end
						end
					end
				end
			end
		elseif "endpoint_sipphone" == r then
			apply_param.extension = "on"
			apply_param.sipextension = "on"
			apply_param.ringgrp = "on"
			apply_param.routegrp = "on"
			apply_param.route = "on"
		elseif "endpoint_mobile" == r then
			apply_param.mobile = "on"
		elseif "endpoint_fxso" == r or "profile_fxso" == r then
			apply_param.fxso = "on"
			apply_param.extension = "on"
			apply_param.ringgrp = "on"
			apply_param.routegrp = "on"
			apply_param.route = "on"
			if "endpoint_fxso" == r then
				for k,v in pairs(tbl) do
					if v.number_1 or v.number_2 then
						apply_param.sipendpoint = "on"
						apply_param.sipprofile = "on"
					end
					if v.port_1_reg or v.port_2_reg or v.port_1_server_1 or v.port_1_server_2 or v.port_2_server_1 or v.port_2_server_2 then
						apply_param.sipendpoint = "on"
						if v.port_1_server_1 or v.port_1_server_2 or v.port_2_server_1 or v.port_2_server_2 then
							local sip_trunk = uci:get_all("endpoint_siptrunk")
							for i,j in pairs(sip_trunk) do
								if j.index and j.index == v.port_1_server_1 or j.index == v.port_1_server_2 or j.index == v.port_2_server_1 or j.index == v.port_2_server_2 then
									apply_param.profile_changes = add_to_dst(apply_param.profile_changes,get_profile_by_gw(j.index))
									apply_param.endpoint_changes = add_to_dst(apply_param.endpoint_changes,j.index)
								end
							end
						end
					end
					if v.port_1_password or v.username_1 or v.authuser_1 or v.from_username_1 or v.reg_url_with_transport_1 or v.expire_seconds_1 or v.retry_seconds_1 then
						apply_param.sipendpoint = "on"
						apply_param.profile_changes = add_to_dst(apply_param.profile_changes,get_profile_by_gw(v.port_1_server_1))
						apply_param.profile_changes = add_to_dst(apply_param.profile_changes,get_profile_by_gw(v.port_1_server_2))
					end
					if v.port_2_password or v.username_2 or v.authuser_2 or v.from_username_2 or v.reg_url_with_transport_2 or v.expire_seconds_2 or v.retry_seconds_2 then
						apply_param.sipendpoint = "on"
						apply_param.profile_changes = add_to_dst(apply_param.profile_changes,get_profile_by_gw(v.port_2_server_1))
						apply_param.profile_changes = add_to_dst(apply_param.profile_changes,get_profile_by_gw(v.port_2_server_2))
					end
					if v['.type'] and v['.type'] ~= "" then
						apply_param.sipprofile = "on"
						apply_param.sipendpoint = "on"
					end
				end
		    end
		elseif "feature_code" == r then
			apply_param.featurecode = "on"
			apply_param.extension = "on"
			apply_param.ringgrp = "on"
		elseif "ivr" == r then
			apply_param.ivr = "on"
			apply_param.route = "on"
		elseif "endpoint_ringgroup" == r then
			apply_param.ringgrp = "on"
			apply_param.route = "on"
			apply_param.extension = "on"
		elseif "endpoint_routegroup" == r then
			apply_param.routegrp = "on"
			apply_param.route = "on"
		elseif "profile_time" == r or "profile_number" == r or "profile_manipl" == r or "route" == r then
			apply_param.extension = "on"
			apply_param.route = "on"
		elseif "provision" == r then
			apply_param.provision = "on"
		elseif "callcontrol" == r then
			apply_param.extension = "on"
			if tbl.voice and tbl.voice.nortp then
				apply_param.fxso = "on"
			end
			if tbl.voice and (tbl.voice.rtp_start_port or tbl.voice.rtp_end_port) then
				apply_param.rtp = "on"
				apply_param.firewall = "on"
				os.execute("echo rtp >>/tmp/require_reboot")
			end
			if tbl.voice and tbl.voice.featurecode then
				apply_param.featurecode = "on"
			end
		elseif "fax" == r then
			apply_param.fax = "on"
		elseif "system" == r then
			--if tbl.log then
			--	apply_param.log = "on"
			--end
			if tbl.main and tbl.main.mod_cdr then
				apply_param.cdr = tbl.main.mod_cdr
			end
			if tbl.main and tbl.main.lang then
				apply_param.featurecode = "on"
				apply_param.ivr = "on"
			end
			if tbl.main and ( tbl.main.log_level or tbl.main.log_ip or tbl.main.log_port ) then
				apply_param.log = "on"
			end
			if tbl.telnet and tbl.telnet.action then
				apply_param.telnet_action = tbl.telnet.action
			end
			if tbl.telnet and tbl.telnet.port then
				apply_param.telnet_port = "on"
				apply_param.firewall = "on"
			end
			if tbl.main and tbl.main.localcall then
				apply_param.extension = "on"
			end
		elseif "network" == r then
			apply_param.network = "on"
			apply_param.sipprofile = "on"
			apply_param.sipendpoint = "on"
			apply_param.firewall = "on"
			apply_param.dns = "on"
			--apply_param.wireless = "on"
			for k,v in pairs(tbl) do
				--@ wan subinterface
				if k:match("^vwan") then
					apply_param.wansub = "on"
					apply_param.vlan = "on"
				elseif v.vid or k:match("^vlan") then
					apply_param.vlan = "on"
				elseif "wan" == k then
					for kk,vv in pairs(v) do
						if "mtu"==kk then
							apply_param.mtu="on"
							uci:set("network","eth1","mtu",vv)
							uci:save("network")
							uci:commit("network")
						elseif "wan_switch" == kk then
							os.execute("echo wan_switch >>/tmp/require_reboot")
						end
					end
				elseif "route" == v["name"] then
					apply_param.mwan3 = "on"
				end
			end
			--@ static route
			apply_param.static_route = "on"
		elseif "dhcp" == r then
			apply_param.dhcp = "on"
			apply_param.arp = "on"
		elseif "attack" == r then
			apply_param.attack = "on"
		elseif "dropbear" == r then
			apply_param.ssh = "on"
			apply_param.firewall = "on"
		elseif "lucid" == r then
			apply_param.webserver = "on"
			apply_param.firewall = "on"
		elseif "firewall" == r then
			apply_param.firewall = "on" 
			apply_param.nat = "on"
			for k,v in pairs(tbl) do
				if v.tmp_mac then
					apply_param.mac_filter = "on"
					break
				end
			end
			apply_param.mwan3 = "on"
		elseif "ddns" == r then
			apply_param.ddns = "on"
		elseif "mwan3" == r then
			apply_param.mwan3 = "on"
		elseif "qos" == r then
			apply_param.qos = "on"
		elseif "gre" == r then
			apply_param.gre = "on"
		elseif "openvpn" == r then
			apply_param.openvpn = "on"
			apply_param.firewall = "on"
		elseif "xl2tpd" == r then
			apply_param.xl2tpd = "reload"
			if tbl.l2tpd or tbl.main then
				apply_param.xl2tpd = "restart"
				apply_param.firewall = "on"
			end
		elseif "pptpd" == r then
			apply_param.pptpd = "reload"
			if tbl.pptpd then
				apply_param.pptpd = "restart"
				apply_param.firewall = "on"
			end
		elseif "pptpc" == r then
			apply_param.pptpc = "on"
		elseif "ipsec" == r then
			apply_param.ipsec = "on"
		elseif "profile_portal" == r then
			--@ modify user
			apply_param.portal_update = "on"
		elseif "portal" == r then
			apply_param.portal_update = "on"
			for k,v in pairs(tbl) do
				if v.enabled then
					apply_param.portal_restart = "on"
					break
				end
			end
		elseif "wireless" == r then
			apply_param.wireless = "on"
		elseif "cloud" == r then
			apply_param.cloud = "on"
		elseif "autovpn" == r then
			apply_param.autovpn ="on"
		elseif "domainlist_tmp" == r then
			apply_param.domainlist="on"
		elseif "alg" == r then
			apply_param.alg="on"
		end
	end

	luci.template.render("admin_uci/apply", {
		changes = next(changes) and changes,
		configs = reload,
		webserver = apply_param.webserver,
		action = "apply",
	})
	luascripts.load_scripts(apply_param)
	if fs.access("/ramlog/uci_changes_log") then
		local size=fs.stat("/ramlog/uci_changes_log","size")
		if size > 100000 then
			os.execute("mv /ramlog/uci_changes_log /ramlog/uci_changes_log.0")
			os.execute("cat /tmp/uci_changes_log_temp > /ramlog/uci_changes_log")
		else
			local old = fs.readfile("/ramlog/uci_changes_log")
			local new = fs.readfile("/tmp/uci_changes_log_temp")
			fs.writefile("/ramlog/uci_changes_log",new.."\n\n"..old)
		end
	else
		os.execute("cat /tmp/uci_changes_log_temp >> /ramlog/uci_changes_log")
	end
end


function action_revert()
	local uci = luci.model.uci.cursor()
	local changes = uci:changes()

	-- Collect files to be reverted
	for r, tbl in pairs(changes) do
		uci:load(r)
		uci:revert(r)
		uci:unload(r)
	end

	luci.template.render("admin_uci/revert", {
		changes = next(changes) and changes,
		action = "revert",
	})
end
