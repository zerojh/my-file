
local uci = require "luci.model.uci".cursor()
require "luci.util"

local sipphone_cfg = uci:get_all("endpoint_sipphone") or {}
local sip_profile_cfg = uci:get_all("profile_sip") or {}
local fxso_cfg = uci:get_all("endpoint_fxso") or {}
local codec_cfg = uci:get_all("profile_codec") or {"PCMA","PCMU"}
local time_cfg = uci:get_all("profile_time") or {}
local siptrunk_cfg = uci:get_all("endpoint_siptrunk") or {}

local codec = {}
local sip_ex_tb = ""
local fxs_ex_tb = ""

local fm_ex_tb = {forward_uncondition="",forward_unregister="",forward_busy="",forward_noreply="",forward_noreply_timeout=""}
local fm_sipuser_reg_query = ""
local fm_profile_time_tb = ""

local profile_interface = {}
local endpoint_interface = ""

for k,v in pairs(sip_profile_cfg) do
	for i,j in pairs(codec_cfg) do
		if v.index and v.outbound_codec_prefs and j.index and v.outbound_codec_prefs == j.index and j.code then
			codec[v.index] = table.concat(j.code,",") or "PCMA,PCMU"
		end
	end
	if v.index and v.localinterface then
		profile_interface[v.index] = v.localinterface
	end
end

for k,v in pairs(sipphone_cfg) do
	if v.user then
		sip_ex_tb = sip_ex_tb .. "[\""..v.user.."\"]={[\"reg_query\"]=\"sofia status profile "..v.profile.." reg "..v.user.."\","
		fm_sipuser_reg_query = fm_sipuser_reg_query .. "[\"]"..v.user.."\"]=\"sofia status profile "..v.profile.." reg "..v.user.."\","
		if v.waiting then
			sip_ex_tb = sip_ex_tb .. "[\"waiting\"]=\""..v.waiting.."\","
		end
		if v.notdisturb then
			sip_ex_tb = sip_ex_tb .. "[\"notdisturb\"]=\""..v.notdisturb.."\","
		end

		local forward_option_tb = {"forward_uncondition","forward_unregister","forward_busy","forward_noreply"}
		for _,forward_option in ipairs(forward_option_tb) do
			if v[forward_option] then
				if type(v[forward_option]) == "string" then
					local tmp_tb = {}
					table.insert(tmp_tb, v[forward_option])
					v[forward_option] = tmp_tb
				end
				if type(v[forward_option]) == "table" and next(v[forward_option]) then
					if v[forward_option][1] == "" or v[forward_option][1] == "Deactivate" then
						sip_ex_tb = sip_ex_tb .. "[\""..forward_option.."\"]=\"Deactivate\","
					else
						local tmp_str = ""
						sip_ex_tb = sip_ex_tb .. "[\""..forward_option.."\"]=\"Activate\","
						for _,val in ipairs(v[forward_option]) do
							local dest,time,number = val:match("([^:]*)::([^:]*)::([^:]*)")
							if not dest or not time or not number then
								dest,time = val:match("([^:]*)::([^:]*)")
								if not dest then
									dest = val
								end
							end
							if dest and time and number then
								tmp_str = tmp_str .. "{\""..dest.."\""..",\""..time.."\",\""..number.."\"},"
							elseif dest and time then
								tmp_str = tmp_str .. "{\""..dest.."\""..",\""..time.."\"},"
							elseif dest then
								tmp_str = tmp_str .. "{\""..dest.."\"},"
							end
						end
						if tmp_str ~= "" then
							fm_ex_tb[forward_option] = fm_ex_tb[forward_option] .."[\""..v.user.."\"]={"..tmp_str.."},"
						end
						tmp_str = nil
					end
				end
			end
		end
		if v["forward_noreply"] and v["forward_noreply_timeout"] then
			fm_ex_tb["forward_noreply_timeout"] = fm_ex_tb["forward_noreply_timeout"] .. "[\""..v.user.."\"]=\""..v["forward_noreply_timeout"].."\","
		end
		sip_ex_tb = sip_ex_tb .. "},"
	end
	if v.user and v.profile then
		endpoint_interface = endpoint_interface .. "[\""..v.user.."\"]=\""..(profile_interface[v.profile] or "").."\","
	end
end

