--[[

]]--
local dsp = require "luci.dispatcher"
local uci = require "luci.model.uci".cursor()

uci:check_cfg("endpoint_siptrunk")
uci:check_cfg("endpoint_sipphone")
uci:check_cfg("endpoint_mobile")

local endpoint_siptrunk = uci:get_all("endpoint_siptrunk") or {}
local endpoint_sipphone = uci:get_all("endpoint_sipphone") or {}
local endpoint_mobile = uci:get_all("endpoint_mobile") or {}
local profile_smsroute = uci:get_all("profile_smsroute") or {}
local MAX_SMSROUTE_PROFILE = tonumber(uci:get("profile_param","global","max_default") or "32")
local MAX_SIP_EXTENSION = tonumber(uci:get("profile_param","global","max_sip_extension") or "256")
local MAX_SIP_TRUNK = tonumber(uci:get("profile_param","global","max_sip_trunk") or "32")

this_section = arg[1] or ""
arg[2] = arg[2] or ""

if arg[2] == "edit" then
    m = Map("profile_smsroute",translate("Call Control / SMS Route / Edit"))
else
    m = Map("profile_smsroute",translate("Call Control / SMS Route / New"))
    m.addnew = true
    m.new_section = this_section
end

m.redirect = dsp.build_url("admin","callcontrol","sms_route")

if not m.uci:get(this_section) == "rule" then
	luci.http.redirect(m.redirect)
end

s = m:section(NamedSection,this_section,"rule","")
m.currsection = s
s.addremove = false
s.anonymous = true

index = s:option(ListValue,"index",translate("Priority"))
index.rmempty = false
local this_index = uci:get("profile_smsroute",this_section,"index")
for i=MAX_SMSROUTE_PROFILE,1,-1 do
	local flag = true
	for k,v in pairs(profile_smsroute) do
		if v.index and tonumber(v.index) == i then
			flag = false
			break
		end
	end
	if flag == true or i == tonumber(this_index) then
		index:value(i,i)
	end
end

name = s:option(Value,"name",translate("Name"))
name.rmempty = false
name.datatype = "cfgname"

s = m:section(NamedSection,this_section,"rule",translate("From"))

from = s:option(ListValue,"from",translate("Source"))
local sipt_list = {}
local sipp_list = {}
local gsm_list = {}
local sip_deps_list = {}
local nonallsippdst_list = {}
local ussd_deps_list = {}
local non_ussd_dest_deps_list = {}
local add_from_in_content_deps_list = {}
local get_from_content_deps_list = {}
--@ from sip extension
for i=1,MAX_SIP_EXTENSION do
	for k,v in pairs(endpoint_sipphone) do
		if v.index and v.name and v.user and v.status == "Enabled" then
			if tonumber(v.index) == i then
				from:value("SIPP-"..v.index,translate("SIP Extension").." / "..v.user)
				table.insert(sipp_list,"SIPP-"..v.index)
				table.insert(sip_deps_list,{from=("SIPP-"..v.index)})
				table.insert(ussd_deps_list,{from=("SIPP-"..v.index)})
				table.insert(get_from_content_deps_list,{from=("SIPP-"..v.index)})
				break
			end
		end
	end
end
--@ from sip trunk
for i=1,MAX_SIP_TRUNK do
	for k,v in pairs(endpoint_siptrunk) do
		if v.index and v.name and v.status and v.status == "Enabled" then
			if tonumber(v.index) == i then
				from:value("SIPT-"..v.index,translate("SIP Trunk").." / "..v.name)
				table.insert(sipt_list,"SIPT-"..v.index)
				table.insert(sip_deps_list,{from=("SIPT-"..v.index)})
				table.insert(ussd_deps_list,{from=("SIPT-"..v.index)})
				table.insert(get_from_content_deps_list,{from=("SIPT-"..v.index)})
				break
			end
		end
	end
end
--@ from gsm/lte/volte
for k,v in pairs(endpoint_mobile) do
	local slot,stype=v.slot_type:match("(%d+)-([GSMCDALTEVO]+)$")
	if v.index and slot and stype and v.status == "Enabled" then
		from:value("SMS-"..v.index, "SIM "..slot.." / "..stype.." / "..translate("SMS"))
		table.insert(gsm_list,"SMS-"..v.index)
		table.insert(ussd_deps_list,{from=("SMS-"..v.index)})
		table.insert(get_from_content_deps_list,{from=("SMS-"..v.index)})
		from:value("USSD-"..v.index, "SIM "..slot.." / "..stype.." / USSD")
		break
	end
end

--@ special from
from:value("0",translate("All SIP Extension / Trunk"))
from.rmempty = false
table.insert(sip_deps_list,{from="0"})
table.insert(ussd_deps_list,{from="0"})

caller_number_prefix = s:option(Value,"src_number",translate("Src Number Prefix"))
caller_number_prefix.datatype = "regular_simple"
for k,v in pairs(sipt_list) do
	caller_number_prefix:depends("from",v)
end
for k,v in pairs(gsm_list) do
	caller_number_prefix:depends("from",v)
end
caller_number_prefix:depends("from","0")

keywords = s:option(Value,"keywords",translate("Content Has the Words"))
for k,v in pairs(sipp_list) do
	keywords:depends("from",v)
end
for k,v in pairs(sipt_list) do
	keywords:depends("from",v)
end
for k,v in pairs(gsm_list) do
	keywords:depends("from",v)
end
keywords:depends("from","0")

