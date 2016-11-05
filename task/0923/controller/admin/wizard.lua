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
	entry({"admin","wizard","5","openvpn"},call("action_openvpn"),_("Openvpn"),52)
end

function action_first_page()

	if luci.http.formvalue("action") then
		local action = luci.http.formvalue("action")
		local tb = luci.http.formvaluetable("table")
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
