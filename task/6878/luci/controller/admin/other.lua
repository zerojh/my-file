module("luci.controller.admin.other", package.seeall)

function index()
	entry({"admin", "ov"}, template("admin_other/index"), "Overview", 81).index = true

	entry({"admin", "wl"}, cbi("admin_other/wireless"), "Wireless", 82).index = true

	entry({"admin", "ts"}, call("action_troubleshooting"), "Troubleshooting", 83).index = true

	entry({"admin","system","led"},cbi("admin_system/led"),_("LED"),14)
end

function action_troubleshooting()
	local req_from = (luci.http.getenv("REMOTE_ADDR") or "")..":"..(luci.http.getenv("REMOTE_PORT") or "")

	if luci.http.formvalue("reboot") then
		local log_str = req_from.." | ".."Reboot /admin/ts/reboot"
		log.web_operation_log("Info",log_str)

		luci.template.render("admin_other/applyreboot", {
			msg   = luci.i18n.translate("Please wait: Device rebooting..."),
		})
		os.execute("sleep 2")
		luci.sys.reboot()
	elseif luci.http.formvalue("factory_reset") then
		local log_str = req_from.." | ".."Reset /admin/ts/factory_reset"
		log.web_operation_log("Info",log_str)

		luci.template.render("admin_other/applyreboot", {
			title = luci.i18n.translate("Erasing..."),
			msg   = luci.i18n.translate("The system is erasing the config data now and will reboot itself when finished."),
		})
		os.execute("lua /usr/lib/lua/luci/scripts/reset_default_config.lua")
		os.execute("sync && sleep 1")
		os.execute("reboot -f")
	else
		luci.template.render("admin_other/troubleshooting")
	end
end
