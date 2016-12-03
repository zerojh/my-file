module("luci.controller.admin.callcontrol",package.seeall)

function index()
	if luci.http.getenv("SERVER_PORT") == 8345 or luci.http.getenv("SERVER_PORT") == 8848 then
		local page
		page = node("admin","callcontrol")
		page.target = firstchild()
		page.title = _("Call Control")
		page.order = 80
		page.index = true
		entry({"admin", "callcontrol", "setting"}, cbi("admin_callcontrol/setting"), _("Setting"), 1)
		entry({"admin","callcontrol","routegroup"},call("routegroup"),"Route Group",2)
		entry({"admin","callcontrol","routegroup","routegroup"},cbi("admin_callcontrol/routegroup_edit"),nil,2).leaf = true
		entry({"admin","callcontrol","route"},call("route"),"Route",3)
		entry({"admin","callcontrol","route","route"},cbi("admin_callcontrol/route_edit"),nil,3).leaf = true
		entry({"admin","callcontrol","featureCode"},call("featurecode"),"Feature Code",4)
		entry({"admin","callcontrol","featureCode","featureCode"},cbi("admin_callcontrol/featureCode_edit"),nil,4).leaf = true
		entry({"admin","callcontrol","ivr"},cbi("admin_callcontrol/ivr_edit"),"IVR",5)
		--entry({"admin","callcontrol","ivr","action"},call("action_ivr"),nil)
		--@ SMS route
		entry({"admin","callcontrol","sms_route"},call("action_sms_route"),"SMS Route",6)
		entry({"admin","callcontrol","sms_route","sms_route"},cbi("admin_callcontrol/sms_route_edit"),nil,10).leaf = true
		--entry({"admin", "callcontrol", "flowcontrol"}, template("admin_callcontrol/flowcontrol"), "Flow Control",4)
		if luci.version.license and (luci.version.license.gsm or luci.version.license.lte) then
			entry({"admin", "callcontrol", "sms"}, template("admin_callcontrol/sms"), "SMS",7)
			entry({"admin", "callcontrol", "ussd"}, call("action_ussd_get"), "USSD",8)
			page = entry({"admin","callcontrol","sendmsg"},call("action_sendmsg"),nil)
			page.leaf = true
			page = entry({"admin","callcontrol","deletemsg"},call("action_deletemsg"),nil)
			page.leaf = true
			page = entry({"admin","callcontrol","readmsg"},call("action_readmsg"),nil)
			page.leaf = true
			page = entry({"admin","callcontrol","emptymsg"},call("action_emptymsg"),nil)
			page.leaf = true
			page = entry({"admin","callcontrol","exportmsg"},call("action_exportmsg"),nil)
			page.leaf = true
			page = entry({"admin","callcontrol","sendussd"},call("action_sendussd"),nil)
			page.leaf = true
			page = entry({"admin","callcontrol","quitussd"},call("action_quitussd"),nil)
			page.leaf = true
		end
		entry({"admin", "callcontrol", "diagnostics"}, call("action_call_trace"), "Diagnostics",9)
	end
end

function action_sms_route()
	local MAX_ROUTE = 32
	local uci = require "luci.model.uci".cursor()
	local ds = require "luci.dispatcher"
	local i18n = require "luci.i18n"
	uci:check_cfg("profile_smsroute")
	--@ delete
	local del_target = luci.http.formvaluetable("Delete")
	if next(del_target) then
		uci:delete_section(del_target)
	end
	--@ new
	if luci.http.formvalue("New") then
		local created = uci:section("profile_smsroute","rule")
		uci:save("profile_smsroute")
		luci.http.redirect(ds.build_url("admin","callcontrol","sms_route","sms_route",created,"add"))
		return
	end

	local th = {"Priority","Name","Source","Src Number Prefix","Destination","Dest Number","Prefix","Suffix"}
	local colgroup = {"6%","10%","8%","13%","9%","15","15%","15","9%"}
	local content = {}
	local edit = {}
	local delchk = {}
	local uci_cfg = {}
	local status = {}
	local addnewable = true
	local cnt = 0
	local profile = uci:get_all("profile_smsroute")
	
	for i=1,MAX_ROUTE do
		for k,v in pairs(profile) do
			if v.index and v.name and i == tonumber(v.index) then
				cnt = cnt + 1
				local td = {}
				td[1] = v.index
				td[2] = v.name
				
				if v.from == "0" then
					td[3] = "SIP"
				else
					td[3] = get_name_by_cfgtype_id(v.from:match("([A-Z]+)"),v.from:match("([0-9]+)"))
				end
				
				td[4] = v.src_number or i18n.translate("NONE")
				td[5] = get_name_by_cfgtype_id(v.dest:match("([A-Z]+)"),v.dest:match("([0-9]+)"))
				if v.dest_number_src == "to" then
					td[6] = i18n.translate("Get from To Header Field")
				elseif v.dest_number_src == "content" and v.dest_number_separator then
					td[6] = i18n.translate("Get from Content").." / "..v.dest_number_separator
				else
					td[6] = v.dst_number or i18n.translate("NONE")
				end
				if v.prefix == "from" then
					td[7] = i18n.translatef("From %s : ","${from_user}")
				elseif v.prefix == "custom" then
					td[7] = v.custom_prefix or ""
				else
					td[7] = i18n.translate("NONE")
				end
				if v.suffix == "from" then
					td[8] = i18n.translatef(" -- Send by %s","${from_user}")
				elseif v.suffix == "custom" then
					td[8] = v.custom_suffix or ""
				else
					td[8] = i18n.translate("NONE")
				end
				
				edit[cnt] = ds.build_url("admin","callcontrol","sms_route","sms_route",k,"edit")
				delchk[cnt] = ""
				uci_cfg[cnt] = "profile_smsroute." .. k
				table.insert(content,td)
				break
			elseif not v.index or not v.name then
				uci:delete("profile_smsroute",k)
			end
		end
	end
	if MAX_ROUTE == cnt then
		addnewable = false
	end
	luci.template.render("cbi/configlist",{
		title = i18n.translate("Call Control / SMS Route"),
		colgroup = colgroup,
		th = th,
		content = content,
		edit = edit,
		delchk = delchk,
		status = status,
		uci_cfg = uci_cfg,
		addnewable = addnewable,
		})
