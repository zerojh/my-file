
module ("luci.version", package.seeall)

require "ini"
nixio = require "nixio"
ini = INI.load("/etc/provision/control.conf")

model 	=	""
sn		=	""
hard_id	=	""
osver = ""
rootver = ""
imagever = ""
bootver = ""
-- wifiver = ""
mac = ""
default_password="admin"
license = {}
oem ={}

local imageinfo=""
if nixio.fs.access("/bin/updateimage") then
	local imageshow=io.popen("updateimage show")
	imageinfo=imageshow:read("*a")
	imageshow:close()
end

if nixio.fs.access("/proc/sys/kernel/osrelease") then
	io.input("/proc/sys/kernel/osrelease")
	osver = io.read("*all")
end

if nixio.fs.access("/proc/kernelversion") then
	io.input("/proc/kernelversion")
	rootver = io.read("*all")
end

-- if nixio.fs.access("/proc/wifiversion") then
-- 	io.input("/proc/wifiversion")
-- 	wifiver = io.read("*all")
-- end

-- io.input("/proc/imageversion")
-- imagever = io.read("*all")

io.input("/proc/bootversion")
bootver = io.read("*all")
if "0\n" == bootver then
	bootver = imageinfo and (imageinfo:match("mngt_sec%[0%]%.version:([0-9%.]+)") or "0") or "0.0"
end
if "0\n" == rootver then
	rootver = imageinfo and (imageinfo:match("mngt_sec%[2%]%.version:([0-9%.]+)") or "0") or "0.0"
end
-- if "0\n" == wifiver then
-- 	wifiver = imageinfo and (imageinfo:match("mngt_sec%[1%]%.version:([0-9%.]+)") or "0") or "0.0"
-- end

if ini then
	firmware_ver =	ini['firmware']['version'] .. " " .. (ini["firmware"]["build"] or "")
else
	firmware_ver = ""
end

