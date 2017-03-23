module("luci.controller.admin.wizard",package.seeall)

local fs = require "luci.fs"
local fs_server = require "luci.scripts.fs_server"
local util = require "luci.util"
local ds = require "luci.dispatcher"

function index()
	if luci.http.getenv("SERVER_PORT") == 80 or luci.http.getenv("SERVER_PORT") == 443 or luci.http.getenv("SERVER_PORT") == 8848 then
		local uci = require "luci.model.uci".cursor()
		entry({"admin","wizard"},template("admin_wizard/wizard"),"配置向导",82)
		entry({"admin","wizard","wifilist"},call("action_get_wireless"))
		entry({"admin","wizard","network"},cbi("admin_wizard/net_access")).leaf = true
		entry({"admin","wizard","siptrunk"},cbi("admin_wizard/siptrunk")).leaf = true
		--entry({"admin","wizard","sim"},cbi("admin_wizard/sim")).leaf = true
		entry({"admin","wizard","sim"},call("action_sim")).leaf = true
		if uci:get("wireless","wifi0","mode") ~= "sta" then
			entry({"admin","wizard","ap"},cbi("admin_wizard/wlan_ap")).leaf = true
		end
		entry({"admin","wizard","ddns"},cbi("admin_wizard/ddns")).leaf = true
		entry({"admin","wizard","vpn"},template("admin_wizard/vpn")).leaf = true
		entry({"admin","wizard","pptp"},cbi("admin_wizard/pptp_client")).leaf = true
		entry({"admin","wizard","l2tp"},cbi("admin_wizard/l2tp_client")).leaf = true
		entry({"admin","wizard","openvpn"},call("action_openvpn")).leaf = true
		local page = entry({"admin","wizard","changes"},call("action_changes"))
		page.query = {redir=redir}
		page.leaf = true
	end
end

function action_changes()
	local fs = require "nixio.fs"
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
	luci.template.render("admin_wizard/changes", {
		changes = next(changes) and changes,
		network = network,
		upgrading = fs.access("/tmp/upgrading_flag"),
	})
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

function action_openvpn()
	local uci = require "luci.model.uci".cursor()
	local uci_tmp = require "luci.model.uci".cursor("/tmp/config")
	local destfile = "/tmp/my-vpn.conf.latest"
	local flag = uci_tmp:get("wizard","globals","openvpn") or "1"

	if not fs.access("/etc/config/vpnselect") then
		util.exec("touch /etc/config/vpnselect")
	end

	if not uci:get("vpnselect","vpnselect") then
		uci:section("vpnselect","select","vpnselect")
		uci:save("vpnselect")
		uci:commit("vpnselect")
	end

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
		local profile_wan_section
		local tmp_tb = uci:get_all("profile_sip") or {}
		if next(tmp_tb) then
			for k,v in pairs(tmp_tb) do
				if v.index and v.index == "2" then
					profile_wan_section = k
				end
			end
		end

		if status and  status == "1" then
			uci:set("xl2tpd","main","enabled","0")
			uci:set("pptpc","main","enabled","0")
			uci:set("openvpn","custom_config","enabled","1")
			uci:set("vpnselect","vpnselect","vpntype","openvpn")
			if profile_wan_section then
				uci:set("profile_sip",profile_wan_section,"localinterface","OpenVPN")
			end
		else
			local last_vpn_type = uci:get("vpnselect","vpnselect","vpntype") or uci_tmp:get("vpnselect","vpnselect","vpntype")
			if not last_vpn_type or last_vpn_type == "openvpn" then
				uci:set("vpnselect","vpnselect","vpntype","disabled")
				if profile_wan_section then
					uci:set("profile_sip",profile_wan_section,"localinterface","WAN")
				end
			end
			uci:set("openvpn","custom_config","enabled","0")
		end

		local key = luci.http.formvalue("key")
		if key and #key > 0 then
			uci:set("openvpn","custom_config","key_change","0"==uci:get("openvpn","custom_config","key_change") and "1" or "0")
		end

		if not uci:get("openvpn","custom_config","defaultroute") then
			uci:set("openvpn","custom_config","defaultroute","0")
		end

		uci:save("openvpn")
		uci:save("xl2tpd")
		uci:save("pptpc")
		uci:save("profile_sip")
		uci:save("vpnselect")
		uci_tmp:set("wizard","globals","openvpn","1")
		uci_tmp:save("wizard")
		uci_tmp:commit("wizard")

		luci.http.redirect(ds.build_url("admin","wizard","changes"))
		return
	elseif luci.http.formvalue("cancel") then
		luci.http.redirect(ds.build_url("admin","wizard","vpn"))
	else
		luci.template.render("admin_wizard/openvpn",{
			status = flag == "1" and uci:get("openvpn","custom_config","enabled") or "0"
		})
	end
