local tb = {}
local extension_number = "1001"
local uuid = "8c4fb3e3-0337-4d35-9b2d-9cea0eab8313"
local read_codec = "pcma" 
local read_pack_time = "20" 
local read_bit_rate = "64000"
local write_codec = "pcmu"
local write_pack_time = "20"
local write_bit_rate = "64000"
local local_media_port = "1000"
local remote_media_ip = "172.16.88.172"
local remote_media_port = "2000"
local callstate = "RINGING"
tb[1] = "extension_number:"..extension_number
tb[2] = "uuid:"..uuid
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

local fd = io.open("current_call","a+")
--local str = extension_number..","..uuid..","..read_codec..","..write_codec..","..read_pack_time..","..write_pack_time..","..read_rate_bit..","..write_rate_bit..","..local_media_port..","..remote_media_ip..","..remote_media_port..","..callstate
for k,v in ipairs(tb) do
    if k == #tb then
        fd:write(v,"\n")
    else
        fd:write(v,", ")
    end
end
fd:close()

