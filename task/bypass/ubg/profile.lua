module("luci.controller.admin.profile",package.seeall)

function index()
	local page
	page = node("admin","profile")
	page.target = firstchild()
	page.title = _("VoIP Config")
	page.order = 60
	page.index = true

	--# SIP->profile / extension / trunk
	entry({"admin","profile","sip"},alias("admin","profile","sip","extension"),_("SIP"),1)
	entry({"admin","profile","sip","extension"},call("action_sip_extension"),"SIP Extension",1)
	entry({"admin","profile","sip","extension","edit"},cbi("admin_profile/sip_extension_edit"),nil,1).leaf = true
	entry({"admin","profile","sip","batchnew"},call("sip_batch_new"),nil,1).leaf = true
	entry({"admin","profile","sip","trunk"},call("action_sip_trunk"),"SIP Trunk",2)
	entry({"admin","profile","sip","trunk","edit"},cbi("admin_profile/sip_trunk_edit"),nil,2).leaf = true
	entry({"admin","profile","sip","profile"},call("action_sip_profile"),"SIP Profile",3)
	entry({"admin","profile","sip","profile","edit"},cbi("admin_profile/sip_profile_edit"),nil,3).leaf = true

	--# FXS->profile / extension
	entry({"admin","profile","fxs"},alias("admin","profile","fxs","extension"),"FXS",4)
	entry({"admin","profile","fxs","extension"},call("action_fxs_extension"),_("FXS Extension"),4)
	entry({"admin","profile","fxs","extension","edit"},cbi("admin_profile/fxs_extension_edit"),nil,4).leaf = true
	entry({"admin","profile","fxs","profile"},call("action_fxs_profile"),_("FXS Profile"),5)
	entry({"admin","profile","fxs","profile","edit"},cbi("admin_profile/fxs_profile_edit"),nil,5).leaf = true

	--# FXO->profile / trunk
	if luci.version.fxo then --#check fxo license
		entry({"admin","profile","fxo"},alias("admin","profile","fxo","trunk"),"FXO",6)
		entry({"admin","profile","fxo","trunk"},call("action_fxo_trunk"),_("FXO Trunk"),6)
		entry({"admin","profile","fxo","trunk","edit"},cbi("admin_profile/fxo_trunk_edit"),nil,6).leaf = true
		entry({"admin","profile","fxo","profile"},call("action_fxo_profile"),_("FXO Profile"),7)
		entry({"admin","profile","fxo","profile","edit"},cbi("admin_profile/fxo_profile_edit"),nil,7).leaf = true
	  	entry({"admin","profile","fxo","slic"}, cbi("admin_profile/slic"),_("Automatch Impedance"), 8).leaf = true
	end

	entry({"admin","profile","ringgroup"},call("action_ringgroup"), _("Ring Group"),9)
	entry({"admin","profile","ringgroup","ringgroup"},cbi("admin_profile/ringgroup_edit"),nil,10).leaf = true

	entry({"admin","profile","routegroup"},call("action_routegroup"),"Route Group",10)
	entry({"admin","profile","routegroup","routegroup"},cbi("admin_profile/routegroup_edit"),nil,10).leaf = true

	entry({"admin","profile","codec"},call("action_codec"),"Codec",11)
	entry({"admin","profile","codec","codec"},cbi("admin_profile/codec_edit"),nil,11).leaf = true
	entry({"admin","profile","number"},call("action_number"),"Number Profile",12)
	entry({"admin","profile","number","number"},cbi("admin_profile/number_edit"),nil,12).leaf = true
	entry({"admin","profile","time"},call("action_time"),"Time Profile",13)
	entry({"admin","profile","time","time"},cbi("admin_profile/time_edit"),nil,13).leaf = true
	entry({"admin","profile","dialplan"},call("action_dialplan"),"Dialplan Profile",14)
	entry({"admin","profile","dialplan","dialplan"},cbi("admin_profile/dialplan_edit"),nil,14).leaf = true
	entry({"admin","profile","manipl"},call("action_manipulation"),"Manipulation",15)
	entry({"admin","profile","manipl","manipl"},cbi("admin_profile/manipulation_edit"),nil,15).leaf = true
end
function action_sip_profile()
	local uci = require "luci.model.uci".cursor()
	local ds = require "luci.dispatcher"
	local i18n = require "luci.i18n"
	local MAX_SIP_PROFILE = tonumber(uci:get("profile_param","global","max_sip_profile") or '8')
	
	uci:check_cfg("profile_sip")
	uci:check_cfg("profile_codec")
	uci:check_cfg("endpoint_siptrunk")

	local del_target = luci.http.formvaluetable("Delete")
	if del_target then
		uci:delete_section(del_target,"endpoint_siptrunk.profile")
	end

	if luci.http.formvalue("New") then
		local created = uci:section("profile_sip","sip")
		uci:save("profile_sip")
		luci.http.redirect(ds.build_url("admin","profile","sip","profile","edit",created,"add"))
		return
	end
	local dscp={["0"]="CS0",["8"]="CS1",["10"]="AF11",["12"]="AF12",["14"]="AF13",["16"]="CS2",["18"]="AF21",["20"]="AF22",["22"]="AF23",["24"]="CS3",["26"]="AF31",["28"]="AF32",["30"]="AF33",["32"]="CS4",["34"]="AF41",["36"]="AF42",["38"]="AF43",["40"]="CS5",["46"]="EF",["48"]="CS6",["56"]="CS7"}

	local th = {"Index","Name","Interface","Listening Port","DTMF","Session Timeout","Codec Priority","Incodec Profile","Outcodec Profile"}
	local colgroup = {"5%","10%","6%","12%","11%","10%","11%","14%","14%","7%"}
	local content = {}
	local edit = {}
	local delchk = {}
	local uci_cfg = {}
	local more_info = {}
	local addnewable = true
	local cnt = 0
	local profile = uci:get_all("profile_sip")
	local codec = uci:get_all("profile_codec")
	for i=1,MAX_SIP_PROFILE do
		for k,v in pairs(profile) do
			if v.index and v.name then
				if i == tonumber(v.index) then
					cnt = cnt + 1
					local td = {}
					td[1] = v.index
					td[2] = v.name
					
					td[3] = ""

					if v.localinterface then
						if v.localinterface == "wan" or v.localinterface == "lan" then
							td[3] = string.upper(v.localinterface)
						elseif v.localinterface == "wan2" then
							td[3] = "LTE"
						elseif v.localinterface:match("^vlan") then
							td[3] = v.localinterface
						elseif v.localinterface:match("^vwan") then
							td[3] = uci:get("network",v.localinterface,"name") or ""
						else
							td[3] = v.localinterface
						end
					end
					
					td[4] = v.localport or ""
					if v.rfc2833_pt and v.dtmf and "rfc2833" == v.dtmf then
						td[5] = "RFC2833/"..v.rfc2833_pt
					elseif v.dtmf and "info" == v.dtmf then
						td[5] = "SIP INFO"
					elseif v.dtmf and "inband" == v.dtmf then
						td[5] = "Inband"
					else
						td[5] = ""
					end
					
					td[6] = v.session_timeout or i18n.translate("Off")
					
					if v.inbound_codec_negotiation and "generous" == v.inbound_codec_negotiation then
						td[7] = i18n.translate("Remote")
					elseif v.inbound_codec_negotiation and "greedy" == v.inbound_codec_negotiation then
						td[7] = i18n.translate("Local")
					elseif v.inbound_codec_negotiation and "scrooge" == v.inbound_codec_negotiation then
						td[7] = i18n.translate("Local Force")
					else
						td[7] = ""
					end

					td[8] = ""
					for x,y in pairs(codec) do
						if y.index and y.name and y.index == v.inbound_codec_prefs then
							td[8] = y.index.."-< "..y.name.." >"
							break
						end
					end

					td[9] = ""
					for x,y in pairs(codec) do
						if y.index and y.name and y.index == v.outbound_codec_prefs then
							td[9] = y.index.."-< "..y.name.." >"
							break
						end
					end
					local nat = ("auto-nat" == v.ext_sip_ip and "uPNP / NAT-PMP") or ("ip" == v.ext_sip_ip and i18n.translate("IP Address")) or ("stun" == v.ext_sip_ip and "Stun") or ("host" == v.ext_sip_ip and "Host") or i18n.translate("Off")
					more_info[cnt] = i18n.translate("NAT")..": "..nat
					if "off" ~= v.ext_sip_ip and "auto-nat" ~= v.ext_sip_ip and v.ext_sip_ip_more then	
						more_info[cnt] = more_info[cnt].."->"..v.ext_sip_ip_more.."<br>"
					else
						more_info[cnt] = more_info[cnt].."<br>"
					end
					more_info[cnt] = more_info[cnt]..i18n.translate("PRACK")..": "..(v.prack == "on" and i18n.translate("On") or i18n.translate("Off")).."<br>"
					more_info[cnt] = more_info[cnt]..i18n.translate("Bypass Media(SIP to SIP)")..":"..("on" == v.bypass_media and i18n.translate("On") or i18n.translate("Off")).."<br>"
					more_info[cnt] = more_info[cnt]..i18n.translate("Detect Extension is Online")..": "..("on" == v.heartbeat and i18n.translate("On") or i18n.translate("Off")).."<br>"
					if "on" == v.heartbeat and v.ping then
						more_info[cnt] = more_info[cnt].."&nbsp;&nbsp;&nbsp;&nbsp;"..i18n.translate("Detect Period(s)")..": "..v.ping.."<br>"
					end
					more_info[cnt] = more_info[cnt]..i18n.translate("Allow Unknown Call")..": "..(v.allow_unknown_call == "on" and i18n.translate("On") or i18n.translate("Off")).."<br>"
					more_info[cnt] = more_info[cnt]..i18n.translate("Inbound Source Filter")..": "..((not v.auth_acl or "0.0.0.0" == v.auth_acl or "0.0.0.0/0" == v.auth_acl or "0.0.0.0/0.0.0.0" == v.auth_acl ) and i18n.translate("All") or v.auth_acl).."<br>"
					more_info[cnt] = more_info[cnt].."QoS: "..("on" == v.qos and i18n.translate("On") or i18n.translate("Off")).."<br>"
					if "on" == v.qos then
						more_info[cnt] = more_info[cnt].."&nbsp;&nbsp;&nbsp;&nbsp;"..i18n.translate("SIP Message DSCP Value")..": "..(dscp[v.dscp_sip or "46"] or dscp["46"]).." / "..(dscp[v.dscp_sip] and v.dscp_sip or 46).."<br>"
						more_info[cnt] = more_info[cnt].."&nbsp;&nbsp;&nbsp;&nbsp;"..i18n.translate("RTP DSCP Value")..": "..(dscp[v.dscp_rtp or "46"] or dscp["46"]).." / "..(dscp[v.dscp_rtp] and v.dscp_rtp or 46).."<br>"
					end
					edit[cnt] = ds.build_url("admin","profile","sip","profile","edit",k,"edit")
					delchk[cnt] = uci:check_cfg_deps("profile_sip",k,"endpoint_siptrunk.profile endpoint_sipphone.profile")
					uci_cfg[cnt] = "profile_sip." .. k
					table.insert(content,td)
				end
			else
				--uci:delete("profile_sip",k)
				--uci:save("profile_sip")
			end
		end
	end
	if MAX_SIP_PROFILE == cnt then
		addnewable = false
	end
	luci.template.render("cbi/configlist",{
		th = th,
		colgroup = colgroup,
		content = content,
		more_info = more_info,
		edit = edit,
		delchk = delchk,
		uci_cfg = uci_cfg,
		addnewable = addnewable,
		})