s = m:section(NamedSection,this_section,"rule",translate("To"))

option = s:option(ListValue,"action",translate("Action"))
option:value("forward",translate("Forward"))
option:value("reply",translate("Reply"),ussd_deps_list)

option = s:option(ListValue,"dest",translate("Destination"))
option:depends("action","forward")
--@ to sip extension
for i=1,MAX_SIP_EXTENSION do
	for k,v in pairs(endpoint_sipphone) do
		if v.index and v.name and v.user and v.status == "Enabled" then
			if tonumber(v.index) == i then
				option:value("SIPP-"..v.index,translate("SIP Extension").." / "..v.user)
				table.insert(nonallsippdst_list,{dest=("SIPP-"..v.index)})
				table.insert(add_from_in_content_deps_list,{dest=("SIPP-"..v.index)})
				break
			end
		end
	end
end
--@ to sip trunk
for i=1,MAX_SIP_TRUNK do
	for k,v in pairs(endpoint_siptrunk) do
		if v.index and tonumber(v.index) == i and v.name and v.status and v.status == "Enabled" then
			option:value("SIPT-"..v.index,translate("SIP Trunk").." / "..v.name)
			table.insert(nonallsippdst_list,{dest=("SIPT-"..v.index)})
			table.insert(add_from_in_content_deps_list,{dest=("SIPT-"..v.index)})
			break
		end
	end
end
--@ to gsm/lte/volte
for k,v in pairs(endpoint_mobile) do
	local slot,stype=v.slot_type:match("(%d+)-([GSMCDALTEVO]+)$")
	if v.index and slot and stype and v.status == "Enabled" then
		option:value("SMS-"..v.index, "SIM "..slot.." / "..stype.." / "..translate("SMS"))
		table.insert(nonallsippdst_list,{dest=("SMS-"..v.index)})
		table.insert(add_from_in_content_deps_list,{dest=("SMS-"..v.index)})
		option:value("USSD-"..v.index, "SIM "..slot.." / "..stype.." / USSD",ussd_deps_list)
		break
	end
end
option:value("0",translate("Local SIP Extension"))

option = s:option(ListValue,"dest_number_src",translate("Dest Number Src"))
for k,v in pairs(sipt_list) do
	option:depends("dest",v)
end
for k,v in pairs(gsm_list) do
	option:depends("dest",v)
end
option:depends("dest","0")
option:value("custom",translate("Custom"),nonallsippdst_list)
option:value("to",translate("Get from To Header Field"),sip_deps_list)
option:value("content",translate("Get from Content"),get_from_content_deps_list)

option = s:option(Value,"dest_number_separator",translate("Separator between Dest Number and Content"))
option:depends("dest_number_src","content")
option.datatype = "notempty"
option.rmempty = false
function option.validate(self, value)
	local tmp_dest_src = m:formvalue("cbid.profile_smsroute."..this_section..".dest_number_src")
	if "content" ~= tmp_dest_src then
		m.uci:delete("profile_smsroute",this_section,"content")
		return value or ""
	else
		return Value.validate(self,value)
	end
end

option = s:option(Value,"dst_number",translate("Dest Number"))
option.datatype = "phonenumber"
option.rmempty = false
for k,v in pairs(sipt_list) do
	option:depends({dest_number_src="custom",dest=v})
end
for k,v in pairs(gsm_list) do
	option:depends({dest_number_src="custom",dest=v})
end

function option.validate(self, value)
	local tmp_dest = m:formvalue("cbid.profile_smsroute."..this_section..".dest")
	local tmp_dest_src = m:formvalue("cbid.profile_smsroute."..this_section..".dest_number_src")
	if (tmp_dest and tmp_dest:match("^SIPP")) or "custom" ~= tmp_dest_src then
		m.uci:delete("profile_smsroute",this_section,"dst_number")
		return value or ""
	else
		return Value.validate(self,value)
	end
end

option = s:option(ListValue,"prefix",translate("Add Prefix in Content"))
option:value("from",translatef("From %s : ","${from_user}"),add_from_in_content_deps_list)
option:value("none",translate("NONE"))
option:value("custom",translate("Custom"))
option:depends("action","forward")

option = s:option(Value,"custom_prefix"," ")
option.margin="32px"
option:depends("prefix","custom")

option = s:option(ListValue,"suffix",translate("Add Suffix in Content"))
option:value("from",translatef(" -- Send by %s","${from_user}"),add_from_in_content_deps_list)
option:value("none",translate("NONE"))
option:value("custom",translate("Custom"))
option.default="none"
option:depends("action","forward")

option = s:option(Value,"custom_suffix"," ")
option.margin="32px"
option:depends("suffix","custom")

option = s:option(ListValue,"pre_reply_list",translate("Reply"))

option:value("phonenumber",translatef("Your Phone Number is %s","${from_user}"))
option:value("custom",translate("Custom"))
option:depends("action","reply")
option.default="custom"

option = s:option(TextValue,"reply_content",translate("Reply Content"))
option.height = "100px"
option.width="61%"
option.rmempty = false
option.datatype="notempty"
option:depends("pre_reply_list","custom")

function option.validate(self, value)
	local reply_src = m:formvalue("cbid.profile_smsroute."..this_section..".pre_reply_list")
	if (not reply_src) or (reply_src and "custom" ~= reply_src) then
		m.uci:delete("profile_smsroute",this_section,"reply_content")
		return value or ""
	else
		return Value.validate(self,value)
	end
end

return m
