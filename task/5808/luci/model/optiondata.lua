local uci = require "luci.model.uci".cursor()
local util = require "luci.util"
local translate = require "luci.i18n".translate
local translatef = require "luci.i18n".translatef

module ("luci.model.optiondata", package.seeall)

local config_file = {
	["callcontrol"] = "Call Control",
	["cloud"] = "Cloud Server",
	["ddns"] = "DDNS",
	["dhcp"] = "DHCP Server",
	["dropbear"] = "SSH",
	["easycwmp"] = "TR069",
	["endpoint_mobile"] = "GSM Trunk",
	["endpoint_ringgroup"] = "Ring Group",
	["endpoint_routegroup"] = "Route Group",
	["endpoint_sipphone"] = "SIP Extension",
	["endpoint_siptrunk"] = "SIP Trunk",
	["fax"] = "FAX",
	["feature_code"] = "Feature Code",
	["firewall"] = "Firewall",
	["ivr"] = "IVR",
	["luci"] = "System",
	["lucid"] = "Web",
	["mwan3"] = "Uplink Config",
	["network"] = "Network",
	["profile_codec"] = "Codec Profile",
	["profile_dialplan"] = "Dialplan",
	["profile_manipl"] = "Manipulation Profile",
	["profile_number"] = "Number Profile",
	["profile_numberlearning"] = "SIM Number Learning Profile",
	["profile_sip"] = "SIP Profile",
	["profile_time"] = "Time Profile",
	["provision"] = "Provision",
	["route"] = "Route",
	["system"] = "System",
	["telnet"] = "Telnet",
	["openvpn"] = "OpenVPN Client",
	["pptpc"] = "PPTP Client",
	["xl2tpd"] = "L2TP Client",
	["wireless"] = "WIFI",
	["network_tmp"] = "Network",
	["profile_smsroute"] = "SMS Route",
	["static_route"] = "Static Route",
	["upnpc"] = "UPnP Client",
}
local config = {
	["profile_sip"] = {
		["index"]="Index",
		["name"]="Name",
		["localinterface"]="Local Listening Interface",
		["__localinterface_value"]={
			["wan2"]="LTE",
		},
		["localport"]="Local Listening Port",
		["ext_sip_ip"]="NAT",
		["__ext_sip_ip_value"]={
			["auto-nat"]="uPNP / NAT-PMP",
			},
		["prack"]="PRACK",
		["ext_sip_ip_more"]="NAT Address",
		["dtmf"]="DTMF Type",
		["__dtmf_value"]={
			["info"]="SIP INFO",
			["rfc2833"]="RFC2833",
			["inband"]="Inband",
		},
		["rfc2833_pt"]="RFC2833-PT",
		["session_timer"]="Session Timer",
		["session_timeout"]="Session Timeout(s)",
		["inbound_codec_negotiation"]="Inbound Codec Negotiation Priority",
		["__inbound_codec_negotiation_value"] = {
			["generous"]="Remote",
			["greedy"]="Local",
			["scrooge"]="Local Force",
			},
		["inbound_codec_prefs"]="Inbound Codec Profile",
		["outbound_codec_prefs"]="Outbound Codec Profile",
		["heartbeat"]="Detect Extension is Online",
		["ping"]="Detect Period(s)",
		["info"]="SIP INFO",
		["allow_unknown_call"]="Allow Unknown Call",
		["auth_acl"]="Inbound Source Filter",
		["qos"]="QoS",
		["dscp_sip"]="SIP Message DSCP Value",
		["__dscp_sip_value"]={
			["0"]="CS0 / 0",
			["8"]="CS1 / 8",
			["10"]="AF11 / 10",
			["12"]="AF12 / 12",
			["14"]="AF13 / 14",
			["16"]="CS2 / 16",
			["18"]="AF21 / 18",
			["20"]="AF22 / 20",
			["22"]="AF23 / 22",
			["24"]="CS3 / 24",
			["26"]="AF31 / 26",
			["28"]="AF32 / 28",
			["30"]="AF33 / 30",
			["32"]="CS4 / 32",
			["34"]="AF41 / 34",
			["36"]="AF42 / 36",
			["38"]="AF43 / 38",
			["40"]="CS5 / 40",
			["46"]="EF / 46",
			["48"]="CS6 / 48",
			["56"]="CS7 / 56",
		},
		["dscp_rtp"]="RTP DSCP Value",
		["__dscp_rtp_value"]={
			["0"]="CS0 / 0",
			["8"]="CS1 / 8",
			["10"]="AF11 / 10",
			["12"]="AF12 / 12",
			["14"]="AF13 / 14",
			["16"]="CS2 / 16",
			["18"]="AF21 / 18",
			["20"]="AF22 / 20",
			["22"]="AF23 / 22",
			["24"]="CS3 / 24",
			["26"]="AF31 / 26",
			["28"]="AF32 / 28",
			["30"]="AF33 / 30",
			["32"]="CS4 / 32",
			["34"]="AF41 / 34",
			["36"]="AF42 / 36",
			["38"]="AF43 / 38",
			["40"]="CS5 / 40",
			["46"]="EF / 46",
			["48"]="CS6 / 48",
			["56"]="CS7 / 56",
		},
	},
	["profile_fxso"] = {
		["index"]="Index",
		["name"]="Name",
		["tonegrp"]="Tone Group",
		["__tonegrp_value"] = {
			["0"]="USA",
			["1"]="Austria",
			["2"]="Belgium",
			["3"]="Finland",
			["4"]="France",
			["5"]="Germany",
			["6"]="Greece",
			["7"]="Italy",
			["8"]="Japan",
			["9"]="Norway",
			["10"]="Spain",
			["11"]="Sweden",
			["12"]="UK",
			["13"]="Australia",
			["14"]="China",
			["15"]="Hongkong",
			["16"]="Denmark",
			["17"]="Russia",
			["18"]="Poland",
			["19"]="Portugal",
			["20"]="Turkey",
			["21"]="Dutch",
			["ph"]="Philippines",
		},
		["digit"]="Digit Timeout(s)",
		["dialTimeout"]="Dial Timeout(s)",
		["ringtimeout"]="Ring Timeout(s)",
		["noanswer"]="No Answer Timeout(s)",
		["flash_min_time"]="Flash Detection Min Time (ms)",
		["flash_max_time"]="Flash Detection Max Time (ms)",
		["dtmf_sendinterval"]="DTMF Send Interval(ms)",
		["dtmf_duration"]="DTMF Duration(ms)",
		["dtmf_detect_threshold"]="DTMF Detect Threshold",
		["dtmf_end_char"]="DTMF Terminator",
		["__dtmf_end_char_value"]={
			["none"]="None",
		},
		["send_dtmf_end_char"]="Send DTMF Terminator",
		["cid_send_mode"]="CID Send Mode",
		["dtmf_gain"]="DTMF Gain",
		["__cid_send_mode_value"]={
			["FSK"]="FSK-BEL202",
			["FSK-V23"]="FSK-V.23",
		},
		["message_mode"]="Message Mode",
		["message_format"]="Message Format",
		["__message_format_value"]={
			["0"]="Display Name and CID",
			["1"]="Only CID",
			["2"]="Only Display Name",
		},
		["send_cid_before"]="CID Send Timing",
		["__send_cid_before_value"] = 
		{
			["0"]="Send After RING",
			["1"]="Send Before RING",
		},
		["send_cid_delay"]="Delay Timeout After Ring(ms)",
		["slic"]="Impedance",
		["__slic_value"] = {
			["0"]="600 Ohm",
			["1"]="900 Ohm",
			["2"]="600 Ohm + 1uF",
			["3"]="900 Ohm + 2.16uF",
			["4"]="270 Ohm + (750 Ohm || 150nF)",
			["5"]="220 Ohm + (820 Ohm || 120 nF)",
			["6"]="220 Ohm + (820 Ohm || 115 nF)",
			["7"]="220 Ohm + (680 Ohm || 100 nF)",
			},
		["polarity_reverse"]="Send Polarity Reverse",
		["flashhook_dtmf"]="Send Flash Hook via SIP INFO",
		["__flashhook_dtmf_value"]={
			["0"]="Off",
			["A"]="A(12)",
			["B"]="B(13)",
			["C"]="C(14)",
			["D"]="D(15)",
			["F"]="F(16)",
		},
		["dialRegex"]="Dialplan",
		["dtmf_detectcid_timeout"]="DTMF Detect Timeout(ms)",
		["delay_offhook"]="Delay Offhook(s)",
		["detectcid_opt"]="Detect Caller ID",
		["__detectcid_opt_value"] = {
			["0"]="Off",
			["1"]="Detect before ring",
			["2"]="Detect after ring",
		},
		["busy_ratio"]="BusyTone Detect Intermittent Ratio",
        ["busytone_count"]="Detect Tone counts",
        ["busytone_detect_busy_delta"]="Detect Tone Delta(ms)",
		["__busy_ratio_value"] = {
			["0"]="1:1",
			["1"]="Custom",
		},
		["busy_tone_on"]="Tone 1 On Time(ms)",
		["busy_tone_off"]="Tone 1 Off Time(ms)",
        ["busy_tone_on_1"]="Tone 2 On Time(ms)",
		["busy_tone_off_1"]="Tone 2 Off Time(ms)"
	},
	["profile_codec"] = {
		["index"]="Index",
		["name"]="Name",
		["code"]="Codec",
	},
	["profile_number"] = {
		["index"]="Index",
		["name"]="Name",
		["caller"]="Caller Number Prefix",
		["callerlength"]="Caller Number Length",
		["called"]="Called Number Prefix",
		["calledlength"]="Called Number Length",
	},
	["profile_numberlearning"] = {
		["index"]="Index",
		["name"]="Name",
		["type"]="Type",
		["__type_value"] = {
			["sms"]="SMS",
			["call"]="Dial Number",
			["ussd"]="USSD",
		},
		["dest_number"]="Destination Number",
		["from_number"]="Check SMS From Number",
		["send_text"]="Send Text",
		["keywords"]="Keywords",
	},
	["profile_manipl"] = {
		["index"]="Index",
		["name"]="Name",
		["caller"]="Caller",
		["__caller_value"] = {
			["0"]="Off",
			["1"]="On",
		},
		["CallerDelPrefix"]="Delete Caller Prefix Count",
		["CallerDelSuffix"]="Delete Caller Suffix Count",
		["CallerAddPrefix"]="Add Caller Prefix",
		["CallerAddSuffix"]="Add Caller Suffix",
		["CallerReplace"]="Replace Caller by",
		["called"]="Called",
		["__called_value"]={
			["0"]="Off",
			["1"]="On",
		},
		["CalledDelPrefix"]="Delete Called Prefix Count",
		["CalledDelSuffix"]="Delete Called Suffix Count",
		["CalledAddPrefix"]="Add Called Prefix",
		["CalledAddSuffix"]="Add Called Suffix",
		["CalledReplace"]="Replace Called by",
	},
	["profile_time"] = {
		["index"]="Index",
		["name"]="Name",
		["date_options"]="Date Period",
		["weekday"]="Weekday",
		["time_options"]="Time Period",
	},
	["profile_dialplan"] = {
		["index"]="Index",
		["name"]="Name",
		["format"]="Format",
		["__format_value"]={
			["regex"]="Regex",
			["digitmap"]="DigitMap",
		},
		["dialregex"]="Dialplan",
		["digitmap"]="Dialplan",
	},
	["profile_smsroute"] = {
		["index"]="Priority",
		["name"]="Name",
		["from"]="Source",
		["__from_value"]={
			["0"]="All SIP Extension / Trunk",
		},
		["src_number"]="Src Number Prefix",
		["caller"]="Src Number",
		["keywords"]="Content Has the Words",
		["action"]="Action",
		["__action_value"]={
			["forward"]="Forward",
			["reply"]="Reply",
		},
		["pre_reply_list"]="Reply",
		["__pre_reply_list_value"]={
			["custom"]="Custom",
			["phonenumber"]=translatef("Your Phone Number is %s","${from_user}"),
		},
		["reply_content"]="Reply Content",
		["dest"]="Destination",
		["__dest_value"]={
			["0"]="Local SIP Extension",
		},
		["dest_number_src"]="Dest Number Src",
		["__dest_number_src_value"]={
			["custom"]="Custom",
			["to"]="Get from To Header Field",
			["content"]="Get from Content",
		},
		["dest_number_separator"]="Separator between Dest Number and Content",
		["dst_number"]="Dest Number",
		["prefix"]="Add Prefix in Content",
		["__prefix_value"]={
			["from"]=translatef("From %s : ","${from_user}"),
			["none"]="NONE",
			["custom"]="Custom",
			},
		["custom_prefix"]="Custom Prefix",
		["suffix"]="Add Suffix in Content",
		["__suffix_value"]={
			["from"]=translatef(" -- Send by %s","${from_user}"),
			["none"]="NONE",
			["custom"]="Custom",
			},
		["custom_suffix"]="Custom Suffix",
	},
	
	["endpoint_siptrunk"] = {
		["index"]="Index",
		["name"]="Name",
		["ipv4"]="Address",
		["port"]="Port",
		["outboundproxy"]="Outbound Proxy",
		["outboundproxy_port"]="Outbound Proxy Port",
		["transport"]="Transport",
		["register"]="Register",
		["username"]="Username",
		["auth_username"]="Auth Username",
		["password"]="Password",
		["from_username"]="From Header Username",
		["__from_username_value"]={
			["username"]="Username",
			["caller"]="Caller",
		},
		["reg_url_with_transport"]="Specify Transport Protocol on Register URL",
		["expire_seconds"]="Expire Seconds",
		["retry_seconds"]="Retry Seconds",
		["heartbeat"]="Heartbeat",
		["ping"]="Heartbeat Period(s)",
		["profile"]="SIP Profile",
		["status"]="Status",
	},
	["endpoint_sipphone"] = {
		["index"]="Index",
		["name"]="Name",
		["user"]="Extension",
		["password"]="Password",
		["did"]="DID",
		["from"]="Register Source",
		["__from_value"]={
			["any"]="Any",
			["specified"]="Specified",
		},
		["ip"]="IP Address",
		["nat"]="NAT",
		["waiting"]="Call Waiting",
		["notdisturb"]="Do Not Disturb",
		["forward_uncondition"]="Call Forward Unconditional",
		["forward_uncondition_dst"]="Call Forward Unconditional Dest Number",
		["forward_unregister"]="Call Forward Unregister",
		["forward_unregister_dst"]="Call Forward Unregister Dest Number",
		["forward_busy"]="Call Forward Busy",
		["forward_busy_dst"]="Call Forward Busy Dest Number",
		["forward_noreply"]="Call Forward No Reply",
		["forward_noreply_dst"]="Call Forward No Reply Dest Number",
		["forward_noreply_timeout"]="Call Forward No Reply Timeout(s)",
		["profile"]="SIP Profile",
		["status"]="Status",
	},
	["endpoint_mobile"] = {
		["index"]="Index",
		["name"]="Name",
		["number"]="Extension",
		["autodial"]="Autodial Number",
		["did"]="DID",
		["port_reg"]="Register to SIP Server",
		["port_server_1"]="Master Server",
		["port_server_2"]="Slave Server",
		["username"]="Username",
		["authuser"]="Auth Username",
		["port_password"]="Password",
		["sip_from_field"]="Display Name / Username Format",
		["__sip_from_field_value"]={
			["0"]="Caller ID / Caller ID",
			["1"]="Display Name / Caller ID",
			["2"]="Extension / Caller ID",
			["3"]="Caller ID / Extension",
			["4"]="Anonymous",
		},
		["sip_from_field_un"]="Display Name / Username Format when CID unavailable",
		["__sip_from_field_un_value"]={
			["0"]="Display Name / Extension",
			["1"]="Anonymous",
		},
		["gsmspeedtype"]="GSM Codec",
		["__gsmspeedtype_value"]={
			["0"]="Auto",
			["1"]="FR",
			["2"]="HR",
			["3"]="EFR",
			["4"]="AMR_FR",
			["5"]="AMR_HR",
			["6"]="FR & EFR",
			["7"]="EFR & FR",
			["8"]="EFR & HR",
			["9"]="EFR & ARM_FR",
			["10"]="AMR_FR & FR",
			["11"]="AMR_FR & HR",
			["12"]="AMR_FR & EFR",
			["13"]="AMR_HR & FR",
			["14"]="AMR_HR & HR",
			["15"]="AMR_HR & EFR",
		},
		["bandtype"]="Band Type",
		["__bandtype_value"]={
			["0"]="All",
			["1"]="GSM 900",
			["2"]="GSM 1800",
			["3"]="GSM 1900",
			["4"]="GSM 900 & GSM 1800",
			["5"]="GSM 850 & GSM 1900",
		},
		["carrier"]="Carrier",
		["__carrier_value"]={
			["auto"]="Auto",
		},
		["lte_mode"]="Mode",
		["__lte_mode_value"]={
			["auto"]="AUTO",
			["4g"]="4G",
			["3g"]="3G",
			["gsm"]="GSM",
		},
        ["hide_callernumber"]="CLIR",
        ["__hide_callernumber_value"]={     
                ["0"]="Auto",         
                ["1"]="On",     
                ["2"]="Off",      
        },
		["reg_fail_reactive"]="Reactive when register fail",
		["at_sms_encoding"]="SMS Encoding",
		["at_smsc_number"]="SMS Center Number",
		["pincode"]="PIN Code",
		["dsp_input_gain"]="Input Gain",
		["dsp_output_gain"]="Output Gain",
		["numberlearning_profile"]="SIM Number Learning Profile",
		["status"]="Status",
	},
	["endpoint_ringgroup"] = {
		["index"]="Index",
		["name"]="Name",
		["number"]="Ring Group Number",
		["members_select"]="Members Select",
		["strategy"]="Strategy",
		["ringtime"]="Ring Time(5s~60s)",
		["did"]="DID",
	},
	["endpoint_routegroup"] = {
		["index"]="Index",
		["name"]="Name",
		["members_select"]="Members Select",
		["strategy"]="Strategy",
	},
	["endpoint_fxso"] = {
		["index"]="Index",
		["name"]="Name",
		["number_1"]="Extension",
		["autodial_1"]="Autodial Number",
		["did_1"]="DID",
		["hotline_1"]="Hot Line",
		["hotline_1_number"]="Hot Line Number",
		["hotline_1_time"]="Hot Line Delay",
		["__hotline_1_time_value"]={
			["10"]="Immediately",
			["1000"]="1 s",
			["2000"]="2 s",
			["3000"]="3 s",
			["4000"]="4 s",
			["5000"]="5 s",
		},
		["port_1_reg"]="Register to SIP Server",
		["port_1_server_1"]="Master Server",
		["port_1_server_2"]="Slave Server",
		["username_1"]="Username",
		["authuser_1"]="Auth Username",
		["port_1_password"]="Password",
		["from_username_1"]="From Header Username",
		["__from_username_1_value"]={
			["username"]="Username",
			["caller"]="Caller",
		},
		["reg_url_with_transport_1"]="Specify Transport Protocol on Register URL",
		["expire_seconds_1"]="Expire Seconds",
		["retry_seconds_1"]="Retry Seconds",
		["waiting_1"]="Call Waiting",
		["notdisturb_1"]="Do Not Disturb",
		["forward_uncondition_1"]="Call Forward Unconditional",
		["forward_uncondition_dst_1"]="Call Forward Unconditional Dest Number",
		["forward_busy_1"]="Call Forward Busy",
		["forward_busy_dst_1"]="Call Forward Busy Dest Number",
		["forward_noreply_1"]="Call Forward No Reply",
		["forward_noreply_dst_1"]="Call Forward No Reply Dest Number",
		["forward_noreply_timeout_1"]="Call Forward No Reply Timeout(s)",
		["dsp_input_gain_1"]="Input Gain",
		["dsp_output_gain_1"]="Output Gain",
		["number_2"]="Extension",
		["autodial_2"]="Autodial Number",
		["did_2"]="DID",
		["hotline_2"]="Hot Line",
		["hotline_2_number"]="Hot Line Number",
		["hotline_2_time"]="Hot Line Delay",
		["__hotline_2_time_value"]={
			["10"]="Immediately",
			["1000"]="1 s",
			["2000"]="2 s",
			["3000"]="3 s",
			["4000"]="4 s",
			["5000"]="5 s",
		},
		["port_2_reg"]="Register to SIP Server",
		["port_2_server_1"]="Master Server",
		["port_2_server_2"]="Slave Server",
		["work_mode_2"]="Work Mode",
		["__work_mode_2_value"]={
			["0"]="Voice",
			["1"]="POS",
		},
		["username_2"]="Username",
		["authuser_2"]="Auth Username",
		["port_2_password"]="Password",
		["from_username_2"]="From Header Username",
		["__from_username_2_value"]={
			["username"]="Username",
			["caller"]="Caller",
		},
		["reg_url_with_transport_2"]="Specify Transport Protocol on Register URL",
		["expire_seconds_2"]="Expire Seconds",
		["retry_seconds_2"]="Retry Seconds",
		["waiting_2"]="Call Waiting",
		["notdisturb_2"]="Do Not Disturb",
		["forward_uncondition_2"]="Call Forward Unconditional",
		["forward_uncondition_dst_2"]="Call Forward Unconditional Dest Number",
		["forward_busy_2"]="Call Forward Busy",
		["forward_busy_dst_2"]="Call Forward Busy Dest Number",
		["forward_noreply_2"]="Call Forward No Reply",
		["forward_noreply_dst_2"]="Call Forward No Reply Dest Number",
		["forward_noreply_timeout_2"]="Call Forward No Reply Timeout(s)",
		["dsp_input_gain_2"]="Input Gain",
		["dsp_output_gain_2"]="Output Gain",
		["slic_2"]="Impedance",
		["__slic_2_value"]={
				["0"]="600 Ohm",
				["1"]="900 Ohm",
				["2"]="270 Ohm + (750 Ohm || 150 nF) and 275 Ohm + (780 Ohm || 150 nF)",
				["3"]="220 Ohm + (820 Ohm || 120 nF) and 220 Ohm + (820 Ohm || 115 nF)",
				["4"]="370 Ohm + (620 Ohm || 310 nF)",
				["5"]="320 Ohm + (1050 Ohm || 230 nF)",
				["6"]="370 Ohm + (820 Ohm || 110 nF)",
				["7"]="275 Ohm + (780 Ohm || 115 nF)",
				["8"]="120 Ohm + (820 Ohm || 110 nF)",
				["9"]="350 Ohm + (1000 Ohm || 210 nF)",
				["10"]="200 Ohm + (680 Ohm || 100 nF)",
				["11"]="600 Ohm + 2.16 uF",
				["12"]="900 Ohm + 1 uF",
				["13"]="900 Ohm + 2.16 uF",
				["14"]="600 Ohm + 1 uF",
				["15"]="Global impedance"
		},
		["sip_from_field_2"]="Display Name / Username Format",
		["__sip_from_field_2_value"]={
			["0"]="Caller ID / Caller ID",
			["1"]="Display Name / Caller ID",
			["2"]="Extension / Caller ID",
			["3"]="Caller ID / Extension",
			["4"]="Anonymous",
		},
		["sip_from_field_un_2"]="Display Name / Username Format when CID unavailable",
		["__sip_from_field_un_2_value"]={
			["0"]="Display Name / Extension",
			["1"]="Anonymous",
		},
		["work_mode"]="Work Mode",
		["__work_mode_value"]={
			["0"]="Voice",
			["1"]="POS",
		},
		["profile"]="Profile",
		["status"]="Status",
	},
	["callcontrol"]={
		["featurecode"]="Feature Code",
		["__featurecode_value"]={
			["0"]="Off",
			["1"]="On",
		},
		["nortp"]="Disconnect call when no RTP packet",
		["__nortp_value"]={
			["0"]="Off"
		},
		["plc"]="Packet Loss Concealment(PLC)",
		["__plc_value"]={
			["0"]="Off",
			["1"]="On",
		},
		["eclen"]="Echo Canceller Tail Length(ms)",
		["ecgain"]="Echo Gain",
		["dtmf_detect_interval"]="DTMF Min Detect Interval(ms)",
		["rtp_start_port"]="RTP Start Port",
		["rtp_end_port"]="RTP End Port",
		["localcall"]="Local extension call",
		["__localcall_value"]={
			["0"]="Off",
			["1"]="On",
		},
	},
	["fax"]={
		["mode"]="Send Mode",
		["__mode_value"]={
			["t30"]="T.30",
			["t38"]="T.38",
		},
		["local_detect"]="Tone Detection by Local",
		["__local_detect_value"]={
			["0"]="Off",
			["1"]="On",
		},
		["detect_cng"]="Detect CNG/CED",
		["__detect_cng_value"]={
			["0"]="Off",
			["1"]="On",
		},
		["fax"]="a=fax",
		["__fax_value"]={
			["0"]="Off",
			["1"]="On",
		},
		["x_fax"]="a=X-fax",
		["__x_fax_value"]={
			["0"]="Off",
			["1"]="On",
		},
		["x_modem"]="a=X-modem",
		["__x_modem_value"]={
			["0"]="Off",
			["1"]="On",
		},
		["modem"]="a=modem",
		["__modem_value"]={
			["0"]="Off",
			["1"]="On",
		},
		["ecm"]="ECM",
		["__ecm_value"]={
			["0"]="Off",
			["1"]="On",
		},
		["rate"]="Rate",
		["__rate_value"] = {
			["2400"]="2400 bps",
			["4800"]="4800 bps",
			["7200"]="7200 bps",
			["9600"]="9600 bps",
			["12000"]="12000 bps",
			["14400"]="14400 bps",
		}
	},
	["feature_code"] = {
		["index"]="Index",
		["name"]="Name",
		["code"]="Key",
		["description"]="Description",
		["status"]="Status",
	},
	["ivr"] = {
		["timeout"]="Timeout",
		["repeat_loops"]="Repeat Loops",
		["enable_extension"]="Enable Direct Extension",
		["dtmf"]="DTMF",
		["destination"]="Destination",
		["dst_number"]="Destination Number",
		["status"]="Status",
	},
	["route"] = {
		["index"]="Priority",
		["name"]="Name",
		["from"]="Source",
		["__from_value"]={
			["0"]="Any",
			["-1"]="Custom",
		},
		["custom_from"]="Custom Source",
		["numberProfile"]="Number Profile",
		["__numberProfile_value"]={
			["0"]="Not Config",
		},
		["caller_num_prefix"]="Caller Number Prefix",
		["called_num_prefix"]="Called Number Prefix",
		["timeProfile"]="Time Profile",
		["__timeProfile_value"]={
			["0"]="Not Config",
		},
		["successNumberManipulation"]="Manipulation",
		["__successNumberManipulation_value"]={
			["0"]="Not Config",
		},
		["successDestination"]="Destination",
		["__successDestination_value"]={
			["Extension-1"]="Local Extension",
			["Hangup-1"]="Hangup",
		},
		["failoverflag"]="Failover Action",
		["__failoverflag_value"]={
			["0"]="Off",
			["1"]="On",
		},
		["failCondition"]="Condition",
		["timeout"]="Timeout Len(s)",
		["causecode"]="Other Condition Code",
		["failNumberManipulation"]="Manipulation or Failover Action",
		["__failNumberManipulation_value"]={
			["0"]="Not Config",
		},
		["failDestination"]="Destination for Failover Action",
	},
	["ddns"] = {
		["enabled"]="DDNS Service",
		["__enabled_value"]={
			["0"]="Disabled",
			["1"]="Enabled",
		},
		["service_name_list"]="Service Providers List",
		["service_name"]="Service Providers",
		["domain"]="Domain",
		["update_url"]="Update Url",
		["username"]="Username",
		["password"]="Password",
		["ip_source"]="IP Source",
		["__ip_source_value"]={
			["web"]="External Address",
			["network"]="Device Address",
		},
		["ip_url"]="IP Check URL",
		["check_interval"]="IP Check Period(m)",
		["force_interval"]="Service Update Interval(h)",
		["retry_interval"]="Retry Interval When Fail(s)",
	},
	["pptpc"] = {
		["enabled"]="Status",
		["__enabled_value"]={
			["0"]="Disabled",
			["1"]="Enabled",
		},
		["defaultroute"]="Default Route",
		["__defaultroute_value"]={
			["0"]="Disabled",
			["1"]="Enabled",
		},
		["mppe"]="Data Encryption",
		["__mppe_value"]={
			["0"]="Disabled",
			["1"]="Enabled",
		},
		["server"]="Server Address",
		["username"]="Username",
		["password"]="Password",
	},
	["xl2tpd"] = {
		["enabled"]="Status",
		["__enabled_value"]={
			["0"]="Disabled",
			["1"]="Enabled",
		},
		["start_ip"]="Client Start Address",
		["stop_ip"]="Client End Address",
		["locals"]="Server Address",
		["index"]="Index",
		["username"]="Username",
		["password"]="Password",
		["description"]="Description",
		["defaultroute"]="Default Route",
		["__defaultroute_value"]={
			["0"]="Disabled",
			["1"]="Enabled",
		},
		["server"]="Server Address",
	},
	["openvpn"] = {
		["enabled"]="Status",
		["__enabled_value"]={
			["0"]="Disable",
			["1"]="Enable",
		},
		["defaultroute"]="Default Route",
		["__defaultroute_value"]={
			["0"]="Disable",
			["1"]="Enable",
		},
		["key_change"]="Certificate",
		["__key_change_value"]={
			["0"]="Update",
			["1"]="Update",--when update, value is 0->1->0->1...,so no matter what value, certificate update is true
		},
	},
	["dhcp"] = {
		["rebind_protection"]="Disable Private Internets(RFC2918) DNS responses",
		["__rebind_protection_value"]={
			["0"]="Off",
			["1"]="On",
		},
		["ignore"]="DHCP Server",
		["__ignore_value"]={
			["0"]="Enabled",
			["1"]="Disabled",
		},
		["start"]="Start Address",
		["limit"]="End Address",
		["leasetime"]="Leasetime(Hour)",
		["dhcp_option"]="DHCP Server Setting",
	},
	["lucid"] = {
		["address"]="Port",
	},
	["system"] = {
		["hostname"]="Hostname",
		["timezone"]="Timezone Offset",
		["zonename"]="Timezone Name",
		["mod_cdr"]="CDRs",
		["__mod_cdr_value"]={
			["on"]="Enable",
			["off"]="Disable",
		},
		["log_level"]="Service Log Level",
		["__log_level_value"]={
			["8"]="Debug",
			["7"]="Info",
			["6"]="Notice",
			["5"]="Warning",
			["4"]="Error",
			["3"]="Critical",
			["2"]="Alert",
			["1"]="Emergency",
		},
		["syslog_enable"]="Enable Syslog",
		["__syslog_enable_value"]={
			["0"]="Off",
			["1"]="On",
		},
		["log_ip"]="Log Server IP Address",
		["log_port"]="Log Server Port",
		["enabled"]="Enable builtin NTP server",
		["__enabled_value"]={
			["0"]="Off",
			["1"]="On",
		},
		["server"]="NTP server candidates",
		["action"]="Enable",
		["port"]="Port",
	},
	["telnet"] = {
		["action"]="Enable",
		["port"]="Port",
	},
	["provision"] = {
		["enable"]="Enable",
		["repeat"]="Periodic Check",
		["__repeat_value"]={
			["yes"]="On",
			["no"]="Off",
		},
		["interval"]="Check Interval(s)",
		["url"]="URL",
		["username"]="Username",
		["password"]="Password",
		["proxy"]="Proxy Address",
		["proxy_username"]="Username",
		["proxy_password"]="Password",
	},
	["cloud"] = {
		["enable"]="Status",
		["__enable_value"]={
			["0"]="Disable",
			["1"]="Enable",
		},
		["domain"]="Server Address",
		["port"]="Server Port",
		["password"]="Password",
	},
	["easycwmp"] = {
		["enable"] = "Status",
		["__enable_value"]={
			["0"]="Disable",
			["1"]="Enable",
		},
		["url"]="URL",
		["username"]="Username",
		["password"]="Password",
		["periodic_enable"]="Periodic Inform",
		["__periodic_enable_value"]={
			["0"]="Disable",
			["1"]="Enable",
		},
		["periodic_interval"]="Inform Interval(s)",
	},
	["firewall"]={
		["enabled_http"]="Allow HTTP WAN access",
		["__enabled_http_value"]={
			["0"]="Off",
			["1"]="On",
		},
		["enabled_https"]="Allow HTTPS WAN access",
		["__enabled_https_value"]={
			["0"]="Off",
			["1"]="On",
		},
		["enabled_telnet"]="Allow Telnet WAN access",
		["__enabled_telnet_value"]={
			["0"]="Off",
			["1"]="On",
		},
		["enabled_ssh"]="Allow SSH WAN access",
		["__enabled_ssh_value"]={
			["0"]="Off",
			["1"]="On",
		},
		["lan_forward"] = "Default action outside the filter rules",
		["index"]="Index",
		["name"]="Name",
		["src_dport"]="WAN Port",
		["proto"]="Protocol",
		["__proto_value"]={
			["all"]="Any",
			["tcp"]="TCP",
			["udp"]="UDP",
			["tcp udp"]="TCP/UDP",
		},
		["src"]="Source",
		["__src_value"]={
			["lan"]="LAN",
			["wan"]="WAN",
		},
		["src_ip"]="Source IP",
		["src_port"]="Source Port",
		["src_mac"]="Source MAC",
		["dest"]="Dest",
		["__dest_value"]={
			["lan"]="LAN",
			["wan"]="WAN",
		},
		["dest_ip"]="Destination IP",
		["dest_port"]="Destination Port",
		["enabled"]="Status",
		["__enabled_value"]={
			["0"]="Disabled",
			["1"]="Enabled",
		},
		["target"]="Action",
	},
	["network"] = {
		["network_mode"] = "Network Model",
		["__network_mode_value"]={
			["route"]="Route",
			["bridge"]="Bridge",
		},
		["proto"]="Protocol",
		["__proto_value"]={
			["dhcp"]="DHCP",
			["static"]="Static address",
			["pppoe"]="PPPOE",
		},
		["ipaddr"]="IP Address",
		["netmask"]="Netmask",
		["username"]="Username",
		["password"]="Password",
		["service"]="Server Name",
		["gateway"]="Default Gateway",
		["peerdns"]="Obtain DNS server address automatically",
		["__peerdns_value"]={
			["0"]="Off",
			["1"]="On",
		},
		["dns"]="Use custom DNS server",
		["mtu"]="MTU",
	},
	["network_tmp"] = {
		["network_mode"] = "Network Model",
		["__network_mode_value"]={
			["route"]="Route",
			["bridge"]="Bridge",
			["client"]="客户端模式",
		},
		["access_mode"] = "网络接入方式",
		["__access_mode_value"]={
			["wan_dhcp"]="有线动态IP",
			["wan_static"]="有线静态IP",
			["wan_pppoe"]="PPPOE",
			["wlan_dhcp"]="无线动态IP",
			["wlan_static"]="无线静态IP",
		},
		["wan_proto"]="WAN Protocol",
		["__wan_proto_value"]={
			["dhcp"]="DHCP",
			["static"]="Static address",
			["pppoe"]="PPPOE",
		},
		["wan_ipaddr"]="WAN IP Address",
		["wan_netmask"]="WAN Netmask",
		["wan_username"]="Username",
		["wan_password"]="Password",
		["wan_service"]="Server Name",
		["wan_gateway"]="Default Gateway",
		["wan_peerdns"]="Obtain DNS server address automatically",
		["__wan_peerdns_value"]={
			["0"]="Off",
			["1"]="On",
		},
		["wan_dns"]="Use custom DNS server",
		["wan_mtu"]="MTU",
		["lan_proto"]="LAN Protocol",
		["__lan_proto_value"]={
			["dhcp"]="DHCP",
			["static"]="Static address",
			["pppoe"]="PPPOE",
		},
		["lan_ipaddr"]="LAN IP Address",
		["lan_netmask"]="LAN Netmask",
		["lan_username"]="Username",
		["lan_password"]="Password",
		["lan_service"]="Server Name",
		["lan_gateway"]="Default Gateway",
		["lan_peerdns"]="Obtain DNS server address automatically",
		["wifi_disabled"]="WIFI Status",
		["__wifi_disabled_value"]={
			["0"]="On",
			["1"]="Off",
		},
		["wifi_ssid"]="SSID",
		["wifi_channel"]="WIFI Channel",
		["wifi_encryption"]="WIFI Encryption",
		["__wifi_encryption_value"]={
			["wep"]="WEP",
			["psk"]="WPA+PSK",
			["psk2"]="WPA2+PSK",
			["none"]="NONE",
		},
		["wifi_wep"]="WIFI WEP Encryption Mode",
		["wifi_key"]="WIFI Password",
	},
	["upnpc"] = {
		["enable_http"]="Enable HTTP",
		["__enable_http_value"]={
			["0"]="Off",
			["1"]="On",
		},
		["http_port"]="HTTP External Port",
		["enable_https"]="Enable HTTPS",
		["__enable_https_value"]={
			["0"]="Off",
			["1"]="On",
		},
		["https_port"]="HTTPS External Port",
		["enable_telnet"]="Enable Telnet",
		["__enable_telnet_value"]={
			["0"]="Off",
			["1"]="On",
		},
		["telnet_port"]="Telnet External Port",
		["enable_ssh"]="Enable SSH",
		["__enable_ssh_value"]={
			["0"]="Off",
			["1"]="On",
		},
		["ssh_port"]="SSH External Port",
	},
	["lte"]={
		["disabled"]="Hardware Status",
		["userdisabled"]="Service Status",
		["username"]="Username",
		["password"]="Password",
		["__disabled_value"]={
			["0"]="Enabled",
			["1"]="Disabled",
		},
		["apn"]="APN",
		["__apn_value"]={
			["3gnet"]="3GNET",
			["cmnet"]="cmnet",
		},
		["dialnumber"]="Dial Number",
		["service"]="Service",
	},
	["mwan3"]={
		["metric"]="Uplink Strategy",
		["__metric_value"]={
			["1"]="Master",
			["2"]="Slave",
		},
		["track_ip"]="Track IP",
		["count"]="Ping Count",
		["timeout"]="Timeout(s)",
		["interval"]="Interval(s)",
		["down"]="Count of Down",
		["up"]="Count of Up",
	},
	["static_route"]={
		["index"]="Index",
		["netmask"]="Netmask",
		["name"]="Name",
		["target"]="Target IP",
		["gateway"]="Gateway",
		["status"]="Status",
		["interface"]="Interface",
		["__interface_value__"]={
			["wan"]="WAN",
			["lan"]="LAN",
			["wan2"]="LTE",
			["openvpn"]="OpenVPN",
			["ppp1701"]="L2TP",
			["ppp1723"]="PPTP",
		},
	},
	["hosts"]={
		["enabled"]="Status",
		["__enabled_value"]={
			["0"]="Enable",
			["1"]="Disable",
		},
		["hosts"]="Hosts List"
	},
	["wireless"] = {
		["ra_disabled"]="WLAN Service",
		["disabled"]="Status",
		["__disabled_value"]={
			["0"]="Enabled",
			["1"]="Disabled",
		},
		["channel"]="Channel",
		["txpower"]="TX Power",
		["__txpower_value"]={
			["10"]="10%",
			["20"]="20%",
			["30"]="30%",
			["40"]="40%",
			["50"]="50%",
			["60"]="60%",
			["70"]="70%",
			["80"]="80%",
			["90"]="90%",
			["100"]="100%",
		},
		["htmode"]="Band Width",
		["__htmode_value"]={
			["HT20"]="20 MHz",
			["HT40"]="40 MHz",
			["HT20/HT40"]="Auto",
		},
		["hwmode"]="Work Model",
		["isolate"]="Isolation",
		["__isolate_value"]={
			["0"]="Disabled",
			["1"]="Enabled",
		},
		["btw_isolate"]="Isolation (between SSID)",
		["__btw_isolate_value"]={
			["0"]="Disabled",
			["1"]="Enabled",
		},
		["within_isolate"]="Isolation (within SSID)",
		["__within_isolate_value"]={
			["0"]="Disabled",
			["1"]="Enabled",
		},
		["wps"]="WPS",
		["__wps_value"]={
			["off"]="Disabled",
			["on"]="Enabled",
		},
		["index"]="Index",
		["ssid"]="SSID",
		["network"]="Interface Binding",
		["encryption"]="Encryption",
		["__encryption_value"]={
			["psk2"]="WPA2+PSK",
			["psk"]="WPA+PSK",
			["none"]="None",
		},
		["key"]="Password",
		["wmm"]="Wireless Multimedia Extensions",
		["__wmm_value"]={
			["0"]="Off",
			["1"]="On",
		},
		["wdsencryptype"]="Encryption",
		["__wdsencryptype_value"]={
			["psk2"]="WPA2+PSK",
			["psk"]="WPA+PSK",
			["aes"]="AES",
			["none"]="None",
		},
		["mode"]="Mode",
		["device"]="Device",
		["ifname"]="Ifname",
		["wdsmode"]="WDS Service",
		["wdskey"]="Password",
		["wdsphymode"]="Physical Mode",
	},
}

