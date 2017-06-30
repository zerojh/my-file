local dsp = require "luci.dispatcher"
local uci = require "luci.model.uci".cursor()
local util = require "luci.util"

arg[1] = arg[1] or ""
arg[2] = arg[2] or ""

uci:check_cfg("profile_fxso")
uci:check_cfg("profile_dialplan")

local profile_fxso = uci:get_all("profile_fxso") or {}
local profile_dialplan = uci:get_all("profile_dialplan") or {}
local MAX_FXSO_PROFILE = tonumber(uci:get("profile_param","global","max_fxso_profile") or "4")
local MAX_DIALPLAN_PROFILE = tonumber(uci:get("profile_param","global","max_dialplan_profile") or "32")

local current_user = dsp.context.authuser
local dialplan_access = uci:get("user",current_user.."_web","profile_dialplan")

if arg[2] == "edit" then
    m = Map("profile_fxso",translate("Profile / FXS / Edit"))
else
    m = Map("profile_fxso",translate("Profile / FXS / New"))
    m.addnew = true
    m.new_section = arg[1]
end

local current_section = arg[1]
if arg[3] then
	m.saveaction = false
	m.redirect = m:gen_redirect(arg[3])
else
	m.redirect = dsp.build_url("admin","profile","fxso")
end

if not m.uci:get(arg[1]) == "fxs" then
	luci.http.redirect(m.redirect)
end

s = m:section(NamedSection,arg[1],"fxs","")
s.addremove = false
s.anonymous = true
m.currsection = s

if arg[2] == "edit" then
	index = s:option(DummyValue,"index",translate("Index"))
else
	index = s:option(ListValue,"index",translate("Index"))
	index.rmempty = false
	for i=1,MAX_FXSO_PROFILE do
		local flag = true
		for k,v in pairs(profile_fxso) do
			if v.index and tonumber(v.index) == i and 'fxs' == v['.type'] then
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

tonegrp = s:option(ListValue,"tonegrp",translate("Tone Group"))
tonegrp.default = "14"
local tonegrpvalue = {"USA","Austria","Belgium","Finland","France","Germany","Greece","Italy","Japan","Norway","Spain","Sweden","UK","Australia","China","Hongkong","Denmark","Russia","Poland","Portugal","Turkey","Dutch"}
for k,v in pairs(tonegrpvalue) do
	tonegrp:value(k-1,translate(v))
end
tonegrp:value("ph",translate("Philippines"))
tonegrp:value("za",translate("South Africa"))

digit = s:option(Value,"digit",translate("Digit Timeout(s)"))
digit.default = "4"
digit.rmempty = false
digit.datatype = "range(1,20)"

-- maxlen = s:option(Value,"maxlen",translate("Max Length"))
-- maxlen.rmempty = false
-- maxlen.datatype = "uinteger"
-- maxlen.default = 11

-- callwaiting = s:option(ListValue,"callwaiting",translate("Call Waiting"))
-- callwaiting.default = "on"
-- callwaiting:value("on",translate("On"))
-- callwaiting:value("off",translate("Off"))

dialtimeout = s:option(Value,"dialTimeout",translate("Dial Timeout(s)"))
dialtimeout.default = "10"
dialtimeout.rmempty = false
dialtimeout.datatype = "range(1,20)"

ringtimeout = s:option(Value,"ringtimeout",translate("Call Out Ring Timeout(s)"))
ringtimeout.default = "55"
ringtimeout.rmempty = false
ringtimeout.datatype = "range(1,200)"

noanswer = s:option(Value,"noanswer",translate("Call In No Answer Timeout(s)"))
noanswer.default = "55"
noanswer.rmempty = false
noanswer.datatype = "range(1,200)"

-- holdmusic = s:option(ListValue,"holdmusic",translate("Hold Music"))
-- holdmusic.default = "cn_busy_pls_wait"
-- holdmusic:value("cn_busy_pls_wait","cn_busy_pls_wait")
-- holdmusic:value("en_busy_pls_wait","en_busy_pls_wait")

flash_flag = s:option(Flag,"flash_flag",translate("Flash Detection"))

flash_min_time = s:option(Value,"flash_min_time",translate("Min Time (ms)"))
flash_min_time.margin = "32px"
flash_min_time.default = "100"
flash_min_time.datatype = "range(60,1500)"
flash_min_time.rmempty = "false"
flash_min_time:depends("flash_flag","1")
function flash_min_time.validate(self, value)
	local tmp = m:get(arg[1],"flash_flag")
	if tmp then
		return Value.validate(self, value)
	else
		m:del(arg[1],"flash_min_time")
		return value or ""
	end
