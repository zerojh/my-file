module("luci.controller.admin.trunk",package.seeall)

function index()
	if luci.http.getenv("SERVER_PORT") == 8345 or luci.http.getenv("SERVER_PORT") == 8848 then
		local page
		page = node("admin","trunk")
		page.target = firstchild()
		page.title = _("Trunk")
		page.order = 72
		page.index = true
		entry({"admin","trunk","sip"},call("sip"),"SIP",1)
		entry({"admin","trunk","sip","sip"},cbi("admin_trunk/siptrunk_edit"),nil,1).leaf = true
		if luci.version.license and luci.version.license.fxo then
			entry({"admin","trunk","fxo"},alias("admin","trunk","fxo","trunk"),"FXO",2)
			entry({"admin","trunk","fxo","trunk"},call("fxo"), "FXO",2)
			entry({"admin","trunk","fxo","fxo"},cbi("admin_trunk/fxo_edit"),nil,2).leaf = true
			entry({"admin","trunk","fxo","slic"},cbi("admin_trunk/slic"),_("Automatch Impedance"),8).leaf=true
		end
		if luci.version.license and luci.version.license.gsm then
			entry({"admin","trunk","mobile"},call("mobile"), "GSM",3)
			entry({"admin","trunk","mobile","mobile"},cbi("admin_trunk/mobile_edit"),nil,3).leaf = true
		end
		entry({"admin", "trunk", "carrier_list"}, call("action_carrier_list"))
	end
end

function action_carrier_list()
	local fs = require "luci.scripts.fs_server"
	local carrier_list = fs.carrier_list() or {}

	local cfg = luci.http.formvalue("cfg")
	if cfg then
		local uci = require "luci.model.uci".cursor()
		cfg = cfg:match("endpoint_mobile%.(.+)%.carrier")
		local carrier = {}
		for k,v in ipairs(carrier_list) do
			table.insert(carrier,v.name)
		end

		uci:set("endpoint_mobile",cfg,"carrier_list",carrier)
		uci:save("endpoint_mobile")
	end

	luci.http.prepare_content("application/json")
	luci.http.write_json(carrier_list)
end

