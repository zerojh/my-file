require "mxml"
require "ESL"
require "luci.util"
	
module ("luci.scripts.luci_load_scripts", package.seeall)

local exe = os.execute
local fs = require "nixio.fs"
local uci = require "luci.model.uci".cursor()
local util = require "luci.util"
local backup_dir = "/tmp/backup_xml"
local xml_dir = "/etc/freeswitch/conf"
local scripts_dir = "/usr/lib/lua/luci/scripts"

function check_all_cfg()
	local file_check_list = {"profile_time","profile_number","profile_manipl","profile_codec","fax","profile_sip",
							 "profile_fxso","profile_mobile","provision","endpoint_siptrunk","endpoint_fxso",
							 "endpoint_mobile","endpoint_ringgroup","endpoint_routegroup","route","feature_code"}
	for k,v in pairs(file_check_list) do
		uci:check_cfg(v)
	end
end

if not fs.access(backup_dir) then
	exe("mkdir "..backup_dir)
	exe("mkdir "..backup_dir.."/sip_profiles")
	exe("mkdir "..backup_dir.."/gateways")
	exe("mkdir "..backup_dir.."/dialplan")
end

--@ backup old xml file
function backup_xml()
	exe("cp "..xml_dir.."/sip_profiles/*.xml "..backup_dir.."/sip_profiles")
	exe("cp "..xml_dir.."/sip_profiles/external/*.xml "..backup_dir.."/gateways")
	exe("cp "..xml_dir.."/dialplan/public/*.xml "..backup_dir.."/dialplan")
	exe("cp "..xml_dir.."/autoload_configs/gsmopen.conf.xml "..xml_dir.."/autoload_configs/freetdm.conf.xml "..backup_dir)
	exe("cp "..xml_dir.."/autoload_configs/c300_dsp.conf.xml "..xml_dir.."/autoload_configs/cdr_sqlite.conf.xml "..backup_dir)
	exe("cp "..xml_dir.."/autoload_configs/switch.conf.xml "..xml_dir.."/autoload_configs/myfax.conf.xml "..backup_dir)
end

--@ compare xml with config for checking load operation whether success
function compare_xml_cfg(cfg,xml)
	if not fs.access("/etc/config/"..cfg) then
		exe("touch /etc/config/"..cfg)
	end
	local cfg_tb = uci:get_all(cfg)
	local root
	local flag = true
	local url
	local node
	if string.find(xml,"gsmopen.conf.xml") then
		if not fs.access(xml) then
			return false
		else
			root = mxml.parsefile(xml)
			if root == nil then
				return false
			end
		end
		url = "configuration/per_interface_settings"
		node = "interface"
		flag = false
	elseif string.find(xml,"freetdm.conf.xml") then
		if not fs.access(xml) then
			return false
		else
			root = mxml.parsefile(xml)
			if root == nil then
				return false
			end
		end
		url = "configuration/analog_spans"
		node = "span"
		flag = false
	else

	end

	if flag == true then
		--@ just find file by name
		for k,v in pairs(cfg_tb) do
			if cfg == "route" then
				if v.index and not fs.access(xml.."/r_"..(tonumber(v.index) < 10 and "0"..v.index or v.index)..".xml") then
					return false
				end
			elseif cfg == "feature_code" then
				if v.index and v.enable and v.enable == "on" and not fs.access(xml.."/f_"..v.index..".xml") then
					return false
				end
			elseif cfg == "endpoint_siptrunk" then
				if v.index and v.status and v.status == "Enabled" and not fs.access(xml.."/"..v.index..".xml") then
					return false
				end
			else
				if v.index and not fs.access(xml.."/"..v.index..".xml") then
					return false
				end
			end
		end
	else
		for k,v in pairs(cfg_tb) do
			if v.slot_type and v.status and v.status == "Enabled" then
				if not mxml.find(root,url,node,"name",v.slot_type) then
					return false
				end
			end
		end
	end
	return true
end

--@ Recover xml if load script fialed
function recover_xml()
	exe("mv "..backup_dir.."/sip_profiles/*".." "..xml_dir.."/sip_profiles")
	exe("mv "..backup_dir.."/freetdm.conf.xml".." "..xml_dir.."/autoload_configs")
	exe("mv "..backup_dir.."/gsmopen.conf.xml".." "..xml_dir.."/autoload_configs")
	exe("mv "..backup_dir.."/autoload_configs/c300_dsp.conf.xml "..backup_dir.."/autoload_configs/cdr_sqlite.conf.xml "..xml_dir)
	exe("mv "..backup_dir.."/autoload_configs/switch.conf.xml "..backup_dir.."/autoload_configs/myfax.conf.xml "..xml_dir)
	exe("mv "..backup_dir.."/sip_profiles/gateways/*".." "..xml_dir.."/sip_profiles/external")
	exe("mv "..backup_dir.."/dialplan/*".." "..xml_dir.."/dialplan/public")
end
function web_rpc_syn(timeout, server, method, ...)
	require "dpr"
	local ch = dpr.newrpc(server, "cli", "cli")
	local time = 0	
	ch:addparam("command", method)
	if number == type(timeout) then
		time = timeout
	else		
		time = tonumber(timeout)*1000
	end	
	for i,v in ipairs(arg) do
		ch:addparam("argv", tostring(v))
	end
	ch:call(time, false, cli_cb)
end

function compatibility_check_fax()
	uci:check_cfg("fax")
	local fax = uci:get_all("fax")
	local option = {}

	if not fax.main then
		option = {mode="t30",local_detect="false"}
		uci:create_section("fax","fax","main",option)
		uci:commit("fax")
	end
end

function compatibility_check()
	compatibility_check_fax()
end

function load_provision()
	require "ini"
	local cfg = uci:get_all("provision","provision")
	local ini = INI.load("/etc/provision/provision.conf")

	if not cfg then
		return false,"get cfg data error!"
	end

	if not ini or not ini['provision'] then
		return false,"file or branch not exist!"
	end

	ini['provision']['provision'] = (((cfg['enable'] or "0") == "1") and "yes") or "no"
	ini['provision']['repeate'] = cfg['repeat'] or "yes"
	ini['provision']['interval'] = cfg['interval'] or "3600"
	ini['provision']['url'] = cfg['url'] or ""
	ini['provision']['username'] = cfg['username'] or ""
	ini['provision']['password'] = cfg['password'] or ""
	ini['provision']['proxy'] = cfg['proxy'] or ""
	ini['provision']['proxy_username'] = cfg['proxy_username'] or ""
	ini['provision']['proxy_password'] = cfg['proxy_password'] or ""

	INI.save("/etc/provision/provision.conf", ini)
	web_rpc_syn(5000,"provision","reload_config")
	return true,"success"
end

function load_cdr()
	if true == get_cdr_is_enable() then
		return set_cdr_module_xml("on")
	else
		return set_cdr_module_xml("off")
	end
end

function get_cdr_is_enable()
	local x = uci:get_all("system","main")
	if x.mod_cdr and "on" == x.mod_cdr then
		return true
	else
		return false
	end
end

function add_param_name_value(parent_node,name,value)
	if parent_node  and name  and value then
		param = mxml.newnode(parent_node,"param")
		mxml.setattr(param,"name",name)
		mxml.setattr(param,"value",value)
	end
end

function set_dsp_xml()
	local root = mxml.parsefile("/etc/freeswitch/conf/autoload_configs/c300_dsp.conf.xml")
	if root then
		local plc = mxml.find(root,"configuration/settings","param","name","plc_enable")
		if not plc then
			local modules_node = mxml.find(root,"configuration","settings")
			plc = mxml.newnode(modules_node,"param")
			mxml.setattr(plc,"name","plc_enable")
		end
		if uci:get("callcontrol","voice","plc") then
			mxml.setattr(plc,"value","1")
		else
			mxml.setattr(plc,"value","0")
		end

		local dtmf = mxml.find(root,"configuration/settings","param","name","dtmf_detect_intval")
		if not dtmf then
			local modules_node = mxml.find(root,"configuration","settings")
			dtmf = mxml.newnode(modules_node,"param")
			mxml.setattr(dtmf,"name","dtmf_detect_intval")
		end
		if uci:get("callcontrol","voice","dtmf_detect_interval") then
			mxml.setattr(dtmf,"value",uci:get("callcontrol","voice","dtmf_detect_interval"))
		else
			mxml.setattr(dtmf,"value","0")
		end
		mxml.savefile(root,"/etc/freeswitch/conf/autoload_configs/c300_dsp.conf.xml")
		mxml.release(root)
	else
		return false,"parse dsp conf fail!"
	end
	return true,"success"
