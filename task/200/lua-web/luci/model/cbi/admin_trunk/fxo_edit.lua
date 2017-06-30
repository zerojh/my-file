--[[

]]--
local dsp = require "luci.dispatcher"
local uci = require "luci.model.uci".cursor()

arg[1] = arg[1] or ""
arg[2] = arg[2] or ""
this_port = arg[3] or "2"

uci:check_cfg("profile_fxso")
uci:check_cfg("endpoint_fxso")
uci:check_cfg("endpoint_siptrunk")
uci:check_cfg("endpoint_sipphone")
uci:check_cfg("endpoint_mobile")
uci:check_cfg("endpoint_ringgroup")

local this_index = uci:get("endpoint_fxso",arg[1],"index")
local endpoint_sipphone = uci:get_all("endpoint_sipphone") or {}
local endpoint_fxso = uci:get_all("endpoint_fxso") or {}
local endpoint_mobile = uci:get_all("endpoint_mobile") or {}
local endpoint_ringgroup = uci:get_all("endpoint_ringgroup") or {}
local endpoint_siptrunk = uci:get_all("endpoint_siptrunk") or {}
local profile_fxso = uci:get_all("profile_fxso") or {}
local MAX_SIP_TRUNK = tonumber(uci:get("profile_param","global","max_sip_trunk") or '32')
local MAX_FXSO_PROFILE = tonumber(uci:get("profile_param","global","max_fxso_profile") or "12")

local current_user = dsp.context.authuser
local profile_access = uci:get("user",current_user.."_web","profile_fxso")

local current_section=arg[1]
if arg[2] == "edit" then
	m = Map("endpoint_fxso",translate("Trunk / FXO / Edit"))
else
	m = Map("endpoint_fxso",translate("Trunk / FXO / New"))
    m.addnew = true
    m.new_section = arg[1]
end

function m.insertprofile(self,param)
	local profile,exparam = param:match("([a-z_]+)/(.+)")
	
	if profile == "profile_fxso" then
		local map = Map(profile)
		local section = map:section(TypedSection,"fxo")
		local created = TypedSection.create(section,nil)
		map.uci:save(profile)
		luci.http.redirect(dsp.build_url("admin","profile","fxso","fxo",created,"add",exparam))
	elseif profile == "profile_slic" then
		local slot,port = exparam:match("([0-9]+)_([0-9]+)_(.+)")

		local fxo_endpoint = "FXO-"..slot.."-"..port
		local fxo_slic = uci:get("endpoint_fxso",arg[1],"slic_"..(tonumber(port)+1))
		local fxo_slic_id = string.gsub(fxo_endpoint,"-","_")
		
		luci.http.redirect(dsp.build_url("admin","trunk","fxo","slic",fxo_endpoint,fxo_slic,fxo_slic_id,exparam))
	end
	return
end

m.redirect = dsp.build_url("admin","trunk","fxo")

if not m.uci:get(arg[1]) == "fxo" then
	luci.http.redirect(m.redirect)
end

s = m:section(NamedSection,arg[1],"fxo","")
m.currsection = s
s.addremove = false
s.anonymous = true

local str = ""
--# sip_extension
for k,v in pairs(endpoint_sipphone) do
    if v.user then
    	str = str..v.user.."&"
    end
end
--# fxs /fxo
for k,v in pairs(endpoint_fxso) do
	--# fxs
	if v['.type'] == "fxs" and luci.version.license.fxs then
		if v.number_1 then
			str = str..v.number_1.."&"
		end
		if v.number_2 then
			str = str..v.number_2.."&"
		end
	end
	--# fxo
	if v['.type'] == "fxo" and v.index and v.index ~= this_index then
		if v.number_1 then
			str = str..v.number_1.."&"
		end
		if v.number_2 then
			str = str..v.number_2.."&"
		end		
	end
end
--# gsm / cdma / volte
if luci.version.license and luci.version.license.gsm or luci.version.license.volte then
	for k,v in pairs(endpoint_mobile) do
		if v.number then
			str = str..v.number.."&"
		end
	end
end
--# ringgroup 
for k,v in pairs(endpoint_ringgroup) do
	if v.number then
		str = str..v.number.."&"
	end
