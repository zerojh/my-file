local api = freeswitch.API()

local tb = {}
tb[1] = argv[1] or "null"
tb[2] = argv[3] or "null"
tb[3] 
--tb[2] = session:getVariable("uuid") or "null" 
--tb[3] = session:getVariable("read_codec") or "null"
--tb[4] = session:getVariable("read_bit_rate") or "null"
--tb[5] = session:getVariable("write_codec") or "null"
--tb[6] = session:getVariable("write_bit_rate") or "null"
--tb[7] = api:executeString("uuid_getvar "..tb[2].." local_media_port") or "null"
--tb[8] = session:getVariable("remote_media_ip") or "null"
--tb[9] = session:getVariable("remote_media_port") or "null"
--tb[10] = "null"
--tb[11] = session:getVariable("remote_media_porta") or "null"

os.execute("echo '------------------lua get_variable start---------------' >> /tmp/a-legt")

local fd = io.open("/tmp/current_call","a+")
for k,v in ipairs(tb) do
	if k == #tb then
		fd:write(v, "\n")
	else
		fd:write(v, ", ")
	end
end
fd:close()	

os.execute("echo '------------------lua get_variable finish---------------' >> /tmp/a-legt")