end
function get_all_exist_extension()
	local uci = require "luci.model.uci".cursor()
	local str=""
	local cnt=0

	for k,v in pairs(uci:get_all("endpoint_sipphone") or {}) do
		if v.user then
			str = str..v.user.."&"
			cnt=cnt+1
		end
	end
	for k,v in pairs(uci:get_all("endpoint_fxso") or {}) do
		str = str..(v.number_1 and (v.number_1.."&") or "")
		str = str..(v.number_2 and (v.number_2.."&") or "")
	end
	for k,v in pairs(uci:get_all("endpoint_mobile") or {}) do
		str = str..(v.number and (v.number.."&") or "")
	end
	for k,v in pairs(uci:get_all("endpoint_ringgroup") or {}) do
		str = str..(v.number and (v.number.."&") or "")
	end
	return str,32-cnt
end

function sip_batch_new()
	local uci = require "luci.model.uci".cursor()
	local ds = require "luci.dispatcher"
	if luci.http.formvalue("save") then
		local bn=luci.http.formvaluetable("batch")
		local idx_t={}
		for k,v in pairs(uci:get_all("endpoint_sipphone") or {}) do
			if v.index then
				idx_t[v.index]=true
			end
		end
		local idx=0
		-- Save leading zeros and length of extension.
		local zero_prefix = bn.extension:match("^([0]*)")
		local len_extension = bn.extension:len()
		local start_ex=tonumber(bn.extension)
		local cnt=tonumber(bn.ex_cnt)
		local step=tonumber(bn.step)
		for i=1,cnt do
			idx=idx+1
			while idx_t[tostring(idx)] do
				idx=idx+1
			end
			local tmp={}
			tmp.index=idx
			tmp.user=start_ex+step*(i-1)
			if zero_prefix then
				local diff = len_extension - tostring(tmp.user):len()
				if diff > 0 then
					local i
					for i = 1, diff do
						tmp.user = "0" .. tmp.user
					end
				end
			end
			tmp.name=tmp.user
			if "on"==bn.did then
				tmp.did=tmp.user
			end
			if "same" == bn.pwd_policy then
				tmp.password=bn.pwd
			elseif "same_with_extension" == bn.pwd_policy then
				tmp.password=tmp.user
			elseif "prefix_extension" == bn.pwd_policy then
				tmp.password=bn.pwd_prefix..tmp.user
			elseif "extension_suffix" == bn.pwd_policy then
				tmp.password=tmp.user..bn.pwd_suffix
			elseif "prefix_extension_suffix" == bn.pwd_policy then
				tmp.password=bn.pwd_prefix..tmp.user..bn.pwd_suffix
			end
			tmp.from=bn.regsrc
			tmp.ip=bn.regsrv_val
			tmp.waiting=bn.waiting
			tmp.notdisturb=bn.notdisturb
			tmp.forward_uncondition="Deactivate"
			tmp.forward_busy="Deactivate"
			tmp.forward_noreply="Deactivate"
			tmp.nat=bn.nat
			tmp.profile=bn.profile
			tmp.status=bn.status
			uci:section("endpoint_sipphone","sip",nil,tmp)
			uci:save("endpoint_sipphone")
		end
		luci.http.redirect(ds.build_url("admin","profile","sip"))
	elseif luci.http.formvalue("cancel") then
		luci.http.redirect(ds.build_url("admin","profile","sip"))
	else
		local exist_extension,max_cnt=get_all_exist_extension()
		luci.template.render("admin_profile/batchnew",{
			max_cnt=((max_cnt>=0) and max_cnt or 0),
			exist_extension=exist_extension,
		})
	end
end

function action_sip_extension()
	local uci = require "luci.model.uci".cursor()
	local ds = require "luci.dispatcher"
	local i18n = require "luci.i18n"
	local MAX_SIP_EXTENSION = tonumber(uci:get("profile_param","global","max_sip_extension") or '32')
	
	uci:check_cfg("profile_sip")
	uci:check_cfg("endpoint_sipphone")
	uci:check_cfg("endpoint_ringgroup")
	uci:check_cfg("route")
	local siptrunk_cfg = uci:get_all("endpoint_siptrunk") or {}

	--@ Delete
	local del_target = luci.http.formvaluetable("Delete")
	if del_target then
		uci:delete_section(del_target,"route.endpoint")
	end

	--@ New
	if luci.http.formvalue("New") then
		local created = uci:section("endpoint_sipphone","sip")
		uci:save("endpoint_sipphone")
		luci.http.redirect(ds.build_url("admin","profile","sip","extension","edit",created,"add"))
		return
	end

	--@ Enable/Disable
	local status_target = luci.http.formvaluetable("Status")
	if status_target and "table" == type(status_target) then
		for k,v in pairs(status_target) do
			local state,cfg,section = k:match("([A-Za-z]+)%.([a-zA-Z_]+)%.(%w+).x")
			if cfg and section and state then
				uci:set(cfg,section,"status",state == "Enabled" and "Enabled" or "Disabled")
				uci:save(cfg)
			end
		end
	end
	
	local th = {"Index","Name","Extension","DID","Password Auth","Register Source","Profile","Status"}
	local colgroup = {"7%","13%","9%","15%","12%","13%","13%","8%","10%"}
	local content = {}
	local edit = {}
	local delchk = {}
	local uci_cfg = {}
	local status = {}
	local more_info = {}
	local addnewable = true
	local cnt = 0
	local endpoint = uci:get_all("endpoint_sipphone")
	local profile = uci:get_all("profile_sip")
	for i=1,MAX_SIP_EXTENSION do
		for k,v in pairs(endpoint) do
			if v.index and v.name and i == tonumber(v.index) then
				cnt = cnt + 1
				local tmp = {}
				tmp[1] = v.index
				tmp[2] = v.name
				tmp[3] = v.user or ""
				tmp[4] = v.did or ""
				if v.password and "" ~= v.password then
					tmp[5] = i18n.translate("On")
				else
					tmp[5] = i18n.translate("Off")
				end
				if v.from and "specified" == v.from then
					tmp[6] = v.ip or ""
				else
					tmp[6] = i18n.translate("Any")
				end
				tmp[7] = ""
				for x,y in pairs(profile) do
					if y.index and y.name and v.profile and y.index == v.profile then
						tmp[7] = v.profile .. "-< " .. y.name .. " >"
					end
				end
				tmp[8] = i18n.translate(v.status or "")
				edit[cnt] = ds.build_url("admin","profile","sip","extension","edit",k,"edit")
				delchk[cnt] = uci:check_cfg_deps("endpoint_sipphone",k,"route.endpoint")
				uci_cfg[cnt] = "endpoint_sipphone." .. k
				more_info[cnt] = i18n.translate("Call Waiting")..": "..((v.waiting and "Activate" == v.waiting) and i18n.translate("On") or i18n.translate("Off")).."<br>"
				more_info[cnt] = more_info[cnt]..i18n.translate("Do Not Disturb")..": "..("Activate" == v.notdisturb and i18n.translate("On") or i18n.translate("Off")).."<br>"
				more_info[cnt] = more_info[cnt]..i18n.translate("Call Forward Unconditional")..": "..((v.forward_uncondition and "Deactivate" ~= v.forward_uncondition) and uci.get_destination_detail(v.forward_uncondition,v.forward_uncondition_dst) or i18n.translate("Off")).."<br>"
				more_info[cnt] = more_info[cnt]..i18n.translate("Call Forward Busy")..": "..((v.forward_busy and "Deactivate" ~= v.forward_busy) and uci.get_destination_detail(v.forward_busy,v.forward_busy_dst) or i18n.translate("Off")).."<br>"
				more_info[cnt] = more_info[cnt]..i18n.translate("Call Forward No Reply")..": "..((v.forward_noreply and "Deactivate" ~= v.forward_noreply) and (uci.get_destination_detail(v.forward_noreply,v.forward_noreply_dst).." / "..v.forward_noreply_timeout) or i18n.translate("Off")).."<br>"
				more_info[cnt] = more_info[cnt]..i18n.translate("NAT").." : "..((v.nat and "on" == v.nat) and i18n.translate("On") or i18n.translate("Off")).."<br>"
				status[cnt] = v.status
				table.insert(content,tmp)
	 		else
	 			--uci:delete("endpoint_sipphone",k)
				--uci:save("endpoint_sipphone")
	 		end
	 	end
	 end
	if MAX_SIP_EXTENSION == cnt then
		addnewable = false
	end
	luci.template.render("cbi/configlist",{
		colgroup = colgroup,
		th = th,
		content = content,
		edit = edit,
		delchk = delchk,
		uci_cfg = uci_cfg,
		status = status,
		more_info = more_info,
		addnewable = addnewable,
		batchnew=ds.build_url("admin","profile","sip","batchnew"),
		})
end

