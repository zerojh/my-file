function exec(command)
	local pp = io.popen(command)
	local data = pp:read("*a")
	pp:close()

	return data
end

local api = freeswitch.API()
local session_uuid = session:getVariable("uuid")
local match_str = "uuid:"..session_uuid

local uid_file = "/tmp/access_uid"
local fd_uid_file
local curcall_file = "/tmp/current_call"
local fd_curcall_file
local is_finish = false

local uid = exec("cat /proc/sys/kernel/random/uuid")
uid = string.sub(uid,1,-2)
local access_uid = ""

while is_finish == false do
	fd_uid_file = io.open(uid_file, "r+")
	if fd_uid_file == nil then
		fd_uid_file = io.open(uid_file, "w+")
	end
	access_uid = fd_uid_file:read("*line")
	if access_uid == nil then
		-- first creat file
		fd_uid_file:write(uid, "\n")
		fd_uid_file:flush()
		fd_uid_file:close()	
	elseif access_uid ~= uid then
		-- other thread use
		fd_uid_file:close()
		session:sleep(100)
	else
		-- access to write curcall_file
		fd_uid_file:close()
		is_finish = true
	end
end

exec("sed -i '/"..match_str.."/d' /tmp/current_call")

fd_uid_file = io.open(uid_file, "w+")
fd_uid_file:close()
