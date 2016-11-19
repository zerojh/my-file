module("luci.controller.admin.detailset",package.seeall)

local fs_server = require "luci.scripts.fs_server"
local util = require "luci.util"

function index()
	local page
	page = node("admin","detailset")
	page.target = firstchild()
	page.title = ("配置")
	page.order = 110
	page.index = true

	entry({"admin","detailset","network"},cbi("admin_detailset/net_access"),"上网设置",10).leaf = true
	entry({"admin","detailset","wifilist"},call("action_get_wireless"))
	entry({"admin","detailset","siptrunk"},cbi("admin_detailset/siptrunk"),"通讯调度平台",20).leaf = true
	entry({"admin","detailset","ddns"},cbi("admin_detailset/ddns"),"动态域名服务",30).leaf = true
	entry({"admin","detailset","vpn"}, alias("admin","detailset","vpn","pptp"),"VPN客户端",40)
	entry({"admin","detailset","vpn","pptp"},cbi("admin_detailset/pptp_client"),"PPTP",40).leaf = true
	entry({"admin","detailset","vpn","l2tp"},cbi("admin_detailset/l2tp_client"),"L2TP",41).leaf = true
	entry({"admin","detailset","vpn","openvpn"},call("action_openvpn"),"OpenVPN",42).leaf = true
	--entry({"admin","detailset","sim"},cbi("admin_detailset/sim"),"SIM",43).leaf = true
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

