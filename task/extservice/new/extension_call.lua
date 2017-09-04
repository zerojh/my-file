require "mxml"
require "uci"
require "luci.util"

local fs = require "nixio.fs"
local base64 = require "luci.base64"
local uci = uci.cursor("/tmp/config","/tmp/state")
local exe = os.execute

local extension_callout_check_00 = "/tmp/fsconf/dialplan/public/00_callout_check.xml"
local extension_callin_check = "/tmp/fsconf/dialplan/public/extension_callin_check.xml"

local cfgfilelist = {"system","profile_fxso","profile_codec","profile_sip","profile_number","endpoint_fxso","endpoint_siptrunk","endpoint_sipphone","endpoint_ringgroup","endpoint_mobile","callcontrol","feature_code"}
for k,v in ipairs(cfgfilelist) do
	exe("cp /etc/config/"..v.." /tmp/config")
end

local interface = uci:get("system","main","interface") or ""
local license = {}
license.fxs = tonumber(interface:match("(%d+)S") or "0")
license.fxo = tonumber(interface:match("(%d+)O") or "0")
license.gsm = tonumber(interface:match("(%d+)G") or "0")
license.volte = tonumber(interface:match("(%d+)V") or "0")

local fxso_cfg = uci:get_all("endpoint_fxso") or {}
local sipphone_cfg = uci:get_all("endpoint_sipphone") or {}
local number_profile_cfg = uci:get_all("profile_number") or {}

local ext_callin_chk_table = {}
local ext_callout_chk_table = {}

local number_filter = {}

if not fs.access("/tmp/fsconf/dialplan/public") then
	exe("mkdir -p /tmp/fsconf/dialplan/public")
end

exe("rm -rf "..extension_callout_check_00)
--exe("rm -rf "..did_call_00.." "..extension_call_00.." "..extension_call_z99.." "..extension_callout_check_00)

for k,v in pairs(number_profile_cfg) do
	if v.index then
		number_filter[v.index]={}
		if v.callerlength and "" ~= v.callerlength then
			number_filter[v.index]["callerlength"] = v.callerlength
		end
		if v.caller then
			if ("table" == type(v.caller) and v["caller"][1] and (not v["caller"][1]:match("^%s*$"))) or ("string" == type(v.caller) and (not v.caller:match("^%s*$"))) then
				number_filter[v.index]["caller"]=v.caller
			end
		end
		if v.calledlength and "" ~= v.calledlength then
			number_filter[v.index]["calledlength"] = v.calledlength
		end
		if v.called then
			if ("table" == type(v.called) and v["called"][1] and (not v["called"][1]:match("^%s*$"))) or ("string" == type(v.called) and (not v.called:match("^%s*$"))) then
				number_filter[v.index]["called"]=v.called
			end
		end
	end
end

for k,v in pairs(sipphone_cfg) do
	if v.user and v.index and v.status == "Enabled" then
		if "blacklist" == v.callin_filter and v.callin_filter_blacklist and number_filter[v.callin_filter_blacklist] and (number_filter[v.callin_filter_blacklist]["callerlength"] or number_filter[v.callin_filter_blacklist]["caller"]) then
			local tmp = {chan_name="sofia/user/"..v.user.."/",number=v.user,filter="blacklist",blacklist=v.callin_filter_blacklist,bridge_channel="SIP Extension/"..v.user}
			table.insert(ext_callin_chk_table,tmp)
		elseif "whitelist" == v.callin_filter and v.callin_filter_whitelist and number_filter[v.callin_filter_whitelist] and (number_filter[v.callin_filter_whitelist]["callerlength"] or number_filter[v.callin_filter_whitelist]["caller"]) then
			local tmp = {chan_name="sofia/user/"..v.user.."/",number=v.user,filter="whitelist",whitelist=v.callin_filter_whitelist,bridge_channel="SIP Extension/"..v.user}
			table.insert(ext_callin_chk_table,tmp)
		end

		if "blacklist" == v.callout_filter and v.callout_filter_blacklist and number_filter[v.callout_filter_blacklist] and (number_filter[v.callout_filter_blacklist]["calledlength"] or number_filter[v.callout_filter_blacklist]["called"]) then
			local tmp = {chan_name="sofia/user/"..v.user.."/",number=v.user,filter="blacklist",blacklist=v.callout_filter_blacklist}
			table.insert(ext_callout_chk_table,tmp)
		elseif "whitelist" == v.callout_filter and v.callout_filter_whitelist and number_filter[v.callout_filter_whitelist] and (number_filter[v.callout_filter_whitelist]["calledlength"] or number_filter[v.callout_filter_whitelist]["called"]) then
			local tmp = {chan_name="sofia/user/"..v.user.."/",number=v.user,filter="whitelist",whitelist=v.callout_filter_whitelist}
			table.insert(ext_callout_chk_table,tmp)
		end
	end
