function ctl_xml()
	require "ESL"
	local fs  = require "luci.fs"
	local util = require "luci.util"
	local uci = require "luci.model.uci".cursor()
	local exe = require "os".execute

	local action = luci.http.formvalue("action")
	local file = luci.http.formvalue("file_name")
	local content = luci.http.formvalue("content")
	local con
	local info = {}
	local file_list = {
		["c300_dsp"]=""
	}
	local file_name_list = {
		"'c300_dsp'"
	}

	local abs_path = ""
	local bak_path = ""

	action = action or ""

	if not fs.access("/etc/fs_bak") then
		fs.mkdir("/etc/fs_bak",true)
	end

	if file then
		if file == "" then
			abs_path = "unknown_file"
			bak_path = "unknown_file"
		else
			abs_path = "/etc/freeswitch/conf/autoload_configs/"..file..".conf.xml"
			bak_path = "/etc/fs_bak/"..file..".conf.xml"
		end
		info["action"] = action
		if not file_list[file] or not fs.access(abs_path) then
			luci.http.prepare_content("application/json")
			luci.http.write_json({ret="false", info="No file!"})
			return
		elseif action ~= "read" and action ~= "write" and action ~= "restore" then
			luci.http.prepare_content("application/json")
			luci.http.write_json({ret="false", info="Unknown action!"})
			return
		elseif action == "write" and (not content or content == "")then
			luci.http.prepare_content("application/json")
			luci.http.write_json({ret="false", info="No acceptable content"})
			return
		end

		info["ret"] = "true"
		if action == "read" then
			-- read
			info["info"] = fs.readfile(abs_path) or ""
		elseif action == "write" then
			if not fs.access(bak_path) then
				exe("cp "..abs_path.." "..bak_path)
			end
			fs.writefile(abs_path,content)

			con = ESL.ESLconnection("127.0.0.1","8021","ClueCon")
			if 1 == con:connected() then
				con:api("reloadxml")
				con:disconnect()
				info["info"] = "Success!"
			else
				info["info"] = "Failed!"
			end
			-- write
		else
			if fs.access(bak_path) then
				exe("cp "..bak_path.." "..abs_path)
			end
			info["info"] = fs.readfile(abs_path) or ""
			-- restore
		end

		luci.http.prepare_content("application/json")
		luci.http.write_json(info)
	else
		luci.template.render("admin_system/ctl_xml", {
			file_name_list = file_name_list,
		})
	end
end
