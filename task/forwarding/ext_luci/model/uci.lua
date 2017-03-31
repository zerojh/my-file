--[[
LuCI - UCI model

Description:
Generalized UCI model

FileId:
$Id: uci.lua 8131 2011-12-20 19:52:03Z jow $

License:
Copyright 2008 Steven Barth <steven@midlink.org>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

	http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

]]--
local os    = require "os"
local nixio = require "nixio"
local uci   = require "uci"
local util  = require "luci.util"
local table = require "table"


local setmetatable, rawget, rawset = setmetatable, rawget, rawset
local require, getmetatable = require, getmetatable
local error, pairs, ipairs = error, pairs, ipairs
local type, tostring, tonumber, unpack = type, tostring, tonumber, unpack

--- LuCI UCI model library.
-- The typical workflow for UCI is:  Get a cursor instance from the
-- cursor factory, modify data (via Cursor.add, Cursor.delete, etc.),
-- save the changes to the staging area via Cursor.save and finally
-- Cursor.commit the data to the actual config files.
-- LuCI then needs to Cursor.apply the changes so deamons etc. are
-- reloaded.
-- @cstyle	instance
module "luci.model.uci"

--- Create a new UCI-Cursor.
-- @class function
-- @name cursor
-- @return	UCI-Cursor
cursor = uci.cursor

APIVERSION = uci.APIVERSION

--- Create a new Cursor initialized to the state directory.
-- @return UCI cursor
function cursor_state()
	return cursor(nil, "/var/state")
end


inst = cursor()
inst_state = cursor_state()

local Cursor = getmetatable(inst)

--- Applies UCI configuration changes
-- @param configlist		List of UCI configurations
-- @param command			Don't apply only return the command
function Cursor.apply(self, configlist, command)
	configlist = self:_affected(configlist)
	if command then
		return { "/sbin/luci-reload", unpack(configlist) }
	else
		return os.execute("/sbin/luci-reload %s >/dev/null 2>&1"
			% table.concat(configlist, " "))
	end
end


