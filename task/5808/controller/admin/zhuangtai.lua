module("luci.controller.admin.zhuangtai",package.seeall)

function index()
	local page
	page = node("admin","zhuangtai")
	page.target = firstchild()
	page.title = ("状态")
	page.order = 99
	page.index = true

	entry({"admin","zhuangtai","overview"},template("admin_zhuangtai/index"),"总览",10).leaf = true

	entry({"admin", "denglu"}, call("action_logout"), "登出", 200)
end

function action_logout()
	local dsp = require "luci.dispatcher"
	local sauth = require "luci.sauth"
	if dsp.context.authsession then
		sauth.kill(dsp.context.authsession)
		dsp.context.urltoken.stok = nil
	end

	luci.http.header("Set-Cookie", "sysauth=; path=" .. dsp.build_url())
	luci.http.redirect(luci.dispatcher.build_url())
end
