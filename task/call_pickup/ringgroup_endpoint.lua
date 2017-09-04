require "uci"
require "luci.util"
require "mxml"
local fs = require "nixio.fs"
local exe = os.execute
local cfgfilelist = {"endpoint_fxso","endpoint_sipphone","endpoint_ringgroup","feature_code"}
for k,v in ipairs(cfgfilelist) do
	exe("cp /etc/config/"..v.." /tmp/config")
end

local uci = uci.cursor("/tmp/config","/tmp/state")
local interface = uci:get("system","main","interface") or ""
local ringgroup_endpoint = uci:get_all("endpoint_ringgroup") or {}
local fxso_endpoint = uci:get_all("endpoint_fxso") or {}
local sip_extension = uci:get_all("endpoint_sipphone") or {}
local feature_code = uci:get_all("feature_code") or {}
local intercept_code_str = ""
local ringgroup_template = "/usr/lib/lua/luci/scripts/ringgroup_template.lua"
local callgroup_dir = "/etc/freeswitch/conf/directory/default/users.xml"
local intercept_dir = "/etc/freeswitch/conf/dialplan/public/intercept.xml"
local group_bridge_str = ""
local group_bridge_channel_str = ""
local group_unconditional_forward_str = ""
local group_busy_forward_str = ""
local group_unregister_forward_str = ""
local group_codec_str = ""
local group_user_reg_str = ""
local group_call_pickup_str = ""
local pickup_in_extension = {}
local extension_data = {}
local extension_chan_index = {}
local extension_number_index = {}
local extension_number_reg_index = {}
local extension_codec = {}
local bind_transfer_dtmf = ""
local attended_transfer_dtmf = ""
--@ delete old ringgroup lua scripts
exe("rm /etc/freeswitch/scripts/RingGroup-*.lua")

if fs.access(intercept_dir) then
	exe("rm "..intercept_dir)
end
--@ Parse callgroup.xml
local root

if fs.access(callgroup_dir) then
	root = mxml.parsefile(callgroup_dir)
end
--@ Create intercept.xml
local intercept_xml = mxml:newxml()

local intercept_include = mxml.newnode(intercept_xml,"include")

--@ get the feature code
for k,v in pairs(feature_code) do
	if v.index == "22" and v.code and v.status == "Enabled" then
		intercept_code_str = string.gsub(v.code,"*","\\*")
	elseif v.index == "12"  and v.code and v.status == "Enabled" then
		bind_transfer_dtmf = string.sub(v.code,2,string.len(v.code))
	elseif v.index == "13"  and v.code and v.status == "Enabled" then
		attended_transfer_dtmf = string.sub(v.code,2,string.len(v.code))
	end
end

--@ Extension for intercept a call in callgroup 
local intercept_extension = mxml.newnode(intercept_include,"extension")
mxml.setattr(intercept_extension,"name","intercept-default")
local condition = mxml.newnode(intercept_extension,"condition")
mxml.setattr(condition,"field","chan_name")
mxml.setattr(condition,"expression","^FreeTDM|^sofia/user")
condition = mxml.newnode(intercept_extension,"condition")
mxml.setattr(condition,"field","destination_number")
mxml.setattr(condition,"expression","^"..intercept_code_str.."$")

local action = mxml.newnode(condition,"action")
mxml.setattr(action,"application","set")
mxml.setattr(action,"data","intercept_unanswered_only=true")

action = mxml.newnode(condition,"action")
mxml.setattr(action,"application","intercept")
mxml.setattr(action,"data","${hash(select/callgroup/${user_data(${caller_id_number}@${domain} var callgroup)})}")

action = mxml.newnode(condition,"action")
mxml.setattr(action,"application","set")
mxml.setattr(action,"data","dest_chan_name=RingGroup-${user_data(${caller_id_number}@${domain} var callgroup)}")
--@ End

