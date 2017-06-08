local bridge_str = argv[1]
local endpoint_interface = {}
local bypass_media = {}
local codec_list = {}

function split(str, pat, max, regex)
	pat = pat or "\n"
	max = max or #str

	local t = {}
	local c = 1

	if #str == 0 then
		return {""}
	end

	if #pat == 0 then
		return nil
	end

	if max == 0 then
		return str
	end

	repeat
		local s, e = str:find(pat, c, not regex)
		max = max - 1
		if s and max < 0 then
			t[#t+1] = str:sub(c)
		else
			t[#t+1] = str:sub(c, s and s - 1)
		end
		c = e and e + 1 or #str + 1
	until not s or max < 0

	return t
end

if session:ready() then
	local from = session:getVariable("chan_name")
	if from:match("^sofia") then
		local max_forwards = session:getVariable("max_forwards")
		if tonumber(max_forwards) < 3 then
			session:setVariable("max_forwards",3)
		end
	end

	if (bridge_str:match("sofia/") or bridge_str:match("user/")) and from:match("^sofia") then
		local from_name = from:match("^sofia/gateway/(%d+_%d+)") or from:match("^sofia/user/(%d+)") or "unknown"
		local bridge_name = bridge_str:match("sofia/gateway/(%d+_%d+)") or bridge_str:match("user/(%w+)@") or "unknown"
		if endpoint_interface[from_name] == endpoint_interface[bridge_name] and bypass_media[from_name] and bypass_media[bridge_name] then
			session:consoleLog("info","call from interface:"..(endpoint_interface[from_name] or "unknown").." to interface:"..(endpoint_interface[bridge_name] or "unknown")..",set bypass_media=true")
			session:setVariable("bypass_media","true")
			session:setVariable("proxy_media","false")
		else
			session:consoleLog("info","call from interface:"..(endpoint_interface[from_name] or "unknown").." to interface:"..(endpoint_interface[bridge_name] or "unknown")..",set bypass_media=false")
			session:setVariable("bypass_media","false")
			session:setVariable("proxy_media","false")
			local caller_codec = session:getVariable("ep_codec_string")
			local caller_codec_tbl = split(caller_codec,",")
			for k = #caller_codec_tbl,1,-1 do
				local codec = caller_codec_tbl[k]:match("^(%w+)@") or "NULL"
				if not string.find(codec_list[bridge_name],codec) then
					table.remove(caller_codec_tbl,k)
				end
			end
			local codec_string = table.concat(caller_codec_tbl,",")
			session:consoleLog("info","compare codec: caller["..caller_codec.."] vs called["..codec_list[bridge_name].."]")
			session:consoleLog("info","compare result: "..codec_string)
			session:execute("export","nolocal:absolute_codec_string="..codec_string)
		end
		-- session:setVariable("bypass_media","false")
		-- session:setVariable("proxy_media","false")
	elseif (bridge_str:match("sofia/") or bridge_str:match("user/")) then
		if from:match("^FreeTDM") and "pos" == session:getVariable("channel_work_mode") then
			session:consoleLog("info","caller channel is working in pos mode, set called codec to PCMU,PCMA")
			session:execute("export","nolocal:absolute_codec_string=PCMU,PCMA")
		else
			local bridge_name = bridge_str:match("sofia/gateway/(%d+_%d+)") or bridge_str:match("user/(%w+)@") or "unknown"
			session:consoleLog("info","set called codec to "..(codec_list[bridge_name] or "PCMU,PCMA"))
			session:execute("export","nolocal:absolute_codec_string="..(codec_list[bridge_name] or "PCMU,PCMA"))
		end
	end
end
