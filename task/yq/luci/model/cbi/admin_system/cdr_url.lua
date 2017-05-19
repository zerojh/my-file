local uci = require "luci.model.uci".cursor()
local lang = uci:get("oem","general","lang") or "en"
local str = ""

if lang == "cn" then
	str = "话单上传地址"
else
	str = "CDR Upload URL"
end

m = Map("oem", translate("System / LED"))

s = m:section(NamedSection,"dinstar","brand",translate(""))
s.addremove = false
s.anonymous = true

url = s:option(Value, "cdr_url", str)
url.datatype="url"
return m