function sip()
	local MAX_SIP_ENDPOINT = 32
	local uci = require "luci.model.uci".cursor()
	local ds = require "luci.dispatcher"
	local i18n = require "luci.i18n"

	uci:check_cfg("profile_sip")
	uci:check_cfg("profile_codec")
	uci:check_cfg("endpoint_siptrunk")
	uci:check_cfg("endpoint_sipphone")
	uci:check_cfg("endpoint_routegroup")
	uci:check_cfg("endpoint_ringgroup")
	uci:check_cfg("route")

	local status_target = luci.http.formvaluetable("Status")
	if next(status_target) then
		for k,v in pairs(status_target) do
			local state,cfg,section = k:match("([A-Za-z]+)%.([a-zA-Z_]+)%.(%w+)%.x")
			if cfg and section and state then
				uci:set(cfg,section,"status",state == "Enabled" and "Enabled" or "Disabled")
				uci:save(cfg)
			end
		end
	end

	local del_target = luci.http.formvaluetable("Delete")
	if next(del_target) then
		uci:delete_section(del_target,"route.endpoint")
	end

	if luci.http.formvalue("New") then
		local created = uci:section("endpoint_siptrunk","sip")
		uci:save("endpoint_siptrunk")
		luci.http.redirect(ds.build_url("admin","trunk","sip","sip",created,"add"))
		return
	end

	local th = {"Index","Name","Realm","Transport","Heartbeat","Register","SIP Profile","Status"}
	local colgroup = {"7%","10%","21%","10%","10%","10%","15%","8%","9%"}
	local content = {}
	local edit = {}
	local status = {}
	local delchk = {}
	local uci_cfg = {}
	local more_info = {}
	local addnewable = true
	local cnt = 0
	local endpoint = uci:get_all("endpoint_siptrunk")
	local profile = uci:get_all("profile_sip")
	for i=1,MAX_SIP_ENDPOINT do
		for k,v in pairs(endpoint) do
			if v.index and i == tonumber(v.index) then
				cnt = cnt + 1
				local tmp = {}
				tmp[1] = v.index
				tmp[2] = v.name or "Error"
				tmp[3] = v.ipv4 and (v.ipv4 .. ":" .. (v.port or "5060")) or "Error"
				tmp[4] = i18n.translate(v.transport or "")
				if v.heartbeat and "on" == v.heartbeat then
					tmp[5] = v.ping or ""
				else
					tmp[5] = i18n.translate("Off")
				end
				tmp[6] = i18n.translate((v.register == "on") and "On" or "Off")
				tmp[7] = ""
				for x,y in pairs(profile) do
					if y.index and y.name and v.profile and y.index == v.profile then
						tmp[7] = v.profile .. "-< " .. y.name .. " >"
					end
				end
				tmp[7] = "" ~= tmp[7] and tmp[7] or "Error"
				tmp[8] = i18n.translate(v.status or "")

				more_info[cnt] = ""
				if v.outboundproxy or v.outboundproxy_port then
					more_info[cnt] = more_info[cnt]..i18n.translate("Outbound Proxy")..":"..(v.outboundproxy or v.ipv4 or "")..":"..(v.outboundproxy_port or v.port or 5060).."<br>"
				end
				if v.register == "on" then
					if more_info[cnt] == nil or more_info[cnt] == "" then
						more_info[cnt] = ""
					end
					if v.username then
						more_info[cnt] = more_info[cnt]..i18n.translate("Username")..":"..v.username.."<br>"
					end
					more_info[cnt] = more_info[cnt]..i18n.translate("Auth Username")..":"..(v.auth_username or v.username or "").."<br>"
					more_info[cnt] = more_info[cnt]..i18n.translate("From Header Username")..":"..(v.from_username == "username" and i18n.translate("Username") or i18n.translate("Caller")).."<br>"
					more_info[cnt] = more_info[cnt]..i18n.translate("Expire Seconds")..":"..(v.expire_seconds or "1800").."<br>"
					more_info[cnt] = more_info[cnt]..i18n.translate("Retry Seconds")..":"..(v.retry_seconds or "60").."<br>"
				end
				edit[cnt] = ds.build_url("admin","trunk","sip","sip",k,"edit")
				status[cnt] = v.status or "Disabled"
				delchk[cnt] = uci:check_cfg_deps("endpoint_siptrunk",k,"route.endpoint")
				uci_cfg[cnt] = "endpoint_siptrunk." .. k
				table.insert(content,tmp)
				break
			elseif not v.index or not v.name then
				uci:delete("endpoint_siptrunk",k)
			end
		end
	end
	if MAX_SIP_ENDPOINT == cnt then
		addnewable = false
	end
	luci.template.render("cbi/configlist",{
		title = i18n.translate("Trunk / SIP"),
		colgroup = colgroup,
		th = th,
		content = content,
		more_info = more_info,
		edit = edit,
		status = status,
		delchk = delchk,
		uci_cfg = uci_cfg,
		addnewable = addnewable,
		})
end
	
