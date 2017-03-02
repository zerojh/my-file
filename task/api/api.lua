module("luci.controller.api.api", package.seeall)

function index()
	node("api")
	entry({"api", "test"}, call("action_test"))
	entry({"api", "cdr"}, call("action_cdrs"))
end

function action_test()
	local info = {"hello world"}

	luci.http.prepare_content("application/json")
	luci.http.write_json(info)
end

function action_cdrs()
	local fs  = require "luci.fs"
	local sys = require "luci.sys"
	local sqlite = require "luci.scripts.sqlite3_service"
	
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