end

--@ Port, 0-1
option = s:option(DummyValue,"index",translate("Port"))
function option.cfgvalue(self,value)
	local tmp = m:get(arg[1],"index")

	return ((tonumber(tmp)-1)*2 + tonumber(this_port) - 1)
end

--@ Extension number
option = s:option(Value,"number_"..this_port,translate("Extension"))
option.datatype = "extension("..str..")"
option.rmempty = false

--@ Autodial Number
option = s:option(Value,"autodial_"..this_port,translate("Autodial Number"))
option.datatype = "phonenumber"

local server_list = {}

for i=1,MAX_SIP_TRUNK do
	for k,v in pairs(endpoint_siptrunk) do
		if v.index and tonumber(v.index) == i and "Enabled" == v.status and v.index and v.name then
			table.insert(server_list, {index=v.index, name=translate("SIP Trunk").." / "..v.name})
			break
		end
	end
end

local slic_tb = {"600 Ohm",
				"900 Ohm",
				"270 Ohm + (750 Ohm || 150 nF) and 275 Ohm + (780 Ohm || 150 nF)",
				"220 Ohm + (820 Ohm || 120 nF) and 220 Ohm + (820 Ohm || 115 nF)",
				"370 Ohm + (620 Ohm || 310 nF)",
				"320 Ohm + (1050 Ohm || 230 nF)",
				"370 Ohm + (820 Ohm || 110 nF)",
				"275 Ohm + (780 Ohm || 115 nF)",
				"120 Ohm + (820 Ohm || 110 nF)",
				"350 Ohm + (1000 Ohm || 210 nF)",
				"200 Ohm + (680 Ohm || 100 nF)",
				"600 Ohm + 2.16 uF",
				"900 Ohm + 1 uF",
				"900 Ohm + 2.16 uF",
				"600 Ohm + 1 uF",
				translate("Global impedance")
				}
--@ SIP Reg
option = s:option(ListValue,"port_"..this_port.."_reg",translate("Register to SIP Server"))
option.default = "off"
option:value("off",translate("Off"))
option:value("on",translate("On"))

--@ SIP Master Server
option = s:option(ListValue,"port_"..this_port.."_server_1",translate("Master Server"))
option:depends("port_"..this_port.."_reg","on")
option.margin = "30px"
for k,v in ipairs(server_list) do
	if 1 == k then
		option.default = v.index
	end
	option:value(v.index,v.name)
end
if 0 == #server_list then
	option:value("0",translate("Not Config"))
end

--@ SIP Slave Server
option = s:option(ListValue,"port_"..this_port.."_server_2",translate("Slave Server"))
option:depends("port_"..this_port.."_reg","on")
option.margin = "30px"
for k,v in ipairs(server_list) do
	if 2 == k then
		option.default = v.index
	end
	option:value(v.index,v.name)
end
option:value("0",translate("Not Config"))
option.default="0"

--@ Username
option = s:option(Value,"username_"..this_port,translate("Username"))
option:depends("port_"..this_port.."_reg","on")
option.margin="30px"

--@ Authname
option = s:option(Value,"authuser_"..this_port,translate("Auth Username"))
option:depends("port_"..this_port.."_reg","on")
option.margin="30px"

--@ Password
option = s:option(Value,"port_"..this_port.."_password",translate("Password"))
option.password = true
option:depends("port_"..this_port.."_reg","on")
option.margin="30px"

fromusername = s:option(ListValue,"from_username_"..this_port,translate("From Header Username"))
fromusername:depends("port_"..this_port.."_reg","on")
fromusername.margin="30px"
fromusername:value("username",translate("Username"))
fromusername:value("caller",translate("Caller"))

regurl = s:option(ListValue,"reg_url_with_transport_"..this_port,translate("Specify Transport Protocol on Register URL"))
regurl:depends("port_"..this_port.."_reg","on")
regurl.margin="30px"
regurl:value("off",translate("Off"))
regurl:value("on",translate("On"))