end

function set_fax_xml()
	local param
	local fax = uci:get_all("fax")

	if not fax or not fax.main or not fax.t30 or not fax.t38 then
		return false,"read config fail"
	end

	local xml = mxml:newxml()
	local conf = mxml.newnode(xml,"configuration")
	mxml.setattr(conf,"name","myfax.conf")
	mxml.setattr(conf,"description","Fax Configuration")

	local settings = mxml.newnode(conf,"fax-settings")
	add_param_name_value(settings,"fax-mode",fax.main.mode or "t30")
	add_param_name_value(settings,"local-detect",(fax.main.local_detect == "1") and "true" or "false")
	add_param_name_value(settings,"detect-cng",(fax.main.detect_cng == "1") and "true" or "false")
	
	local t30 = mxml.newnode(conf,"fax-t30-settings")
	add_param_name_value(t30,"ext-x-fax",(fax.t30.x_fax == "1") and "true" or "false")
	add_param_name_value(t30,"ext-fax",(fax.t30.fax == "1") and "true" or "false")
	add_param_name_value(t30,"ext-x-modem",(fax.t30.x_modem == "1") and "true" or "false")
	add_param_name_value(t30,"ext-modem",(fax.t30.modem == "1") and "true" or "false")

	local t38 = mxml.newnode(conf,"fax-t38-settings")
	add_param_name_value(t38,"t38useecm",(fax.t38.ecm == "1") and "true" or "false")
	add_param_name_value(t38,"t38maxbitrate",fax.t38.rate or 9600)
	add_param_name_value(t38,"t38faxversion",0)
	add_param_name_value(t38,"t38faxfillbitremoval",1)
	add_param_name_value(t38,"t38faxtranscodingmmr",0)
	add_param_name_value(t38,"t38faxtranscodingjbig",0)
	add_param_name_value(t38,"t38faxratemanagement","transferredTCF")
	add_param_name_value(t38,"t38maxbuffer",2000)
	add_param_name_value(t38,"t38faxmaxdatagram",400)
	add_param_name_value(t38,"t38faxudpec","t38UDPRedundancy")
	add_param_name_value(t38,"t38vendorinfo","0 0 0")

	mxml.savefile(xml,"/etc/freeswitch/conf/autoload_configs/myfax.conf.xml")
	mxml.release(xml)

	return true,"success"
end
function set_cdr_module_xml(param)
	local root = mxml.parsefile("/etc/freeswitch/conf/autoload_configs/cdr_sqlite.conf.xml")
	if root then
		local cdr_sqlite = mxml.find(root,"configuration/settings","param","name","db-insert-server")
		if not cdr_sqlite then
			local modules_node = mxml.find(root,"configuration","settings")
			cdr_sqlite = mxml.newnode(modules_node,"param")
			mxml.setattr(cdr_sqlite,"name","db-insert-server")
		end
		if "off" == param then
			mxml.setattr(cdr_sqlite,"value","disable")
		else
			mxml.setattr(cdr_sqlite,"value","enable")
		end
		mxml.savefile(root,"/etc/freeswitch/conf/autoload_configs/cdr_sqlite.conf.xml")
		mxml.release(root)
	else
		return false,"parse cdr_sqlite conf fail!"
	end
	return true,"success"
end

function refresh_rtp_portrange()
	local cfg = uci:get_all("callcontrol","voice")

	if not cfg or not cfg.rtp_start_port or not cfg.rtp_end_port then
		return false,"read config fail!"
	end

	local root = mxml.parsefile("/etc/freeswitch/conf/autoload_configs/switch.conf.xml")
	if root then
		local rtp = mxml.find(root,"configuration/settings","param","name","rtp-start-port")
		if rtp then
			mxml.setattr(rtp,"value",cfg.rtp_start_port or 16000)
		else
			local modules_node = mxml.find(root,"configuration","settings")
			add_param_name_value(modules_node,"rtp-start-port",cfg.rtp_start_port or 16000)
		end

		rtp = mxml.find(root,"configuration/settings","param","name","rtp-end-port")
		if rtp then
			mxml.setattr(rtp,"value",cfg.rtp_end_port or 16200)
		else
			local modules_node = mxml.find(root,"configuration","settings")
			add_param_name_value(modules_node,"rtp-end-port",cfg.rtp_end_port or 16200)
		end
	else
		return false,"parse switch conf fail!"
	end

	mxml.savefile(root,"/etc/freeswitch/conf/autoload_configs/switch.conf.xml")
	mxml.release(root)

	--@ echo
	os.execute("echo "..cfg.rtp_start_port.."-"..cfg.rtp_end_port.." >/proc/sys/net/ipv4/ip_local_reserved_ports")
	
	return true,"success"
end

function get_all_configed_gw()
	local uci = require "luci.model.uci".cursor()

	local trunk = {}
	local trunk_list = {}
	local trunk_list_tmp = {}
	local profile_list = {}
	local trunk_list_str = ""

	trunk = uci:get_all("endpoint_siptrunk")
    for k,v in pairs(trunk) do
    	if v.index and v.profile then
	    	table.insert(trunk_list,{gw_name=v.profile.."+"..v.index,gw_profile=v.profile})
	    	trunk_list_tmp[v.index] = v.profile.."+"..v.index
	    	profile_list[v.index] = v.profile
	    	trunk_list_str = trunk_list_str..v.profile.."+"..v.index..","
    	end
    end

    trunk = uci:get_all("endpoint_fxso")
	for k,v in pairs(trunk) do
		if "Enabled" == v.status then
			if v.port_1_reg and "on" == v.port_1_reg and v.number_1 then
				if v.port_1_server_1 and 0 ~= tonumber(v.port_1_server_1) and trunk_list_tmp[v.port_1_server_1] then
					table.insert(trunk_list,{gw_name=trunk_list_tmp[v.port_1_server_1].."-"..v.slot_type.."-"..v.number_1,gw_profile=profile_list[v.port_1_server_1]})
					trunk_list_str = trunk_list_str..trunk_list_tmp[v.port_1_server_1].."-"..v.slot_type.."-"..v.number_1..","
				end
				if v.port_1_server_2 and 0 ~= tonumber(v.port_1_server_2) and trunk_list_tmp[v.port_1_server_2] then
					table.insert(trunk_list,{gw_name=trunk_list_tmp[v.port_1_server_2].."-"..v.slot_type.."-"..v.number_1,gw_profile=profile_list[v.port_1_server_2]})
					trunk_list_str = trunk_list_str..trunk_list_tmp[v.port_1_server_2].."-"..v.slot_type.."-"..v.number_1..","
				end
			end
			if v.port_2_reg and "on" == v.port_2_reg and v.number_2 then
				if v.port_2_server_1 and 0 ~= tonumber(v.port_2_server_1) and trunk_list_tmp[v.port_2_server_1] then
					table.insert(trunk_list,{gw_name=trunk_list_tmp[v.port_2_server_1].."-"..v.slot_type.."-"..v.number_2,gw_profile=profile_list[v.port_2_server_1]})
					trunk_list_str = trunk_list_str..trunk_list_tmp[v.port_2_server_1].."-"..v.slot_type.."-"..v.number_2..","
				end
				if v.port_2_server_2 and 0 ~= tonumber(v.port_2_server_2) and trunk_list_tmp[v.port_2_server_2] then
					table.insert(trunk_list,{gw_name=trunk_list_tmp[v.port_2_server_2].."-"..v.slot_type.."-"..v.number_2,gw_profile=profile_list[v.port_2_server_2]})
					trunk_list_str = trunk_list_str..trunk_list_tmp[v.port_2_server_2].."-"..v.slot_type.."-"..v.number_2..","
				end
			end
		end 
	end

	trunk = uci:get_all("endpoint_mobile")
	for k,v in pairs(trunk) do
		if "Enabled" == v.status then
			if v.port_reg and "on" == v.port_reg and v.number then
				if v.port_server_1 and 0 ~= tonumber(v.port_server_1) and trunk_list_tmp[v.port_server_1] then
					table.insert(trunk_list,{gw_name=trunk_list_tmp[v.port_server_1].."-"..v.slot_type.."-"..v.number,gw_profile=profile_list[v.port_server_1]})
					trunk_list_str = trunk_list_str..trunk_list_tmp[v.port_server_1].."-"..v.slot_type.."-"..v.number..","
				end
				if v.port_server_2 and 0 ~= tonumber(v.port_server_2) and trunk_list_tmp[v.port_server_2] then
					table.insert(trunk_list,{gw_name=trunk_list_tmp[v.port_server_2].."-"..v.slot_type.."-"..v.number,gw_profile=profile_list[v.port_server_2]})
					trunk_list_str = trunk_list_str..trunk_list_tmp[v.port_server_2].."-"..v.slot_type.."-"..v.number..","
				end
			end
		end 
	end

	return trunk_list,trunk_list_str
