--[[

]]--
local dsp = require "luci.dispatcher"
local uci = require "luci.model.uci".cursor()

arg[1] = arg[1] or ""
arg[2] = arg[2] or ""

uci:check_cfg("profile_dialplan")

local profile_dialplan = uci:get_all("profile_dialplan") or {}
local MAX_DIALPLAN_PROFILE = tonumber(uci:get("profile_param","global","max_dialplan_profile") or "32")

if arg[2] == "edit" then
    m = Map("profile_dialplan",translate("Profile / Dialplan / Edit"))
else
    m = Map("profile_dialplan",translate("Profile / Dialplan / New"))
    m.addnew = true
    m.new_section = arg[1]
end

if arg[3] then
	m.saveaction = false
	m.redirect = m:gen_redirect(arg[3])
else
	m.redirect = dsp.build_url("admin","profile","dialplan")
end

if not m.uci:get(arg[1]) == "dialplan" then
	luci.http.redirect(m.redirect)
end

s = m:section(NamedSection,arg[1],"dialplan","")
s.addremove = false
s.anonymous = true


if arg[2] == "edit" then
	index = s:option(DummyValue,"index",translate("Index"))
else
	index = s:option(ListValue,"index",translate("Index"))
	index.rmempty = false
	for i=1,MAX_DIALPLAN_PROFILE do
		local flag = true
		for k,v in pairs(profile_dialplan) do
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

ft = s:option(ListValue,"format",translate("Format"))
ft:value("regex",translate("Regex"))
ft:value("digitmap",translate("DigitMap"))

regex = s:option(TextValue,"dialregex",translate("Dialplan"))
regex.height = "200px"
regex:depends("format","regex")
regex.datatype = "regular"

digitmap = s:option(TextValue,"digitmap",translate("Dialplan"))
digitmap.height = "200px"
digitmap:depends("format","digitmap")
digitmap.datatype = "digitmap"


return m

