require "ESL"
require "luci.util"
require "mxml"


module ("luci.scripts.fs_server", package.seeall)

function get_fs_status()
	local ps = luci.util.exec("ps")

	if string.find(ps,"/bin/freeswitch") then
		local con = ESL.ESLconnection("127.0.0.1","8021","ClueCon")

		if con:connected() ~= 1 then
			return false,"Switch Kernel Service is initializing, please wait for a moment !"
		else
			return true,""
		end
	else
		return false,"Switch Kernel Service stoped !"
	end
end

function fxo_detection_slic(cmd)
	local con = ESL.ESLconnection("127.0.0.1","8021","ClueCon")
	local ret_str = ""
	
	if con:connected() ~= 1 then
		return "Fail"
	end	
	
	if cmd then
		ret_str = con:api(cmd):getBody()
	end
	
	return ret_str
	
end

function check_wav_format(block,format)
	if block then
		local tmp = ""
		for b in string.gfind(block,".") do
			tmp = tmp..string.format("%02X",string.byte(b))
		end

		if tmp == string.upper(format) then
			return true
		else
			return false
		end
	else
		return false
	end
end

function create_hardware_endpoint()
	local fs = require "luci.fs"
	local uci = require "luci.model.uci".cursor()
	local need_create_fxso = true
	local need_create_mobile = true
	
	uci:check_cfg("endpoint_fxso")
	uci:check_cfg("endpoint_mobile")

	for k,v in pairs(uci:get_all("endpoint_fxso") or {}) do
		if v and v['.type'] == "fxs" then
			need_create_fxso = false
			break
		end
	end
	
	for k,v in pairs(uci:get_all("endpoint_mobile") or {}) do
		if v and v['.type'] == "mobile" then
			need_create_mobile = false
			break
		end
	end

	if need_create_fxso then
		section = uci:add("endpoint_fxso","fxs")
		uci:set("endpoint_fxso",section,"index",1)
		uci:set("endpoint_fxso",section,"name","0-FXS")
		uci:set("endpoint_fxso",section,"slot_type","0-FXS")
		uci:set("endpoint_fxso",section,"number_1",8000)
		uci:set("endpoint_fxso",section,"profile","1")
		uci:set("endpoint_fxso",section,"status","Enabled")
		uci:set("endpoint_fxso",section,"dsp_input_gain_1","0")
		uci:set("endpoint_fxso",section,"dsp_output_gain_1","0")
		uci:set("endpoint_fxso",section,"waiting_1","Deactivate")
		uci:set("endpoint_fxso",section,"notdisturb_1","Deactivate")
		uci:set("endpoint_fxso",section,"forward_uncondition_1","Deactivate")
		uci:set("endpoint_fxso",section,"forward_busy_1","Deactivate")
		uci:set("endpoint_fxso",section,"forward_noreply_1","Deactivate")
					
		section = uci:add("endpoint_fxso","fxo")
		uci:set("endpoint_fxso",section,"index",1)
		uci:set("endpoint_fxso",section,"name","0-FXO")
		uci:set("endpoint_fxso",section,"slot_type","0-FXO")
		uci:set("endpoint_fxso",section,"number_2",8001)
		uci:set("endpoint_fxso",section,"profile","1")
		uci:set("endpoint_fxso",section,"status","Enabled")
		uci:set("endpoint_fxso",section,"dsp_input_gain_2","0")
		uci:set("endpoint_fxso",section,"dsp_output_gain_2","0")
		uci:set("endpoint_fxso",section,"slic_2","0")				
		uci:commit("endpoint_fxso")
	end

	if need_create_mobile then
		section = uci:add("endpoint_mobile","mobile")
		uci:set("endpoint_mobile",section,"index",2)
		uci:set("endpoint_mobile",section,"name","1-GSM")
		uci:set("endpoint_mobile",section,"slot_type","1-GSM")
		uci:set("endpoint_mobile",section,"number",8002)
		uci:set("endpoint_mobile",section,"at_sms_encoding","ucs2")
		uci:set("endpoint_mobile",section,"status","Enabled")

		uci:commit("endpoint_mobile")
	end
end

