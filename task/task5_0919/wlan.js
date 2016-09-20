<%
	local uci = require "luci.model.uci".cursor()
	local status = luci.http.formvalue("status")
	if status then
		return
	end
-%>

<%+header%>
<script type="text/javascript" src="<%=resource_cbi_js%>"></script>
<script type="text/javascript">
function get_list()
{

}

$(document).ready(function() {
	get_list()
})

</script>
<% if wifi_info then %>
<div style="position:relative;left:10px;top:10px;width:480px;float:left;height:250;">
<fieldset class="cbi-section" style="border-buttom:;">
	<legend><%:WIFI Network%></legend>
	<table width="100%" cellspacing="10" class="info">
		<tr><td width="30%"><%:MAC Address%></td><td><%=string.gsub(string.upper(wlan_info.mac_addr or "00:00:00:00:00:00"),":","-")%></td></tr>
		<tr><td><%:SSID%></td><td><%=wlan_info.ssid or ""%></td></tr>
		<tr><td><%:Channel%></td><td><%=wlan_info.channel or ""%></td></tr>
		<tr><td><%:Encryption%></td><td><%=translate(string.upper(wlan_info.encrypt or "Unknown"))%></td></tr>
		<tr><td><%:RX / TX (Per Second)%></td><td id="wlan_network_traffic" colspan="3"></td></tr>
		<tr><td><%:RX / TX (Total)%></td><td id="wlan_network_static" colspan="3"></td></tr>
	</table>
</fieldset>
</div>
<% end %>

<% if wds_info_abc then %>
<div style="position:relative;left:10px;top:10px;width:480px;float:left;height:250;">
<fieldset class="cbi-section" style="border-buttom:;">
	<legend><%:WIFI Network%></legend>
	<table width="100%" cellspacing="10" class="info">
		<tr><td width="30%"><%:MAC Address%></td><td><%=string.gsub(string.upper(wlan_info.mac_addr or "00:00:00:00:00:00"),":","-")%></td></tr>
		<tr><td><%:SSID%></td><td><%=wlan_info.ssid or ""%></td></tr>
		<tr><td><%:Channel%></td><td><%=wlan_info.channel or ""%></td></tr>
		<tr><td><%:Encryption%></td><td><%=translate(string.upper(wlan_info.encrypt or "Unknown"))%></td></tr>
		<tr><td><%:RX / TX (Per Second)%></td><td id="wlan_network_traffic" colspan="3"></td></tr>
		<tr><td><%:RX / TX (Total)%></td><td id="wlan_network_static" colspan="3"></td></tr>
	</table>
</fieldset>
</div>
<% end %>

<%+footer%>
