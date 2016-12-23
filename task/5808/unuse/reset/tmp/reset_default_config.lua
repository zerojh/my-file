local uci = require "luci.model.uci".cursor()
local fs = require "luci.fs"
local param = arg[1]
local reset_src_ip = arg[2] or "unknown"

function reset_feature_code()
	--@ copy default feature_code to the /etc/config
	os.execute("cp /usr/lib/lua/luci/scripts/default_config/feature_code /etc/config")
	os.execute("lua /usr/lib/lua/luci/scripts/feature_code.lua")
end
function reset_callcontrol_setting()
	os.execute("cp /usr/lib/lua/luci/scripts/default_config/callcontrol /etc/config")
end
function reset_ivr()
	os.execute("cp /usr/lib/lua/luci/scripts/default_config/ivr /etc/config && lua /usr/lib/lua/luci/scripts/ivr.lua")
end
function reset_fax()
	local load = require "luci.scripts.luci_load_scripts"
	os.execute("cp /usr/lib/lua/luci/scripts/fax /etc/config/")
	load.set_fax_xml()
end

function reset_provision()
	os.execute("rm /etc/config/provision && touch /etc/config/provision")
	uci:create_section("provision","cfg","provision",{})

	os.execute("cp /usr/lib/lua/luci/scripts/default_config/provision.conf /etc/provision/")
end

function reset_log()
	local log_file = io.open("/etc/logsrv/mod_log.conf","w+")

	local log_str = "" 
	log_str = log_str.."[console]\n\nlevel=-1\n\n[cli]\n\nremote_sub_uri = tcp://127.0.0.1:52225\n\n[syslog]\n\nremote_sub_uri = tcp://127.0.0.1:52225\n\n"
	log_str = log_str.."[module]\n\ncli = no\nsyslog=no\nconsole=no\n\n[rsyslog]\n"

	log_str = log_str.."server=\n"
	log_str = log_str.."port = 514\n"
	log_str = log_str.."file_func_line = func\n"
	log_str = log_str.."level_name = yes\n"
	log_str = log_str.."log_count = yes\n"
	log_str = log_str.."level = -1\n\n"
	log_str = log_str.."[file]\n\n"
	log_str = log_str.."level = 5\n"
	log_str = log_str.."path = /ramlog/log\nrotate_size = 2000\n"
	log_file:write(log_str)

	log_file:close()
end

function reset_default_profile()
	os.execute("cp /usr/lib/lua/luci/scripts/default_config/profile_codec /etc/config/")
	os.execute("cp /usr/lib/lua/luci/scripts/default_config/profile_sip /etc/config/")
	os.execute("cp /usr/lib/lua/luci/scripts/default_config/profile_fxso /etc/config/")
end

function reset_hardware_endpoint()
	os.execute("cp /usr/lib/lua/luci/scripts/default_config/endpoint_fxso /etc/config/")
	os.execute("cp /usr/lib/lua/luci/scripts/default_config/endpoint_mobile /etc/config/")
end

function reset_mod_cdr()
	require "mxml"
	local root = mxml.parsefile("/etc/freeswitch/conf/autoload_configs/cdr_sqlite.conf.xml")
	if root then
		local cdr_sqlite = mxml.find(root,"configuration/settings","param","name","db-insert-server")
		if cdr_sqlite then
			mxml.setattr(cdr_sqlite,"value","disable")
		end
		mxml.savefile(root,"/etc/freeswitch/conf/autoload_configs/cdr_sqlite.conf.xml")
		mxml.release(root)
	end
end
function reset_rtp_portrange()
	require "mxml"
	local cfg = uci:get_all("callcontrol","voice")

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
	end

	mxml.savefile(root,"/etc/freeswitch/conf/autoload_configs/switch.conf.xml")
	mxml.release(root)
end

function reset_cloud_config()
	local uci = require "luci.model.uci".cursor()
	uci:set("cloud","cloud","enable","0")
	uci:delete("cloud","cloud","domain")
	uci:delete("cloud","cloud","port")
	uci:delete("cloud","cloud","password")
	uci:commit("cloud")
end

function reset_tr069_config()
	local dpr = require "dpr"
	sn = string.upper(dpr.getdevicesn() or "unknown")
	uci:set("easycwmp","acs","enable","0")
	uci:set("easycwmp","acs","url","")
	uci:set("easycwmp","acs","periodic_interval","3600")
	uci:set("easycwmp","acs","username",sn)
	uci:set("easycwmp","acs","password","")
	uci:commit("easycwmp")
end

