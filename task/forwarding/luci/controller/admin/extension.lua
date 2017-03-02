module("luci.controller.admin.extension",package.seeall)

function index()
	local page
	page = node("admin","extension")
	page.target = firstchild()
	page.title = _("Extension")
	page.order = 71
	page.index = true
	entry({"admin","extension","sip"},call("sip"),"SIP",1)
	entry({"admin","extension","sip","sip"},cbi("admin_extension/sipphone_edit"),nil,1).leaf = true
	entry({"admin","extension","sip","batchnew"},call("sip_batch_new"),nil,1).leaf = true
	if luci.version.license and luci.version.license.fxs then
		entry({"admin","extension","fxs"},call("fxs"), "FXS",2)
		entry({"admin","extension","fxs","fxs"},cbi("admin_extension/fxs_edit"),nil,2).leaf = true
	end
	entry({"admin","extension","ringgroup"},call("ringgroup"), "Ring Group",3)
	entry({"admin","extension","ringgroup","ringgroup"},cbi("admin_extension/ringgroup_edit"),nil,3).leaf = true
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
		if "FXS" == cfg_type or "FXO" == cfg_type and "GSM" == cfg_type and "CDMA" == cfg_type then
			return cfg_type
		else
			return get_name_by_index(cfg[cfg_type],index,cfg_type)
		end
	end
	return ""
end

