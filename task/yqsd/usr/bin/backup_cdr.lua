require "lsqlite3"
require "os"

local fs = require "luci.fs"
local exe = os.execute
local date = os.date
local db
local upload_file = arg[1]

if not upload_file or not fs.access("/etc/freeswitch/cdr") then
	return
end

-- open database
exe("cp /etc/freeswitch/cdr "..upload_file)
db = sqlite3.open(upload_file)

-- query table 'cdr'
local is_exist_table = false
for _ in db:urows("SELECT * FROM sqlite_master WHERE type='table' AND name='cdr'") do
	is_exist_table = true
end
if not is_exist_table then
	db:close()
	exe("rm "..upload_file.." -rf")
	return
end

local date_tb = os.date("*t")
local epoch = os.time({year=date_tb.year,month=date_tb.month,day=date_tb.day,hour=0,min=0,sec=0})
local min_epoch = epoch - 24*60*60
local max_epoch = epoch - 1

-- delete data
db:exec("DELETE FROM cdr WHERE start_epoch<"..min_epoch.." OR start_epoch>"..max_epoch..";VACUUM;")

local is_exist_data = false
for num in db:urows("SELECT COUNT(*) FROM cdr") do
	if num and tonumber(num) > 0 then
		is_exist_data = true
	end
end
if not is_exist_data then
	exe("rm "..upload_file.." -rf")
end

db:close()