function check_audio_transcoding_status()
	local con = ESL.ESLconnection("127.0.0.1","8021","ClueCon")
	
	if con:connected() ~= 1 then
		return "Fail"
	end	

	local ret_str = con:api("ftdm driver fxso transcoding query"):getBody()
	local ret_tb = {}

	if ret_str:match("in transcoding now") then
		ret_tb.status = "working"
		local total = ret_str:match("total%s*=%s*([0-9]+)%s*ms\n")
		local completed = ret_str:match("completed%s*=%s*([0-9]+)%s*ms\n")
		if tonumber(completed) >= tonumber(total) then
				ret_tb.percent = "100%"
		else
			ret_tb.percent = string.sub(tostring(tonumber(completed)/tonumber(total)*100),1,5).."%"
		end		
	elseif ret_str:match("finished successly") then
		ret_tb.status = "success"
		os.execute("rm -f /tmp/welcome.wav")
	elseif ret_str:match("transcoding error") then
		ret_tb.status = "failed"
		os.execute("rm -f /tmp/welcome.wav")
	else
	
	end

	con:disconnect()

	return ret_tb
end

function set_audio_file(lang)
	local fs = require "nixio.fs"
	local wav_audio_dir = "/tmp/welcome.wav"
	local zh_audio_dir = "/etc/freeswitch/sounds/zh/cn/callie"
	local en_audio_dir = "/etc/freeswitch/sounds/en/us/callie"

	--@ check wav file
	local wav_file = io.open(wav_audio_dir,"rb")
	if wav_file then
		--@ RIFF	
		local block = wav_file:read(4)
		if not check_wav_format(block,"52494646") then
			return "Fail,the audio file must be wav format!"
		end
			
		block = wav_file:read(4)

		--@ WAVEfmt		
		block = wav_file:read(8)
		if not check_wav_format(block,"57415645666d7420") then
			return "Fail,the audio file must be wav format!"
		end
		
		block = wav_file:read(4)

		block = wav_file:read(2)

		--@ µ¥ÉùµÀ		
		block = wav_file:read(2)
		if not check_wav_format(block,"0100") then
			return "Fail,the audio file must be Mono!"
		end		

		--@  8000HZ	
		block = wav_file:read(4)
		if not check_wav_format(block,"401f0000") then
			return "Fail,the audio file must be 8000HZ!"
		end		
		
		block = wav_file:read(4)
		block = wav_file:read(2)

		--@ 16bit
		block = wav_file:read(2)
		if not check_wav_format(block,"1000") then
			return "Fail,the audio file must be 16 bit!"
		end		
		
		--@ File Size less than 550kb
		lens = tonumber(wav_file:seek("end"))
		if lens > 550*1000 then
			return "Fail,the audio file size must be less than 550 kb!"
		end
	else
		return "Fail,upload audio file failed!"
	end
	
	if lang then
		
		if lang == "en" then                                                                   
				luci.util.exec("audioconvert /tmp/welcome.wav "..en_audio_dir.."/welcome.PCMA PCMA")
				luci.util.exec("audioconvert /tmp/welcome.wav "..en_audio_dir.."/welcome.PCMU PCMU")
				luci.util.exec("audioconvert /tmp/welcome.wav "..en_audio_dir.."/welcome.G723 G723")
				luci.util.exec("audioconvert /tmp/welcome.wav "..en_audio_dir.."/welcome.G729 G729")
		else                                                                                   
				luci.util.exec("audioconvert /tmp/welcome.wav "..zh_audio_dir.."/welcome.PCMA PCMA")
				luci.util.exec("audioconvert /tmp/welcome.wav "..zh_audio_dir.."/welcome.PCMU PCMU")
				luci.util.exec("audioconvert /tmp/welcome.wav "..zh_audio_dir.."/welcome.G723 G723")
				luci.util.exec("audioconvert /tmp/welcome.wav "..zh_audio_dir.."/welcome.G729 G729")
		end 

		return "Success"		
	else
		return "Fail,system error!"
	end
end

