module("luci.controller.admin.profile",package.seeall)

function index()
	local page
	page = node("admin","profile")
	page.target = firstchild()
	page.title = _("Profile")
	page.order = 70
	page.index = true
	
	entry({"admin","profile","sip"},call("sip"),"SIP",1)
	entry({"admin","profile","sip","sip"},cbi("admin_profile/sip_edit"),nil,1).leaf = true
	if luci.version.license and luci.version.license.fxs and luci.version.license.fxo then
		entry({"admin","profile","fxso"},call("fxso"),"FXS/FXO",2)
		entry({"admin","profile","fxso","fxs"},cbi("admin_profile/fxs_edit"),nil,2).leaf = true
		entry({"admin","profile","fxso","fxo"},cbi("admin_profile/fxo_edit"),nil,2).leaf = true
	elseif luci.version.license and luci.version.license.fxs then
		entry({"admin","profile","fxso"},call("fxso"),"FXS",2)
		entry({"admin","profile","fxso","fxs"},cbi("admin_profile/fxs_edit"),nil,2).leaf = true
	elseif luci.version.license and luci.version.license.fxo then
		entry({"admin","profile","fxso"},call("fxso"),"FXO",2)
		entry({"admin","profile","fxso","fxo"},cbi("admin_profile/fxo_edit"),nil,2).leaf = true
	end
	entry({"admin","profile","codec"},call("codec"),"Codec",4)
	entry({"admin","profile","codec","codec"},cbi("admin_profile/codec_edit"),nil,4).leaf = true
	entry({"admin","profile","number"},call("number"),"Number",6)
	entry({"admin","profile","number","number"},call("number_edit"),nil,6).leaf = true
	if luci.version.license and luci.version.license.gsm then
		entry({"admin","profile","numberlearning"},call("number_learning"),"SIM Number Learning",7)
		entry({"admin","profile","numberlearning","numberlearning"},call("number_learning_edit"),nil,7).leaf = true
	end
	entry({"admin","profile","time"},call("time"),"Time",8)
	entry({"admin","profile","time","time"},cbi("admin_profile/time_edit"),nil,8).leaf = true
	entry({"admin","profile","manipl"},call("manipulation"),"Manipulation",9)
	entry({"admin","profile","manipl","manipl"},cbi("admin_profile/manipulation_edit"),nil,9).leaf = true
	entry({"admin","profile","dialplan"},call("dialplan"),"Dialplan",10)
	entry({"admin","profile","dialplan","dialplan"},cbi("admin_profile/dialplan_edit"),nil,10).leaf = true
end

