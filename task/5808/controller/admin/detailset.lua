module("luci.controller.admin.detailset",package.seeall)

function index()
	local page
	page = node("admin","detailset")
	page.target = firstchild()
	page.title = ("设置")
	page.order = 110
	page.index = true

	entry({"admin","detailset",""},cbi("admin_detailset/"),"",1).leaf = true
end