function sip_status()
	local uci = require "luci.model.uci".cursor()
	uci:check_cfg("endpoint_sipphone")

	local con = ESL.ESLconnection("127.0.0.1","8021","ClueCon")

	local sip_profile_status = {}
	local sip_gw_status = {}
	local sip_user_status = {}

	if con:connected() ~= 1 then
		return sip_profile_status,sip_gw_status,sip_user_status
	end

	local str = con:api("sofia status"):getBody()

	local start_index = string.find(str,"=\n")
	local end_index = string.find(str,"\n",start_index+2)
	local total_len = string.find(str,"\n=",start_index)

	while  start_index < total_len and end_index <= total_len do
		local current_line = string.sub(str,start_index+2,end_index)
		if string.find(current_line,"::") then
			local gw_name = current_line:match("::(.*)%s+gateway")
			local gw_info = con:api("sofia status gateway "..gw_name):getBody()
			if not gw_info:match("^Invalid Gateway") then
				local user = gw_info:match("Username%s+([^\n]+)")
				local state = gw_info:match("State%s+([%u_]+)")
				local status = gw_info:match("Status%s+(%u+)")
				local callin = gw_info:match("CallsIN%s+(%d+)")
				local callin_fail = gw_info:match("FailedCallsIN%s+(%d+)")
				local callout = gw_info:match("CallsOUT%s+(%d+)")
				local callout_fail = gw_info:match("FailedCallsOUT%s+(%d+)")
				local tmp = {}
				tmp.name = gw_name:match("%d+%_(.*)") or gw_name
				tmp.state = state
				tmp.status = status
				tmp.callin = callin
				tmp.callin_fail = callin_fail
				tmp.callout = callout
				tmp.callout_fail = callout_fail
				table.insert(sip_gw_status,tmp)
			else
				local tmp = {}
				local state = current_line:match("[%d%.]+:%d+%s+(.+)\n")
				tmp.name = gw_name
				tmp.state = state
				tmp.status = "DOWN"
				tmp.callin = 0
				tmp.callin_fail = 0
				tmp.callout = 0
				tmp.callout_fail = 0
				table.insert(sip_gw_status,tmp)
			end
		else
			local profile_name, data, state, call = current_line:match("%s+(.*)%s+profile.*@([0-9.:]+)%s*(%a+)%s+[(](%d+)[)]")
			local profile_info = con:api("sofia status profile "..profile_name):getBody()

			local codec_in = profile_info:match("CODECS%s+IN%s+([^\n]+)")
			local codec_out = profile_info:match("CODECS%s+OUT%s+([^\n]+)")
			local callin = profile_info:match("CALLS[-]IN%s+(%d+)")
			local callin_fail = profile_info:match("FAILED[-]CALLS[-]IN%s+(%d+)")
			local callout = profile_info:match("CALLS[-]OUT%s+(%d+)")
			local callout_fail = profile_info:match("FAILED[-]CALLS[-]OUT%s+(%d+)")
			local tmp={}
			tmp.name = profile_name
			tmp.data = data
			tmp.state = state
			tmp.call = call
			tmp.codec_in = codec_in
			tmp.codec_out = codec_out
			tmp.callin = callin
			tmp.callin_fail = callin_fail
			tmp.callout = callout
			tmp.callout_fail = callout_fail
			--tmp.detail = profile_info
			table.insert(sip_profile_status,tmp)
		end
		start_index = string.find(str,"\n",end_index)
		end_index = string.find(str,"\n",start_index+1)
	end

	local sipuser = uci:get_all("endpoint_sipphone")

	local sipprofile_list = {}
	local user_list = {}

	for k,v in pairs(sipuser) do
		if v.user and v.profile then
			sipprofile_list[v.profile] = v.profile
			user_list[v.user] = v.profile
		end
	end

	local netinfo = uci:get_all("network","lan")

	for k,v in pairs(sipprofile_list) do
		str = con:api("sofia status profile "..k.." reg"):getBody()
		if not str:match("Total items returned: 0") then
			for i,j in pairs(user_list) do
				if j == k then
					local start_idx = string.find(str,"\t"..i.."@")
					if start_idx then
						local end_idx = string.find(str,"\n\n",start_idx)
						local user_str = string.sub(str,start_idx,end_idx)
						local tmp = {}
						tmp.user = i
						local ip = user_str:match("IP:%s+([0-9%.]+)\n") or ""
						local port = user_str:match("Port:%s+(%d+)\n") or ""
						tmp.from = ip..":"..port
						tmp.status = user_str:match("Status:%s+([%a%(%)%-]+)%(") or ""
						tmp.exp = user_str:match("EXPSECS%((%d+)%)") or ""
						tmp.agent = user_str:match("Agent:%s*(.+)\nStatus") or ""
						table.insert(sip_user_status,tmp)
					end
				end
			end
		end
	end

	for k,v in pairs(user_list) do
		local flag = true
		for i,j in ipairs(sip_user_status) do
			if j.user == k then
				flag = false
				break
			end
		end
		if flag then
			local tmp = {}
			tmp.user = k
			tmp.from = ""
			tmp.status = "Unregistered"
			tmp.exp = ""
			tmp.agent = ""
			table.insert(sip_user_status,tmp)
		end
	end

	con:disconnect()

	return sip_profile_status,sip_gw_status,sip_user_status