function translate_multi_value(value)
	local t=util.split(value," ")
	local s=""
	for k,v in ipairs(t) do
		s = s..translate(v).." "
	end
	return s
end
function get_siptrunk_server(server_index)
	for i,j in pairs(uci:get_all("endpoint_siptrunk") or {}) do
		if j.index and j.name and server_index == j.index then
			return translate("SIP Trunk").." / "..j.name
		end	
	end

	return translate("Not Config")
end

function get_endpoint_name(value)
	if value:match("^GSM%-%d+$") or value:match("^gsmopen") then
		return translate("GSM Trunk")
	end

	if value:match("^FXS%-%d+%-%d+$") or value:match("^FXS%-%d+%/%d+$") then
		return translate("FXS Extension")
	end

	if value:match("^FXO%-%d+%-%d+$") or value:match("^FXO%/%d+%/%d+$") then
		return translate("FXO Trunk")
	end

	if value:match("^SIPP%-%d+$") then
		local sipp_number = value:match("^SIPP%-(%d+)$")
		for k, v in pairs(uci:get_all("endpoint_sipphone") or {}) do
			if v.index and v.name and sipp_number == v.index then
				return translate("SIP Extension").." / "..v.name.." / "..v.user
			end
		end
	end

	if value:match("^SIPT%-%d+$") or value:match("^SIPT%-%d+%_%d+$") then
		local sipt_number = value:match("^SIPT%-(%d+)$") or value:match("^SIPT%-(%d+%_%d+)$")
		for k, v in pairs(uci:get_all("endpoint_siptrunk") or {}) do
			if v.index and v.name and (sipt_number == v.index or sipt_number == v.profile.."_"..v.index) then
				return translate("SIP Trunk").." / "..v.name
			end
		end
	end

	if value:match("^ROUTE%-%d+$") then
		local idx = value:match("^ROUTE%-(%d+)$")
		for k, v in pairs(uci:get_all("endpoint_routegroup") or {}) do 
			if v.index and v.name and idx == v.index then
				return translate("Route Group").." / "..v.name
			end
		end
	end

	if value:match("^RING%-%d+$") then
		local idx = value:match("^RING%-(%d+)$")
		for k, v in pairs(uci:get_all("endpoint_ringgroup") or {}) do 
			if v.index and v.name and idx == v.index then
				return translate("Ring Group").." / "..v.name
			end
		end
	end

	if "Extension-1" == value then
		return translate("Local Extension")
	elseif "Hangup-1" == value then
		return translate("Hangup")
	else
		return value
	end
