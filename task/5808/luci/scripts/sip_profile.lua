require "mxml"
require "uci"
require "luci.version"
local fs = require "nixio.fs"
local sys = require "luci.sys"

local pairs = pairs
local tostring = tostring
local conf_dir = "/etc/freeswitch/conf/sip_profiles"

local cfgfilelist = {"profile_sip","profile_codec","endpoint_siptrunk"}
for k,v in ipairs(cfgfilelist) do
	os.execute("cp /etc/config/"..v.." /tmp/config")
end
local uci = uci.cursor("/tmp/config","/tmp/state")

local sip_cfg = uci:get_all("profile_sip") or {}
local codec_cfg = uci:get_all("profile_codec") or {}
local endpoint = uci:get_all("endpoint_siptrunk") or {}

--@ rm old xml file
if fs.access(conf_dir) then
	os.execute("rm "..conf_dir.."/*.xml")
end

function add_param_name_value(parent_node,name,value)
	if parent_node  and name  and value then
		param = mxml.newnode(parent_node,"param")
		mxml.setattr(param,"name",name)
		mxml.setattr(param,"value",value)
		return true
	else
		return false
	end
end

function netmask2num(val)
	local bit = require "bit"
	if val and "0.0.0.0" ~= val then
		if val:match("^%d+%.%d+%.%d+%.%d+$") then
			return val.."/"..32
		elseif val:match("^%d+%.%d+%.%d+%.%d+/%d+$") then
			return val
		elseif val:match("%d+%.%d+%.%d+%.%d+/%d+%.%d+%.%d+%.%d+$") then
			local addr = "0.0.0.0"
			local x = {}
			local cnt = 0
			addr,x[1],x[2],x[3],x[4] = val:match("^(%d+%.%d+%.%d+%.%d+)/(%d+)%.(%d+)%.(%d+)%.(%d+)$")
			for i=1,4 do
				for j=0,7 do
					local b = bit.band(tonumber(x[i]),bit.rshift(128,j))
					if 0 ~= b then
						cnt = cnt + 1
					else
						return addr.."/"..cnt
					end
				end
			end
		end
	else
		return "0.0.0.0/0"
	end
