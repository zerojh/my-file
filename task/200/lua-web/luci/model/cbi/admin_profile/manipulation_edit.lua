--[[

]]--
local dsp = require "luci.dispatcher"
local uci = require "luci.model.uci".cursor()

arg[1] = arg[1] or ""
arg[2] = arg[2] or ""

uci:check_cfg("profile_manipl")

local profile_manipl = uci:get_all("profile_manipl") or {}
local MAX_MANIPL_PROFILE = tonumber(uci:get("profile_param","global","max_manipl_profile") or "32")

if arg[2] == "edit" then
    m = Map("profile_manipl",translate("Profile / Manipulation / Edit"))
else
    m = Map("profile_manipl",translate("Profile / Manipulation / New"))
    m.addnew = true
    m.new_section = arg[1]
end

if arg[3] then
	m.saveaction = false
	m.redirect = m:gen_redirect(arg[3])
else
	m.redirect = dsp.build_url("admin","profile","manipl")
end

if not m.uci:get(arg[1]) == "manipl" then
	luci.http.redirect(m.redirect)
end

s = m:section(NamedSection,arg[1],"manipl","")
s.addremove = false
s.anonymous = true

if arg[2] == "edit" then
	index = s:option(DummyValue,"index",translate("Index"))
else
	index = s:option(ListValue,"index",translate("Index"))
	index.rmempty = false
	for i=1,MAX_MANIPL_PROFILE do
		local flag = true
		for k,v in pairs(profile_manipl) do
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

caller = s:option(Flag,"caller",translate("Caller"))

caller_del_prefix = s:option(Value,"CallerDelPrefix",translate("Delete Prefix Count"))
 caller_del_prefix.datatype = "uinteger"
 caller_del_prefix.margin = "32px"
 caller_del_prefix:depends("caller","1")
caller_del_suffix = s:option(Value,"CallerDelSuffix",translate("Delete Suffix Count"))
 caller_del_suffix.datatype = "uinteger"
 caller_del_suffix.margin = "32px"
 caller_del_suffix:depends("caller","1")
caller_add_prefix = s:option(Value,"CallerAddPrefix",translate("Add Prefix"))
 caller_add_prefix.datatype = "phonenumber"
 caller_add_prefix.margin = "32px"
 caller_add_prefix:depends("caller","1")
caller_add_suffix = s:option(Value,"CallerAddSuffix",translate("Add Suffix"))
 caller_add_suffix.datatype = "phonenumber"
 caller_add_suffix.margin = "32px"
 caller_add_suffix:depends("caller","1")
caller_replace = s:option(Value,"CallerReplace",translate("Replace by"))
 caller_replace.datatype = "phonenumber"
 caller_replace.margin = "32px"
 caller_replace:depends("caller","1")



called = s:option(Flag,"called",translate("Called"))

called_del_prefix = s:option(Value,"CalledDelPrefix",translate("Delete Prefix Count"))
 called_del_prefix.datatype = "uinteger"
 called_del_prefix.margin = "32px"
 called_del_prefix:depends("called","1")
called_del_suffix = s:option(Value,"CalledDelSuffix",translate("Delete Suffix Count"))
 called_del_suffix.datatype = "uinteger"
 called_del_suffix.margin = "32px"
 called_del_suffix:depends("called","1")
called_add_prefix = s:option(Value,"CalledAddPrefix",translate("Add Prefix"))
 called_add_prefix.datatype = "phonenumber"
 called_add_prefix.margin = "32px"
 called_add_prefix:depends("called","1")
called_add_suffix = s:option(Value,"CalledAddSuffix",translate("Add Suffix"))
 called_add_suffix.datatype = "phonenumber"
 called_add_suffix.margin = "32px"
 called_add_suffix:depends("called","1")
called_replace = s:option(Value,"CalledReplace",translate("Replace by"))
 called_replace.datatype = "phonenumber"
 called_replace.margin = "32px"
 called_replace:depends("called","1")

return m