end

function get_ivr_dest(name)
	local i18n = require "luci.i18n"
	local uci = require "luci.model.uci".cursor()

	local desttype,param = name:match("(.+),(.+)")
	if desttype and param then
		if "Extensions" == desttype then
			for k,v in pairs(uci:get_all("endpoint_sipphone")) do
				if "fxs" == v[".type"] and param == v.number then
					return "SIP Extension / "..v.name.." / "..v.user
				end
			end
			return "FXS Extension / "..param
		elseif "Trunks" == desttype then
			if param:match("^FXO") then
				return "FXO Trunk"
			elseif param:match("^gsmopen") then
				return "GSM Trunk"
			else
				local sipt_number = param:match("^SIPT%-([0-9_]+)$")
				for k, v in pairs(uci:get_all("endpoint_siptrunk") or {}) do 
					if v.index and v.name and sipt_number == v.profile.."_"..v.index then
						return i18n.translate("SIP Trunk").." / "..v.name
					end
				end
			end
		elseif "Ringgroup" == desttype then
			local idx = param:match("^(%d+)/")
			for k, v in pairs(uci:get_all("endpoint_ringgroup") or {}) do 
				if v.index and v.name and idx == v.index then
					return i18n.translate("Ring Group").." / "..v.name
				end
			end
		else
			return "Get value fail !"
		end
		return "Get Value fail!"
	else
		return "Error"
	end