end

function calls()
	local con = ESL.ESLconnection("127.0.0.1","8021","ClueCon")
	local info = {}

	if con:connected() ~= 1 then
		return info
	end

	local str = con:api("show detailed_calls as xml"):getBody()
	local root = mxml.parsestring(str)

	if root then
		local row = mxml.getfirstchild(root)

		while row do
			local param = mxml.getfirstchild(row)
			local tmp = {}
			local name
			local value
			while param do
				name = mxml.getname(param)
				value = mxml.gettext(param)
				if name and value then
					tmp[name] = value
				end
				param = mxml.getnextsibling(param)
			end
			table.insert(info,tmp)
			row = mxml.getnextsibling(row)
		end
	else	
	end
	mxml.release(root)
	con:disconnect()
	
	return info
end

function port_reg_status()
	local uci = require "luci.model.uci".cursor()
	uci:check_cfg("endpoint_fxso")
	uci:check_cfg("endpoint_mobile")

	local con = ESL.ESLconnection("127.0.0.1","8021","ClueCon")

	local running_gw_status = {}
	local port_reg_status = {}

	if con:connected() ~= 1 then
		return port_reg_status
	end

	local str = con:api("sofia status"):getBody()

	local start_index = string.find(str,"=\n")
	local end_index = string.find(str,"\n",start_index+2)
	local total_len = string.find(str,"\n=",start_index)

	while  start_index < total_len and end_index <= total_len do
		local current_line = string.sub(str,start_index+2,end_index)
		if string.find(current_line,"::") then
			local gw_name = current_line:match("::%d+%_(.*)%s+gateway")
			
			local tmp = {}
			local state = current_line:match("@[%d%.a-zA-Z]+[%:%d]*%s+(.+)\n")
			running_gw_status[gw_name] = state
		end
		start_index = string.find(str,"\n",end_index)
		end_index = string.find(str,"\n",start_index+1)
	end

	con:disconnect()

	local cfg = uci:get_all("endpoint_fxso")
	for k,v in pairs(cfg) do
		if "Enabled" == v.status and v.slot_type then
			port_reg_status[v.slot_type] = {user_1 = v.number_1 or "",reg_1 = "Unregistered",user_2 = v.number_2 or "",reg_2 = "Unregistered"}
			if "on" == v.port_1_reg and v.number_1 then
				local index = v.port_1_server_1.."-"..v.slot_type.."-1-"..v.number_1
				if v.port_1_server_1 and "0" ~= v.port_1_server_1 then
					if "REGED" == running_gw_status[index] or "REGISTER" == running_gw_status[index] then
						port_reg_status[v.slot_type]["reg_1"] = "Reged(Master)"
					end
				end
				if v.port_1_server_2 and "0" ~= v.port_1_server_2 then
					index = v.port_1_server_2.."-"..v.slot_type.."-1-"..v.number_1
					if "REGED" == running_gw_status[index] or "REGISTER" == running_gw_status[index] then
						port_reg_status[v.slot_type]["reg_1"] = "Reged(Master)" == port_reg_status[v.slot_type]["reg_1"] and "Reged(All)" or "Reged(Slave)"
					end
				end
			else
				port_reg_status[v.slot_type]["reg_1"] = "Not Config"
			end
			if "on" == v.port_2_reg and v.number_2 then
				local index = v.port_2_server_1.."-"..v.slot_type.."-2-"..v.number_2
				if v.port_2_server_1 and "0" ~= v.port_2_server_1 then
					if "REGED" == running_gw_status[index] or "REGISTER" == running_gw_status[index] then
						port_reg_status[v.slot_type]["reg_2"] = "Reged(Master)"
					end
				end
				if v.port_2_server_2 and "0" ~= v.port_2_server_2 then
					index = v.port_2_server_2.."-"..v.slot_type.."-2-"..v.number_2
					if "REGED" == running_gw_status[index] or "REGISTER" == running_gw_status[index] then
						port_reg_status[v.slot_type]["reg_2"] = "Reged(Master)" == port_reg_status[v.slot_type]["reg_2"] and "Reged(All)" or "Reged(Slave)"
					end
				end
			else
				port_reg_status[v.slot_type]["reg_2"] = "Not Config"
			end
		end
	end

	cfg = uci:get_all("endpoint_mobile")
	for k,v in pairs(cfg) do
		if "Enabled" == v.status and v.slot_type then
			port_reg_status[v.slot_type] = {user = v.number or "",reg = "Unregistered"}
			if "on" == v.port_reg and v.number then
				if v.port_server_1 and "0" ~= v.port_server_1 then
					local index = v.port_server_1.."-"..v.slot_type.."-"..v.number
					if "REGED" == running_gw_status[index] or "REGISTER" == running_gw_status[index] then
						port_reg_status[v.slot_type]["reg"] = "Reged(Master)"
					end
				end
				if v.port_server_2 and "0" ~= v.port_server_2 then
					local index = v.port_server_2.."-"..v.slot_type.."-"..v.number
					if "REGED" == running_gw_status[index] or "REGISTER" == running_gw_status[index] then
						port_reg_status[v.slot_type]["reg"] = "Reged(Master)" == port_reg_status[v.slot_type]["reg"] and "Reged(All)" or "Reged(Slave)"
					end
				end
			else
				port_reg_status[v.slot_type]["reg"] = "Not Config"
			end
		end
	end

	return port_reg_status
