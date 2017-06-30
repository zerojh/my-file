--[[

]]--
local dsp = require "luci.dispatcher"
local uci = require "luci.model.uci".cursor()

arg[1] = arg[1] or ""
arg[2] = arg[2] or ""

uci:check_cfg("profile_number")

local profile_number = uci:get_all("profile_number") or {}
local MAX_NUMBER_PROFILE = tonumber(uci:get("profile_param","global","max_number_profile") or "32")

if arg[2] == "edit" then
    m = Map("profile_number",translate("Profile / Number / Edit"))
else
    m = Map("profile_number",translate("Profile / Number / New"))
    m.addnew = true
    m.new_section = arg[1]
end

if arg[3] then
	m.saveaction = false
	m.redirect = m:gen_redirect(arg[3])
else
	m.redirect = dsp.build_url("admin","profile","number")
end

if not m.uci:get(arg[1]) == "number" then
	luci.http.redirect(m.redirect)
end

s = m:section(NamedSection,arg[1],"number","")
s.addremove = false
s.anonymous = true

if arg[2] == "edit" then
	index = s:option(DummyValue,"index",translate("Index"))
else
	index = s:option(ListValue,"index",translate("Index"))
	index.rmempty = false
	for i=1,MAX_NUMBER_PROFILE do
		local flag = true
		for k,v in pairs(profile_number) do
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

s = m:section(NamedSection,arg[1],"profile_number",translate("Caller Number"))

caller = s:option(TextValue,"caller",translate("Prefix"))
caller.height = "100px"
caller.datatype = "regular"

--callerflag = s:option(Flag,"callerflag",translate("More"))
--callerflag.rmempty = false

callerlength = s:option(Value,"callerlength",translate("Length"))
callerlength.datatype = "numberrange"
--callerlength.margin = "32px"
--callerlength:depends("callerflag","1")

--callerproperty = s:option(ListValue,"callerproperty",translate("Property"))
--callerproperty.default = "Unknown"
--callerproperty.margin = "32px"
--callerproperty:depends("callerflag","1")
--local data = {"Unknown","Internationl","National","Network Special","Subscriber","Abbreviated"}
--for _,v in pairs(data) do
--	callerproperty:value(v,translate(v))
--end

--callerarea = s:option(ListValue,"callerarea",translate("Area"))
--callerarea:depends("callerflag","1")
--callerarea.margin = "32px"

--callercarrier = s:option(ListValue,"callercarrier",translate("Carrier"))
--callercarrier.default = "Unknown"
--callercarrier.margin = "32px"
--callercarrier:depends("callerflag","1")
--local carrier = {"Unknown","CMCC","CUC","CT"}
--for _,v in pairs(carrier) do
--	callercarrier:value(v,translate(v))
--end

--
--called seting
--
s = m:section(NamedSection,arg[1],"profile_number",translate("Called Number"))

called = s:option(TextValue,"called",translate("Prefix"))
called.height = "100px"
called.datatype = "regular"

--calledflag = s:option(Flag,"calledflag",translate("More"))
--calledflag.rmempty = false

calledlength = s:option(Value,"calledlength",translate("Length"))
--calledlength:depends("calledflag","1")
calledlength.datatype = "numberrange"
--calledlength.margin = "32px"

--calledproperty = s:option(ListValue,"calledproperty",translate("Property"))
--calledproperty.default = "Unknown"
--calledproperty.margin = "32px"
--calledproperty:depends("calledflag","1")
--for _,v in pairs(data) do
--	calledproperty:value(v,translate(v))
--end

--calledarea = s:option(ListValue,"calledarea",translate("Area"))
--calledarea:depends("calledflag","1")
--calledarea.margin = "32px"

--calledcarrier = s:option(ListValue,"calledcarrier",translate("Carrier"))
--calledcarrier.default = "Unknown"
--calledcarrier.margin = "32px"
--calledcarrier:depends("calledflag","1")
--for _,v in pairs(carrier) do
--	calledcarrier:value(v,translate(v))
--end

return m

