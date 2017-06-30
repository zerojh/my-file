--[[

]]--
local dsp = require "luci.dispatcher"
local uci = require "luci.model.uci".cursor()
local mod_type
if luci.version.license and luci.versin.license.volte then
	mod_type = "volte"
else
	mod_type = "gsm"
end

arg[1] = arg[1] or ""
arg[2] = arg[2] or ""

current_section=arg[1]
uci:check_cfg("profile_mobile")
uci:check_cfg("endpoint_sipphone")
uci:check_cfg("endpoint_mobile")
uci:check_cfg("endpoint_siptrunk")
uci:check_cfg("endpoint_ringgroup")
uci:check_cfg("endpoint_fxso")
uci:check_cfg("profile_numberlearning")

local this_index = uci:get("endpoint_mobile",arg[1],"index")
local sip_profile = uci:get_all("endpoint_sipphone") or {}
local fxso_profile = uci:get_all("endpoint_fxso") or {}
local mobile_profile = uci:get_all("endpoint_mobile") or {}
local ringgroup_profile = uci:get_all("endpoint_ringgroup") or {}
local sip_trunk = uci:get_all("endpoint_siptrunk") or {}
local numberlearning_profile = uci:get_al("profile_numberlearning") or {}
local MAX_SIP_TRUNK = tonumber(uci:get("profile_param","global","max_sip_trunk") or "32")
local MAX_NUMBERLEARNING_PROFILE = tonumber(uci:get("profile_param","global","max_sip_trunk") or "32")
local MAX_DEFAULT = tonumber(uci:get("profile_param","global","max_default") or "32")

if arg[2] == "edit" then
	if mod_type == "volte" then
		m = Map("endpoint_mobile",translate("Trunk / VoLTE / Edit"))
	else
		m = Map("endpoint_mobile",translate("Trunk / GSM / Edit"))
	end
else
	if mod_type == "volte" then
		m = Map("endpoint_mobile",translate("Trunk / VoLTE / New"))
	else
		m = Map("endpoint_mobile",translate("Trunk / GSM / New"))
	end
	m.addnew = true
	m.new_section = arg[1]
end

m.redirect = dsp.build_url("admin","trunk","mobile")

if not m.uci:get(arg[1]) == "mobile" then
	luci.http.redirect(m.redirect)
end

s = m:section(NamedSection,arg[1],"mobile","")
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
	if v.number_1 then
		str = str..v.number_1.."&"
	end
	if v.number_2 then
		str = str..v.number_2.."&"
	end
end
--# gsm / cdma / volte
for k,v in pairs(endpoint_mobile) do
	if v.number and v.index and v.index ~= this_index then
		str = str..v.number.."&"
	end
end
--# ringgroup 
for k,v in pairs(endpoint_ringgroup) do
	if v.number then
		str = str..v.number.."&"
	end
end

extension = s:option(Value,"number",translate("Extension"))
--extension.datatype = "phonenumber"
extension.datatype = "extension("..str..")"
extension.rmempty = false

autodial = s:option(Value,"autodial",translate("Autodial Number"))
autodial.datatype = "phonenumber"

local server_list = {}

for i=1,MAX_SIP_TRUNK do
	for k,v in pairs(endpoint_siptrunk) do
		if v.index and tonumber(v.index) == i and "Enabled" == v.status and v.index and v.name then
			table.insert(server_list, {index=v.index, name=translate("SIP Trunk").." / "..v.name})
			break
		end
	end
end

reg = s:option(ListValue,"port_reg",translate("Register to SIP Server"))
reg.default = "off"
reg:value("off",translate("Off"))
reg:value("on",translate("On"))

reg_master_server = s:option(ListValue,"port_server_1",translate("Master Server"))
reg_master_server:depends("port_reg","on")
reg_master_server.margin = "30px"
for k,v in ipairs(server_list) do
	if 1 == k then
		reg_master_server.default = v.index
	end
	reg_master_server:value(v.index,v.name)
