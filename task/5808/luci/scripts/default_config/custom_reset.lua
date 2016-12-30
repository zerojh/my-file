local uci = require "luci.model.uci".cursor()
local exe = require "os".execute

exe("rm /etc/config/vpnselect -rf")

uci:set_list("lucid","http","address",{"80","8345","8848"})
uci:save("lucid")
uci:commit("lucid")

uci:set("firewall","defaults","enabled_8345","1")
uci:set("firewall","defaults","enabled_8848","0")
uci:section("firewall","redirect","redirecta",{name="Allow-8345",src="wan",src_dport="8345",dest_port="8345",enabled="1"})
uci:section("firewall","rule","rulea",{name="Allow-8345",src="wan",dest_port="8345",target="ACCEPT",enabled="1"})
uci:section("firewall","redirect","redirectb",{name="Allow-8848",src="wan",src_dport="8848",dest_port="8345",enabled="1"})
uci:section("firewall","rule","ruleb",{name="Allow-8848",src="wan",dest_port="8848",target="REJECT",enabled="1"})
uci:save("firewall")
uci:commit("firewall")

