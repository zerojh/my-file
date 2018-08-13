module ("luci.scripts.custom_cmd", package.seeall)

set = {}
cmd_set.remove = {}
local test_set = cmd_set.test

test_set.test1 = function(...)
	print("test1", table.concat(..., ","))
	return true, "+OK."
end

test_set.test2 = function(...)
	print("test2", table.concat(..., ","))
	return true, "+OK."
end

function analyze_cmd(cmd)
	local cmd = cmd or ""
	local tb = {}
	local func = nil
	local argv = {}

	cmd = string.gsub(cmd, "%s+", " ")
	tb = util.split(cmd, " ") or {}

	func = type(cmd_set) == "table" and cmd_set or {}
	for k,v in ipairs(tb) do
		if type(func) ~= "function" then
			func = func[v]
			if not func or (type(func) ~= "table" and type(func) ~= "function") then
				break
			end
		else
			table.insert(argv, v)
		end
	end

	if type(func) ~= "function" then
		return nil, nil
	else
		return func, argv
	end
end

function execute_cmd(cmd)
	local f, argv

	if not cmd then
		return false, "-ERR No Command!"
	end

	f, argv = analyze_cmd(cmd)
	if f and argv then
		return f(argv)
	else
		return false, "-ERR "..cmd.." command not found!"
	end
end

function execute_custom_cmd(cmd_set, cmd)
	local util = require "luci.util"
	local str
	local tb = {}
	local func
	local argv = {}

	if not cmd_set or not cmd then
		return false, "-ERR No Command!"
	end

	str = string.gsub(cmd, "%s+", " ")
	tb = util.split(cmd, " ") or {}

	func = type(cmd_set) == "table" and cmd_set or {}
	for k,v in ipairs(tb) do
		if type(func) ~= "function" then
			func = func[v]
			if not func or (type(func) ~= "table" and type(func) ~= "function") then
				break
			end
		else
			table.insert(argv, v)
		end
	end

	if type(func) ~= "function" then
		return false, "-ERR \""..cmd.."\" command not found!"
	else
		return func(argv)
	end
end
