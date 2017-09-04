local util = require "luci.util"
local fs = require "nixio.fs"
local mxml = require "mxml"
local base64 = require "luci.base64"
local exe = os.execute
local uci = require "luci.model.uci".cursor("/tmp/config","/tmp/state")
local action = arg[1]

local cfgfilelist = {"system","profile_number","endpoint_fxso","endpoint_sipphone","endpoint_mobile"}
for k,v in ipairs(cfgfilelist) do
	exe("cp /etc/config/"..v.." /tmp/config")
end

local users_dir = "/tmp/fsconf/directory/default"
local pstn_extension_dir = "/tmp/fsconf/dialplan/extension"
local lua_extension_data_dir = "/tmp/fsconf/data/extension"
local lua_trunk_data_dir = "/tmp/fsconf/data/trunk"
--local lua_number_to_extension = "/tmp/fsconf/data/number_to_extension"

local fxso_cfg = uci:get_all("endpoint_fxso") or {}
local mobile_cfg = uci:get_all("endpoint_mobile") or {}
local sipphone_cfg = uci:get_all("endpoint_sipphone") or {}

local interface = uci:get("system","main","interface") or ""
local license = {}
license.fxs = tonumber(interface:match("(%d+)S") or "0")
license.fxo = tonumber(interface:match("(%d+)O") or "0")
license.gsm = tonumber(interface:match("(%d+)G") or "0")
license.volte = tonumber(interface:match("(%d+)V") or "0")

local change_all = true
local changes_sipp = {}
local changes_fxs = {}
local changes_fxo = {}
local changes_mobile = {}
local del_users_cmd = {"cd "..users_dir..";rm -rf "}
local del_pstn_extension_cmd = {"cd "..pstn_extension_dir..";rm -rf"}
local del_lua_extension_data_cmd = {"cd "..lua_extension_data_dir..";rm -rf"}
local del_lua_trunk_data_cmd = {"cd "..lua_trunk_data_dir..";rm -rf"}

