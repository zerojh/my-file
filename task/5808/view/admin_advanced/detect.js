<%+header%>
<style type="text/css">
.description {
	border: 1px solid;
	padding: 15px 30px;
}
.line {
	white-space: normal;
	text-align: left;
	text-indent: 2em;
	margin-bottom: 0;
	margin-left: 0;
	line-height: 16px;
	font-size: 14px;
}
table {
	margin:0;
}
table td {
	line-height: 24px;
	padding: 18px 0 0 0;
}
.detect-list {
	width: 60% ;
	float: left;
	clear: both;
}
.detect-value {
	padding-top: 18px;
	margin-bottom: 18px;
	zoom: 1;
	clear: both;
}
.detect-title {
	width: 40%;
	float: left;
	line-height: 24px;
}
.detect-field {
	width: 20%;
	float: left;
	text-align: right;
	line-height: 24px;
}
.detect-tip {
	width: 39%;
	float: right;
	color: #b94a48;
	text-align: left;
	word-break: break-all;
	line-height: 1;
	padding-top: 5px;
}
.button-action {
	margin-bottom: 18px;
	padding-top: 15px;
	text-align: center;
	clear: both;
}
</style>
<script language=javascript type="text/javascript" src="/luci-static/resources/jquery-1.9.1.min.js"></script>
<script type="text/javascript" src="<%=resource_cbi_js%>"></script>
<script language="JavaScript" type="text/JavaScript">
var g_status = "<%=status or "test_stop"%>";
var g_num = 0;
var g_detecting_mod = new Array();
<%- if detecting_str and status == "test_working" then %>
var g_detecting_str = "<%=detecting_str%>"
<%- else %>
var g_detecting_str = ""
<%- end %>
var g_access_mod = new Array("network");
<%- if siptrunk == "1" then -%>
g_access_mod.push("siptrunk");
<%- end -%>
<%- if sim == "1" then -%>
g_access_mod.push("sim");
<%- end %>
<%- if ddns == "1" then -%>
g_access_mod.push("dDns");
<%- end -%>
<%- if l2tp == "1" then -%>
g_access_mod.push("l2tp");
<%- end -%>
<%- if pptp == "1" then -%>
g_access_mod.push("pptp");
<%- end -%>
<%- if openvpn == "1" then -%>
g_access_mod.push("openvpn");
<%- end -%>

