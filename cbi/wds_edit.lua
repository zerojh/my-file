--[[

]]--
local ds = require "luci.dispatcher"
local uci = require "luci.model.uci".cursor()
local fs_server = require "luci.scripts.fs_server"
local fs = require "luci.fs"

local dev_name = ""
if fs.access("/lib/modules/3.14.18/rt2860v2_ap.ko") then
	dev_name = "ra0"
else
	dev_name = "radio0"
end

local this_section = arg[1] or ""
local this_edit = arg[2] or ""
local wds_mode = uci:get("wireless",dev_name,"wdsmode")
local profile = uci:get_all("wireless")

if luci.http.formvalue("save") then
	--@ save action
	local wds_config_tb = luci.http.formvaluetable("wds") or {}

	--@ 
	for k,v in pairs(wds_config_tb) do
		if k ~= "cus_bssid" and v then
			uci:set("wireless",this_section,k,v)
		end
	end

	if wds_config_tb.cus_bssid and wds_config_tb.wdspeermac == "none" then
		uci:set("wireless",this_section,"wdspeermac",wds_config_tb.cus_bssid)
	end
	
	--@ new section
	if this_edit == "add" then
		--@ set default option
		uci:set("wireless",this_section,"device",dev_name)
		uci:set("wireless",this_section,"mode","ap")
		uci:set("wireless",this_section,"network","lan")--?
	end
	
	uci:save("wireless")
	
	luci.http.redirect(ds.build_url("admin","network","wlan","wds_config"))
elseif luci.http.formvalue("cancel") then
	--@ cancel action
	
	luci.http.redirect(ds.build_url("admin","network","wlan","wds_config"))
elseif luci.http.formvalue("status") then
	--@ refresh 
	fs_server.get_wifi_list("refresh")
else
	local wds = {}
	local index_tb = {}
	local wifi_list = fs_server.get_wifi_list()
	local wds_model = uci:get("wireless",dev_name,"wdsmode") or "disable"
	local local_ssid = {}
	local tmp_ssid_tb = {}
	local tmp_wds_tb = {}
	for k,v in pairs(profile) do
		if v['.type'] == "wifi-iface" and v.ifname and string.find(v.ifname,"ra") then
			tmp_ssid_tb[v.ifname] = v.ssid
		end
		if v['.type'] == "wifi-iface" and v.ifname and string.find(v.ifname,"wds") then
			tmp_wds_tb[v.ifname] = v.index
		end
	end
	
	--@ new
	if this_edit == "add" then
		for i=1,4 do
			local flag = true
			for _,v in pairs(tmp_wds_tb) do
				if v and tonumber(v) == i then
					flag = false
					break
				end
			end

			if flag == true then
				table.insert(index_tb,i)
			end
		end
	--@ edit
	else
		local tmp_tb = uci:get_all("wireless",this_section) or {}
		local wds_str = uci:get("wireless",this_section,"ifname")
		local ssid_str = "ra"..wds_str:match("wds(%d+)")
		local_ssid[wds_str] = tmp_ssid_tb[ssid_str]
		
		for k,v in pairs(tmp_tb) do
			if k and v then
				wds[k] = v
			end
		end
		wds["bssid"] = tmp_tb.wdspeermac or ""
	end

	for k,v in pairs(tmp_ssid_tb) do
		local wds_str = "wds"..k:match("ra(%d+)")
		if not tmp_wds_tb[wds_str] then
			local_ssid[wds_str] = v
		end
	end
	
	luci.template.render("admin_network/wds_edit",{this_edit=this_edit,wds_model=wds_model,wds=wds,index_tb=index_tb,wifi_list=wifi_list,local_ssid=local_ssid})
end
