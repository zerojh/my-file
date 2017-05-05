module("luci.controller.admin.url", package.seeall)

function index()
	-- local page
	-- page = node("admin","tirasoft")
	-- page.target = firstchild()
	-- page.title = _("Tirasoft")
	-- page.order = 90
	-- page.index = true
	-- entry({"admin", "tirasoft","pbx"}, call("call_nivada_pbx_cloud"), _("Nivada PBX Cloud"), 1)
	entry({"admin", "nw"}, call("call_nivada_pbx_cloud"), _("Network"), 100)
end

function call_nivada_pbx_cloud()
	local ds = require "luci.dispatcher"
	local uci = require "luci.model.uci".cursor()

	local url = uci:get("system","main","outdoor_url") or ""
	if luci.http.formvalue("save") then
		url = luci.http.formvalue("outdoor_url")
		if not url:match("^http") then
			url="http://"..url
		end
		uci:set("system","main","outdoor_url",url)
		uci:save("system")
		luci.http.redirect(ds.build_url("admin","uci","saveapply"))
		return
	end
	if luci.http.formvalue("status") then
		luci.http.prepare_content("text/plain")
		luci.http.write("")
		return
	end
	luci.template.render("admin_other/outdoor_url",{url=url,https=url:match("^https://")})
end