function sip()
	local MAX_SIP_EXTENSION = 32
	local uci = require "luci.model.uci".cursor()
	local ds = require "luci.dispatcher"
	local i18n = require "luci.i18n"

	uci:check_cfg("profile_sip")
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
		local created = uci:section("endpoint_sipphone","sip")
		uci:save("endpoint_sipphone")
		luci.http.redirect(ds.build_url("admin","extension","sip","sip",created,"add"))
		return
	end

	local th = {"Index","Name","Extension","DID","Password Auth","Register Source","Profile","Status"}
	local colgroup = {"7%","7%","12%","12%","12%","20%","13%","8%","9%"}
	local content = {}
	local edit = {}
	local delchk = {}
	local uci_cfg = {}
	local status = {}
	local more_info = {}
	local addnewable = true
	local cnt = 0
	local endpoint = uci:get_all("endpoint_sipphone") or {}
	local profile = uci:get_all("profile_sip") or {}
	local number_rule = uci:get_all("profile_number") or {}
	for i=1,MAX_SIP_EXTENSION do
		for k,v in pairs(endpoint) do
			if v.index and i == tonumber(v.index) then
				cnt = cnt + 1
				local tmp = {}
				tmp[1] = v.index
				tmp[2] = v.name or "Error"
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
				more_info[cnt] = i18n.translate("Call Waiting").." : "..((v.waiting and "Activate" == v.waiting) and i18n.translate("On") or i18n.translate("Off")).."<br>"
				more_info[cnt] = more_info[cnt]..i18n.translate("Do Not Disturb").." : "..((v.notdisturb and "Activate" == v.notdisturb) and i18n.translate("On") or i18n.translate("Off")).."<br>"

				local forward_uncondition = (type(v.forward_uncondition) == "string" and v.forward_uncondition) or (type(v.forward_uncondition) == "table" and v.forward_uncondition[1])
				if not forward_uncondition or "Deactivate" == forward_uncondition then
					more_info[cnt] = more_info[cnt]..i18n.translate("Call Forward Unconditional").." : "..i18n.translate("Off").."<br>"

					local forward_unregister = (type(v.forward_unregister) == "string" and v.forward_unregister) or (type(v.forward_unregister) == "table" and v.forward_unregister[1])
					local forward_busy = (type(v.forward_busy) == "string" and v.forward_busy) or (type(v.forward_busy) == "table" and v.forward_busy[1])
					local forward_noreply = (type(v.forward_noreply) == "string" and v.forward_noreply) or (type(v.forward_noreply) == "table" and v.forward_noreply[1])
					if not forward_unregister or "Deactivate" == forward_unregister then
						more_info[cnt] = more_info[cnt]..i18n.translate("Call Forward Unregister").." : "..i18n.translate("Off").."<br>"
					else
						more_info[cnt] = more_info[cnt]..i18n.translate("Call Forward Unregister").." : "..i18n.translate("On").."->"..uci.get_destination_detail(forward_unregister,v.forward_unregister_dst).."...<br>"
					end
					if not forward_busy or "Deactivate" == forward_busy then
						more_info[cnt] = more_info[cnt]..i18n.translate("Call Forward Busy").." : "..i18n.translate("Off").."<br>"
					else
						more_info[cnt] = more_info[cnt]..i18n.translate("Call Forward Busy").." : "..i18n.translate("On").."->"..uci.get_destination_detail(forward_busy,v.forward_busy_dst).."...<br>"
					end
					if not forward_noreply or "Deactivate" == forward_noreply then
						more_info[cnt] = more_info[cnt]..i18n.translate("Call Forward No Reply").." : "..i18n.translate("Off").."<br>"
					else
						more_info[cnt] = more_info[cnt]..i18n.translate("Call Forward No Reply").." : "..i18n.translate("On").."->"..uci.get_destination_detail(forward_noreply,v.forward_noreply_dst).."...<br>"
					end
				else
					more_info[cnt] = more_info[cnt]..i18n.translate("Call Forward Unconditional").." : "..i18n.translate("On").."->"..uci.get_destination_detail(forward_uncondition,v.forward_uncondition_dst).."...<br>"
				end
				if v.callin_filter == "blacklist" or v.callin_filter == "whitelist" then
					local filter_idx = (v.callin_filter == "blacklist" and v.callin_filter_blacklist or v.callin_filter_whitelist)
					more_info[cnt] = more_info[cnt]..i18n.translate("Call In Filter").." : "..(v.callin_filter == "blacklist" and i18n.translate("Black List") or i18n.translate("White List"))
					local filter_name
					for x,y in pairs(number_rule) do
						if filter_idx == y.index and y.name then
							filter_name = filter_idx.."-< "..y.name.." >"
							break
						end
					end
					if filter_name then
						more_info[cnt] = more_info[cnt].." / "..filter_name.."<br>"
					else
						more_info[cnt] = more_info[cnt].." / <font style='background:red'>"..(filter_idx or i18n.translate("Error")).."-< "..i18n.translate("Error").." ></font><br>"
					end
				else
					more_info[cnt] = more_info[cnt]..i18n.translate("Call In Filter").." : "..i18n.translate("Off").."<br>"
				end
				if v.callout_filter == "blacklist" or v.callout_filter == "whitelist" then
					local filter_idx = (v.callout_filter == "blacklist" and v.callout_filter_blacklist or v.callout_filter_whitelist)
					more_info[cnt] = more_info[cnt]..i18n.translate("Call Out Filter").." : "..(v.callout_filter == "blacklist" and i18n.translate("Black List") or i18n.translate("White List"))
					local filter_name
					for x,y in pairs(number_rule) do
						if filter_idx == y.index and y.name then
							filter_name = filter_idx.."-< "..y.name.." >"
							break
						end
					end
					if filter_name then
						more_info[cnt] = more_info[cnt].." / "..filter_name.."<br>"
					else
						more_info[cnt] = more_info[cnt].." / <font style='background:red'>"..(filter_idx or i18n.translate("Error")).."-< "..i18n.translate("Error").." ></font><br>"
					end
				else
					more_info[cnt] = more_info[cnt]..i18n.translate("Call Out Filter").." : "..i18n.translate("Off").."<br>"
				end
				more_info[cnt] = more_info[cnt]..i18n.translate("NAT").." : "..((v.nat and "on" == v.nat) and i18n.translate("On") or i18n.translate("Off")).."<br>"
				tmp[7] = ""
				for x,y in pairs(profile) do
					if y.index and y.name and v.profile and y.index == v.profile then
						tmp[7] = v.profile .. "-< " .. y.name .. " >"
						break
					end
				end
				tmp[7] = "" ~= tmp[7] and tmp[7] or "Error"
				tmp[8] = i18n.translate(v.status or "")
				status[cnt] = v.status or "Disabled"
				edit[cnt] = ds.build_url("admin","extension","sip","sip",k,"edit")
				delchk[cnt] = uci:check_cfg_deps("endpoint_sipphone",k,"route.endpoint")
				uci_cfg[cnt] = "endpoint_sipphone." .. k
				table.insert(content,tmp)
				break
			elseif not v.index or not v.name then
				uci:delete("endpoint_sipphone",k)
			end
		end
	end
	if MAX_SIP_EXTENSION <= cnt then
		addnewable = false
	end
	luci.template.render("cbi/configlist",{
		title = i18n.translate("Extension / SIP"),
		colgroup = colgroup,
		th = th,
		content = content,
		more_info = more_info,
		edit = edit,
		status = status,
		delchk = delchk,
		uci_cfg = uci_cfg,
		addnewable = addnewable,
		batchnew=ds.build_url("admin","extension","sip","batchnew"),
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
			tmp.nat=bn.nat
			tmp.profile=bn.profile
			tmp.status=bn.status
			uci:section("endpoint_sipphone","sip",nil,tmp)
			uci:save("endpoint_sipphone")
		end
		luci.http.redirect(ds.build_url("admin","extension","sip"))
	elseif luci.http.formvalue("cancel") then
		luci.http.redirect(ds.build_url("admin","extension","sip"))
	else
		local exist_extension,max_cnt=get_all_exist_extension()
		luci.template.render("admin_extension/batchnew",{
			max_cnt=((max_cnt>=0) and max_cnt or 0),
			exist_extension=exist_extension,
		})
	end
end
function fxs()
	local MAX_FXS_EXTENSION = 12
	local uci = require "luci.model.uci".cursor()
	local freeswitch = require "luci.scripts.fs_server"
	local ds = require "luci.dispatcher"
	local i18n = require "luci.i18n"

	uci:check_cfg("profile_fxso")
	uci:check_cfg("endpoint_fxso")
	uci:check_cfg("endpoint_routegroup")
	uci:check_cfg("endpoint_ringgroup")
	uci:check_cfg("route")

--@ Enable/Disable
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

	local th = {"Extension","DID","Register to SIP Server","Call Waiting","Do Not Disturb","Call Forward","Profile","Status"}
	local colgroup = {"10%","10%","15%","11%","11%","11%","11%","11%","10%"}
	local content = {}
	local edit = {}
	local delchk = {}
	local uci_cfg = {}
	local more_info = {}
	local status = {}
	local addnewable = true
	local cnt = 0
	local endpoint = uci:get_all("endpoint_fxso") or {}
	local profile = uci:get_all("profile_fxso") or {}
	local number_rule = uci:get_all("profile_number") or {}
	for i=1,MAX_FXS_EXTENSION do
		for k,v in pairs(endpoint) do
			if v.index and v.name and i == tonumber(v.index) and "fxs" == v['.type']then
				for port=1,luci.version.license.fxs do
					cnt = cnt + 1
					local tmp = {}
					tmp[1] = v["number_"..port] or ""
					tmp[2] = v["did_"..port] or ""
					tmp[3] = i18n.translate((("on" == v["port_"..port.."_reg"]) and "On" or "Off"))
					tmp[4] = (v["waiting_"..port] == "Activate") and i18n.translate("On") or i18n.translate("Off")
					tmp[5] = (v["notdisturb_"..port] == "Activate") and i18n.translate("On") or i18n.translate("Off")
					
					if v["forward_uncondition_"..port] ~= "Deactivate" or (v["forward_busy_"..port] and v["forward_busy_"..port] ~= "Deactivate") or (v["forward_noreply_"..port] and v["forward_noreply_"..port] ~= "Deactivate") then
						tmp[6] = i18n.translate("On")
					else
						tmp[6] = i18n.translate("Off")
					end
					tmp[7] = ""
					for x,y in pairs(profile) do
						if y.index and y.name and v.profile and y.index == v.profile then
							tmp[7] = v.profile .. "-< " .. y.name .. " >"
							break
						end
					end
					tmp[7] = "" ~= tmp[7] and tmp[7] or "Error"
					tmp[8] = i18n.translate(v.status or "")

					more_info[cnt] = ""
					if "on" == v["port_"..port.."_reg"] and (v["port_"..port.."_server_1"] or v["port_"..port.."_server_2"] or v["authuser_"..port]) then
						if v["port_"..port.."_server_1"] == "0" then
							more_info[cnt] = more_info[cnt]..i18n.translate("Master Server").." : "..i18n.translate("Not Config").."<br>"
						end
						if v["port_"..port.."_server_1"] ~= "0" or v["port_"..port.."_server_2"] ~= "0" then
							if v["port_"..port.."_server_1"] ~= "0" then
								more_info[cnt] = more_info[cnt]..i18n.translate("Master Server").." : "..uci.get_siptrunk_server(v["port_"..port.."_server_1"]).."<br>"
							end
							if v["port_"..port.."_server_2"] ~= "0" then
								more_info[cnt] = more_info[cnt]..i18n.translate("Slave Server").." : "..uci.get_siptrunk_server(v["port_"..port.."_server_2"]).."<br>"
							end
						end
						if v["port_"..port.."_server_2"] == "0" then
							more_info[cnt] = more_info[cnt]..i18n.translate("Slave Server").." : "..i18n.translate("Not Config").."<br>"
						end
						more_info[cnt] = more_info[cnt]..i18n.translate("Username")..": "..(v["username_"..port] or v["number_"..port]).."<br>"
						more_info[cnt] = more_info[cnt]..i18n.translate("Auth Username")..": "..(v["authuser_"..port] or v["user_name_"..port] or v["number_"..port]).."<br>"
						more_info[cnt] = more_info[cnt]..i18n.translate("Specify Transport Protocol on Register URL")..": "..( i18n.translate(v["reg_url_with_transport_"..port] == "on" and "On" or "Off")).."<br>"
						more_info[cnt] = more_info[cnt]..i18n.translate("Expire Seconds")..": "..(v["expire_seconds_"..port] or "1800").."<br>"
						more_info[cnt] = more_info[cnt]..i18n.translate("Retry Seconds")..": "..(v["retry_seconds_"..port] or "60").."<br>"
					end

					if v["hotline_"..port] and "on" == v["hotline_"..port] then
						more_info[cnt] = more_info[cnt]..i18n.translate("Hot Line").." : "..v["hotline_"..port.."_number"].." / "..(("10"==v["hotline_"..port.."_time"]) and i18n.translate("Immediately") or i18n.translatef("%d Second",tonumber(v["hotline_"..port.."_time"])/1000)).."</br>"
					else
						more_info[cnt] = more_info[cnt]..i18n.translate("Hot Line").." : "..i18n.translate("Off").."</br>"
					end
					
					if v["forward_uncondition_"..port] and "Deactivate" ~= v["forward_uncondition_"..port] then
						more_info[cnt] = more_info[cnt]..i18n.translate("Call Forward Unconditional").." : "..i18n.translate("On").."->"..uci.get_destination_detail(v["forward_uncondition_"..port],v["forward_uncondition_dst_"..port]).."<br>"
					elseif "Deactivate" == v["forward_uncondition_"..port] then
						more_info[cnt] = more_info[cnt]..i18n.translate("Call Forward Unconditional").." : "..i18n.translate("Off").."<br>"
						if v["forward_busy_"..port] and "Deactivate" == v["forward_busy_"..port] then
							more_info[cnt] = more_info[cnt]..i18n.translate("Call Forward Busy").." : "..i18n.translate("Off").."<br>"
						elseif v["forward_busy_"..port] then
							more_info[cnt] = more_info[cnt]..i18n.translate("Call Forward Busy").." : "..i18n.translate("On").."->"..uci.get_destination_detail(v["forward_busy_"..port],v["forward_busy_dst_"..port]).."<br>"
						end
						
						if v["forward_noreply_"..port] and "Deactivate" == v["forward_noreply_"..port] then
							more_info[cnt] = more_info[cnt]..i18n.translate("Call Forward No Reply").." : "..i18n.translate("Off").."<br>"
						else
							more_info[cnt] = more_info[cnt]..i18n.translate("Call Forward No Reply").." : "..i18n.translate("On").."->"..uci.get_destination_detail(v["forward_noreply_"..port],v["forward_noreply_dst_"..port])
							if v["forward_noreply_timeout_"..port] then
								more_info[cnt] = more_info[cnt].."/"..v["forward_noreply_timeout_"..port].."<br>"
							else
								more_info[cnt] = more_info[cnt].."<br>"
							end
						end
					end
					if v["callin_filter_"..port] == "blacklist" or v["callin_filter_"..port] == "whitelist" then
						local filter_idx = (v["callin_filter_"..port] == "blacklist" and v["callin_filter_blacklist_"..port] or v["callin_filter_whitelist_"..port])
						more_info[cnt] = more_info[cnt]..i18n.translate("Call In Filter").." : "..(v["callin_filter_"..port] == "blacklist" and i18n.translate("Black List") or i18n.translate("White List"))
						local filter_name
						for x,y in pairs(number_rule) do
							if filter_idx == y.index and y.name then
								filter_name = filter_idx.."-< "..y.name.." >"
								break
							end
						end
						if filter_name then
							more_info[cnt] = more_info[cnt].." / "..filter_name.."<br>"
						else
							more_info[cnt] = more_info[cnt].." / <font style='background:red'>"..(filter_idx or i18n.translate("Error")).."-< "..i18n.translate("Error").." ></font><br>"
						end
					else
						more_info[cnt] = more_info[cnt]..i18n.translate("Call In Filter").." : "..i18n.translate("Off").."<br>"
					end
					if v["callout_filter_"..port] == "blacklist" or v["callout_filter_"..port] == "whitelist" then
						local filter_idx = (v["callout_filter_"..port] == "blacklist" and v["callout_filter_blacklist_"..port] or v["callout_filter_whitelist_"..port])
						more_info[cnt] = more_info[cnt]..i18n.translate("Call Out Filter").." : "..(v["callout_filter_"..port] == "blacklist" and i18n.translate("Black List") or i18n.translate("White List"))
						local filter_name
						for x,y in pairs(number_rule) do
							if filter_idx == y.index and y.name then
								filter_name = filter_idx.."-< "..y.name.." >"
								break
							end
						end
						if filter_name then
							more_info[cnt] = more_info[cnt].." / "..filter_name.."<br>"
						else
							more_info[cnt] = more_info[cnt].." / <font style='background:red'>"..(filter_idx or i18n.translate("Error")).."-< "..i18n.translate("Error").." ></font><br>"
						end
					else
						more_info[cnt] = more_info[cnt]..i18n.translate("Call Out Filter").." : "..i18n.translate("Off").."<br>"
					end

					more_info[cnt] = more_info[cnt]..i18n.translate("Input Gain").." : "..(v["dsp_input_gain_"..port] or "0").."dB".."<br>"
					more_info[cnt] = more_info[cnt]..i18n.translate("Output Gain").." : "..(v["dsp_output_gain_"..port] or "0").."dB".."<br>"
					more_info[cnt] = more_info[cnt]..i18n.translate("Work Mode").." : "..("1" == v.work_mode and "POS" or i18n.translate("Voice")).."<br>"
					status[cnt] = v.status
					edit[cnt] = ds.build_url("admin","extension","fxs","fxs",k,"edit",tostring(port))
					delchk[cnt] = "return true;"
					uci_cfg[cnt] = "endpoint_fxso." .. k
					table.insert(content,tmp)
					break
				end
			end
		end
	 end

	luci.template.render("cbi/configlist",{
		title = i18n.translate("Extension / FXS"),
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

function ringgroup()
	local MAX_RING_GRP = 32
	local uci = require "luci.model.uci".cursor()
	local freeswitch = require "luci.scripts.fs_server"
	local ds = require "luci.dispatcher"
	local i18n = require "luci.i18n"

	uci:check_cfg("endpoint_ringgroup")
	uci:check_cfg("endpoint_sipphone")
	uci:check_cfg("endpoint_fxso")
	uci:check_cfg("route")

	local del_target = luci.http.formvaluetable("Delete")
	if next(del_target) then
		uci:delete_section(del_target,"route.endpoint")
	end

	if luci.http.formvalue("New") then
		local created = uci:section("endpoint_ringgroup","group")
		uci:save("endpoint_ringgroup")
		luci.http.redirect(ds.build_url("admin","extension","ringgroup","ringgroup",created,"add"))
		return
	end

	local th = {"Index","Name","Members","Strategy"}
	local colgroup = {"5%","10%","56%","20%","7%"}
	local content = {}
	local edit = {}
	local delchk = {}
	local uci_cfg = {}
	local more_info = {}
	local addnewable = true
	local cnt = 0
	local ringgrp = uci:get_all("endpoint_ringgroup")
	for i=1,MAX_RING_GRP do
		for k,v in pairs(ringgrp) do
			if v.index and v.name and i == tonumber(v.index) then
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
						v = i18n.translate("FXS Extension")
					end

					table.insert(td[3],v)
				end

				td[4] = i18n.translate(v.strategy or "")

				more_info[cnt] = ""
				if v.number then
					more_info[cnt] = more_info[cnt]..i18n.translate("Ring Group Number").." : "..v.number.."<br>"
				end
				if v.did then
					more_info[cnt] = more_info[cnt]..i18n.translate("DID").." : "..v.did.."<br>"
				end
				if v.ringtime then
					more_info[cnt] = more_info[cnt]..i18n.translate("Ring Time(5s~60s)").." : "..v.ringtime.."<br>"
				end
				edit[cnt] = ds.build_url("admin","extension","ringgroup","ringgroup",k,"edit")
				delchk[cnt] = uci:check_cfg_deps("endpoint_ringgroup",k,"route.endpoint")
				uci_cfg[cnt] = "endpoint_ringgroup." .. k
				table.insert(content,td)
				break
			elseif not v.index or not v.name then
				uci:delete("endpoint_ringgroup",k)
			end
		end
	end
	if MAX_RING_GRP == cnt then
		addnewable = false
	end
	luci.template.render("cbi/configlist",{
		title = i18n.translate("Extension / Ring Group"),
		colgroup = colgroup,
		split_col = 4,
		classname = "paddingtight",
		th = th,
		content = content,
		more_info = more_info,
		edit = edit,
		delchk = delchk,
		uci_cfg = uci_cfg,
		addnewable = addnewable,
		})
end