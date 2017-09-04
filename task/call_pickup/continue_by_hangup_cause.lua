local param = argv[1]

--@ continue actions after bridge by hangup_cause
if session:ready() == true then
	local hangup_cause = session:getVariable("last_bridge_hangup_cause")

	freeswitch.consoleLog("debug",session:getVariable("chan_name").." end, Hangup Cause:"..(hangup_cause or "nil"))

	local prev_extension_number = session:getVariable("prev_extension_number")
	if prev_extension_number and prev_extension_number ~= "" then
		session:execute("hash","delete/callgroup/U-"..prev_extension_number)
	end

	if hangup_cause == "NORMAL_CLEARING" or hangup_cause == "SUCCESS" then
		session:hangup("NORMAL_CLEARING")
	else
		if param == "IVR" then
			session:execute("transfer","IVRServiceContinue$ XML IVR")
		elseif param == "Extension" then
			session:execute("transfer","ExtensionServiceContinue XML extension-service")
		end
	end
end