end

function action_call_trace()
	require "ESL"
	local sys = require "luci.sys"
	local fs  = require "luci.fs"
	local util = require "luci.util"
 	local uci = require "luci.model.uci".cursor()

	local calltrace_status = "stop"
	local calltrace_options = "sipmsg,fxso,gsm"

	if luci.http.formvalue("calltrace_start") then
		local mod = luci.http.formvaluetable("trace")
		local con = ESL.ESLconnection("127.0.0.1","8021","ClueCon")
		
		if 1 == con:connected() and next(mod) then
			con:api("fsctl loglevel debug")
			calltrace_options = ""
			for k,v in pairs(mod) do
				calltrace_options = calltrace_options..k
				if "sipstack" == k then
					con:api("sofia loglevel all 9")
				elseif "sipmsg" == k then
					con:api("sofia global siptrace on")
				elseif "fxso" == k then
					con:api("ftdm loglevel debug")
				elseif "gsm" == k then
					con:api("gsm log on")
				elseif "dsp" == k then
					con:api("c300dsp 1000 6")
				elseif "voice" == k then
					local sip_profile = uci:get_all("profile_sip")
					local port
					for k,v in pairs(sip_profile) do
						if v.index and v.localport then
							port = port and (port.." or "..v.localport) or v.localport
						end
					end

					local portrange = (uci:get_all("callcontrol","voice","rtp_start_port") or "16000") .. "-" .. (uci:get_all("callcontrol","voice","rtp_end_port") or "16200")
					con:api("c300dsp 450 9")
					os.execute("tcpdump -U -C 10 -W 1 -s 0 -i any "..(port and ("port "..port.." or ") or "").." portrange "..portrange.." -w /tmp/rtp_capture.pcap &")
				end
				fs.writefile("/tmp/calltrace_options",calltrace_options)
			end
			con:disconnect()
			calltrace_status = "calltrace_working"
			os.execute("touch /tmp/calltrace_flag && logread -f > /tmp/calltrace.txt & ")
		end	
	elseif luci.http.formvalue("calltrace_end") then
		local level = {"console","alert","crit","err","warning","notice","info","debug"}
		local loglevel = uci:get("system","main","loglevel") or 6

		local con = ESL.ESLconnection("127.0.0.1","8021","ClueCon")

		if 1 == con:connected() then
			con:api("fsctl loglevel "..level[loglevel])
			con:api("gsm log off")
			con:api("ftdm loglevel "..level[loglevel])
			con:api("sofia global siptrace off")
			con:api("sofia loglevel all 0")
			con:api("c300dsp 1000 3")
		end

		os.execute("killall logread && killall tcpdump")
		os.execute("sleep 2 && rm /tmp/calltrace_with_voice_flag /tmp/calltrace_flag")

		if fs.access("/tmp/calltrace0.txt") then
			os.execute("cat /tmp/calltrace.txt >> /tmp/calltrace0.txt && mv /tmp/calltrace0.txt /tmp/calltrace.txt")
		end

		local localip = luci.http.getenv("SERVER_ADDR")
		local trace_file = "/tmp/calltrace.txt"
		local voice_file = "/tmp/rtp_capture.pcap"
		if fs.access(trace_file) and fs.access(voice_file) then
			local destfile_gz = "/tmp/calltrace.tar.gz"
			if 1 == con:connected() then
				con:api("c300dsp 451 9")
			end

			sys.call("tar -c /tmp/pcm_send_* /tmp/pcm_recv_* /tmp/rtp_capture.pcap /tmp/calltrace.txt -f "..destfile_gz)
			local reader = luci.ltn12.source.file(io.open(destfile_gz,"r"))
			luci.http.header('Content-Disposition', 'attachment; filename="call_trace-%s-%s-%s.tar.gz"' % {
				luci.sys.hostname(), localip, os.date("%Y-%m-%d %X")})
			luci.http.prepare_content("application/gzip")
			luci.ltn12.pump.all(reader, luci.http.write)
			fs.unlink(destfile_gz)

			os.execute("rm /tmp/pcm_send_* /tmp/pcm_recv_* /tmp/rtp_capture.pcap /tmp/calltrace*")
		elseif fs.access(trace_file) then
			luci.http.header('Content-Disposition', 'attachment; filename="call_trace-%s-%s-%s.txt"' % {
				luci.sys.hostname(), localip, os.date("%Y-%m-%d %X")})
			luci.http.prepare_content("text/plain")
			luci.ltn12.pump.all(luci.ltn12.source.file(io.open(trace_file)), luci.http.write)
			fs.unlink(trace_file)
		end
		con:disconnect()
	else
		if fs.access("/tmp/calltrace_flag") then
			calltrace_status = "calltrace_working"
			calltrace_options = fs.readfile("/tmp/calltrace_options")
		end
		luci.template.render("admin_callcontrol/calltrace",{calltrace_status=calltrace_status,calltrace_options=calltrace_options})
	end