function action_sip_trunk()
	local uci = require "luci.model.uci".cursor()
	local ds = require "luci.dispatcher"
	local i18n = require "luci.i18n"
	local MAX_SIP_ENDPOINT = tonumber(uci:get("profile_param","global","max_sip_trunk") or '32')
	
	uci:check_cfg("profile_sip")
	uci:check_cfg("profile_codec")
	uci:check_cfg("endpoint_siptrunk")
	uci:check_cfg("endpoint_sipphone")
	uci:check_cfg("endpoint_ringgroup")
	uci:check_cfg("endpoint_routegroup")
	uci:check_cfg("route")

	local del_target = luci.http.formvaluetable("Delete")
	if del_target then
		uci:delete_section(del_target,"route.endpoint")
	end

	if luci.http.formvalue("New") then
		local created = uci:section("endpoint_siptrunk","sip")
		uci:save("endpoint_siptrunk")
		luci.http.redirect(ds.build_url("admin","profile","sip","trunk","edit",created,"add"))
		return
	end
	
	--@ Enable/Disable
	local status_target = luci.http.formvaluetable("Status")
	if status_target and "table" == type(status_target) then
		for k,v in pairs(status_target) do
			local state,cfg,section = k:match("([A-Za-z]+)%.([a-zA-Z_]+)%.(%w+).x")
			if cfg and section and state then
				uci:set(cfg,section,"status",state == "Enabled" and "Enabled" or "Disabled")
				uci:save(cfg)
			end
		end
	end
	
	local th = {"Index","Name","Realm","Transport","Heartbeat","Register","SIP Profile","Status"}
	local colgroup = {"7%","14%","20%","7%","10%","9%","15%","8%","10%"}
	local content = {}
	local edit = {}
	local delchk = {}
	local uci_cfg = {}
	local more_info = {}
	local status = {}
	local addnewable = true
	local cnt = 0
	local endpoint = uci:get_all("endpoint_siptrunk")
	local profile = uci:get_all("profile_sip")
	for i=1,MAX_SIP_ENDPOINT do
		for k,v in pairs(endpoint) do
			if v.index and v.name and i == tonumber(v.index) then
				cnt = cnt + 1
				local tmp = {}
				tmp[1] = v.index
				tmp[2] = v.name
				tmp[3] = (v.ipv4 or "") .. ":" .. (v.port or "")
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
				tmp[8] = i18n.translate(v.status or "")
				more_info[cnt] = ""
				if v.outboundproxy or v.outboundproxy_port then
					more_info[cnt] = more_info[cnt]..i18n.translate("Outbound Proxy")..": "..(v.outboundproxy or v.ipv4 or "")..": "..(v.outboundproxy_port or v.port or 5060).."<br>"
				end
				if v.register == "on" then
					if more_info[cnt] == nil or more_info[cnt] == "" then
						more_info[cnt] = ""
					end
					if v.username then
						more_info[cnt] = more_info[cnt]..i18n.translate("Username")..": "..v.username.."<br>"
					end
					if v.auth_username then
						more_info[cnt] = more_info[cnt]..i18n.translate("Auth Username")..": "..i18n.translate(v.auth_username).."<br>"
					end
					more_info[cnt] = more_info[cnt]..i18n.translate("From Header Username")..": "..(v.from_username == "username" and i18n.translate("Username") or i18n.translate("Caller")).."<br>"
					more_info[cnt] = more_info[cnt]..i18n.translate("Expire Seconds")..": "..(v.expire_seconds or "1800").."<br>"
					more_info[cnt] = more_info[cnt]..i18n.translate("Retry Seconds")..": "..(v.retry_seconds or "60").."<br>"
				end
				edit[cnt] = ds.build_url("admin","profile","sip","trunk","edit",k,"edit")
				delchk[cnt] = uci:check_cfg_deps("endpoint_siptrunk",k,"route.endpoint")
				uci_cfg[cnt] = "endpoint_siptrunk." .. k
				status[cnt] = v.status
				table.insert(content,tmp)
	 		else
	 			--uci:delete("endpoint_siptrunk",k)
	 			--uci:save("endpoint_siptrunk")
	 		end
	 	end
	 end
	if MAX_SIP_ENDPOINT == cnt then
		addnewable = false
	end
	luci.template.render("cbi/configlist",{
		colgroup = colgroup,
		th = th,
		content = content,
		more_info = more_info,
		edit = edit,
		delchk = delchk,
		uci_cfg = uci_cfg,
		status = status,
		addnewable = addnewable,
		})
end

function action_fxs_profile()
	local uci = require "luci.model.uci".cursor()
	local ds = require "luci.dispatcher"
	local i18n = require "luci.i18n"
	local MAX_FXS_PROFILE = 12
	local slic_tb = {"600 Ohm","900 Ohm","600 Ohm + 1uF","900 Ohm + 2.16uF","270 Ohm + (750 Ohm || 150nF)","220 Ohm + (820 Ohm || 120 nF)","220 Ohm + (820 Ohm || 115 nF)","220 Ohm + (680 Ohm || 100 nF)"}

	uci:check_cfg("profile_fxso")
	uci:check_cfg("profile_dialplan")

	local del_target = luci.http.formvaluetable("Delete")
	if del_target then
		uci:delete_section(del_target,"endpoint_fxso.profile")
	end

	if luci.http.formvalue("New") then
		local created = uci:section("profile_fxso","fxs")
		uci:save("profile_fxso")
		luci.http.redirect(ds.build_url("admin","profile","fxs","profile","edit",created,"add"))
		return
	end

	local th = {"Index","Name","Tone Group","Digit Timeout(s)","Dial Timeout(s)","Ring Timeout(s)","No Answer Timeout(s)"}
	local colgroup = {"6%","10%","12%","15%","15%","15%","20%","7%"}
	local content = {}
	local edit = {}
	local delchk = {}
	local uci_cfg = {}
	local more_info = {}
	local addnewable = true
	local cnt = 0
	local profile = uci:get_all("profile_fxso")
	local dialplan = uci:get_all("profile_dialplan")

	for i=1,MAX_FXS_PROFILE do
		for k,v in pairs(profile) do
			if v['.type'] == "fxs" and v.index and v.name and i == tonumber(v.index) then
				cnt = cnt + 1
				local td = {}
				td[1] = v.index
				td[2] = v.name
				td[3] = i18n.translate(translatetone(v.tonegrp))
				td[4] = v.digit or ""
				td[5] = v.dialTimeout or ""
				td[6] = v.ringtimeout or ""
				td[7] = v.noanswer or ""
				more_info[cnt] = ""
				if v.flash_flag then
					more_info[cnt] = more_info[cnt]..i18n.translate("Flash Detection")..": "..(v.flash_flag == "1" and i18n.translate("On")).."<br>"
					more_info[cnt] = more_info[cnt].."&nbsp;&nbsp;&nbsp;&nbsp;"..i18n.translate("Min Time (ms)")..": "..v.flash_min_time.."<br>"
					more_info[cnt] = more_info[cnt].."&nbsp;&nbsp;&nbsp;&nbsp;"..i18n.translate("Max Time (ms)")..": "..v.flash_max_time.."<br>"
				end
				more_info[cnt] = more_info[cnt]..i18n.translate("DTMF Parameters").."<br>"
				more_info[cnt] = more_info[cnt].."&nbsp;&nbsp;&nbsp;&nbsp;"..i18n.translate("DTMF Send Interval(ms)")..": "..(v.dtmf_sendinterval or "200").."<br>"
				more_info[cnt] = more_info[cnt].."&nbsp;&nbsp;&nbsp;&nbsp;"..i18n.translate("DTMF Duration(ms)")..": "..(v.dtmf_duration or "200").."<br>"
				more_info[cnt] = more_info[cnt].."&nbsp;&nbsp;&nbsp;&nbsp;"..i18n.translate("DTMF Gain")..": "..(v.dtmf_gain or "-6").."dB".."<br>"
				more_info[cnt] = more_info[cnt].."&nbsp;&nbsp;&nbsp;&nbsp;"..i18n.translate("DTMF Detect Threshold")..": "..(v.dtmf_detect_threshold or "-30").."dB".."<br>"
				more_info[cnt] = more_info[cnt].."&nbsp;&nbsp;&nbsp;&nbsp;"..i18n.translate("DTMF Terminator")..": "..(v.dtmf_end_char == "none" and i18n.translate("None") or v.dtmf_end_char).."<br>"
				more_info[cnt] = more_info[cnt].."&nbsp;&nbsp;&nbsp;&nbsp;"..i18n.translate("Send DTMF Terminator")..": "..(v.send_dtmf_end_char == "on" and i18n.translate("On") or i18n.translate("Off")).."<br>"
				more_info[cnt] = more_info[cnt]..i18n.translate("Send DTMF Terminator")..": "..(v.cid_send_mode:match("^FSK$") and "FSK-BEL202" or v.cid_send_mode).."<br>"
				if v.message_mode then
					more_info[cnt] = more_info[cnt].."&nbsp;&nbsp;&nbsp;&nbsp;"..i18n.translate("Message Mode")..": "..v.message_mode.."<br>"
				end
				if v.message_format then
					local message_format = (v.message_format == "0" and i18n.translate("Display Name and CID")) or (v.message_format == "1" and i18n.translate("Only CID")) or (v.message_format == "2" and i18n.translate("Only Display Name"))
					more_info[cnt] = more_info[cnt].."&nbsp;&nbsp;&nbsp;&nbsp;"..i18n.translate("Message Format")..": "..message_format.."<br>"
				end
				if v.send_cid_before and v.send_cid_before == "0" then
					more_info[cnt] = more_info[cnt].."&nbsp;&nbsp;&nbsp;&nbsp;"..i18n.translate("CID Send Timing")..": "..i18n.translate("Send After RING").."<br>"
					more_info[cnt] = more_info[cnt].."&nbsp;&nbsp;&nbsp;&nbsp;"..i18n.translate("Delay Timeout After Ring(ms)")..": "..(v.send_cid_delay or "2000").."<br>"
				elseif v.send_cid_before and v.send_cid_before == "1" then
					more_info[cnt] = more_info[cnt].."&nbsp;&nbsp;&nbsp;&nbsp;"..i18n.translate("CID Send Timing")..": "..i18n.translate("Send Before RING").."<br>"
				end
				more_info[cnt] = more_info[cnt]..i18n.translate("Impedance")..": "..slic_tb[v.slic+1].."<br>"
				more_info[cnt] = more_info[cnt]..i18n.translate("Send Polarity Reverse")..": "..(v.polarity_reverse == "off" and i18n.translate("Off") or i18n.translate("On")).."<br>"
				if not v.flashhook_dtmf or "0" == v.flashhook_dtmf then
					more_info[cnt] = more_info[cnt]..i18n.translate("Send Flash Hook via SIP INFO / RFC2833")..": "..i18n.translate("Off").."<br>"
				else
					more_info[cnt] = more_info[cnt]..i18n.translate("Send Flash Hook via SIP INFO / RFC2833")..": "..(v.flashhook_dtmf == "A" and "A(12)" or v.flashhook_dtmf == "B" and "B(13)" or v.flashhook_dtmf == "C" and "C(14)" or v.flashhook_dtmf == "D" and "D(15)" or v.flashhook_dtmf == "F" and "F(16)" or v.flashhook_dtmf).."<br>"
				end
				more_info[cnt] = more_info[cnt]..i18n.translate("Offhook Current Detect Threshold")..":"..(v.offhook_current_threshold or "12")..i18n.translate("mA").."<br>"
				more_info[cnt] = more_info[cnt]..i18n.translate("Onhook Current Detect Threshold")..":"..(v.onhook_current_threshold or "10")..i18n.translate("mA").."<br>"
				if "off" == v.dialRegex then
					more_info[cnt] = more_info[cnt]..i18n.translate("Dialplan")..": "..i18n.translate("Off").."<br>"
				else
					for i,j in pairs(dialplan) do
						if j.index and j.name and j.index == v.dialRegex then
							more_info[cnt] = more_info[cnt]..i18n.translate("Dialplan")..": "..v.dialRegex.."-&lt"..j.name..">".."<br>"
						end
					end
				end
				edit[cnt] = ds.build_url("admin","profile","fxs","profile","edit",k,"edit")
				delchk[cnt] = uci:check_cfg_deps("profile_fxso",k,"endpoint_fxso.profile")
				uci_cfg[cnt] = "profile_fxso." .. k
				table.insert(content,td)
			end
		end
	end

	if MAX_FXS_PROFILE == cnt then
		addnewable = false
	end

	luci.template.render("cbi/configlist",{
		th = th,
		colgroup = colgroup,
		content = content,
		more_info = more_info,
		edit = edit,
		delchk = delchk,
		uci_cfg = uci_cfg,
		addnewable = addnewable,
		})
