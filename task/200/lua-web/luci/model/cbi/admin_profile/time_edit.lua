--[[

]]--
local dsp = require "luci.dispatcher"
local uci = require "luci.model.uci".cursor()

arg[1] = arg[1] or ""
arg[2] = arg[2] or ""

uci:check_cfg("profile_time")

local profile_time = uci:get_all("profile_time") or {}
local MAX_TIME_PROFILE = tonumber(uci:get("profile_param","global","max_time_profile") or '32')

if arg[2] == "edit" then
    m = Map("profile_time",translate("Profile / Time / Edit"))
else
    m = Map("profile_time",translate("Profile / Time / New"))
    m.addnew = true
    m.new_section = arg[1]
end

if arg[3] then
	m.saveaction = false
	m.redirect = m:gen_redirect(arg[3])
else
	m.redirect = dsp.build_url("admin","profile","time")
end

if not m.uci:get(arg[1]) == "time" then
	luci.http.redirect(m.redirect)
end

s = m:section(NamedSection,arg[1],"time","")
s.addremove = false
s.anonymous = true

if arg[2] == "edit" then
	index = s:option(DummyValue,"index",translate("Index"))
else
	index = s:option(ListValue,"index",translate("Index"))
	index.rmempty = false
	for i=1,MAX_TIME_PROFILE do
		local flag = true
		for k,v in pairs(profile_time) do
			if v["index"] and tonumber(v["index"]) == i then
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

date_options = s:option(DynamicList,"date_options",translate("Date Period"))
date_options.datatype = "date"

weekday = s:option(MultiValue,"weekday",translate("Weekday"))
weekday.widget = "checkbox"
local weekday_tb = {"Mon","Tue","Wed","Thu","Fri","Sat","Sun"}
for _,v in pairs(weekday_tb) do
	weekday:value(v,translate(v))
end

time_options = s:option(DynamicList,"time_options",translate("Time Period"))
time_options.datatype = "clock"

return m