function check_pstn_status()
	local uci = luci.model.uci.cursor()

	local fxso_cfg = uci:get_all("endpoint_fxso") or {}
	for k,v in pairs(fxso_cfg) do
		if "0-FXS" == v.slot_type and not license.fxs then
			uci:set("endpoint_fxso",k,"status","Disabled")
			uci:commit("endpoint_fxso")
		elseif "0-FXS" == v.slot_type and license.fxs then
			uci:set("endpoint_fxso",k,"status","Enabled")
			if license.fxs == 2 and (not uci:get("endpoint_fxso",k,"number_2")) then
				uci:set("endpoint_fxso",k,"number_2","8001")
				uci:set("endpoint_fxso",k,"port_2_reg","off")
				uci:set("endpoint_fxso",k,"notdisturb_2","Deactivate")
				uci:set("endpoint_fxso",k,"forward_uncondition_2","Deactivate")
				uci:set("endpoint_fxso",k,"forward_noreply_2","Deactivate")
				uci:set("endpoint_fxso",k,"waiting_2","Deactivate")
				uci:set("endpoint_fxso",k,"forward_busy_2","Deactivate")
				uci:set("endpoint_fxso",k,"hotline_2","Deactivate")
				uci:set("endpoint_fxso",k,"dsp_output_gain_2","0")
				uci:set("endpoint_fxso",k,"dsp_input_gain_2","0")
			end
			uci:commit("endpoint_fxso")
		end
		if "0-FXO" == v.slot_type and not license.fxo then
			uci:set("endpoint_fxso",k,"status","Disabled")
			uci:commit("endpoint_fxso")
		elseif "0-FXO" == v.slot_type and license.fxo then
			uci:set("endpoint_fxso",k,"status","Enabled")
			if license.fxo == 2 and (not uci:get("endpoint_fxso",k,"number_1")) then
				uci:set("endpoint_fxso",k,"number_1","8000")
				uci:set("endpoint_fxso",k,"port_1_reg","off")
				uci:set("endpoint_fxso",k,"slic_1","0")
				uci:set("endpoint_fxso",k,"dsp_input_gain_1","0")
				uci:set("endpoint_fxso",k,"dsp_output_gain_1","0")
				uci:set("endpoint_fxso",k,"sip_from_field_1","0")
				uci:set("endpoint_fxso",k,"sip_from_field_un_1","0")
			end
			uci:commit("endpoint_fxso")
		end
	end

	local mobile_cfg = uci:get_all("endpoint_mobile") or {}
	for k,v in pairs(mobile_cfg) do
		if "1-GSM" == v.slot_type or "1-LTE" == v.slot_type or "1-VOLTE" == v.slot_type then
			if license.gsm and (not license.lte) and (not license.volte) then
				uci:set("endpoint_mobile",k,"slot_type","1-GSM")
				uci:set("endpoint_mobile",k,"name","GSM")
				uci:set("endpoint_mobile",k,"status","Enabled")
			elseif license.lte and (not license.gsm) and (not license.volte) then
				uci:set("endpoint_mobile",k,"slot_type","1-LTE")
				uci:set("endpoint_mobile",k,"name","LTE")
				uci:set("endpoint_mobile",k,"status","Enabled")
			elseif license.volte and (not license.gsm) and (not license.lte) then
				uci:set("endpoint_mobile",k,"slot_type","1-VOLTE")
				uci:set("endpoint_mobile",k,"name","VOLTE")
				uci:set("endpoint_mobile",k,"status","Enabled")
			elseif (not license.gsm) and (not license.lte) and (not license.volte) then
				uci:set("endpoint_mobile",k,"status","Disabled")
			end
			uci:commit("endpoint_mobile")
			break
		end
	end
	local product = "UC200-1G1S1O"
	if "1T1S1O" == string.upper(uci:get("system","main","interface") or "") then
		product = "UC200-1T1S1O"
	elseif "1T2S" == string.upper(uci:get("system","main","interface") or "") then
		product = "UC200-1T2S"
	elseif "1T2O" == string.upper(uci:get("system","main","interface") or "") then
		product = "UC200-1T2O"
	elseif "1V1S1O" == string.upper(uci:get("system","main","interface") or "") then
		product = "UC200-1V1S1O"
	elseif "1V2S" == string.upper(uci:get("system","main","interface") or "") then
		product = "UC200-1V2S"
	elseif "1V2O" == string.upper(uci:get("system","main","interface") or "") then
		product = "UC200-1V2O"
	elseif "1G2S" == string.upper(uci:get("system","main","interface") or "") then
		product = "UC200-1G2S"
	elseif "1G2O" == string.upper(uci:get("system","main","interface") or "") then
		product = "UC200-1G2O"
	elseif "4S" == string.upper(uci:get("system","main","interface") or "") then
		product = "UC200-4S"
	elseif "3S1O" == string.upper(uci:get("system","main","interface") or "") then
		product = "UC200-3S1O"
	elseif "2S2O" == string.upper(uci:get("system","main","interface") or "") then
		product = "UC200-2S2O"
	elseif "1S3O" == string.upper(uci:get("system","main","interface") or "") then
		product = "UC200-1S3O"
	elseif "4O" == string.upper(uci:get("system","main","interface") or "") then
		product = "UC200-4O"
	else
		product = "UC200-1G1S1O"
	end
	os.execute("sed -i 's/-product UC200-[0-9a-zA-Z]*/-product "..product.."/g' /etc/init.d/freeswitch")
end