end
--@ get section by sip_cfg file,the result is in v
for k,v in pairs(sip_cfg) do
	if v.index then
	local xml = mxml:newxml()

	local profile = mxml.newnode(xml,"profile")
	mxml.setattr(profile,"name",v.index)

	local gateways = mxml.newnode(profile,"gateways")

	local domains = mxml.newnode(profile,"domains")

	local domain = mxml.newnode(domains,"domain")
	mxml.setattr(domain,"name","all")
	mxml.setattr(domain,"alias","false")
	mxml.setattr(domain,"parse","true")

	local settings = mxml.newnode(profile,"settings")

	add_param_name_value(settings,"dialplan","XML")
	add_param_name_value(settings,"context","public")
	add_param_name_value(settings,"challenge-realm","$${domain}")
	add_param_name_value(settings,"force-register-db-domain","$${domain}")
	add_param_name_value(settings,"user-agent-string",sys.hostname().."/"..luci.version.firmware_ver)
	add_param_name_value(settings,"username",sys.hostname())
	add_param_name_value(settings,"contact-user",sys.hostname())
	--add_param_name_value(settings,"auth-calls","true")
	add_param_name_value(settings,"sps-limit",3)
	add_param_name_value(settings,"rtp-autofix-timing","false")
	add_param_name_value(settings,"rtp-autofix-payload","false")
	add_param_name_value(settings,"extension-in-contact","true")
	add_param_name_value(settings,"aggressive-nat-detection","true")
    add_param_name_value(settings,"manual-redirect","true")
    
	local addr = "interface:ipv4/br-lan"
	if uci:get("network","wan") then
		if "pppoe" == uci:get("network","wan","proto") then
			if v.localinterface == "WAN" then
				addr = "interface:ipv4/pppoe-wan"
			end
		else
			if uci:get("network","wan","ifname") == "ra0" then
				addr = "interface:ipv4/ra0"
			else
				--@ if auto,maybe get ipv6 address when protocol is dhcp
				if v.localinterface == "WAN" then
					addr = "interface:ipv4/eth0.2"
				end
			end
		end
	else
		if "pppoe" == uci:get("network","lan","proto") then
			addr = "interface:ipv4/pppoe-lan"
		end
	end

	if "LTE" == v.localinterface then
		addr = "interface:ipv4/3g-wan2"
	elseif "OpenVPN" == v.localinterface then
		addr = "interface:ipv4/tun0"
	elseif "PPTP" == v.localinterface then
		addr = "interface:ipv4/ppp1723"
	elseif "L2TP" == v.localinterface then
		addr = "interface:ipv4/ppp1701"
	end

	add_param_name_value(settings,"sip-ip",addr)
	add_param_name_value(settings,"rtp-ip",addr)
	add_param_name_value(settings,"inbound-late-negotiation","false")
	add_param_name_value(settings,"disable-transcoding","true")
	add_param_name_value(settings,"hold-music","$${hold_music}")
	add_param_name_value(settings,"sip-port",v.localport or 5060)
	add_param_name_value(settings,"max-proceeding",v.max_channels or ((luci.version.license and luci.version.license.gsm) and 11 or 10))
	add_param_name_value(settings,"session-timeout",v.session_timeout or 1800)
	add_param_name_value(settings,"enable-100rel",v.prack or "off")
	add_param_name_value(settings,"inbound-codec-negotiation",v.inbound_codec_negotiation or "generous")
	if "off" == v.ext_sip_ip or (v.localinterface == "LAN" and (uci:get("network","wan") or "route" == uci:get("network_tmp","network","network_mode"))) then
		add_param_name_value(settings,"ext-sip-ip",addr)
		add_param_name_value(settings,"ext-rtp-ip",addr)
	else
		if "auto" == v.ext_sip_ip or "auto-nat" == v.ext_sip_ip then
			addr = v.ext_sip_ip
		elseif "ip" == v.ext_sip_ip and v.ext_sip_ip_more and v.ext_sip_ip_more:match("%d+%.%d+%.%d+%.%d+") then
			addr = v.ext_sip_ip_more
		elseif "ip_autonat" == v.ext_sip_ip and v.ext_sip_ip_more and v.ext_sip_ip_more:match("%d+%.%d+%.%d+%.%d+") then
			addr = "auto-nat:"..v.ext_sip_ip_more
		elseif "stun" == v.ext_sip_ip and v.ext_sip_ip_more then
			addr = "stun:"..v.ext_sip_ip_more
		elseif "host" == v.ext_sip_ip and v.ext_sip_ip_more then
			addr = "host:"..v.ext_sip_ip_more
		end

		add_param_name_value(settings,"ext-sip-ip",addr)
		add_param_name_value(settings,"ext-rtp-ip",addr)
	end

	if v.dtmf then
		add_param_name_value(settings,"dtmf-type",v.dtmf)
		if "rfc2833" == v.dtmf then
			add_param_name_value(settings,"rfc2833-pt",v.rfc2833_pt)
			add_param_name_value(settings,"liberal-dtmf","true")
		elseif "info" == v.dtmf then
			add_param_name_value(settings,"liberal-dtmf","false")
		end
	else
		add_param_name_value(settings,"dtmf-type","rfc2833")
		add_param_name_value(settings,"rfc2833-pt",101)
	end

	if v.inbound_codec_prefs or v.outbound_codec_prefs then
		
		--@ get the profile information from other cfg_file
		for key,value in pairs(codec_cfg) do
			--@ get the right section,judge by the value of "index"
			if value.index == v.inbound_codec_prefs or value.index == v.outbound_codec_prefs then
				--@ foreach in this section
				local profile_str = ""
				for k2,v2 in pairs(value.code) do
					if profile_str == "" then
						profile_str = tostring(v2)
					else
						profile_str = tostring(profile_str)..","..tostring(v2)
					end
				end
				if value.index == v.inbound_codec_prefs then
					add_param_name_value(settings,"inbound-codec-prefs",profile_str)
				end
				if value.index == v.outbound_codec_prefs then
					add_param_name_value(settings,"outbound-codec-prefs",profile_str)
				end
			end
		end
	else
		add_param_name_value(settings,"inbound-codec-prefs","PCMU,PCMA,G723,G729")
		add_param_name_value(settings,"outbound-codec-prefs","PCMU,PCMA,G723,G729")
	end

	if v.heartbeat and "on" == v.heartbeat then
		add_param_name_value(settings,"all-reg-options-ping","true")
		add_param_name_value(settings,"unregister-on-options-fail","true")
		add_param_name_value(settings,"registration-thread-frequency",v.ping or 30)
	end
	if "on" == v.allow_unknown_call then
		add_param_name_value(settings,"allow-unknown-call","true")
	end
	add_param_name_value(settings,"apply-inbound-acl",netmask2num(v.auth_acl))
	if v.qos and "on" == v.qos then
		add_param_name_value(settings,"sip-dscp",v.dscp_sip and (((tonumber(v.dscp_sip) or 64) > 63 or (tonumber(v.dscp_sip) or -1) < 0) and 46 or v.dscp_sip) or 46)
		add_param_name_value(settings,"rtp-dscp",v.dscp_rtp and (((tonumber(v.dscp_rtp) or 64) > 63 or (tonumber(v.dscp_sip) or -1) < 0) and 46 or v.dscp_rtp) or 46)
	end

	--local acl = ""
	for i,j in pairs(endpoint) do
		if j.status and "Enabled" == j.status and j.profile == v.index and j.ipv4 then
			--acl = acl..j.ipv4.."/32,"
			if gateways then
				local param = mxml.newnode(gateways,"X-PRE-PROCESS")
				mxml.setattr(param,"cmd","include")
				mxml.setattr(param,"data","external/"..j.index..".xml")
				param = mxml.newnode(gateways,"X-PRE-PROCESS")
				mxml.setattr(param,"cmd","include")
				mxml.setattr(param,"data","external/"..j.index.."-*.xml")
			end
		end
	end
	--
	local xml_file
	if fs.access(conf_dir) then
		xml_file = conf_dir.."/"..tostring(v.index)..".xml"
		mxml.savefile(xml,xml_file)
	else

	end
	mxml.release(xml)
	end
end

