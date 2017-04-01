
local uci = require "luci.model.uci".cursor()
local netmount_script = "/usr/lib/lua/luci/scripts/netmount.sh"

local action = uci:get("cron", "netmount", "disabled") == "0" and "on" or "off"
local server = uci:get("cron", "netmount", "server") or ""
local folder = uci:get("cron", "netmount", "folder") or ""
local username = uci:get("cron", "netmount", "username") or ""
local password = uci:get("cron", "netmount", "password") or ""

local cmd_str = ""
cmd_str=cmd_str.."sed -i 's/^sed_global_action=.*/sed_global_action=\""..action.."\"/g' "..netmount_script..";"
cmd_str=cmd_str.."sed -i 's/^sed_global_server=.*/sed_global_server=\""..server.."\"/g' "..netmount_script..";"
cmd_str=cmd_str.."sed -i 's/^sed_global_folder=.*/sed_global_folder=\""..folder.."\"/g' "..netmount_script..";"
cmd_str=cmd_str.."sed -i 's/^sed_global_username=.*/sed_global_username=\""..username.."\"/g' "..netmount_script..";"
cmd_str=cmd_str.."sed -i 's/^sed_global_password=.*/sed_global_password=\""..password.."\"/g' "..netmount_script..";"
cmd_str=cmd_str.."cp "..netmount_script.." /usr/bin/ ;"
os.execute(cmd_str)
