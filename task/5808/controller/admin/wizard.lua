module("luci.controller.admin.wizard",package.seeall)

function index()
	local page
	page = node("admin","wizard")
	page.target = firstchild()
	page.title = ("Setup Wizard")
	page.order = 100
	page.index = true

	entry({"admin","wizard","1"},template("admin_wizard/wizard"),_("Setup Wizard"),1).leaf = true
	--entry({"admin","wizard","netmode"},call("action_first_page"))
	entry({"admin","wizard","2"},cbi("admin_wizard/net_access"),_("2"),2).leaf = true
	entry({"admin","wizard","3"},cbi("admin_wizard/siptrunk"),_("3"),3).leaf = true
	entry({"admin","wizard","4"},cbi("admin_wizard/ddns"),_("4"),4).leaf = true
	entry({"admin","wizard","5"}, alias("admin","wizard","5","pptp"),_("5"),5)
	entry({"admin","wizard","5","pptp"},cbi("admin_wizard/pptp_client"),_("PPTP"),50).leaf = true
	entry({"admin","wizard","5","l2tp"},cbi("admin_wizard/l2tp_client"),_("L2TP"),51).leaf = true
	entry({"admin","wizard","5","openvpn"},call("action_openvpn"),_("Openvpn"),52).leaf = true
	entry({"admin","wizard","6"},template("admin_wizard/first_detect"),("first detect"),6)

	entry({"admin","wizard","7"},call("action_get_wireless"))
	entry({"admin","wizard","8"},call("first_detect_status"))
	entry({"admin","wizard","9"},call("action_first_detect"))
end

function action_get_wireless()
	local fs_server = require "luci.scripts.fs_server"
	local util = require "luci.util"

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

function first_detect_status()
	local status = nixio.fs.readfile("/tmp/detect_status")

	if status then
		luci.http.write(status)
	else
		luci.http.write("No data\n")
	end
end

function action_first_detect()
	local fs_server = require "luci.scripts.fs_server"
	local ubus_get_addr = require "luci.model.network".ubus_get_addr
	local uci = require "luci.model.uci".cursor()
	local util = require "luci.util"
	local exe = require "os".execute
	local fs = require "nixio.fs"
	local access_mode = uci:get("network_tmp","network","access_mode") or "wired_static"
	local wan_ipaddr,wan_netmask,wan_gateway,wan_dns =  ubus_get_addr("wan")
	local wan_dns_tb = util.split(wan_dns," ") or {}
	local str_suc = "OK="

	exe("rm /tmp/detect_status")

	-- ping local ipaddr
	if wan_ipaddr and wan_ipaddr ~= "" and wan_ipaddr ~= "0.0.0.0" then
		local result = util.exec("ping -c 5 -W 1 2>&1 "..wan_ipaddr.." | grep 'loss'")
		result = result:match("(%d+)%%")
		if result and result ~= "" and result ~= "100" then
			str_suc = str_suc.."ipaddr"
			fs.writefile("/tmp/detect_status","Access Mode="..access_mode..","..str_suc.."\n")
		else
			fs.writefile("/tmp/detect_status","Access Mode="..access_mode..",Error=ipaddr\n")
			return
		end
	else
		fs.writefile("/tmp/detect_status","Access Mode="..access_mode..",Error=ipaddr\n")
		return
	end

	-- ping gateway
	if wan_gateway and wan_gateway ~= "" and wan_gateway ~= "0.0.0.0" then
		local result = util.exec("ping -c 5 -W 1 2>&1 "..wan_gateway.." | grep 'loss'")
		result = result:match("(%d+)%%")
		if result and result ~= "" and result ~= "100" then
			str_suc = str_suc..",gateway"
			fs.writefile("/tmp/detect_status","Access Mode="..access_mode..","..str_suc.."\n")
		else
			fs.writefile("/tmp/detect_status","Access Mode="..access_mode..",Error=gateway\n")
			return
		end
	else
		fs.writefile("/tmp/detect_status","Access Mode="..access_mode..",Error=gateway\n")
		return
	end

	-- ping dns
	if wan_dns_tb and next(wan_dns_tb) then
		local loop_num = 0
		for k,v in pairs(wan_dns_tb) do
			if v and v ~= "" then
				local result = util.exec("ping -c 5 -W 1 2>&1 "..v.." | grep 'loss'")
				result = result:match("(%d+)%%")
				if result and result ~= "" and result ~= "100" then
					str_suc = str_suc..",dns"
					fs.writefile("/tmp/detect_status","Access Mode="..access_mode..","..str_suc.."\n")
					break
				end
			end
			loop_num = loop_num + 1
		end
		if loop_num == #wan_dns_tb then
			fs.writefile("/tmp/detect_status","Access Mode="..access_mode..",Error=dns\n")
			return
		end
	else
		fs.writefile("/tmp/detect_status","Access Mode="..access_mode..",Error=dns\n")
		return
	end

	-- ping baidu
	local result = util.exec("ping -c 5 -W 1 2>&1 www.baidu.com | grep 'loss'")
	result = result:match("(%d+)%%")
	if result and result ~= "" and result ~= "100" then
		str_suc = str_suc..",baidu"
		fs.writefile("/tmp/detect_status","Access Mode="..access_mode..",Finish\n")
	else
		fs.writefile("/tmp/detect_status","Access Mode="..access_mode..",Error=baidu\n")
	end
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

	if luci.http.formvalue("save") then
		uci:set("openvpn","custom_config","defaultroute","0")
	end

	local status = luci.http.formvalue("status")
	if status then
		uci:set("openvpn","custom_config","enabled",status)
		uci:save("openvpn")
	end

	status = uci:get("openvpn","custom_config","enabled")

	if luci.http.formvalue("key") then
		local key = luci.http.formvalue("key")
		if key and #key > 0 then
			uci:set("openvpn","custom_config","key_change","0"==uci:get("openvpn","custom_config","key_change") and "1" or "0")
			uci:save("openvpn")
			luci.template.render("admin_wizard/openvpn",{
				result = "upload succ",
				status = status,
			})
		else
			luci.template.render("admin_wizard/openvpn",{
				status = uci:get("openvpn","custom_config","enabled"),
			})
		end
	else
		luci.template.render("admin_wizard/openvpn",{
			status = status,
		})
	end
end