end

function action_ivr()
	local sys = require "luci.sys"
	local fs  = require "luci.fs"
	local ds = require "luci.dispatcher"
	local uci = require "luci.model.uci".cursor()
	
	local section = luci.http.formvalue("section")
	local count = luci.http.formvalue("count")
	
	if luci.http.formvalue("status") == "Delete" then
		--@ uci work
		local del_index = luci.http.formvalue("index")
		for i=tonumber(del_index),tonumber(count) do
			if del_index == count then
				uci:delete("ivr",section,"dtmf_"..count)
				uci:delete("ivr",section,"service_"..count)
				uci:delete("ivr",section,"service_choose_"..count)
				uci:delete("ivr",section,"destination_number_"..count)
				uci:delete("ivr",section,"del_button_"..count)
				uci:set("ivr",section,"option_count",tonumber(count)-1)
				break
			else
				if uci:get("ivr",section,"dtmf_"..(i+1)) then
					uci:set("ivr",section,"dtmf_"..i,uci:get("ivr",section,"dtmf_"..(i+1)))
				end
				if uci:get("ivr",section,"service_"..(i+1)) then
					uci:set("ivr",section,"service_"..i,uci:get("ivr",section,"service_"..(i+1)))
				end
				if uci:get("ivr",section,"service_choose_"..(i+1)) then
					uci:set("ivr",section,"service_choose_"..i,uci:get("ivr",section,"service_choose_"..(i+1)))
				end
				if uci:get("ivr",section,"destination_number_"..(i+1)) then
					uci:set("ivr",section,"destination_number_"..i,uci:get("ivr",section,"destination_number_"..(i+1)))
				end
				if uci:get("ivr",section,"del_button_"..(i+1)) then
					uci:set("ivr",section,"del_button_"..i,uci:get("ivr",section,"del_button_"..(i+1)))
				end	
				uci:set("ivr",section,"option_count",tonumber(count)-1)
			end
		end
		uci:save("ivr")
		luci.http.prepare_content("text/plain")
		luci.http.write(ds.build_url("admin","callcontrol","ivr","ivr",section,"edit",tostring(tonumber(count)-1)))
		--luci.http.redirect(ds.build_url("admin","callcontrol","ivr","ivr",section,"edit",tostring(tonumber(count)-1)))
		return 
	elseif luci.http.formvalue("status") == "Add" then
		--@ uci work
		uci:set("ivr",section,"option_count",tonumber(count)+1)
		uci:save("ivr")
		luci.http.prepare_content("text/plain")
		luci.http.write(ds.build_url("admin","callcontrol","ivr","ivr",section,"edit",tostring(tonumber(count)+1)))		
	else
		luci.template.render("cbi/ivrconf",{
			title = i18n.translate("IVR"),
			colgroup = colgroup,
			split_col = 4,
			classname = "paddingtight",
			th = th,
			content = content,
			edit = edit,
			delchk = delchk,
			delvalue = delvalue,
			addnewable = addnewable,
			})
	end
end

function get_name_by_index(cfg,index,cfg_type)
	local uci = require "luci.model.uci".cursor()
	local x = uci:get_all(cfg)
	if x and index then
		for k,v in pairs(x) do
			if v.index == index and v.name then
				return v.name
			end
		end
	end
	return ""
end
function get_name_by_cfgtype_id(cfg_type,index)
	local cfg = {SIPP="endpoint_sipphone",SIPT="endpoint_siptrunk",FXS="endpoint_fxso",FXO="endpoint_fxso",FXSO="endpoint_fxso",GSM="endpoint_mobile",CDMA="endpoint_mobile",RING="endpoint_ringgroup",ROUTE="endpoint_routegroup",IVR="ivr"}
	if cfg[cfg_type] and index then
		if "FXS" == cfg_type or "FXO" == cfg_type or "GSM" == cfg_type or "CDMA" == cfg_type then
			return cfg_type
		else
			return get_name_by_index(cfg[cfg_type],index,cfg_type)
		end
	end
	return "*"
