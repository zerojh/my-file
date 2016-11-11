local fs = require "nixio.fs"
local ip = require "luci.ip"
local math = require "math"
local util = require "luci.util"
local tonumber, type, ipairs ,tostring ,sub = tonumber, type, ipairs,tostring,string.sub
local uci = require "luci.model.uci".cursor()
local bit = require "bit"

module "luci.cbi.datatypes"

local datatypes_tip = {
	cfgname = "Config name can not be empty, less than 32 characters",
	cidr = "A single Class A/B/C IPv4 address or network segment, Example: 192.168.11.1 or 192.168.11.1/24 or 192.168.11.1/255.255.255.0",
	abc_ip4addr_domain = "Class A/B/C IPv4 address or domain, Example: 192.168.1.1",
	domain = "A valid domain can contain digit(0-9), letter(a-Z), dash(-), at least one dot(.) between them",
	extension = "Extension should be number, not same with existing",
	ip4addr = "IPv4 address, Example: 192.168.1.1",
	abc_ip4addr = "Class A/B/C IPv4 address, Example: 192.168.1.1",
	macaddr = "MAC address,Example: xx:xx:xx:xx:xx:xx",
	unicast_macaddr = "Unicast MAC address,Example: xx:xx:xx:xx:xx:xx",
	dhcp_addrpool = "Class A/B/C IPv4 address,and match format: ",
	port = "Port should be a number between 1 and 65535",
	portrange = "One or two port separated by a dash(-), Example: 5000-6000",
	dif_portrange = "One or two ports separated by a dash(-), and not same with existing",
	upnpexport = "Port should be a number between 1 and 65535,and not same with existing",
	serviceport = "Port should be a number between 1 and 65535,and not same with existing",
	ip4addrrange = "One or two Class A/B/C ipv4 separated by a dash(-),Example: 192.168.1.1-192.168.1.199",
	clock = "Hour and minute , Example: 12:10",
	uinteger = "Positive (unsigned) number and doesn't contain period(.)",
	integer = "A number doesn't contain period(.)",
	numberrange = "One or more number length separated by OR operation(|), or range by dash(-), Example: 8,10-12, totally less than 32 characters.",
	numberprefix = "Number begin with 0-9,a-Z or +/*, Max length is 32, Support multi-prefix by OR operation(|), Example: +86|852",
	phonenumber = "Number only could use 0-9,a-Z or +/*/#, Max length is 32",
	hostname = "Hostname should begin with letters, could contain number, period(.) or minus(-), last character must not be minus or period,totally less than 24 characters.",
	url = "Valid URL should begin with tftp:// or http:// or ftp:// or https:// or ftps://",
	notempty = "Can not be empty!",
	regular = "Regular expression should not contain other characters except digits(0-9),letter(a-Z),symbols(,.-?!()[]{}\\+*^$|).",
	regular_simple = "Regular expression should not contain other characters except digits(0-9),letter(a-Z),symbols(,.-?!()[]{}\\+*^$|), totally less than 32 characters.",
	localport = "Port should be a number between 1 and 65535, not conflict with local listening port, and can not be empty!",
	feature_code = "Feature code should only begin with *, and could only use 0-9 or *, not same with existing",
	netmask = "Invalid netmask address",
	gateway = "Gateway must be in the same subnet with IPv4 address",
	wan_gateway = "Gateway must be in the same subnet with WAN IP address",
	dhcp_gateway = "DHCP gateway must be in the same subnet with LAN IP address",
	wan_addr = "Class A/B/C IPv4 address, and can not in the same subnet with LAN IP address",
	lan_addr = "Class A/B/C IPv4 address, and can not in the same subnet with WAN IP address",
	range = "Value range: ",
	min = "Value can not greater than 99999,and can not less than ",
	max = "Value can not greater than ",
	pincode = "PIN Code must be 4 to 8 digits in length",
	password = "The length must more than 8 characters and less than 32 characters",
	wifi_password = "The length must more than 8 characters and less than 32 characters, should not contain other characters except digits(0-9),letter(a-Z),symbols(~!@#$%^&*()_+-={}[])",
	wep_password = "The length of 64bit WEP must be 5 characters,and 128bit must be 13 characters",
	uni_ssid = "The SSID only could use letters,digits,periods,underscores,and minus,length must less then 32",
	multi_ssid = "The SSID only could use letters,digits,periods,underscores,and minus,length must less then 32, and can not be conflict with local other SSID!",
	wlan_gateway = "Gateway must be in the same subnet with WLAN IP address"
}