expiresec = s:option(Value,"expire_seconds_"..this_port,translate("Expire Seconds"))
expiresec:depends("port_"..this_port.."_reg","on")
expiresec.default = "1800"
expiresec.rmempty = false
expiresec.datatype = "min(5)"
expiresec.margin="30px"
function expiresec.validate(self, value)
	if "on" == m:get(arg[1],"port_"..this_port.."_reg") then
		return AbstractValue.validate(self, value)
	else
		m:del(arg[1],"expire_seconds_"..this_port)
		return value or ""
	end
end

retrysec = s:option(Value,"retry_seconds_"..this_port,translate("Retry Seconds"))
retrysec:depends("port_"..this_port.."_reg","on")
retrysec.default = "60"
retrysec.rmempty = false
retrysec.datatype = "range(5,99999)"
retrysec.margin="30px"
function retrysec.validate(self, value)
	if "on" == m:get(arg[1],"port_"..this_port.."_reg") then
		return AbstractValue.validate(self, value)
	else
		m:del(arg[1],"retry_seconds_"..this_port)
		return value or ""
	end
end

--@ Display Name / Username Format
option = s:option(ListValue,"sip_from_field_"..this_port,translate("Display Name / Username Format"))
option.default = "0"
option:value("0",translate("Caller ID / Caller ID"))
option:value("1",translate("Display Name / Caller ID"))
option:value("2",translate("Extension / Caller ID"))
option:value("3",translate("Caller ID / Extension"))
option:value("4",translate("Anonymous"))

option = s:option(ListValue,"sip_from_field_un_"..this_port,translate("Display Name / Username Format when CID unavailable"))
option.default = "0"
option:value("0",translate("Display Name / Extension"))
option:value("1",translate("Anonymous"))

dsp_input_gain_2 = s:option(ListValue,"dsp_input_gain_"..this_port,translate("Input Gain"))
dsp_input_gain_2.rmempty = false
dsp_input_gain_2.default = 0

dsp_output_gain_2 = s:option(ListValue,"dsp_output_gain_"..this_port,translate("Output Gain"))
dsp_output_gain_2.rmempty = false
dsp_output_gain_2.default = 0
for i=-10,10 do
	if i > 0 then
		dsp_input_gain_2:value(i,"+"..i.."dB")
		dsp_output_gain_2:value(i,"+"..i.."dB")	
	else
		dsp_input_gain_2:value(i,i.."dB")
		dsp_output_gain_2:value(i,i.."dB")
	end
end

option = s:option(ListValue,"slic_"..this_port,translate("Impedance"))
option.default = "0"
for k,v in pairs(slic_tb) do
	option:value(k-1,v)
end
--@ auto fxo slic detection
local continue_param = "trunk-fxo-"..arg[1].."-"..arg[2]
if arg[3] then
	continue_param = continue_param .. ";" .. arg[3]
end
option:value("addnew_profile_slic/"..(tonumber(uci:get("endpoint_fxso",arg[1],"index"))-1).."_"..(tonumber(this_port) - 1).."_"..continue_param,translate("< Slic Detection...>"))

if span_type == "fxso" then
	profile = s:option(ListValue,"fxo_profile",translate("FXO Profile"))
else
	profile = s:option(ListValue,"profile",translate("FXO Profile"))
end

profile.rmempty = false
for i=1,MAX_FXSO_PROFILE do
	for k,v in pairs(profile_fxso) do
		if "fxo" == v['.type'] and v.index and v.name and tonumber(v.index) == i then
			profile:value(v.index,v.index.."-< "..v.name.." >")
			break
		end
	end
end
if "admin" == current_user or (profile_access and profile_access:match("edit")) then
	profile:value("addnew_profile_fxso/"..continue_param,translate("< Add New ...>"))
	function profile.cfgvalue(...)
		local v = m.uci:get("endpoint_fxso",current_section, "profile")
		if v and v:match("^addnew") then
			m.uci:revert("endpoint_fxso",current_section, "profile")
			v = m.uci:get("endpoint_fxso",current_section, "profile")
		end
		return v or "1"
	end
end
slot_status = s:option(ListValue,"status",translate("Status"))
slot_status.rmempty = false
slot_status:value("Enabled",translate("Enable"))
slot_status:value("Disabled",translate("Disable"))

return m