end

function pstn_status(reset_flag)
	local sqlite = require "luci.scripts.sqlite3_service"
	local uci = require "luci.model.uci".cursor()
	local gsm_status = {}
	local fxs_status = {}
	local fxo_status = {}
	local ret_tb = {}
	local err = ""

	local fxso_cfg = uci:get_all("endpoint_fxso")
	for k,v in pairs(fxso_cfg) do
		if "0-FXS" == v.slot_type then
			if "Disabled" == v.status then
				fxs_status.disabled = "on"
			elseif not v.port_1_reg or (v.port_1_reg and "on" ~= v.port_1_reg) then
				fxs_status.reg_config = "off"
			end
		end
		if "0-FXO" == v.slot_type then
			if "Disabled" == v.status then
				fxo_status.disabled = "on"
			elseif not v.port_2_reg or (v.port_2_reg and "on" ~= v.port_2_reg) then
				fxo_status.reg_config = "off"
			end
		end
	end

	local mobile_cfg = uci:get_all("endpoint_mobile")
	for k,v in pairs(mobile_cfg) do
		if "1-GSM" == v.slot_type then
			if "Disabled" == v.status then
				gsm_status.disabled = "on"
			elseif not v.port_reg or (v.port_reg and "on" ~= v.port_reg) then
				gsm_status.reg_config = "off"
			end
		end
	end
	
	if fxs_status.disabled and fxo_status.disabled and gsm_status.disabled then
		return fxs_status,fxo_status,gsm_status
	end

	local port_reg_status = port_reg_status()

	ret_tb,err = sqlite.sqlite3_execute("/tmp/fsdb/core.db","select * from pstn")

	for k,v in pairs(ret_tb) do
		if v.dev_state then
			v.dev_state = v.dev_state:match("DEV_(.+)")
		end
		if v.config_state then
			v.config_state = v.config_state:match("CONFIG_STATUS_(.+)")
		end

		if v.type == "FXS" and not fxs_status.disabled then
			if port_reg_status["0-FXS"] then
				v.user = port_reg_status["0-FXS"]["user_1"] or ""
				v.regstate = port_reg_status["0-FXS"]["reg_1"] or "Unregistered"
			else
				v.user = ""
				v.regstate = "off"==fxs_status.reg_config and "Not Config" or "Unregistered"
			end
			table.insert(fxs_status,v)
		elseif v.type == "FXO" and not fxo_status.disabled then
			if port_reg_status["0-FXO"] then
				v.user = port_reg_status["0-FXO"]["user_2"] or ""
				v.regstate = port_reg_status["0-FXO"]["reg_2"] or "Unregistered"
			else
				v.user = ""
				v.regstate = "off"==fxo_status.reg_config and "Not Config" or "Unregistered"
			end	
			table.insert(fxo_status,v)
		elseif ("GSM1" == v.type or "GSM" == v.type) and not gsm_status.disabled then
			if port_reg_status["1-GSM"] then
				v.user = port_reg_status["1-GSM"]["user"] or ""
				v.regstate = port_reg_status["1-GSM"]["reg"] or "Unregistered"
			else
				v.user = ""
				v.regstate = "off"==gsm_status.reg_config and "Not Config" or "Unregistered"
			end	
			table.insert(gsm_status,v)
		else
		
		end
	end

	return fxs_status,fxo_status,gsm_status