function uni_ssid(val)
	if val and val:match("^[0-9a-zA-Z%-%.%_]+$") and #val <= 32 then
		return true
	end
	
	return false
end

function multi_ssid(val, ssid_list)
	if val and val:match("^[0-9a-zA-Z%-%.%_]+$") and #val <= 32 then
		local ssid_list_tb = util.split(ssid_list,"&")
		for _,v in pairs(ssid_list_tb) do
			if val == v then
				return false
			end
		end

		return true
	end
	return false
end

function wep_password(val)
	if val then
		if #val == 5 or #val == 13 then
			return true
		else
			return false
		end
	end
	return true
end

function password(val)
	if val then
		if #val < 8 or #val > 32 then
			return false
		else
			return true
		end
	end
	return true
end

function get_datatypes_tip(val)
	local datatype = val:match("^([a-zA-Z0-9_]+)")
	return datatypes_tip[datatype] or ""
end

function feature_code(val,code_list)
	if not val then
		return false
	end

	if val:match("^\*[0-9\*]+$") then
		return true
	else
		return false
	end

	local code_list_tb = util.split(code_list,"&")
	for k,v in ipairs(code_list_tb) do
		if val == v then
			return false
		end
	end

	return true
end

--like:2014-03-24
function date(val)
	if not val then
		return true
	end
	if val:match("^[0-9%-~]+[0-9%-~]*$") == nil then
		return false
	else
		local tmp_tb = {}
		tmp_tb[1],tmp_tb[2],tmp_tb[3],tmp_tb[4],tmp_tb[5],tmp_tb[6] = val:match("^(%d+)-(%d+)-(%d+)~(%d+)-(%d+)-(%d+)$")
		if tmp_tb[1] == nil or tmp_tb[2] == nil or tmp_tb[3] == nil or tmp_tb[4] == nil or tmp_tb[5] == nil or tmp_tb[6] == nil then
			return false
		end		
		--check number format
		for i=1,2 do
			local year = tonumber(tmp_tb[3*i-2])
			local month = tonumber(tmp_tb[3*i-1])
			local day = tonumber(tmp_tb[3*i])
			if tmp_tb[3*i-2]:len() ~= 4 or tmp_tb[3*i-1]:len() > 2 or tmp_tb[3*i]:len() > 2 then
				return false
			else		
				if month == 1 or month == 3 or month == 5 or month == 7 or month == 8 or month == 10 or month == 12 then
					if day > 0 and day < 32 then

					else
						return false
					end
				elseif month == 4 or month == 6 or month == 9 or month == 11 then
					if day > 0 and day < 31 then

					else
						return false
					end
				elseif month == 2 then
					if day > 0 and day < 29 then

					elseif day == 29 then
						if (year%400 == 0) or (year%4 == 0 and year%100 ~= 0) then

						else
							return false
						end
					 else
						return false
					 end
				else
					return false
				end
			end
		end

		--check start date whether less then end date
		if tmp_tb[4] < tmp_tb[1] then
			return false
		elseif tmp_tb[4] == tmp_tb[1] then
			if tmp_tb[5] < tmp_tb[2] then
				return false
			elseif tmp_tb[5] == tmp_tb[2] then
				if tmp_tb[6] < tmp_tb[3] then
					return false
				end
			end
		end		
		return true
	end