end

function freeswitch_reload(param)
	local con = ESL.ESLconnection("127.0.0.1","8021","ClueCon")
	local uci = require "luci.model.uci".cursor()
	local running_profile = {}

	if "table" ~= type(param) then
		return false,"Connect Param Err !"
	end
	if con:connected() ~= 1 then
		return false,"Connect Server Fail !"
	end
	
	if param.sipprofile or param.sipendpoint or param.profile_changes then
		local running_gateway = {}
		local running_gateway_str = ""
		local allprofile = {}
		local allgateway = {}
		local allgateway_str = ""
		local profilechanges = {}
		local profilechanges_str = param.profile_changes

 		-- get all config profile--
	    local sip_profile = uci:get_all("profile_sip")
	    for k,v in pairs(sip_profile) do
	    	if v.index then
	    		table.insert(allprofile,v.index)
	    	end
	    end

	    allgateway,allgateway_str = get_all_configed_gw()

		-- get running_profile profile--
		local str_profile = con:api("sofia status"):getBody()

	    local start_index = string.find(str_profile,"=\n")
	    local end_index = string.find(str_profile,"\n",start_index+2)
	    local total_len = string.find(str_profile,"\n=",start_index)

	    while start_index < total_len and end_index <= total_len do
	        local current_line = string.sub(str_profile,start_index+2,end_index)
	        if not string.find(current_line,"::") then
	            local profile_name = current_line:match("^%s+(.*)%s+profile.*@[0-9.:]+%s*")
	            table.insert(running_profile,profile_name)
	        else
        		local gw_profile,gw_name = current_line:match("^%s*(.*)::(.*)%s+gateway")

        		if param.endpoint_changes and string.find(param.endpoint_changes,gw_name..",") or string.find(allgateway_str,gw_name..",") then
        			if profilechanges_str and (not string.find(profilechanges_str,gw_profile..",")) then
        				profilechanges_str = profilechanges_str .. gw_profile .. ","
        			end
        		end
        		table.insert(running_gateway,gw_name)
        		running_gateway_str = running_gateway_str..gw_name..","
	        end
	        start_index = string.find(str_profile,"\n",end_index)
	        end_index = string.find(str_profile,"\n",start_index+1)
	    end

	    for k,v in ipairs(allgateway) do
	    	if not string.find(running_gateway_str,v.gw_name..",") then
	    		if profilechanges_str and (not string.find(profilechanges_str,v.gw_profile..",")) then
    				profilechanges_str = profilechanges_str .. v.gw_profile .. ","
    			end
	    	end
	    end

	    --get all related changed profile--
		if profilechanges_str then
			profilechanges = luci.util.split(profilechanges_str,",")
		end

	    -- step 1: stop unexist -- 

	    for k,v in ipairs(running_profile) do
	    	local flag = true
	    	for i,j in ipairs(allprofile) do
	    		if v == j then
	    			flag = false
	    			break
	    		end
	    	end
	    	if flag then
	    		con:api("sofia profile "..v.." stop")
	    		table.remove(running_profile,k)
	    	end
	    end

	    -- step 2: restart changes -- 
	    if profilechanges_str then
		    for k,v in ipairs(running_profile) do
		    	for i,j in ipairs(profilechanges) do
		    		if v == j then
		    			con:api("sofia profile "..v.." restart")
		    		end
		    	end
		    end
		else
			con:api("sofia profile restart all")
		end
		
	    -- step 3: start new profile --
	    for k,v in ipairs(allprofile) do
	    	local flag = true
	    	for i,j in ipairs(running_profile) do
	    		if v == j then
	    			flag = false
	    			break
	    		end
	    	end
	    	if flag then
	    		con:api("sofia profile "..v.." start")
	    	end
	    end
	    if param.sipextension then
			exe("sleep 2")--wait profile init finish
		end
	end

	if param.sipextension then
		local running_user = {}
		--get all online user--
		if not next(running_profile) then
			local str_profile = con:api("sofia status"):getBody()
			local start_index = string.find(str_profile,"=\n")
			local end_index = string.find(str_profile,"\n",start_index+2)
			local total_len = string.find(str_profile,"\n=",start_index)

			while start_index < total_len and end_index <= total_len do
				local current_line = string.sub(str_profile,start_index+2,end_index)
				if not string.find(current_line,"::") then
					local profile_name = current_line:match("^%s+(.*)%s+profile.*@[0-9.:]+%s*")
					table.insert(running_profile,profile_name)
				end
				start_index = string.find(str_profile,"\n",end_index)
				end_index = string.find(str_profile,"\n",start_index+1)
			end
		end
		for k,v in ipairs(running_profile) do
			local reg_info = con:api("sofia status profile "..v.." reg"):getBody()
			if reg_info and not reg_info:match("returned: 0") then
				local start_index = string.find(reg_info,"=\n")
				local end_index = string.find(reg_info,"\n\n",start_index+2)
				local total_len = string.find(reg_info,"\n=",start_index)
				while end_index and start_index < total_len and end_index <= total_len do
					local user_info = string.sub(reg_info,start_index+2,end_index)
					local user = user_info:match("Auth%-User:%s*(.+)\nAuth")
					local domain = user_info:match("Auth%-Realm:%s*(.+)\nMWI")
					running_user[user]={["domain"]=domain,["profile"]=v}
					start_index = end_index+2
					end_index = string.find(reg_info,"\n\n",start_index+1)
				end
			end
		end
		-- flush disabled/unexist user--
		for k,v in pairs(running_user) do
			local flag = true
			for i,j in pairs(uci:get_all("endpoint_sipphone") or {}) do
				if k == j.user and v.profile == j.profile and "Enabled" == j.status then
					flag = false
					break
				end
			end
			if flag then
				con:api("sofia profile "..v.profile.." flush_inbound_reg "..k.."@"..v.domain)
			end
		end
	end

	con:api("reloadxml")
	
	con:disconnect()
	
	return true
end

function add_to_list(list, msg)
	if "" ~= list then
		return list .. " , " .. msg
	else
		return msg
	end
end

function config_ddns()
	local update_url_tbl = 
	{
	  ["dyn.com"] = "http://[USERNAME]:[PASSWORD]@members.dyndns.com/nic/update?hostname=[DOMAIN]&myip=[IP]",
	  ["changeip.com"] = "http://[USERNAME]:[PASSWORD]@nic.changeip.com/nic/update?u=[USERNAME]&p=[PASSWORD]&cmd=update&hostname=[DOMAIN]&ip=[IP]",
	  ["he.net"] = "http://[DOMAIN]:[PASSWORD]@dyn.dns.he.net/nic/update?hostname=[DOMAIN]&myip=[IP]",
	  ["ovh.com"] = "http://[USERNAME]:[PASSWORD]@www.ovh.com/nic/update?system=dyndns&hostname=[DOMAIN]&myip=[IP]",
	  ["dnsomatic.com"] = "http://[USERNAME]:[PASSWORD]@updates.dnsomatic.com/nic/update?hostname=[DOMAIN]&myip=[IP]",
	  ["3322.org"] = "http://[USERNAME]:[PASSWORD]@members.3322.org/dyndns/update?system=dyndns&hostname=[DOMAIN]&myip=[IP]",
	  ["easydns.com"] = "http://[USERNAME]:[PASSWORD]@api.cp.easydns.com/dyn/tomato.php?hostname=[DOMAIN]&myip=[IP]",
	  ["twodns.de"] = "http://[USERNAME]:[PASSWORD]@update.twodns.de/update?hostname=[DOMAIN]&ip=[IP]",
	  ["oray.com"] = "http://[USERNAME]:[PASSWORD]@ddns.oray.com/ph/update?hostname=[DOMAIN]&myip=[IP]"
	}

	local service_str = uci:get("ddns","myddns_ipv4","service_name")
	local service_str_type = uci:get("ddns","myddns_ipv4","service_name_list")
	if "custom" ~= service_str_type then
		for k,v in pairs(update_url_tbl) do
			if service_str == k then
				local update_url_str = update_url_tbl[service_str]
				uci:set("ddns","myddns_ipv4","update_url",update_url_str)
				uci:commit("ddns")
				return true
			end
		end
	end
	
	return true
