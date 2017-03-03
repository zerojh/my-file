module("luci.controller.api.api", package.seeall)

-- dispatcher.lua
-- if pathinfo:match("^/gsm_") or pathinfo:match("^/api") then
--

function index()
	node("api")
	entry({"api", "cdr"}, call("action_cdrs"))
end

function action_cdrs()
	local fs  = require "luci.fs"
	local sys = require "luci.sys"
	local sqlite = require "luci.scripts.sqlite3_service"
	local exe = require "os".execute
	local uci = require "luci.model.uci".cursor()
	local tmp_cdrs_file = "/tmp/cdr.db"

	local cdr_enable = uci:get("system","main","mod_cdr") or "off"
	if cdr_enable == "off" then
		luci.http.prepare_content("text/plain")
		luci.http.write("CDR is not enabled!")
		return
	end

	if fs.access("/etc/freeswitch/cdr") then
		exe("cp /etc/freeswitch/cdr "..tmp_cdrs_file)
	else
		luci.http.prepare_content("text/plain")
		luci.http.write("No CDR records!")
		return
	end

	local data_type = luci.http.formvalue("data_type") or "csv"
	if data_type ~= "json" and data_type ~= "csv" and data_type ~= "db" then
		luci.http.prepare_content("text/plain")
		luci.http.write("Invalid data type!")
		return
	end

	-- optional data
	local sql_condition_tb = {}
	local sql_condition_str = ""
	sql_condition_tb.caller_id_number = luci.http.formvalue("caller_number")
	sql_condition_tb.destination_number = luci.http.formvalue("callee_number")
	sql_condition_tb.source_chan_name = luci.http.formvalue("source")
	sql_condition_tb.dest_chan_name = luci.http.formvalue("destination")
	sql_condition_tb.min_billsec = luci.http.formvalue("min_duration")
	sql_condition_tb.max_billsec = luci.http.formvalue("max_duration")
	sql_condition_tb.start_time = luci.http.formvalue("start_time")
	sql_condition_tb.end_time = luci.http.formvalue("end_time")

	if data_type == "json" or data_type == "csv" then
		if sql_condition_tb.caller_id_number then
			local source_tb = luci.util.split(sql_condition_tb.caller_id_number,",") or {}
			local dest_str = "("
			for _,v in pairs(source_tb) do
				if v:match("%S+") then
					dest_str = dest_str == "(" and (dest_str.."caller_id_number=\""..v.."\"") or (dest_str.." or caller_id_number=\""..v.."\"")
				end
			end
			dest_str = dest_str..")"
			if dest_str ~= "()" then
				sql_condition_tb.caller_id_number = dest_str
			else
				sql_condition_tb.caller_id_number = nil
			end
		end
		if sql_condition_tb.destination_number then
			local source_tb = luci.util.split(sql_condition_tb.destination_number,",") or {}
			local dest_str = "("
			for _,v in pairs(source_tb) do
				if v:match("%S+") then
					dest_str = dest_str == "(" and (dest_str.."destination_number=\""..v.."\"") or (dest_str.." or destination_number=\""..v.."\"")
				end
			end
			dest_str = dest_str..")"
			if dest_str ~= "()" then
				sql_condition_tb.destination_number = dest_str
			else
				sql_condition_tb.destination_number = nil
			end
		end
		if sql_condition_tb.source_chan_name then
			local source_str = sql_condition_tb.source_chan_name
			local match_tb = {"SIP","FXS","FXO","GSM"}
			local dest_str = "("
			for _,v in pairs(match_tb) do
				if source_str:match(v) then
					dest_str = dest_str == "(" and dest_str.."source_chan_name like \""..v.."%\"" or dest_str.." or source_chan_name like \""..v.."%\""
				end
			end
			dest_str = dest_str..")"
			if dest_str ~= "()" then
				sql_condition_tb.source_chan_name = dest_str
			else
				sql_condition_tb.source_chan_name = nil
			end
		end
		if sql_condition_tb.dest_chan_name then
			local source_str = sql_condition_tb.dest_chan_name
			local match_tb = {"SIP","FXS","FXO","GSM"}
			local dest_str = "("
			for _,v in pairs(match_tb) do
				if source_str:match(v) then
					dest_str = dest_str == "(" and dest_str.."dest_chan_name like \""..v.."%\"" or dest_str.." or dest_chan_name like \""..v.."%\""
				end
			end
			dest_str = dest_str..")"
			if dest_str ~= "()" then
				sql_condition_tb.dest_chan_name = dest_str
			else
				sql_condition_tb.dest_chan_name = nil
			end
		end
		sql_condition_tb.min_billsec = sql_condition_tb.min_billsec and "billsec>="..sql_condition_tb.min_billsec
		sql_condition_tb.max_billsec = sql_condition_tb.max_billsec and "billsec<="..sql_condition_tb.max_billsec
		if sql_condition_tb.start_time and (sql_condition_tb.start_time:match("^date,%d+,%d+,%d+$") or sql_condition_tb.start_time:match("^epoch,%d+$")) then
			local time_type = sql_condition_tb.start_time:match("^(%a+),")
			if time_type == "epoch" then
				sql_condition_tb.start_time = "start_epoch>="..sql_condition_tb.start_time:match(",(%d+)$")
			elseif time_type == "date" then
				local year,month,day = sql_condition_tb.start_time:match(",(%d+),(%d+),(%d+)$")
				local tmp_epoch = os.time({year=year,month=month,day=day,hour=0,min=0,sec=0})
				if tmp_epoch then
					sql_condition_tb.start_time = "start_epoch>="..tmp_epoch
				else
					sql_condition_tb.start_time = nil
				end
			end
		else
			sql_condition_tb.start_time = nil
		end
		if sql_condition_tb.end_time and (sql_condition_tb.end_time:match("^date,%d+,%d+,%d+$") or sql_condition_tb.end_time:match("^epoch,%d+$")) then
			local time_type = sql_condition_tb.end_time:match("^(%a+),")
			if time_type == "epoch" then
				sql_condition_tb.end_time = "end_epoch<="..sql_condition_tb.end_time:match(",(%d+)$")
			elseif time_type == "date" then
				local year,month,day = sql_condition_tb.end_time:match(",(%d+),(%d+),(%d+)$")
				local tmp_epoch = os.time({year=year,month=month,day=day,hour=23,min=59,sec=59})
				if tmp_epoch then
					sql_condition_tb.end_time = "end_epoch<="..tmp_epoch
				else
					sql_condition_tb.end_time = nil
				end
			end
		else
			sql_condition_tb.end_time = nil
		end
	else
		if sql_condition_tb.caller_id_number then
			local source_tb = luci.util.split(sql_condition_tb.caller_id_number,",") or {}
			local dest_str = "("
			for _,v in pairs(source_tb) do
				if v:match("%S+") then
					dest_str = dest_str == "(" and (dest_str.."caller_id_number<>\""..v.."\"") or (dest_str.." and caller_id_number<>\""..v.."\"")
				end
			end
			dest_str = dest_str..")"
			if dest_str ~= "()" then
				sql_condition_tb.caller_id_number = dest_str
			else
				sql_condition_tb.caller_id_number = nil
			end
		end
		if sql_condition_tb.destination_number then
			local source_tb = luci.util.split(sql_condition_tb.destination_number,",") or {}
			local dest_str = "("
			for _,v in pairs(source_tb) do
				if v:match("%S+") then
					dest_str = dest_str == "(" and (dest_str.."destination_number<>\""..v.."\"") or (dest_str.." and destination_number<>\""..v.."\"")
				end
			end
			dest_str = dest_str..")"
			if dest_str ~= "()" then
				sql_condition_tb.destination_number = dest_str
			else
				sql_condition_tb.destination_number = nil
			end
		end
		if sql_condition_tb.source_chan_name then
			local source_str = sql_condition_tb.source_chan_name
			local match_tb = {"SIP","FXS","FXO","GSM"}
			local dest_str = "("
			for _,v in pairs(match_tb) do
				if source_str:match(v) then
					dest_str = dest_str == "(" and dest_str.."source_chan_name not like \""..v.."%\"" or dest_str.." and source_chan_name not like \""..v.."%\""
				end
			end
			dest_str = dest_str..")"
			if dest_str ~= "()" then
				sql_condition_tb.source_chan_name = dest_str
			else
				sql_condition_tb.source_chan_name = nil
			end
		end
		if sql_condition_tb.dest_chan_name then
			local source_str = sql_condition_tb.dest_chan_name
			local match_tb = {"SIP","FXS","FXO","GSM"}
			local dest_str = "("
			for _,v in pairs(match_tb) do
				if source_str:match(v) then
					dest_str = dest_str == "(" and dest_str.."dest_chan_name not like \""..v.."%\"" or dest_str.." and dest_chan_name not like \""..v.."%\""
				end
			end
			dest_str = dest_str..")"
			if dest_str ~= "()" then
				sql_condition_tb.dest_chan_name = dest_str
			else
				sql_condition_tb.dest_chan_name = nil
			end
		end
		sql_condition_tb.min_billsec = sql_condition_tb.min_billsec and "billsec<"..sql_condition_tb.min_billsec
		sql_condition_tb.max_billsec = sql_condition_tb.max_billsec and "billsec>"..sql_condition_tb.max_billsec
		if sql_condition_tb.start_time and (sql_condition_tb.start_time:match("^date,%d+,%d+,%d+$") or sql_condition_tb.start_time:match("^epoch,%d+$")) then
			local time_type = sql_condition_tb.start_time:match("^(%a+),")
			if time_type == "epoch" then
				sql_condition_tb.start_time = "start_epoch<"..sql_condition_tb.start_time:match(",(%d+)$")
			elseif time_type == "date" then
				local year,month,day = sql_condition_tb.start_time:match(",(%d+),(%d+),(%d+)$")
				local tmp_epoch = os.time({year=year,month=month,day=day,hour=0,min=0,sec=0})
				if tmp_epoch then
					sql_condition_tb.start_time = "start_epoch<"..tmp_epoch
				else
					sql_condition_tb.start_time = nil
				end
			end
		else
			sql_condition_tb.start_time = nil
		end
		if sql_condition_tb.end_time and (sql_condition_tb.end_time:match("^date,%d+,%d+,%d+$") or sql_condition_tb.end_time:match("^epoch,%d+$")) then
			local time_type = sql_condition_tb.end_time:match("^(%a+),")
			if time_type == "epoch" then
				sql_condition_tb.end_time = "end_epoch>"..sql_condition_tb.end_time:match(",(%d+)$")
			elseif time_type == "date" then
				local year,month,day = sql_condition_tb.end_time:match(",(%d+),(%d+),(%d+)$")
				local tmp_epoch = os.time({year=year,month=month,day=day,hour=23,min=59,sec=59})
				if tmp_epoch then
					sql_condition_tb.end_time = "end_epoch>"..tmp_epoch
				else
					sql_condition_tb.end_time = nil
				end
			end
		else
			sql_condition_tb.end_time = nil
		end
	end

	if next(sql_condition_tb) then
		for i,j in pairs(sql_condition_tb) do
			if j ~= "" then
				if sql_condition_str == "" then
					sql_condition_str = j
				else
					if data_type == "json" or data_type == "csv" then
						sql_condition_str = sql_condition_str.." and "..j
					else
						sql_condition_str = sql_condition_str.." or "..j
					end
				end
			end
		end
	end

	--require "os".execute("echo '"..sql_condition_str.."' >> /tmp/aaaaaa")

	if data_type == "json" then
		local sql_cmd
		if sql_condition_str == "" then
			sql_cmd = "select * from cdr"
		else
			sql_cmd = "select * from cdr where "..sql_condition_str
		end
		cdr_info_tb = sqlite.sqlite3_execute(tmp_cdrs_file,sql_cmd) or {}
		luci.http.prepare_content("application/json")
		luci.http.write_json({content=cdr_info_tb, length=#cdr_info_tb})
		fs.unlink(tmp_cdrs_file)
	elseif data_type == "csv" then
		local tmp_tar_file = "/tmp/CDRs"
		local localip = luci.http.getenv("SERVER_ADDR")
		local _file = io.open("/tmp/cdrs.xls","w+")
		local sql_cmd
		if sql_condition_str == "" then
			sql_cmd = "select * from cdr"
		else
			sql_cmd = "select * from cdr where "..sql_condition_str
		end
		cdr_info_tb = sqlite.sqlite3_execute(tmp_cdrs_file,sql_cmd) or {}

		--write into file
		if _file then
			local title_flag = true
			for k,v in pairs(cdr_info_tb) do
				local tmp_str = ""
				if title_flag then
					for k2,v2 in pairs(v) do
						tmp_str = tmp_str..k2.."\t"
					end
					title_flag = false
					_file:write(tmp_str.."\n")
				end
				tmp_str = ""
				for k2,v2 in pairs(v) do
					tmp_str = tmp_str..v2.."\t"
				end
				_file:write(tmp_str.."\n")
			end
			_file:close()
		end

		sys.call("tar -cz /tmp/cdrs.xls -f "..tmp_tar_file)
		local reader = luci.ltn12.source.file(io.open(tmp_tar_file,"r"))
		luci.http.header('Content-Disposition', 'attachment; filename="CDRs-%s-%s-%s.tar.gz"' % {luci.sys.hostname(), localip, os.date("%Y-%m-%d")})
		luci.http.prepare_content("application/gzip")
		luci.ltn12.pump.all(reader, luci.http.write)
		fs.unlink(tmp_cdrs_file)
		fs.unlink(tmp_tar_file)
		fs.unlink("/tmp/cdrs.xls")
	else
		local tmp_tar_file = "/tmp/CDRs"
		local localip = luci.http.getenv("SERVER_ADDR")
		if sql_condition_str ~= "" then
			local sql_cmd = "delete from cdr where "..sql_condition_str
			local ret = sqlite.sqlite3_execute(tmp_cdrs_file,sql_cmd)
			ret = sqlite.sqlite3_execute(tmp_cdrs_file,"vacuum")
		end

		sys.call("tar -cz "..tmp_cdrs_file.." -f "..tmp_tar_file)
		local reader = luci.ltn12.source.file(io.open(tmp_tar_file,"r"))
		luci.http.header('Content-Disposition', 'attachment; filename="CDRs-%s-%s-%s.tar.gz"' % {luci.sys.hostname(), localip, os.date("%Y-%m-%d")})
		luci.http.prepare_content("application/gzip")
		luci.ltn12.pump.all(reader, luci.http.write)
		fs.unlink(tmp_cdrs_file)
		fs.unlink(tmp_tar_file)
	end
end

