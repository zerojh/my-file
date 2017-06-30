--[[

]]--
local dsp = require "luci.dispatcher"
local uci = require "luci.model.uci".cursor()

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

local current_section=arg[1]
if arg[2] == "edit" then
    m = Map("profile_fxso",translate("Profile / FXO / Edit"))
else
    m = Map("profile_fxso",translate("Profile / FXO / New"))
    m.addnew = true
    m.new_section = arg[1]
end

if arg[3] then
	m.saveaction = false
	m.redirect = m:gen_redirect(arg[3])
else
	m.redirect = dsp.build_url("admin","profile","fxso")
end

if not m.uci:get(arg[1]) == "fxo" then
	luci.http.redirect(m.redirect)
end

s = m:section(NamedSection,arg[1],"fxo","")
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
			if v.index and tonumber(v.index) == i and 'fxo' == v['.type'] then
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

-- ringtimeout = s:option(Value,"ringtimeout",translate("Ring Timeout(s)"))
-- ringtimeout.default = "55"
-- ringtimeout.rmempty = false
-- ringtimeout.datatype = "range(1,200)"

-- noanswer = s:option(Value,"noanswer",translate("No Answer Timeout(s)"))
-- noanswer.default = "55"
-- noanswer.rmempty = false
-- noanswer.datatype = "range(1,200)"

pr = s:option(ListValue,"polarity_reverse",translate("Detect Polarity Reverse"))
pr:value("on",translate("On"))
pr:value("off",translate("Off"))
pr.default = "on"

delay_offhook = s:option(Value,"delay_offhook",translate("Delay Offhook(s)"))
delay_offhook:depends("polarity_reverse","off")
delay_offhook.default = "3"
delay_offhook.datatype = "range(1,60)"
delay_offhook.rmempty = false

function delay_offhook.validate(self, value)
	if "off" == m:get(arg[1],"polarity_reverse") then
		return AbstractValue.validate(self, value)
	else
		m:del(arg[1],"delay_offhook")
		return value or ""
	end
end

cid_detect = s:option(ListValue,"detectcid_opt",translate("Detect Caller ID"))
cid_detect.default = "2"
cid_detect:value("0",translate("Off"))
cid_detect:value("1",translate("Detect before ring"))
cid_detect:value("2",translate("Detect after ring"))

dtmf_detectinterval = s:option(Value,"dtmf_detectcid_timeout",translate("DTMF Detect Timeout(ms)"))
dtmf_detectinterval:depends("detectcid_opt","1")
dtmf_detectinterval:depends("detectcid_opt","2")
dtmf_detectinterval.default = "5000"
dtmf_detectinterval.rmempty = false
dtmf_detectinterval.datatype = "range(100,20000)"
dtmf_detectinterval.margin = "32px"

function dtmf_detectinterval.validate(self, value)
	if "0" ~= m:get(arg[1],"detectcid_opt") then
		return AbstractValue.validate(self, value)
	else
		return value or ""
	end
end

dial_delay = s:option(Value,"dial_delay",translate("Dial Delay(ms)"))
dial_delay.default = "400"
dial_delay.rmempty = false
dial_delay.datatype = "range(400,1500)"

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
dtmf_gain.margin = "32px"
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

dtmf_threshold = s:option(ListValue,"dtmf_detect_threshold",translate("DTMF Detect Threshold"))
dtmf_threshold.default="-30"
for i=-20,-40,-1 do
	dtmf_threshold:value(i,i.."db")
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

busy = s:option(DummyValue,"_",translate("BusyTone Detect Parameters"))

busytone_count = s:option(Value,"busytone_count",translate("Detect Tone counts"))      
busytone_count.default = "8"                                                       
busytone_count.rmempty = false                                                     
busytone_count.datatype = "range(1,200)"                                           
busytone_count.margin = "32px"

busytone_detect_busy_delta = s:option(Value,"busytone_detect_busy_delta",translate("Detect Tone Delta(ms)"))      
busytone_detect_busy_delta.default = "50"                                                       
busytone_detect_busy_delta.rmempty = false                                                     
busytone_detect_busy_delta.datatype = "range(1,30000)"                                           
busytone_detect_busy_delta.margin = "32px"


busy_ratio = s:option(ListValue,"busy_ratio",translate("Intermittent Ratio"))
busy_ratio.default = 0
busy_ratio:value("0",translate("1:1"))
busy_ratio:value("1",translate("Custom"))
busy_ratio.margin = "32px"

busy_on = s:option(Value,"busy_tone_on",translate("Tone 1 On Time(ms)"))
busy_on:depends("busy_ratio","1")
busy_on.default = "0"
busy_on.datatype = "max(30000)"
busy_on.margin = "32px"

busy_off = s:option(Value,"busy_tone_off",translate("Tone 1 Off Time(ms)"))
busy_off:depends("busy_ratio","1")
busy_off.default = "0"
busy_off.datatype = "max(30000)"
busy_off.margin = "32px"

busy_on_1 = s:option(Value,"busy_tone_on_1",translate("Tone 2 On Time(ms)"))
busy_on_1:depends("busy_ratio","1")
busy_on_1.default = "0"
busy_on_1.datatype = "max(30000)"
busy_on_1.margin = "32px"

busy_off_1 = s:option(Value,"busy_tone_off_1",translate("Tone 2 Off Time(ms)"))
busy_off_1:depends("busy_ratio","1")
busy_off_1.default = "0"
busy_off_1.datatype = "max(30000)"
busy_off_1.margin = "32px"

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
	local continue_param = "profile-fxo-"..arg[1].."-"..arg[2]
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