function fxo()
	local MAX_FXO_TRUNK = 12
	local uci = require "luci.model.uci".cursor()
	local freeswitch = require "luci.scripts.fs_server"
	local ds = require "luci.dispatcher"
	local i18n = require "luci.i18n"

	uci:check_cfg("profile_fxso")
	uci:check_cfg("endpoint_fxso")
	uci:check_cfg("endpoint_routegroup")
	uci:check_cfg("route")

	--@ Enable/Disable
	local status_target = luci.http.formvaluetable("Status")
	for k,v in pairs(status_target) do
		local state,cfg,section = k:match("([A-Za-z]+)%.([a-zA-Z_]+)%.(%w+)%.x")
		if cfg and section and state then
			uci:set(cfg,section,"status",state == "Enabled" and "Enabled" or "Disabled")
			uci:save(cfg)
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
		"Global impedance"
		}

	local th = {"Extension","Autodial Num","Register to SIP Server","Input Gain","Output Gain","Impedance","Profile","Status"}
	local colgroup = {"10%","10%","15%","10%","10%","15%","13%","10%","7%"}
	local content = {}
	local edit = {}
	local delchk = {}
	local uci_cfg = {}
	local more_info = {}
	local status = {}
	local addnewable = true
	local cnt = 0
	local endpoint = uci:get_all("endpoint_fxso")
	local profile = uci:get_all("profile_fxso")

	local from_field_v = {["0"] = "Caller ID / Caller ID",["1"] = "Display Name / Caller ID",["2"] = "Extension / Caller ID",["3"] = "Caller ID / Extension",["4"] = "Anonymous"}
	local from_field_un_v = {["0"]="Display Name / Extension",["1"]="Anonymous"}

	for i=1,MAX_FXO_TRUNK do
		for k,v in pairs(endpoint) do
			if v.index and v.name and "fxo" == v['.type'] and i == tonumber(v.index) then
				cnt = cnt + 1
				local tmp = {}
				tmp[1] = v.number_2 or ""
				tmp[2] = v.autodial_2 or ""
				tmp[3] = i18n.translate((("on" == v.port_2_reg and "On" or "Off")))
				tmp[4] = v.dsp_input_gain_2.."dB" or "0dB"
				tmp[5] = v.dsp_output_gain_2.."dB" or "0dB"
				tmp[6] = slic_tb[tonumber((v.slic_2 and v.slic_2:match("^%d+$")) and v.slic_2 or 0)+1]
				tmp[7] = ""
				for x,y in pairs(profile) do
					if y.index and y.name and v.profile and y.index == v.profile then
						tmp[7] = v.profile .. "-< " .. y.name .. " >"
					end
				end
				tmp[7] = "" ~= tmp[7] and tmp[7] or "Error"
				tmp[8] = i18n.translate(v.status or "")
				if "on" == v.port_2_reg and (v.port_2_server_1 or v.port_2_server_2 or v.authuser_2) then
					more_info[cnt] = ""
					if v.port_2_server_1 == "0" then
						more_info[cnt] = more_info[cnt]..i18n.translate("Master Server")..": "..i18n.translate("Not Config").."<br>"
					end
					if v.port_2_server_1 ~= "0" or v.port_2_server_2 ~= "0" then
						if v.port_2_server_1 ~= "0" then
							more_info[cnt] = more_info[cnt]..i18n.translate("Master Server")..": "..uci.get_siptrunk_server(v.port_2_server_1).."<br>"
						end
						if v.port_2_server_2 ~= "0"  then
							more_info[cnt] = more_info[cnt]..i18n.translate("Slave Server")..": "..uci.get_siptrunk_server(v.port_2_server_2).."<br>"
						end
					end
					if v.port_2_server_2 == "0" then
						more_info[cnt] = more_info[cnt]..i18n.translate("Slave Server")..":"..i18n.translate("Not Config").."<br>"
					end
					more_info[cnt] = more_info[cnt]..i18n.translate("Username")..": "..(v.username_2 or v.number_2 or "").."<br>"
					more_info[cnt] = more_info[cnt]..i18n.translate("Auth Username")..": "..(v.authuser_2 or v.username_2 or v.number_2 or "").."<br>"
					more_info[cnt] = more_info[cnt]..i18n.translate("From Header Username")..": "..i18n.translate(v.from_username_2 == "caller" and "Caller" or "Username").."<br>"
					more_info[cnt] = more_info[cnt]..i18n.translate("Specify Transport Protocol on Register URL")..": "..(i18n.translate(v.reg_url_with_transport_2 == "on" and "On" or "Off")).."<br>"
					more_info[cnt] = more_info[cnt]..i18n.translate("Expire Seconds")..": "..(v.expire_seconds_2 or "1800").."<br>"
					more_info[cnt] = more_info[cnt]..i18n.translate("Retry Seconds")..": "..(v.retry_seconds_2 or "60").."<br>"
					more_info[cnt] = more_info[cnt]..i18n.translate("Display Name / Username Format")..": "..i18n.translate(from_field_v[v.sip_from_field_2] or from_field_v["0"]).."<br>"
					more_info[cnt] = more_info[cnt]..i18n.translate("Display Name / Username Format when CID unavailable")..": "..i18n.translate(from_field_un_v[v.sip_from_field_un_2] or from_field_un_v["0"]).."<br>"

				end
				status[cnt] = v.status
				edit[cnt] = ds.build_url("admin","trunk","fxo","fxo",k,"edit")
				delchk[cnt] = uci:check_cfg_deps("endpoint_fxso",k,"route.endpoint")
				uci_cfg[cnt] = "endpoint_fxso." .. k
				table.insert(content,tmp)
				break
			end
		end
	end
	luci.template.render("cbi/configlist",{
		colgroup = colgroup,
		th = th,
		content = content,
		more_info = more_info,
		edit = edit,
		delchk = delchk,
		uci_cfg = uci_cfg,
		addnewable = false,
		status = status,
		undelable = true,
		})
