
function exec(command)
	local pp = io.popen(command)
	local data = pp:read("*a")
	pp:close()

	return data
end

local uuid_file = "/tmp/access_uuid"
local fd_uuid_file
local curcall_file = "/tmp/current_call"
local fd_curcall_file
local is_finish = false

local uuid = exec("cat /proc/sys/kernel/random/uuid")
uuid = string.sub(uuid,1,-2)
local access_uuid = ""

print(uuid)

while is_finish == false do
	fd_uuid_file = io.open(uuid_file, "r+")
	if fd_uuid_file == nil then
		fd_uuid_file = io.open(uuid_file, "w+")
	end
	access_uuid = fd_uuid_file:read("*line")
	if access_uuid == nil then
		-- first creat file
		fd_uuid_file:write(uuid,"\n")
        fd_uuid_file:flush()
		fd_uuid_file:close()	
	elseif access_uuid ~= uuid then
		-- other thread use
		print("other thread use the file")
		fd_uuid_file:close()
		is_finish = true
	else
		-- access to write curcall_file
		print("access to write curcall file")
		fd_uuid_file:close()
		is_finish = true
	end
end