end
if 0 == #server_list then
	reg_master_server:value("0",translate("Not Config"))
end

reg_slave_server = s:option(ListValue,"port_server_2",translate("Slave Server"))
reg_slave_server:depends("port_reg","on")
reg_slave_server.margin = "30px"
for k,v in ipairs(server_list) do
	if 2 == k then
		reg_slave_server.default = v.index
	end
	reg_slave_server:value(v.index,v.name)
end
reg_slave_server:value("0",translate("Not Config"))
reg_slave_server.default="0"

user = s:option(Value,"username",translate("Username"))
user:depends("port_reg","on")
user.margin="30px"

authuser = s:option(Value,"authuser",translate("Auth Username"))
authuser:depends("port_reg","on")
authuser.margin="30px"

password = s:option(Value,"port_password",translate("Password"))
password.password = true
password:depends("port_reg","on")
password.margin="30px"

fromusername = s:option(ListValue,"from_username",translate("From Header Username"))
fromusername:depends("port_reg","on")
fromusername.margin="30px"
fromusername:value("username",translate("Username"))
fromusername:value("caller",translate("Caller"))

regurl = s:option(ListValue,"reg_url_with_transport",translate("Specify Transport Protocol on Register URL"))
regurl:depends("port_reg","on")
regurl.margin="30px"
regurl:value("off",translate("Off"))
regurl:value("on",translate("On"))

expiresec = s:option(Value,"expire_seconds",translate("Expire Seconds"))
expiresec:depends("port_reg","on")
expiresec.default = "1800"
expiresec.rmempty = false
expiresec.datatype = "min(5)"
expiresec.margin="30px"
function expiresec.validate(self, value)
	if "on" == m:get(arg[1],"port_reg") then
		return AbstractValue.validate(self, value)
	else
		m:del(arg[1],"expire_seconds")
		return value or ""
	end
end

retrysec = s:option(Value,"retry_seconds",translate("Retry Seconds"))
retrysec:depends("port_reg","on")
retrysec.default = "60"
retrysec.rmempty = false
retrysec.datatype = "range(5,99999)"
retrysec.margin="30px"
function retrysec.validate(self, value)
	if "on" == m:get(arg[1],"port_reg") then
		return AbstractValue.validate(self, value)
	else
		m:del(arg[1],"retry_seconds")
		return value or ""
	end
end

--@ sip invite from field setting; when cid is available
option = s:option(ListValue,"sip_from_field",translate("Display Name / Username Format"))
option.default = "2"
option:value("0",translate("Extension / Caller ID"))
option:value("1",translate("Extension / Extension"))
option:value("2",translate("Caller ID / Caller ID"))
option:value("3",translate("Caller ID / Extension"))
option:value("4",translate("Anonymous"))

--@ sip invite from field setting; when cid is unavailable
option = s:option(ListValue,"sip_from_field_un",translate("Display Name / Username Format when CID unavailable"))
option.default = "0"
option:value("0",translate("Extension / Extension"))
option:value("1",translate("Anonymous"))

codec = s:option(ListValue,"gsmspeedtype",translate("Voice Codec"))
codec:value("0",translate("Auto"))
codec:value("1","FR")
codec:value("2","HR")
codec:value("3","EFR")
codec:value("4","AMR_FR")
codec:value("5","AMR_HR")
codec:value("6","FR & EFR")
codec:value("7","EFR & FR")
codec:value("8","EFR & HR")
codec:value("9","EFR & ARM_FR")
codec:value("10","AMR_FR & FR")
codec:value("11","AMR_FR & HR")
codec:value("12","AMR_FR & EFR")
codec:value("13","AMR_HR & FR")
codec:value("14","AMR_HR & HR")
codec:value("15","AMR_HR & EFR")