end

--cdrs
function empty_cdr()
	local con = ESL.ESLconnection("127.0.0.1","8021","ClueCon")
	if con:connected() ~= 1 then
		return false
	end

	con:api("cdr empty")

	return true
end

--msg
function message(cmd)
	local con = ESL.ESLconnection("127.0.0.1","8021","ClueCon")
	local mobile_status = {}
	
	if con:connected() ~= 1 then
		if nil == cmd then
			return mobile_status
		else
			return ""
		end
	end

	if not cmd then
		local str = con:api("gsm dump list"):getBody()
		if not str:match("^-ERR") then  
			local tmp_tb = luci.util.split(str,"\n\n")
			for k,v in pairs(tmp_tb) do
				if 1 == tonumber(v:match("chan_ready%s*=%s*(%d+)\n")) and "0" == v:match("not_registered%s*=%s*(%d+)\n") and "SIMPIN_READY" == v:match("simpin_state%s*=%s*([a-zA-Z_]+)\n") then
				   local temp = {}
				   temp.slot = v:match("slot%s*=%s*([0-9]+)\n")
				   temp.type = v:match("boardtype%s*=%s*([0-9A-Z]+)")
				   temp.name = v:match("interface_name%s*=%s*([a-zA-Z0-9_%-]+)\n")  
				   table.insert(mobile_status, temp)
				end
			end
		end

		con:disconnect()
		return mobile_status
	 elseif cmd then
		local str = con:api(cmd):getBody()
		con:disconnect()
		return str 
	 end
end

function light_location_calc(slot, slot_type)
	local html = ""
	local level = 0
	local margin_top = 0
	local margin_left = (slot%6) * 150 + 65

	if slot < 6 then
		level = 1
	else
		level = 0
	end

	if "FXS" == slot_type or "FXO" == slot_type then
		margin_top = level * 50 + 24
		html = "<div id=light.fxso."..slot..".0 style='margin-left:"..margin_left.."px; margin-top:"..margin_top.."px;' class=pannel-light></div>"
		margin_top = level * 50 + 12
		html = html.."<div id=light.fxso."..slot..".1 style='margin-left:"..margin_left.."px; margin-top:"..margin_top.."px;' class=pannel-light></div>"
	elseif "FXSO" == slot_type then
		margin_top = level * 50 + 24
		html = "<div id=light.fxso."..slot..".0 style='margin-left:"..margin_left.."px; margin-top:"..margin_top.."px;' class=pannel-light></div>"
		margin_top = level * 50 + 12
		html = html.."<div id=light.fxso."..slot..".1 style='margin-left:"..margin_left.."px; margin-top:"..margin_top.."px;' class=pannel-light></div>"		
	elseif "GSM" == slot_type or "CDMA" == slot_type then
		margin_top = level * 50 + 24
		html = "<div id=light.mobile."..slot..".0 style='margin-left:"..margin_left.."px; margin-top:"..margin_top.."px;' class=pannel-light></div>"
	end

	return html
end

function userboard_upgrade(cmd)
	local con = ESL.ESLconnection("127.0.0.1","8021","ClueCon")
	
	if con:connected() ~= 1 then
		return false
	end

	local str = con:api(cmd):getBody()
	if string.find(str,"ERR") then
		con:disconnect()
		return false
	else
		con:disconnect()
		return true
	end
end

function get_pstn_upgrade_status()
	local con = ESL.ESLconnection("127.0.0.1","8021","ClueCon")
	local upgrade_status = {}
	
	if con:connected() ~= 1 then
		return upgrade_status
	end	

	local ret_gsm_str = con:api("gsm transport update -v"):getBody()--test
	if ret_gsm_str:match("-ERR") then
		ret_gsm_str = con:api("ftdm driver transport update -v"):getBody()
	end
	
	if  not ret_gsm_str:match("-ERR") then
		local ret_tb = luci.util.split(ret_gsm_str,"\n\n")
		for k,v in pairs(ret_tb) do
			if v ~= "" then
				local status = v:match("updata_userboard_step%s*=%s*([A-Z_]+)\n")		
				if "UPDATE_USERBOARD_SETP_IDLE" ~= status then	
					local slot = v:match("slot%s*=%s*([0-9]+)\n")
					local type = v:match("board_type%s*=%s*([a-zA-Z2]+)\n")
					local total_size = v:match("file_total_len%s*=%s*([0-9]+)\n")
					local cur_size = v:match("cur_index%s*=%s*([0-9]+)\n")
					local percent
					if (tonumber(cur_size)*4) >= tonumber(total_size) then
							percent = "100%"
					else
						percent = string.sub(tostring((tonumber(cur_size)*4/tonumber(total_size))*100),1,5).."%"
					end
					
					local tmp_tb = {}
					tmp_tb.slot = slot
					if type == "FXS2" or type == "FXO2" then
						tmp_tb.type = string.sub(type,1,3)
					else
						tmp_tb.type = type
					end
					tmp_tb.status = status
					tmp_tb.percent = percent

					table.insert(upgrade_status,tmp_tb)
				end
			end
		end
	end
	
	con:disconnect()
	return upgrade_status
