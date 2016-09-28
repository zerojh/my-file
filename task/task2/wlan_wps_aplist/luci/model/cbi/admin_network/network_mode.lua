local fs = require "nixio.fs"
local ut = require "luci.util"
local uci = require "luci.model.uci".cursor()
local fs_server = require "luci.scripts.fs_server"

m = Map("network",translate(""), translate(""))

--@ first
s = m:section(NamedSection,"globals","globals")

network_mode = s:option(ListValue,"network_mode",translate("Network Model"))
network_mode.rmempty = false
network_mode:value("route",translate("Route"))
network_mode:value("bridge",translate("Bridge"))
network_mode:value("client",translate("Client"))

return m