function add_user_to_callgroup(user_id,user_callgroup)
	if user_id and user_callgroup and root then
		local user_node = mxml.find(root,"include","user","id",user_id)
		if user_node then
			local params = mxml.getfirstchild(user_node)
			local variables
			if params then
				variables = mxml.getnextsibling(params)
			end
			if not variables then
				variables = mxml.newnode(user_node,"variables")
			end

			local user_context = mxml.find(variables,nil,"variable","name","user_context")
			if not user_context then
				user_context = mxml.newnode(variables,"variable")
				mxml.setattr(user_context,"name","user_context")
				mxml.setattr(user_context,"value","public")
			else
				mxml.setattr(user_context,"value","public")
			end

			local callgroup = mxml.find(variables,nil,"variable","name","callgroup")
			if not callgroup then
				callgroup = mxml.newnode(variables,"variable")
				mxml.setattr(callgroup,"name","callgroup")
				mxml.setattr(callgroup,"value",user_callgroup)
			else
				mxml.setattr(callgroup,"value",user_callgroup)
			end
		end
	end
end

function get_codec_string_by_sip_profile()
	local codec_string = {}
	local codec = uci:get_all("profile_codec") or {}
	local sip_profile = uci:get_all("profile_sip") or {}

	for k,v in pairs(sip_profile) do
		for i,j in pairs(codec) do
			if v.index and v.outbound_codec_prefs and j.index and v.outbound_codec_prefs == j.index and j.code then
				codec_string[v.index] = table.concat(j.code,",")
			end
		end
	end

	return codec_string
end

local codec = get_codec_string_by_sip_profile()

for k,v in pairs(sip_extension) do
	if v.index and v.user and v.name and v.profile and "Enabled" == v.status and (not ("Activate" == v.notdisturb)) then
		extension_data[v.index]={}
		extension_data[v.index]["number"]=v.user
		extension_data[v.index]["codec"]=codec[v.profile] or ""
		extension_data[v.index]["reg_query"]="sofia status profile "..v.profile.." reg "..v.user
		extension_data[v.index]["name"]="SIP Extension/"..(v.name or "unknown")
		extension_codec[v.user]=codec[v.profile] or ""
		extension_chan_index["user/"..v.user] = v.user
		extension_number_index[v.user] = "user\\/"..v.user
		extension_number_reg_index[v.user] = "sofia status profile "..v.profile.." reg "..v.user
		extension_data[v.index]["call_pickup"] = v.call_pickup or "ringgrp"
		if v.forward_uncondition and "Deactivate" ~= v.forward_uncondition and v.forward_uncondition:match("^%w+$") then
			extension_data[v.index]["forward_uncondition"] = v.forward_uncondition
		end
		if v.forward_busy and "Deactivate" ~= v.forward_busy and v.forward_busy:match("^%w+$") then
			extension_data[v.index]["forward_busy"] = v.forward_busy
		end
		if v.forward_unregister and "Deactivate" ~= v.forward_unregister and v.forward_unregister:match("^%w+$") then
			extension_data[v.index]["forward_unregister"] = v.forward_unregister
		end
	end
end

for k,v in pairs(fxso_endpoint) do
	if v.index and v[".type"] == "fxs" and interface and interface:match("S")then
		if v.number_1 then
			extension_chan_index["freetdm\\/"..v.index.."\\/1\\/"..v.number_1] = v.number_1
			extension_number_index[v.number_1] = "freetdm\\/"..v.index.."\\/1\\/"..v.number_1
		end
		if interface and interface:match("2S") and v.number_2 then
			extension_chan_index["freetdm\\/"..v.index.."\\/2\\/"..v.number_2] = v.number_2
			extension_number_index[v.number_2] = "freetdm\\/"..v.index.."\\/2\\/"..v.number_2
		end
	end
end