end

--like:21:29
function clock(val)
	if not val then
		return true
	end
	
	if val:match("^[0-9:~]+[0-9:~]*$") == nil then
		return false
	else
		local tmp_tb = {}
		tmp_tb[1],tmp_tb[2],tmp_tb[3],tmp_tb[4] = val:match("^(%d+):(%d+)~(%d+):(%d+)$")
		if tmp_tb[1] == nil or tmp_tb[2] == nil or tmp_tb[3] == nil or tmp_tb[4] == nil then
			return false
		end
		--check number format
		for k2,v2 in util.kspairs(tmp_tb) do
			if v2:len() > 2 then
				return false
			else
				if k2 == 1 or k2 == 3 then
					local tmp = tonumber(v2)
					if tmp < 0 or tmp > 24 then
						return false
					end
				else
					local tmp = tonumber(v2)
					if tmp < 0 or tmp > 60 then
						return false
					end
				end
			end
		end
		--check start time whether less then end time
		if tmp_tb[3] < tmp_tb[1] then
			return false
		elseif tmp_tb[3] == tmp_tb[1] then
			if tmp_tb[4] <= tmp_tb[2] then
				return false
			end
		end
		return true
	end

end

function bool(val)
	if val == "1" or val == "yes" or val == "on" or val == "true" then
		return true
	elseif val == "0" or val == "no" or val == "off" or val == "false" then
		return true
	elseif val == "" or val == nil then
		return true
	end

	return false
end

function uinteger(val)
	local n = tonumber(val)
	if n ~= nil and math.floor(n) == n and n >= 0 then
		return true
	end

	return false
end

function integer(val)
	local n = tonumber(val)
	if n ~= nil and math.floor(n) == n then
		return true
	end

	return false
end

function ufloat(val)
	local n = tonumber(val)
	return ( n ~= nil and n >= 0 )
end

function float(val)
	return ( tonumber(val) ~= nil )
end

function ipaddr(val)
	return ip4addr(val) or ip6addr(val)
end

function neg_ipaddr(v)
	if type(v) == "string" then
		v = v:gsub("^%s*!", "")
	end
	return v and ipaddr(v)
end

function ip4addr(val)
	if val then
		return ip.IPv4(val) and true or false
	end

	return false
end

function abc_ip4addr(val,exception)
	if exception then
		local exception_tb = util.split(exception,"&")
		for k,v in ipairs(exception_tb) do
			if val == v then
				return true
			end
		end
	end
	if ip.IPv4(val) then
		local b1, b2, b3, b4 = val:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")

		b1 = tonumber(b1)
		b2 = tonumber(b2)
		b3 = tonumber(b3)
		b4 = tonumber(b4)

		if b1 and b2 and b3 and b4 and b1 > 0 and b1 <= 223 and b1 ~= 127 and b2 >=0 and b2 <= 255 and b3 >=0 and b3 <= 255 and b4 >0 then
			return true
		end
	else
		return false
	end
end

function ip4addrrange(val)
	if val then
		if val:match("-") then
			local tmp = util.split(val, "-")
			if tmp[1] and tmp[2] then
				if (ip.IPv4(tmp[1]) and true or false) and (ip.IPv4(tmp[2]) and true or false) then
					return true
				else
					return false
				end
			else
				return false
			end
		else
			return ip.IPv4(val) and true or false
		end
	end
end

function neg_ip4addr(v)
	if type(v) == "string" then
		v = v:gsub("^%s*!", "")
	end
		return v and ip4addr(v)
end

function ip4prefix(val)
	val = tonumber(val)
	return ( val and val >= 0 and val <= 32 )
end

function ip6addr(val)
	if val then
		return ip.IPv6(val) and true or false
	end

	return false
end

function ip6prefix(val)
	val = tonumber(val)
	return ( val and val >= 0 and val <= 128 )