end

function get_sms()
	local sqlite = require "luci.scripts.sqlite3_service"
	local sms_db_dir = "/etc/freeswitch/sms"
	local msg_info = {}
	local ret_tb = {}
	local send_tb = {}
	local recv_tb = {}
	local err = ""

	send_tb,err = sqlite.sqlite3_execute(sms_db_dir,"select * from sms_sending")
	
	ret_tb,err = sqlite.sqlite3_execute(sms_db_dir,"select * from sms_sendover")
	for k,v in pairs(ret_tb) do
		table.insert(send_tb,v)
	end
	
	recv_tb,err = sqlite.sqlite3_execute(sms_db_dir,"select * from sms_recv")

	table.insert(msg_info,send_tb)
	table.insert(msg_info,recv_tb)
	
	return msg_info
end

function get_wifi_list(param)
	local uci = require "luci.model.uci".cursor("/tmp/config")
	local util = require "luci.util"
	local fs = require "luci.fs"
	local lasttime = os.time()
	local ret_wifi_list = {}
	local param = param
	local profile_wifi = {}

	uci:check_cfg("profile_wifi")

	if param and param == "refresh" then
		profile_wifi = uci:get_all("profile_wifi") or {}
		--@ refresh
		if fs.access("/lib/modules/3.14.18/rt2860v2_ap.ko") then
			--@ new driver
			local status =  util.exec("ifconfig | grep 'ra0'")
			if status == "" then
				return ret_wifi_list
			else
				luci.util.exec("iwpriv ra0 set SiteSurvey=")
				local ret_str = util.exec("iwpriv ra0 get_site_survey")
				local tmp_tb = util.split(ret_str,"\n")

				for _,v in pairs(tmp_tb or {}) do
					if v and v:match("^[0-9]") then
						local channel,ssid,bssid,encryption,signal
						local exist_flag = true

						channel,ssid,bssid,encryption,signal = v:match("^([0-9]+)%s+([a-zA-Z0-9%.%-%_/]+)%s+(%w%w:%w%w:%w%w:%w%w:%w%w:%w%w)%s+([a-zA-Z0-9%/]+)%s+([0-9]+)%s*")
						if channel then
							exist_flag = false
							bssid = string.upper(bssid)
							signal = signal.."%"
							for k,v in pairs(profile_wifi) do
								if v.bssid and v.bssid == bssid then
									exist_flag = true
									uci:set("profile_wifi",k,"channel",channel)
									uci:set("profile_wifi",k,"ssid",ssid)
									uci:set("profile_wifi",k,"encryption",encryption)
									uci:set("profile_wifi",k,"signal",signal)
									uci:set("profile_wifi",k,"lasttime",lasttime)
									break
								end
							end
						end
						if not exist_flag then
							local section = uci:section("profile_wifi","wifi")
							uci:set("profile_wifi",section,"ssid",ssid)
							uci:set("profile_wifi",section,"channel",channel)
							uci:set("profile_wifi",section,"bssid",bssid)
							uci:set("profile_wifi",section,"encryption",encryption)
							uci:set("profile_wifi",section,"signal",signal)
							uci:set("profile_wifi",section,"lasttime",lasttime)
						end
					end
				end
			end
		else
			--@ old driver
			local status =  util.exec("ifconfig | grep 'wlan0'")
			if status == "" then
				return ret_wifi_list
			else
				local ret_str = util.exec("iwlist wlan0 scanning|sed '1d'|tr '\n' ','|tr -d ' '|sed 's/,Cell/\\nCell/g'")
				local tmp_tb = luci.util.split(ret_str,"\n")

				for k,v in pairs(tmp_tb or {}) do
					if v and v:match("^Cell") then
						local channel = v:match("Channel:(%d+),") or ""
						local ssid = v:match("ESSID:\"(.-)\"") or ""
						local bssid = v:match("Address:(%w%w:%w%w:%w%w:%w%w:%w%w:%w%w)") or ""
						local signal = v:match("Signallevel=(%-%d+dBm)") or ""
						local encryption = ""
						local exist_flag = true

						if v:match("Encryptionkey:off") then
							encryption = "NONE"
						elseif v:match("IE:IEEE802.11i/WPA2Version1") then
							encryption = "WPA2PSK"
						elseif v:match("IE:WPAVersion1") then
							encryption = "WPA1PSK"
						else
							encryption = "WPA1PSK"
						end

						if channel ~= "" and ssid ~= "" and bssid ~= "" and signal ~= "" and encryption ~= "" then
							exist_flag = false
							bssid = string.upper(bssid)
							for k,v in pairs(profile_wifi) do
								if v.bssid and v.bssid == bssid then
									exist_flag = true
									uci:set("profile_wifi",k,"channel",channel)
									uci:set("profile_wifi",k,"ssid",ssid)
									uci:set("profile_wifi",k,"encryption",encryption)
									uci:set("profile_wifi",k,"signal",signal)
									uci:set("profile_wifi",k,"lasttime",lasttime)
									break
								end
							end
						end
						if not exist_flag then
							local section = uci:section("profile_wifi","wifi")
							uci:set("profile_wifi",section,"ssid",ssid)
							uci:set("profile_wifi",section,"channel",channel)
							uci:set("profile_wifi",section,"bssid",bssid)
							uci:set("profile_wifi",section,"encryption",encryption)
							uci:set("profile_wifi",section,"signal",signal)
							uci:set("profile_wifi",section,"lasttime",lasttime)
						end
					end
				end
			end
		end
		uci:commit("profile_wifi")
	end

	profile_wifi = uci:get_all("profile_wifi") or {}
	for k,v in pairs(profile_wifi) do
		if v.bssid then
			if v.lasttime and (lasttime - v.lasttime) < 300 then
				table.insert(ret_wifi_list,v)
			else
				uci:delete("profile_wifi",k)
			end
		end
	end
	uci:commit("profile_wifi")
	
	return ret_wifi_list
