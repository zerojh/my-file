local api = freeswitch.API()

local ext_num = argv[1]
local uuid = session:getVariable("uuid")
local read_codec = session:getVariable("read_codec")
local read_rate = session:getVariable("read_rate")
local write_codec = session:getVariable("write_codec")
local write_rate = session:getVariable("write_rate")
local local_media_ip = api:executeString("uuid_getvar "..uuid.." local_media_ip")
local local_media_port = api:executeString("uuid_getvar "..uuid.." local_media_port")
local remote_media_ip = session:getVariable("remote_media_ip")
local remote_media_port = session:getVariable("remote_media_port")
local callstate = api:executeString("eval uuid:"..uuid.." ${channel-call-state}")

os.execute("echo '------------------lua get_variable start---------------' >> /tmp/a-legt")
local str = ext_num..","
if ext_num then
    os.execute("echo 'extension_number = "..ext_num.."' >> /tmp/a-legt")
end
if uuid then
    os.execute("echo 'uuid = "..uuid.."' >> /tmp/a-legt")
end
if read_codec then
    os.execute("echo 'read_codec = "..read_codec.."' >> /tmp/a-legt")
end
if read_rate then
    os.execute("echo 'read_rate = "..read_rate.."' >> /tmp/a-legt")
end
if write_codec then
    os.execute("echo 'write_codec = "..write_codec.."' >> /tmp/a-legt")
end
if write_rate then
    os.execute("echo 'write_rate = "..write_rate.."' >> /tmp/a-legt")
end
if local_media_ip then
    os.execute("echo 'local_media_ip = "..local_media_ip.."' >> /tmp/a-legt")
end
if local_media_port then
    os.execute("echo 'local_media_port = "..local_media_port.."' >> /tmp/a-legt")
end
if remote_media_ip then
    os.execute("echo 'remote_media_ip = "..remote_media_ip.."' >> /tmp/a-legt")
end
if remote_media_port then
    os.execute("echo 'remote_media_port = "..remote_media_port.."' >> /tmp/a-legt")
end
if callstate then
    os.execute("echo 'state = "..callstate.."' >> /tmp/a-legt")
end

os.execute("echo '------------------lua get_variable finish---------------' >> /tmp/a-legt")