end

function action_fxs_extension()
	local MAX_FXS_EXTENSION = 4
	local uci = require "luci.model.uci".cursor()
	local freeswitch = require "luci.scripts.fs_server"
	local ds = require "luci.dispatcher"
	local i18n = require "luci.i18n"

	uci:check_cfg("profile_fxso")
	uci:check_cfg("endpoint_fxso")
	uci:check_cfg("endpoint_ringgroup")
	uci:check_cfg("route")
	local siptrunk_cfg = uci:get_all("endpoint_siptrunk") or {}

	--@ Enable/Disable
	local status_target = luci.http.formvaluetable("Status")
	if status_target and "table" == type(status_target) then
		for k,v in pairs(status_target) do
			local state,cfg,section = k:match("([A-Za-z]+)%.([a-zA-Z_]+)%.(%w+).x")
			if cfg and section and state then
				uci:set(cfg,section,"status",state == "Enabled" and "Enabled" or "Disabled")
				uci:save(cfg)
			end
		end
	end

	local th = {"Port","Number","DID","SIP Reg","Call Waiting","Do Not Disturb","Call Transfer","Profile"}
	local colgroup = {"5%","13%","14%","10%","13%","12%","13%","15%","5%"}
	local content = {}
	local edit = {}
	local uci_cfg = {}
	local more_info = {}
	local cnt = 0
	local endpoint = uci:get_all("endpoint_fxso")
	local profile = uci:get_all("profile_fxso")
	
	for i=1,MAX_FXS_EXTENSION do
		for k,v in pairs(endpoint) do
			if i == tonumber(v.index) and "fxs" == v['.type'] then
				cnt = cnt + 1
				local tmp_0 = {}
				local tmp_1 = {}

				--@ port
				tmp_0[1] = (tonumber(v.index)-1)*2 + 0
				tmp_1[1] = (tonumber(v.index)-1)*2 + 1

				tmp_0[2] = v.number_1 or ""
				tmp_1[2] = v.number_2 or ""

				tmp_0[3] = v.did_1 or "-"
				tmp_1[3] = v.did_2 or "-"
				
				tmp_0[4] = i18n.translate(v.port_1_reg or "Off")
				tmp_1[4] = i18n.translate(v.port_2_reg or "Off")

				tmp_0[5] = i18n.translate(v.waiting_1 == "Activate" and "On" or "Off")
				tmp_1[5] = i18n.translate(v.waiting_2 == "Activate" and "On" or "Off")
				
				tmp_0[6] = i18n.translate(v.notdisturb_1 == "Activate" and "On" or "Off")
				tmp_1[6] = i18n.translate(v.notdisturb_2 == "Activate" and "On" or "Off")

				if v.forward_uncondition_1 ~= "Deactivate" or (v.forward_busy_1 and v.forward_busy_1 ~= "Deactivate") or (v.forward_noreply_1 and v.forward_noreply_1 ~= "Deactivate") then
					tmp_0[7] = i18n.translate("On")
				else
					tmp_0[7] = i18n.translate("Off")
				end
				if v.forward_uncondition_2 ~= "Deactivate" or (v.forward_busy_2 and v.forward_busy_2 ~= "Deactivate") or (v.forward_noreply_2 and v.forward_noreply_2 ~= "Deactivate") then
					tmp_1[7] = i18n.translate("On")
				else
					tmp_1[7] = i18n.translate("Off")
				end

				tmp_0[8] = ""
				tmp_1[8] = ""

				for x,y in pairs(profile) do
					if y['.type'] == "fxs" and y.index and y.name and v.profile and y.index == v.profile then
						tmp_0[8] = v.profile .. "-< " .. y.name .. " >"
						tmp_1[8] = v.profile.."-< "..y.name.." >"
					end
				end

				edit[cnt] = ds.build_url("admin","profile","fxs","extension","edit",k,"edit","1")
				more_info[cnt] = ""
				if v.port_1_reg == "on" then
					if not v.port_1_server_1 or "0" == v.port_1_server_1 then
						more_info[cnt] = more_info[cnt]..i18n.translate("Master Server")..": "..i18n.translate("Not Config").."<br>"
					else
						more_info[cnt] = more_info[cnt]..i18n.translate("Master Server")..": "..i18n.translate("SIP Trunk").." / "..uci.get_siptrunk_server(v.port_1_server_1).."<br>"
					end
					if not v.port_1_server_2 or "0" == v.port_1_server_2 then
						more_info[cnt] = more_info[cnt]..i18n.translate("Master Server")..": "..i18n.translate("Not Config").."<br>"
					else
						more_info[cnt] = more_info[cnt]..i18n.translate("Slave Server")..": "..i18n.translate("SIP Trunk").." / "..uci.get_siptrunk_server(v.port_1_server_2).."<br>"
					end
					more_info[cnt] = more_info[cnt]..i18n.translate("Username")..": "..(v.username_1 or v.number_1).."<br>"
					more_info[cnt] = more_info[cnt]..i18n.translate("Auth Username")..": "..(v.authuser_1 or v.user_name1 or v.number_1).."<br>"
					more_info[cnt] = more_info[cnt]..i18n.translate("Specify Transport Protocol on Register URL")..": "..( i18n.translate(v.reg_url_with_transport_1 == "on" and "On" or "Off")).."<br>"
					more_info[cnt] = more_info[cnt]..i18n.translate("Expire Seconds")..": "..(v.expire_seconds_1 or "1800").."<br>"
					more_info[cnt] = more_info[cnt]..i18n.translate("Retry Seconds")..": "..(v.retry_seconds_1 or "60").."<br>"
				end
				if v.hotline_1 and "on" == v.hotline_1 then
					more_info[cnt] = more_info[cnt]..i18n.translate("Hot Line")..":"..v.hotline_1_number.." / "..(("10"==v.hotline_1_time) and i18n.translate("Immediately") or i18n.translatef("%d Second",tonumber(v.hotline_1_time)/1000)).."</br>"
				else
					more_info[cnt] = more_info[cnt]..i18n.translate("Hot Line")..":"..i18n.translate("Off").."</br>"
				end

				if v.forward_uncondition_1 and v.forward_uncondition_1 ~= "Deactivate" then
					more_info[cnt] = more_info[cnt]..i18n.translate("Call Forward Unconditional")..": "..i18n.translate("On").."->"..uci.get_destination_detail(v.forward_uncondition_1,v.forward_uncondition_dst_1).."<br>"
				elseif "Deactivate" == v.forward_uncondition_1 then
					more_info[cnt] = more_info[cnt]..i18n.translate("Call Forward Unconditional")..": "..i18n.translate("Off").."<br>"
					if v.forward_busy_1 and "Deactivate" == v.forward_busy_1 then
						more_info[cnt] = more_info[cnt]..i18n.translate("Call Forward Busy")..": "..i18n.translate("Off").."<br>"
					elseif v.forward_busy_1 then
						more_info[cnt] = more_info[cnt]..i18n.translate("Call Forward Busy")..": "..i18n.translate("On").."->"..uci.get_destination_detail(v.forward_busy_1,v.forward_busy_dst_1).."<br>"
					end
					if v.forward_noreply_1 and "Deactivate" == v.forward_noreply_1 then
						more_info[cnt] = more_info[cnt]..i18n.translate("Call Forward No Reply")..": "..uci.get_destination_detail(v.forward_noreply_1,v.forward_noreply_dst_1).."<br>"
					else
						more_info[cnt] = more_info[cnt]..i18n.translate("Call Forward No Reply")..": "..i18n.translate("On").."->"..uci.get_destination_detail(v.forward_noreply_1,v.forward_noreply_dst_1)
						if v.forward_noreply_timeout_1 then
							more_info[cnt] = more_info[cnt].." / "..v.forward_noreply_timeout_1.."<br>"
						else
							more_info[cnt] = more_info[cnt].."<br>"
						end
					end
				end
				more_info[cnt] = more_info[cnt]..i18n.translate("Input Gain")..": "..(v.dsp_input_gain_1 or "0").."dB".."<br>"
				more_info[cnt] = more_info[cnt]..i18n.translate("Output Gain")..": "..(v.dsp_output_gain_1 or "0").."dB".."<br>"
				more_info[cnt] = more_info[cnt]..i18n.translate("Work Mode")..": "..("1" == v.work_mode_1 and "POS" or i18n.translate("Voice")).."<br>"
				cnt = cnt + 1
				edit[cnt] = ds.build_url("admin","profile","fxs","extension","edit",k,"edit","2")
				more_info[cnt] = ""
				if v.port_2_reg == "on" then
					if not v.port_2_server_1 or "0" == v.port_2_server_1 then
						more_info[cnt] = more_info[cnt]..i18n.translate("Master Server")..": "..i18n.translate("Not Config").."<br>"
					else
						more_info[cnt] = i18n.translate("Master Server")..": "..i18n.translate("SIP Trunk").." / "..uci.get_siptrunk_server(v.port_2_server_1).."<br>"
					end
					if not v.port_2_server_2 or "0" == v.port_2_server_2 then
						more_info[cnt] = more_info[cnt]..i18n.translate("Master Server")..": "..i18n.translate("Not Config").."<br>"
					else
						more_info[cnt] = more_info[cnt]..i18n.translate("Slave Server")..": "..i18n.translate("SIP Trunk").." / "..uci.get_siptrunk_server(v.port_2_server_2).."<br>"
					end
					more_info[cnt] = more_info[cnt]..i18n.translate("Username")..": "..(v.username_2 or v.number_2).."<br>"
					more_info[cnt] = more_info[cnt]..i18n.translate("Auth Username")..": "..(v.authuser_2 or v.user_name1 or v.number_2).."<br>"
					more_info[cnt] = more_info[cnt]..i18n.translate("Specify Transport Protocol on Register URL")..": "..( i18n.translate(v.reg_url_with_transport_2 == "on" and "On" or "Off")).."<br>"
					more_info[cnt] = more_info[cnt]..i18n.translate("Expire Seconds")..": "..(v.expire_seconds_2 or "1800").."<br>"
					more_info[cnt] = more_info[cnt]..i18n.translate("Retry Seconds")..": "..(v.retry_seconds_2 or "60").."<br>"
				end
				if v.hotline_2 and "on" == v.hotline_2 then
					more_info[cnt] = more_info[cnt]..i18n.translate("Hot Line")..":"..v.hotline_2_number.." / "..(("10"==v.hotline_2_time) and i18n.translate("Immediately") or i18n.translatef("%d Second",tonumber(v.hotline_2_time)/1000)).."</br>"
				else
					more_info[cnt] = more_info[cnt]..i18n.translate("Hot Line")..":"..i18n.translate("Off").."</br>"
				end
				if v.forward_uncondition_2 and v.forward_uncondition_2 ~= "Deactivate" then
					more_info[cnt] = more_info[cnt]..i18n.translate("Call Forward Unconditional")..": "..i18n.translate("On").."->"..uci.get_destination_detail(v.forward_uncondition_2,v.forward_uncondition_dst_2).."<br>"
				elseif "Deactivate" == v.forward_uncondition_2 then
					more_info[cnt] = more_info[cnt]..i18n.translate("Call Forward Unconditional")..": "..i18n.translate("Off").."<br>"
					if v.forward_busy_2 and "Deactivate" == v.forward_busy_2 then
						more_info[cnt] = more_info[cnt]..i18n.translate("Call Forward Busy")..": "..i18n.translate("Off").."<br>"
					elseif v.forward_busy_2 then
						more_info[cnt] = more_info[cnt]..i18n.translate("Call Forward Busy")..": "..i18n.translate("On").."->"..uci.get_destination_detail(v.forward_busy_2,v.forward_busy_dst_2).."<br>"
					end
					if v.forward_noreply_2 and "Deactivate" == v.forward_noreply_2 then
						more_info[cnt] = more_info[cnt]..i18n.translate("Call Forward No Reply")..": "..i18n.translate("Off").."<br>"
					else
						more_info[cnt] = more_info[cnt]..i18n.translate("Call Forward No Reply")..": "..i18n.translate("On").."->"..uci.get_destination_detail(v.forward_noreply_2,v.forward_noreply_dst_2)
						if v.forward_noreply_timeout_2 then
							more_info[cnt] = more_info[cnt].." / "..v.forward_noreply_timeout_2.."<br>"
						else
							more_info[cnt] = more_info[cnt].."<br>"
						end
					end
				end
				more_info[cnt] = more_info[cnt]..i18n.translate("Input Gain")..": "..(v.dsp_input_gain_2 or "0").."dB".."<br>"
				more_info[cnt] = more_info[cnt]..i18n.translate("Output Gain")..": "..(v.dsp_output_gain_2 or "0").."dB".."<br>"
				more_info[cnt] = more_info[cnt]..i18n.translate("Work Mode")..": "..("1" == v.work_mode_2 and "POS" or i18n.translate("Voice")).."<br>"
				table.insert(content,tmp_0)
				table.insert(content,tmp_1)
 			end
	 	end
	 end

	luci.template.render("cbi/configlist",{
		colgroup = colgroup,
		th = th,
		content = content,
		edit = edit,
		uci_cfg = uci_cfg,
		more_info = more_info,
		addnewable = false,
		})
