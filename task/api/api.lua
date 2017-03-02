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
	local data_type = luci.http.formvalue("type") or "json"
	local str = luci.http.formvalue("cmd") or ""
	local query_str = ""

	-- optional data
	local cdr_caller_id_number
	local cdr_destination_number
	local cdr_source
	local cdr_destination
	local cdr_billsec
	local cdr_start_epoch
	local cdr_end_epoch
	if str ~= "" then
		local list = luci.util.split(str,",") or {}
		for i,j in pairs(list) do
			if j:match("caller_id_number%s*=") then
				cdr_caller_id_number = j:match("caller_id_number%s*=%s*([^%s]+)")
			elseif j:match("destination_number%s*=") then
				cdr_destination_number = j:match("destination_number%s*=%s*([^%s]+)")
			elseif j:match("source%s*=") then
				cdr_source = j:match("source%s*=%s*([^%s]+)")
			elseif j:match("destination%s*=") then
				cdr_destination = j:match("destination%s*=%s*([^%s]+)")
			elseif j:match("min_billsec%s*=") then
				cdr_billsec = j:match("min_billsec%s*=%s*([^%s]+)")
			elseif j:match("max_billsec%s*=") then
				cdr_billsec = j:match("max_billsec%s*=%s*([^%s]+)")
			elseif j:match("start_epoch%s*=") then
				cdr_start_epoch = j:match("start_epoch%s*=%s*([^%s]+)")
			elseif j:match("end_epoch%s=") then
				cdr_end_epoch = j:match("end_epoch%s*=%s*([^%s]+)")
			end
		end
	end
	
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

	luci.http.prepare_content("application/json")
	luci.http.write_json(cdr_info)
	return
end