end

local flash_max_time_default_val=util.exec("uci -c /usr/lib/lua/luci/scripts/default_config/ get profile_fxso.@fxs[0].flash_max_time")

flash_max_time = s:option(Value,"flash_max_time",translate("Max Time (ms)"))
flash_max_time.margin = "32px"
flash_max_time.default = flash_max_time_default_val ~= "" and flash_max_time_default_val or "400"
flash_max_time.datatype = "range(60,1500)"
flash_max_time.rmempty = "false"
flash_max_time:depends("flash_flag","1")
function flash_max_time.validate(self, value)
	local tmp = m:get(arg[1],"flash_flag")
	if tmp then
		local min_t = m:get(arg[1],"flash_min_time")
		if tonumber(value) < tonumber(min_t) then
			return false
		end
		return Value.validate(self, value)
	else
		m:del(arg[1],"flash_max_time")
		return value or ""
	end
end

dtmf = s:option(DummyValue,"_",translate("DTMF Parameters"))
dtmf_sendinterval = s:option(Value,"dtmf_sendinterval",translate("DTMF Send Interval(ms)"))
dtmf_sendinterval.default = "200"
dtmf_sendinterval.rmempty = false
dtmf_sendinterval.datatype = "range(100,2000)"
dtmf_sendinterval.margin = "32px"

dtmf_duration = s:option(Value,"dtmf_duration",translate("DTMF Duration(ms)"))
dtmf_duration.default = "200"
dtmf_duration.rmempty = false
dtmf_duration.datatype = "range(80,200)"
dtmf_duration.margin = "32px"

dtmf_gain = s:option(ListValue,"dtmf_gain",translate("DTMF Gain"))
dtmf_gain.default = "-6"
dtmf_gain.rmempty = false
dtmf_gain:value("6","-6dB")
dtmf_gain:value("4","-4dB")
dtmf_gain:value("2","-2dB")
dtmf_gain:value("0","-0dB")
dtmf_gain:value("-2","2dB")
dtmf_gain:value("-4","4dB")
dtmf_gain:value("-6","6dB")
dtmf_gain:value("-8","8dB")
dtmf_gain:value("-10","10dB")
dtmf_gain.margin = "32px"

dtmf_threshold = s:option(ListValue,"dtmf_detect_threshold",translate("DTMF Detect Threshold"))
dtmf_threshold.default="-30"
for i=-20,-40,-1 do
	dtmf_threshold:value(i,i.."dB")
end
dtmf_threshold.margin = "32px"

et = s:option(ListValue,"dtmf_end_char",translate("DTMF Terminator"))
et:value("none",translate("NONE"))
et:value("*","*")
et:value("#","#")
et.default = "#"
et.margin = "32px"

set = s:option(ListValue,"send_dtmf_end_char",translate("Send DTMF Terminator"))
set:value("on",translate("On"))
set:value("off",translate("Off"))
set.default = "off"
set.margin = "32px"

cid_send_mode = s:option(ListValue,"cid_send_mode",translate("CID Send Mode"))
cid_send_mode:value("FSK","FSK-BEL202")
cid_send_mode:value("FSK-V23","FSK-V.23")
cid_send_mode:value("DTMF","DTMF")

message_mode = s:option(ListValue,"message_mode",translate("Message Mode"))
message_mode:value("MDMF","MDMF")
message_mode:value("SDMF","SDMF")
message_mode:depends("cid_send_mode","FSK")
message_mode:depends("cid_send_mode","FSK-V23")
message_mode.margin = "32px"

message_format = s:option(ListValue,"message_format",translate("Message Format"))
message_format.default = "0"
message_format:value("0",translate("Display Name and CID"))
message_format:value("1",translate("Only CID"))
message_format:value("2",translate("Only Display Name"))
message_format:depends("cid_send_mode","FSK")
message_format:depends("cid_send_mode","FSK-V23")
message_format.margin = "32px"

send_cid_before = s:option(ListValue,"send_cid_before",translate("CID Send Timing"))
send_cid_before.margin = "32px"
send_cid_before:value("0",translate("Send After RING"))
send_cid_before:value("1",translate("Send Before RING"))

send_cid_delay = s:option(Value,"send_cid_delay",translate("Delay Timeout After Ring(ms)"))
send_cid_delay:depends("send_cid_before","0")
send_cid_delay.default = "2000"
send_cid_delay.rmempty = "false"
send_cid_delay.datatype = "range(0,5000)"
send_cid_delay.margin = "32px"