end

function translatetone(param)
	local tonegrpvalue = {["0"]="USA",["1"]="Austria",["2"]="Belgium",["3"]="Finland",["4"]="France",["5"]="Germany",
							["6"]="Greece",["7"]="Italy",["8"]="Japan",["9"]="Norway",["10"]="Spain",["11"]="Sweden",
							["12"]="UK",["13"]="Australia",["14"]="China",["15"]="Hongkong",["16"]="Denmark",["17"]="Russia",
							["18"]="Poland",["19"]="Portugal",["20"]="Turkey",["21"]="Dutch",["ph"]="Philippines",["za"]="South Africa"}
						 
	return tonegrpvalue[param] or "0"
end

function action_fxo_profile()
	local uci = require "luci.model.uci".cursor()
	local ds = require "luci.dispatcher"
	local i18n = require "luci.i18n"
	local MAX_FXO_PROFILE = 12
	
	uci:check_cfg("profile_fxso")

	local del_target = luci.http.formvaluetable("Delete")
	if del_target then
		uci:delete_section(del_target,"endpoint_fxso.profile")
	end

	if luci.http.formvalue("New") then
		local created = uci:section("profile_fxso","fxo")
		uci:save("profile_fxso")
		luci.http.redirect(ds.build_url("admin","profile","fxo","profile","edit",created,"add"))
		return
	end

	local th = {"Index","Name","Tone Group","Digit Timeout(s)","Dial Timeout(s)","Ring Timeout(s)","No Answer Timeout(s)"}
	local colgroup = {"6%","10%","12%","15%","15%","15%","20%","7%"}
	local content = {}
	local edit = {}
	local delchk = {}
	local uci_cfg = {}
	local more_info = {}
	local addnewable = true
	local cnt = 0
	local profile = uci:get_all("profile_fxso")

	for i=1,MAX_FXO_PROFILE do
		for k,v in pairs(profile) do
			if v['.type'] == "fxo" and v.index and v.name and i == tonumber(v.index) then
				cnt = cnt + 1
				local td = {}
				td[1] = v.index
				td[2] = v.name
				td[3] = i18n.translate(translatetone(v.tonegrp))
				td[4] = v.digit or ""
				td[5] = v.dialTimeout or ""
				td[6] = v.ringtimeout or ""
				td[7] = v.noanswer or ""
				more_info[cnt] = ""
				more_info[cnt] = more_info[cnt]..i18n.translate("Detect Polarity Reverse")..": "..((v.polarity_reverse == "on" and i18n.translate("On")) or i18n.translate("Off")).."<br>"
				if v.polarity_reverse == "off" and v.delay_offhook then
					more_info[cnt] = more_info[cnt]..i18n.translate("Delay Offhook(s)")..": "..v.delay_offhook.."<br>"
				end
				local  detectcid_opt = (v.detectcid_opt == "0" and i18n.translate("Off")) or (v.detectcid_opt == "1" and i18n.translate("Detect before ring")) or (v.detectcid_opt == "2" and i18n.translate("Detect after ring"))
				more_info[cnt] = more_info[cnt]..i18n.translate("Detect Caller ID")..": "..(detectcid_opt or "Detect after ring").."<br>"
				if "1" == v.detectcid_opt or "2" == v.detectcid_opt then
					more_info[cnt] = more_info[cnt].."&nbsp;&nbsp;&nbsp;&nbsp;"..i18n.translate("DTMF Detect Timeout(ms)")..": "..(v.dtmf_detectcid_timeout or "5000").."<br>"
				end
				more_info[cnt] = more_info[cnt]..i18n.translate("Dial Delay(ms)")..":"..(v.dial_delay or 400).."<br>"
				more_info[cnt] = more_info[cnt]..i18n.translate("DTMF Parameters").."<br>"
				more_info[cnt] = more_info[cnt].."&nbsp;&nbsp;&nbsp;&nbsp;"..i18n.translate("DTMF Send Interval(ms)")..": "..(v.dtmf_sendinterval or "200").."<br>"
				more_info[cnt] = more_info[cnt].."&nbsp;&nbsp;&nbsp;&nbsp;"..i18n.translate("DTMF Duration(ms)")..": "..(v.dtmf_duration or "200").."<br>"
			  	more_info[cnt] = more_info[cnt].."&nbsp;&nbsp;&nbsp;&nbsp;"..i18n.translate("DTMF Gain")..": "..(v.dtmf_gain or "-6").."dB".."<br>"
			  	more_info[cnt] = more_info[cnt].."&nbsp;&nbsp;&nbsp;&nbsp;"..i18n.translate("DTMF Detect Threshold")..": "..(v.dtmf_detect_threshold or "-30").."dB".."<br>"
			  	if v.dtmf_end_char then
			  		more_info[cnt] = more_info[cnt].."&nbsp;&nbsp;&nbsp;&nbsp;"..i18n.translate("DTMF Terminator")..": "..(v.dtmf_end_char == "none" and i18n.translate("None") or v.dtmf_end_char).."<br>"
			  	end
			  	if v.send_dtmf_end_char then
			  		more_info[cnt] = more_info[cnt].."&nbsp;&nbsp;&nbsp;&nbsp;"..i18n.translate("Send DTMF Terminator")..": "..(v.send_dtmf_end_char == "on" and i18n.translate("On") or i18n.translate("Off")).."<br>"
			  	end
			  	more_info[cnt] = more_info[cnt]..i18n.translate("BusyTone Detect Parameters").."<br>"
			  	more_info[cnt] = more_info[cnt].."&nbsp;&nbsp;&nbsp;&nbsp;"..i18n.translate("Intermittent Ratio")..": "..((not v.busy_ratio or v.busy_ratio == "0") and i18n.translate("1:1") or v.busy_ratio == "1" and i18n.translate("Custom")).."<br>"
			  	if v.busy_tone_on then
					more_info[cnt] = more_info[cnt].."&nbsp;&nbsp;&nbsp;&nbsp;"..i18n.translate("Tone 1 On Time(ms)")..":"..v.busy_tone_on.."<br>"
				end
				if v.busy_tone_off then
					more_info[cnt] = more_info[cnt].."&nbsp;&nbsp;&nbsp;&nbsp;"..i18n.translate("Tone 1 Off Time(ms)")..":"..v.busy_tone_off.."<br>"
				end
				if v.busy_tone_on_1 then
					more_info[cnt] = more_info[cnt].."&nbsp;&nbsp;&nbsp;&nbsp;"..i18n.translate("Tone 2 On Time(ms)")..":"..v.busy_tone_on_1.."<br>"
				end
				if v.busy_tone_off_1 then
					more_info[cnt] = more_info[cnt].."&nbsp;&nbsp;&nbsp;&nbsp;"..i18n.translate("Tone 2 Off Time(ms)")..":"..v.busy_tone_off_1.."<br>"
				end
				if "off" == v.dialRegex then
					more_info[cnt] = more_info[cnt]..i18n.translate("Dialplan")..": "..i18n.translate("Off").."<br>"
				else
					local dialplan = uci:get_all("profile_dialplan")
					for i,j in pairs(dialplan) do
						if j.index and j.name and j.index == v.dialRegex then
							more_info[cnt] = more_info[cnt]..i18n.translate("Dialplan")..": "..v.dialRegex.."-&lt"..j.name..">".."<br>"
						end
					end
				end
				edit[cnt] = ds.build_url("admin","profile","fxo","profile","edit",k,"edit")
				delchk[cnt] = uci:check_cfg_deps("profile_fxso",k,"endpoint_fxso.profile")
				uci_cfg[cnt] = "profile_fxso." .. k
				table.insert(content,td)
			end
		end
	end

	if MAX_FXO_PROFILE == cnt then
		addnewable = false
	end

	luci.template.render("cbi/configlist",{
		th = th,
		colgroup = colgroup,
		content = content,
		more_info = more_info,
		edit = edit,
		delchk = delchk,
		uci_cfg = uci_cfg,
		addnewable = addnewable,
		})