end

function config_firewall()
	--local network_mode = uci:get_all("network","wan") and "route" or "bridge"
	local sip_profile = uci:get_all("profile_sip") or {}
	local firewall_cfg = uci:get_all("firewall") or {}
	
	--@ if network is route mode,check the sip profile port
	--@ if network is route mode,check the rtp port
	--@ if network is route mode,check the http,https,telnet,ssh port
	--@ if network is route mode,check the firewall control
		local enabled_firewall
		local enabled_http
		local enabled_https
		local enabled_telnet
		local enabled_ssh
		local default_action 
		
		local rule_http_sec
		local rule_https_sec
		local rule_ssh_sec
		local rule_telnet_sec
		local rule_rtp_sec
		local zone_wan_sec
		local zone_lan_sec
		local rule_sip_sec_tb = {}
		
		local redirect_http_sec
		local redirect_https_sec
		local redirect_ssh_sec
		local redirect_telnet_sec
		local redirect_rtp_sec
		local redirect_l2tp_sec
		local redirect_pptp_sec
		local redirect_sip_sec_tb = {}
		local rule_section_tb = {}
		
		for k,v in pairs(firewall_cfg) do
			if v['.type'] == "defaults" then
				enabled_firewall = v.enabled or "0"
				enabled_http = v.enabled_http or "0"
				enabled_https = v.enabled_https or "0"
				enabled_ssh = v.enabled_ssh or "0"
				enabled_telnet = v.enabled_telnet or "0"
				default_action = v.forward or "ACCEPT"
			elseif v['.type'] == "zone" and v.name == "lan" then
				zone_lan_sec = k
			elseif v['.type'] == "zone" and v.name == "wan" then
				zone_wan_sec = k
			elseif v['.type'] == "rule" and v.name == "Allow-SIP" then
				table.insert(rule_sip_sec_tb,k)
			elseif v['.type'] == "rule" and v.name == "Allow-http" then
				rule_http_sec = k
			elseif v['.type'] == "rule" and v.name == "Allow-https" then
				rule_https_sec = k
			elseif v['.type'] == "rule" and v.name == "Allow-ssh" then
				rule_ssh_sec = k
			elseif v['.type'] == "rule" and v.name == "Allow-telnet" then
				rule_telnet_sec = k
			elseif v['.type'] == "rule" and v.name == "Allow-RTP" then
				rule_rtp_sec = k
			elseif v['.type'] == "redirect" and v.name == "Allow-SIP" then
				table.insert(redirect_sip_sec_tb,k)
			elseif v['.type'] == "redirect" and v.name == "Allow-http" then
				redirect_http_sec = k
			elseif v['.type'] == "redirect" and v.name == "Allow-https" then
				redirect_https_sec = k
			elseif v['.type'] == "redirect" and v.name == "Allow-ssh" then
				redirect_ssh_sec = k
			elseif v['.type'] == "redirect" and v.name == "Allow-telnet" then
				redirect_telnet_sec = k
			elseif v['.type'] == "redirect" and v.name == "Allow-RTP" then
				redirect_rtp_sec = k
			elseif v['.type'] == "redirect" and v.name == "Allow-l2tp" then
				redirect_l2tp_sec = k
			elseif v['.type'] == "redirect" and v.name == "Allow-pptp" then
				redirect_pptp_sec = k
			elseif v['.type'] == "rule" and v.index and v.name then
				table.insert(rule_section_tb,k)
			end
		end

		--@ set zone network
		local tmp_tb = {}
		table.insert(tmp_tb,"wan")
		table.insert(tmp_tb,"wan2")
		for i=1,8 do
			--@ change interface name
			if uci:get_all("network","vwan"..i) then
				table.insert(tmp_tb,"vwan"..i)
			end
		end
		uci:set_list("firewall",zone_wan_sec,"network",tmp_tb)

		tmp_tb = {}
		table.insert(tmp_tb,"lan")
		for i=0,15 do
			if uci:get_all("network","vlan"..i) then
				table.insert(tmp_tb,"vlan"..i)
			end
		end
		uci:set_list("firewall",zone_lan_sec,"network",tmp_tb)
		--@ end
		
		--@ Lan -> WAN
		if default_action == "ACCEPT" or enabled_firewall == "0" then
			os.execute("echo  >/etc/firewall.user")
		else
			os.execute("echo 'iptables -D zone_lan_forward -m comment --comment \"forwarding lan -> wan\" -j zone_wan_dest_ACCEPT' >/etc/firewall.user")
		end
		
		--@ For nat
		os.execute("echo 'iptables -t nat -A zone_wan_postrouting -i br-lan -p tcp -j MASQUERADE --to-ports 30000-60000' >>/etc/firewall.user")
		os.execute("echo 'iptables -t nat -A zone_wan_postrouting -i br-lan -p udp -j MASQUERADE --to-ports 30000-60000' >>/etc/firewall.user")
		os.execute("echo 'iptables -t nat -D zone_wan_postrouting  -j MASQUERADE ' >>/etc/firewall.user")
		os.execute("echo 'iptables -t nat -A zone_wan_postrouting  -j MASQUERADE' >>/etc/firewall.user")
		os.execute("echo 'lua /usr/lib/lua/luci/scripts/ipaddr_add_dnat.lua' >>/etc/firewall.user")
		
		--@ WAN INPUT
		if enabled_firewall == "0" and zone_wan_sec then
			--@close
			uci:set("firewall",zone_wan_sec,"input","ACCEPT")
		elseif zone_wan_sec then
			--@open
			uci:set("firewall",zone_wan_sec,"input","REJECT")
		end
		
		--@ ip or mac filter
		if enabled_firewall == "0" then
			for k,v in pairs(rule_section_tb) do
				uci:set("firewall",v,"enabled",enabled_firewall)
			end
		end
		
		--@ sip port
		for k,v in pairs(sip_profile) do
			if v.localport and v.localinterface == "wan" then
				local redirect_flag = false
				local rule_falg = false
				
				--@ redirect
				for k,v in pairs(redirect_sip_sec_tb) do
					if v.localport == uci:get("firewall",v,"dest_port") then
						redirect_flag = true
						redirect_sip_sec_tb[k] = nil
						break
					end
				end
				--@ rule
				for k,v in pairs(rule_sip_sec_tb) do
					if v.localport == uci:get("firewall",v,"dest_port") then
						rule_falg = true
						rule_sip_sec_tb[k] = nil
						break
					end
				end
				
				if not rule_falg then
					--@ add
					uci:section("firewall","rule",nil,{name="Allow-SIP",src="wan",dest_port=v.localport,target="ACCEPT",enabled="1"})
				end
				if not redirect_flag then
					--@ add
					uci:section("firewall","redirect",nil,{name="Allow-SIP",src="wan",dest_port=v.localport,src_dport=v.localport,target="ACCEPT",enabled="1"})
				end				
			end
		end
		--@ delete old redirect
		for k,v in pairs(redirect_sip_sec_tb) do
			if v then
				uci:delete("firewall",v)
			end
		end
		--@ delete old rule
		for k,v in pairs(rule_sip_sec_tb) do
			if v then
				uci:delete("firewall",v)
			end
		end	
		--@ end
		
		--@ rtp port
		local rtp_port_start = uci:get("callcontrol","voice","rtp_start_port") or "16000"
		local rtp_port_end = uci:get("callcontrol","voice","rtp_end_port") or "16200"

		if rule_rtp_sec then
			uci:set("firewall",rule_rtp_sec,"dest_port",rtp_port_start.."-"..rtp_port_end)
		end
		
		if redirect_rtp_sec then
			uci:set("firewall",redirect_rtp_sec,"dest_port",rtp_port_start.."-"..rtp_port_end)
			uci:set("firewall",redirect_rtp_sec,"src_dport",rtp_port_start.."-"..rtp_port_end)
		end
		--@ end

		--@ http
		if enabled_http == "1" and rule_http_sec and redirect_http_sec then
			local http_port = uci:get("lucid","http","address") 
			local tmp_port

			if type(http_port) == "table" then
				tmp_port = http_port[1] == "37777" and (http_port[2] or "80") or http_port[1]
			else
				tmp_port = http_port
			end
			
			uci:set("firewall",rule_http_sec,"dest_port",tmp_port)
			uci:set("firewall",rule_http_sec,"enabled","1")
			uci:set("firewall",rule_http_sec,"target","ACCEPT")
			
			uci:set("firewall",redirect_http_sec,"src_dport",tmp_port)
			uci:set("firewall",redirect_http_sec,"dest_port",tmp_port)
			uci:set("firewall",redirect_http_sec,"enabled","1")			
		elseif rule_http_sec and redirect_http_sec then
			uci:set("firewall",rule_http_sec,"enabled","1")	
			uci:set("firewall",rule_http_sec,"target","REJECT")
			uci:set("firewall",redirect_http_sec,"enabled","0")	
		end
		--@ https
		if enabled_https == "1" and rule_https_sec and redirect_https_sec then
			local https_port = uci:get("lucid","https","address") 
			local tmp_port

			if type(https_port) == "table" then
				tmp_port = https_port[1]
			else
				tmp_port = https_port
			end
			
			uci:set("firewall",rule_https_sec,"dest_port",tmp_port)
			uci:set("firewall",rule_https_sec,"target","ACCEPT")
			uci:set("firewall",rule_https_sec,"enabled","1")
			
			uci:set("firewall",redirect_https_sec,"src_dport",tmp_port)
			uci:set("firewall",redirect_https_sec,"dest_port",tmp_port)
			uci:set("firewall",redirect_https_sec,"enabled","1")			
		elseif rule_https_sec and redirect_https_sec then
			uci:set("firewall",rule_https_sec,"enabled","1")		
			uci:set("firewall",rule_https_sec,"target","REJECT")
			uci:set("firewall",redirect_https_sec,"enabled","0")	
		end		
		--@ telnet
		if enabled_telnet == "1" and rule_telnet_sec and redirect_telnet_sec then
			local telnet_port = uci:get("system","telnet","port") or "23"
			uci:set("firewall",rule_telnet_sec,"dest_port",telnet_port)
			uci:set("firewall",rule_telnet_sec,"enabled","1")
			uci:set("firewall",rule_telnet_sec,"target","ACCEPT")
			
			uci:set("firewall",redirect_telnet_sec,"src_dport",telnet_port)
			uci:set("firewall",redirect_telnet_sec,"dest_port",telnet_port)
			uci:set("firewall",redirect_telnet_sec,"enabled","1")			
		elseif rule_telnet_sec and redirect_telnet_sec then
			uci:set("firewall",rule_telnet_sec,"enabled","1")		
			uci:set("firewall",rule_telnet_sec,"target","REJECT")
			uci:set("firewall",redirect_telnet_sec,"enabled","0")	
		end		
		--@ ssh
		if enabled_ssh == "1" and rule_ssh_sec and redirect_ssh_sec then
			local ssh_port = uci:get("dropbear","main","Port") or "22"
			uci:set("firewall",rule_ssh_sec,"dest_port",ssh_port)
			uci:set("firewall",rule_ssh_sec,"enabled","1")
			uci:set("firewall",rule_ssh_sec,"target","ACCEPT")	
			
			uci:set("firewall",redirect_ssh_sec,"src_dport",ssh_port)
			uci:set("firewall",redirect_ssh_sec,"dest_port",ssh_port)
			uci:set("firewall",redirect_ssh_sec,"enabled","1")			
		elseif rule_ssh_sec and redirect_ssh_sec then
			uci:set("firewall",rule_ssh_sec,"enabled","1")		
			uci:set("firewall",rule_ssh_sec,"target","REJECT")	
			uci:set("firewall",redirect_ssh_sec,"enabled","0")	
		end		
		--@ l2tpd
		if redirect_l2tp_sec then
			uci:set("firewall",redirect_l2tp_sec,"enabled",(uci:get("xl2tpd","l2tpd","enabled") or "0"))
		end
		--@ pptpd
		if redirect_pptp_sec then
			uci:set("firewall",redirect_pptp_sec,"enabled",(uci:get("pptpd","pptpd","enabled") or "0"))
		end
		
		--@ refresh dmz
		local dmz_enabled = uci:get("firewall","dmz","enabled")
		if dmz_enabled == "1" then
			local dmz_ip = uci:get("firewall","dmz","dest_ip")

			uci:delete("firewall","dmz")
			uci:section("firewall","redirect","dmz",{name="DMZ",src="wan",proto="tcp udp",dest_ip=dmz_ip,enabled="1"})
		end
		
		uci:commit("firewall")
		os.execute("/etc/init.d/firewall enable")
		os.execute("/etc/init.d/firewall restart")