for k,v in pairs(fxso_cfg) do
	if v['.type'] == 'fxs' and v.index then
		fxs_ex_tb = fxs_ex_tb .. "[\""..v.index.."\"]={"
		if v.waiting_1 then
			fxs_ex_tb = fxs_ex_tb .. "[\"waiting_1\"]=\""..v.waiting_1.."\","
		end
		if v.notdisturb_1 then
			fxs_ex_tb = fxs_ex_tb .. "[\"notdisturb_1\"]=\""..v.notdisturb_1.."\","
		end
		if v.waiting_2 then
			fxs_ex_tb = fxs_ex_tb .. "[\"waiting_2\"]=\""..v.waiting_2.."\","
		end
		if v.notdisturb_2 then
			fxs_ex_tb = fxs_ex_tb .. "[\"notdisturb_2\"]=\""..v.notdisturb_2.."\","
		end

		local forward_option_tb = {"forward_uncondition","forward_busy","forward_noreply"}
		local port_tb = {"1","2"}
		for _,port_index in ipairs(port_tb) do
			for _,forward_option in ipairs(forward_option_tb) do
				local port_forward_option = forward_option.."_"..port_index
				if v[port_forward_option] then
					if type(v[port_forward_option]) == "string" then
						local tmp_tb = {}
						table.insert(tmp_tb, v[port_forward_option])
						v[port_forward_option] = tmp_tb
					end
					if type(v[port_forward_option]) == "table" and next(v[port_forward_option]) then
						if v[port_forward_option][1] == "" or v[port_forward_option][1] == "Deactivate" then
							fxs_ex_tb = fxs_ex_tb .. "[\""..port_forward_option.."\"]=\"Deactivate\","
						else
							local tmp_str = ""
							fxs_ex_tb = fxs_ex_tb .. "[\""..port_forward_option.."\"]=\"Activate\","
							for _,val in ipairs(v[port_forward_option]) do
								local dest,time,number = val:match("([^:]*)::([^:]*)::([^:]*)")
								if not dest or not time or not number then
									dest,time = val:match("([^:]*)::([^:]*)")
									if not dest then
										dest = val
									end
								end
								if dest and time and number then
									tmp_str = tmp_str .. "{\""..dest.."\""..",\""..time.."\",\""..number.."\"},"
								elseif dest and time then
									tmp_str = tmp_str .. "{\""..dest.."\""..",\""..time.."\"},"
								elseif dest then
									tmp_str = tmp_str .. "{\""..dest.."\"},"
								end
							end
							if tmp_str ~= "" then
								fm_ex_tb[forward_option] = fm_ex_tb[forward_option] .."[\""..v.index.."/"..port_index.."\"]={"..tmp_str.."},"
							end
							tmp_str = nil
						end
					end
				end
			end
			if v["forward_noreply_"..port_index] and v["forward_noreply_timeout_"..port_index] then
				fm_ex_tb["forward_noreply_timeout"] = fm_ex_tb["forward_noreply_timeout"] .. "[\""..v.index.."/"..port_index.."\"]=\""..v["forward_noreply_timeout_"..port_index].."\","
			end
		end
		fxs_ex_tb = fxs_ex_tb .. "},"
	end
end

for k,v in pairs(siptrunk_cfg) do
	if v.index and v.profile then
		endpoint_interface = endpoint_interface .. "[\""..v.profile.."_"..v.index.."\"]=\""..(profile_interface[v.profile] or "").."\","
	end
end

for k,v in pairs(time_cfg) do
	if v.name and (v.weekday or v.date_options or v.time_options) then
		fm_profile_time_tb = fm_profile_time_tb .."[\""..v.name.."\"]={"
		if v.weekday then
			fm_profile_time_tb = fm_profile_time_tb .."[\"wday\"]=\""
			local tmp_str = v.weekday
			local wday_str = ""
			if tmp_str:match("Sun") then
				wday_str = wday_str.."1"
			end
			if tmp_str:match("Mon") then
				wday_str = wday_str.."2"
			end
			if tmp_str:match("Tue") then
				wday_str = wday_str.."3"
			end
			if tmp_str:match("Wed") then
				wday_str = wday_str.."4"
			end
			if tmp_str:match("Thu") then
				wday_str = wday_str.."5"
			end
			if tmp_str:match("Fri") then
				wday_str = wday_str.."6"
			end
			if tmp_str:match("Sat") then
				wday_str = wday_str.."7"
			end
			fm_profile_time_tb = fm_profile_time_tb ..wday_str.."\","
		end
		if v.date_options and next(v.date_options) then
			fm_profile_time_tb = fm_profile_time_tb .."[\"date\"]={"
			local date_str = ""
			for _,date_option in pairs(v.date_options) do
				date_str = date_str.."\""..date_option.."\","
			end
			fm_profile_time_tb = fm_profile_time_tb ..date_str.."},"
		end
		if v.time_options and next(v.time_options) then
			fm_profile_time_tb = fm_profile_time_tb .."[\"time\"]={"
			local time_str = ""
			for _,time_option in pairs(v.time_options) do
				time_str = time_str.."\""..time_option.."\","
			end
			fm_profile_time_tb = fm_profile_time_tb ..time_str.."},"
		end
		fm_profile_time_tb = fm_profile_time_tb.. "},"
	end
end

print("sip_ex_tb: {"..sip_ex_tb.."}")
print("fxs_ex_tb: {"..fxs_ex_tb.."}")
print("fm_ex_tb.forward_uncondition: {"..fm_ex_tb.forward_uncondition.."}")
print("fm_ex_tb.forward_unregister: {"..fm_ex_tb.forward_unregister.."}")
print("fm_ex_tb.forward_busy: {"..fm_ex_tb.forward_busy.."}")
print("fm_ex_tb.forward_noreply: {"..fm_ex_tb.forward_noreply.."}")
print("fm_ex_tb.forward_noreply_timeout: {"..fm_ex_tb.forward_noreply_timeout.."}")
print("fm_profile_time_tb: {"..fm_profile_time_tb.."}")
print("endpoint_interface: {"..endpoint_interface.."}")
