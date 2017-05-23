module("luci.controller.admin.other", package.seeall)

function index()
	local uci = require "luci.model.uci".cursor()
	local lang = uci:get("luci","main","lang") or "en"
	local title_str = ""
	if lang == "zh_cn" then
		title_str = "上传话单"
	else
		title_str = "Upload CDR"
	end

	entry({"admin","system","upload_cdr"},cbi("admin_system/uploadcdr"), title_str ,20)
end