end

function config_macfilter()
	--@ 
	local firewall_cfg = uci:get_all("firewall") 
	local mac_tb
	
	for k,v in pairs(firewall_cfg) do
		if v['.type'] == "filter" and v.tmp_mac then
			mac_tb = v.tmp_mac
			break
		end
	end

	--@ refresh macfilter cfg
	uci:check_cfg("macfilter")
	uci:delete_all("macfilter","filter")
		
	if mac_tb then
		for k,v in pairs(mac_tb) do
			if v then
				uci:create_section("macfilter","filter",nil,{mac=v})
			end
		end
	end
	
	uci:commit("macfilter")
	os.execute("/etc/init.d/macfilter restart")
end

function dhcp_set_dnsmasq_interface()
	local dhcp_profile = uci:get_all("dhcp") or {}
	local interface_tb = {}

	for k,v in pairs(dhcp_profile) do
		if v['.type'] == "dhcp" and v.interface then
			if v.interface then
				if uci:get("network",v.interface,"type") == "bridge" then
					table.insert(interface_tb,"br-"..v.interface)
				else
					table.insert(interface_tb,uci:get("network",v.interface,"ifname"))
				end
			end
			uci:set("dhcp",k,"force","1")
		end
	end

	if #interface_tb > 0 then
		uci:delete("dhcp","dnsmasq","interface")
		uci:set("dhcp","dnsmasq","interface",interface_tb)
	end
	uci:commit("dhcp")
end
function mwan3_set_strategy_route()
	local mwan3_profile = uci:get_all("mwan3") or {}
	local interface_option_tb = {enabled="1",track_ip="127.0.0.1",reliability="1",count="1",timeout="2",interval="5",down="3",up="3"}
	local member_option_tb = {metric="1",weight="3"}
	
	for k,v in pairs(mwan3_profile) do
		if v['.type'] == "rule" and v.use_policy then
			local interface_name = v.use_policy:match("_([a-z0-9]+)") or ""
			--@ policy 
			if not uci:get_all("mwan3",v.use_policy) then
				uci:create_section("mwan3","policy",v.use_policy,{use_member={"interface_"..interface_name}})
			end
			--@ member
			if not uci:get_all("mwan3","interface_"..interface_name) then
				member_option_tb.interface = interface_name
				uci:create_section("mwan3","member","interface_"..interface_name,member_option_tb)
			end
			--@ interface
			if not uci:get_all("mwan3",interface_name) then
				uci:create_section("mwan3","member",interface_name,interface_option_tb)
			end
		end
	end
	
	uci:commit("mwan3")
	return true
end

function network_set_static_route()
	local ret = true
 	local network_tb = uci:get_all("network") or {}

 	for k,v in pairs(network_tb) do
 		if v['.type'] == "route" and v.index and v.interface then
 			--@ set metric option
 			if v.interface:match("gre") then
 				uci:set("network",k,"metric","11")
 			else
 				uci:set("network",k,"metric",v.index)
 			end
 			--@ set table option
 			if v.interface:match("vwan") then
 				uci:set("network",k,"table",10+tonumber(v.interface:match("([0-9]+)")))
 			elseif v.interface:match("vlan") then
 				local tmp_vwan = uci:get("network",v.interface,"wan_sub_link")
 				if tmp_vwan then
 					uci:set("network",k,"table",10+tonumber(tmp_vwan:match("([0-9]+)")))
 				else
 					uci:delete("network",k,"table")
 				end
 			else
 				uci:delete("network",k,"table")
 			end
 		end
 	end

	uci:commit("network")
	--@ update l2tp/pptp client route
	exe("/etc/init.d/updatevpnroute start")
 	return ret