end

function ip2number(param)
	local ret_number = 0

	if param then
		local param_tb = util.split(param,".")
		for i=1,4,1 do
			ret_number = ret_number + tonumber(param_tb[i])*(256^(4-i))
		end
	end

	return ret_number
end

function number2ip(param)
	local ret_ip = ""
	local tmp_a = param
	local tmp_b = param
	local index = 0
	
	repeat
		index = index + 1
		tmp_a = tmp_b % 256
		tmp_b = math.floor(tmp_b / 256)
		if index == 1 then
			ret_ip = tmp_a
		else
			ret_ip = tmp_a.."."..ret_ip
		end
	until (tmp_b < 256)

	if index == 1 then
		ret_ip = "0.0."..tmp_b.."."..ret_ip
	elseif index == 2 then
		ret_ip = "0."..tmp_b.."."..ret_ip
	elseif index == 3 then
		ret_ip = tmp_b.."."..ret_ip
	end

	return ret_ip
end

function parse_dhcp_server_value(option,value)
	local bit = require "bit"
	local lan_ip = uci:get("network_tmp","network","lan_ipaddr") or "192.168.11.1"
	local lan_netmask = uci:get("network_tmp","network","lan_netmask") or "255.255.255.0"
	--local lan_ip_prefix = ""
	local tmp_ip = util.split(lan_ip,".")
	local tmp_netmask = util.split(lan_netmask,".")
	local dhcp_ip_pool = bit.band(tmp_ip[1],tmp_netmask[1]).."."..bit.band(tmp_ip[2],tmp_netmask[2]).."."..bit.band(tmp_ip[3],tmp_netmask[3]).."."..bit.band(tmp_ip[4],tmp_netmask[4])

	if "start" == option and value then
		local start_number = bit.bor(bit.band(bit.bnot(ip2number(lan_netmask)),value),ip2number(dhcp_ip_pool))
		return number2ip(start_number)
	elseif "limit" == option and value then
		local start = uci:get("dhcp","lan","start") or "1"
		local start_number = bit.bor(bit.band(bit.bnot(ip2number(lan_netmask)),start),ip2number(dhcp_ip_pool))
		local max_number = ip2number(dhcp_ip_pool) + bit.band(bit.bnot(ip2number(lan_netmask)),ip2number("255.255.255.255")) - 1
		local ret_str = ""
		
		if (tonumber(value)+start_number) >= max_number then
			return number2ip(max_number)
		else
			return number2ip(bit.bor(bit.band(bit.bnot(ip2number(lan_netmask)),start+value-1),ip2number(dhcp_ip_pool)))
		end
	elseif "dhcp_option" == option then
		if value:match("^3,") then
			return translate("Gateway").." : "..(value:match("^3,([0-9%.]+)") or translate("Error"))
		elseif value:match("^6,") then
			return translate("DNS").." : "..(value:match("^6,([0-9%.%,]+)") or translate("Error"))
		else
			return ""
		end
	end
	return translate("NULL")
