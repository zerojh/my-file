local uci = require "luci.model.uci".cursor()
local lang = uci:get("luci","main","lang") or "en"

uci:check_cfg("upload_cdr")
if not uci:get("upload_cdr","cdr") then
	uci:section("upload_cdr","cdr","cdr")
	uci:commit("upload_cdr")
end

local title_str = ""
local url_str = ""

if lang == "zh_cn" then
	title_str = "系统 / 上传话单"
	url_str = "话单上传地址"
else
	title_str = "System / CDR Upload"
	url_str = "CDR Upload URL"
end

m = Map("upload_cdr", title_str)

s = m:section(NamedSection,"cdr","cdr",translate(""))
s.addremove = false
s.anonymous = true

enable = s:option(ListValue,"status",translate("Status"))
enable.rmempty = false
enable:value("1",translate("Enable"))
enable:value("0",translate("Disable"))

url = s:option(Value, "url", url_str)
url.datatype="url"
return m
