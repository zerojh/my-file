module("luci.controller.admin.other", package.seeall)

function index()
	entry({"admin", "ov"}, template("admin_other/index"), "Overview", 81).index = true

	entry({"admin", "wl"}, template("admin_other/index_template"), "Wireless", 82).index = true

	entry({"admin", "ts"}, template("admin_other/index_template"), "Troubleshooting", 83).index = true

	entry({"admin", "nw"}, template("admin_other/index_template"), "Network", 84).index = true
end
