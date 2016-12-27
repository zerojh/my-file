local uci = require "luci.model.uci".cursor()
local network_mode = uci:get_all("network","wan") and "route" or "bridge"

if network_mode == "route" then
	local firewall_cfg = uci:get_all("firewall")

	local enabled_firewall
	local enabled_http
	local enabled_https
	local enabled_telnet
	local enabled_ssh
	local enabled_8345
	local enabled_8848
	
	local rule_http_sec
	local rule_https_sec
	local rule_ssh_sec
	local rule_telnet_sec
	
	local redirect_http_sec
	local redirect_https_sec
	local redirect_ssh_sec
	local redirect_telnet_sec

	local rule_8345_sec
	local rule_8848_sec
	local redirect_8345_sec
	local redirect_8848_sec
	
	for k,v in pairs(firewall_cfg) do
		if v['.type'] == "defaults" then
			enabled_http = v.enabled_http or "0"
			enabled_https = v.enabled_https or "0"
			enabled_ssh = v.enabled_ssh or "0"
			enabled_telnet = v.enabled_telnet or "0"
			enabled_8345 = v.enabled_8345 or "0"
			enabled_8848 = v.enabled_8848 or "0"
		elseif v['.type'] == "rule" and v.name == "Allow-http" then
			rule_http_sec = k
		elseif v['.type'] == "rule" and v.name == "Allow-https" then
			rule_https_sec = k
		elseif v['.type'] == "rule" and v.name == "Allow-ssh" then
			rule_ssh_sec = k
		elseif v['.type'] == "rule" and v.name == "Allow-telnet" then
			rule_telnet_sec = k
		elseif v['.type'] == "rule" and v.name == "Allow-8345" then
			rule_8345_sec = k
		elseif v['.type'] == "rule" and v.name == "Allow-8848" then
			rule_8848_sec = k
		elseif v['.type'] == "redirect" and v.name == "Allow-http" then
			redirect_http_sec = k
		elseif v['.type'] == "redirect" and v.name == "Allow-https" then
			redirect_https_sec = k
		elseif v['.type'] == "redirect" and v.name == "Allow-ssh" then
			redirect_ssh_sec = k
		elseif v['.type'] == "redirect" and v.name == "Allow-telnet" then
			redirect_telnet_sec = k
		elseif v['.type'] == "redirect" and v.name == "Allow-8345" then
			redirect_8345_sec = k
		elseif v['.type'] == "redirect" and v.name == "Allow-8848" then
			redirect_8848_sec = k
		end
	end

	--@ http
	if enabled_http == "1" and rule_http_sec and redirect_http_sec then
		local http_port = uci:get("lucid","http","address") 
		local tmp_port

		if type(http_port) == "table" then
			tmp_port = http_port[1]
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
		uci:set("firewall",redirect_http_sec,"enabled","1")	
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
		uci:set("firewall",redirect_https_sec,"enabled","1")	
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
		uci:set("firewall",redirect_telnet_sec,"enabled","1")	
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
		uci:set("firewall",redirect_ssh_sec,"enabled","1")	
	end
	
	--@8345
	if enabled_8345 == "1" and rule_8345_sec and redirect_8345_sec then
		uci:set("firewall",rule_8345_sec,"enabled","1")
		uci:set("firewall",rule_8345_sec,"target","ACCEPT")
		uci:set("firewall",redirect_8345_sec,"enabled","1")
	elseif rule_8345_sec and redirect_8345_sec then
		uci:set("firewall",rule_8345_sec,"enabled","1")
		uci:set("firewall",rule_8345_sec,"target","REJECT")
		uci:set("firewall",redirect_8345_sec,"enabled","1")
	end
	--@8848
	if enabled_8848 == "1" and rule_8848_sec and redirect_8848_sec then
		uci:set("firewall",rule_8848_sec,"enabled","1")
		uci:set("firewall",rule_8848_sec,"target","ACCEPT")
		uci:set("firewall",redirect_8848_sec,"enabled","1")
	elseif rule_8848_sec and redirect_8848_sec then
		uci:set("firewall",rule_8848_sec,"enabled","1")
		uci:set("firewall",rule_8848_sec,"target","REJECT")
		uci:set("firewall",redirect_8848_sec,"enabled","1")
	end
		
	uci:commit("firewall")
	os.execute("/etc/init.d/firewall enable")
	os.execute("/etc/init.d/firewall restart")
end