end

function get_config_name(cfg_name,section)
	if section then
		local t = uci:get_all(cfg_name) or {}
		for k,v in pairs(t) do
			if k == section or v[".name"] == section then
				if "profile_fxso" == cfg_name and v.name then
					return translate(("fxs" == v[".type"] and "FXS Profile" or "FXO Profile")).." / "..v.name
				elseif "endpoint_fxso" == cfg_name and v.name then
					return translate(("fxs" == v[".type"] and "FXS Extension" or "FXO Trunk")).." / "..(v.number_1 or v.number_2 or "unknown")
				elseif "feature_code" == cfg_name and v.name then
					return translate("Feature Code").." / "..translate(v.name)
				elseif "callcontrol" == cfg_name and "voice" == v[".type"] and v.featurecode then
					return translate("Feature Code")
				elseif "ivr" == cfg_name then
					return "IVR / "..translate("ivr"==v[".type"] and "General" or "Menu")
				elseif "provision" == cfg_name or "cloud" == cfg_name or "dhcp" == cfg_name or "ddns" == cfg_name or "upnpc" == cfg_name then
					return translate(config_file[cfg_name])
				elseif "firewall" == fcfg_name and "dmz" == v[".name"] then
					return "DMZ"
				elseif "firewall" == cfg_name and "redirect" == v[".type"] and v.name then
					return translate("Port Mapping").." / "..v.name
				elseif "network" == cfg_name and "wan2" == section then
					return "LTE"
				elseif "mwan3" == cfg_name and ("wan" == section or "wan_m1_w3" == section) then
					return translate("Uplink Config").." / WAN"
				elseif "mwan3" == cfg_name and ("wan2" == section or "wan2_m2_w2" == section) then
					return translate("Uplink Config").." / LTE"
				elseif "network_tmp" == cfg_name and "network" == section then
					return translate("Network")
				elseif "hosts" == cfg_name then
					return "Hosts"
				elseif "openvpn" == cfg_name then
					return translate("OpenVPN Client")
				elseif "pptpc" == cfg_name then
					return translate("PPTP Client")
				elseif "xl2tpd" == cfg_name then
					return translate("L2TP Client")
				elseif "easycwmp" == cfg_name then
					return "TR069"
				elseif "wireless" == cfg_name then
					return "WLAN / "..translate("wifi-device"==v[".type"] and "General" or "SSID")
				elseif v.name then
					return translate((config_file[cfg_name] or cfg_name or "unknown")).." / "..v.name
				else
					return translate(config_file[cfg_name] or cfg_name) ..(v[".name"] and (("main" == v[".name"]) and (" / "..translate("General"))) or (" / "..translate(v[".name"])) or "")
				end
			end
		end
	end
	if "ivr" == cfg_name then
		return translate(config_file[cfg_name] or cfg_name or "unknown") .." / "..translate("Menu")
	else
		return translate(config_file[cfg_name] or cfg_name or "unknown")
	end