end

function port(val)
	val = tonumber(val)
	return ( val and val >= 1 and val <= 65535 )
end

function upnpexport(val,port_list)
	if port(val) then
		local list_tb = util.split(port_list,"&")
		for k,v in ipairs(list_tb) do
			if val == v then
				return false
			end
		end
		return true
	end

	return false
end

function portrange(val)
	local p1, p2 = val:match("^(%d+)%-(%d+)$")
	if p1 and p2 and port(p1) and port(p2) and (tonumber(p2) > tonumber(p1)) then
		return true
	else
		return port(val)
	end
end

function isdif(param1,param2)
	local ret = false
	local param1_min = param1
	local param1_max = param1
	local param2_min = param2
	local param2_max = param2

	if param1:match("%-") then
		param1_min,param1_max = param1:match("([0-9]+)%-([0-9]+)")
	end
	if param2:match("%-") then
		param2_min,param2_max = param2:match("([0-9]+)%-([0-9]+)")
	end

	if tonumber(param1_max) < tonumber(param2_min) then
		ret = true
	end
	if tonumber(param1_min) > tonumber(param2_max) then
		ret = true
	end
	
	return ret
end

function dif_portrange(val,port_list)
	if not portrange(val) then
		return false
	end
	
	local portlist = util.split(port_list,"&")
	for k,v in ipairs(portlist) do
		if not isdif(val,v) then
			return false
		end
	end
	
	return true
end

function macaddr(val)
	if val and val:match(
		"^[a-fA-F0-9]+:[a-fA-F0-9]+:[a-fA-F0-9]+:" ..
		 "[a-fA-F0-9]+:[a-fA-F0-9]+:[a-fA-F0-9]+$"
	) then
		local parts = util.split( val, ":" )

		for i = 1,6 do
			parts[i] = tonumber( parts[i], 16 )
			if parts[i] < 0 or parts[i] > 255 then
				return false
			end
		end

		return true
	end

	return false
end

function cfgname(val,name_list)
	if #val > 32 or #val == 0 then
		return false
	end
	return true
end