end

function carrier_list(slot)
	local con = ESL.ESLconnection("127.0.0.1","8021","ClueCon")

	local carrier_list = {}

	if con:connected() ~= 1 then
		return carrier_list
	end

	local str = con:api("gsm oper "..(slot or "")):getBody()

	local total_len = #str
	local start_index = string.find(str,"oper_index") or total_len
	local end_index = string.find(str,"numeric",start_index+1) or total_len
	

	while  start_index < total_len and end_index <= total_len do
		local current = string.sub(str,start_index,end_index)
		if not string.find(current,"forbidden") then
			local tmp = {}
			tmp.idx = current:match("oper_index%s+=%s+(%d+)")
			tmp.state = current:match("oper_state%s+=%s+(%a+)")
			tmp.name = current:match("longname%s+=%s+(.+)\nshort")
			
			table.insert(carrier_list,tmp)
		end
		start_index = string.find(str,"oper_index",end_index) or total_len
		end_index = string.find(str,"numeric",start_index+1) or total_len
	end

	con:disconnect()

	return carrier_list
end

function bcch_list(slot)
	local con = ESL.ESLconnection("127.0.0.1","8021","ClueCon")

	local bcch_list = {}

	if con:connected() ~= 1 then
		return bcch_list
	end

	local str = con:api("gsm bcch "..(slot or "")):getBody()

	local total_len = #str
	local start_index = string.find(str,"bcch_index") or total_len
	local end_index = string.find(str,"bcch_index",start_index+1) or total_len

	while  start_index < total_len and end_index <= total_len do
		local current = string.sub(str,start_index,end_index)
		local tmp = {}
		tmp.idx = current:match("bcch_index%s+=%s+(%d+)")
		tmp.lac = current:match("lac%s+=%s+(%w+)")
		tmp.bcch = current:match("bcch%s+=%s+(%d+)")
		tmp.recv = current:match("recv_level%s+=%s+(-%d+)")

		table.insert(bcch_list,tmp)
		start_index = string.find(str,"bcch_index",end_index) or total_len
		end_index = string.find(str,"bcch_index",start_index+1) or total_len
	end

	con:disconnect()

	return bcch_list
end