end

function routegroup()
	local MAX_ROUTE_GRP = 32
	local uci = require "luci.model.uci".cursor()
	local freeswitch = require "luci.scripts.fs_server"
	local ds = require "luci.dispatcher"
	local i18n = require "luci.i18n"

	uci:check_cfg("endpoint_routegroup")
	uci:check_cfg("endpoint_siptrunk")
	uci:check_cfg("endpoint_sipphone")
	uci:check_cfg("endpoint_fxso")
	uci:check_cfg("endpoint_mobile")
	uci:check_cfg("route")

	local freeswitch = require "luci.scripts.fs_server"

	local del_target = luci.http.formvaluetable("Delete")
	if next(del_target) then
		uci:delete_section(del_target,"route.endpoint")
	end

	if luci.http.formvalue("New") then
		local created = uci:section("endpoint_routegroup","group")
		uci:save("endpoint_routegroup")
		luci.http.redirect(ds.build_url("admin","callcontrol","routegroup","routegroup",created,"add"))
		return
	end

	local th = {"Index","Name","Members","Strategy"}
	local colgroup = {"5%","10%","56%","20%","7%"}
	local content = {}
	local edit = {}
	local delchk = {}
	local uci_cfg = {}
	local addnewable = true
	local cnt = 0
	local routegrp = uci:get_all("endpoint_routegroup")
	for i=1,MAX_ROUTE_GRP do
		for k,v in pairs(routegrp) do
			if v.index and v.name and i == tonumber(v.index) then
				cnt = cnt + 1
				local td = {}
				td[1] = v.index
				td[2] = v.name
				td[3] = {}
				for _,v in ipairs(v.members_select) do
					local vtype,index,port="","",""
					if v:match("^SIPP") or v:match("^SIPT") or v:match("^GSM") or v:match("^CDMA") then
						vtype,index = v:match("^(%u+)%-(%d+)")
					else
						vtype,index,port = v:match("^(%u+)%-(%d+)(/%d)")
					end
					if vtype == "SIPP" then
						v = tostring(i18n.translate("SIP Extension")).."-< "..get_name_by_cfgtype_id(vtype,index).." >"..port
					elseif vtype == "SIPT" then
						v = tostring(i18n.translate("SIP Trunk")).."-< "..get_name_by_cfgtype_id(vtype,index).." >"..port
					elseif vtype == "FXS" then
						v = tostring(i18n.translate("FXS Extension"))
					elseif vtype == "FXO" then
						v = tostring(i18n.translate("FXO Trunk"))
					elseif vtype == "GSM" then
						v = tostring(i18n.translate("GSM Trunk"))
					elseif vtype == "CDMA" then
						v = tostring(i18n.translate("CDMA Trunk"))
					end
					table.insert(td[3],v)
				end

				td[4] = i18n.translate(v.strategy or "")

				edit[cnt] = ds.build_url("admin","callcontrol","routegroup","routegroup",k,"edit")
				delchk[cnt] = uci:check_cfg_deps("endpoint_routegroup",k,"route.endpoint")
				uci_cfg[cnt] = "endpoint_routegroup." .. k
				table.insert(content,td)
				break
			elseif not v.index or not v.name then
				uci:delete("endpoint_routegroup",k)
				--uci:save("endpoint_routegroup")
			end
		end
	end
	if MAX_ROUTE_GRP == cnt then
		addnewable = false
	end
	luci.template.render("cbi/configlist",{
		title = i18n.translate("Call Control / Route Group"),
		colgroup = colgroup,
		split_col = 4,
		classname = "paddingtight",
		th = th,
		content = content,
		edit = edit,
		delchk = delchk,
		uci_cfg = uci_cfg,
		addnewable = addnewable,
		})
end