end

function action_slic()
	local fs_server = require "luci.scripts.fs_server"
	local uci = require "luci.model.uci".cursor()
	local ds = require "luci.dispatcher"

	if luci.http.formvalue("status") == "1" then
		local fxo_info = luci.http.formvalue("fxo")
		local dtmf_str = luci.http.formvalue("dtmf") or "1234567890123456789"
		local ret_str = "Fail"
		local slot,port = fxo_info:match("FXO%-([0-9]+)%-([0-9]+)")
	
		if slot and port then
			local cmd = "ftdm driver fxso acim_automatch start "..slot.." "..port.." "..dtmf_str
	
			local tmp = fs_server.fxo_detection_slic(cmd)

			if tmp and tmp:match("+OK") then
				--@ success done
				ret_str = "Success"
			else
				ret_str = luci.i18n.translate("Failed,Please check your fxo outbound line")
			end
		end
		
		luci.http.prepare_content("text/plain")
		luci.http.write(ret_str)
	elseif luci.http.formvalue("status") == "2" then
		local fxo_info = luci.http.formvalue("fxo")
		local ret_tb = {}
		local slot,port = fxo_info:match("FXO%-([0-9]+)%-([0-9]+)")
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
						"Global impedance"
					}
		if slot and port then
			local cmd = "ftdm driver fxso acim_automatch query "..slot.." "..port

			local ret_str = fs_server.fxo_detection_slic(cmd)

			if ret_str then
				if ret_str:match("currentstep:%-1") or ret_str:match("acim_automatch failed") then
				--@ ¼ì²âÊ§°Ü
					ret_tb.status = "Failed"
				elseif ret_str:match("hybrid:") and ret_str:match("currentstep") then
				--@ ¼ì²âÍê³É
					local im,hybrid = ret_str:match("im:([0-9]+), hybrid:([0-9]+)")
					ret_tb.status = "Complete"
					ret_tb.percent = "100%"
					ret_tb.slic = im.."-"..hybrid
					ret_tb.slic_show = slic_tb[tonumber(im)+1]
					
				elseif ret_str:match("currentstep") then
				--@ ¼ì²âÖÐ
					local current,total = ret_str:match("currentstep:([0-9]+), totalstep:([0-9]+)")
					
					ret_tb.status = "Detecting"
					ret_tb.percent = string.gsub(string.sub(tostring(tonumber(current)/tonumber(total)*100),1,2),"%.","").."%"
				else
					ret_tb.status = "Never"
				end
			end
		end
		
		luci.http.prepare_content("application/json")
		luci.http.write_json(ret_tb)
	else
		luci.http.redirect(ds.build_url("admin","trunk","slic","slic"))
	end
end