end

function config_vlan_port()
	local network_profile = uci:get_all("network") or {}

	for k,v in pairs(network_profile) do
		--@ get "access" type port
		if "switch_port" == v['.type'] and "2" == v.tagged and v.port then
			local flag_idle = true
			
			for k2,v2 in pairs(network_profile) do
				if "switch_vlan" == v2['.type'] and v2.ports and string.find(v2.ports,v.port) and v2.vid then
					uci:set("network",k,"pvid",v2.vid)
					flag_idle = false
					break
				end
			end
			--@ reset to default pvid , belong to br-lan
			if flag_idle then
				uci:set("network",k,"pvid","1")
			end
		end
	end

	uci:commit("network")

	return true
end

function config_portal_account()
	local portal_profile = uci:get_all("profile_portal") or {}
	local port_account_dir = "/etc/portal_account.txt"
	
	if fs.access(port_account_dir) then
		exe("rm "..port_account_dir)
	end

	local _file = io.open(port_account_dir,"w+")
	if _file then
		for k,v in pairs(portal_profile) do
			if v.username and v.password then
				local str = ""

				str = str..v.username.." "..v.password.." "..(v.multipath or "").." "..(v.logintries or "").." "..(v.ipaddr or "0.0.0.0").." "..(v.macaddr or "00:00:00:00:00:00").."\n"

				_file:write(str)
			end
		end

		_file:close()
	end
	
	return true
end

function config_vlan_proto()
	local network_cfg = uci:get_all("network") or {}
	local wireless_cfg = uci:get_all("wireless") or {}

	for k,v in pairs(network_cfg) do
		if v['.type'] == "interface" and k:match("^vlan") then
			local flag_include = false
			
			for k2,v2 in pairs(wireless_cfg) do
				if v2['.type'] == "wifi-iface" and v2.network == k then
					flag_include = true
					break
				end
			end

			if flag_include then
				uci:set("network",k,"type","bridge")
			else
				uci:delete("network",k,"type")
			end
		end
	end

	uci:commit("network")
end
function autovpn(param)
	if param.domainlist or param.restore or param.upgrade then
		local s = uci:get("domainlist_tmp","domain_list","domain") or {}
		fs.writefile("/etc/config/domainlist",table.concat(s,"\n"))
	end
	exe("/etc/init.d/autovpn restart")
	return true
end
function check_xl2tpd_enabled()
	local t = uci:get_all("xl2tpd")
	local l2tpd_flag = uci:get("xl2tpd","l2tpd","enabled") or "0"
	local main_flag = uci:get("xl2tpd","main","enabled") or "0"
	local default_flag = ("0" == l2tpd_flag and "0" == main_flag) and "0" or "1"
	for k,v in pairs(t) do
		if v[".type"] == "default" then
			uci:set("xl2tpd",k,"enabled",default_flag)
			uci:commit("xl2tpd")
			break
		end
	end
end
function check_sip_trunk_ref()
	local sipt = {}
	for k,v in pairs(uci:get_all("endpoint_siptrunk") or {}) do
		if v.index and v.profile then
			sipt[v.index]=v.profile
		end
	end
	local flag=false
	for k,v in pairs(uci:get_all("endpoint_fxso") or {}) do
		if v[".type"] == "fxs" then
			if v.forward_uncondition_1 and v.forward_uncondition_1:match("^SIPT%-%d+_%d+") then
				local profile,idx = v.forward_uncondition_1:match("^SIPT%-(%d+)_(%d+)")
				if sipt[idx] ~= profile then
					uci:set("endpoint_fxso",k,"forward_uncondition_1","SIPT-"..(sipt[idx] or "unknown").."_"..idx)
					uci:save("endpoint_fxso")
					flag=true
				end
			end
			if v.forward_busy_1 and v.forward_busy_1:match("^SIPT%-%d+_%d+") then
				local profile,idx = v.forward_busy_1:match("^SIPT%-(%d+)_(%d+)")
				if sipt[idx] ~= profile then
					uci:set("endpoint_fxso",k,"forward_busy_1","SIPT-"..(sipt[idx] or "unknown").."_"..idx)
					uci:save("endpoint_fxso")
					flag=true
				end
			end
			if v.forward_noreply_1 and v.forward_noreply_1:match("^SIPT%-%d+_%d+") then
				local profile,idx = v.forward_noreply_1:match("^SIPT%-(%d+)_(%d+)")
				if sipt[idx] ~= profile then
					uci:set("endpoint_fxso",k,"forward_noreply_1","SIPT-"..(sipt[idx] or "unknown").."_"..idx)
					uci:save("endpoint_fxso")
					flag=true
				end
			end
			if v.forward_uncondition_2 and v.forward_uncondition_2:match("^SIPT%-%d+_%d+") then
				local profile,idx = v.forward_uncondition_2:match("^SIPT%-(%d+)_(%d+)")
				if sipt[idx] ~= profile then
					uci:set("endpoint_fxso",k,"forward_uncondition_2","SIPT-"..(sipt[idx] or "unknown").."_"..idx)
					uci:save("endpoint_fxso")
					flag=true
				end
			end
			if v.forward_busy_2 and v.forward_busy_2:match("^SIPT%-%d+_%d+") then
				local profile,idx = v.forward_busy_2:match("^SIPT%-(%d+)_(%d+)")
				if sipt[idx] ~= profile then
					uci:set("endpoint_fxso",k,"forward_busy_2","SIPT-"..(sipt[idx] or "unknown").."_"..idx)
					uci:save("endpoint_fxso")
					flag=true
				end
			end
			if v.forward_noreply_2 and v.forward_noreply_2:match("^SIPT%-%d+_%d+") then
				local profile,idx = v.forward_noreply_2:match("^SIPT%-(%d+)_(%d+)")
				if sipt[idx] ~= profile then
					uci:set("endpoint_fxso",k,"forward_noreply_2","SIPT-"..(sipt[idx] or "unknown").."_"..idx)
					uci:save("endpoint_fxso")
					flag=true
				end
			end
		end
	end
	if flag then
		uci:commit("endpoint_fxso")
	end
	flag=false
	for k,v in pairs(uci:get_all("endpoint_sipphone") or {}) do
		if v.forward_uncondition and v.forward_uncondition:match("^SIPT%-%d+_%d+") then
			local profile,idx = v.forward_uncondition:match("^SIPT%-(%d+)_(%d+)")
			if sipt[idx] ~= profile then
				uci:set("endpoint_sipphone",k,"forward_uncondition","SIPT-"..(sipt[idx] or "unknown").."_"..idx)
				uci:save("endpoint_sipphone")
				flag=true
			end
		end
		if v.forward_busy and v.forward_busy:match("^SIPT%-%d+_%d+") then
			local profile,idx = v.forward_busy:match("^SIPT%-(%d+)_(%d+)")
			if sipt[idx] ~= profile then
				uci:set("endpoint_sipphone",k,"forward_busy","SIPT-"..(sipt[idx] or "unknown").."_"..idx)
				uci:save("endpoint_sipphone")
				flag=true
			end
		end
		if v.forward_noreply and v.forward_noreply:match("^SIPT%-%d+_%d+") then
			local profile,idx = v.forward_noreply:match("^SIPT%-(%d+)_(%d+)")
			if sipt[idx] ~= profile then
				uci:set("endpoint_sipphone",k,"forward_noreply","SIPT-"..(sipt[idx] or "unknown").."_"..idx)
				uci:save("endpoint_sipphone")
				flag=true
			end
		end
	end
	if flag then
		uci:commit("endpoint_sipphone")
	end
	flag=false
	for k,v in pairs(uci:get_all("ivr") or {}) do
		if v[".type"] == "menu" then
			if v.destination and v.destination:match("^Trunks,SIPT%-%d+_%d+.*$") then
				local profile,idx,tail = v.destination:match("^Trunks,SIPT%-(%d+)_(%d+)(.*)$")
				if sipt[idx] ~= profile then
					uci:set("ivr",k,"destination","Trunks,SIPT-"..(sipt[idx] or "unknown").."_"..idx..tail)
					uci:save("endpoint_sipphone")
					flag=true
				end
			end
		end
	end
	if flag then
		uci:commit("ivr")
	end
