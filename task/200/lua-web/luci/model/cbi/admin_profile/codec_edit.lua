--[[

]]--
local dsp = require "luci.dispatcher"
local uci = require "luci.model.uci".cursor()

arg[1] = arg[1] or ""
arg[2] = arg[2] or ""

uci:check_cfg("profile_codec")

local profile_codec = uci:get_all("profile_codec") or {}
local MAX_CODEC_PROFILE = tonumber(uci:get("profile_param","global","max_codec_profile") or "32")

if arg[2] == "edit" then
    m = Map("profile_codec",translate("Profile / Codec / Edit"))
else
    m = Map("profile_codec",translate("Profile / Codec / New"))
    m.addnew = true
    m.new_section = arg[1]
end

if arg[3] then
	m.saveaction = false
	m.redirect = m:gen_redirect(arg[3])
else
	m.redirect = dsp.build_url("admin","profile","codec")
end

if not m.uci:get(arg[1]) == "codec" then
	luci.http.redirect(m.redirect)
end

s = m:section(NamedSection,arg[1],"codec","")
s.addremove = false
s.anonymous = true


if arg[2] == "edit" then
	index = s:option(DummyValue,"index",translate("Index"))
else
	index = s:option(ListValue,"index",translate("Index"))
	index.rmempty = false
	for i=1,MAX_CODEC_PROFILE do
		local flag = true
		for k,v in pairs(profile_codec) do
			if v.index and tonumber(v.index) == i then
				flag = false
				break
			end
		end

		if flag == true then
			index:value(i,i)
		end
	end
end

name = s:option(Value,"name",translate("Name"))
name.rmempty = false
name.datatype = "cfgname"

codec = s:option(DynListValue,"code",translate("Codec"))
local codec_tb = {"G729","G723","PCMU","PCMA"}
for _,v in pairs(codec_tb) do
	codec:value(v,v)
end

-- minptime = s:option(Value,"minptime",translate("Min Ptime"))
-- minptime.default = "10"
-- minptime.rmempty = false
-- minptime.datatype = "uinteger"

-- maxptime = s:option(Value,"maxptime",translate("Max Ptime"))
-- maxptime.default = "60"
-- maxptime.rmempty = false
-- maxptime.datatype = "uinteger"

return m