function device_info_init()
	local dpr = require "dpr"
	local uci = luci.model.uci.cursor()
	local util = require "luci.util"
	local license_model=""
	local hostname="UC200"

	dpr.reloadsyscfg()
	model	=	string.upper(dpr.getproduct() or "")
	license_model = model
	sn    	= 	string.upper(dpr.getdevicesn() or "")
	hard_id	=	string.upper(nixio.fs.access("/bin/readflashid") and util.exec("readflashid") or (dpr.gethardwareid() or ""))
	mac 	=	string.gsub(string.upper(util.exec("readmac") or ""),":","-")
	if sn ~= "" and string.len(sn) == 19 and sn:match("^[0-9A-Fa-f%-]*$") then
		uci:set("ddns","dinstar_ddns","domain",sn)
	else
		uci:set("ddns","dinstar_ddns","domain","0000-0000-0000-0000")
	end
	uci:commit("ddns")
	-- 1、only 1g1s1o/1t1s1o module at the first time, interface info store in uci system.main.interface , product value in the license is uc200
	-- 2、after 1g1s/1s1o/1s module push out, we decide to store the interface info in product value in the license(image ver >= 2.28)
	local uci_interface=uci:get("system","main","interface")
	if not uci_interface then
		uci_interface=model:match("%-(%w+)$") or "1G1S1O"
		if uci_interface then
			uci:set("system","main","interface",uci_interface)
			uci:commit("system")
		end
	elseif model:match("%-(%w+)$") then
		local interface_tmp = model:match("%-(%w+)$")
		if string.upper(interface_tmp) ~= string.upper(uci_interface) then
			uci:set("system","main","interface",interface_tmp)
			uci:commit("system")
		end
	end

	local interface = uci_interface or ""

	license.gsm = tonumber(interface:match("([12])G"))
	license.lte = tonumber(interface:match("([12])T"))
	license.volte = tonumber(interface:match("([12])V"))
	license.fxo = tonumber(interface:match("([12])O"))
	license.fxs = tonumber(interface:match("([12])S"))

	check_pstn_status()

	if "" ~= model and firmware_ver:match("^2%.") and "" ~= interface then
		model = "UC200-"..interface
	elseif "" ~= model and firmware_ver:match("^1%.") and "" ~= interface then
		model = "AIO200-"..interface
		hostname="AIO200"
	end
	oem.brand = uci:get("oem","general","brand") or "unknown"
	oem.lang = uci:get("oem","general","lang") or "en"

	oem.model = uci:get("oem",oem.brand,"model")
	if oem.model then
		model = oem.model
	else
		oem.model = model
	end
	oem.logo = uci:get("oem",oem.brand,"logo")
	oem.hostname = uci:get("oem",oem.brand,"hostname")
	oem.timezone = uci:get("oem",oem.brand,"timezone")
	oem.zonename = uci:get("oem",oem.brand,"zonename")
	oem.firmware_ver = uci:get("oem",oem.brand,"firmware_ver")
	oem.hard_id = uci.get("oem",oem.brand,"hard_id")
	oem.default_ssid = uci:get("oem",oem.brand,"default_ssid")
	oem.company_url_en = uci:get("oem",oem.brand,"company_url_en")
	oem.company_url_cn = uci:get("oem",oem.brand,"company_url_cn")
	oem.phonenumber = uci:get("oem",oem.brand,"phonenumber")
	oem.facebook = uci:get("oem",oem.brand,"facebook")
	oem.wechat_qrcode = uci:get("oem",oem.brand,"wechat_qrcode")
	oem.wechat_name = uci:get("oem",oem.brand,"wechat_name")
	oem.copyright = uci:get("oem",oem.brand,"copyright")
	oem.display_on_about_page = uci:get("oem",oem.brand,"display_on_about_page")

	if oem.hostname then
		hostname=oem.hostname
	end

	if oem.firmware_ver then
		firmware_ver = oem.firmware_ver
	end

	if oem.hard_id then
		hard_id = oem.hard_id
	end

	local current_hostname = string.upper(uci:get("system","main","hostname") or "UC200")
	if ("AIO200" == current_hostname or "UC200" == current_hostname) and current_hostname ~= hostname then
		uci:set("system","main","hostname",hostname)
		uci:commit("system")
		os.execute("echo "..hostname.." >/proc/sys/kernel/hostname")
		if uci:get_all("network","wan") then
			uci:set("network","wan","hostname",hostname)
		else
			uci:set("network","lan","hostname",hostname)
		end
		uci:commit("network")
	end

	-- if oem.default_ssid then
	-- 	local drv_str = util.exec("lsmod | sed -n '/^rt2x00/p;/^rt2860v2_ap/p;/^rt2860v2_sta/p;'")
	-- 	drv_str = drv_str:match("(rt2860v2_ap)") or drv_str:match("(rt2860v2_sta)") or drv_str:match("(rt2x00)") or ""

	-- 	local current_ssid = uci:get("wireless","wifi0","ssid")
	-- 	if current_ssid and current_ssid:match("^domain_[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]$") then
	-- 		uci:set("wireless","wifi0","ssid",oem.default_ssid)
	-- 		uci:save("wireless")
	-- 		uci:commit("wireless")
	-- 		if drv_str ~= "rt2x00" then
	-- 			os.execute("iwpriv ra0 set SSID="..oem.default_ssid)
	-- 		end
	-- 	end
	-- end

	if oem.timezone and oem.zonename then
		local current_timezone=uci:get("system","main","timezone")
		local current_zonename=uci:get("system","main","zonename")
		if ((not current_zonename) or (not current_zonename)) or (current_timezone == "GMT0" and current_zonename == "UTC") then
			uci:set("system","main","timezone",oem.timezone)
			uci:set("system","main","zonename",oem.zonename)
			uci:commit("system")
		end
	end

	local lang = oem.lang
	if ("cn" == lang and "zh_cn" ~= uci:get("luci","main","lang")) or ("en" == lang and "en" ~= uci:get("luci","main","lang")) then
		uci:set("luci","main","lang",lang == "cn" and "zh_cn" or "en")
		uci:commit("luci")
	end

	if ("cn" == lang and "cn" ~= uci:get("callcontrol","voice","lang")) or ("en" == lang and "en" ~= uci:get("callcontrol","voice","lang")) then
		uci:set("callcontrol","voice","lang",lang)
		uci:commit("callcontrol")
	end

	local mac = util.exec("readmac") or ""
	local dsp = util.exec("readdspkey >>/dev/null 2>&1") and nixio.fs.access("/tmp/mtkauth.dat") and (26 == nixio.fs.stat("/tmp/mtkauth.dat","size"))

	if "" == license_model or "" == sn or "" == mac or not dsp then
		license.invalid = true
		license.invalid_info = {}
		if "" == license_model then
			table.insert(license.invalid_info,"Device Model")
		end
		if "" == sn then
			table.insert(license.invalid_info,"Device SN")
		end
		if "" == mac then
			table.insert(license.invalid_info,"MAC")
		end
		if not dsp then
			table.insert(license.invalid_info,"DSP Auth")
		end
	end
	if uci:get("network","wan") then
		uci:set("easycwmp","local","interface","eth0.2")
	else
		uci:set("easycwmp","local","interface","br-lan")
	end
	acs_username = uci:get("easycwmp","acs","username")
	if not acs_username or "" == acs_username then
		uci:set("easycwmp","acs","username",sn)
	end
	uci:set("easycwmp","device","manufacturer",uci:get("oem",oem.brand,"manufacturer") or oem.brand or "oem.brand")
	uci:set("easycwmp","device","oui",uci:get("oem",oem.brand,"manufacturer_oui") or "FFFFFF")
	uci:set("easycwmp","device","product_class",uci:get("oem",oem.brand,"product_class") or "uc200")
	uci:set("easycwmp","device","description",uci:get("oem",oem.brand,"description") or "")
	uci:set("easycwmp","device","model",model)
	uci:set("easycwmp","device","serial_number",sn)
	uci:set("easycwmp","device","hardware_version","1")
	uci:set("easycwmp","device","software_version",firmware_ver)
	uci:commit("easycwmp")

	default_password = uci:get("oem",oem.brand,"default_password") or "admin"

	if "admin" ~= default_password and luci.sys.user.checkpasswd("admin","admin") then
		luci.sys.user.setpasswd("admin", default_password)
	end
	os.execute("echo 600 > /proc/sys/net/netfilter/nf_conntrack_expect_max") --网上问题 #6618,先临时在这里把SIP ALG跟踪数上限调大，原来默认是60
	os.execute("sleep 1")
	dpr.unloaddpr()
	package.loaded['dpr'] = nil
end
