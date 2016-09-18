<%
	local uci = require "luci.model.uci".cursor()
	local fs_server = require "luci.scripts.fs_server"

	if luci.http.formvalue("status") == "1" then
		local wifi_list = fs_server.get_wifi_list("refresh") or {}

		luci.http.prepare_content("application/json")
		luci.http.write_json(wifi_list)

		return
	end
-%>

<%+header%>
<style>
/* Make text align center. */
.text-center {
	text-align: center;
}

/* The filters input style. */
input.connfilter {
	width: 80%;
}

/* The filter button. */
button.filter-btn {
	color: #3498db;
	background-color: #ffffff;
	padding: 5px;
	border-radius: 4px;
}

/* Content table style */
div.div-table {
	max-height: 285px;
	overflow: auto;
}

/* General table style. */
table td {overflow: hidden; text-overflow: ellipsis; white-space:nowrap; text-align: center;}
table {table-layout: fixed;}
</style>
<script language=javascript type="text/javascript" src="/luci-static/resources/jquery-1.9.1.min.js"></script>
<script src="<%=resource_cbi_js%>"></script>
<script>
function filter_result()
{
	$("#filter-id").toggle();
	keyup_event();
}

function keyup_event()
{
	$(".connfilter").val("")

	/* Simulate a keyup event. */
	var e = $.Event("keyup")
	e.which = 13
	$(".connfilter").trigger(e)
}

function change_encryption_view(encryption)
{
	var enc = encryption
	var ret = ""

	if (enc.indexOf('WPA2') >= 0) {
		ret = "WPA2+PSK"
	} else if (enc.indexOf('WPA1') >= 0) {
		ret = "WPA+PSK"
	} else if (enc.indexOf('AES') >= 0) {
		ret = "AES"
	} else if (enc.indexOf('NONE') >= 0) {
		ret = "NONE"
	} else {
		ret = "WPA+PSK"
	}

	return ret
}

function get_list()
{
	XHR.poll(5, '<%=REQUEST_URI%>',{status:1},function(x,info)
/*
	XHR.get('<%=REQUEST_URI%>',{status:1},function(x,info)
*/
	{
		if (info != null) {
			$("#content-id").empty()
			for (i=0; i<info.length; i++) {
				var str = ""

				if (0 == i%2)
					str += "<tr class='cbi-rowstyle-odd'>"
				else
					str += "<tr class='cbi-eowstyle-even'>"
				str += "<td class='text-center'>" + (i+1) + "</td>"
				str += "<td class='text-center'>" + info[i]["channel"] + "</td>"
				str += "<td class='text-center'>" + info[i]["ssid"] + "</td>"
				str += "<td class='text-center'>" + info[i]["bssid"] + "</td>"
				str += "<td class='text-center'>" + change_encryption_view(info[i]["encryption"]) + "</td>"
				str += "<td class='text-center connlist' colspan='2'>" + info[i]["signal"] + "</td></tr>"
				$("#content-id").append(str)

				if("none" != $("#filter-id").css("display")) {
					$("#filter-id input").each(function(){
						if($(this).val().length > 0)
							$(this).keyup()
					})
				}
			}
		}
	})
}

$(document).ready(function(){
	$(".connfilter").keyup(function(e) {
		$(".no-result").remove()
		/* ignore tab. */
		var code = e.keyCode || e.which
		if ("9" == code) {
			return;
		}

		var $input = $(this)
		inputContent = $input.val().toLowerCase()
		$panel = $input.parents("#filter-id")
		column = $panel.find("td").index($input.parents("td"))
		$table = $(".connlist").parent("tr")
		$rows = $table
		var $filteredRows = $rows.filter(function() {
			var value = $(this).find("td").eq(column).text().toLowerCase()
			return value.indexOf(inputContent) === -1
		})
		$rows.show()
		$filteredRows.hide()
		if ($filteredRows.length === $rows.length) {
			$("#content-id").append($('<tr class="no-result"><td colspan="8"><%:No result found%></td></tr>'))
		}
	})
	$("#content-id").append($('<tr class="loading-now"><td colspan="8"><img src="<%=resource%>/icons/loading.gif" alt="<%:Loading%>"/></td></tr>'))

	get_list()
})

</script>
<style type="text/css">
table td {overflow:hidden;text-overflow:ellipsis;white-space:nowrap;}
table {table-layout:fixed;}
</style>
<div>
<fieldset>
	<legend><%:WIFI List%></legend>
	<table>
		<colgroup>
			<col style="width:10%;"/>
			<col style="width:10%;"/>
			<col style="width:25%;"/>
			<col style="width:25%;"/>
			<col style="width:15%;"/>
			<col style="width:10%;"/>
			<col style="width:5%;"/>
		</colgroup>
		<tr>
			<th><%:Index%></th>
			<th><%:Channel%></th>
			<th><%:SSID%></th>
			<th><%:BSSID%></th>
			<th><%:encryption%></th>
			<th style="text-align:right"><%:Signal%></th>
			<th><div><button type="button" class="filter-btn" onclick="filter_result()"><%:Filter%></button></div></th>
		</tr>
		<tr id="filter-id" style="display: none;">
			<td><input type="text" class="connfilter"/></td>
			<td><input type="text" class="connfilter"/></td>
			<td><input type="text" class="connfilter"/></td>
			<td><input type="text" class="connfilter"/></td>
			<td><input type="text" class="connfilter"/></td>
			<td colspan="2"><input type="text" class="connfilter"/></td>
		</tr>
	</table>

	<table class="div-table cbi-section-table">
		<colgroup>
			<col style="width:10%;"/>
			<col style="width:10%;"/>
			<col style="width:25%;"/>
			<col style="width:25%;"/>
			<col style="width:15%;"/>
			<col style="width:10%;"/>
			<col style="width:5%;"/>
		</colgroup>
		<tbody id="content-id">
		</tbody>
	</table>
</fieldset>
</div>
<%+footer%>
