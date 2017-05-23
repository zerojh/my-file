
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
wifiver = ""
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

if nixio.fs.access("/proc/wifiversion") then
	io.input("/proc/wifiversion")
	wifiver = io.read("*all")
end

--io.input("/proc/imageversion")
--imagever = io.read("*all")

io.input("/proc/bootversion")
bootver = io.read("*all")
if "0\n" == bootver then
	bootver = imageinfo and (imageinfo:match("mngt_sec%[0%]%.version:([0-9%.]+)") or "0") or "0.0"
end
if "0\n" == rootver then
	rootver = imageinfo and (imageinfo:match("mngt_sec%[2%]%.version:([0-9%.]+)") or "0") or "0.0"
end
if "0\n" == wifiver then
	wifiver = imageinfo and (imageinfo:match("mngt_sec%[1%]%.version:([0-9%.]+)") or "0") or "0.0"
end

if ini then
	firmware_ver =	ini['firmware']['version'] .. " " .. (ini["firmware"]["build"] or "")
else
	firmware_ver = ""
end

function device_info_init()
	local dpr = require "dpr"
	local uci = luci.model.uci.cursor()
	local util = require "luci.util"
	local license_model=""
	local hostname="UBG1000"

	model	=	string.upper(dpr.getproduct() or "")
	license_model = model
	sn    	= 	string.upper(dpr.getdevicesn() or "")
	hard_id	=	string.upper(nixio.fs.access("/bin/readflashid") and util.exec("readflashid") or (dpr.gethardwareid() or ""))
	mac 	=	string.gsub(string.upper(util.exec("readmac") or ""),":","-")
	if sn ~= "" and string.len(sn) == 19 and sn:match("^[0-9A-Fa-f%-]*$") then
		uci:set("system","main","sn",sn)
		uci:set("ddns","dinstar_ddns","domain",sn)
	else
		uci:set("system","main","sn",sn)
		uci:set("ddns","dinstar_ddns","domain","0000-0000-0000-0000")
	end
	uci:commit("system")
	uci:commit("ddns")

	if util.exec("cat /proc/fxo_check 2>/dev/null"):match("1") then --check fxo license
		fxo = true
	end
	
	local interface = uci:get("system","main","interface") or ""
	if "" ~= model and firmware_ver:match("^2%.") and "" ~= interface then
		model = "UBG1000-"..interface
	elseif "" ~= model and firmware_ver:match("^1%.") and "" ~= interface then
		model = "AIO1000-"..interface
		hostname="AIO1000"
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

	local current_hostname = string.upper(uci:get("system","main","hostname") or "UBG1000")
	if ("AIO1000" == current_hostname or "UBG1000" == current_hostname) and current_hostname ~= hostname then
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

	default_password = uci:get("oem",oem.brand,"default_password") or "admin"
	if "admin" ~= default_password and luci.sys.user.checkpasswd("admin","admin") then
		luci.sys.user.setpasswd("admin", default_password)
	end
	os.execute("sleep 1")
	dpr.unloaddpr()
	package.loaded['dpr'] = nil
end