function send_cid_delay.validate(self, value)
	local tmp = m:get(arg[1],"send_cid_before")
	if tmp and "0" == tmp then
		return Value.validate(self, value)
	else
		m:del(arg[1],"send_cid_delay")
		return value or ""
	end
end		

local slic_tb = {"600 Ohm","900 Ohm","600 Ohm + 1uF","900 Ohm + 2.16uF","270 Ohm + (750 Ohm || 150nF)","220 Ohm + (820 Ohm || 120 nF)","220 Ohm + (820 Ohm || 115 nF)","220 Ohm + (680 Ohm || 100 nF)"}
slic_setting = s:option(ListValue,"slic",translate("Impedance"))
slic_setting.default = "0"
for k,v in pairs(slic_tb) do
	slic_setting:value(k-1,v)
end

--# disabled
--enablecallerid = s:option(ListValue,"enablecallerid",translate("Enable Caller ID"))
--enablecallerid.default = "on"
--enablecallerid:value("on",translate("ON"))
--enablecallerid:value("off",translate("OFF"))

ren = s:option(ListValue,"ren",translate("REN(Ringer Equivalency Number)"))
ren:value("1","1")
ren:value("2","2")
ren:value("3","3")
ren:value("4","4")

pr = s:option(ListValue,"polarity_reverse",translate("Send Polarity Reverse"))
pr:value("on",translate("On"))
pr:value("off",translate("Off"))
pr.default = "on"

fh = s:option(ListValue,"flashhook_dtmf",translate("Send Flash Hook via SIP INFO / RFC2833"))
fh:value("0",translate("Off"))
fh:value("*","*")
fh:value("#","#")
fh:value("A","A(12)")
fh:value("B","B(13)")
fh:value("C","C(14)")
fh:value("D","D(15)")
fh:value("F","F(16)")
fh.default = "0"

offhook_current_threshold = s:option(ListValue,"offhook_current_threshold",translate("Offhook Current Detect Threshold"))
for i=8,18 do
	offhook_current_threshold:value(i,i..translate("mA"))
end
offhook_current_threshold.default="12"

onhook_current_threshold = s:option(ListValue,"onhook_current_threshold",translate("Onhook Current Detect Threshold"))
for i=1,12 do
	onhook_current_threshold:value(i,i..translate("mA"))
end
onhook_current_threshold.default="10"
-- polaritydelay = s:option(ListValue,"polarityDelay",translate("Polarity Delay"))
-- polaritydelay:value("on",translate("On"))
-- polaritydelay:value("off",translate("Off"))
-- polaritydelay.default = "off"

-- polaritycallerid = s:option(ListValue,"polarityCallerId",translate("Polarity Caller ID"))
-- polaritycallerid:value("on",translate("On"))
-- polaritycallerid:value("off",translate("Off"))
-- polaritycallerid.default = "off"

dialregex = s:option(ListValue,"dialRegex",translate("Dialplan"))
dialregex.rmempty = false
local dialregex_tb = uci:get_all("profile_dialplan") or {}
dialregex.default = "off"
dialregex:value("off",translate("Off"))
for i=1,MAX_DIALPLAN_PROFILE do
	for k,v in pairs(profile_dialplan) do
		if v.index and v.name then
			if tonumber(v.index) == i then
				dialregex:value(v.index,v.index.."-< "..v.name.." >")
				break
			end
		else
			uci:delete("profile_dialplan",k)
			uci:save("profile_dialplan")
		end
	end
end

if "admin" == current_user or (dialplan_access and dialplan_access:match("edit")) then
	local continue_param = "profile-fxs-"..arg[1].."-"..arg[2]
	if arg[3] then
		continue_param = continue_param .. ";" .. arg[3]
	end
	dialregex:value("addnew_profile_dialplan/"..continue_param,translate("< Add New ...>"))
	function dialregex.cfgvalue(...)
		local v = m.uci:get("profile_fxso",current_section, "dialRegex")
		if v and v:match("^addnew") then
			m.uci:revert("profile_fxso",current_section, "dialRegex")
			v = m.uci:get("profile_fxso",current_section, "dialRegex")
		end
		return v
	end
end
-- hotline = s:option(ListValue,"hotline",translate("Hot Line"))
-- hotline.default = "Immediately"
-- hotline:value("Immediately",translate("Immediately"))
-- hotline:value("Deley",translate("Deley"))

-- rxgain = s:option(Value,"rxgain",translate("Rxgain"))
-- rxgain.default = "0"
-- rxgain.rmempty = false

-- txgain = s:option(Value,"txgain",translate("Txgain"))
-- txgain.default = "0"
-- txgain.rmempty = false

return m