function change_description()
{
	id = document.getElementById("description");
	var str = "";

	if (g_status == "test_working") {
		str += '<p class="line">正在检测，请稍等...</p>';
		str += '<br/>';
		str += '<p class="line" style="color:#b94a48;">检测期间，请勿进行其它操作！</p>';
	} else if (g_status == "test_finish"){
		str += '<p class="line">检测完毕．</p>';
		str += '<br/>';
	} else {
		str += '<p class="line">请选择要检测的模块，并点击＂开始＂．如没有开启模块，则无法选择并检测该模块！</p>';
		str += '<br/>';
	}
	id.innerHTML = str;
}
function translate_cause(access_mode, element, err_msg)
{
	var access_mode = access_mode
	var element = element
	var ret = ''

	if (element == 'ipaddr') {
		ret += '可能由以下原因造成:<br/>'
		if (access_mode == 'wan_dhcp') {
			ret += '1.网线松动或断裂<br/>'
			ret += '2.网关DHCP未开启<br/>'
			ret += '3.网关设备硬件问题'
		} else if (access_mode == 'wan_pppoe') {
			ret += '1.网线松动或断裂<br/>'
			ret += '2.pppoe连接密码有误'
		} else if (access_mode == 'wlan_dhcp') {
			ret += '1.无线连接失败'
		} else {
			ret += '未知原因'
		}
	} else if (element == 'gateway') {
		ret += '可能由以下原因造成:<br/>'
		if (access_mode == 'wan_static') {
			ret += '1.网线松动或断裂<br/>'
			ret += '2.网关地址填写有误<br/>'
			ret += '3.网关设备硬件问题'
		} else if (access_mode == 'wlan_static') {
			ret += '1.无线连接失败'
		} else {
			ret += '未知原因'
		}
	} else if (element == 'dns') {
		ret += "可能由以下原因造成:<br/>"
		ret += '1.网关无法连接外部网络<br/>'
		ret += '2.DNS服务器地址填写错误<br/>'
		ret += '3.DNS服务器不可用'
	} else if (element == 'baidu') {
		ret += '可能由以下原因造成:<br/>'
		ret += "DNS服务器域名解析错误"
	} else if (element == 'siptrunk-connect') {
		ret += '通讯调度平台地址填写或通讯调度平台错误'
	} else if (element == 'siptrunk-register') {
		ret += '通讯调度平台地址填写或通讯调度平台错误'
	} else if (element == 'ddns') {
		ret += 'DDNS信息填写有误'
	} else if (element == 'l2tp') {
		ret += 'L2TP信息填写有误或L2TP服务器错误'
	} else if (element == 'pptp') {
		ret += 'PPTP信息填写有误或PPTP服务器错误'
	} else if (element == 'openvpn') {
		ret += 'OpenVPN信息填写有误或OpenVPN服务器错误'
	} else if (element == 'sim') {
		if (err_msg.indexOf('disabled') >= 0)
			ret += 'SIM模块已禁用'
		else if (err_msg.indexOf('no_device') >= 0)
			ret += '无SIM模块'
		else if (err_msg.indexOf('no_card') >= 0)
			ret += 'SIM卡未插入、未插好或已损坏'
		else if (err_msg.indexOf('not_registered') >= 0)
			ret += '注册失败'
		else
			ret += '未知原因'
	} else {
		ret += '未知原因'
	}
	return ret
}
function option_changes()
{
	var flag = 0;
	for (var i=0;i<g_access_mod.length;i++) {
		if (document.getElementById("test."+g_access_mod[i]).checked)
		{
			flag = 1;
			break;
		}
	}
	if(flag)
		document.getElementById("test_start").disabled="";
	else
		document.getElementById("test_start").disabled="disabled";
}
function insert_detecting_array(arg)
{
	var str = arg;

	g_detecting_str = "%"
	g_detecting_mod = new Array();

	if (str.indexOf("network")>=0 || str.indexOf("ipaddr")>=0 || str.indexOf("gateway")>=0 || str.indexOf("dns")>=0 || str.indexOf("baidu")>=0) {
		g_detecting_str += "ipaddr%gateway%dns%baidu%";
		g_detecting_mod.push("ipaddr","gateway","dns","baidu");
	}
	if (str.indexOf("siptrunk") >= 0) {
		g_detecting_str += "siptrunk-connect%siptrunk-register%";
		g_detecting_mod.push("siptrunk-connect","siptrunk-register");
	}
	if (str.indexOf("sim") >= 0) {
		g_detecting_str += "sim%"
		g_detecting_mod.push("sim")
	}
	if (str.indexOf("dDns") >= 0) {
		g_detecting_str += "dDns%";
		g_detecting_mod.push("dDns");
	}
	if (str.indexOf("l2tp") >= 0) {
		g_detecting_str += "l2tp%";
		g_detecting_mod.push("l2tp")
	}
	if (str.indexOf("pptp") >= 0) {
		g_detecting_str += "pptp%"
		g_detecting_mod.push("pptp")
	}
	if (str.indexOf("openvpn") >= 0) {
		g_detecting_str += "openvpn%"
		g_detecting_mod.push("openvpn")
	}
}
function test_start()
{
	var v = "";
	for(i=0;i<g_access_mod.length;i++)
	{
		if(document.getElementById("test."+g_access_mod[i]).checked)
			v = v+g_access_mod[i]+",";
	}
	g_detecting_str = v
	$("#button").empty()
	$("#checkbox").remove()
	insert_detecting_array(g_detecting_str);
	detect();
}
function detect()
{
	var element = g_detecting_mod[g_num]
	var value_id = document.getElementById('value-'+element)
	var field_id = document.getElementById('field-'+element)

	window.onbeforeunload = function () {
		 return true
	}

	if (element == 'ipaddr'||element == 'gateway'||element == 'dns'||element == 'baidu')
		$('#value-network').show()
	$('#value-'+element).show()
	field_id.innerHTML = '<img style="width:20px;" src="/luci-static/resources/icons/loading.gif"/>'

	if (g_status != "test_working") {
		XHR.get('<%=REQUEST_URI%>',{action:"start",string:g_detecting_str},function(x, info) {});
	}
	g_status = "test_working";
	change_description();

	checkfinish = function() {
		XHR.get('<%=luci.dispatcher.build_url("admin","advanced","detectstatus")%>',{action:"status"},function(x) {
			var element = g_detecting_mod[g_num];
			var regex = new RegExp(element + ':([^;]*);');
			var stop = false;
			var in_network = false;
			var field_id;

			if (x.responseText.match(regex)) {
				var err_msg = RegExp.$1;
				field_id = document.getElementById('field-' + element);

				if (err_msg == 'success') {
					field_id.innerHTML = '<img style="width:20px;" src="/luci-static/resources/icons/correct.png"/>'
				} else {
					var tip_id;
					var access_mode;

					if (x.responseText.match('access_mode:([^;]*);')) {
						access_mode = RegExp.$1;
						access_mode = access_mode!=''?access_mode:'';
					} else {
						access_mode = ''
					}

					if (element == 'ipaddr'||element == 'gateway'||element == 'dns'||element == 'baidu') {
						tip_id = document.getElementById('tip-network');
						stop = true;
					} else {
						tip_id = document.getElementById('tip-' + element);
					}
					field_id.innerHTML = '<img style="width:20px;" src="/luci-static/resources/icons/error.png"/>'
					tip_id.innerHTML = translate_cause(access_mode,element,err_msg)
				}
				g_num += 1
			}

			if (!stop && g_num != g_detecting_mod.length) {
				element = g_detecting_mod[g_num]
				$('#value-'+element).show()
				field_id = document.getElementById('field-' + element)
				field_id.innerHTML = '<img style="width:20px;" src="/luci-static/resources/icons/loading.gif"/>'
				window.setTimeout(checkfinish, 1000);
			} else {
				g_status = "test_finish";
				change_description();
				window.onbeforeunload = null
			}
		});
	};
	window.setTimeout(checkfinish, 1000);
}
$(document).ready(function () {
	change_description()
	if (g_status == "test_working") {
		insert_detecting_array(g_detecting_str);
		detect()
	} else {
		option_changes()
	}
})
</script>
<h2><a id="content" name="content">高级 / 检测</a></h2>
<fieldset>
	<div class="description" id="description">
	</div>