function route()
	local MAX_ROUTE = 32
	local uci = require "luci.model.uci".cursor()
	local ds = require "luci.dispatcher"
	local i18n = require "luci.i18n"

	uci:check_cfg("route")
	uci:check_cfg("endpoint_siptrunk")
	uci:check_cfg("endpoint_sipphone")
	uci:check_cfg("endpoint_fxso")
	uci:check_cfg("endpoint_mobile")
	uci:check_cfg("endpoint_ringgroup")
	uci:check_cfg("endpoint_routegroup")
	uci:check_cfg("profile_time")
	uci:check_cfg("profile_number")
	uci:check_cfg("profile_manipl")
	
	local del_target = luci.http.formvaluetable("Delete")
	if next(del_target) then
		uci:delete_section(del_target)
	end

	if luci.http.formvalue("New") then
		local created = uci:section("route","route")
		uci:save("route")
		luci.http.redirect(ds.build_url("admin","callcontrol","route","route",created,"add"))
		return
	end

	local th= {"Priority","Name","Source","Num Profile","Caller Prefix","Called Prefix","Time Profile","Action: Manipulation/Dest","Failover: Manipulation/Dest"}
	local colgroup = {"6%","10%","10%","8%","8%","8%","8%","18","18","6%"}
	
	local content = {}
	local edit = {}
	local delchk = {}
	local uci_cfg = {}
	local more_info = {}
	local addnewable = true
	local cnt = 0
	local route = uci:get_all("route")
	for i=1,MAX_ROUTE do
		for k,v in pairs(route) do
			if v.index and i == tonumber(v.index) then
				cnt = cnt + 1
				local td = {}
				td[1] = v.index
				td[2] = v.name or "Error"
				
				--Condition: Source/Number/Time--
				local Source = i18n.translate("Any")
				local caller_prefix = v.caller_num_prefix or i18n.translate("Any")
				local called_prefix = v.called_num_prefix or i18n.translate("Any")
				local Number = i18n.translate("Off")
				local Time = i18n.translate("Off")
				local profile_name = ""

				if v.from and "0" ~= v.from and "-1" ~= v.from then
					Source = v.from
					local stype,index = Source:match("(%w+)%-(%d+)")
					if stype == "FXS" or stype == "FXO" then
						Source = stype
					else
						Source = get_name_by_cfgtype_id(stype,index)
						Source = "" ~= Source and Source or "Error"
					end
				elseif "-1" == v.from then
					if v.custom_from and "table" == type(v.custom_from) then
						for k,v in pairs(v.custom_from) do
							Source = tostring(i18n.translate("Custom"))
						end
					end
				end

				if v.numberProfile and "0" ~= v.numberProfile then
					profile_name = get_name_by_index("profile_number",v.numberProfile)
					if "" ~= profile_name then
						Number =  v.numberProfile.."-< "..profile_name.." >"
					else
						Number = "Error"
					end
				end

				if v.timeProfile and "0" ~= v.timeProfile then
					profile_name = get_name_by_index("profile_time",v.timeProfile)
					if "" ~= profile_name then
						Time =  v.timeProfile.."-< "..profile_name.." >"
					else
						Time = "Error"
					end
				end

				--td[3] = Source.."/"..Number.."/"..Time
				td[3] = Source
				td[4] = Number
				td[5] = caller_prefix
				td[6] = called_prefix
				td[7] = Time
				--Condition: Source/Number/Time  End--

				--Succ Action: Manipulation/Dest--
				local mapl = i18n.translate("Off")
				local dest = "*"

				profile_name = get_name_by_index("profile_manipl",v.successNumberManipulation)
				if "" ~= profile_name then
					mapl =  profile_name
				end

				if v.successDestination then
					dest =  v.successDestination
					local dtype,index = dest:match("(%w+)%-(%d+)")
					if dtype == "FXS" or dtype == "FXO" then
						dest = dtype
					elseif dtype == "Hangup" then
						dest = string.gsub(dtype,"Hangup",tostring(i18n.translate("Hangup")))
					elseif dtype == "Extension" then
						dest = string.gsub(dtype,"Extension",tostring(i18n.translate("Local Extension")))
					elseif dest == "IVR" then
						dest = "IVR"
					else
						dest = get_name_by_cfgtype_id(dtype,index)
					end
				end
				if "" ~= dest then
					td[8] =  mapl.."/"..dest
				else
					td[8] = "Error"
				end
				--Succ Action: Manipulation/Dest End--

				--Callfail Action: Manipulation/New Dest--

				if v.failDestination then
					mapl = i18n.translate("Off")
					dest = "*"

					profile_name = get_name_by_index("profile_manipl",v.failNumberManipulation)
					if "" ~= profile_name then
						mapl =  profile_name
					end

					dest =  v.failDestination
					local dtype,index = dest:match("(%w+)%-(%d+)")
					if dtype == "FXS" or dtype == "FXO" then
						dest= dtype
					elseif dtype == "IVR" then
						dest = "IVR"
					else
						dest= get_name_by_cfgtype_id(dtype,index)
					end
					td[9] =  mapl.."/"..dest
					if "" ~= dest then
						td[9] =  mapl.."/"..dest
					else
						td[9] = "Error"
					end
				else
					td[9] = i18n.translate("Not Config")
				end

				--Callfail Action: Manipulation/Dest End--
				more_info[cnt] = ""
				if "-1" == v.from then
					more_info[cnt] = more_info[cnt]..i18n.translate("Custom Source")..":<br>"
					for i,j in pairs(v.custom_from) do
						more_info[cnt] = more_info[cnt].."&nbsp;&nbsp;&nbsp;&nbsp;"..uci.get_custom_source(j).."<br>"
					end
				end
				if v.failoverflag == "1" then
					more_info[cnt] = more_info[cnt]..i18n.translate("Failover Action")..":"..i18n.translate("On").."<br>"
					if v.failCondition then
						local translate_str
						if v.failCondition:match("Timeout") then
							translate_str = i18n.translate("Timeout")
						end
						if v.failCondition:match("Busy") then
							translate_str = translate_str and (translate_str.." / "..i18n.translate("Busy")) or i18n.translate("Busy")
						end
						if v.failCondition:match("Unavailable") then
							translate_str = translate_str and (translate_str.." / "..i18n.translate("Unavailable")) or i18n.translate("Unavailable")
						end
						more_info[cnt] = more_info[cnt].."&nbsp;&nbsp;&nbsp;&nbsp"..i18n.translate("Condition")..":"..translate_str.."<br>"
					end
					if v.failCondition and v.failCondition:match("Timeout") and v.timeout then
						more_info[cnt] = more_info[cnt].."&nbsp;&nbsp;&nbsp;&nbsp"..i18n.translate("Timeout Len(s)")..":"..v.timeout.."<br>"
					end
					if v.causecode then
						more_info[cnt] = more_info[cnt].."&nbsp;&nbsp;&nbsp;&nbsp"..i18n.translate("Other Condition Code")..":"..v.causecode.."<br>"
					end
				end
				edit[cnt] = ds.build_url("admin","callcontrol","route","route",k,"edit")
				delchk[cnt] = ""
				uci_cfg[cnt] = "route." .. k
				table.insert(content,td)
				break
			elseif not v.index or not v.name then
				uci:delete("route",k)
				--uci:save("route")
			end
		end
	end
	if MAX_ROUTE == cnt then
		addnewable = false
	end
	luci.template.render("cbi/configlist",{
		title = i18n.translate("Call Control / Route"),
		colgroup = colgroup,
		th = th,
		content = content,
		more_info = more_info,
		edit = edit,
		delchk = delchk,
		uci_cfg = uci_cfg,
		addnewable = addnewable,
		})