end

for k,v in pairs(fxso_cfg) do
	if v[".type"] == "fxs" and v.index and v.status == "Enabled" then
		if v.number_1 and "" ~= v.number_1 and license.fxs > 0 then
			if "blacklist" == v.callin_filter_1 and v.callin_filter_blacklist_1 and number_filter[v.callin_filter_blacklist_1] and (number_filter[v.callin_filter_blacklist_1]["callerlength"] or number_filter[v.callin_filter_blacklist_1]["caller"]) then
				local tmp = {chan_name="^FreeTDM/"..v.index.."/1|^FreeTDM/"..v.index..":1",number=v.number_1,filter="blacklist",blacklist=v.callin_filter_blacklist_1,bridge_channel="FXS Extension/"..v.number_1}
				table.insert(ext_callin_chk_table,tmp)
			elseif "whitelist" == v.callin_filter_1 and v.callin_filter_whitelist_1 and number_filter[v.callin_filter_whitelist_1] and (number_filter[v.callin_filter_whitelist_1]["callerlength"] or number_filter[v.callin_filter_whitelist_1]["caller"]) then
				local tmp = {chan_name="^FreeTDM/"..v.index.."/1|^FreeTDM/"..v.index..":1",number=v.number_1,filter="whitelist",whitelist=v.callin_filter_whitelist_1,bridge_channel="FXS Extension/"..v.number_1}
				table.insert(ext_callin_chk_table,tmp)
			end

			if "blacklist" == v.callout_filter_1 and v.callout_filter_blacklist_1 and number_filter[v.callout_filter_blacklist_1] and (number_filter[v.callout_filter_blacklist_1]["calledlength"] or number_filter[v.callout_filter_blacklist_1]["called"]) then
				local tmp = {chan_name="^FreeTDM/"..v.index.."/1|^FreeTDM/"..v.index..":1",number=v.number_1,filter="blacklist",blacklist=v.callout_filter_blacklist_1}
				table.insert(ext_callout_chk_table,tmp)
			elseif "whitelist" == v.callout_filter_1 and v.callout_filter_whitelist_1 and number_filter[v.callout_filter_whitelist_1] and (number_filter[v.callout_filter_whitelist_1]["calledlength"] or number_filter[v.callout_filter_whitelist_1]["called"]) then
				local tmp = {chan_name="^FreeTDM/"..v.index.."/1|^FreeTDM/"..v.index..":1",number=v.number_1,filter="whitelist",whitelist=v.callout_filter_whitelist_1}
				table.insert(ext_callout_chk_table,tmp)
			end
		end
		if v.number_2 and "" ~= v.number_2 and license.fxs > 1 then
			if "blacklist" == v.callin_filter_2 and v.callin_filter_blacklist_2 and number_filter[v.callin_filter_blacklist_2] and (number_filter[v.callin_filter_blacklist_2]["callerlength"] or number_filter[v.callin_filter_blacklist_2]["caller"]) then
				local tmp = {chan_name="^FreeTDM/"..v.index.."/2|^FreeTDM/"..v.index..":2",number=v.number_2,filter="blacklist",blacklist=v.callin_filter_blacklist_2,bridge_channel="FXS Extension/"..v.number_2}
				table.insert(ext_callin_chk_table,tmp)
			elseif "whitelist" == v.callin_filter_2 and v.callin_filter_whitelist_2 and number_filter[v.callin_filter_whitelist_2] and (number_filter[v.callin_filter_whitelist_2]["callerlength"] or number_filter[v.callin_filter_whitelist_2]["caller"]) then
				local tmp = {chan_name="^FreeTDM/"..v.index.."/2|^FreeTDM/"..v.index..":2",number=v.number_2,filter="whitelist",whitelist=v.callin_filter_whitelist_2,bridge_channel="FXS Extension/"..v.number_2}
				table.insert(ext_callin_chk_table,tmp)
			end

			if "blacklist" == v.callout_filter_2 and v.callout_filter_blacklist_2 and number_filter[v.callout_filter_blacklist_2] and (number_filter[v.callout_filter_blacklist_2]["calledlength"] or number_filter[v.callout_filter_blacklist_2]["called"]) then
				local tmp = {chan_name="^FreeTDM/"..v.index.."/2|^FreeTDM/"..v.index..":2",number=v.number_2,filter="blacklist",blacklist=v.callout_filter_blacklist_2}
				table.insert(ext_callout_chk_table,tmp)
			elseif "whitelist" == v.callout_filter_2 and v.callout_filter_whitelist_2 and number_filter[v.callout_filter_whitelist_2] and (number_filter[v.callout_filter_whitelist_2]["calledlength"] or number_filter[v.callout_filter_whitelist_2]["called"]) then
				local tmp = {chan_name="^FreeTDM/"..v.index.."/2|^FreeTDM/"..v.index..":2",number=v.number_2,filter="whitelist",whitelist=v.callout_filter_whitelist_2}
				table.insert(ext_callout_chk_table,tmp)
			end
		end
	end
