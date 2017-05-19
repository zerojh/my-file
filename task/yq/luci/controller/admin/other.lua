module("luci.controller.admin.other", package.seeall)

function index()
	local uci = require "luci.model.uci".cursor()
	local lang = uci:get("oem","general","lang") or "en"
	local str = ""
	if str == "cn" then
		str = "上传话单"
	else
		str = "Upload CDR"
	end

	entry({"admin","system","upload_cdr"},cbi("admin_system/cdr_url"), str ,20)
end