bandtype = s:option(ListValue,"bandtype",translate("Band Type"))
bandtype:value("0",translate("All"))
if mod_type == "volte" then
	bandtype:value("1","VoLTE 900")
	bandtype:value("2","VoLTE 1800")
	bandtype:value("3","VoLTE 1900")
	bandtype:value("4","VoLTE 900 & VoLTE 1800")
	bandtype:value("5","VoLTE 850 & VoLTE 1900")
else
	bandtype:value("1","GSM 900")
	bandtype:value("2","GSM 1800")
	bandtype:value("3","GSM 1900")
	bandtype:value("4","GSM 900 & GSM 1800")
	bandtype:value("5","GSM 850 & GSM 1900")
end

carrier = s:option(ListValue,"carrier",translate("Carrier"))
carrier:value("auto",translate("Auto"))
local carrier_list = uci:get("endpoint_mobile",arg[1],"carrier_list")
if carrier_list then
	for k,v in ipairs(carrier_list) do
		carrier:value(v,v)
	end
end
carrier.template = "admin_trunk/carrier"

function carrier.validate(self, value)
	return value
end

reg_fail = s:option(ListValue,"reg_fail_reactive",translate("Reactive when register fail"))
reg_fail:value("true",translate("On"))
reg_fail:value("false",translate("Off"))

sms_encoding = s:option(ListValue,"at_sms_encoding",translate("SMS Encoding"))
sms_encoding:value("ucs2","ucs2")
sms_encoding:value("7-bit","7bit")

sms_number = s:option(Value,"at_smsc_number",translate("SMS Center Number"))
sms_number.datatype = "phonenumber"

clir = s:option(ListValue,"hide_callernumber",translate("CLIR"))
clir:value("0",translate("Auto"))
clir:value("1",translate("On"))
clir:value("2",translate("Off"))

pin_code = s:option(Value,"pincode",translate("PIN Code"))
pin_code.datatype = "pincode"

dsp_input_gain = s:option(ListValue,"dsp_input_gain",translate("Input Gain"))
dsp_input_gain.rmempty = false
dsp_input_gain.default = 0
dsp_output_gain = s:option(ListValue,"dsp_output_gain",translate("Output Gain"))
dsp_output_gain.rmempty = false
dsp_output_gain.default = 0
for i=-10,10 do
	if i > 0 then
		dsp_input_gain:value(i,"+"..i.."dB")
		dsp_output_gain:value(i,"+"..i.."dB")
	else
		dsp_input_gain:value(i,i.."dB")
		dsp_output_gain:value(i,i.."dB")
	end
end

number_profile = s:option(ListValue,"numberlearning_profile",translate("SIM Number Learning Profile"))
number_profile:value("0",translate("Off"))
number_profile.default = "0"
for i=1,MAX_NUMBERLEARNING_PROFILE do
	for k,v in pairs(profile_numberlearning) do
		if v.index and v.name then
			if tonumber(v.index) == i then
				number_profile:value(v.index,v.index.."-< "..v.name.." >")
				--break
			end
		else
			uci:delete("profile_numberlearning",k)
			uci:save("profile_numberlearning")
		end
	end
end

local continue_param = "trunk-mobile-"..arg[1].."-"..arg[2]
if arg[3] then
	continue_param = continue_param .. ";" .. arg[3]
end
number_profile:value("addnew_profile_numberlearning/"..continue_param,translate("< Add New ...>"))

function number_profile.cfgvalue(...)
	local v = m.uci:get("endpoint_mobile",current_section, "numberlearning_profile")
	if v and v:match("^addnew") then
		m.uci:revert("endpoint_mobile",current_section, "numberlearning_profile")
		v = m.uci:get("endpoint_mobile",current_section, "numberlearning_profile")
	end
	return v
end

slot_status = s:option(ListValue,"status",translate("Status"))
slot_status.rmempty = false
slot_status:value("Enabled",translate("Enable"))
slot_status:value("Disabled",translate("Disable"))

return m

