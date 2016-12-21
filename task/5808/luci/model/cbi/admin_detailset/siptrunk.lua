local uci = require "luci.model.uci".cursor()
local dsp = require "luci.dispatcher"
local currsection

uci:check_cfg("endpoint_siptrunk")

if uci:get("endpoint_siptrunk","main_trunk") then
	currsection = "main_trunk"
else
	local tmp_tb = uci:get_all("endpoint_siptrunk") or {}
	if tmp_tb and next(tmp_tb) then
		for k,v in pairs(tmp_tb) do
			if v.index and v.index == "1" then
				currsection = k
				break
			end
		end
	end
end

if not currsection then
	local ret = uci:create_section("endpoint_siptrunk","sip","main_trunk",{index="1"})
	if ret then
		currsection = "main_trunk"
	else
		currsection = uci:section("endpoint_siptrunk","sip")
		uci:set("endpoint_siptrunk",currsection,"index","1")
		uci:save("endpoint_siptrunk")
		uci:commit("endpoint_siptrunk")
	end
end

m = Map("endpoint_siptrunk",translate("配置 / 通讯调度平台"))

s = m:section(NamedSection,currsection,"sip")
m.currsection = s
s.addremove = false
s.anonymous = true

--#### Address #####----
option = s:option(Value,"ipv4","服务器地址")
option.rmempty = false
option.datatype="abc_ip4addr_domain"
function option.validate(self,value)
	m.uci:set("endpoint_siptrunk",currsection,"name","1")
	m.uci:set("endpoint_siptrunk",currsection,"register","on")
	if not m.uci:get("endpoint_siptrunk",currsection,"expire_seconds") then
		m.uci:set("endpoint_siptrunk",currsection,"expire_seconds","1800")
	end
	if not m.uci:get("endpoint_siptrunk",currsection,"from_username") then
		m.uci:set("endpoint_siptrunk",currsection,"from_username","username")
	end
	if not m.uci:get("endpoint_siptrunk",currsection,"heartbeat") then
		m.uci:set("endpoint_siptrunk",currsection,"heartbeat","on")
		m.uci:set("endpoint_siptrunk",currsection,"ping","5")
	end
	if not m.uci:get("endpoint_siptrunk",currsection,"profile") then
		m.uci:set("endpoint_siptrunk",currsection,"profile","2")
	end
	if not m.uci:get("endpoint_siptrunk",currsection,"reg_url_with_transport") then
		m.uci:set("endpoint_siptrunk",currsection,"reg_url_with_transport","off")
	end
	if not m.uci:get("endpoint_siptrunk",currsection,"retry_seconds") then
		m.uci:set("endpoint_siptrunk",currsection,"retry_seconds","60")
	end
	if not m.uci:get("endpoint_siptrunk",currsection,"status") then
		m.uci:set("endpoint_siptrunk",currsection,"status","Enabled")
	end
	if not m.uci:get("endpoint_siptrunk",currsection,"transport") then
		m.uci:set("endpoint_siptrunk",currsection,"transport","udp")
	end

	return Value.validate(self, value)
end

--#### Port #####----
option = s:option(Value,"port","服务器端口")
option.datatype = "port"

--#### Username #####----
option = s:option(Value,"username","用户名")
option.rmempty = false
option.datatype="notempty"
function option.write(self,section,value)
	m.uci:set("endpoint_siptrunk",currsection,"username",value or "")
end

--#### Password #####----
option = s:option(Value,"password","密码")
option.password = true

return m
