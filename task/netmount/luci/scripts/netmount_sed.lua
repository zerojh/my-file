
local uci = require "luci.model.uci".cursor()
local netmount_script = "/usr/lib/lua/luci/scripts/netmount.sh"

local action = uci:get("cron", "netmount", "disabled") == "0" and "on" or "off"
local server = uci:get("cron", "netmount", "server") or ""
local folder = uci:get("cron", "netmount", "folder") or ""
local username = uci:get("cron", "netmount", "username") or ""
local password = uci:get("cron", "netmount", "password") or ""

local cmd_str = ""
cmd_str=cmd_str.."sed -i 's/^global_action=.*/global_action=\""..action.."\"/g' "..netmount_script..";"
cmd_str=cmd_str.."sed -i 's/^global_server=.*/global_server=\""..server.."\"/g' "..netmount_script..";"
cmd_str=cmd_str.."sed -i 's/^global_folder=.*/global_folder=\""..folder.."\"/g' "..netmount_script..";"
cmd_str=cmd_str.."sed -i 's/^global_username=.*/global_username=\""..username.."\"/g' "..netmount_script..";"
cmd_str=cmd_str.."sed -i 's/^global_password=.*/global_password=\""..password.."\"/g' "..netmount_script..";"
os.execute(cmd_str)