end

function featurecode()
	local MAX_FEATURE_CODE = 32
	local uci = require "luci.model.uci".cursor()
	local ds = require "luci.dispatcher"
	local i18n = require "luci.i18n"
	local enable_flg
	
	uci:check_cfg("feature_code")

	local del_target = luci.http.formvaluetable("Delete")
	if next(del_target) then
		for k,v in pairs(del_target) do
			local cfg, section = k:match("([a-z_]+)%.(%w+).x")
			if cfg and section then
				uci:set(cfg,section,"status","Disabled")
				uci:save(cfg)
			end
		end
	end

	local enable_target = luci.http.formvaluetable("Enable")
	if next(enable_target) then
		for k,v in pairs(enable_target) do
			local cfg, section = k:match("([a-z_]+)%.(%w+).x")
			if cfg and section then
				uci:set(cfg,section,"status","Enabled")
				uci:save(cfg)
			end
		end
	end
	
	if "save" == luci.http.formvalue("action") then
		enabled_flag = luci.http.formvalue("feature.enabled") or "0"
		uci:set("callcontrol","voice","featurecode",enabled_flag)
		uci:save("callcontrol")
	end

	enable_flag = uci:get("callcontrol","voice","featurecode") or "1"
	
	local th = {"Index","Feature","Key","Description","Status"}
	local colgroup = {"5%","26%","12%","44%","7%","7%"}
	local content = {}
	local edit = {}
	local delchk = {}
	local delvalue = {}
	local status ={}
	local cnt = 1
	local feature_code = uci:get_all("feature_code")
	for i=1,MAX_FEATURE_CODE do
		for k,v in pairs(feature_code) do
			if v.index and v.name and i == tonumber(v.index) then
				local td = {}
				td[1] = v.index
				td[2] = i18n.translate(v.name)
				td[3] = v.code
				td[4] = i18n.translate(v.description)
				td[5] = i18n.translate(v.status)

				edit[cnt] = ds.build_url("admin","callcontrol","featureCode","featureCode",k,"edit")
				status[cnt] = v.status
				delvalue[cnt] = "feature_code." .. k
				table.insert(content,td)
				cnt = cnt + 1
				break
			elseif not v.index or not v.name then
				uci:delete("feature_code",k)
			end
		end
	end

	luci.template.render("admin_callcontrol/featurecode",{
		title = i18n.translate("Call Control / Feature Code"),
		colgroup = colgroup,
		split_col = 6,
		classname = "paddingleft",
		th = th,
		content = content,
		enable = enable_flag,
		edit = edit,
		delchk = delchk,
		delvalue = delvalue,
		addnewable = false,
		deltype = "stop",
		status = status,
		})
end

function action_sendmsg()
	local freeswitch = require "luci.scripts.fs_server"
	local endpoint = luci.http.formvalue("endpoint") or ""
	local number = luci.http.formvalue("number") or ""
	local msginfo = luci.http.formvalue("msginfo") or ""

	--local number_list = luci.util.split(number,"|")
	
	local msg_info = {}
	
	--for k,v in ipairs(number_list) do
	local current_time = os.date("%Y-%m-%d %H:%M:%S")--for DATETIME datatype
	
	--replace '\n' to '\1', because '\n' can not send using fs api ascii 1:SOH(start of headline) 
	msginfo=string.gsub(msginfo, "\n", "\1");
	msginfo=string.gsub(msginfo, "\\", "\\\\");
	msginfo=string.gsub(msginfo, "'", "\\'");
	local cmd = "gsm sendsms "..endpoint.." '"..current_time.."' "..number.." '"..msginfo.."'"
	local str = freeswitch.message(cmd)
	--end
	
	luci.http.prepare_content("application/json")
	luci.http.write_json(msg_info)

	return
