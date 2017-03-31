
local fs = require "nixio.fs"
local cron_public = ""
local cron_optional = ""

cron_public = cron_public.."*/3 * * * * /usr/bin/cron_system.sh\n"
cron_public = cron_public.."01  * * * * touch /etc/systimeupdate\n"
cron_public = cron_public.."*/1 * * * * /etc/ipsec_check_status.sh &\n"
cron_public = cron_public.."*/1 * * * * /etc/openvpn/client_check_process.sh &\n"
cron_public = cron_public.."*/1 * * * * /usr/bin/pppd_d_check.sh\n"
cron_public = cron_public.."*/1 * * * * /usr/bin/cron_app.sh\n"

cron_optional = cron_optional.."*/1 * * * * /usr/bin/netmount.sh &\n"

fs.writefile("/tmp/root",cron_public..cron_optional)
