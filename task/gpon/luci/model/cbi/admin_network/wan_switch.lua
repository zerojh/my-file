
m = Map("network",translate(""),translate(""))

s = m:section(NamedSection,"wan","interface")

wan_switch = s:option(ListValue, "wan_switch", translate("WAN/GPON Switch"))
wan_switch.default = "off"
wan_switch.rmempty = false
wan_switch:value("on", "GPON")
wan_switch:value("off", translate("WAN"))

return m
