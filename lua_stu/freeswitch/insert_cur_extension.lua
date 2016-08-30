function exec(command)
	local pp = io.popen(command)
	local data = pp:read("*a")
	pp:close()

	return data
end

local api = freeswitch.API()

local tb = {}
local extension_number = argv[1] or "null"
local local_uuid = session:getVariable("uuid") or "null"
local remote_uuid = ""
local direction = session:getVariable("direction")
if direction == "inbound" then
	remote_uuid = session:getVariable("originated_legs")
	remote_uuid = remote_uuid:match("(.-);")
else
	remote_uuid = session:getVariable("originator")
end
local read_codec = session:getVariable("read_codec") or "null"
local read_pack_time = "null"
local read_rate = session:getVariable("read_rate") or "null"
local read_bit_rate = api:executeString("eval uuid:"..local_uuid.." ${Channel-Read-Codec-Bit-Rate}") or "null"
local write_codec = session:getVariable("write_codec") or "null"
local write_pack_time = "null"
local write_rate = session:getVariable("write_rate") or "null"
local write_bit_rate = api:executeString("eval uuid:"..local_uuid.." ${Channel-Write-Codec-Bit-Rate}") or "null"
local local_media_port = api:executeString("uuid_getvar "..local_uuid.." local_media_port") or "null"
local remote_media_ip = session:getVariable("remote_media_ip") or "null"
local remote_media_port = session:getVariable("remote_media_port") or "null"
local callstate = argv[2] or "null"

tb[1] = "extension_number:"..extension_number
tb[2] = "uuid:"..local_uuid
tb[3] = "read_codec:"..read_codec
tb[4] = "read_pack_time:"..read_pack_time
tb[5] = "read_bit_rate"..read_bit_rate
tb[6] = "write_codec:"..write_codec
tb[7] = "write_pack_time:"..write_pack_time
tb[8] = "write_bit_rate:"..write_bit_rate
tb[9] = "local_media_port:"..local_media_port
tb[10] = "remote_media_ip:"..remote_media_ip
tb[11] = "remote_media_port:"..remote_media_port
tb[12] = "callstate:"..callstate

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

fd_curcall_file = io.open(curcall_file, "a+")
for k,v in ipairs(tb) do
	if k == #tb then
		fd_curcall_file:write(v, "\n")
	else
		fd_curcall_file:write(v, ", ")
	end
end
fd_curcall_file:close()

fd_uid_file = io.open(uid_file, "w+")
fd_uid_file:close()