end

function action_deletemsg()
	local freeswitch = require "luci.scripts.fs_server"
	local endpoint = luci.http.formvalue("endpoint")
	local direction = luci.http.formvalue("direction") 
	local contact = luci.http.formvalue("contact") 
	local date = luci.http.formvalue("date")
	local msg_info = {}
	
	if direction == "recvfrom" then
		direction = "sms_recv"
	elseif direction == "sendto" then
		direction = "sms_sendover"
	end

	local cmd = "gsm deletesms "..direction.." '"..date.."' "..endpoint.." "..contact
	local str = freeswitch.message(cmd)

	luci.http.prepare_content("application/json")
	luci.http.write_json(msg_info)

	return
end

function action_readmsg()
	local freeswitch = require "luci.scripts.fs_server"
	local endpoint = luci.http.formvalue("endpoint")
	local contact = luci.http.formvalue("contact") 
	local date = luci.http.formvalue("date")
	local status = luci.http.formvalue("status")
	
	local msg_info = {}
	
	local cmd = "gsm updatesms '"..date.."' "..endpoint.." "..contact.." "..status
	local str = freeswitch.message(cmd)

	
	luci.http.prepare_content("application/json")
	luci.http.write_json(msg_info)

	return
end

function action_emptymsg()
	local freeswitch = require "luci.scripts.fs_server"
	local db_name = luci.http.formvalue("db_name")
	local msg_info = {}
	local cmd = ""
	
	if db_name == "empty_send" then
		cmd = "gsm deletesms sms_sendover all"
	else
		cmd = "gsm deletesms sms_recv all"
	end
	 
	local str = freeswitch.message(cmd)

	
	luci.http.prepare_content("application/json")
	luci.http.write_json(msg_info)

	return
end
function action_exportmsg()
	local fs  = require "luci.fs"
	local sys = require "luci.sys"
	local sqlite = require "luci.scripts.sqlite3_service"
	local bit32  = nixio.bit

	local tmp_info = ""
	local tmp_file = "/tmp/SMS"
	local localip = luci.http.getenv("SERVER_ADDR")
	local ret_tb = {}
	local db_table_name = luci.http.formvalue("export_type") == "export_send" and "sms_sendover" or "sms_recv"
	local file_name = db_table_name == "sms_sendover" and "Send" or "Recv"
	
	ret_tb = sqlite.sqlite3_execute("/etc/freeswitch/sms","select contact,date,smsinfo,status from "..db_table_name.." order by date")

	--write into file
	local _file = io.open("/tmp/SMS.xls","w+")
	if _file then
		local title_flag = true
		
		for k,v in pairs(ret_tb) do
			tmp_info = ""
			if title_flag then
				for k2,v2 in pairs(v) do
					tmp_info = tmp_info..k2.."\t"
				end
				title_flag = false
				_file:write(tmp_info.."\r\n")
			end
			tmp_info = ""
			for k2,v2 in pairs(v) do
				if string.find(v2,"\n") then
					tmp_info = tmp_info.."\""..v2.."\"\t"
				else
					tmp_info = tmp_info..v2.."\t"
				end
			end
			_file:write(tmp_info.."\r\n")
		end
		
		_file:close()
	end

	sys.call("tar -cz /tmp/SMS.xls -f "..tmp_file)
	local reader = luci.ltn12.source.file(io.open(tmp_file,"r"))
	luci.http.header('Content-Disposition', 'attachment; filename="Message%s-%s-%s-%s.tar.gz"' % {
		file_name,luci.sys.hostname(), localip, os.date("%Y-%m-%d")})
	luci.http.prepare_content("application/gzip")
	luci.ltn12.pump.all(reader, luci.http.write)
	fs.unlink(tmp_file)	
	fs.unlink("/tmp/SMS.xls")
end