end

function add_action(parent_node,app,data)
	if parent_node and app then
		local action = mxml.newnode(parent_node,"action")
		mxml.setattr(action,"application",app)
		if data then
			mxml.setattr(action,"data",data)
		end
	end
end
function add_anti_action(parent_node,app,data)
	if parent_node and app then
		local action = mxml.newnode(parent_node,"anti-action")
		mxml.setattr(action,"application",app)
		if data then
			mxml.setattr(action,"data",data)
		end
	end
end
function add_to_destnum_list(src,dst)
	if not src or "" == src then
		return dst
	end
	local num = string.gsub(src,"+","\\+")
	num = string.gsub(num,"*","\\*")
	if not dst or dst == "" then
		dst = "^"..num.."[*#]{0,1}$"
	elseif not string.find(dst,"^"..num.."$") then
		dst = dst.."|^"..num.."[*#]{0,1}$"
	end

	return dst
end
function add_condition(parent_node,field,expression)
	local condition = mxml.newnode(parent_node,"condition")
	if field == "regex" or field == "wday" or field == "time-of-day" or field == "date-time" then
		mxml.setattr(condition,field,expression)
	elseif field and expression then
		mxml.setattr(condition,"field",field)
		mxml.setattr(condition,"expression",expression)
	end
	return condition
end
function add_regex(parent_node,field,expression)
	local condition = mxml.newnode(parent_node,"regex")
	if field and expression then
		mxml.setattr(condition,"field",field)
		mxml.setattr(condition,"expression",expression)
	end
	return condition
end
function add_child_node(parent_node,child_node_name,param)
	if parent_node and child_node_name and param then
		local child_node = mxml.newnode(parent_node,child_node_name)
		if "table" == type(param) then
			for k,v in ipairs(param) do
				mxml.setattr(child_node,v.param,v.value)
			end
		end
		return child_node
	else
		return parent_node
	end
end
function number_regular_parse(parent_node,field,value)
	function string_val_parse(value)
		if value:match("^[0-9a-zA-Z]+$") then
			return "^"..value 
		elseif value:match("^[0-9a-zA-Z|]+$") then
			return "^".."("..value..")"
		else
			return value
		end
	end
	if value and "string" == type(value) then
		return add_regex(parent_node,field,string_val_parse(value))
	elseif value and "table" == type(value) then
		local result_str
		for k,v in ipairs(value) do
			if "" ~= v then
				result_str=(result_str and (result_str.."|") or "")..string_val_parse(v)
			end
		end
		return add_regex(parent_node,field,result_str)
	end
end
function number_length_parse(value)
	local tmp = luci.util.split(value,"|")
	local exp = ""
	for _,v2 in pairs(tmp) do
		if v2 ~= "" then
			if exp == "" then
				exp = tostring("^(\\d{")..string.gsub(v2,"-",",")..tostring("})$")
			else
				exp = exp.."|"..tostring("^(\\d{")..string.gsub(v2,"-",",")..tostring("})$")
			end
		end
	end
	return exp
