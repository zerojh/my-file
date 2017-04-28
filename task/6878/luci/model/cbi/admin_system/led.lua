m = Map("oem", translate("System / LED"))

s = m:section(NamedSection,"bluewave","brand",translate(""))
s.addremove = false
s.anonymous = true

url = s:option(Value, "lte_url", translate("URL"))
url.datatype="url"
return m