if fs.access("/tmp/config/uci_changes") then
	local tmp_tb = uci:get("uci_changes","endpoint_sipphone","sip") or {}
	if next(tmp_tb) then
		change_all = false
		for _,v in pairs(tmp_tb) do
			changes_sipp[v] = 1
			del_users_cmd[#del_users_cmd+1] = " SIPP-"..v.."*.xml"
			del_pstn_extension_cmd[#del_pstn_extension_cmd+1] = " SIPP-"..v.."*.xml"
			del_lua_extension_data_cmd[#del_lua_extension_data_cmd+1] = " SIPP-"..v.."*"
		end
	end

	tmp_tb = uci:get("uci_changes","endpoint_fxso","fxs") or {}
	if next(tmp_tb) then
		change_all = false
		for _,v in pairs(tmp_tb) do
			changes_fxs[v] = 1
			del_users_cmd[#del_users_cmd+1] = " FXS-"..v.."*.xml"
			del_pstn_extension_cmd[#del_pstn_extension_cmd+1] = " FXS-"..v.."*.xml"
			del_lua_extension_data_cmd[#del_lua_extension_data_cmd+1] = " FXS-"..v.."*"
		end
	end
	tmp_tb = uci:get("uci_changes","endpoint_fxso","fxo") or {}
	if next(tmp_tb) then
		change_all = false
		for _,v in pairs(tmp_tb) do
			changes_fxo[v] = 1
			del_pstn_extension_cmd[#del_pstn_extension_cmd+1] = " FXO-"..v.."*.xml"
			del_lua_trunk_data_cmd[#del_lua_trunk_data_cmd+1] = " FXO-"..v.."*"
		end
	end

	tmp_tb = uci:get("uci_changes","endpoint_mobile","index") or {}
	if next(tmp_tb) then
		change_all = false
		for _,v in pairs(tmp_tb) do
			changes_mobile[v] = 1
			del_pstn_extension_cmd[#del_pstn_extension_cmd+1] = " mobile-"..v.."*.xml"
			del_lua_trunk_data_cmd[#del_lua_trunk_data_cmd+1] = " mobile-"..v.."*"
		end
	end
end

--@ delete old xml file
if not fs.access(users_dir) then
	os.execute("mkdir -p "..users_dir)
elseif fs.access(users_dir) and change_all then
	os.execute("rm -rf "..users_dir.."/*.xml")
end
if not fs.access(pstn_extension_dir) then
	os.execute("mkdir -p "..pstn_extension_dir)
elseif fs.access(pstn_extension_dir) and change_all then
	os.execute("rm -rf "..pstn_extension_dir.."/*.xml")
end
if not fs.access(lua_extension_data_dir) then
	os.execute("mkdir -p "..lua_extension_data_dir)
elseif fs.access(lua_extension_data_dir) and change_all then
	os.execute("rm -rf "..lua_extension_data_dir.."/*")
end
if not fs.access(lua_trunk_data_dir) then
	os.execute("mkdir -p "..lua_trunk_data_dir)
elseif fs.access(lua_trunk_data_dir) and change_all then
	os.execute("rm -rf "..lua_trunk_data_dir.."/*")
end

if not change_all then
	if #del_users_cmd > 1 then
		exe(table.concat(del_users_cmd,""))
	end
	if #del_pstn_extension_cmd > 1 then
		exe(table.concat(del_pstn_extension_cmd,""))
	end
	if #del_lua_extension_data_cmd > 1 then
		exe(table.concat(del_lua_extension_data_cmd,""))
	end
	if #del_lua_trunk_data_cmd > 1 then
		exe(table.concat(del_lua_trunk_data_cmd,""))
	end
end

local number_to_extension = {}
for k,v in pairs(sipphone_cfg) do
	if v.user and v.index and v.status == "Enabled" and (change_all or changes_sipp[v.index]) then
		local dtb = {}
		dtb[#dtb+1] = "[\"SIPP-"..v.index.."\"]={"
		dtb[#dtb+1] = "[\"type\"]=\"sipp\","
		dtb[#dtb+1] = "[\"number\"]=\""..v.user.."\","
		if v.waiting then
			dtb[#dtb+1] = "[\"waiting\"]=\""..(v.waiting or "").."\","
		end
		if v.notdisturb then
			dtb[#dtb+1] =  "[\"notdisturb\"]=\""..(v.notdisturb or "").."\","
		end
		if v.forward_unregister_dst then
			dtb[#dtb+1] = "[\"forward_unregister_dst\"]=\""..(v.forward_unregister_dst or "").."\","
		end
		if v.forward_unregister then
			dtb[#dtb+1] = "[\"forward_unregister\"]=\""..(v.forward_unregister or "").."\","
		end
		if v.forward_uncondition_dst then
			dtb[#dtb+1] = "[\"forward_uncondition_dst\"]=\""..(v.forward_uncondition_dst or "").."\","
		end
		if v.forward_uncondition then
			dtb[#dtb+1] = "[\"forward_uncondition\"]=\""..(v.forward_uncondition or "").."\","
		end
		if v.forward_busy_dst then
			dtb[#dtb+1] = "[\"forward_busy_dst\"]=\""..(v.forward_busy_dst or "").."\","
		end
		if v.forward_busy then
			dtb[#dtb+1] = "[\"forward_busy\"]=\""..(v.forward_busy or "").."\","
		end
		if v.forward_noreply_dst then
			dtb[#dtb+1] = "[\"forward_noreply_dst\"]=\""..(v.forward_noreply_dst or "").."\","
		end
		if v.forward_noreply then
			dtb[#dtb+1] = "[\"forward_noreply\"]=\""..(v.forward_noreply or "").."\","
		end
		if v.forward_noreply_timeout then
			dtb[#dtb+1] = "[\"forward_noreply_timeout\"]=\""..(v.forward_noreply_timeout or "").."\","
		end
		if v.profile then
			dtb[#dtb+1] = "[\"profile\"]=\""..(v.profile or "").."\","
			dtb[#dtb+1] = "[\"reg_query\"]=\"sofia status profile "..v.profile.." reg "..v.user.."\","
		end
		dtb[#dtb+1] = "},"
		dtb[#dtb+1] = "\n"
		fs.writefile(lua_extension_data_dir.."/SIPP-"..v.index, table.concat(dtb, ""))
		--number_to_extension[#number_to_extension+1] = "[\""..v.user.."\"]=\"SIPP-"..v.index.."\","
	end
end

for k,v in pairs(fxso_cfg) do
	if v['.type'] == 'fxs' and v.index and v.status == "Enabled" and (change_all or changes_fxs[v.index]) then
		local dtb = {}
		if v.number_1 then
			dtb[#dtb+1] = "[\"FXS-"..v.index.."_1\"]={"
			dtb[#dtb+1] = "[\"type\"]=\"fxs\","
			dtb[#dtb+1] = "[\"number\"]=\""..v.number_1.."\","
			if v.waiting_1 then
				dtb[#dtb+1] = "[\"waiting\"]=\""..(v.waiting_1 or "").."\","
			end
			if v.notdisturb_1 then
				dtb[#dtb+1] = "[\"notdisturb\"]=\""..(v.notdisturb_1 or "").."\","
			end
			if v.forward_uncondition_dst_1 then
				dtb[#dtb+1] = "[\"forward_uncondition_dst\"]=\""..(v.forward_uncondition_dst_1 or "").."\","
			end
			if v.forward_uncondition_1 then
				dtb[#dtb+1] = "[\"forward_uncondition\"]=\""..(v.forward_uncondition_1 or "").."\","
			end
			if v.forward_busy_dst_1 then
				dtb[#dtb+1] = "[\"forward_busy_dst\"]=\""..(v.forward_busy_dst_1 or "").."\","
			end
			if v.forward_busy_1 then
				dtb[#dtb+1] = "[\"forward_busy\"]=\""..(v.forward_busy_1 or "").."\","
			end
			if v.forward_noreply_dst_1 then
				dtb[#dtb+1] = "[\"forward_noreply_dst\"]=\""..(v.forward_noreply_dst_1 or "").."\","
			end
			if v.forward_noreply_1 then
				dtb[#dtb+1] = "[\"forward_noreply\"]=\""..(v.forward_noreply_1 or "").."\","
			end
			if v.forward_noreply_timeout_1 then
				dtb[#dtb+1] = "[\"forward_noreply_timeout\"]=\""..(v.forward_noreply_timeout_1 or "").."\","
			end
			if v.profile then
				dtb[#dtb+1] = "[\"profile\"]=\""..(v.profile or "").."\","
			end
			dtb[#dtb+1] = "},"
			dtb[#dtb+1] = "\n"
			--number_to_extension[#number_to_extension+1] = "[\""..v.number_1.."\"]=\"FXS-"..v.index.."_1\","
		end

		if v.number_2 and license.fxs > 1 then
			dtb[#dtb+1] = "[\"FXS-"..v.index.."_2\"]={"
			dtb[#dtb+1] = "[\"type\"]=\"fxs\","
			dtb[#dtb+1] = "[\"number\"]=\""..v.number_2.."\","
			if v.waiting_2 then
				dtb[#dtb+1] = "[\"waiting\"]=\""..(v.waiting_2 or "").."\","
			end
			if v.notdisturb_2 then
				dtb[#dtb+1] = "[\"notdisturb\"]=\""..(v.notdisturb_2 or "").."\","
			end
			if v.forward_uncondition_dst_2 then
				dtb[#dtb+1] = "[\"forward_uncondition_dst\"]=\""..(v.forward_uncondition_dst_2 or "").."\","
			end
			if v.forward_uncondition_2 then
				dtb[#dtb+1] = "[\"forward_uncondition\"]=\""..(v.forward_uncondition_2 or "").."\","
			end
			if v.forward_busy_dst_2 then
				dtb[#dtb+1] = "[\"forward_busy_dst\"]=\""..(v.forward_busy_dst_2 or "").."\","
			end
			if v.forward_busy_2 then
				dtb[#dtb+1] = "[\"forward_busy\"]=\""..(v.forward_busy_2 or "").."\","
			end
			if v.forward_noreply_dst_2 then
				dtb[#dtb+1] = "[\"forward_noreply_dst\"]=\""..(v.forward_noreply_dst_2forward_noreply_dst_2 or "").."\","
			end
			if v.forward_noreply_2 then
				dtb[#dtb+1] = "[\"forward_noreply\"]=\""..(v.forward_noreply_2 or "").."\","
			end
			if v.forward_noreply_timeout_2 then
				dtb[#dtb+1] = "[\"forward_noreply_timeout\"]=\""..(v.forward_noreply_timeout_2 or "").."\","
			end
			if v.profile then
				dtb[#dtb+1] = "[\"profile\"]=\""..(v.profile or "").."\","
			end
			dtb[#dtb+1] = "},"
			dtb[#dtb+1] = "\n"
			--number_to_extension[#number_to_extension+1] = "[\""..v.number_1.."\"]=\"FXS-"..v.index.."_2\","
		end
		if next(dtb) then
			fs.writefile(lua_extension_data_dir.."/FXS-"..v.index, table.concat(dtb, ""))
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
function generate_extension_xml(param)
	local xml = mxml:newxml()
	local include = mxml.newnode(xml,"include")
	local extension = mxml.newnode(include,"extension")
	mxml.setattr(extension,"name",param.number)

	local condition = add_condition(extension,"destination_number","^"..param.number.."[*#]{0,1}$")

	local filename = ""
	if "FXS" == param.slot_type or "FXO" == param.slot_type then
		filename = param.slot_type.."-"..param.index.."_"..param.port..".xml"
	else
		filename = param.slot_type.."-"..param.index..".xml"
	end

	if "FXS" == param.slot_type or "SIPP" == param.slot_type then
		add_action(condition,"set","my_exten_bridge_param="..param.bridge_data)
		add_action(condition,"set","my_callwaiting_number="..param.number)
		add_action(condition,"set","my_bridge_channel="..param.bridge_channel)
		if "SIPP" == param.slot_type then
			add_action(condition,"export","sip_contact_user="..param.number)
		end
		add_action(condition,"transfer","ExtensionService XML extension-service")
	else
		add_action(condition,"set","destination_number=${my_dst_number}")
		add_action(condition,"set","dest_chan_name="..param.bridge_channel)
		--这里设置一下bypass_media=false, 以防之前如果是sip到sip的bypass呼叫，呼转过来从fxo/gsm等接口出去，会没有语音
		add_action(condition,"set","bypass_media=false")
		add_action(condition,"lua","check_line_is_busy.lua "..param.bridge_data)
		add_action(condition,"ring_ready")
		add_action(condition,"bridge",param.bridge_data)
		
		local condition_transfer = mxml.newnode(extension,"condition")
		mxml.setattr(condition_transfer,"field","${transfer_name_on_fail}")
		mxml.setattr(condition_transfer,"expression","^FAIL")
		mxml.setattr(condition_transfer,"break","never")
		
		add_action(condition_transfer,"transfer","${transfer_name_on_fail} XML failroute")--@ when you set channel_var continue_on_fail,it will transfer the failed_hextension
	end

	mxml.savefile(xml,pstn_extension_dir.."/"..filename)
	mxml.release(xml)
end

function generate_pstn_extension_data()
	for k,v in pairs(fxso_cfg) do
		if v.index and v.status == "Enabled" then
			if v[".type"] == "fxs" and license.fxs > 0 and (change_all or changes_fxs[v.index]) then
				if v.number_1 and "" ~= v.number_1 then
					local xml = mxml:newxml()
					local include = mxml.newnode(xml, "include")
					local callgroup_user = mxml.newnode(include,"user")
					mxml.setattr(callgroup_user,"id",v.number_1)
					local callgroup_params = mxml.newnode(callgroup_user,"params")
					local callgroup_param = mxml.newnode(callgroup_params,"param")
					mxml.setattr(callgroup_param,"name","dial_string")
					mxml.setattr(callgroup_param,"value","freetdm/"..v.index.."/1/${digits}")
					local channel_name = mxml.newnode(callgroup_params,"param")
					mxml.setattr(channel_name,"name","channel_name")

					local param = {}
					param.index = v.index
					param.number = v.number_1
					param.bridge_data = "freetdm/"..v.index.."/1/${my_dst_number}"
					param.slot_type = "FXS"	
					param.port = "1"

					if license.fxs == 1 then
						mxml.setattr(channel_name,"value","FXS")
						param.bridge_channel = "FXS"
					else
						mxml.setattr(channel_name,"value","FXS Extension/"..v.number_1)
						param.bridge_channel = "FXS Extension/"..v.number_1
					end

					mxml.savefile(xml, users_dir.."/FXS-"..v.index.."_1.xml")
					mxml.release(xml)
					generate_extension_xml(param)
				end
				if v.number_2 and "" ~= v.number_2 and license.fxs > 1 then
					local xml = mxml:newxml()
					local include = mxml.newnode(xml, "include")
					local callgroup_user = mxml.newnode(include,"user")
					mxml.setattr(callgroup_user,"id",v.number_2)
					local callgroup_params = mxml.newnode(callgroup_user,"params")
					local callgroup_param = mxml.newnode(callgroup_params,"param")
					mxml.setattr(callgroup_param,"name","dial_string")
					mxml.setattr(callgroup_param,"value","freetdm/"..v.index.."/2/${digits}")
					local channel_name = mxml.newnode(callgroup_params,"param")
					mxml.setattr(channel_name,"name","channel_name")
					mxml.setattr(channel_name,"value","FXS Extension/"..v.number_2)

					local param = {}
					param.index = v.index
					param.number = v.number_2
					param.bridge_data = "freetdm/"..v.index.."/2/${my_dst_number}"
					param.slot_type = "FXS"
					param.port = "2"
					param.bridge_channel = "FXS Extension/"..v.number_2
					
					mxml.savefile(xml, users_dir.."/FXS-"..v.index.."_2.xml")
					mxml.release(xml)
					generate_extension_xml(param)
				end
			elseif v[".type"] == "fxo" and license.fxo > 0 and (change_all or changes_fxo[v.index]) then
				if v.number_1 and "" ~= v.number_1 and license.fxo > 1 then
					local param = {}
					param.index = v.index
					param.number = v.number_1
					param.bridge_data = "freetdm/"..v.index.."/1/${my_dst_number}"
					param.slot_type = "FXO"
					param.bridge_channel = "FXO Trunk/Port 0"
					param.port = "1"
					generate_extension_xml(param)
				end
				if v.number_2 and "" ~= v.number_2 then
					local param = {}
					param.index = v.index
					param.number = v.number_2
					param.bridge_data = "freetdm/"..v.index.."/2/${my_dst_number}"
					param.slot_type = "FXO"
					param.port = "2"
					if license.fxo == 1 then
						param.bridge_channel = "FXO"
					else
						param.bridge_channel = "FXO Trunk/Port 1"
					end
					generate_extension_xml(param)
				end
			end
		end
	end
	if license.gsm > 0 or license.volte > 0 then
		for k,v in pairs(mobile_cfg) do
			if v.index and v.slot_type and v.number and v.number ~= "" and v.slot_type and (v.slot_type:match("GSM$") or v.slot_type:match("VOLTE$")) and v.status == "Enabled" then
				local param = {}
				param.index = v.index
				param.number = v.number
				param.bridge_data = "gsmopen/"..v.slot_type.."/${my_dst_number}"
				if license.volte > 0 then
					param.bridge_channel = "VOLTE"
				else
					param.bridge_channel = "GSM"
				end
				param.slot_type = "mobile"
				
				generate_extension_xml(param)
			end
		end
	end
end
function netmask2num(val)
	local bit = require "bit"
	if val and "0.0.0.0" ~= val then
		if val:match("^%d+%.%d+%.%d+%.%d+$") then
			return val.."/"..32
		elseif val:match("^%d+%.%d+%.%d+%.%d+/%d+$") then
			return val
		elseif val:match("%d+%.%d+%.%d+%.%d+/%d+%.%d+%.%d+%.%d+$") then
			local addr = "0.0.0.0"
			local x = {}
			local cnt = 0
			addr,x[1],x[2],x[3],x[4] = val:match("^(%d+%.%d+%.%d+%.%d+)/(%d+)%.(%d+)%.(%d+)%.(%d+)$")
			for i=1,4 do
				for j=0,7 do
					local b = bit.band(tonumber(x[i]),bit.rshift(128,j))
					if 0 ~= b then
						cnt = cnt + 1
					else
						return addr.."/"..cnt
					end
				end
			end
		end
	else
		return "0.0.0.0/0"
	end
end
function generate_sip_extension_data()
	for k,v in pairs(sipphone_cfg) do
		if v.user and v.index and (change_all or changes_sip[v.index]) then
			local xml = mxml:newxml()
			local include = mxml.newnode(xml,"include")
			local user = mxml.newnode(include,"user")
			mxml.setattr(user,"id",v.user)

			local params = mxml.newnode(user,"params")
			local param = mxml.newnode(params,"param")
			if v.password and "" ~= v.password then
				mxml.setattr(param,"name","password-base64")
				mxml.setattr(param,"value",base64.enc(v.password))
			else
				mxml.setattr(param,"name","allow-empty-password")
				mxml.setattr(param,"value","on")
			end

			param = mxml.newnode(params,"param")
			mxml.setattr(param,"name","dial_string")
			mxml.setattr(param,"value","{sip_contact_user=${caller_id_number}}user/"..v.user.."@$${domain}")

			param = mxml.newnode(params,"param")
			mxml.setattr(param,"name","channel_name")
			mxml.setattr(param,"value","SIP Extension/"..(v.name or "unknown"))
				
			param = mxml.newnode(params,"param")
			mxml.setattr(param,"name","auth-profile")
			mxml.setattr(param,"value",v.profile or "")

			if v.from and "any" ~= v.from and v.ip then
				param = mxml.newnode(params,"param")
				mxml.setattr(param,"name","auth-acl")
				mxml.setattr(param,"value",netmask2num(v.ip))
			end

			if "Enabled" ~= v.status then
				param = mxml.newnode(params,"param")
				mxml.setattr(param,"name","sip-forbid-register")
				mxml.setattr(param,"value","on")
			end

			if v.nat and "on" == v.nat then
				local variables = mxml.newnode(user,"variables")
				local variable = mxml.newnode(variables,"variable")
				mxml.setattr(variable,"name","sip-force-contact")
				mxml.setattr(variable,"value","NDLB-connectile-dysfunction")
			end

			mxml.savefile(xml,users_dir.."/SIPP-"..v.index..".xml")
			mxml.release(xml)

			if "Enabled" == v.status then
				local param = {}
				param.index = v.index
				param.slot_type = "SIPP"
				param.number = v.user
				param.bridge_data = "{sip_contact_user=${ani}}user/"..v.user.."@${domain_name}"
				param.bridge_channel = "SIP Extension/"..(v.name or "unknown")

				generate_extension_xml(param)
			end
		end
	end
end

generate_pstn_extension_data()
generate_sip_extension_data()