</fieldset>
<% if status ~= "test_working" then %>
<fieldset class="cbi-section" id="checkbox"><form><div class="cbi-value" style="padding-top:0;">
	<div class="cbi-value-title"><label>选择要检测的网络</label></div>
	<div class="cbi-value-field">
		<div style="width:20%;float:left;">
			<input class="cbi-input-checkbox" type="checkbox" id="test.network" name="test.network" onclick="option_changes()"/>
			<label for="test.network" id="label-network">网络</label>
		</div>
		<div style="width:35%;float:left;">
			<input class="cbi-input-checkbox" type="checkbox" id="test.siptrunk" name="test.siptrunk" <%=siptrunk == "1" and "" or "disabled='disabled'"%> onclick="option_changes()"/>
			<label for="test.siptrunk" id="label-siptrunk" style="color:<%=siptrunk == "1" and "#404040" or "#c3c3c3"%>">通讯调度平台</label>
		</div>
		<div style="width:35%;float:left;">
			<input class="cbi-input-checkbox" type="checkbox" id="test.dDns" name="test.dDns" <%=ddns == "1" and "" or "disabled='disabled'"%> onclick="option_changes()"/>
			<label for="test.dDns" id="label-dDns" style="color:<%=ddns == "1" and "#404040" or "#c3c3c3"%>">动态域名服务</label>
		</div>
		<div style="width:20%;float:left;">
			<input class="cbi-input-checkbox" type="checkbox" id="test.pptp" name="test.pptp" <%=pptp == "1" and "" or "disabled='disabled'"%> onclick="option_changes()"/>
			<label for="test.pptp" id="label-pptp" style="color:<%=pptp == "1" and "#404040" or "#c3c3c3"%>">PPTP</label>
		</div>
		<div style="width:20%;float:left;">
			<input class="cbi-input-checkbox" type="checkbox" id="test.l2tp" name="test.l2tp" <%=l2tp == "1" and "" or "disabled='disabled'"%> onclick="option_changes()"/>
			<label for="test.l2tp" id="label-l2tp" style="color:<%=l2tp == "1" and "#404040" or "#c3c3c3"%>">L2TP</label>
		</div>
		<div style="width:30%;float:left;">
			<input class="cbi-input-checkbox" type="checkbox" id="test.openvpn" name="test.openvpn" <%=openvpn == "1" and "" or "disabled='disabled'"%> onclick="option_changes()"/>
			<label for="test.openvpn" id="label-openvpn" style="color:<%=openvpn == "1" and "#404040" or "#c3c3c3"%>">OpenVPN</label>
		</div>
		<div style="width:20%;float:left;">
			<input class="cbi-input-checkbox" type="checkbox" id="test.sim" name="test.sim" <%=sim == "1" and "" or "disabled='disabled'"%> onclick="option_changes()"/>
			<label for="test.sim" id="label-sim" style="color:<%=sim == "1" and "#404040" or "#c3c3c3"%>">SIM</label>
		</div>
	</div>