function reset_system_config()
	local uci = require "luci.model.uci".cursor()
	local sys = require "luci.sys"
	local brand = uci:get("oem","general","brand") or "unknown"
	uci:set("system","main","timezone",uci:get("oem",brand,"timezone") or "GMT0")
	uci:set("system","main","zonename",uci:get("oem",brand,"zonename") or "UTC")
	uci:set("system","main","hostname",uci:get("oem",brand,"hostname") or "UC100")
	uci:set("system","main","mod_cdr","off")

	--@ system log
	uci:set("system","main","syslog_enable","0")
	uci:set("system","main","log_type","file")
	uci:set("system","main","log_file","/ramlog/log")
	uci:set("system","main","log_size","2000")
	uci:set("system","main","log_level","6")
	uci:delete("system","main","log_ip")
	uci:delete("system","main","log_port")
	
	uci:set("system","ntp","enabled","1")
	uci:set("system","ntp","server",{"0.pool.ntp.org","1.pool.ntp.org","2.pool.ntp.org","3.pool.ntp.org"})
	
	uci:commit("system")
	uci:commit("luci")
	reset_cloud_config()
	reset_provision()
	--reset_log()
	reset_mod_cdr()
	reset_rtp_portrange()
	sys.user.setpasswd("admin","admin")

	if not param:match("tr069") then
		reset_tr069_config()
	end

	os.execute("rm /etc/log/clilog /etc/log/weblog /etc/log/pptpc_log /etc/log/l2tpc_log /etc/log/openvpnc_log /etc/log/uci_changes_log*")
end

function reset_network()
	--@ default network mode is route
	local uci = require "luci.model.uci".cursor()
	local brand = uci:get("oem","general","brand") or "unknown"
	local hostname = uci:get("oem",brand,"hostname") or "UC100"
	--@ telnet default config
	uci:set("system","telnet","action","on")
	uci:set("system","telnet","port","23")
	uci:check_cfg("telnet")
	local tel_cfg = uci:get("telnet","telnet")
	if not tel_cfg then
		uci:create_section("telnet","telnet","telnet",{action="on",port="23"})
	else
		uci:set("telnet","telnet","action","on")
		uci:set("telnet","telnet","port","23")
	end
	--@ http/https port default config
	uci:set_list("lucid","http","address",{"80"})
	uci:set_list("lucid","https","address",{"443"})
	--@ ssh default config
	uci:set("dropbear","main","Port","22")

	--@ network default config/static route cfg in here
	os.execute("cp /usr/lib/lua/luci/scripts/default_config/network /etc/config")
	if "UC100" ~= hostname then
		uci:set("network","wan","hostname",hostname)
		uci:set("network","lan","hostname",hostname)
		uci:commit("network")
	end
	--@ mwan3 default config
	os.execute("cp /usr/lib/lua/luci/scripts/default_config/mwan3 /etc/config")
	--@ dhcp default config
	os.execute("cp /usr/lib/lua/luci/scripts/default_config/dhcp /etc/config")
	--@ openvpn default config
	os.execute("cp /usr/lib/lua/luci/scripts/default_config/openvpn /etc/config")
	os.execute("rm /etc/openvpn/my-vpn.conf")
	--@ pptp client default config
	os.execute("cp /usr/lib/lua/luci/scripts/default_config/pptpc /etc/config")
	--@ l2tp default config
	os.execute("cp /usr/lib/lua/luci/scripts/default_config/xl2tpd /etc/config")
	--@ wireless default config
	os.execute("rm /etc/config/wireless")
	--@ rm tmp network
	os.execute("rm /etc/config/network_tmp /etc/config/static_route")
	
	--@ ddns default config
	uci:delete("ddns","myddns_ipv4","service_name_list")
	uci:delete("ddns","myddns_ipv4","update_url")
	uci:set("ddns","myddns_ipv4","enabled","0")
	uci:set("ddns","myddns_ipv4","service_name","dyndns.org")
	uci:set("ddns","myddns_ipv4","domain","yourhost.dyndns.org")
	uci:set("ddns","myddns_ipv4","username","your_username")
	uci:set("ddns","myddns_ipv4","password","your_password")
	uci:set("ddns","myddns_ipv4","ip_source","web")
	uci:set("ddns","myddns_ipv4","ip_url","http://checkip.dyndns.com")
	uci:set("ddns","myddns_ipv4","check_interval","10")
	uci:set("ddns","myddns_ipv4","force_interval","72")
	uci:set("ddns","myddns_ipv4","retry_interval","60")
	uci:create_section("ddns","service","dinstar_ddns",{enabled="1",use_https="1",cacert="IGNORE",interface="wan",ip_source="web",ip_url="http://ddns.oray.com/checkip",domain="0000-0000-0000-0000",update_url="http://dstardns.com:8080/nic/update?domain=[DOMAIN]&ip=[IP]&key=[KEY]"})
	
	uci:commit("system")
	uci:commit("telnet")
	uci:commit("lucid")
	uci:commit("dropbear")
	uci:commit("ddns")
