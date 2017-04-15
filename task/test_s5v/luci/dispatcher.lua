
--- LuCI web dispatcher.
local fs = require "nixio.fs"
local sys = require "luci.sys"
local init = require "luci.init"
local util = require "luci.util"
local http = require "luci.http"
local nixio = require "nixio", require "nixio.util"
log = require "luci.log"
module("luci.dispatcher", package.seeall)
context = util.threadlocal()
uci = require "luci.model.uci"
i18n = require "luci.i18n"
_M.fs = fs

authenticator = {}

-- Index table
local index = nil

-- Fastindex
local fi

function get_srv_addr(addrtype)
	local uci = require "luci.model.uci".cursor()
	local proto = http.getenv("HTTPS") and "https://" or "http://"
	local ip = ""
	if "current" == addrtype then
		ip = http.getenv("SERVER_ADDR") or ""
	else
		ip = uci:get("network","lan","ipaddr") or http.getenv("SERVER_ADDR") or ""
	end

	local port = ""

	if http.getenv("HTTPS") then
		port = uci:get("lucid","https","address")
		if port and "table" == type(port) then
			port = port[1]
		end
	else
		port = uci:get("lucid","http","address")
		if port and "table" == type(port) then
			port = port[1]
		end
	end

	return proto..ip..":"..port