--- Delete all sections of a given type that match certain criteria.
-- @param config		UCI config
-- @param type			UCI section type
-- @param comparator	Function that will be called for each section and
-- returns a boolean whether to delete the current section (optional)
function Cursor.delete_all(self, config, stype, comparator)
	local del = {}

	if type(comparator) == "table" then
		local tbl = comparator
		comparator = function(section)
			for k, v in pairs(tbl) do
				if section[k] ~= v then
					return false
				end
			end
			return true
		end
	end

	local function helper (section)

		if not comparator or comparator(section) then
			del[#del+1] = section[".name"]
		end
	end

	self:foreach(config, stype, helper)

	for i, j in ipairs(del) do
		self:delete(config, j)
	end
end

--- Create a new section and initialize it with data.
-- @param config	UCI config
-- @param type		UCI section type
-- @param name		UCI section name (optional)
-- @param values	Table of key - value pairs to initialize the section with
-- @return			Name of created section
function Cursor.section(self, config, type, name, values)
	local stat = true
	if name then
		stat = self:set(config, name, type)
	else
		name = self:add(config, type)
		stat = name and true
	end

	if stat and values then
		stat = self:tset(config, name, values)
	end

	return stat and name
end

--- Updated the data of a section using data from a table.
-- @param config	UCI config
-- @param section	UCI section name (optional)
-- @param values	Table of key - value pairs to update the section with
function Cursor.tset(self, config, section, values)
	local stat = true
	for k, v in pairs(values) do
		if k:sub(1, 1) ~= "." then
			stat = stat and self:set(config, section, k, v)
		end
	end
	return stat
end

--- Get a boolean option and return it's value as true or false.
-- @param config	UCI config
-- @param section	UCI section name
-- @param option	UCI option
-- @return			Boolean
function Cursor.get_bool(self, ...)
	local val = self:get(...)
	return ( val == "1" or val == "true" or val == "yes" or val == "on" )
end

--- Get an option or list and return values as table.
-- @param config	UCI config
-- @param section	UCI section name
-- @param option	UCI option
-- @return			UCI value
function Cursor.get_list(self, config, section, option)
	if config and section and option then
		local val = self:get(config, section, option)
		return ( type(val) == "table" and val or { val } )
	end
	return nil
end

--- Get the given option from the first section with the given type.
-- @param config	UCI config
-- @param type		UCI section type
-- @param option	UCI option (optional)
-- @param default	Default value (optional)
-- @return			UCI value
function Cursor.get_first(self, conf, stype, opt, def)
	local rv = def

	self:foreach(conf, stype,
		function(s)
			local val = not opt and s['.name'] or s[opt]

			if type(def) == "number" then
				val = tonumber(val)
			elseif type(def) == "boolean" then
				val = (val == "1" or val == "true" or
				       val == "yes" or val == "on")
			end

			if val ~= nil then
				rv = val
				return false
			end
		end)

	return rv
end

--- Set given values as list.
-- @param config	UCI config
-- @param section	UCI section name
-- @param option	UCI option
-- @param value		UCI value
-- @return			Boolean whether operation succeeded
function Cursor.set_list(self, config, section, option, value)
	if config and section and option then
		return self:set(
			config, section, option,
			( type(value) == "table" and value or { value } )
		)
	end
	return false
end

-- Return a list of initscripts affected by configuration changes.
function Cursor._affected(self, configlist)
	configlist = type(configlist) == "table" and configlist or {configlist}

	local c = cursor()
	c:load("ucitrack")

	-- Resolve dependencies
	local reloadlist = {}

	local function _resolve_deps(name)
		local reload = {name}
		local deps = {}

		c:foreach("ucitrack", name,
			function(section)
				if section.affects then
					for i, aff in ipairs(section.affects) do
						deps[#deps+1] = aff
					end
				end
			end)

		for i, dep in ipairs(deps) do
			for j, add in ipairs(_resolve_deps(dep)) do
				reload[#reload+1] = add
			end
		end

		return reload
	end

	-- Collect initscripts
	for j, config in ipairs(configlist) do
		for i, e in ipairs(_resolve_deps(config)) do
			if not util.contains(reloadlist, e) then
				reloadlist[#reloadlist+1] = e
			end
		end
	end

	return reloadlist
end

--- Create a sub-state of this cursor. The sub-state is tied to the parent
-- curser, means it the parent unloads or loads configs, the sub state will
-- do so as well.
-- @return			UCI state cursor tied to the parent cursor
function Cursor.substate(self)
	Cursor._substates = Cursor._substates or { }
	Cursor._substates[self] = Cursor._substates[self] or cursor_state()
	return Cursor._substates[self]
end

local _load = Cursor.load
function Cursor.load(self, ...)
	if Cursor._substates and Cursor._substates[self] then
		_load(Cursor._substates[self], ...)
	end
	return _load(self, ...)
end

local _unload = Cursor.unload
function Cursor.unload(self, ...)
	if Cursor._substates and Cursor._substates[self] then
		_unload(Cursor._substates[self], ...)
	end
	return _unload(self, ...)
end

function Cursor.create_section(self,config,cfgtype,cfgname,option_tb)
	if config == nil or cfgtype == nil or option_tb == nil then
		return false
	end

	if type(option_tb) ~= "table" then
		return false
	end
	local new_section = self:section(config,cfgtype,cfgname)
	if new_section == nil then
		return false
	end
	
	for k,v in pairs(option_tb) do
		if "table" == type(v) then
			self:set_list(config,new_section,k,v)
		else
			self:set(config,new_section,k,v)
		end
	end
	self:commit(config)
	
	return true
end

-- delete section of config by param of special format
-- @param target   format: config.section
-- @param refer
-- @return

function Cursor.delete_section(self,target,refer)
	if "table" == type(target) then
		for k,v in pairs(target) do
			local cfg, section = k:match("([a-z_]+)%.(%w+).x")
			if cfg and section then
				if refer then
					local _, flag = self:check_cfg_deps(cfg,section,refer)
					if false == flag then
						return
					end
				end
				self:delete(cfg,section)
				self:save(cfg)
				break
			end
		end
	end
end

-- check if config file exist, if not ,touch it
-- @param config  config filename
-- @return
function Cursor.check_cfg(self,config)
	if config and not nixio.fs.access("/etc/config/"..config) then
		os.execute("touch /etc/config/"..config)
	end
end

function Cursor.check_cfg_deps(self,config,section,param)
	if "" ~= param then
		local i18n = require "luci.i18n"
		local cur_index = self:get(config,section,"index") or ""
		local tmp_tb = util.split(param," ")

		for _,node in pairs(tmp_tb) do
			if "route.endpoint" == node then
				local compare_param = "unknown"

				if "endpoint_siptrunk" == config then
					compare_param = "SIPT-"..cur_index
				elseif "endpoint_sipphone" == config then
					compare_param = "SIPP-"..cur_index
				elseif "endpoint_ringgroup" == config then
					compare_param = "RING-"..cur_index
				elseif "endpoint_routegroup" == config then
					compare_param = "ROUTE-"..cur_index
				elseif "ivr" == config then
					compare_param = "IVR-"..cur_index
				elseif "endpoint_fxso" == config or "endpoint_mobile" == config then
					local tmp = self:get(config,section,"slot_type") or ""
					local idx = self:get(config,section,"index") or ""
					local slot_type = tmp:match("-(%u+)$") or ""
					compare_param = slot_type.."-"..idx
				end
				local cfg_tb

				if "endpoint_siptrunk" == config then
					cfg_tb = self:get_all("endpoint_fxso") or {}
					if cfg_tb and "table" == type(cfg_tb) then
						for k,v in pairs(cfg_tb) do
							if cur_index == v.port_1_server_1 or cur_index == v.port_1_server_2 or cur_index == v.port_2_server_1 or cur_index == v.port_2_server_2 then
								if v.slot_type and v.slot_type:match("FXS") then
									return "alert('"..i18n.translatef("Can not delete, it is being used in <%s> !",tostring(i18n.translate("FXS Extension"))).."');return false",false
								else
									return "alert('"..i18n.translatef("Can not delete, it is being used in <%s> !",tostring(i18n.translate("FXO Trunk"))).."');return false",false
								end
							end
						end
					end
					cfg_tb = self:get_all("endpoint_mobile") or {}
					if cfg_tb and "table" == type(cfg_tb) then
						for k,v in pairs(cfg_tb) do
							if cur_index == v.port_server_1 or cur_index == v.port_server_2 then
								if v.slot_type and v.slot_type:match("GSM") then
									return "alert('"..i18n.translatef("Can not delete, it is being used in <%s> !",tostring(i18n.translate("GSM Trunk"))).."');return false",false
								else
									return "alert('"..i18n.translatef("Can not delete, it is being used in <%s> !",tostring(i18n.translate("CDMA Trunk"))).."');return false",false
								end
							end
						end
					end
				end
				
				if ("endpoint_fxso" == config and "FXS" == slot_type) or "endpoint_sipphone" == config then
					cfg_tb = self:get_all("endpoint_ringgroup") or {}
					if cfg_tb and "table" == type(cfg_tb) then
						for k,v in pairs(cfg_tb) do
							if v.members_select and type(v.members_select) == "table" then
								for _,v2 in pairs(v.members_select) do
									if v2 and "FXS" == slot_type and (v2 == compare_param.."/0" or v2 == compare_param.."/1") then
										return "alert('"..i18n.translatef("Can not delete, it is being used in <%s> !",tostring(i18n.translate("Ring Group"))).."');return false",false
									elseif v2 and v2 == compare_param then
										return "alert('"..i18n.translatef("Can not delete, it is being used in <%s> !",tostring(i18n.translate("Ring Group"))).."');return false",false
									end
								end
							end
						end
					end
				end
				
				cfg_tb = self:get_all("endpoint_routegroup") or {}
				for k,v in pairs(cfg_tb) do
					if v.members_select and type(v.members_select) == "table" then
						for _,v2 in pairs(v.members_select) do
							if "endpoint_fxso" == config and v2 and (v2 == compare_param.."/0" or v2 == compare_param.."/1") then
								return "alert('"..i18n.translatef("Can not delete, it is being used in <%s> !",tostring(i18n.translate("Route Group"))).."');return false",false
							elseif "endpoint_mobile" == config and v2 and v2 == compare_param then
								return "alert('"..i18n.translatef("Can not delete, it is being used in <%s> !",tostring(i18n.translate("Route Group"))).."');return false",false
							elseif ("endpoint_siptrunk" == config or "endpoint_sipphone" == config) and v2 and v2 == compare_param then
								return "alert('"..i18n.translatef("Can not delete, it is being used in <%s> !",tostring(i18n.translate("Route Group"))).."');return false",false
							end
						end
					end
				end

				cfg_tb = self:get_all("route") or {}
				if cfg_tb and "table" == type(cfg_tb) then
					for k,v in pairs(cfg_tb) do
						if "-1" == v.from and v.custom_from and "table" == type(v.custom_from) then
							for i,j in pairs(v.custom_from) do
								if "endpoint_fxso" == config and (j == compare_param.."-1" or j == compare_param.."-2") then
									return "alert('"..i18n.translatef("Can not delete, it is being used in <%s> !",tostring(i18n.translate("Route"))).."');return false",false
								elseif j == compare_param then
									return "alert('"..i18n.translatef("Can not delete, it is being used in <%s> !",tostring(i18n.translate("Route"))).."');return false",false
								end
							end
						elseif v.from == compare_param or v.successDestination == compare_param or v.failDestination == compare_param then
							return "alert('"..i18n.translatef("Can not delete, it is being used in <%s> !",tostring(i18n.translate("Route"))).."');return false",false
						end
					end
				end
			elseif "endpoint_forwardgroup.timeProfile" == node then
				for k,v in pairs(self:get_all("endpoint_forwardgroup") or {}) do
					if v.destination and type(v.destination) == "table" then
						for _,val in pairs(v.destination) do
							local time_index = val:match("[^:]+::([^:]*)::[^:]+")
							if not time_index then
								time_index = val:match("[^:]+::([^:]+)")
							end

							if time_index and time_index == cur_index then
								return "alert('"..i18n.translatef("Can not delete, it is being used in <%s> !",tostring(i18n.translate("Call Forward Group"))).."');return false",false
							end
						end
					end
				end
			elseif "endpoint_forwardgroup.extension" == node and config == "endpoint_sipphone" then
				local cur_number = self:get(config,section,"user") or ""

				for k,v in pairs(self:get_all("endpoint_forwardgroup") or {}) do
					if v.destination and type(v.destination) == "table" then
						for _,val in pairs(v.destination) do
							local extension_number = val:match("^([^:]+)::")
							if not extension_number then
								extension_number = val
							end

							if extension_number and extension_number == cur_number then
								return "alert('"..i18n.translatef("Can not delete, it is being used in <%s> !",tostring(i18n.translate("Call Forward Group"))).."');return false",false
							end
						end
					end
				end
			elseif "endpoint_extension.forwardgrp" == node then
				local forward_name = "FORWARD-"..cur_index
				for k,v in pairs(self:get_all("endpoint_sipphone") or {}) do
					if (v.forward_uncondition and v.forward_uncondition == forward_name) or (v.forward_unregister and v.forward_unregister == forward_name) or (v.forward_busy and v.forward_busy == forward_name) or (v.forward_noreply and v.forward_noreply == forward_name) then
						return "alert('"..i18n.translatef("Can not delete, it is being used in <%s> !",tostring(i18n.translate("SIP Extension"))).."');return false",false
					end
				end
				for k,v in pairs(self:get_all("endpoint_fxso") or {}) do
					if v[".type"] == "fxs" then
						if (v.forward_uncondition_1 and v.forward_uncondition_1 == forward_name) or (v.forward_unregister_1 and v.forward_unregister_1 == forward_name) or (v.forward_busy_1 and v.forward_busy_1 == forward_name) or (v.forward_noreply_1 and v.forward_noreply_1 == forward_name) then
							return "alert('"..i18n.translatef("Can not delete, it is being used in <%s> !",tostring(i18n.translate("FXS Extension"))).."');return false",false
						elseif (v.forward_uncondition_2 and v.forward_uncondition_2 == forward_name) or (v.forward_unregister_2 and v.forward_unregister_2 == forward_name) or (v.forward_busy_2 and v.forward_busy_2 == forward_name) or (v.forward_noreply_2 and v.forward_noreply_2 == forward_name) then
							return "alert('"..i18n.translatef("Can not delete, it is being used in <%s> !",tostring(i18n.translate("FXS Extension"))).."');return false",false
						end
					end
				end
			else
				local cur_type = self:get(config,section) or ""
				local cfg_param = util.split(node,".")
				local dep_config = cfg_param[1] or ""
				local dep_option = cfg_param[2] or ""
				local dep_cfg_tb = self:get_all(dep_config) or {}

				for k,v in pairs(dep_cfg_tb) do
					if v[dep_option] == cur_index and v['.type'] == cur_type then
						if "endpoint_fxso" == dep_config and "fxs" == v['.type'] then
							return "alert('"..i18n.translatef("Can not delete, it is being used in <%s> !",tostring(i18n.translate("FXS Extension"))).."');return false",false
						elseif "endpoint_fxso" == dep_config and "fxo" == v['.type'] then
							return "alert('"..i18n.translatef("Can not delete, it is being used in <%s> !",tostring(i18n.translate("FXO Trunk"))).."');return false",false
						elseif "profile_fxso" == dep_config and "fxs" == v['.type'] then
							return "alert('"..i18n.translatef("Can not delete, it is being used in <%s> !",tostring(i18n.translate("FXS Profile"))).."');return false",false
						elseif "profile_fxso" == dep_config and "fxo" == v['.type'] then
							return "alert('"..i18n.translatef("Can not delete, it is being used in <%s> !",tostring(i18n.translate("FXO Profile"))).."');return false",false
						else
							return "alert('"..i18n.translatef("Can not delete, it is being used in <%s> !",tostring(i18n.translate(dep_config))).."');return false",false
						end
					elseif v[dep_option] == cur_index and "fxs" ~= cur_type and "fxo" ~= cur_type then
						return "alert('"..i18n.translatef("Can not delete, it is being used in <%s> !",tostring(i18n.translate(dep_config))).."');return false",false
					end
				end
			end
		end
	end
	
	return "return true",true
end

function Cursor.get_destination_detail(dest,num)
	local i18n = require "luci.i18n"
	local uci = require "luci.model.uci".cursor()
	local interface = uci:get("system","main","interface") or ""

	if not dest then
		return i18n.translate("Error")
	end

	if dest:match("^gsmopen") then
		return i18n.translate("GSM Trunk").."/"..(num or "")
	elseif dest:match("^FXO") then
		if interface:match("1[Oo]") then
			return i18n.translate("FXO Trunk").."/"..(num or "")
		else
			local slot,port = dest:match("(%d+)/(%d+)")
			if slot and port then
				port = (slot-1)*2+port-1
				return i18n.translate("FXO Trunk").."/"..i18n.translate("Port").." "..port.."/"..(num or "")
			else
				return i18n.translate("FXO Trunk").."/"..(num or "")
			end
		end
	elseif dest:match("^SIPT") then
		local profile,idx = dest:match("^SIPT%-(%d+)_(%d+)")
		for k,v in pairs(uci:get_all("endpoint_siptrunk") or {}) do
			if v.index and v.index == idx and v.profile and v.profile == profile and v.name then
				if v.status == "Enabled" then
					return i18n.translate("SIP Trunk").."/"..v.name.."/"..(num or "")
				else
					return i18n.translate("Error")..":"..i18n.translate("SIP Trunk").."/"..v.name.." "..i18n.translate("Disabled")
				end
			end
		end
		return i18n.translate("Error")..":"..i18n.translate("SIP Trunk").." ("..i18n.translate("Index")..":"..(idx or "unknown").." "..i18n.translate("Profile")..":"..(profile or "unknown")..") "..i18n.translate("is not exist!")
	elseif dest:match("^FORWARD%-%d+$") then
		local idx = dest:match("^FORWARD%-(%d+)$")
		for k,v in pairs(uci:get_all("endpoint_forwardgroup") or {}) do
			if v.index and v.index == idx and v.name then
				return i18n.translate("Call Forward Group").." "..v.name
			end
		end
	elseif dest:match("^%d+$") then
		for k,v in pairs(uci:get_all("endpoint_fxso") or {}) do
			if "fxs" == v['.type'] and v.number_1 and v.number_1 == dest then
				if v.status == "Enabled" then
					return i18n.translate("FXS Extension").."/"..dest
				else
					return i18n.translate("Error")..":"..i18n.translate("FXS Extension").." ("..dest..") "..i18n.translate("Disabled")
				end
			end
		end
		for k,v in pairs(uci:get_all("endpoint_sipphone") or {}) do
			if v.user and v.user == dest and v.name then
				if v.status == "Enabled" then
					return i18n.translate("SIP Extension").."/"..v.name.."/"..v.user
				else
					return i18n.translate("Error")..":"..i18n.translate("SIP Extension").." ("..dest..") "..i18n.translate("Disabled")
				end
			end
		end
		return i18n.translate("Error")..":"..i18n.translate("Extension").." ("..dest..") "..i18n.translate("is not exist!")
	end

	return i18n.translate("Error")
end

function Cursor.get_siptrunk_server(server_index)
	local i18n = require "luci.i18n"
	local uci = require "luci.model.uci".cursor()
	local siptrunk = uci:get_all("endpoint_siptrunk") or {}
	
	for i,j in pairs(siptrunk) do
		if j.index and j.name and server_index == j.index then
			return i18n.translate("SIP Trunk").." / "..j.name
		end	
	end

	return i18n.translate("Error")
end

function Cursor.get_custom_source(name)
	local i18n = require "luci.i18n"
	local uci = require "luci.model.uci".cursor()
	local interface = uci:get("system","main","interface") or ""
	local sipt = uci:get_all("endpoint_siptrunk") or {}
	local sipp = uci:get_all("endpoint_sipphone") or {}

	if name:match("^GSM%-%d+$") then
		return i18n.translate("GSM Trunk")
	end

	if name:match("^FXS%-%d+%-%d+$") and interface:match("1S") then
		return i18n.translate("FXS Extension")
	elseif name:match("^FXO%-%d+%-%d+$") and interface:match("1O") then
		return i18n.translate("FXO Trunk")
	elseif name:match("^FX[SO]%-%d+%-%d+$") and interface:match("[SO]") then
		local tmp_type,tmp_index,tmp_port = name:match("(FX[SO])%-([0-9]+)%-([0-9]+)")
		for k,v in pairs(uci:get_all("endpoint_fxso") or {}) do
			if v.index == tmp_index and "fxs" == v[".type"] and "FXS" == tmp_type then
				return i18n.translate("FXS Extension").." / "..v["number_"..tmp_port]
			end
			if v.index == tmp_index and "fxo" == v[".type"] and "FXO" == tmp_type then
				return "FXO / "..i18n.translate("Port").." "..(tonumber(tmp_index)-1)*2+(tonumber(tmp_port)-1)
			end
		end
	end

	if name:match("^SIPP%-%d+$") then
		local sipp_number = name:match("^SIPP%-(%d+)$")
		for k, v in pairs(sipp) do
			if v.index and v.name and sipp_number == v.index then
				return i18n.translate("SIP Extension").." / "..v.name.." / "..v.user
			end
		end
	end

	if name:match("^SIPT%-%d+$") then
		local sipt_number = name:match("^SIPT%-(%d+)$")
		for k, v in pairs(sipt) do
			if v.index and v.name and sipt_number == v.index then
				return i18n.translate("SIP Trunk").." / "..v.name
			end
		end
	end

	return i18n.translate("Error")
end

--- Add an anonymous section.
-- @class function
-- @name Cursor.add
-- @param config	UCI config
-- @param type		UCI section type
-- @return			Name of created section

--- Get a table of saved but uncommitted changes.
-- @class function
-- @name Cursor.changes
-- @param config	UCI config
-- @return			Table of changes
-- @see Cursor.save

--- Commit saved changes.
-- @class function
-- @name Cursor.commit
-- @param config	UCI config
-- @return			Boolean whether operation succeeded
-- @see Cursor.revert
-- @see Cursor.save

--- Deletes a section or an option.
-- @class function
-- @name Cursor.delete
-- @param config	UCI config
-- @param section	UCI section name
-- @param option	UCI option (optional)
-- @return			Boolean whether operation succeeded

--- Call a function for every section of a certain type.
-- @class function
-- @name Cursor.foreach
-- @param config	UCI config
-- @param type		UCI section type
-- @param callback	Function to be called
-- @return			Boolean whether operation succeeded

--- Get a section type or an option
-- @class function
-- @name Cursor.get
-- @param config	UCI config
-- @param section	UCI section name
-- @param option	UCI option (optional)
-- @return			UCI value

--- Get all sections of a config or all values of a section.
-- @class function
-- @name Cursor.get_all
-- @param config	UCI config
-- @param section	UCI section name (optional)
-- @return			Table of UCI sections or table of UCI values

--- Manually load a config.
-- @class function
-- @name Cursor.load
-- @param config	UCI config
-- @return			Boolean whether operation succeeded
-- @see Cursor.save
-- @see Cursor.unload

--- Revert saved but uncommitted changes.
-- @class function
-- @name Cursor.revert
-- @param config	UCI config
-- @return			Boolean whether operation succeeded
-- @see Cursor.commit
-- @see Cursor.save

--- Saves changes made to a config to make them committable.
-- @class function
-- @name Cursor.save
-- @param config	UCI config
-- @return			Boolean whether operation succeeded
-- @see Cursor.load
-- @see Cursor.unload

--- Set a value or create a named section.
-- @class function
-- @name Cursor.set
-- @param config	UCI config
-- @param section	UCI section name
-- @param option	UCI option or UCI section type
-- @param value		UCI value or nil if you want to create a section
-- @return			Boolean whether operation succeeded

--- Get the configuration directory.
-- @class function
-- @name Cursor.get_confdir
-- @return			Configuration directory

--- Get the directory for uncomitted changes.
-- @class function
-- @name Cursor.get_savedir
-- @return			Save directory

--- Set the configuration directory.
-- @class function
-- @name Cursor.set_confdir
-- @param directory	UCI configuration directory
-- @return			Boolean whether operation succeeded

--- Set the directory for uncommited changes.
-- @class function
-- @name Cursor.set_savedir
-- @param directory	UCI changes directory
-- @return			Boolean whether operation succeeded

--- Discard changes made to a config.
-- @class function
-- @name Cursor.unload
-- @param config	UCI config
-- @return			Boolean whether operation succeeded
-- @see Cursor.load
-- @see Cursor.save