</div></form></fieldset>
<% end %>
<fieldset>
	<div class="detect-node" id="value-network" style="display:none;">
		<div class="detect-list">
			<table>
				<tr id="value-ipaddr">
					<td style="text-align:left">检查本地IP地址</td>
					<td style="text-align:right" id="field-ipaddr"><img style="width:20px;" src="/luci-static/resources/icons/loading.gif"/></td>
				</tr>
				<tr id="value-gateway">
					<td style="text-align:left">检查网关地址</td>
					<td style="text-align:right" id="field-gateway"></td>
				</tr>
				<tr id="value-dns">
					<td style="text-align:left">检查DNS服务器</td>
					<td style="text-align:right" id="field-dns"></td>
				</tr>
				<tr id="value-baidu">
					<td style="text-align:left">尝试连接百度</td>
					<td style="text-align:right" id="field-baidu"></td>
				</tr>
			</table>
		</div>
		<div class="detect-tip" id="tip-network" style="padding-top:20px;line-height:1.5;">
		</div>
	</div>
	<div class="detect-node">
		<%- if  siptrunk and siptrunk == "1" then %>
		<div class="detect-value" id="value-siptrunk-connect" style="display:none;">
			<div class="detect-title">连接通讯调度平台</div>
			<div class="detect-field" id="field-siptrunk-connect"><img style="width:20px;" src="/luci-static/resources/icons/loading.gif"/></div>
			<div class="detect-tip" id="tip-siptrunk-connect"></div>
		</div>
		<div class="detect-value" id="value-siptrunk-register" style="display:none;">
			<div class="detect-title">注册到通讯调度平台</div>
			<div class="detect-field" id="field-siptrunk-register"></div>
			<div class="detect-tip" id="tip-siptrunk-register"></div>
		</div>
		<%- end
			if sim and sim == "1" then %>
		<div class="detect-value" id="value-sim" style="display:none;">
			<div class="detect-title">获取SIM卡信息</div>
			<div class="detect-field" id="field-sim"></div>
			<div class="detect-tip" id="tip-sim"></div>
		</div>
		<%-	end
			if ddns and ddns == "1" then %>
		<div class="detect-value" id="value-dDns" style="display:none;">
			<div class="detect-title">连接DDNS服务商</div>
			<div class="detect-field" id="field-dDns"></div>
			<div class="detect-tip" id="tip-dDns"></div>
		</div>
		<%- end
			if l2tp and l2tp == "1" then %>
		<div class="detect-value" id="value-l2tp" style="display:none;">
			<div class="detect-title">建立L2TP连接</div>
			<div class="detect-field" id="field-l2tp"></div>
			<div class="detect-tip" id="tip-l2tp"></div>
		</div>
		<%- end
			if pptp and pptp == "1" then %>
		<div class="detect-value" id="value-pptp" style="display:none">
			<div class="detect-title">建立PPTP连接</div>
			<div class="detect-field" id="field-pptp"></div>
			<div class="detect-tip" id="tip-pptp"></div>
		</div>
		<%- end
			if openvpn and openvpn == "1" then %>
		<div class="detect-value" id="value-openvpn" style="display:none">
			<div class="detect-title">建立OpenVPN连接</div>
			<div class="detect-field" id="field-openvpn"></div>
			<div class="detect-tip" id="tip-openvpn"></div>
		</div>
		<%-	end %>
	</div>
	<% if status ~= "test_working" then %>
	<div class="button-action" id="button" style="clear:both;margin-bottom:0;">
		<input class="cbi-button" type="button" value="开始" id="test_start" name="test_start" onclick="return test_start();"/>
	</div>
	<% end %>
</fieldset>
<%+footer%>