end
--- Build the URL relative to the server webroot from given virtual path.
-- @param ...	Virtual path
-- @return 		Relative URL
function build_url(...)
	local path = {...}
	local url = { http.getenv("SCRIPT_NAME") or "" }

	local k, v
	for k, v in pairs(context.urltoken) do
		url[#url+1] = "/;"
		url[#url+1] = http.urlencode(k)
		url[#url+1] = "="
		url[#url+1] = http.urlencode(v)
	end

	local p
	for _, p in ipairs(path) do
		if p:match("^[a-zA-Z0-9_%-%.%%/,;]+$") then
			url[#url+1] = "/"
			url[#url+1] = p
		end
	end

	return table.concat(url, "")
end

--- Check whether a dispatch node shall be visible
-- @param node	Dispatch node
-- @return		Boolean indicating whether the node should be visible
function node_visible(node)
   if node then
	  return not (
		 (not node.title or #node.title == 0) or
		 (not node.target or node.hidden == true) or
		 (type(node.target) == "table" and node.target.type == "firstchild" and
		  (type(node.nodes) ~= "table" or not next(node.nodes)))
	  )
   end
   return false
end

--- Return a sorted table of visible childs within a given node
-- @param node	Dispatch node
-- @return		Ordered table of child node names
function node_childs(node)
	local rv = { }
	if node then
		local k, v
		for k, v in util.spairs(node.nodes,
			function(a, b)
				return (node.nodes[a].order or 100)
				     < (node.nodes[b].order or 100)
			end)
		do
			if node_visible(v) then
				rv[#rv+1] = k
			end
		end
	end
	return rv
end


--- Send a 404 error code and render the "error404" template if available.
-- @param message	Custom error message (optional)
-- @return			false
function error404(message)
	luci.http.status(404, "Not Found")
	-- message = message or "Not Found"

	-- require("luci.template")
	-- if not luci.util.copcall(luci.template.render, "error404") then
	-- 	luci.http.prepare_content("text/plain")
	-- 	luci.http.write(message)
	-- end
	-- return false
	luci.template.render("error404", {})
end
--- Send a 500 error code and render the "error500" template if available.
-- @param message	Custom error message (optional)#
-- @return			false
function error500(message)
	luci.util.perror(message)
	 if not context.template_header_sent then
	 	local str=""
	 	luci.http.status(500, "Internal Server Error")
	 	luci.http.prepare_content("text/html")
	 	message=string.gsub(message,"/usr/lib/lua/luci/","")
	 	message=string.gsub(message,".lua","")
	 	message=string.gsub(message,"nil","null")
	 	str="<!DOCTYPE html><html><head></head>"
	 	str=str.."<body style='background-color:#f3f4eb;padding-top:58px;'>"
	 	str=str.."<div style='margin-left:auto;margin-right:auto;background-color:#eaeadf;max-width:960px;'>"
	 	str=str.."<h2 style='font-size:20px;color:#0069d6;line-height: 36px;padding-top: 4px;font-family: Trebuchet MS,Verdana,sans-serif;padding-left: 10px;'>500 Internal Server Error</h2>"
		str=str.."<p style='font-size:13px;line-height:18px;margin-left:10px;'>Sorry, the server encountered an unexpected error !</p>"
		str=str.."<pre style='background-color:#f5f5f5;padding: 8.5px;font-size:12px;line-height:18px;border: 1px solid #ccc;'>"..message.."</pre></div></body></html>"
	 	luci.http.write(str)
	 else
	 	require("luci.template")
	 	message=string.gsub(message,"/usr/lib/lua/luci/","")
 		message=string.gsub(message,".lua","")
 		message=string.gsub(message,"nil","null")
	 	if not luci.util.copcall(luci.template.render, "error500", {message=message}) then
	 		luci.http.prepare_content("text/plain")
	 		luci.http.write(message)
	 	end
	 end
	
	--luci.http.status(500, "Internal Server Error")
	--message = string.gsub(message,".lua","")
	--message = string.gsub(message,"nil","null")
	--luci.template.render("error500", {message = message})
	return false
end

function check_user_expires(username)
	if "admin" == username or "homeultera" == username then
		return true
	end

	local uci = require "luci.model.uci".cursor()
	local expires_epoch = uci:get("user",username,"expires_epoch")
	if expires_epoch and expires_epoch:match("^(%d+)$") then
		if tonumber(expires_epoch) > os.time() then
			return true
		end
	end
	return false
end
function authenticator.htmlauth(validator, accs, default)
	local user = luci.http.formvalue("username")
	local pass = luci.http.formvalue("password")
	local login_ip=luci.http.getenv("REMOTE_ADDR") or "unknown"
	local req_from = login_ip..":".. (luci.http.getenv("REMOTE_PORT") or "")
	local login_fail_log="/tmp/log/256/web_login_fail_"..login_ip
	local login_fail_cnt=tonumber(util.exec("cat "..login_fail_log.." | wc -l") or "0")
	local last_login_time=util.exec("tail -n 1 "..login_fail_log) or "0"
	last_login_time = tonumber(last_login_time == "" and "0" or last_login_time)
	local relative_time = os.time() - last_login_time

	if (login_fail_cnt < 5 or relative_time >= 30) and user and validator(user, pass) and check_user_expires(user) then
		log_str = req_from.." | ".."LoginSucc "
		log.web_operation_log("Info",log_str)
		if fs.access(login_fail_log) then
			os.execute("rm "..login_fail_log)
		end
		return user
	elseif user or pass then
		log_str = req_from.." | ".."LoginFail "
		os.execute("echo "..os.time().." >>/tmp/log/256/web_login_fail_"..login_ip)
		login_fail_cnt=tonumber(login_fail_cnt) + 1
		relative_time = 0
		log.web_operation_log("Error",log_str)
	end

	require("luci.i18n")
	require("luci.template")
	context.path = {}
	luci.http.header("Set-Cookie", "devckie="..luci.version.sn)
	luci.template.render("sysauth", {duser=default, fuser=user,login_fail_cnt=login_fail_cnt,relative_time=relative_time})
	return false
end

--- Dispatch an HTTP request.
-- @param request	LuCI HTTP Request object
function httpdispatch(request, prefix)
	luci.http.context.request = request

	local r = {}
	context.request = r
	context.urltoken = {}

	local pathinfo = http.urldecode(request:getenv("PATH_INFO") or "", true)

	if prefix then
		for _, node in ipairs(prefix) do
			r[#r+1] = node
		end
	end

	local tokensok = true
	for node in pathinfo:gmatch("[^/]+") do
		local tkey, tval
		if tokensok then
			tkey, tval = node:match(";(%w+)=([a-fA-F0-9]*)")
		end
		if tkey then
			context.urltoken[tkey] = tval
		else
			tokensok = false
			r[#r+1] = node
		end
	end

	--# special API for msg
	if pathinfo:match("^/gsm_") then
		local stat, err = util.coxpcall(function()
			dispatch(context.request,true)
		end, error500)	
	else
		local stat, err = util.coxpcall(function()
			dispatch(context.request)
		end, error500)
	end

	local status = request:formvalue("status") or ""
	local action = request:formvalue("action") or ""
	local req_from = (request:getenv("REMOTE_ADDR") or "") ..":".. (request:getenv("REMOTE_PORT") or "")
	local req_method = request:getenv("REQUEST_METHOD") or ""
	local req_uri = ""

	for k,v in ipairs(context.request) do
		req_uri = req_uri .."/".. v
	end

	if "" == status and "auto" ~= action and "more" ~= action and "default" ~= action then
		if "del" == action then
			req_uri = req_uri .. "/"..request:formvalue("cfg") or ""
		end
		local operation = log.operation_analysis(req_method,action,req_uri)
		local log_str = req_from.." | "..operation.." "..req_uri
		log.web_operation_log("Info",log_str)
	end
	
	luci.http.close()

	--context._disable_memtrace()
end

--- Dispatches a LuCI virtual path.
-- @param request	Virtual path
function dispatch(request,passport)
	--context._disable_memtrace = require "luci.debug".trap_memtrace("l")
	local ctx = context
	ctx.path = request

	local conf = require "luci.config"
	assert(conf.main,
		"/etc/config/luci seems to be corrupt, unable to find section 'main'")

	local lang = conf.main.lang or "auto"
	if lang == "auto" then
		local aclang = http.getenv("HTTP_ACCEPT_LANGUAGE") or ""
		aclang = string.lower(aclang)
		for lpat in aclang:gmatch("[%w-]+") do
			lpat = lpat and lpat:gsub("-", "_")
			if conf.languages[lpat] then
				lang = lpat
				break
			end
		end
	end
	require "luci.i18n".setlanguage(lang)

	local c = ctx.tree
	local stat
	if not c then
		c = createtree()
	end

	local track = {}
	local args = {}
	ctx.args = args
	ctx.requestargs = ctx.requestargs or args
	local n
	local token = ctx.urltoken
	local preq = {}
	local freq = {}

	for i, s in ipairs(request) do
		preq[#preq+1] = s
		freq[#freq+1] = s
		c = c.nodes[s]
		n = i
		if not c then
			break
		end

		util.update(track, c)

		if c.leaf then
			break
		end
	end

	if c and c.leaf then
		for j=n+1, #request do
			args[#args+1] = request[j]
			freq[#freq+1] = request[j]
		end
	end

	ctx.requestpath = ctx.requestpath or freq
	ctx.path = preq

	if track.i18n then
		i18n.loadc(track.i18n)
	end

	-- Init template engine
	if (c and c.index) or not track.notemplate then
		local tpl = require("luci.template")
		local media = track.mediaurlbase or luci.config.main.mediaurlbase
		if not pcall(tpl.Template, "themes/%s/header" % fs.basename(media)) then
			media = nil
			for name, theme in pairs(luci.config.themes) do
				if name:sub(1,1) ~= "." and pcall(tpl.Template,
				 "themes/%s/header" % fs.basename(theme)) then
					media = theme
				end
			end
			assert(media, "No valid theme found")
		end

		local function _ifattr(cond, key, val)
			if cond then
				local env = getfenv(3)
				local scope = (type(env.self) == "table") and env.self
				return string.format(
					' %s="%s"', tostring(key),
					luci.util.pcdata(tostring( val
					 or (type(env[key]) ~= "function" and env[key])
					 or (scope and type(scope[key]) ~= "function" and scope[key])
					 or "" ))
				)
			else
				return ''
			end
		end

		tpl.context.viewns = setmetatable({
		   write       = luci.http.write;
		   include     = function(name) tpl.Template(name):render(getfenv(2)) end;
		   translate   = i18n.translate;
		   translatef  = i18n.translatef;
		   export      = function(k, v) if tpl.context.viewns[k] == nil then tpl.context.viewns[k] = v end end;
		   striptags   = util.striptags;
		   pcdata      = util.pcdata;
		   media       = media;
		   theme       = fs.basename(media);
		   resource    = luci.config.main.resourcebase;
		   resource_cbi_js = luci.config.main.resourcebase.."/cbi-1.19.min.js";
		   ifattr      = function(...) return _ifattr(...) end;
		   attr        = function(...) return _ifattr(true, ...) end;
		}, {__index=function(table, key)
			if key == "controller" then
				return build_url()
			elseif key == "REQUEST_URI" then
				return build_url(unpack(ctx.requestpath))
			else
				return rawget(table, key) or _G[key]
			end
		end})
	end

	track.dependent = (track.dependent ~= false)
	assert(not track.dependent or not track.auto,
		"Access Violation\nThe page at '" .. table.concat(request, "/") .. "/' " ..
		"has no parent node so the access to this location has been denied.\n" ..
		"This is a software bug, please report this message at " ..
		"http://luci.subsignal.org/trac/newticket"
	)

	if passport then
		--# authorization for GSM API
		--[[
		local authorization = luci.http.getenv("AUTHORIZATION")
		local req_from = (luci.http.getenv("REMOTE_ADDR") or "") ..":".. (luci.http.getenv("REMOTE_PORT") or "")
		
		if authorization then
			--# 
			local auth_key = authorization:match("key=(.*)")
			local passwd_key = luci.sys.user.getpasswd("admin")--Only one user 'admin' now.
			local sault,key = passwd_key:match("$1$(.*)$(.*)")
			
			if auth_key == key then
				local log_str = req_from.." | Authorization Succ"
				log.web_operation_log("Info",log_str)
			else
				local log_str = req_from.." | Authorization Fail"
				log.web_operation_log("Info",log_str)
				luci.http.header("WWW-Authenticate","key="..sault)
				luci.http.status(405)
				return		
			end
		else
			local log_str = req_from.." | Authorization Fail"
			log.web_operation_log("Info",log_str)
			local passwd_key = luci.sys.user.getpasswd("admin")--Only one user 'admin' now.
			local sault = passwd_key:match("$1$(.*)$.*")

			if sault then
				luci.http.header("WWW-Authenticate","key="..sault)
				luci.http.status(401)
			else
				error404()
			end
			
			return
		end
		]]--
	else
		if track.sysauth then
			local sauth = require "luci.sauth"

			local authen = type(track.sysauth_authenticator) == "function"
			 and track.sysauth_authenticator
			 or authenticator[track.sysauth_authenticator]

			local def  = (type(track.sysauth) == "string") and track.sysauth
			local accs = def and {track.sysauth} or track.sysauth
			local sess = ctx.authsession
			local verifytoken = false
			if not sess then
				sess = luci.http.getcookie("sysauth")
				sess = sess and sess:match("^[a-f0-9]*$")
				verifytoken = true
			end

			local sdat = sauth.read(sess)
			local user

			if sdat then
				sdat = loadstring(sdat)
				setfenv(sdat, {})
				sdat = sdat()
				if not verifytoken or ctx.urltoken.stok == sdat.token then
					user = sdat.user
				end
			else
				local eu = http.getenv("HTTP_AUTH_USER")
				local ep = http.getenv("HTTP_AUTH_PASS")
				if eu and ep and luci.sys.user.checkpasswd_by_cryptpass(eu, ep) then
					authen = function() return eu end
				end
			end

			if not util.contains(accs, user) then
				if authen then
					ctx.urltoken.stok = nil
					local user, sess = authen(luci.sys.user.checkpasswd_by_cryptpass, accs, def)
					if not user or not util.contains(accs, user) then
						return
					else
						local sid = sess or luci.sys.uniqueid(16)
						if not sess then
							local token = luci.sys.uniqueid(16)
							sauth.write(sid, util.get_bytecode({
								user=user,
								token=token,
								secret=luci.sys.uniqueid(16)
							}),user)
							ctx.urltoken.stok = token
						end
						luci.http.header("Set-Cookie", "sysauth=" .. sid.."; path="..build_url())
						ctx.authsession = sid
						ctx.authuser = user
					end
				else
					luci.http.status(403, "Forbidden")
					return
				end
			else
				ctx.authsession = sess
				ctx.authuser = user
			end
		end
	end

	if track.setgroup then
		luci.sys.process.setgroup(track.setgroup)
	end

	if track.setuser then
		luci.sys.process.setuser(track.setuser)
	end

	local target = nil
	if c then
		if type(c.target) == "function" then
			target = c.target
		elseif type(c.target) == "table" then
			target = c.target.target
		end
	end

	if c and (c.index or type(target) == "function") then
		ctx.dispatched = c
		ctx.requested = ctx.requested or ctx.dispatched
	end

	if c and c.index then
		local tpl = require "luci.template"

		if util.copcall(tpl.render, "indexer", {}) then
			return true
		end
	end

	--require "os".execute("echo '"..(request[1] or "none")..", "..(request[2] or "none")..", "..(request[3] or "none").."' >> /tmp/aaaaaa")
	local access_permission = true
	if ctx.authuser and "admin" ~= ctx.authuser and "homeultera" ~= ctx.authuser and request[1] and "admin" == request[1] and request[2] and "logout" ~= request[2] then
		local uci = require "luci.model.uci".cursor()
		local menu_list={
			["status"]={
				["sipstatus"]="",["pstnstatus"]="",["client_list"]="",["vpn"]="",["wifi"]="",["currentcall"]="",["cdr"]="",
				["service"]="",["about"]=""
			},
			["system"]={
				["setting"]="",["security"]="",["provision"]="",["operationlog"]="",["servicelog"]="",["changeslog"]="",["backup_upgrade"]="",
				["voice"]="",["cmd"]="",["tr069"]="",["cloud"]="",["reboot"]="",["gsm_tools"]="",["diagnostics"]=""
			},
			["network"]={
				["setting"]="",["access_control"]="",["firewall"]="",["dhcp_server"]="",["port_map"]="",["dmz"]="",["diagnostics"]="",
				["ddns"]="",["static_route"]="",["upnpc"]="",["vpn"]="",["hosts"]="",["lte"]="",["uplink"]=""
			},
			["profile"]={
				["sip"]="",["codec"]="",["number"]="",["time"]="",["manipl"]="",["dial"]="",["fxso"]="",["numberlearning"]="",
			},
			["extension"]={
				["extension_sip"]="",["extension_ringgroup"]="",["extension_fxs"]=""
			},
			["trunk"]={
				["sip"]="",["fxo"]="",["mobile"]=""
			},
			["callcontrol"]={
				["setting"]="",["routegroup"]="",["route"]="",["featureCode"]="",["ivr"]="",["sms"]="",["ussd"]="",["sms_route"]="",["diagnostics"]=""
			},
		}
		local menu = request[2]
		local sub_menu = request[3]
		if menu_list[menu] then
			if sub_menu and ("overview" ~= sub_menu and "Overview" ~= sub_menu) and menu_list[menu][sub_menu] then
				if not uci:get("user",ctx.authuser.."_web",menu.."_"..sub_menu) then
					access_permission = false
				end
			elseif "status" ~= menu and "uci" ~= menu and (not sub_menu) then
				if not uci:get("user",ctx.authuser.."_web",menu) then
					access_permission = false
				end
			end
		end
	elseif "admin" == ctx.authuser and "admin" == request[1] and request[2] and "logout" ~= request[2] and "uci" ~= request[2] then
		-- admin can't view oem page
		local menu_list={["status"]="",["system"]="",["network"]="",["profile"]="",["extension"]="",["trunk"]="",["callcontrol"]=""}
		local menu = request[2]
		if not menu_list[menu] then
			access_permission = false
		end
	elseif "homeultera" == ctx.authuser and "admin" == request[1] and request[2] and "logout" ~= request[2] and "uci" ~= request[2] then
		-- homeultera only view oem page
		local menu_list = {}
		local menu = request[2]
		local sub_menu = request[3]
		if not menu_list[menu] then
			if "status" == menu and (not sub_menu or ("overview" == sub_menu or "Overview" == submenu)) then
				access_permission = true
			else
				access_permission = false
			end
		end
	end
	if access_permission and type(target) == "function" then
		util.copcall(function()
			local oldenv = getfenv(target)
			local module = require(c.module)
			local env = setmetatable({}, {__index=

			function(tbl, key)
				return rawget(tbl, key) or module[key] or oldenv[key]
			end})

			setfenv(target, env)
		end)

		local ok, err
		if type(c.target) == "table" then
			ok, err = util.copcall(target, c.target, unpack(args))
		else
			ok, err = util.copcall(target, unpack(args))
		end
		assert(ok,
		       "Failed to execute " .. (type(c.target) == "function" and "function" or c.target.type or "unknown") ..
		       " dispatcher target for entry '/" .. table.concat(request, "/") .. "'.\n" ..
		       "The called action terminated with an exception:\n" .. tostring(err or "(unknown)"))
	else
		local root = node()
		if not root or not root.target then
			error404("No root node was registered, this usually happens if no module was installed.\n" ..
			         "Install luci-mod-admin-full and retry. " ..
			         "If the module is already installed, try removing the /tmp/luci-indexcache file.")
		else
			error404("No page is registered at '/" .. table.concat(request, "/") .. "'.\n" ..
			         "If this url belongs to an extension, make sure it is properly installed.\n" ..
			         "If the extension was recently installed, try removing the /tmp/luci-indexcache file.")
		end
	end
end

--- Generate the dispatching index using the best possible strategy.
function createindex()
	local path = luci.util.libpath() .. "/controller/"
	local suff = { ".lua", ".lua.gz" }

	if luci.util.copcall(require, "luci.fastindex") then
		createindex_fastindex(path, suff)
	else
		createindex_plain(path, suff)
	end
end

--- Generate the dispatching index using the fastindex C-indexer.
-- @param path		Controller base directory
-- @param suffixes	Controller file suffixes
function createindex_fastindex(path, suffixes)
	index = {}

	if not fi then
		fi = luci.fastindex.new("index")
		for _, suffix in ipairs(suffixes) do
			fi.add(path .. "*" .. suffix)
			fi.add(path .. "*/*" .. suffix)
		end
	end
	fi.scan()

	for k, v in pairs(fi.indexes) do
		index[v[2]] = v[1]
	end
end

--- Generate the dispatching index using the native file-cache based strategy.
-- @param path		Controller base directory
-- @param suffixes	Controller file suffixes
function createindex_plain(path, suffixes)
	local controllers = { }
	for _, suffix in ipairs(suffixes) do
		nixio.util.consume((fs.glob(path .. "*" .. suffix)), controllers)
		nixio.util.consume((fs.glob(path .. "*/*" .. suffix)), controllers)
	end

	if indexcache then
		local cachedate = fs.stat(indexcache, "mtime")
		if cachedate then
			local realdate = 0
			for _, obj in ipairs(controllers) do
				local omtime = fs.stat(obj, "mtime")
				realdate = (omtime and omtime > realdate) and omtime or realdate
			end

			if cachedate > realdate then
				assert(
					sys.process.info("uid") == fs.stat(indexcache, "uid")
					and fs.stat(indexcache, "modestr") == "rw-------",
					"Fatal: Indexcache is not sane!"
				)

				index = loadfile(indexcache)()
				return index
			end
		end
	end

	index = {}

	for i,c in ipairs(controllers) do
		local modname = "luci.controller." .. c:sub(#path+1, #c):gsub("/", ".")
		for _, suffix in ipairs(suffixes) do
			modname = modname:gsub(suffix.."$", "")
		end

		local mod = require(modname)
		assert(mod ~= true,
		       "Invalid controller file found\n" ..
		       "The file '" .. c .. "' contains an invalid module line.\n" ..
		       "Please verify whether the module name is set to '" .. modname ..
		       "' - It must correspond to the file path!")

		local idx = mod.index
		assert(type(idx) == "function",
		       "Invalid controller file found\n" ..
		       "The file '" .. c .. "' contains no index() function.\n" ..
		       "Please make sure that the controller contains a valid " ..
		       "index function and verify the spelling!")

		index[modname] = idx
	end

	if indexcache then
		local f = nixio.open(indexcache, "w", 600)
		f:writeall(util.get_bytecode(index))
		f:close()
	end
end

--- Create the dispatching tree from the index.
-- Build the index before if it does not exist yet.
function createtree()
	if not index then
		createindex()
	end

	local ctx  = context
	local tree = {nodes={}, inreq=true}
	local modi = {}

	ctx.treecache = setmetatable({}, {__mode="v"})
	ctx.tree = tree
	ctx.modifiers = modi

	-- Load default translation
	require "luci.i18n".loadc("base")

	local scope = setmetatable({}, {__index = luci.dispatcher})

	for k, v in pairs(index) do
		scope._NAME = k
		setfenv(v, scope)
		v()
	end

	local function modisort(a,b)
		return modi[a].order < modi[b].order
	end

	for _, v in util.spairs(modi, modisort) do
		scope._NAME = v.module
		setfenv(v.func, scope)
		v.func()
	end

	return tree
end

--- Register a tree modifier.
-- @param	func	Modifier function
-- @param	order	Modifier order value (optional)
function modifier(func, order)
	context.modifiers[#context.modifiers+1] = {
		func = func,
		order = order or 0,
		module
			= getfenv(2)._NAME
	}
end

--- Clone a node of the dispatching tree to another position.
-- @param	path	Virtual path destination
-- @param	clone	Virtual path source
-- @param	title	Destination node title (optional)
-- @param	order	Destination node order value (optional)
-- @return			Dispatching tree node
function assign(path, clone, title, order)
	local obj  = node(unpack(path))
	obj.nodes  = nil
	obj.module = nil

	obj.title = title
	obj.order = order

	setmetatable(obj, {__index = _create_node(clone)})

	return obj
end

--- Create a new dispatching node and define common parameters.
-- @param	path	Virtual path
-- @param	target	Target function to call when dispatched.
-- @param	title	Destination node title
-- @param	order	Destination node order value (optional)
-- @return			Dispatching tree node
function entry(path, target, title, order)
	local c = node(unpack(path))

	c.target = target
	c.title  = title
	c.order  = order
	c.module = getfenv(2)._NAME

	return c
end

--- Fetch or create a dispatching node without setting the target module or
-- enabling the node.
-- @param	...		Virtual path
-- @return			Dispatching tree node
function get(...)
	return _create_node({...})
end

--- Fetch or create a new dispatching node.
-- @param	...		Virtual path
-- @return			Dispatching tree node
function node(...)
	local c = _create_node({...})

	c.module = getfenv(2)._NAME
	c.auto = nil

	return c
end

function _create_node(path)
	if #path == 0 then
		return context.tree
	end

	local name = table.concat(path, ".")
	local c = context.treecache[name]

	if not c then
		local last = table.remove(path)
		local parent = _create_node(path)

		c = {nodes={}, auto=true}
		-- the node is "in request" if the request path matches
		-- at least up to the length of the node path
		if parent.inreq and context.path[#path+1] == last then
		  c.inreq = true
		end
		parent.nodes[last] = c
		context.treecache[name] = c
	end
	return c
end

-- Subdispatchers --

function _firstchild()
   local path = { unpack(context.path) }
   local name = table.concat(path, ".")
   local node = context.treecache[name]

   local lowest
   if node and node.nodes and next(node.nodes) then
	  local k, v
	  for k, v in pairs(node.nodes) do
		 if not lowest or
			(v.order or 100) < (node.nodes[lowest].order or 100)
		 then
			lowest = k
		 end
	  end
   end

   assert(lowest ~= nil,
		  "The requested node contains no childs, unable to redispatch")

   path[#path+1] = lowest
   dispatch(path)
end

--- Alias the first (lowest order) page automatically
function firstchild()
   return { type = "firstchild", target = _firstchild }
end

--- Create a redirect to another dispatching node.
-- @param	...		Virtual path destination
function alias(...)
	local req = {...}
	return function(...)
		for _, r in ipairs({...}) do
			req[#req+1] = r
		end

		dispatch(req)
	end
end

--- Rewrite the first x path values of the request.
-- @param	n		Number of path values to replace
-- @param	...		Virtual path to replace removed path values with
function rewrite(n, ...)
	local req = {...}
	return function(...)
		local dispatched = util.clone(context.dispatched)

		for i=1,n do
			table.remove(dispatched, 1)
		end

		for i, r in ipairs(req) do
			table.insert(dispatched, i, r)
		end

		for _, r in ipairs({...}) do
			dispatched[#dispatched+1] = r
		end

		dispatch(dispatched)
	end
end


local function _call(self, ...)
	local func = getfenv()[self.name]
	assert(func ~= nil,
	       'Cannot resolve function "' .. self.name .. '". Is it misspelled or local?')

	assert(type(func) == "function",
	       'The symbol "' .. self.name .. '" does not refer to a function but data ' ..
	       'of type "' .. type(func) .. '".')

	if #self.argv > 0 then
		return func(unpack(self.argv), ...)
	else
		return func(...)
	end
end

--- Create a function-call dispatching target.
-- @param	name	Target function of local controller
-- @param	...		Additional parameters passed to the function
function call(name, ...)
	return {type = "call", argv = {...}, name = name, target = _call}
end


local _template = function(self, ...)
	require "luci.template".render(self.view)
end

--- Create a template render dispatching target.
-- @param	name	Template to be rendered
function template(name)
	return {type = "template", view = name, target = _template}
end


local function _cbi(self, ...)
	local cbi = require "luci.cbi"
	local tpl = require "luci.template"
	local http = require "luci.http"

	local config = self.config or {}
	local maps = cbi.load(self.model, ...)

	local state = nil

	for i, res in ipairs(maps) do
		res.flow = config
		local cstate = res:parse()
		if cstate and (not state or cstate < state) then
			state = cstate
		end
	end

	local function _resolve_path(path)
		return type(path) == "table" and build_url(unpack(path)) or path
	end

	if config.on_valid_to and state and state > 0 and state < 2 then
		http.redirect(_resolve_path(config.on_valid_to))
		return
	end

	if config.on_changed_to and state and state > 1 then
		http.redirect(_resolve_path(config.on_changed_to))
		return
	end

	if config.on_success_to and state and state > 0 then
		http.redirect(_resolve_path(config.on_success_to))
		return
	end

	if config.state_handler then
		if not config.state_handler(state, maps) then
			return
		end
	end

	http.header("X-CBI-State", state or 0)

	if not config.noheader then
		tpl.render("cbi/header", {state = state})
	end

	local redirect
	local messages
	local applymap   = false
	local pageaction = true
	local saveaction = true
	local parsechain = { }

	for i, res in ipairs(maps) do
		if res.apply_needed and res.parsechain then
			local c
			for _, c in ipairs(res.parsechain) do
				parsechain[#parsechain+1] = c
			end
			applymap = true
		end

		if res.redirect then
			redirect = redirect or res.redirect
		end

		if res.pageaction == false then
			pageaction = false
		end
		if res.saveaction == false then
			saveaction = false
		end

		if res.message then
			messages = messages or { }
			messages[#messages+1] = res.message
		end
	end

	for i, res in ipairs(maps) do
		res:render({
			firstmap   = (i == 1),
			applymap   = applymap,
			redirect   = redirect,
			messages   = messages,
			pageaction = pageaction,
			saveaction = saveaction,
			parsechain = parsechain
		})
	end

	if not config.nofooter then
		tpl.render("cbi/footer", {
			flow       = config,
			pageaction = pageaction,
			saveaction = saveaction,
			redirect   = redirect,
			state      = state,
			autoapply  = config.autoapply
		})
	end
end

--- Create a CBI model dispatching target.
-- @param	model	CBI model to be rendered
function cbi(model, config)
	return {type = "cbi", config = config, model = model, target = _cbi}
end


local function _arcombine(self, ...)
	local argv = {...}
	local target = #argv > 0 and self.targets[2] or self.targets[1]
	setfenv(target.target, self.env)
	target:target(unpack(argv))
end

--- Create a combined dispatching target for non argv and argv requests.
-- @param trg1	Overview Target
-- @param trg2	Detail Target
function arcombine(trg1, trg2)
	return {type = "arcombine", env = getfenv(), target = _arcombine, targets = {trg1, trg2}}
end


local function _form(self, ...)
	local cbi = require "luci.cbi"
	local tpl = require "luci.template"
	local http = require "luci.http"

	local maps = luci.cbi.load(self.model, ...)
	local state = nil

	for i, res in ipairs(maps) do
		local cstate = res:parse()
		if cstate and (not state or cstate < state) then
			state = cstate
		end
	end

	http.header("X-CBI-State", state or 0)
	tpl.render("header")
	for i, res in ipairs(maps) do
		res:render()
	end
	tpl.render("footer")
end

--- Create a CBI form model dispatching target.
-- @param	model	CBI form model tpo be rendered
function form(model)
	return {type = "cbi", model = model, target = _form}
end

--- Access the luci.i18n translate() api.
-- @class  function
-- @name   translate
-- @param  text    Text to translate
translate = i18n.translate

--- No-op function used to mark translation entries for menu labels.
-- This function does not actually translate the given argument but
-- is used by build/i18n-scan.pl to find translatable entries.
function _(text)
	return text
end
