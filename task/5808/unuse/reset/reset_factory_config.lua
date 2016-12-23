--@ reset factory config for feature code
local api = freeswitch:API()

if session:ready() then
	os.execute("lua /usr/lib/lua/luci/scripts/reset_default_config.lua profile,endpoint,call");
	api.executeString("reloadxml")
	session:execute("palyback","/etc/freeswitch/sounds/music/8000/setting success");--need sound
	return;
end
