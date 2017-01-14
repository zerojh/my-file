module("luci.controller.admin.detailset",package.seeall)

local fs = require "luci.fs"
local fs_server = require "luci.scripts.fs_server"
local util = require "luci.util"

function index()
	if luci.http.getenv("SERVER_PORT") == 80 or luci.http.getenv("SERVER_PORT") == 443 or luci.http.getenv("SERVER_PORT") == 8848 then
		local uci = require "luci.model.uci".cursor()

		entry({"admin","detailset"},firstchild(),"配置",83).index = true
		entry({"admin","detailset","network"},cbi("admin_detailset/net_access"),"上网设置",10).leaf = true
		entry({"admin","detailset","wifilist"},call("action_get_wireless"))
		entry({"admin","detailset","siptrunk"},cbi("admin_detailset/siptrunk"),"通讯调度平台",20).leaf = true
		--entry({"admin","detailset","sim"},cbi("admin_detailset/sim"),"SIM卡",30).leaf = true
		if uci:get("wireless","wifi0","mode") ~= "sta" then
			entry({"admin","detailset","ap"},cbi("admin_detailset/wlan_ap"),"无线热点",40).leaf = true
		end
		entry({"admin","detailset","ddns"},cbi("admin_detailset/ddns"),"动态域名服务",50).leaf = true
		entry({"admin","detailset","vpn"}, alias("admin","detailset","vpn","pptp"),"VPN客户端",60)
		entry({"admin","detailset","vpn","pptp"},cbi("admin_detailset/pptp_client"),"PPTP",60).leaf = true
		entry({"admin","detailset","vpn","l2tp"},cbi("admin_detailset/l2tp_client"),"L2TP",61).leaf = true
		entry({"admin","detailset","vpn","openvpn"},call("action_openvpn"),"OpenVPN",62).leaf = true
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
	local sys = require "luci.sys"
	local ds = require "luci.dispatcher"
	local uci = require "luci.model.uci".cursor()
	local uci_tmp  = require "luci.model.uci".cursor("/tmp/config")
	local destfile = "/tmp/my-vpn.conf.latest"

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

	local status = luci.http.formvalue("status")
	if status then
		local profile_wan_section
		local tmp_tb = uci:get_all("profile_sip") or {}
		if next(tmp_tb) then
			for k,v in pairs(tmp_tb) do
				if v.index and v.index == "2" then
					profile_wan_section = k
				end
			end
		end

		if status == "1" then
			uci:set("openvpn","custom_config","enabled","1")
			uci:set("xl2tpd","main","enabled","0")
			uci:set("pptpc","main","enabled","0")
			uci:set("vpnselect","vpnselect","vpntype","openvpn")
			if profile_wan_section then
				uci:set("profile_sip",profile_wan_section,"localinterface","OpenVPN")
			end
		else
			local last_vpn_type = uci:get("vpnselect","vpnselect","vpntype")
			if not last_vpn_type or last_vpn_type == "openvpn" then
				uci:set("vpnselect","vpnselect","vpntype","disabled")
				if profile_wan_section then
					uci:set("profile_sip",profile_wan_section,"localinterface","WAN")
				end
			end
			uci:set("openvpn","custom_config","enabled","0")
		end
		uci:save("openvpn")
		uci:save("xl2tpd")
		uci:save("pptpc")
		uci:save("profile_sip")
		uci:save("vpnselect")
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