end

function action_fxo_trunk()
	local MAX_FXO_TRUNK = 1
	local uci = require "luci.model.uci".cursor()
	local freeswitch = require "luci.scripts.fs_server"
	local ds = require "luci.dispatcher"
	local i18n = require "luci.i18n"

	uci:check_cfg("profile_fxso")
	uci:check_cfg("endpoint_fxso")
	uci:check_cfg("endpoint_routegroup")
	uci:check_cfg("route")

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

	local th = {"Port","Extension","Autodial Num","Register to SIP Server","Input Gain","Output Gain","Impedance","Profile"}
	local colgroup = {"5%","10%","12%","15%","12%","12%","12%","15%","7%"}
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

				--@ port 0
				--@ port 1
				local tmp_0 = {}
				local tmp_1 = {}
				tmp_0[1] = (tonumber(v.index)-1)*2 + 0
				tmp_1[1] = (tonumber(v.index)-1)*2 + 1
				
				tmp_0[2] = v.number_1 or ""
				tmp_1[2] = v.number_2 or ""

				tmp_0[3] = v.autodial_1 or ""
				tmp_1[3] = v.autodial_2 or ""

				tmp_0[4] = i18n.translate("on" == v.port_1_reg and "On" or "Off")
				tmp_1[4] = i18n.translate((("on" == v.port_2_reg and "On" or "Off")))

				tmp_0[5] = (v.dsp_input_gain_1 or "0").."dB"
				tmp_1[5] = (v.dsp_input_gain_2 or "0").."dB"

				tmp_0[6] = (v.dsp_output_gain_1 or "0").."dB"
				tmp_1[6] = (v.dsp_output_gain_2 or "0").."dB"

				tmp_0[7] = slic_tb[tonumber(v.slic_1 or 0)+1]
				tmp_1[7] = slic_tb[tonumber(v.slic_2 or 0)+1]

				tmp_0[8] = ""
				tmp_1[8] = ""
				
				for x,y in pairs(profile) do
					if y['.type'] == "fxo" and y.index and y.name and v.profile and y.index == v.profile then
						tmp_0[8] = v.profile .. "-< " .. y.name .. " >"
						tmp_1[8] = v.profile .. "-< " .. y.name .. " >"
					end
				end
				tmp_0[8] = "" ~= tmp_0[8] and tmp_0[8] or "Error"
				tmp_1[8] = "" ~= tmp_1[8] and tmp_1[8] or "Error"

				if "on" == v.port_1_reg and (v.port_1_server_1 or v.port_1_server_2 or v.authuser_1) then
					more_info[cnt] = ""
					if v.port_1_server_1 == "0" then
						more_info[cnt] = more_info[cnt]..i18n.translate("Master Server")..": "..i18n.translate("Not Config").."<br>"
					end
					if v.port_1_server_1 ~= "0" or v.port_1_server_2 ~= "0" then
						if v.port_1_server_1 ~= "0" then
							more_info[cnt] = more_info[cnt]..i18n.translate("Master Server")..": "..uci.get_siptrunk_server(v.port_1_server_1).."<br>"
						end
						if v.port_1_server_2 ~= "0"  then
							more_info[cnt] = more_info[cnt]..i18n.translate("Slave Server")..": "..uci.get_siptrunk_server(v.port_1_server_2).."<br>"
						end
					end
					if v.port_1_server_2 == "0" then
						more_info[cnt] = more_info[cnt]..i18n.translate("Slave Server")..": "..i18n.translate("Not Config").."<br>"
					end
					more_info[cnt] = more_info[cnt]..i18n.translate("Username")..": "..(v.username_1 or v.number_1).."<br>"
					more_info[cnt] = more_info[cnt]..i18n.translate("Auth Username")..": "..(v.authuser_1 or v.user_name1 or v.number_1).."<br>"
					more_info[cnt] = more_info[cnt]..i18n.translate("From Header Username")..": "..i18n.translate(v.from_username_1 == "caller" and "Caller" or "Username").."<br>"
					more_info[cnt] = more_info[cnt]..i18n.translate("Specify Transport Protocol on Register URL")..": "..(i18n.translate(v.reg_url_with_transport_1 == "on" and "On" or "Off")).."<br>"
					more_info[cnt] = more_info[cnt]..i18n.translate("Expire Seconds")..": "..(v.expire_seconds_1 or "1800").."<br>"
					more_info[cnt] = more_info[cnt]..i18n.translate("Retry Seconds")..": "..(v.retry_seconds_1 or "60").."<br>"
				else
					more_info[cnt] = ""
				end
				more_info[cnt] = more_info[cnt]..i18n.translate("Display Name / Username Format")..": "..i18n.translate(from_field_v[v.sip_from_field_1] or from_field_v["0"]).."<br>"
				more_info[cnt] = more_info[cnt]..i18n.translate("Display Name / Username Format when CID unavailable")..": "..i18n.translate(from_field_un_v[v.sip_from_field_un_1] or from_field_un_v["0"]).."<br>"
				edit[cnt] = ds.build_url("admin","profile","fxo","trunk","edit",k,"edit","1")
				table.insert(content,tmp_0)
				
				cnt = cnt +1
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
						more_info[cnt] = more_info[cnt]..i18n.translate("Slave Server")..": "..i18n.translate("Not Config").."<br>"
					end
					more_info[cnt] = more_info[cnt]..i18n.translate("Username")..": "..(v.username_2 or v.number_2).."<br>"
					more_info[cnt] = more_info[cnt]..i18n.translate("Auth Username")..": "..(v.authuser_2 or v.user_name1 or v.number_2).."<br>"
					more_info[cnt] = more_info[cnt]..i18n.translate("From Header Username")..": "..i18n.translate(v.from_username_2 == "caller" and "Caller" or "Username").."<br>"
					more_info[cnt] = more_info[cnt]..i18n.translate("Specify Transport Protocol on Register URL")..": "..(i18n.translate(v.reg_url_with_transport_2 == "on" and "On" or "Off")).."<br>"
					more_info[cnt] = more_info[cnt]..i18n.translate("Expire Seconds")..": "..(v.expire_seconds_2 or "1800").."<br>"
					more_info[cnt] = more_info[cnt]..i18n.translate("Retry Seconds")..": "..(v.retry_seconds_2 or "60").."<br>"
				else
					more_info[cnt] = ""
				end
				more_info[cnt] = more_info[cnt]..i18n.translate("Display Name / Username Format")..": "..i18n.translate(from_field_v[v.sip_from_field_2] or from_field_v["0"]).."<br>"
				more_info[cnt] = more_info[cnt]..i18n.translate("Display Name / Username Format when CID unavailable")..": "..i18n.translate(from_field_un_v[v.sip_from_field_un_2] or from_field_un_v["0"]).."<br>"
				edit[cnt] = ds.build_url("admin","profile","fxo","trunk","edit",k,"edit","2")
				table.insert(content,tmp_1)
			
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
		addnewable = false,
		undelable = true,
		})
end

function action_codec()
	local uci = require "luci.model.uci".cursor()
	local ds = require "luci.dispatcher"
	local i18n = require "luci.i18n"
	local MAX_CODEC = tonumber(uci:get("profile_param","global","max_default") or '32')
	
	uci:check_cfg("profile_codec")
	uci:check_cfg("profile_sip")

	local del_target = luci.http.formvaluetable("Delete")
	if del_target then
		uci:delete_section(del_target,"profile_sip.inbound_codec_prefs profile_sip.outbound_codec_prefs")
	end

	if luci.http.formvalue("New") then
		local created = uci:section("profile_codec","codec")
		uci:save("profile_codec")
		luci.http.redirect(ds.build_url("admin","profile","codec","codec",created,"add"))
		return
	end

	local th = {"Index","Name","Codec"}
	local colgroup = {"10%","15%","68%","7%"}
	local content = {}
	local edit = {}
	local delchk = {}
	local uci_cfg = {}
	local addnewable = true
	local cnt = 0
	local codec = uci:get_all("profile_codec")
	for i=1,MAX_CODEC do
		for k,v in pairs(codec) do
			if v.index and v.name then
				if i == tonumber(v.index) then
					cnt = cnt + 1
					local td = {}
					td[1] = v.index
					td[2] = v.name
					td[3] = table.concat((v.code or {}),", ")

					edit[cnt] = ds.build_url("admin","profile","codec","codec",k,"edit")
					delchk[cnt] = uci:check_cfg_deps("profile_codec",k,"profile_sip.inbound_codec_prefs profile_sip.outbound_codec_prefs")
					uci_cfg[cnt] = "profile_codec." .. k
					table.insert(content,td)
				end
			else
				--uci:delete("profile_codec",k)
				--uci:save("profile_codec")
			end
		end
	end
	if MAX_CODEC == cnt then
		addnewable = false
	end
	luci.template.render("cbi/configlist",{
		title = i18n.translate("VoIP Config / Codec Profile"),
		colgroup = colgroup,
		th = th,
		content = content,
		edit = edit,
		delchk = delchk,
		uci_cfg = uci_cfg,
		addnewable = addnewable,
		})