function action_ussd_get()
	local freeswitch = require "luci.scripts.fs_server"
	local sqlite = require "luci.scripts.sqlite3_service"
	local unfinished_recv,direction_tmp,ussdinfo_tmp
	local info_send_msg={}
	local refresh=0
	local flag=0
	local num=0
	local enable_quit=0

	local gsm_status = 0
	local gsm_check = freeswitch.message()
	for k,v in pairs(gsm_check) do
		if v.name and v.type and v.slot == "1" then
			gsm_status = 1
		end
	end

	unfinished_recv = sqlite.sqlite3_execute("/etc/freeswitch/sms","select * from (select * from ussd order by ussd_index desc limit 5) order by  ussd_index")
	num = #unfinished_recv
	if num >=5 then
		num = 5
	end

	for i,j in ipairs(unfinished_recv) do
		direction_tmp=nil
		ussdinfo_tmp=nil
		info_send_msg[i]={}
		if j.result == "Fail" then
			info_send_msg[i].result = "Fail"
		end
	
		for k,v in pairs(j) do
			if tostring(k):match("direction") then
				direction_tmp = v
				if ussdinfo_tmp then
					if tostring(v):match("send") then
						info_send_msg[i].send = ussdinfo_tmp
					elseif tostring(v):match("recv") then
						info_send_msg[i].recv = ussdinfo_tmp
					end
				end
			end
			if tostring(k):match("ussdinfo") then
				ussdinfo_tmp = string.gsub(v,"\r","")
				ussdinfo_tmp = string.gsub(ussdinfo_tmp,"\n","<br/>")
				if direction_tmp then
					if tostring(direction_tmp):match("send") then
						info_send_msg[i].send = ussdinfo_tmp
					elseif tostring(direction_tmp):match("recv") then
						info_send_msg[i].recv = ussdinfo_tmp
					end
				end
			end
			if tostring(k):match("date") then
				info_send_msg[i].date = v
			end
			if i == num then
				if tostring(k):match("direction") and tostring(v):match("send") then
					flag = 1
				end  
				if tostring(k):match("ussdinfo") and not tostring(v):match("Cancel Session") then
					refresh=1
				end
				if tostring(k):match("direction") and tostring(v):match("recv") then 
					enable_quit=1
				end
			end
		end
	end
	
	if flag == 1 and refresh == 1 then
		refresh=1
	else
		refresh=0
	end	

	luci.template.render("admin_callcontrol/ussd",{refresh=refresh,info_send_msg=info_send_msg,enable_quit=enable_quit,gsm_status=gsm_status,num=num})
end

function action_sendussd()
	local freeswitch = require "luci.scripts.fs_server"
	local sqlite = require "luci.scripts.sqlite3_service"
	local request_info = luci.http.formvalue("request_info") or ""
	local encode = luci.http.formvalue("encode") or ""
	local cmd_send = luci.http.formvalue("cmd_send") or ""
	local msg_info={}
	local ussd_message
	local index=1
	local flag=0
	
	local gsm_status = freeswitch.message()
	for k,v in pairs(gsm_status) do
		if v.name and v.type and v.slot == "1" then
			flag = 1
		end
	end
	
	if flag == 1 then
		if tonumber(cmd_send) == 0 then
			local cmd = "gsm sendussd 1 send "..request_info
			if encode == "AUTO" then
				cmd = cmd.." 0"
			elseif encode == "ASSIC" then
				cmd = cmd.." 1"
			elseif encode == "UCS2" then
				cmd = cmd.." 2"
			end
			local str = freeswitch.message(cmd)
			os.execute("sleep 1")

			if tostring(str):match(".*%+OK, ussd ok.*") then
				msg_info.result = "OK!"
			else
				msg_info.result = tostring(str)
			end
		else
			msg_info.result = "OK!"
		end
		
		while true do
			ussd_message = sqlite.sqlite3_execute("/etc/freeswitch/sms","select * from ussd where date>=(select max(date) from ussd where direction='send')")
			for i,j in pairs(ussd_message) do
				if j.direction == "send" then
					msg_info.sendtime = j.date
				end

				if j.direction == "recv" then
					for k,v in pairs(j) do
						if tostring(k):match("date") then
							msg_info.date = v
						end
						if tostring(k):match("ussdinfo") then
							msg_info.ussdinfo = v
						end
					end
				end
			end 
			os.execute("sleep 1")
			index = index+1
			if msg_info.date and msg_info.ussdinfo and msg_info.sendtime or index == 60 then
				break
			end
		end
	end
	
	luci.http.prepare_content("application/json")
	luci.http.write_json(msg_info)
end

function action_quitussd()
	local freeswitch = require "luci.scripts.fs_server"
	local sqlite = require "luci.scripts.sqlite3_service"
	local msg_info={}
	local ussd_message
	local cmd = "gsm sendussd 1 stop"
	local num =1
	local flag=0
	
	local time = os.date("%Y-%m-%d %H:%M:%S",os.time())
	os.execute("echo ".."time: "..time.." >> /tmp/lobin")
	local gsm_status = freeswitch.message()
	for k,v in pairs(gsm_status) do
		if v.name and v.type and v.slot == "1" then
			flag = 1  
		end
	end
	os.execute("sleep 1")
	if flag ==1 then
		local str = freeswitch.message(cmd)
		os.execute("sleep 1")
		while true do
			ussd_message = sqlite.sqlite3_execute("/etc/freeswitch/sms","select * from ussd order by date desc limit 1")  
			for i,j in pairs(ussd_message) do
				if j.date and tostring(j.date)>=tostring(time) then
					msg_info.date = j.date
				end
			end
			os.execute("sleep 1")
			num = num+1
			if msg_info.date or num == 30 then
				break
			end
		end
		if tostring(str):match(".*%+OK, ussd ok.*") then
			msg_info.result = "Quit Success!"
		else
			msg_info.result = tostring(str)
		end
	end

	luci.http.prepare_content("application/json")
	luci.http.write_json(msg_info)
end