end

function action_sim()
	local fs = require "luci.fs"
	local uci = require "luci.model.uci".cursor()
	local uci_tmp = require "luci.model.uci".cursor("/tmp/config")
	local ds = require "luci.dispatcher"
	local i18n = require "luci.i18n"
	local util = require "luci.util"
	local numberlearning_section
	local mobile_section
	local enable_value="0"
	local idx_value=1
	local name_value="1"
	local type_value="sms"
	local destination_number_value=""
	local send_text_value=""
	local from_number_value=""
	local keywords_value=""
	local flag = uci_tmp:get("wizard","globals","sim") or "1"

	uci:check_cfg("profile_numberlearning")
	numberlearning_section = uci:get("profile_numberlearning","1")
	if not section then
		numberlearning_section = uci:section("profile_numberlearning","rule","1")
		uci:save("profile_numberlearning")
	end

	for k,v in pairs(uci:get_all("endpoint_mobile") or {}) do
		if v.slot_type and (v.slot_type == "1-GSM" or v.slot_type == "1-LTE") then
			enable_value = v.numberlearning_profile or "0"
			mobile_section = k
			break
		end
	end

	if luci.http.formvalue("save") and mobile_section and numberlearning_section then
		enable_value = luci.http.formvalue("enable") or "0"
		destination_number_value = luci.http.formvalue("profile_numberlearning."..numberlearning_section..".dest_number") or ""
		send_text_value = luci.http.formvalue("profile_numberlearning."..numberlearning_section..".send_text") or ""
		from_number_value = luci.http.formvalue("profile_numberlearning."..numberlearning_section..".from_number") or ""
		keywords_value = luci.http.formvalue("profile_numberlearning."..numberlearning_section..".keywords") or ""
		if enable_value == "1" and destination_number_value ~= "" and send_text_value ~= "" and from_number_value ~= "" and keywords_value ~= "" then
			uci:set("profile_numberlearning",numberlearning_section,"dest_number",destination_number_value)
			uci:set("profile_numberlearning",numberlearning_section,"send_text",send_text_value)
			uci:set("profile_numberlearning",numberlearning_section,"from_number",from_number_value)
			uci:set("profile_numberlearning",numberlearning_section,"keywords",keywords_value)
			uci:set("profile_numberlearning",numberlearning_section,"index",idx_value)
			uci:set("profile_numberlearning",numberlearning_section,"name",name_value)
			uci:set("profile_numberlearning",numberlearning_section,"type",type_value)
			uci:set("endpoint_mobile",mobile_section,"numberlearning_profile","1")
		else
			uci:delete("profile_numberlearning",numberlearning_section)
			uci:set("endpoint_mobile",mobile_section,"numberlearning_profile","0")
		end
		uci:save("profile_numberlearning")
		uci:save("endpoint_mobile")

		flag = "1"
		uci_tmp:set("wizard","globals","ddns","1")
		uci_tmp:save("wizard")
		uci_tmp:commit("wizard")
		if uci:get("wireless","wifi0","mode") ~= "sta" then
			luci.http.redirect(ds.build_url("admin","wizard","ap"))
		else
			luci.http.redirect(ds.build_url("admin","wizard","ddns"))
		end
		return
	elseif luci.http.formvalue("cancel") and mobile_section and numberlearning_section then
		luci.http.redirect(ds.build_url("admin","wizard","siptrunk"))
		return
	end

	if flag == "1" then
		local tmp_tb=uci:get_all("profile_numberlearning",numberlearning_section) or {}
		name_value = tmp_tb.name or ""
		type_value = tmp_tb.type or ""
		destination_number_value = tmp_tb.dest_number or ""
		send_text_value = tmp_tb.send_text or ""
		from_number_value = tmp_tb.from_number or ""
		keywords_value = tmp_tb.keywords or ""
	else
		enable_value = "0"
	end

	luci.template.render("admin_wizard/sim",{
		need_redirect_back=next_redirect,
		enable_id="enable",
		destination_number_id="profile_numberlearning."..numberlearning_section..".dest_number",
		send_text_id="profile_numberlearning."..numberlearning_section..".send_text",
		from_number_id="profile_numberlearning."..numberlearning_section..".from_number",
		keywords_id="profile_numberlearning."..numberlearning_section..".keywords",
		enable_value=enable_value,
		destination_number_value=destination_number_value,
		send_text_value=send_text_value,
		from_number_value=from_number_value,
		keywords_value=keywords_value,
		})
end
