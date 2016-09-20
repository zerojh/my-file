module("luci.controller.admin.status", package.seeall)

function index()
	entry({"admin", "status"}, alias("admin", "status", "overview"), _("Status"), 20).index = true
	entry({"admin", "status", "overview"}, template("admin_status/index"), _("Overview"), 1)
	entry({"admin", "status", "sipstatus"}, template("admin_status/sipstatus"), _("SIP"), 2)
	entry({"admin", "status", "pstnstatus"}, template("admin_status/pstnstatus"), _("PSTN"), 3)
	entry({"admin","status","client_list"},call("client_list"),_("DHCP Client List"),4).leaf = true
	entry({"admin", "status", "currentcall"}, template("admin_status/currentcall"), _("Current Call"), 5)
	entry({"admin", "status", "cdr"}, call("action_cdrs"), _("CDRs"), 6)
	entry({"admin", "status", "wireless"}, template("admin_status/wireless"),_("Wireless AP List"),7)
	entry({"admin", "status", "service"}, template("admin_status/service"),_("Service"),8)
	entry({"admin", "status", "about"}, template("admin_status/about"),_("About"),9)
	page = entry({"admin","status","getcdrs"},call("action_get_cdrs"),nil)
	page.leaf = true
end

function action_cdrs()
	local fs  = require "luci.fs"
	local sys = require "luci.sys"
	local sqlite = require "luci.scripts.sqlite3_service"
	
	if luci.http.formvalue("export") then
		local cdr_info = ""
		local cdrs_file = "/tmp/CDRs"
		local localip = luci.http.getenv("SERVER_ADDR")
		local first_flag = true
		local ret_tb = {}
		
		ret_tb = sqlite.sqlite3_execute("/etc/freeswitch/cdr","select * from cdr order by created_time")

		--write into file
		local _file = io.open("/tmp/cdrs.xls","w+")
		if _file then
			local title_flag = true
			for k,v in pairs(ret_tb) do
				cdr_info = ""
				if title_flag then
					for k2,v2 in pairs(v) do
						cdr_info = cdr_info..k2.."\t"
					end
					title_flag = false
					_file:write(cdr_info.."\n")
				end
				cdr_info = ""
				for k2,v2 in pairs(v) do
					cdr_info = cdr_info..v2.."\t"
				end
				_file:write(cdr_info.."\n")
			end
			_file:close()
		end

		sys.call("tar -cz /tmp/cdrs.xls -f "..cdrs_file)
		local reader = luci.ltn12.source.file(io.open(cdrs_file,"r"))
		luci.http.header('Content-Disposition', 'attachment; filename="CDRs-%s-%s-%s.tar.gz"' % {luci.sys.hostname(), localip, os.date("%Y-%m-%d")})
		luci.http.prepare_content("application/gzip")
		luci.ltn12.pump.all(reader, luci.http.write)
		fs.unlink(cdrs_file)	
		fs.unlink("/tmp/cdrs.xls")
	elseif luci.http.formvalue("empty") then
		local ret_tb = sqlite.sqlite3_execute("/etc/freeswitch/cdr","delete from cdr")	
		luci.template.render("admin_status/cdr")
	else
		luci.template.render("admin_status/cdr")
	end
end
function action_get_cdrs()
	require "luci.util"
	local sqlite = require "luci.scripts.sqlite3_service"
	local str = luci.http.formvalue("cmd")
	local page = luci.http.formvalue("page")
	local cdr_info = {}
	local sql_condition = ""
	local sql_limit = ""
	local sql_cmd = ""
	
	if page then
		sql_limit = " order by created_time desc limit "..tostring((tonumber(page)-1)*100)..",100"
	end

	if str ~= " " then
		local list = luci.util.split(str,",")
		for i,j in pairs(list) do
			if j ~= "" then
				if sql_condition == "" then
					sql_condition = j
				else
					sql_condition = sql_condition.." and "..j
				end
			end
		end
	end

	if sql_condition == "" then
		sql_cmd = "select * from cdr"..sql_limit
	else
		sql_cmd = "select * from cdr where "..sql_condition..sql_limit
	end
	
	cdr_info = sqlite.sqlite3_execute("/etc/freeswitch/cdr",sql_cmd)

	for k,v in pairs(cdr_info) do
		if v.start_epoch then
			v.start_epoch = os.date("%Y-%m-%d %H:%M:%S", v.start_epoch)
		end
		if v.end_epoch then
			v.end_epoch = os.date("%m-%d %H:%M:%S", v.end_epoch)
		end
	end	
	luci.http.prepare_content("application/json")
	luci.http.write_json(cdr_info)
	return
end
function client_list()
	local uci = require "luci.model.uci".cursor()
	local fs = require "luci.fs"
	local ds = require "luci.dispatcher"
	local i18n = require "luci.i18n"

	local th = {"ID","Client Name","MAC Address","IP Address","Expiration","Status"}
	local colgroup = {"6%","28%","16%","17%","18%","15%"}
	local content = {}
	local leases_file = "/tmp/dhcp.leases"
	local detect_data = "/tmp/dhcp.onlines"
	local time_now=tonumber(os.time())

	if fs.access(leases_file) then
		local data = io.open(detect_data,"r") or io.open("leases_file")
		local index = 1
		if data then
			for line in data:lines() do
				local tmp = {}
				local parse_tb = luci.util.split(line," ")
				if 0 == tonumber(parse_tb[1]) or tonumber(parse_tb[1]) > time_now then -- Hide the result which expired.
					tmp[1] = index
					tmp[2] = parse_tb[4] or ""
					tmp[3] = string.upper(parse_tb[2] or "")
					tmp[4] = parse_tb[3] or ""
					if 0 == tonumber(parse_tb[1]) then
						tmp[5] = i18n.translate("Never Expires")
					else
						tmp[5] = os.date("%Y-%m-%d %H:%M:%S",parse_tb[1])
					end
					tmp[6] = i18n.translate(parse_tb[6] or "Offline")
					index = index + 1
					table.insert(content,tmp)
				end
			end
		end
	end
	luci.template.render("cbi/configlist",{
		title = i18n.translate("Status / DHCP Client List"),
		colgroup = colgroup,
		th = th,
		content = content,
		addnewable = false,
		})
end