end

function config_cron_cdr()
	local enable = uci:get("upload_cdr","cdr","status") or "0"
	local cmd_str = "#!/bin/sh\n"

	cmd_str=cmd_str.."#"..os.date().."\n"
	if fs.access("/etc/crontabs/root") then
		cmd_str=cmd_str.."sed -i '/check_cdr/d' /etc/crontabs/root\n"
		if enable == "1" then
			cmd_str=cmd_str.."echo '1 0 * * * /usr/bin/check_cdr.sh &' >> /etc/crontabs/root\n"
		end
	else
		if enable == "1" then
			cmd_str=cmd_str.."echo '1 0 * * * /usr/bin/check_cdr.sh &' > /etc/crontabs/root\n"
		end
	end
	fs.writefile("/tmp/refresh_cron.sh",cmd_str)
	os.execute("sh /tmp/refresh_cron.sh")
end

--@ main function to run scripts
function load_scripts(param)
	local ret
	local state
	local flag = false
	local err = ""
	local err_more = ""
	local applyed_list = ""
	local fs_server = require "luci.scripts.fs_server"
	
	exe("rm /tmp/fs-apply-status")

	if "table" ~= type(param) then
		fs.writefile("/tmp/fs-apply-status","ReloadFail=ParamErr")
		return -1,"ParamErr"
	end

	applyed_list = add_to_list(applyed_list,"Checking config")
	fs.writefile("/tmp/fs-apply-status","Applying="..applyed_list)
	fs.writefile("/tmp/fs-apply-status","Applying=")
	check_all_cfg()
	backup_xml()
	
	--@ Upgrade or Restore
	if param.restore or param.upgrade then
		applyed_list = add_to_list(applyed_list,"Checking compatibility")
		os.execute("lua /usr/lib/lua/luci/scripts/data_upgrade.lua")
		fs_server.create_hardware_endpoint()
	end
	--@ LOG
	if param.log then
		applyed_list = add_to_list(applyed_list,"Log")
		fs.writefile("/tmp/fs-apply-status","Applying="..applyed_list)
		os.execute("/etc/init.d/syslogd stop")
		os.execute("/etc/init.d/syslogd start")
	end
	--@ CDR
	if param.cdr or param.restore or param.upgrade then
		applyed_list = add_to_list(applyed_list,"CDR")
		fs.writefile("/tmp/fs-apply-status","Applying="..applyed_list)
		ret,err_more = load_cdr()
		if not ret then
			flag = true
			err = add_to_list(err, "CDR :"..err_more)
		end
	end
	--@ DSP
	if param.dsp or param.restore or param.upgrade then
		applyed_list = add_to_list(applyed_list,"DSP")
		fs.writefile("/tmp/fs-apply-status","Applying="..applyed_list)
		ret,err_more = set_dsp_xml()
		if not ret then
			flag = true
			err = add_to_list(err, "DSP :"..err_more)
		end
	end
	--@ FAX
	if param.fax or param.restore or param.upgrade then
		applyed_list = add_to_list(applyed_list,"FAX")
		fs.writefile("/tmp/fs-apply-status","Applying="..applyed_list)
		ret,err_more = set_fax_xml()
		if not ret then
			flag = true
			err = add_to_list(err, "FAX :"..err_more)
		end
	end
	--@ VLAN
	if param.vlan or param.restore or param.upgrade then
		applyed_list = add_to_list(applyed_list,"VLAN")
		fs.writefile("/tmp/fs-apply-status","Applying="..applyed_list)
		ret = config_vlan_port()

		if not ret then
			flag = true
			err = add_to_list(err,"VLAN")
		end
	end

	--@ nat
	if param.nat or param.upgrade or param.restore then
		applyed_list = add_to_list(applyed_list,"NAT")
		fs.writefile("/tmp/fs-apply-status","Applying="..applyed_list)
		--@ service nat
		exe("lua /usr/lib/lua/luci/scripts/ipaddr_add_dnat.lua")
	end

	--@ MAC filter
	if param.mac_filter or param.upgrade or param.restore then
		applyed_list = add_to_list(applyed_list,"MACFilter")
		fs.writefile("/tmp/fs-apply-status","Applying="..applyed_list)
		--@ 
		config_macfilter()--## /etc/init.d/macfilter restart
	end
	--@ SIP profile
	if param.sipprofile or param.restore or param.upgrade then
		applyed_list = add_to_list(applyed_list,"SIP Profile")
		fs.writefile("/tmp/fs-apply-status","Applying="..applyed_list)
		ret = exe("lua "..scripts_dir.."/sip_profile.lua")
		state = compare_xml_cfg("profile_sip",xml_dir.."/sip_profiles")
		if ret ~= 0 or not state then
			flag = true
			err = add_to_list(err, "SIP Profile")
		end
	end
	--@ SIP trunk
	if param.sipendpoint or param.restore or param.upgrade then
		applyed_list = add_to_list(applyed_list,"SIP Trunk")
		fs.writefile("/tmp/fs-apply-status","Applying="..applyed_list)
		check_sip_trunk_ref()
		ret = exe("lua "..scripts_dir.."/sip_trunk.lua")
		state = compare_xml_cfg("endpoint_siptrunk",xml_dir.."/sip_profiles/external")
		if ret ~= 0 or not state then
			flag = true
			err = add_to_list(err, "SIP Endpoint")
		end
	end
	--@ FXS/FXO
	if param.fxso or param.restore or param.upgrade then
		applyed_list = add_to_list(applyed_list,"FXS/FXO")
		fs.writefile("/tmp/fs-apply-status","Applying="..applyed_list)
		ret = exe("lua "..scripts_dir.."/fxso_profile.lua")
		--state = compare_xml_cfg("endpoint_fxso",xml_dir.."/autoload_configs/freetdm.conf.xml")
		if ret ~= 0 then
			flag = true
			err = add_to_list(err, "FXS/FXO")
		end
	end
	--@ GSM/CDMA
	if param.mobile or param.restore or param.upgrade then
		applyed_list = add_to_list(applyed_list,"GSM/CDMA")
		fs.writefile("/tmp/fs-apply-status","Applying="..applyed_list)
		ret = exe("lua "..scripts_dir.."/mobile_profile.lua")
		state = compare_xml_cfg("endpoint_mobile",xml_dir.."/autoload_configs/gsmopen.conf.xml")
		if ret ~= 0 or not state then
			flag = true
			err = add_to_list(err, "GSM/CDMA")
		end
	end
	--@ Extension dialplan
	if param.extension or param.restore or param.upgrade then
		applyed_list = add_to_list(applyed_list,"Extension")
		fs.writefile("/tmp/fs-apply-status","Applying="..applyed_list)
		ret = exe("lua "..scripts_dir.."/extension_call.lua")
		if ret ~= 0 then
			flag = true
			err = add_to_list(err, "Extension")
		end
	end	
	--@ Dialplan route
	if param.route or param.restore or param.upgrade then
		applyed_list = add_to_list(applyed_list,"Route")
		fs.writefile("/tmp/fs-apply-status","Applying="..applyed_list)
		ret = exe("lua "..scripts_dir.."/dialplan.lua")
		state = compare_xml_cfg("route",xml_dir.."/dialplan/public")
		if ret ~= 0 or not state then
			flag = true
			err = add_to_list(err, "Route")
		end
	end
	--@ Ringgroup
	if param.ringgrp or param.restore or param.upgrade then
		applyed_list = add_to_list(applyed_list,"Ring Group")
		fs.writefile("/tmp/fs-apply-status","Applying="..applyed_list)
		ret = exe("lua "..scripts_dir.."/ringgroup_endpoint.lua")
		if ret ~= 0 then
			flag = true
			err = add_to_list(err, "Ring Group")
		end
	end	
	--@ Routegroup
	if param.routegrp or param.restore or param.upgrade then
		applyed_list = add_to_list(applyed_list,"Route Group")
		fs.writefile("/tmp/fs-apply-status","Applying="..applyed_list)
		ret = exe("lua "..scripts_dir.."/routegroup_endpoint.lua")
		if ret ~= 0 then
			flag = true
			err = add_to_list(err, "Route Group")
		end		
	end	
	--@ Feature
	if param.featurecode or param.restore or param.upgrade then
		applyed_list = add_to_list(applyed_list,"Feature Code")
		fs.writefile("/tmp/fs-apply-status","Applying="..applyed_list)
		--state = compare_xml_cfg("feature_code",xml_dir.."/dialplan/public")
		ret = exe("lua "..scripts_dir.."/feature_code.lua")
		if ret ~= 0 then
			flag = true
			err = add_to_list(err, "Feature Code")
		end
	end
	--@ IVR
	if param.ivr or param.restore or param.upgrade then
		applyed_list = add_to_list(applyed_list,"IVR")
		fs.writefile("/tmp/fs-apply-status","Applying="..applyed_list)
		ret = exe("lua "..scripts_dir.."/ivr.lua")
		if ret ~= 0 then
			flag = true
			err = add_to_list(err,"IVR")
		end
	end
	--@ Provision
	if param.provision then
		applyed_list = add_to_list(applyed_list,"Provision")
		fs.writefile("/tmp/fs-apply-status","Applying="..applyed_list)
		ret,error_more = load_provision()
		if not ret then
			flag = true
			err = add_to_list(err, "Provision :"..err_more)
		end
	end
	
	--@ RTP port
	if param.rtp or param.restore or param.upgrade then
		applyed_list = add_to_list(applyed_list,"RTP")
		fs.writefile("/tmp/fs-apply-status","Applying="..applyed_list)
		ret,error_more = refresh_rtp_portrange()
		if not ret then
			flag = true
			err = add_to_list(err, "RTP :"..err_more)
		end
	end
	
	--@ static route 
	if param.static_route or param.restore or param.upgrade then
		applyed_list = add_to_list(applyed_list,"Static_Route")
		fs.writefile("/tmp/fs-apply-status","Applying="..applyed_list)
		ret = network_set_static_route()
		if not ret then
			err = add_to_list(err,"Static Route")
		end
	end
	
	--@ Network
	if param.network and not param.mtu then
		--if not param.wireless then
		exe("/etc/init.d/network reload")
		exe("sleep 5")
		--end
	end

	--@ Firewall
	if param.firewall or param.network or param.upgrade or param.restore then
		applyed_list = add_to_list(applyed_list,"Firewall")
		fs.writefile("/tmp/fs-apply-status","Applying="..applyed_list)
		--@ check and set firewall
		config_firewall()--## /etc/init.d/firewall restart
	end
	
	--@ WLAN
	if param.wireless or param.mtu then
		config_vlan_proto()
		exe("/etc/init.d/network restart")
	end
	
	--@ strategy route
	if param.mwan3 or param.restore or param.upgrade then
		applyed_list = add_to_list(applyed_list,"Mwan3")
		fs.writefile("/tmp/fs-apply-status","Applying="..applyed_list)
		ret = mwan3_set_strategy_route()
		if not ret then
			flag = true
			err = add_to_list(err,"Strategy Route")
		end
	end
	if param.mwan3 or param.network or param.firewall then
		exe("mwan3 restart")--@!!! this work need doing after network/firewall reload.
	end
	--@ end
	
	--@ Portal auth
	if param.portal_update or param.restore or param.upgrade then
		applyed_list = add_to_list(applyed_list,"Portal")
		fs.writefile("/tmp/fs-apply-status","Applying="..applyed_list)
		ret = config_portal_account()
		
		if not ret then
			flag = true
			err = add_to_list(err,"Portal Account")
		end
	end
	if param.portal_update then
		--@ update cmd 
		exe("portal check update")
	end
	
	if param.portal_restart or param.restore or param.upgrade then
		exe("/etc/init.d/portal restart")
	end
	--@ end
	
	--@ run scripts failed
	if flag then
		recover_xml()
		fs.writefile("/tmp/fs-apply-status","ApplyFail="..err)
		return -2,"ApplyFail"
	end

	--@ FS reload
	if param.sipprofile or param.sipendpoint or param.profile_changes or param.sipextension or param.extension or param.fxso or param.mobile or param.ivr or param.featurecode or param.route or param.cdr or param.rtp or param.fax or param.dsp or param.restore then
		fs.writefile("/tmp/fs-apply-status","Reloading")
		ret,err = freeswitch_reload(param)
		if not ret then
			fs.writefile("/tmp/fs-apply-status","ReloadFail="..err)
			ret = -3
		end
	end
	
	if param.webserver then
		exe("sleep 2")
		exe("/etc/init.d/lucid stop")
		exe("sleep 1")
		exe("/etc/init.d/lucid start")
	end

	if param.gre or param.network then
		exe("/etc/init.d/gre restart")
	end
	if param.ipsec or param.network then
		exe("/etc/init.d/ipsec restart")
	end
	if param.xl2tpd or param.network then
		check_xl2tpd_enabled()
		if param.xl2tpd == "reload" then
			exe("/etc/init.d/xl2tpd reload")
		else
			exe("/etc/init.d/xl2tpd restart")
		end
	end
	if param.pptpd or param.network then
		if param.pptpd == "reload" then
			exe("/etc/init.d/pptpd reload")
		else
			exe("/etc/init.d/pptpd restart")
		end
	end
	if param.pptpc or param.network then
		exe("/etc/init.d/pptpc restart")
	end
	
	if param.openvpn then
		if fs.access("/tmp/my-vpn.conf.latest") then
			uci:set("openvpn","sample_client","enabled","0")
			uci:commit("openvpn")
			local nopull=util.exec("cat /tmp/my-vpn.conf.latest | grep route-nopull")
			if "" == nopull then
				os.execute("echo route-nopull >>/tmp/my-vpn.conf.latest")
			end
			os.execute("echo route-metric 16 >>/tmp/my-vpn.conf.latest")
			os.execute("echo route-up /etc/openvpn/client_route_up.sh >>/tmp/my-vpn.conf.latest")
			os.execute("echo down /etc/openvpn/client_down.sh >>/tmp/my-vpn.conf.latest")
			os.execute("echo up /etc/openvpn/client_up.sh >>/tmp/my-vpn.conf.latest")
			os.execute("cp /tmp/my-vpn.conf.latest /etc/openvpn/my-vpn.conf && sync")
		end
		os.execute("sed -i '/redirect-gateway/d' /etc/openvpn/my-vpn.conf")
		if "1" == uci:get("openvpn","custom_config","defaultroute") then
			os.execute("echo redirect-gateway def1 >>/etc/openvpn/my-vpn.conf")
		end
		os.execute("/etc/init.d/openvpn restart")
	end

	if param.qos or param.network then
		exe("/etc/init.d/qos restart")
	end
		
	if param.dhcp then
		--exe("rm /tmp/dhcp.leases")
	end

    if param.dhcp or param.dns or param.restore or param.upgrade then
    	--@ 
    	dhcp_set_dnsmasq_interface()
    	exe("/etc/init.d/dnsmasq restart")
    end
	if param.arp or param.restore or param.upgrade then
		exe("/etc/init.d/sarp restart")
	end
	
	if "off" == param.telnet_action or "on" == param.telnet_port then
		exe("/etc/init.d/telnet stop")
		exe("sleep 1")
	end

	if "on" == param.telnet_action or "on" == param.telnet_port then
		exe("/etc/init.d/telnet start")
	end

	if param.ssh then
		exe("/etc/init.d/dropbear stop")
		exe("sleep 1")
		exe("/etc/init.d/dropbear start")
	end

	if param.ddns or param.restore or param.upgrade then
		ret = config_ddns()
		
		if not ret then
			flag = true
			err = add_to_list(err, "DDNS")
		end
		exe("/etc/init.d/ddns restart")
	end

	if param.autovpn or param.network or param.firewall or param.domainlist or param.restore or param.upgrade then
		autovpn(param)
	end

	if param.attack or param.restore or param.upgrade then
		exe("/etc/init.d/attack restart")
	end
	
	if param.cloud or param.network then
		exe("/etc/init.d/cloud restart")
	end

	if param.alg or param.restore then
		exe("/etc/init.d/alg restart")
	end
	
	if param.upload_cdr or param.restore or param.upgrade then
		exe("/etc/init.d/cron stop")
		config_cron_cdr()
		exe("/etc/init.d/cron start")
	end

	exe("rm -fr "..backup_dir)
	fs.writefile("/tmp/fs-apply-status","Success="..applyed_list)
	
	if -3 == ret then
		return -3,"ReloadFail"
	else
		return 0,"Success"
	end
end