function abc_ip4addr_domain(val)
	if not val or (val and (#val < 3 or #val > 64)) then
		return false
	end
	if val:match("^%d+%.%d+%.%d+%.%d+$") then
		return abc_ip4addr(val)
	elseif val:match("^%w[%-a-zA-Z0-9]*[%.%-a-zA-Z0-9]+[%-0-9a-zA-Z]+$") and not val:match("%.%-") then
		return true
	else
		return false
	end
end

function extension(val,extension_list)
	if not tonumber(val) then
		return false
	end
	local extension_list_tb = util.split(extension_list,"&")
	for k,v in ipairs(extension_list_tb) do
		if val == v then
			return false
		end
	end
	return true
end

function localport(val,port_list)
	local port_list_tb = util.split(port_list,"&")
	for k,v in ipairs(port_list_tb) do
		if val == v then
			return false
		end
	end

	local port = tonumber(val)

	if port and port > 1 and port < 65535 then
		return true
	else
		return false
	end
end

function hostname(val)
	if val and (#val < 25) and (
	   val:match("^[a-zA-Z]+$") or
	   (val:match("^[a-zA-Z0-9][a-zA-Z0-9%-%.]*[a-zA-Z0-9]$") and
		val:match("[^0-9%.]"))
	) then
		return true
	end
	return false
end

function host(val)
	return hostname(val) or ipaddr(val)
end

function network(val)
	return uciname(val) or host(val)
end

function wpakey(val)
	if #val == 64 then
		return (val:match("^[a-fA-F0-9]+$") ~= nil)
	else
		return (#val >= 8) and (#val <= 63)
	end
end

function wepkey(val)
	if val:sub(1, 2) == "s:" then
		val = val:sub(3)
	end

	if (#val == 10) or (#val == 26) then
		return (val:match("^[a-fA-F0-9]+$") ~= nil)
	else
		return (#val == 5) or (#val == 13)
	end
end

function string(val)
	return true		-- Everything qualifies as valid string
end

function directory( val, seen )
	local s = fs.stat(val)
	seen = seen or { }

	if s and not seen[s.ino] then
		seen[s.ino] = true
		if s.type == "dir" then
			return true
		elseif s.type == "lnk" then
			return directory( fs.readlink(val), seen )
		end
	end

	return false
end

function file( val, seen )
	local s = fs.stat(val)
	seen = seen or { }

	if s and not seen[s.ino] then
		seen[s.ino] = true
		if s.type == "reg" then
			return true
		elseif s.type == "lnk" then
			return file( fs.readlink(val), seen )
		end
	end

	return false
end

function device( val, seen )
	local s = fs.stat(val)
	seen = seen or { }

	if s and not seen[s.ino] then
		seen[s.ino] = true
		if s.type == "chr" or s.type == "blk" then
			return true
		elseif s.type == "lnk" then
			return device( fs.readlink(val), seen )
		end
	end

	return false
end

function uciname(val)
	return (val:match("^[a-zA-Z0-9_]+$") ~= nil)
end

function neg_network_ip4addr(val)
	if type(v) == "string" then
		v = v:gsub("^%s*!", "")
		return (uciname(v) or ip4addr(v))
	end
end

function range(val, min, max)
	val = tonumber(val)
	min = tonumber(min)
	max = tonumber(max)

	if val ~= nil and min ~= nil and max ~= nil then
		return ((val >= min) and (val <= max))
	end

	return false
end

function min(val, min)
	val = tonumber(val)
	min = tonumber(min)

	if val ~= nil and min ~= nil then
		return (val >= min)
	end

	return false
end

function max(val, max)
	val = tonumber(val)
	max = tonumber(max)

	if val ~= nil and max ~= nil then
		return (val >=0 and val <= max)
	end

	return false
end

function neg(val, what)
	if what and type(_M[what]) == "function" then
		return _M[what](val:gsub("^%s*!%s*", ""))
	end

	return false
end

function list(val, what, ...)
	if type(val) == "string" and what and type(_M[what]) == "function" then
		for val in val:gmatch("%S+") do
			if not _M[what](val, ...) then
				return false
			end
		end

		return true
	end

	return false
end

function numberrange(val)
	local num_tb = util.split(val,"|")
	for k,v in ipairs(num_tb) do
		if v and v ~= "" then
			for x,y in ipairs(num_tb) do
				if y and y ~= "" and x ~= k and v == y then
					return false
				end
			end
			if false == range(v,1,32) then
				local p1, p2 = v:match("^(%d+)%-(%d+)$")
				if not (p1 and p2 and range(p1,1,32) and range(p2,1,32) and (tonumber(p2) > tonumber(p1))) then
					return false
				end
				for x,y in ipairs(num_tb) do
					if y and y ~= "" and range(y,p1,p2) then
						return false
					end
				end
			end
		else
			return false
		end
	end
	return true
end

function numberprefix(val)
	local num_tb = util.split(val,"|")
	for k,v in ipairs(num_tb) do
		if v and v ~= "" and v:match("^[\*\+]*[0-9a-zA-Z]+$") then
			for x,y in ipairs(num_tb) do
				if y and y ~= "" and x ~= k and v == y then
					return false
				end
				if #y > 32 then
					return false
				end
			end
		else
			return false
		end
	end
	return true
end

function phonenumber(val)
	if val:match("[0-9a-zA-Z*#]+") and #val < 33 then
		return true
	end

	return false
end

function pincode(val)
	if val:match("^%d+$") and #val > 3 and #val < 9 then
		return true
	end

	return false
end

function url(val)

	-- util.exec("echo "..tostring(#val)..">>/datatype.txt")
	-- --if val:match("^tftp://") or val:match("^ftp://") or val:match("^http://") or val:match("^https://") or val:match("^ftps://") then
	-- if val:match("^tftp") then
	-- 	return true
	-- else
	-- 	return false
	-- end
	return true
end

function notempty(val)
	if "" == val then
		return false
	else
		return true
	end
end

function regular(val)
	local blRange = false
	local Brack = 0
	local bSlash = false
	local exclam =false

	if #val > 1024 then
		return false
	end
	
	for i=1,#val do
		local c = sub(val,i,i)
		if c:match("[0-9a-zA-Z^,|#]") then
		
		elseif(c:match("[%.%*%+%$%?]")) then
			if i > 1 and "\\" == sub(val,i-1,i-1) then
				return true
			end
			if blRange then
				return false
			end
			if c:match("?") then
				exclam = true
			end
		elseif '[' == c then
			if blRange then
				return false
			end
			blRange = true
		elseif ']' == c then
			if not blRange then
				return false
			end
			blRange = false
		elseif '-' == c then
			if not blRange then
				return false
			end			
		elseif '{' == c then
			if blRange then
				return false
			end
			blRange = true
		elseif '}' == c then
			if not blRange then
				return false
			end
			blRange = false
		elseif '(' == c then
			if blRange then
				return false
			else
				Brack = Brack + 1
			end		
		elseif ')' == c then
			if blRange or 0 == Brack then
				return false
			else
				Brack = Brack - 1
			end
		elseif '!' == c then
			if not exclam then
				return false
			end
		elseif '\\' == c then
			if i >= #val then
				return false
			end
		else
			return false
		end
	end
	if 0 ~= Brack or blRange then
		return false
	else
		return true
	end
end

function regular_simple(val)
	if #val > 32 then
		return false
	else
		return regular(val)
	end
end

function digitmap(val)
	local blRange = false
	local Brack = 0
	for i=1,#val do
		local c = sub(val,i,i)
		if c:match("[%d*#ABCD]") then
			
		elseif(c:match("[\.\?\+x]")) then
			if blRange then
				return false
			end
		elseif '[' == c then
			if blRange then
				return false
			end
			blRange = true
		elseif ']' == c then
			if not blRange then
				return false
			end
			blRange = false
		elseif '-' == c then
			if not blRange then
				return false
			end
		elseif '(' == c then
			if blRange then
				return false
			else
				Brack = Brack + 1
			end
		elseif ')' == c then
			if blRange or 0 == Brack then
				return false
			else
				Brack = Brack - 1
			end
		elseif '|' == c then
			if blRange then
				return false
			end
		else
			return false
		end
	end
	if 0 ~= Brack or blRange then
		return false
	else
		return true
	end
end

function netmask(val)
	if not ip4addr(val) then
		return false
	end

	local x = {}
	local zero = false
	x[1],x[2],x[3],x[4] = val:match("(%d+)%.(%d+)%.(%d+)%.(%d+)")
	for i=1,4 do
		for j=0,7 do
			local b = bit.band(tonumber(x[i]),bit.rshift(128,j))
			if 0 == b then
				zero = true
			end
			if b > 0 and zero then
				return false
			end
		end
	end
	return true
end

function cidr(val)
	if "0.0.0.0" == val or "0.0.0.0/0" == val or "0.0.0.0/0.0.0.0" == val then
		return true
	end
	if val:match("^%d+%.%d+%.%d+%.%d+$") or val:match("^%d+%.%d+%.%d+%.%d+/%d+$") then
		return ip4addr(val)
	elseif val:match("^%d+%.%d+%.%d+%.%d+/%d+%.%d+%.%d+%.%d+$") then
		return abc_ip4addr(val:match("^(%d+%.%d+%.%d+%.%d+)/")) and netmask(val:match("/(%d+%.%d+%.%d+%.%d+)$"))
	else 
		return false
	end
end