end

function action_number()
	local uci = require "luci.model.uci".cursor()
	local ds = require "luci.dispatcher"
	local i18n = require "luci.i18n"
	local MAX_NUM_PROFILE = tonumber(uci:get("profile_param","global","max_default") or '32')
	
	uci:check_cfg("profile_number")
	uci:check_cfg("route")

	local del_target = luci.http.formvaluetable("Delete")
	if del_target then
		uci:delete_section(del_target,"route.numberProfile")
	end

	if luci.http.formvalue("New") then
		local created = uci:section("profile_number","number")
		uci:save("profile_number")
		luci.http.redirect(ds.build_url("admin","profile","number","number",created,"add"))
		return
	end
	
	--local th = {"Index","Name","Caller/Length/Property/Area/Carrier","Called/Length/Property/Area/Carrier"}
	local th = {"Index","Name","Caller Prefix","Caller Length","Called Prefix","Called Length"}
	local colgroup = {"7%","10%","19%","19%","19%","19","7%"}
	local content = {}
	local edit = {}
	local delchk = {}
	local uci_cfg = {}
	local addnewable = true
	local cnt = 0
	local number = uci:get_all("profile_number")
	for i=1,MAX_NUM_PROFILE do
		for k,v in pairs(number) do
			if v.index and v.name then
				if i == tonumber(v.index) then
					cnt = cnt + 1
					local td = {}
					td[1] = v.index
					td[2] = v.name
					--td[3] = (v.caller or "*").."/"..(v.callerlength or "*").."/"..(v.callerproperty or "*").."/"..(v.callerarea or "*").."/"..(v.callercarrier or "*")
					--td[4] = (v.called or "*").."/"..(v.calledlength or "*").."/"..(v.calledproperty or "*").."/"..(v.calledarea or "*").."/"..(v.calledcarrier or "*")
					td[3] = v.caller or "*"
					td[4] = v.callerlength or "*"
					td[5] = v.called or "*"
					td[6] = v.calledlength or "*"
					edit[cnt] = ds.build_url("admin","profile","number","number",k,"edit")
					delchk[cnt] = uci:check_cfg_deps("profile_number",k,"route.numberProfile")
					uci_cfg[cnt] = "profile_number." .. k
					table.insert(content,td)
				end
			else
				--uci:delete("profile_number",k)
				--uci:save("profile_number")
			end
		end
	end
	if MAX_NUM_PROFILE == cnt then
		addnewable = false
	end
	luci.template.render("cbi/configlist",{
		title = i18n.translate("VoIP Config / Number Profile"),
		colgroup = colgroup,
		th = th,
		content = content,
		edit = edit,
		delchk = delchk,
		uci_cfg = uci_cfg,
		addnewable = addnewable,
		})
end

function action_time()
	local uci = require "luci.model.uci".cursor()
	local ds = require "luci.dispatcher"
	local i18n = require "luci.i18n"
	local util = require "luci.util"
	local MAX_TIME_PROFILE = tonumber(uci:get("profile_param","global","max_default") or '32')
	
	uci:check_cfg("profile_time")
	uci:check_cfg("route")

	local del_target = luci.http.formvaluetable("Delete")
	if del_target then
		uci:delete_section(del_target,"route.timeProfile")
	end

	if luci.http.formvalue("New") then
		local created = uci:section("profile_time","time")
		uci:save("profile_time")
		luci.http.redirect(ds.build_url("admin","profile","time","time",created,"add"))
		return
	end

	local th = {"Index","Name","Date Period","Weekday","Time Period"}
	local colgroup = {"7%","10%","25%","26%","25%","7%"}
	local content = {}
	local edit = {}
	local delchk = {}
	local uci_cfg = {}
	local addnewable = true
	local cnt = 0
	local time = uci:get_all("profile_time")
	for i=1,MAX_TIME_PROFILE do
		for k,v in pairs(time) do
			if v.index and v.name then
				if i == tonumber(v.index) then
					cnt = cnt + 1
					local td = {}
					td[1] = v.index
					td[2] = v.name
					td[3] = v.date_options or ""

					local wday =  v.weekday or ""
					local t = util.split(wday," ")
					wday = ""
					for i, value in ipairs(t) do
						wday = wday .. i18n.translate(value) .. " "
					end

					td[4] = wday

					td[5] = v.time_options or ""

					edit[cnt] = ds.build_url("admin","profile","time","time",k,"edit")
					delchk[cnt] = uci:check_cfg_deps("profile_time",k,"route.timeProfile")
					uci_cfg[cnt] = "profile_time." .. k
					table.insert(content,td)
				end
			else
				--uci:delete("profile_time",k)
				--uci:save("profile_time")
			end
		end
	end
	if MAX_TIME_PROFILE == cnt then
		addnewable = false
	end
	luci.template.render("cbi/configlist",{
		title = i18n.translate("VoIP Config / Time Profile"),
		colgroup = colgroup,
		split_col = 1,
		th = th,
		content = content,
		edit = edit,
		delchk = delchk,
		uci_cfg = uci_cfg,
		addnewable = addnewable,
		})
end

function action_manipulation()
	local uci = require "luci.model.uci".cursor()
	local ds = require "luci.dispatcher"
	local i18n = require "luci.i18n"
	local MAX_MANIPL_PROFILE = tonumber(uci:get("profile_param","global","max_default") or '32')
	
	uci:check_cfg("profile_manipl")
	uci:check_cfg("route")

	local del_target = luci.http.formvaluetable("Delete")
	if del_target then
		uci:delete_section(del_target,"route.successNumberManipulation route.failNumberManipulation")
	end

	if luci.http.formvalue("New") then
		local created = uci:section("profile_manipl","manipl")
		uci:save("profile_manipl")
		luci.http.redirect(ds.build_url("admin","profile","manipl","manipl",created,"add"))
		return
	end

	local th = {"Index","Name","Caller: Prefix/Suffix/Replace","Called: Prefix/Suffix/Replace"}
	local colgroup = {"7%","10%","38%","38%","7%"}
	local content = {}
	local edit = {}
	local delchk = {}
	local uci_cfg = {}
	local addnewable = true
	local cnt = 0
	local manipl = uci:get_all("profile_manipl")
	for i=1,MAX_MANIPL_PROFILE do
		for k,v in pairs(manipl) do
			if v.index and v.name then
				if i == tonumber(v.index) then
					cnt = cnt + 1
					local td = {}
					td[1] = v.index
					td[2] = v.name
					
					local del_pre = v.CallerDelPrefix
					local del_suf = v.CallerDelSuffix
					local add_pre = v.CallerAddPrefix
					local add_suf = v.CallerAddSuffix
					local replace = v.CallerReplace
					local result = ""
					if del_pre then
						result = result.."-"..del_pre
					end
					if add_pre then
						result = result.."+"..add_pre
					end
					result = result.."/"
					if del_suf then
						result = result.."-"..del_suf
					end
					if add_suf then
						result = result.."+"..add_suf
					end
					result = result.."/"
					if replace then
						result = result.."->"..replace
					end

					td[3] = result

					del_pre = v.CalledDelPrefix
					del_suf = v.CalledDelSuffix
					add_pre = v.CalledAddPrefix
					add_suf = v.CalledAddSuffix
					replace = v.CalledReplace
					result = ""
					if del_pre then
						result = result.."-"..del_pre
					end
					if add_pre then
						result = result.."+"..add_pre
					end
					result = result.."/"
					if del_suf then
						result = result.."-"..del_suf
					end
					if add_suf then
						result = result.."+"..add_suf
					end
					result = result.."/"
					if replace then
						result = result.."->"..replace
					end

				   	td[4] = result

					edit[cnt] = ds.build_url("admin","profile","manipl","manipl",k,"edit")
					delchk[cnt] = uci:check_cfg_deps("profile_manipl",k,"route.successNumberManipulation route.failNumberManipulation")
					uci_cfg[cnt] = "profile_manipl." .. k
					table.insert(content,td)
				end
			else
				--uci:delete("profile_manipl",k)
				--uci:save("profile_manipl")
			end
		end
	end
	if MAX_MANIPL_PROFILE == cnt then
		addnewable = false
	end
	luci.template.render("cbi/configlist",{
		title = i18n.translate("VoIP Config / Manipulation Profile"),
		colgroup = colgroup,
		th = th,
		content = content,
		edit = edit,
		delchk = delchk,
		uci_cfg = uci_cfg,
		addnewable = addnewable,
		})
end