function sip()
	local MAX_SIP_PROFILE = 8
	local uci = require "luci.model.uci".cursor()
	local ds = require "luci.dispatcher"
	local i18n = require "luci.i18n"

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
		luci.http.redirect(ds.build_url("admin","profile","sip","sip",created,"add"))
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
	local profile = uci:get_all("profile_sip") or {}
	local codec = uci:get_all("profile_codec") or {}
	for i=1,MAX_SIP_PROFILE do
		for k,v in pairs(profile) do
			if v.index and i == tonumber(v.index) then
				cnt = cnt + 1
				local td = {}
				td[1] = v.index
				td[2] = v.name or "Error"
				td[3] = v.localinterface or ""
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
				if ((v.session_timer and "on" == v.session_timer) or (not v.session_timer)) and v.session_timeout then
					td[6] = v.session_timeout
				else
					td[6] = i18n.translate("Off")
				end
				if v.inbound_codec_negotiation and "generous" == v.inbound_codec_negotiation then
					td[7] = i18n.translate("Remote")
				elseif v.inbound_codec_negotiation and "greedy" == v.inbound_codec_negotiation then
					td[7] = i18n.translate("Local")
				elseif v.inbound_codec_negotiation and "scrooge" == v.inbound_codec_negotiation then
					td[7] = i18n.translate("Local Force")
				else
					td[7] = ""
				end

				td[8] = "Error"
				for x,y in pairs(codec) do
					if y.index and y.name and y.index == v.inbound_codec_prefs then
						td[8] = y.index.."-< "..y.name.." >"
						break
					end
				end

				td[9] = "Error"
				for x,y in pairs(codec) do
					if y.index and y.name and y.index == v.outbound_codec_prefs then
						td[9] = y.index.."-< "..y.name.." >"
						break
					end
				end
				local nat = ("auto-nat" == v.ext_sip_ip and "uPNP / NAT-PMP") or ("ip" == v.ext_sip_ip and i18n.translate("IP Address")) or ("stun" == v.ext_sip_ip and "Stun") or ("host" == v.ext_sip_ip and i18n.translate("DDNS")) or i18n.translate("Off")
				more_info[cnt] = i18n.translate("NAT")..":"..nat
				if "off" ~= v.ext_sip_ip and "auto-nat" ~= v.ext_sip_ip and v.ext_sip_ip_more then	
					more_info[cnt] = more_info[cnt].."->"..v.ext_sip_ip_more.."<br>"
				else
					more_info[cnt] = more_info[cnt].."<br>"
				end
				more_info[cnt] = more_info[cnt]..i18n.translate("PRACK")..":"..(v.prack == "on" and i18n.translate("On") or i18n.translate("Off")).."<br>"
				more_info[cnt] = more_info[cnt]..i18n.translate("Detect Extension is Online")..":"..("on" == v.heartbeat and i18n.translate("On") or i18n.translate("Off")).."<br>"
				if "on" == v.heartbeat and v.ping then
					more_info[cnt] = more_info[cnt].."&nbsp;&nbsp;&nbsp;&nbsp;"..i18n.translate("Detect Period(s)")..":"..v.ping.."<br>"
				end
				more_info[cnt] = more_info[cnt]..i18n.translate("Allow Unknown Call")..":"..(v.allow_unknown_call == "on" and i18n.translate("On") or i18n.translate("Off")).."<br>"
				more_info[cnt] = more_info[cnt]..i18n.translate("Inbound Source Filter")..":"..((not v.auth_acl or "0.0.0.0" == v.auth_acl or "0.0.0.0/0" == v.auth_acl or "0.0.0.0/0.0.0.0" == v.auth_acl ) and i18n.translate("All") or v.auth_acl).."<br>"
				more_info[cnt] = more_info[cnt].."QoS: "..("on" == v.qos and i18n.translate("On") or i18n.translate("Off")).."<br>"
				if "on" == v.qos then
					more_info[cnt] = more_info[cnt].."&nbsp;&nbsp;&nbsp;&nbsp;"..i18n.translate("SIP Message DSCP Value")..": "..(dscp[v.dscp_sip or "46"] or dscp["46"]).." / "..(dscp[v.dscp_sip] and v.dscp_sip or 46).."<br>"
					more_info[cnt] = more_info[cnt].."&nbsp;&nbsp;&nbsp;&nbsp;"..i18n.translate("RTP DSCP Value")..": "..(dscp[v.dscp_rtp or "46"] or dscp["46"]).." / "..(dscp[v.dscp_rtp] and v.dscp_rtp or 46).."<br>"
				end
				edit[cnt] = ds.build_url("admin","profile","sip","sip",k,"edit")
				delchk[cnt] = uci:check_cfg_deps("profile_sip",k,"endpoint_siptrunk.profile endpoint_sipphone.profile")
				uci_cfg[cnt] = "profile_sip." .. k
				table.insert(content,td)
				break
			elseif not v.index or not v.name then
				uci:delete("profile_sip",k)
			end
		end
	end
	if MAX_SIP_PROFILE == cnt then
		addnewable = false
	end
	luci.template.render("cbi/configlist",{
		title = i18n.translate("Profile / SIP"),
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

function fxso()
	local uci = require "luci.model.uci".cursor()
	local ds = require "luci.dispatcher"
	local i18n = require "luci.i18n"

	uci:check_cfg("profile_fxso")
	uci:check_cfg("profile_dialplan")

	local del_target = luci.http.formvaluetable("Delete")
	if del_target then
		uci:delete_section(del_target,"endpoint_fxso.profile")
	end

	local new_target = luci.http.formvaluetable("New")
	if new_target and "table" == type(new_target) then
		for k,v in pairs(new_target) do
			local cfg_type = k:match("(fx[so])")
			if cfg_type then
				local created = uci:section("profile_fxso",cfg_type)
				uci:save("profile_fxso")
				luci.http.redirect(ds.build_url("admin","profile","fxso",cfg_type,created,"add"))
				return
			end
		end
	end

	luci.template.render("admin_profile/fxso")
end

function codec()
	local MAX_CODEC = 16
	local uci = require "luci.model.uci".cursor()
	local ds = require "luci.dispatcher"
	local i18n = require "luci.i18n"

	uci:check_cfg("profile_codec")
	uci:check_cfg("profile_sip")

	local del_target = luci.http.formvaluetable("Delete")
	if next(del_target) then
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
	local codec = uci:get_all("profile_codec") or {}
	for i=1,MAX_CODEC do
		for k,v in pairs(codec) do
			if v.index and v.name and i == tonumber(v.index) then
				cnt = cnt + 1
				local td = {}
				td[1] = v.index
				td[2] = v.name
				td[3] = table.concat((v.code or {}),", ")

				edit[cnt] = ds.build_url("admin","profile","codec","codec",k,"edit")
				delchk[cnt] = uci:check_cfg_deps("profile_codec",k,"profile_sip.inbound_codec_prefs profile_sip.outbound_codec_prefs")
				uci_cfg[cnt] = "profile_codec." .. k
				table.insert(content,td)
				break
			elseif not v.index or not v.name then
				uci:delete("profile_codec",k)
			end
		end
	end
	if MAX_CODEC == cnt then
		addnewable = false
	end
	luci.template.render("cbi/configlist",{
		title = i18n.translate("Profile / Codec"),
		colgroup = colgroup,
		th = th,
		content = content,
		edit = edit,
		delchk = delchk,
		uci_cfg = uci_cfg,
		addnewable = addnewable,
		})
end

function number()
	local MAX_NUM_PROFILE = 32
	local uci = require "luci.model.uci".cursor()
	local ds = require "luci.dispatcher"
	local i18n = require "luci.i18n"

	uci:check_cfg("profile_number")
	uci:check_cfg("route")

	local del_target = luci.http.formvaluetable("Delete")
	if next(del_target) then
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
	local number = uci:get_all("profile_number") or {}
	for i=1,MAX_NUM_PROFILE do
		for k,v in pairs(number) do
			if v.index and v.name and i == tonumber(v.index) then
				cnt = cnt + 1
				local td = {}
				td[1] = v.index
				td[2] = v.name
				if v.caller and "string" == type(v.caller) then
					td[3] = v.caller
				elseif v.caller and "table" == type(v.caller) then
					td[3] = table.concat((v.caller or {}),"|")
				else
					td[3] = "*"
				end
				td[4] = v.callerlength or "*"
				if v.called and "string" == type(v.called) then
					td[5] = v.called
				elseif v.called and "table" == type(v.called) then
					td[5] = table.concat((v.called or {}),"|")
				else
					td[5] = "*"
				end
				td[6] = v.calledlength or "*"
				edit[cnt] = ds.build_url("admin","profile","number","number",k,"edit")
				delchk[cnt] = uci:check_cfg_deps("profile_number",k,"route.numberProfile")
				uci_cfg[cnt] = "profile_number." .. k
				table.insert(content,td)
				break
			elseif not v.index or not v.name then
				uci:delete("profile_number",k)
				--uci:save("profile_number")
			end
		end
	end
	if MAX_NUM_PROFILE == cnt then
		addnewable = false
	end
	luci.template.render("cbi/configlist",{
		title = i18n.translate("Profile / Number"),
		colgroup = colgroup,
		th = th,
		content = content,
		edit = edit,
		delchk = delchk,
		uci_cfg = uci_cfg,
		addnewable = addnewable,
		})
end

function number_edit(...)
	local fs = require "luci.fs"
	local uci = require "luci.model.uci".cursor()
	local ds = require "luci.dispatcher"
	local i18n = require "luci.i18n"
	local util = require "luci.util"
	local redirect
	local section=arg[1]
	local add_or_edit=arg[2]
	local next_redirect=arg[3]
	local title="Profile / Number / New"
	local available_id_list={}
	local idx_value=1
	local name_value=""
	local caller_prefix_length_value=""
	local caller_prefix_value=""
	local called_prefix_length_value=""
	local called_prefix_value=""

	if luci.http.formvalue("save") and section then
		local value_t=luci.http.formvaluetable("profile_number."..section)
		for k,v in pairs(value_t) do
			if k == "caller" or k == "called" then
				v=string.gsub(v,"\r","")
				v=string.gsub(v,"\n$","")

				if "" == v then
					uci:delete("profile_number",section,k)
				else
					local old_val=uci:get("profile_number",section,k)
					if "string" == type(old_val) then
						uci:set_list("profile_number",section,k, util.split(v,"\n"))
					elseif (not old_val) or ("table" == type(old_val) and table.concat(old_val,"\n") ~= v) then
						uci:set_list("profile_number",section,k, util.split(v,"\n"))
					end
				end
			else
				uci:set("profile_number",section,k,v)
			end
		end
		uci:save("profile_number")
		redirect=true
	elseif luci.http.formvalue("cancel") and section then
		if "add" == add_or_edit then
			uci:revert("profile_number",section)
			uci:save("profile_number")
		end
		redirect=true
	end

	if redirect then
		if next_redirect then
			local mod,submod,cfg,action = next_redirect:match("(%w+)-(%w+)-(%w+)-(%w+)")
			luci.http.redirect(ds.build_url("admin",mod,submod,submod,cfg,action))
		else
			luci.http.redirect(ds.build_url("admin","profile","number"))
		end
		return
	end

	if section then
		local profile_number=uci:get_all("profile_number") or {}
		for i=1,32 do
			table.insert(available_id_list,i)
		end
		for k,v in pairs(profile_number) do
			if v.index then
				available_id_list[tonumber(v.index)]=0
			end
			if k == section then
				idx_value=v.index
				name_value=v.name
				caller_prefix_length_value=v.callerlength
				if v.caller and "string" == type(v.caller) then
					caller_prefix_value = v.caller
				elseif v.caller and "table" == type(v.caller) then
					caller_prefix_value = table.concat((v.caller or {}),"\n")
				else
					caller_prefix_value = ""
				end
				called_prefix_length_value=v.calledlength
				if v.called and "string" == type(v.called) then
					called_prefix_value = v.called
				elseif v.called and "table" == type(v.called) then
					called_prefix_value = table.concat((v.called or {}),"\n")
				else
					called_prefix_value = ""
				end
				if "edit" == add_or_edit then
					title="Profile / Number / Edit"
					available_id_list={}
					break
				end
			end
		end
	end

	luci.template.render("admin_profile/number_edit",{
		need_redirect_back=next_redirect,
		title = i18n.translate(title),
		available_id_list=available_id_list,
		idx_id="profile_number."..section..".index",
		name_id="profile_number."..section..".name",
		caller_length_id="profile_number."..section..".callerlength",
		caller_prefix_id="profile_number."..section..".caller",
		called_length_id="profile_number."..section..".calledlength",
		called_prefix_id="profile_number."..section..".called",
		idx_value=idx_value,
		name_value=name_value,
		caller_prefix_length_value=caller_prefix_length_value,
		caller_prefix_value=caller_prefix_value,
		called_prefix_length_value=called_prefix_length_value,
		called_prefix_value=called_prefix_value,
		})
end

function number_learning()
	local MAX_NUM_PROFILE = 32
	local uci = require "luci.model.uci".cursor()
	local ds = require "luci.dispatcher"
	local i18n = require "luci.i18n"

	uci:check_cfg("profile_numberlearning")
	uci:check_cfg("endpoint_mobile")

	local del_target = luci.http.formvaluetable("Delete")
	if next(del_target) then
		uci:delete_section(del_target,"endpoint_mobile.numberlearning_profile")
	end

	if luci.http.formvalue("New") then
		local created = uci:section("profile_numberlearning","rule")
		uci:save("profile_numberlearning")
		luci.http.redirect(ds.build_url("admin","profile","numberlearning","numberlearning",created,"add"))
		return
	end

	--local th = {"Index","Name","Caller/Length/Property/Area/Carrier","Called/Length/Property/Area/Carrier"}
	local th = {"Index","Name","Type","Destination Number","Send Text","Check SMS From Number","Keywords"}
	local colgroup = {"7%","10%","10%","19%","10%","19","16%","9%"}
	local content = {}
	local edit = {}
	local delchk = {}
	local uci_cfg = {}
	local addnewable = true
	local cnt = 0
	local number = uci:get_all("profile_numberlearning") or {}
	for i=1,MAX_NUM_PROFILE do
		for k,v in pairs(number) do
			if v.index and v.name and i == tonumber(v.index) then
				cnt = cnt + 1
				local td = {}
				td[1] = v.index
				td[2] = v.name
				td[3] = v.type == "sms" and i18n.translate("SMS") or i18n.translate("Unknown")
				td[4] = v.dest_number or ""
				td[5] = v.send_text or ""
				td[6] = v.from_number or ""
				td[7] = v.keywords or ""
				edit[cnt] = ds.build_url("admin","profile","numberlearning","numberlearning",k,"edit")
				delchk[cnt] = uci:check_cfg_deps("profile_numberlearning",k,"endpoint_mobile.numberlearning_profile")
				uci_cfg[cnt] = "profile_numberlearning." .. k
				table.insert(content,td)
				break
			elseif not v.index or not v.name then
				uci:delete("profile_numberlearning",k)
				--uci:save("profile_number")
			end
		end
	end
	if MAX_NUM_PROFILE == cnt then
		addnewable = false
	end
	luci.template.render("cbi/configlist",{
		title = i18n.translate("Profile / SIM Number Learning"),
		colgroup = colgroup,
		th = th,
		content = content,
		edit = edit,
		delchk = delchk,
		uci_cfg = uci_cfg,
		addnewable = addnewable,
		})
end

function number_learning_edit(...)
	local fs = require "luci.fs"
	local uci = require "luci.model.uci".cursor()
	local ds = require "luci.dispatcher"
	local i18n = require "luci.i18n"
	local util = require "luci.util"
	local redirect
	local section=arg[1]
	local add_or_edit=arg[2]
	local next_redirect=arg[3]
	local title="Profile / SIM Number Learning / New"
	local available_id_list={}
	local idx_value=1
	local name_value=""
	local type_value=""
	local destination_number_value=""
	local send_text_value=""
	local from_number_value=""
	local keywords_value=""

	if luci.http.formvalue("save") and section then
		local value_t=luci.http.formvaluetable("profile_numberlearning."..section)
		for k,v in pairs(value_t) do
			uci:set("profile_numberlearning",section,k,v)
		end
		uci:save("profile_numberlearning")
		redirect=true
	elseif luci.http.formvalue("cancel") and section then
		if "add" == add_or_edit then
			uci:revert("profile_numberlearning",section)
			uci:save("profile_numberlearning")
		end
		redirect=true
	end

	if redirect then
		if next_redirect then
			local mod,submod,cfg,action = next_redirect:match("(%w+)-(%w+)-(%w+)-(%w+)")
			luci.http.redirect(ds.build_url("admin",mod,submod,submod,cfg,action))
		else
			luci.http.redirect(ds.build_url("admin","profile","numberlearning"))
		end
		return
	end

	if section then
		local profile_number=uci:get_all("profile_numberlearning") or {}
		for i=1,32 do
			table.insert(available_id_list,i)
		end
		for k,v in pairs(profile_number) do
			if v.index then
				available_id_list[tonumber(v.index)]=0
			end
			if k == section then
				idx_value=v.index
				name_value=v.name
				type_value=v.type
				destination_number_value=v.dest_number
				send_text_value=v.send_text
				from_number_value=v.from_number
				keywords_value=v.keywords
				if "edit" == add_or_edit then
					title="Profile / SIM Number Learning / Edit"
					available_id_list={}
					break
				end
			end
		end
	end

	luci.template.render("admin_profile/number_learning_edit",{
		need_redirect_back=next_redirect,
		title = i18n.translate(title),
		available_id_list=available_id_list,
		idx_id="profile_numberlearning."..section..".index",
		name_id="profile_numberlearning."..section..".name",
		type_id="profile_numberlearning."..section..".type",
		destination_number_id="profile_numberlearning."..section..".dest_number",
		send_text_id="profile_numberlearning."..section..".send_text",
		from_number_id="profile_numberlearning."..section..".from_number",
		keywords_id="profile_numberlearning."..section..".keywords",
		idx_value=idx_value,
		name_value=name_value,
		type_value=type_value,
		destination_number_value=destination_number_value,
		send_text_value=send_text_value,
		from_number_value=from_number_value,
		keywords_value=keywords_value,
		})
end

function time()
	local MAX_TIME_PROFILE = 32
	local uci = require "luci.model.uci".cursor()
	local ds = require "luci.dispatcher"
	local i18n = require "luci.i18n"
	local util = require "luci.util"

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
	local time = uci:get_all("profile_time") or {}
	for i=1,MAX_TIME_PROFILE do
		for k,v in pairs(time) do
			if v.index and v.name and i == tonumber(v.index) then
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
				delchk[cnt] = uci:check_cfg_deps("profile_time",k,"route.timeProfile endpoint_forwardgroup.timeProfile")
				uci_cfg[cnt] = "profile_time." .. k
				table.insert(content,td)
				break
			elseif not v.index or not v.name then
				uci:delete("profile_time",k)
				--uci:save("profile_time")
			end
		end
	end
	if MAX_TIME_PROFILE == cnt then
		addnewable = false
	end
	luci.template.render("cbi/configlist",{
		title = i18n.translate("Profile / Time"),
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

function manipulation()
	local MAX_MANIPL_PROFILE = 32
	local uci = require "luci.model.uci".cursor()
	local ds = require "luci.dispatcher"
	local i18n = require "luci.i18n"

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
	local manipl = uci:get_all("profile_manipl") or {}
	for i=1,MAX_MANIPL_PROFILE do
		for k,v in pairs(manipl) do
			if v.index and v.name and i == tonumber(v.index) then
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
				break
			elseif not v.index or not v.name then
				uci:delete("profile_manipl",k)
				--uci:save("profile_manipl")
			end
		end
	end
	if MAX_MANIPL_PROFILE == cnt then
		addnewable = false
	end
	luci.template.render("cbi/configlist",{
		title = i18n.translate("Profile / Manipulation"),
		colgroup = colgroup,
		th = th,
		content = content,
		edit = edit,
		delchk = delchk,
		uci_cfg = uci_cfg,
		addnewable = addnewable,
		})
end

function dialplan()
	local MAX_DIALPLAN_PROFILE = 24
	local uci = require "luci.model.uci".cursor()
	local ds = require "luci.dispatcher"
	local i18n = require "luci.i18n"
	local util = require "luci.util"

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
	local dialplan = uci:get_all("profile_dialplan") or {}
	for i=1,MAX_DIALPLAN_PROFILE do
		for k,v in pairs(dialplan) do
			if v.index and v.name and i == tonumber(v.index) then
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
				break
			elseif not v.index or v.name then
				uci:delete("profile_time",k)
				--uci:save("profile_time")
			end
		end
	end
	if MAX_DIALPLAN_PROFILE == cnt then
		addnewable = false
	end
	luci.template.render("cbi/configlist",{
		title = i18n.translate("Profile / Dialplan"),
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