function add_members_to_group(members_tb,callgroup_id)
	if members_tb == nil or type(members_tb) ~= "table" or callgroup_id == nil then
		return
	end
	local chan_name = ""
	local pickup_in_ringgrp = {}

	for _,v in ipairs(members_tb) do
		local exp = ""
		local bridge_channel = "unknown"

		if v:match("^FXS") then
			local m_index,m_port = v:match("^FXS%-(%d+)/([0|1])")
			if m_index and m_port then
				for k2,v2 in pairs(fxso_endpoint) do
					if v2.slot_type and v2.slot_type:match("FXS") and m_index == v2.index and "Enabled" == v2.status then
						if m_port == "0" and (not ("Activate" == v2.notdisturb_1)) then
							exp = "freetdm\\/"..m_index.."\\/"..tostring(tonumber(m_port)+1).."\\/"..v2.number_1
							--@ add node for xml
							add_user_to_callgroup(v2.number_1,callgroup_id)	
							if chan_name == "" then
								chan_name = "^FreeTDM/"..m_index..":1"
							else
								chan_name = chan_name.."|".."^FreeTDM/"..m_index..":1"
							end
							if v2.forward_uncondition_1 and "Deactivate" ~= v2.forward_uncondition_1 and v2.forward_uncondition_1:match("^%w+$") then
								group_unconditional_forward_str = group_unconditional_forward_str.."[\""..exp.."\"]=\""..extension_number_index[v2.forward_uncondition_1].."\","
								if extension_number_reg_index[v2.forward_uncondition_1] then
									if (not string.find(group_user_reg_str,"%[\""..v2.forward_uncondition_1.."\"%]")) then
										group_user_reg_str = group_user_reg_str.."[\""..v2.forward_uncondition_1.."\"]=\""..extension_number_reg_index[v2.forward_uncondition_1].."\","
									end
									if (not string.find(group_codec_str,"%[\""..v2.forward_uncondition_1.."\"%]")) then
										group_codec_str = group_codec_str.."[\""..v2.forward_uncondition_1.."\"]=\""..extension_codec[v2.forward_uncondition_1].."\","
									end
								end
							end
							if v2.forward_busy_1 and "Deactivate" ~= v2.forward_busy_1 and v2.forward_busy_1:match("^%w+$") then
								group_busy_forward_str = group_busy_forward_str.."[\""..exp.."\"]=\""..extension_number_index[v2.forward_busy_1].."\","
								if extension_number_reg_index[v2.forward_busy_1] then
									if (not string.find(group_user_reg_str,"%[\""..v2.forward_busy_1.."\"%]")) then
										group_user_reg_str = group_user_reg_str.."[\""..v2.forward_busy_1.."\"]=\""..extension_number_reg_index[v2.forward_busy_1].."\","
									end
									if (not string.find(group_codec_str,"%[\""..v2.forward_busy_1.."\"%]")) then
										group_codec_str = group_codec_str.."[\""..v2.forward_busy_1.."\"]=\""..extension_codec[v2.forward_busy_1].."\","
									end
								end
							end
							if (not string.find(group_call_pickup_str,"%[\""..v2.number_1.."\"%]")) then
								group_call_pickup_str = group_call_pickup_str.."[\""..v2.number_1.."\"]=\""..(v2.call_pickup_1 or "ringgrp").."\","
							end
							pickup_in_ringgrp[#pickup_in_ringgrp+1] = v2.call_pickup_1 == "ringgrp" and v2.number_1 or nil
						elseif m_port == "1" and (not ("Activate" == v2.notdisturb_2)) and interface and interface:match("2S") then
							exp = "freetdm\\/"..m_index.."\\/"..tostring(tonumber(m_port)+1).."\\/"..v2.number_2
							add_user_to_callgroup(v2.number_2,callgroup_id)
							if chan_name == "" then
								chan_name = "^FreeTDM/"..m_index..":2"
							else
								chan_name = chan_name.."|".."^FreeTDM/"..m_index..":2"
							end
							if v2.forward_uncondition_2 and "Deactivate" ~= v2.forward_uncondition_2 and v2.forward_uncondition_2:match("^%w+$") then
								group_unconditional_forward_str = group_unconditional_forward_str.."[\""..exp.."\"]=\""..extension_number_index[v2.forward_uncondition_2].."\","
								if extension_number_reg_index[v2.forward_uncondition_2] then
									if (not string.find(group_user_reg_str,"%[\""..v2.forward_uncondition_2.."\"%]")) then
										group_user_reg_str = group_user_reg_str.."[\""..v2.forward_uncondition_2.."\"]=\""..extension_number_reg_index[v2.forward_uncondition_2].."\","
									end
									if (not string.find(group_codec_str,"%[\""..v2.forward_uncondition_2.."\"%]")) then
										group_codec_str = group_codec_str.."[\""..v2.forward_uncondition_2.."\"]=\""..extension_codec[v2.forward_uncondition_2].."\","
									end
								end
							end
							if v2.forward_busy_2 and "Deactivate" ~= v2.forward_busy_2 and v2.forward_busy_2:match("^%w+$") then
								group_busy_forward_str = group_busy_forward_str.."[\""..exp.."\"]=\""..extension_number_index[v2.forward_busy_2].."\","
								if extension_number_reg_index[v2.forward_busy_2] then
									if (not string.find(group_user_reg_str,"%[\""..v2.forward_busy_2.."\"%]")) then
										group_user_reg_str = group_user_reg_str.."[\""..v2.forward_busy_2.."\"]=\""..extension_number_reg_index[v2.forward_busy_2].."\","
									end
									if (not string.find(group_codec_str,"%[\""..v2.forward_busy_2.."\"%]")) then
										group_codec_str = group_codec_str.."[\""..v2.forward_busy_2.."\"]=\""..extension_codec[v2.forward_busy_2].."\","
									end
								end
							end
							if (not string.find(group_call_pickup_str,"%[\""..v2.number_2.."\"%]")) then
								group_call_pickup_str = group_call_pickup_str.."[\""..v2.number_2.."\"]=\""..(v2.call_pickup_2 or "ringgrp").."\","
							end
							pickup_in_ringgrp[#pickup_in_ringgrp+1] = v2.call_pickup_2 == "ringgrp" and v2.number_2 or nil
						end
						break
					end
				end
			end
			bridge_channel = "FXS Extension"
		elseif v:match("^SIPP") then
			local index = v:match("^SIPP%-(%d+)")
			if extension_data[index] then
				exp = "user\\/"..extension_data[index]["number"]
				group_codec_str = group_codec_str.."[\""..extension_data[index]["number"].."\"]=\""..extension_data[index]["codec"].."\","
				group_user_reg_str = group_user_reg_str.."[\""..extension_data[index]["number"].."\"]=\""..extension_data[index]["reg_query"].."\","
				bridge_channel = extension_data[index]["name"]
				add_user_to_callgroup(extension_data[index]["number"],callgroup_id)
				if chan_name == "" then
					chan_name = "^sofia/user/"..extension_data[index]["number"].."/"
				else
					chan_name = chan_name.."|".."^sofia/user/"..extension_data[index]["number"].."/"
				end
				if extension_data[index]["forward_uncondition"] then
					local uncondition_dest = extension_data[index]["forward_uncondition"]
					group_unconditional_forward_str = group_unconditional_forward_str.."[\""..exp.."\"]=\""..extension_number_index[uncondition_dest].."\","
					if extension_number_reg_index[uncondition_dest] then
						if (not string.find(group_user_reg_str,"%[\""..uncondition_dest.."\"%]")) then
							group_user_reg_str = group_user_reg_str.."[\""..uncondition_dest.."\"]=\""..extension_number_reg_index[uncondition_dest].."\","
						end
						if (not string.find(group_codec_str,"%[\""..uncondition_dest.."\"%]")) then
							group_codec_str = group_codec_str.."[\""..uncondition_dest.."\"]=\""..extension_codec[uncondition_dest].."\","
						end
					end
				end
				if extension_data[index]["forward_busy"] then
					local busy_dest = extension_data[index]["forward_busy"]
					group_busy_forward_str = group_busy_forward_str.."[\""..exp.."\"]=\""..extension_number_index[busy_dest].."\","
					if extension_number_reg_index[busy_dest] then
						if (not string.find(group_user_reg_str,"%[\""..busy_dest.."\"%]"))  then
							group_user_reg_str = group_user_reg_str.."[\""..busy_dest.."\"]=\""..extension_number_reg_index[busy_dest].."\","
						end
						if (not string.find(group_codec_str,"%[\""..busy_dest.."\"%]")) then
							group_codec_str = group_codec_str.."[\""..busy_dest.."\"]=\""..extension_codec[busy_dest].."\","
						end
					end
				end
				if extension_data[index]["forward_unregister"] then
					local unregister_dest = extension_data[index]["forward_unregister"]
					group_unregister_forward_str = group_unregister_forward_str.."[\""..exp.."\"]=\""..extension_number_index[unregister_dest].."\","
					if extension_number_reg_index[unregister_dest] then
						if (not string.find(group_user_reg_str,"%[\""..unregister_dest.."\"%]"))  then
							group_user_reg_str = group_user_reg_str.."[\""..unregister_dest.."\"]=\""..extension_number_reg_index[unregister_dest].."\","
						end
						if (not string.find(group_codec_str,"%[\""..unregister_dest.."\"%]")) then
							group_codec_str = group_codec_str.."[\""..unregister_dest.."\"]=\""..extension_codec[unregister_dest].."\","
						end
					end
				end
				if extension_data[index]["call_pickup"] then
					if (not string.find(group_call_pickup_str,"%[\""..extension_data[index]["number"].."\"%]")) then
						group_call_pickup_str = group_call_pickup_str.."[\""..extension_data[index]["number"].."\"]=\""..extension_data[index]["call_pickup"].."\","
					end
					pickup_in_ringgrp[#pickup_in_ringgrp+1] = extension_data[index]["call_pickup"] == "ringgrp" and extension_data[index]["number"] or nil
				end
			end
		end

		if "" ~= exp then
			if group_bridge_str == "" then
				group_bridge_str = "\""..exp.."\""
			else
				group_bridge_str = group_bridge_str..",\""..exp.."\""
			end

			local tmp_channel_str = string.gsub(bridge_channel,"/","\\/")
			if group_bridge_channel_str == "" then
				group_bridge_channel_str = "\""..tmp_channel_str.."\""
			else
				group_bridge_channel_str = group_bridge_channel_str..",\""..tmp_channel_str.."\""
			end
		end
	end
	--@ ADD a intercept extension
	if next(pickup_in_ringgrp) then
		local extension = mxml.newnode(intercept_include,"extension")
		mxml.setattr(extension,"name","intercept-callgroup"..callgroup_id)
		local condition = mxml.newnode(extension,"condition")
		mxml.setattr(condition,"field","chan_name")
		mxml.setattr(condition,"expression",chan_name)
		condition = mxml.newnode(extension,"condition")
		mxml.setattr(condition,"field","destination_number")
		mxml.setattr(condition,"expression","^"..intercept_code_str.."("..table.concat(pickup_in_ringgrp,"|")..")$")
		local action = mxml.newnode(condition,"action")
		mxml.setattr(action,"application","set")
		mxml.setattr(action,"data","intercept_unanswered_only=true")
		
		action = mxml.newnode(condition,"action")
		mxml.setattr(action,"application","intercept")
		mxml.setattr(action,"data","${hash(select/callgroup/U-$1)}")

		action = mxml.newnode(condition,"action")
		mxml.setattr(action,"application","set")
		mxml.setattr(action,"data","dest_chan_name=${user_data(${1}@${domain} param channel_name)}")
	end
end

function add_intercept_group()
	local members_tb = {}

	for k,v in pairs(extension_data or {}) do
		if v["call_pickup"] == "extension" then
			members_tb[#members_tb+1] = v["number"]
		end
	end

	for k,v in pairs(fxso_endpoint or {}) do
		if "Enabled" == v.status then
			if v.number_1 and v.call_pickup_1 == "extension" then
				members_tb[#members_tb+1] = v.number_1
			end
			if v.number_2 and v.call_pickup_2 == "extension" then
				members_tb[#members_tb+1] = v.number_2
			end
		end
	end

	if next(members_tb) then
		local extension = mxml.newnode(intercept_include,"extension")
		mxml.setattr(extension,"name","intercept-in-extension")

		local condition = mxml.newnode(extension,"condition")
		mxml.setattr(condition,"field","chan_name")
		mxml.setattr(condition,"expression","^FreeTDM|^sofia/user")
		condition = mxml.newnode(extension,"condition")
		mxml.setattr(condition,"field","destination_number")
		mxml.setattr(condition,"expression","^"..intercept_code_str.."("..table.concat(members_tb,"|")..")$")

		local action = mxml.newnode(condition,"action")
		mxml.setattr(action,"application","set")
		mxml.setattr(action,"data","intercept_unanswered_only=true")
		
		action = mxml.newnode(condition,"action")
		mxml.setattr(action,"application","intercept")
		mxml.setattr(action,"data","${hash(select/callgroup/U-$1)}")

		action = mxml.newnode(condition,"action")
		mxml.setattr(action,"application","set")
		mxml.setattr(action,"data","dest_chan_name=${user_data(${1}@${domain} param channel_name)}")
	end
end

for k,v in pairs(ringgroup_endpoint) do
	if v.index and v.strategy then
		local destfile="/etc/freeswitch/scripts/RingGroup-"..v.index..".lua"
		exe("cp "..ringgroup_template.." "..destfile)
		group_bridge_str = ""
		group_bridge_channel_str = ""
		group_codec_str = ""
		group_user_reg_str = ""

		if v.members_select then
			add_members_to_group(v.members_select,v.index)
		end

		if group_bridge_str ~= "" then
			local sed_cmd_tb = {}
			sed_cmd_tb[#sed_cmd_tb+1] = "sed -i '"
			sed_cmd_tb[#sed_cmd_tb+1] = "s/^local bridge_members_tb = {.*}/local bridge_members_tb = {"..group_bridge_str.."}/g;"
			sed_cmd_tb[#sed_cmd_tb+1] = "s/^local bridge_channel_tb = {.*}/local bridge_channel_tb = {"..group_bridge_channel_str.."}/g;"
			sed_cmd_tb[#sed_cmd_tb+1] = "s/^local bridge_members_unconditional_forward_tb = {.*}/local bridge_members_unconditional_forward_tb = {"..group_unconditional_forward_str.."}/g;"
			sed_cmd_tb[#sed_cmd_tb+1] = "s/^local bridge_members_busy_forward_tb = {.*}/local bridge_members_busy_forward_tb = {"..group_busy_forward_str.."}/g;"
			sed_cmd_tb[#sed_cmd_tb+1] = "s/^local bridge_members_unregister_forward_tb = {.*}/local bridge_members_unregister_forward_tb = {"..group_unregister_forward_str.."}/g;"
			sed_cmd_tb[#sed_cmd_tb+1] = "s/^local codec_list = {.*}/local codec_list = {"..group_codec_str.."}/g;"
			sed_cmd_tb[#sed_cmd_tb+1] = "s/^local sipuser_reg_query = {.*}/local sipuser_reg_query = {"..group_user_reg_str.."}/g;"
			sed_cmd_tb[#sed_cmd_tb+1] = "s/^local grp_id = .*/local grp_id = "..v.index.."/g;"
			sed_cmd_tb[#sed_cmd_tb+1] = "s/^local strategy = .*/local strategy = \""..v.strategy.."\"/g;"
			sed_cmd_tb[#sed_cmd_tb+1] = "s/^local ringtime = .*/local ringtime = \""..(v.ringtime or 25).."\"/g;"
			sed_cmd_tb[#sed_cmd_tb+1] = "s/^local extension_call_pickup = {.*}/local extension_call_pickup = {"..group_call_pickup_str.."}/g;"
			if "" ~= bind_transfer_dtmf then
				sed_cmd_tb[#sed_cmd_tb+1] = "s/^local bind_transfer_dtmf = .*/local bind_transfer_dtmf = "..bind_transfer_dtmf.."/g;"
			end
			if "" ~= attended_transfer_dtmf then
				sed_cmd_tb[#sed_cmd_tb+1] = "s/^local attended_transfer_dtmf = .*/local attended_transfer_dtmf = "..attended_transfer_dtmf.."/g;"
			end
			sed_cmd_tb[#sed_cmd_tb+1] = "' "..destfile
			exe(table.concat(sed_cmd_tb),"")
		end
	end
end

if root then
	mxml.savefile(root,callgroup_dir)
	mxml.release(root)
end

if intercept_code_str ~= "" then
	add_intercept_group()
	mxml.savefile(intercept_xml,intercept_dir)
end
mxml.release(intercept_xml)
