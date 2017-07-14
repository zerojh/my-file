local ccmd_exe = require "luci.scripts.custom_cmd".execute_cmd

local cmd = "test test1 1 2 3 4 5"
local ret, info = ccmd_exe(cmd)
print("["..cmd.."]", ":", ret, info)

cmd = "remove j42 imei"
ret, info = ccmd_exe(cmd)
print("["..cmd.."]", ":", ret, info)

cmd = " remove j42  imei "
ret, info = ccmd_exe(cmd)
print("["..cmd.."]", ":", ret, info)