end
function callin_number_condition(parent_node,value)
	local regex
	if number_filter[value] and number_filter[value]["callerlength"] then
		regex = add_regex(parent_node,"caller_id_number",number_length_parse(number_filter[value]["callerlength"]))
	end
	if number_filter[value] and number_filter[value]["caller"] then
		regex = number_regular_parse(parent_node,"caller_id_number",number_filter[value]["caller"])
	end
	return regex
end
function callout_number_condition(parent_node,value)
	local regex
	if number_filter[value] and number_filter[value]["calledlength"] then
		regex = add_regex(parent_node,"destination_number",number_length_parse(number_filter[value]["calledlength"]))
	end
	if number_filter[value] and number_filter[value]["called"] then
		regex = number_regular_parse(parent_node,"destination_number",number_filter[value]["called"])
	end
	return regex
end

function generate_extension_callin_check_xml()
	if next(ext_callin_chk_table) then
		local xml = mxml:newxml()
		local include = mxml.newnode(xml,"include")

		for k,v in ipairs(ext_callin_chk_table) do
			if "blacklist" == v.filter then
				local extension = add_child_node(include,"extension",{{param="name",value=v.number.."_call_in_blacklist_check"},{param="continue",value="true"}})
				local condition = add_child_node(extension,"condition",{{param="regex",value="all"},{param="require-nested",value="true"}})
				callin_number_condition(condition,v.blacklist)
				add_condition(condition,"destination_number","^"..v.number.."[*#]{0,1}$")
				add_action(condition,"set","my_bridge_channel="..v.bridge_channel)
				add_action(condition,"log","ERR Extension "..v.number.." can not call in ! (Blacklist Matched)")
				add_action(condition,"hangup","INVALID_NUMBER_FORMAT")
			else
				local extension = add_child_node(include,"extension",{{param="name",value=v.number.."_call_in_whitelist_check"},{param="continue",value="true"}})
				local condition = add_child_node(extension,"condition",{{param="regex",value="all"},{param="require-nested",value="true"}})
				callin_number_condition(condition,v.whitelist)
				add_condition(condition,"destination_number","^"..v.number.."[*#]{0,1}$")
				add_anti_action(condition,"set","my_bridge_channel="..v.bridge_channel)
				add_anti_action(condition,"log","ERR Extension "..v.number.." can not call in ! (Whitelist Not Matched)")
				add_anti_action(condition,"hangup","INVALID_NUMBER_FORMAT")
			end
		end

		mxml.savefile(xml,extension_callin_check)
		mxml.release(xml)
	end
end

function generate_00_extension_callout_check_xml()
	if next(ext_callout_chk_table) then
		local xml = mxml:newxml()
		local include = mxml.newnode(xml,"include")

		for k,v in ipairs(ext_callout_chk_table) do
			if "blacklist" == v.filter then
				local extension = add_child_node(include,"extension",{{param="name",value=v.number.."_call_out_blacklist_check"},{param="continue",value="true"}})
				local condition = add_child_node(extension,"condition",{{param="regex",value="all"},{param="require-nested",value="true"}})
				callout_number_condition(condition,v.blacklist)
				add_condition(condition,"chan_name",v.chan_name)
				add_action(condition,"log","ERR Extension "..v.number.." can not call out ! (Blacklist Matched)")
				add_action(condition,"hangup","INVALID_NUMBER_FORMAT")
			else
				local extension = add_child_node(include,"extension",{{param="name",value=v.number.."_call_out_whitelist_check"},{param="continue",value="true"}})
				local condition = add_child_node(extension,"condition",{{param="regex",value="all"},{param="require-nested",value="true"}})
				callout_number_condition(condition,v.whitelist)
				add_condition(condition,"chan_name",v.chan_name)
				add_anti_action(condition,"log","ERR Extension "..v.number.." can not call out ! (Whitelist Not Matched)")
				add_anti_action(condition,"hangup","INVALID_NUMBER_FORMAT")
			end
		end
		mxml.savefile(xml,extension_callout_check_00)
		mxml.release(xml)
	end
end

generate_extension_callin_check_xml()
generate_00_extension_callout_check_xml()