end

function get_config_option_name(cfg_name,section,option)
	if "network" == cfg_name and "wan2" == section then
		return translate(config["lte"] and config["lte"][option] or option)
	else
		return translate(config[cfg_name] and config[cfg_name][option] or option)
	end
end

function get_config_option_value(cfg_name,section,option,value)
	if "true" == value or "on" == value or "Activate" == value then
		return translate("On")
	elseif "false" == value or "off" == value or "Deactivate" == value then
		return translate("Off")
	elseif ("endpoint_fxso" == cfg_name or "endpoint_mobile" == cfg_name) and option:match("_server_") then
		return get_siptrunk_server(value)
	elseif ("endpoint_fxso" == cfg_name or "endpoint_mobile" == cfg_name) and option:match("_gain") and value then
		return value.."dB"
	elseif ("endpoint_fxso" == cfg_name or "endpoint_sipphone") and (option:match("forward_uncondition") or option:match("forward_busy") or option:match("forward_noreply")) and value then
		return get_endpoint_name(value)
	elseif "ivr" == cfg_name and "destination" == option and value then
		return get_ivr_dest(value)
	elseif "dhcp" == cfg_name and ("start" == option or "limit" == option or "dhcp_option" == option) and value then
		return parse_dhcp_server_value(option,value)
	elseif "route" == cfg_name and ("custom_from" == option or "from" == option or "successDestination" == option or "failDestination" == option) and value and value > '0' then
		return get_endpoint_name(value)
	elseif ("endpoint_ringgroup" == cfg_name or "endpoint_routegroup" == cfg_name) and "members_select" == option and value then
		return get_endpoint_name(value)
	elseif "network" == cfg_name and "wan2" == section then
		return translate(config["lte"] and config["lte"]["__"..option.."_value"] and config["lte"]["__"..option.."_value"][value] or value)
	else
		return translate(config[cfg_name] and config[cfg_name]["__"..option.."_value"] and config[cfg_name]["__"..option.."_value"][value] or value)
	end
end