function action_dialplan()
	local uci = require "luci.model.uci".cursor()
	local ds = require "luci.dispatcher"
	local i18n = require "luci.i18n"
	local util = require "luci.util"
	local MAX_DIALPLAN_PROFILE = tonumber(uci:get("profile_param","global","max_default") or '32')
	
	uci:check_cfg("profile_dialplan")
	uci:check_cfg("profile_fxso")

	local del_target = luci.http.formvaluetable("Delete")
	if del_target then
		uci:delete_section(del_target,"profile_fxso.dialRegex")
	end

	if luci.http.formvalue("New") then
		local created = uci:section("profile_dialplan","dialplan")
		uci:save("profile_dialplan")
		luci.http.redirect(ds.build_url("admin","profile","dialplan","dialplan",created,"add"))
		return
	end

	local th = {"Index","Name","Format","Dialplan"}
	local colgroup = {"7%","10%","13%","73%","7%"}
	local content = {}
	local edit = {}
	local delchk = {}
	local uci_cfg = {}
	local addnewable = true
	local cnt = 0
	local dialplan = uci:get_all("profile_dialplan")
	for i=1,MAX_DIALPLAN_PROFILE do
		for k,v in pairs(dialplan) do
			if v.index and v.name then
				if i == tonumber(v.index) then
					cnt = cnt + 1
					local td = {}
					td[1] = v.index
					td[2] = v.name
					if "regex" == v.format then
						td[3] = i18n.translate("Regex")
					elseif "digitmap" == v.format then
						td[3] = i18n.translate("DigitMap")
					else
						td[3] = ""
					end
					if "regex" == v.format then
						td[4] = v.dialregex or ""
					elseif "digitmap" == v.format then
						td[4] = v.digitmap or ""
					else
						td[4] = ""
					end

					edit[cnt] = ds.build_url("admin","profile","dialplan","dialplan",k,"edit")
					delchk[cnt] = uci:check_cfg_deps("profile_dialplan",k,"profile_fxso.dialRegex")
					uci_cfg[cnt] = "profile_dialplan." .. k
					table.insert(content,td)
				end
			else
				--uci:delete("profile_time",k)
				--uci:save("profile_time")
			end
		end
	end
	if MAX_DIALPLAN_PROFILE == cnt then
		addnewable = false
	end
	luci.template.render("cbi/configlist",{
		title = i18n.translate("VoIP Config / Dialplan Profile"),
		colgroup = colgroup,
		split_col = 1,
		th = th,
		content = content,
		edit = edit,
		delchk = delchk,
		uci_cfg = uci_cfg,
		addnewable = addnewable,
		})
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
		return get_name_by_index(cfg[cfg_type],index,cfg_type)
	end
	return ""
end

function action_ringgroup()
	local uci = require "luci.model.uci".cursor()
	local ds = require "luci.dispatcher"
	local i18n = require "luci.i18n"
	local MAX_RING_GRP = tonumber(uci:get("profile_param","global","max_ringgroup") or '32')
	
	uci:check_cfg("endpoint_ringgroup")
	uci:check_cfg("endpoint_sipphone")
	uci:check_cfg("endpoint_fxso")
	uci:check_cfg("route")

	local del_target = luci.http.formvaluetable("Delete")
	if del_target then
		uci:delete_section(del_target,"route.endpoint")
	end

	if luci.http.formvalue("New") then
		local created = uci:section("endpoint_ringgroup","group")
		uci:save("endpoint_ringgroup")
		luci.http.redirect(ds.build_url("admin","profile","ringgroup","ringgroup",created,"add"))
		return
	end
	
	--@ Enable/Disable
	local status_target = luci.http.formvaluetable("Status")
	if status_target and "table" == type(status_target) then
		for k,v in pairs(status_target) do
			local state,cfg,section = k:match("([A-Za-z]+)%.([a-zA-Z_]+)%.(%w+).x")
			if cfg and section and state then
				uci:set(cfg,section,"status",state == "Enabled" and "Enabled" or "Disabled")
				uci:save(cfg)
			end
		end
	end
	
	local th = {"Index","Name","Members","Strategy","Status"}
	local colgroup = {"5%","10%","50%","15%","8%","10%"}
	local content = {}
	local edit = {}
	local delchk = {}
	local uci_cfg = {}
	local status = {}
	local more_info = {}
	local addnewable = true
	local cnt = 0
	local ringgrp = uci:get_all("endpoint_ringgroup")
	for i=1,MAX_RING_GRP do
		for k,v in pairs(ringgrp) do
			if v.index and v.name then
				if i == tonumber(v.index) then
					cnt = cnt + 1
					local td = {}
					td[1] = v.index
					td[2] = v.name
					td[3] = {}

					for _,v in ipairs(v.members_select) do
						if v:match("^SIPP") then
							local vtype,index = v:match("(%u+)%-(%d+)")
							v = string.gsub(vtype,"SIPP",tostring(i18n.translate("SIP Extension"))).."-< "..get_name_by_cfgtype_id(vtype,index).." >"
						elseif v:match("^FXS") then
							local vtype,index,port = v:match("(%u+)%-(%d+)/(%d)")
							local tmp = "unknown"
							for kk,vv in pairs(uci:get_all("endpoint_fxso") or {}) do
								if "fxs" == vv[".type"] and index == vv.index then
									if "0" == port then
										tmp = i18n.translate("FXS Extension").."-< "..vv.number_1.." >"
									else
										tmp = i18n.translate("FXS Extension").."-< "..vv.number_2.." >"
									end
									break
								end
							end
							v = tmp
						end

						table.insert(td[3],v)
					end

					td[4] = i18n.translate(v.strategy or "")
					td[5] = i18n.translate(v.status or "")

					if v.number then
						more_info[cnt] = more_info[cnt] and more_info[cnt]..i18n.translate("Ring Group Number")..": "..v.number.."<br>" or i18n.translate("Ring Group Number")..": "..v.number.."<br>"
					end
					if v.did then
						more_info[cnt] = more_info[cnt] and more_info[cnt]..i18n.translate("DID")..": "..v.did.."<br>" or i18n.translate("DID")..": "..v.did.."<br>"
					end
					if v.ringtime then
						more_info[cnt] = more_info[cnt] and more_info[cnt]..i18n.translate("Ring Time(5s~60s)")..": "..v.ringtime.."<br>" or i18n.translate("Ring Time(5s~60s)")..": "..v.ringtime.."<br>"
					end
					edit[cnt] = ds.build_url("admin","profile","ringgroup","ringgroup",k,"edit")
					delchk[cnt] = uci:check_cfg_deps("endpoint_ringgroup",k,"route.endpoint")
					uci_cfg[cnt] = "endpoint_ringgroup." .. k
					status[cnt] = v.status
					table.insert(content,td)
				end
			else
				--uci:delete("endpoint_ringgroup",k)
				--uci:save("endpoint_ringgroup")
			end
		end
	end
	if MAX_RING_GRP == cnt then
		addnewable = false
	end
	luci.template.render("cbi/configlist",{
		title = i18n.translate("VoIP Config / Ring Group"),
		colgroup = colgroup,
		split_col = 4,
		classname = "paddingtight",
		th = th,
		content = content,
		edit = edit,
		delchk = delchk,
		uci_cfg = uci_cfg,
		status = status,
		more_info = more_info,
		addnewable = addnewable,
		})
end
function action_routegroup()
	local uci = require "luci.model.uci".cursor()
	local ds = require "luci.dispatcher"
	local i18n = require "luci.i18n"
	local MAX_ROUTE_GRP = tonumber(uci:get("profile_param","global","max_routegroup") or '32')
	
	uci:check_cfg("endpoint_routegroup")
	uci:check_cfg("endpoint_siptrunk")
	uci:check_cfg("endpoint_sipphone")
	uci:check_cfg("endpoint_fxso")
	uci:check_cfg("route")

	local del_target = luci.http.formvaluetable("Delete")
	if del_target then
		uci:delete_section(del_target,"route.endpoint")
	end

	if luci.http.formvalue("New") then
		local created = uci:section("endpoint_routegroup","group")
		uci:save("endpoint_routegroup")
		luci.http.redirect(ds.build_url("admin","profile","routegroup","routegroup",created,"add"))
		return
	end
	
	--@ Enable/Disable
	local status_target = luci.http.formvaluetable("Status")
	if status_target and "table" == type(status_target) then
		for k,v in pairs(status_target) do
			local state,cfg,section = k:match("([A-Za-z]+)%.([a-zA-Z_]+)%.(%w+).x")
			if cfg and section and state then
				uci:set(cfg,section,"status",state == "Enabled" and "Enabled" or "Disabled")
				uci:save(cfg)
			end
		end
	end
	
	local th = {"Index","Name","Members","Strategy","Status"}
	local colgroup = {"5%","10%","53%","15%","7%","10%"}
	local content = {}
	local edit = {}
	local delchk = {}
	local uci_cfg = {}
	local status = {}
	local addnewable = true
	local cnt = 0
	local routegrp = uci:get_all("endpoint_routegroup")
	for i=1,MAX_ROUTE_GRP do
		for k,v in pairs(routegrp) do
			if v.index and v.name then
				if i == tonumber(v.index) then
					cnt = cnt + 1
					local td = {}
					td[1] = v.index
					td[2] = v.name
					td[3] = {}

					for _,v in ipairs(v.members_select) do
						local vtype,index,port="","",""
						if v:match("^SIPP") or v:match("^SIPT") then
							vtype,index = v:match("^(%u+)%-(%d+)")
						else
							vtype,index,port = v:match("^(%u+)%-(%d+)/(%d)")
						end
						
						if vtype == "SIPP" then
							v = tostring(i18n.translate("SIP Extension")).."-< "..get_name_by_cfgtype_id(vtype,index).." >"
						elseif vtype == "SIPT" then
							v = tostring(i18n.translate("SIP Trunk")).."-< "..get_name_by_cfgtype_id(vtype,index).." >"
						elseif vtype == "FXS" or vtype == "FXO" then
							local tmp = "unknown"
							for kk,vv in pairs(uci:get_all("endpoint_fxso") or {}) do
								if "fxs" == vv[".type"] and index == vv.index then
									if "0" == port then
										tmp = i18n.translate("FXS Extension").."-< "..vv.number_1.." >"
									else
										tmp = i18n.translate("FXS Extension").."-< "..vv.number_2.." >"
									end
									break
								end
								if "fxo" == vv[".type"] and index == vv.index then
									tmp = i18n.translate("FXO Trunk").."-< "..i18n.translate("Port").." "..port.." >"
									break
								end
							end
							v = tmp
						end
						table.insert(td[3],v)
					end

					td[4] = i18n.translate(v.strategy or "")
					td[5] = i18n.translate(v.status or "")

					edit[cnt] = ds.build_url("admin","profile","routegroup","routegroup",k,"edit")
					delchk[cnt] = uci:check_cfg_deps("endpoint_routegroup",k,"route.endpoint")
					uci_cfg[cnt] = "endpoint_routegroup." .. k
					status[cnt] = v.status
					table.insert(content,td)
				end
			else
				--uci:delete("endpoint_routegroup",k)
				--uci:save("endpoint_routegroup")
			end
		end
	end
	if MAX_ROUTE_GRP == cnt then
		addnewable = false
	end
	luci.template.render("cbi/configlist",{
		title = i18n.translate("VoIP Config / Route Group"),
		colgroup = colgroup,
		split_col = 4,
		classname = "paddingtight",
		th = th,
		content = content,
		edit = edit,
		delchk = delchk,
		uci_cfg = uci_cfg,
		status = status,
		addnewable = addnewable,
		})
end
