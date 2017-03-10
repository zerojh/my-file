
local uci = require "luci.model.uci".cursor()

local sipt = {}
for k,v in pairs(uci:get_all("endpoint_siptrunk1") or {}) do
	if v.index and v.profile then
		sipt[v.index]=v.profile
	end
end
local flag=false
local forward_option_tb = {"forward_uncondition","forward_busy","forward_noreply"}
local port_tb = {"1","2"}
for k,v in pairs(uci:get_all("endpoint_fxso1") or {}) do
	if v[".type"] == "fxs" then
		for _,port_index in ipairs(port_tb) do
			for _,forward_option in ipairs(forward_option_tb) do
				local port_forward_option = forward_option.."_"..port_index

				if v[port_forward_option] then
					if type(v[port_forward_option]) == "string" then
						local tmp_tb = {}
						table.insert(tmp_tb, v[port_forward_option])
						v[port_forward_option] = tmp_tb
					end
					if type(v[port_forward_option]) == "table" and next(v[port_forward_option]) then
						for x,y in ipairs(v[port_forward_option]) do
							if y:match("^SIPT%-%d+_%d+") then
								local profile,idx = y:match("^SIPT%-(%d+)_(%d+)")
								if sipt[idx] ~= profile then
									v[port_forward_option][x] = string.gsub(y,"^SIPT%-%d+_%d+","SIPT-"..(sipt[idx] or "unknown").."_"..idx)
								end
							end
						end
					end
					uci:set("endpoint_fxso1", k, port_forward_option, v[port_forward_option])
					flag=true
				end
			end
		end
	end
end
if flag then
	uci:save("endpoint_fxso1")
	uci:commit("endpoint_fxso1")
end
flag=false
forward_option_tb = {"forward_uncondition","forward_unregister","forward_busy","forward_noreply"}
for k,v in pairs(uci:get_all("endpoint_sipphone1") or {}) do
	for _,forward_option in ipairs(forward_option_tb) do
		if v[forward_option] then
			if type(v[forward_option]) == "string" then
				local tmp_tb = {}
				table.insert(tmp_tb, v[forward_option])
				v[forward_option] = tmp_tb
			end
			if type(v[forward_option]) == "table" and next(v[forward_option]) then
				for x,y in ipairs(v[forward_option]) do
					if y:match("^SIPT%-%d+_%d+") then
						local profile,idx = y:match("^SIPT%-(%d+)_(%d+)")
						if sipt[idx] ~= profile then
							v[forward_option][x] = string.gsub(y,"^SIPT%-%d+_%d+","SIPT-"..(sipt[idx] or "unknown").."_"..idx)
						end
					end
				end
			end
			uci:set("endpoint_sipphone1", k, forward_option, v[forward_option])
			flag=true
		end
	end
end
if flag then
	uci:save("endpoint_sipphone1")
	uci:commit("endpoint_sipphone1")
end