function mobile()
	local MAX_MOBILE_TRUNK = 12
	local ds = require "luci.dispatcher"
	local uci = require "luci.model.uci".cursor()
	local freeswitch = require "luci.scripts.fs_server"
	local i18n = require "luci.i18n"

	uci:check_cfg("endpoint_mobile")
	uci:check_cfg("profile_mobile")
	uci:check_cfg("route")
	uci:check_cfg("endpoint_routegroup")
	uci:check_cfg("profile_numberlearning")
	
	--@ Enable/Disable
	local status_target = luci.http.formvaluetable("Status")
	for k,v in pairs(status_target) do
		local state,cfg,section = k:match("([A-Za-z]+)%.([a-zA-Z_]+)%.(%w+)%.x")
		if cfg and section and state then
			uci:set(cfg,section,"status",state == "Enabled" and "Enabled" or "Disabled")
			uci:save(cfg)
		end
	end

	local speedtype = {"Auto","FR","HR","EFR","AMR_FR","AMR_HR","FR & EFR","EFR & FR","EFR & HR","EFR & ARM_FR","AMR_FR & FR","AMR_FR & HR","AMR_FR & EFR","AMR_HR & FR","AMR_HR & HR","AMR_HR & EFR"}
	local bandtype = {"All","GSM 900","GSM 1800","GSM 1900","GSM 900 & GSM 1800","GSM 850 & GSM 1900"}

	local th = {"Extension","Autodial Number","Register to SIP Server","GSM Codec","Band Type","Carrier","Input Gain","Output Gain","Status"}
	local colgroup = {"10%","12%","15%","10%","10%","10%","9%","9%","8%","7%"}
	local content = {}
	local edit = {}
	local delchk = {}
	local uci_cfg = {}
	local more_info = {}
	local status = {}
	local addnewable = true
	local cnt = 0
	local endpoint = uci:get_all("endpoint_mobile") or {}
	local numberlearning = uci:get_all("profile_numberlearning") or {}

	local from_field_v = {["0"]="Extension / Caller ID",["1"]="Extension / Extension",["2"]="Caller ID / Caller ID",["3"]="Caller ID / Extension",["4"]="Anonymous"}
	local from_field_un_v = {["0"]="Extension / Extension",["1"]="Anonymous"}
    local clir_v = {["0"]="Auto",["1"]="On",["2"]="Off"}

	for i=1,MAX_MOBILE_TRUNK do
		for k,v in pairs(endpoint) do
			if v.index and v.name and i == tonumber(v.index) then
				cnt = cnt + 1
				local tmp = {}
				tmp[1] = (v.number or "")
				tmp[2] = (v.autodial or "")
				tmp[3] = i18n.translate((("on" == v.port_reg and "On" or "Off")))
				tmp[4] = i18n.translate((speedtype[tonumber(v.gsmspeedtype or 0)+1] or "Auto"))
				tmp[5] = i18n.translate((bandtype[tonumber(v.bandtype or 0)+1] or "All"))
				tmp[6] = i18n.translate((v.carrier or "Auto"))
				tmp[7] = (v.dsp_input_gain or "0").."dB"
				tmp[8] = (v.dsp_output_gain or "0").."dB"
				tmp[9] = i18n.translate(v.status or "")
				more_info[cnt] = ""
				if "on" == v.port_reg and (v.port_server_1 or v.port_server_2 or v.authuser)then
					if v.port_server_1 == "0" then
						more_info[cnt] = more_info[cnt]..i18n.translate("Master Server")..":"..i18n.translate("Not Config").."<br>"
					end
					if v.port_server_1 ~= "0" or v.port_server_2 ~= "0" then
						if v.port_1_server_1 ~= "0" then
							more_info[cnt] = more_info[cnt]..i18n.translate("Master Server")..":"..uci.get_siptrunk_server(v.port_server_1).."<br>"
						end
						if v.port_1_server_2 ~= "0" then
							more_info[cnt] = more_info[cnt]..i18n.translate("Slave Server")..":"..uci.get_siptrunk_server(v.port_server_2).."<br>"
						end
					end
					if v.port_server_2 == "0" then
						more_info[cnt] = more_info[cnt]..i18n.translate("Slave Server")..":"..i18n.translate("Not Config").."<br>"
					end
					more_info[cnt] = more_info[cnt]..i18n.translate("Username")..":"..(v.username or v.number or "").."<br>"
					more_info[cnt] = more_info[cnt]..i18n.translate("Auth Username")..":"..(v.authuser or v.username or v.number or "").."<br>"
					more_info[cnt] = more_info[cnt]..i18n.translate("From Header Username")..": "..i18n.translate(v.from_username == "caller" and "Caller" or "Username").."<br>"
					more_info[cnt] = more_info[cnt]..i18n.translate("Specify Transport Protocol on Register URL")..": "..(i18n.translate(v.reg_url_with_transport == "on" and "On" or "Off")).."<br>"
					more_info[cnt] = more_info[cnt]..i18n.translate("Expire Seconds")..": "..(v.expire_seconds or "1800").."<br>"
					more_info[cnt] = more_info[cnt]..i18n.translate("Retry Seconds")..": "..(v.retry_seconds or "60").."<br>"
					--more_info[cnt] = more_info[cnt]..i18n.translate("From Username")..":"..(v.from_username == "username" and i18n.translate("Username") or i18n.translate("Caller")).."<br>"
				end
				more_info[cnt] = more_info[cnt]..i18n.translate("Reactive when register fail")..":"..(v.reg_fail_reactive == "true" and i18n.translate("On") or i18n.translate("Off")).."<br>"
				more_info[cnt] = more_info[cnt]..i18n.translate("SMS Encoding")..":"..(v.at_sms_encoding or "ucs2").."<br>"
				more_info[cnt] = more_info[cnt]..i18n.translate("SMS Center Number")..":"..(v.at_smsc_number or i18n.translate("Not Config")).."<br>"
				more_info[cnt] = more_info[cnt]..i18n.translate("CLIR")..":"..i18n.translate(clir_v[v.hide_callernumber] or clir_v["0"]).."<br>"
				more_info[cnt] = more_info[cnt]..i18n.translate("PIN Code")..":"..(v.pincode or i18n.translate("Not Config")).."<br>"
				more_info[cnt] = more_info[cnt]..i18n.translate("Display Name / Username Format")..":"..i18n.translate(from_field_v[v.sip_from_field_2] or from_field_v["2"]).."<br>"
				more_info[cnt] = more_info[cnt]..i18n.translate("Display Name / Username Format when CID unavailable")..":"..i18n.translate(from_field_un_v[v.sip_from_field_un_2] or from_field_un_v["0"]).."<br>"
				if v.numberlearning_profile and "0" ~= v.numberlearning_profile then
					for x,y in pairs(numberlearning) do
						if y.index == v.numberlearning_profile then
							more_info[cnt] = more_info[cnt]..i18n.translate("SIM Number Learning Profile")..":"..(y.index .. "-< " .. y.name .. " >").."<br>"
							break
						end
					end
				else
					more_info[cnt] = more_info[cnt]..i18n.translate("SIM Number Learning Profile")..":"..i18n.translate("Off").."<br>"
				end
				status[cnt] = v.status
				edit[cnt] = ds.build_url("admin","trunk","mobile","mobile",k,"edit")
				delchk[cnt] = uci:check_cfg_deps("endpoint_mobile",k,"route.endpoint")
				uci_cfg[cnt] = "endpoint_mobile." .. k
				table.insert(content,tmp)
				break
			end
		end
	end

	luci.template.render("cbi/configlist",{
		title = i18n.translate("Trunk / GSM"),
		colgroup = colgroup,
		th = th,
		content = content,
		more_info = more_info,
		edit = edit,
		delchk = delchk,
		uci_cfg = uci_cfg,
		addnewable = false,
		status = status,
		undelable = true,
		})
end
