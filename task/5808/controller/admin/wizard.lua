module("luci.controller.admin.wizard",package.seeall)

local fs_server = require "luci.scripts.fs_server"
local util = require "luci.util"
local ds = require "luci.dispatcher"

function index()
	if luci.http.getenv("SERVER_PORT") == 8345 or luci.http.getenv("SERVER_PORT") == 8848 then
		local uci = require "luci.model.uci".cursor()
		entry({"admin","wizard"},template("admin_wizard/wizard"),"配置向导",82)
		entry({"admin","wizard","wifilist"},call("action_get_wireless"))
		entry({"admin","wizard","network"},cbi("admin_wizard/net_access")).leaf = true
		entry({"admin","wizard","siptrunk"},cbi("admin_wizard/siptrunk")).leaf = true
		entry({"admin","wizard","sim"},cbi("admin_wizard/sim")).leaf = true
		if uci:get("wireless","wifi0","mode") ~= "sta" then
			entry({"admin","wizard","ap"},cbi("admin_wizard/wlan_ap")).leaf = true
		end
		entry({"admin","wizard","ddns"},cbi("admin_wizard/ddns")).leaf = true
		entry({"admin","wizard","pptp"},cbi("admin_wizard/pptp_client")).leaf = true
		entry({"admin","wizard","l2tp"},cbi("admin_wizard/l2tp_client")).leaf = true
		entry({"admin","wizard","openvpn"},call("action_openvpn")).leaf = true
	end
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

		luci.http.redirect(ds.build_url("admin","status1","overview"))
		return
	elseif luci.http.formvalue("cancel") then
		luci.http.redirect(ds.build_url("admin","wizard","l2tp"))
	else
		luci.template.render("admin_wizard/openvpn",{
			status = flag == "1" and uci:get("openvpn","custom_config","enabled") or "0"
		})
	end
end