end

function reset_firewall()
	--@ reset firewall
	os.execute("cp /usr/lib/lua/luci/scripts/default_config/firewall /etc/config")

	--@ For nat
	os.execute("echo 'iptables -t nat -A zone_wan_postrouting -i br-lan -p tcp -j MASQUERADE --to-ports 30000-60000' > /etc/firewall.user")
	os.execute("echo 'iptables -t nat -A zone_wan_postrouting -i br-lan -p udp -j MASQUERADE --to-ports 30000-60000' >>/etc/firewall.user")
	os.execute("echo 'iptables -t nat -D zone_wan_postrouting  -j MASQUERADE ' >>/etc/firewall.user")
	os.execute("echo 'iptables -t nat -A zone_wan_postrouting  -j MASQUERADE' >>/etc/firewall.user")
	
	os.execute("/etc/init.d/firewall enable")
end

function reset_oem_custom_default_config(param)
	--这里实现一些定制客户的个性化缺省配置
	if fs.access("/usr/lib/lua/luci/scripts/default_config/custom_reset.sh") then
		os.execute("sh /usr/lib/lua/luci/scripts/default_config/custom_reset.sh "..param)
	end
	if fs.access("/usr/lib/lua/luci/scripts/default_config/custom_reset.lua") then
		os.execute("lua /usr/lib/lua/luci/scripts/default_config/custom_reset.lua "..param)
	end
end
local reset_all

if (not param) or ("tr069" == param) then
	reset_all = "on"
	param = param or ""
end

os.execute("echo "..os.date("%Y-%m-%d %H:%M:%S",os.time()).." param:"..param.." reset src ip:"..reset_src_ip.." >>/etc/log/reset_log")

if param:match("system") or reset_all then
	reset_system_config()
end

if param:match("network") or reset_all then
	reset_network()
	reset_firewall()
end

local freeswitch = require "luci.scripts.fs_server"

if param:match("service") or reset_all then
	local rm_list = ""
	local touch_list = ""
	local exe_list = ""

	rm_list = rm_list .. "/etc/config/profile_* /etc/freeswitch/conf/sip_profiles/*.xml "

	rm_list = rm_list .. "/etc/config/endpoint_sipphone /etc/config/endpoint_ringgroup "
	touch_list = touch_list .. "/etc/config/endpoint_sipphone /etc/config/endpoint_ringgroup "

	rm_list = rm_list .. "/etc/config/endpoint_siptrunk "
	touch_list = touch_list .. "/etc/config/endpoint_siptrunk "

	rm_list = rm_list .. "/etc/config/endpoint_fxso "

	rm_list = rm_list .. "/etc/config/endpoint_routegroup /etc/config/route "

	rm_list = rm_list .. "/etc/freeswitch/conf/sip_profiles/external/* "

	rm_list = rm_list .. "/etc/freeswitch/conf/directory/default/*.xml "

	rm_list = rm_list .. "/etc/freeswitch/conf/dialplan/public/r_*.xml /etc/freeswitch/conf/dialplan/public/01_extension_call.xml "

	rm_list = rm_list.."/etc/freeswitch/cdr /etc/freeswitch/sms "

	rm_list = rm_list.."/etc/freeswitch/sounds/en/us/callie/welcome.* /etc/freeswitch/sounds/zh/cn/callie/welcome.*"

	os.execute("rm "..rm_list)
	os.execute("touch "..touch_list)
	reset_default_profile()

	reset_hardware_endpoint()

	reset_oem_custom_default_config(param)
	--重新启动下lucid的进程，在其启动初始化时，会根据license重新检查下配置
	os.execute("/etc/init.d/lucid restart")

	os.execute("lua /usr/lib/lua/luci/scripts/sip_profile.lua")
	os.execute("lua /usr/lib/lua/luci/scripts/extension_call.lua")
	os.execute("lua /usr/lib/lua/luci/scripts/fxso_profile.lua")
	os.execute("lua /usr/lib/lua/luci/scripts/mobile_profile.lua")
	os.execute("lua /usr/lib/lua/luci/scripts/sip_trunk.lua")
	os.execute("lua /usr/lib/lua/luci/scripts/chatplan.lua")

	reset_callcontrol_setting()
	reset_fax()
	reset_feature_code()
	reset_ivr()
	os.execute("touch /etc/config/route && lua /usr/lib/lua/luci/scripts/dialplan.lua")
elseif param:match("system") or param:match("network") then
	reset_oem_custom_default_config(param)
	-- only reset system or network , hostname or network mode maybe change, regenerate sip profile xml
	os.execute("lua /usr/lib/lua/luci/scripts/sip_profile.lua")
	os.execute("/etc/init.d/lucid restart")
end
