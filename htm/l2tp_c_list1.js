<%
%>

<%+header%>
<style>
input.connfilter{width:80%;}
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
	$(".connfilter").val("");

	/* Simulate a keyup event. */
	var e = $.Event("keyup");
	e.which = 13;
	$(".connfilter").trigger(e);
}

function get_list(param)
{
/*
	XHR.get('<%=luci.dispatcher.build_url("admin", "status", "vpn","more","l2tp_client")>',
	{action:param, cmd:0, cmd:0},
		function(x, info)
		{
/*
			for k,v in ipairs(live_cont) do
				local str=""
				if 1 == k%2 then
					str=str.."<tr id='live-row-"..k.."' class='cbi-rowstyle-odd'"
				else
					str=str.."<tr id='live-row-"..k.."' class='cbi-rowstyle-even'"
				end
				str=str..">"
				for i,j in ipairs(v) do
					if 8 == i then
						str=str.."<td colspan='2' class='sectohuman text-center' id='live-sectohuman-"..k.."'>"..j.."</td>"
					else
						str=str.."<td class='text-center'>"..j.."</td>"
					end
				end
				write(str.."</tr>")
			end
*/
			if (info != null) {
				if (info["live_cont"] != null) {
					var live_cont = info["live_cont"];
					for (i=0;i<live;i++) {
						var str = ""
						var info = live_cont[i]

						if (1 == i%2)
							str += "<tr class='cbi-rowstyle-odd'>"
						else
							str += "<tr class='cbi-rowstyle-even'>"
						for (j=0;j<info.length;j++) {
							str += "<td class='text-center'>" info[j] + "</td>"
						}
						$(table.live-section-table tbody).append(str)
					}
				}

				if (info["hist_cont"] != null) {
					var hist_cont = info["hist_cont"];
					for (i=0;i<live;i++) {
						var str = ""
						var info = hist_cont[i]

						if (1 == i%2)
							str += "<tr class='cbi-rowstyle-odd'>"
						else
							str += "<tr class='cbi-rowstyle-even'>"
						for (j=0;j<info.length;j++) {
							str += "<td class='text-center'>" info[j] + "</td>"
						}
						$(table.hist-section-table tbody).append(str)
					}
				}
			}
		}
	)
*/
}

function refresh_time(id, time_sec)
{
	var d = (Math.floor(time_sec / (3600 * 24)))
	var h = (Math.floor(time_sec / 3600) % 24)
	var m = (Math.floor((time_sec % 3600) / 60))
	var s = (Math.floor(time_sec % 60))

	var buff = ""
	if(d > 0 )
		buff = d + ' <%:d%> ' + h + ' <%:h%> ' + m + ' <%:m%> ' + s + ' <%:s%> ';
	else if(0 == d && h > 0)
		buff = h + ' <%:h%> ' + m + ' <%:m%> ' + s + ' <%:s%> ';
	else if(0 == d && 0 == h && m > 0)
		buff = m + ' <%:m%> ' + s + ' <%:s%> ';
	else
		buff = s + ' <%:s%>';

	document.getElementById(id).innerHTML = buff;
}

function sec_to_human(idprefix)
{
	var prefix = idprefix;
	for (var i = 1; ; i++)
	{
		if (document.getElementById(prefix+"-"+i) != null)
		{
			var old_sec =  document.getElementById(prefix+"-"+i).innerHTML;
			if (old_sec != 0)
				refresh_time(prefix+"-"+i, old_sec);
		}
		else
			break;
	}
}

$(document).ready(function() {
	/* Convert sec to human readable. */
	sec_to_human("live-sectohuman");
	sec_to_human("hist-sectohuman");

	$(".connfilter").keyup(function(e) {
		$(".no-result").remove();
		/* ignore tab. */
		var code = e.keyCode || e.which;
		if ("9" == code) {
			return;
		}

		var $input = $(this),
		inputContent = $input.val().toLowerCase(),
		$panel = $input.parents("#filter-id"),
		column = $panel.find("td").index($input.parents("td"))
		$table = $(".connlist").parent("tr"),
		$rows = $table;
		var $filteredRows = $rows.filter(function() {
			var value = $(this).find("td").eq(column).text().toLowerCase();
			return value.indexOf(inputContent) === -1;
		});
		$rows.show();
		$filteredRows.hide();
		if ($filteredRows.length === $rows.length) {
			$("#content-id").append($('<tr class="no-result"><td colspan="9"><%:No result found%></td></tr>'));
		}
	});

	get_list("auto");
});
</script>
<div>
<%
if #live_cont > 0 then
%>
<fieldset>
	<table>
		<colgroup>
			<col style="width:5%;"/>
			<col style="width:9%;"/>
			<col style="width:11%;"/>
			<col style="width:11%;"/>
			<col style="width:17%;"/>
			<col style="width:15%;"/>
			<col style="width:14%;"/>
			<col style="width:13%;"/>
			<col style="width:5%;"/>
		</colgroup>
		<tr>
			<th><%:Index%></th>
			<th><%:Username%></th>
			<th><%:IP Address%></th>
			<th><%:Gateway%></th>
			<th><%:Server Address%></th>
			<th><%:RX / TX Bytes%></th>
			<th><%:Login Time%></th>
			<th><%:Connection Time%></th>
			<th><div><button type="button" class="btn filter button-filter" onclick="filter_result()"><%:Filter%></button></div></th>
		</tr>
		<tr id="filter-id" style="display: none;">
			<td><input type="text" class="connfilter"/></td>
			<td><input type="text" class="connfilter"/></td>
			<td><input type="text" class="connfilter"/></td>
			<td><input type="text" class="connfilter"/></td>
			<td><input type="text" class="connfilter"/></td>
			<td><input type="text" class="connfilter"/></td>
			<td><input type="text" class="connfilter"/></td>
			<td><input type="text" class="connfilter"/></td>
			<td></td>
		</tr>
	</table>

	<table class="live-section-table">
		<colgroup>
			<col style="width:5%;"/>
			<col style="width:9%;"/>
			<col style="width:11%;"/>
			<col style="width:11%;"/>
			<col style="width:17%;"/>
			<col style="width:15%;"/>
			<col style="width:14%;"/>
			<col style="width:13%;"/>
			<col style="width:5%;"/>
		</colgroup>
		<tbody>
		<%
		if #live_cont > 0 then
			for k,v in ipairs(live_cont) do
				local str=""
				if 1 == k%2 then
					str=str.."<tr id='live-row-"..k.."' class='cbi-rowstyle-odd'"
				else
					str=str.."<tr id='live-row-"..k.."' class='cbi-rowstyle-even'"
				end
				str=str..">"
				for i,j in ipairs(v) do
					if 8 == i then
						str=str.."<td colspan='2' class='sectohuman text-center' id='live-sectohuman-"..k.."'>"..j.."</td>"
					else
						str=str.."<td class='text-center'>"..j.."</td>"
					end
				end
				write(str.."</tr>")
			end
		end%>
		</tbody>
	</table>
</fieldset>
<%
end
%>

<fieldset>
	<table>
		<colgroup>
			<col style="width:5%;"/>
			<col style="width:9%;"/>
			<col style="width:11%;"/>
			<col style="width:11%;"/>
			<col style="width:17%;"/>
			<col style="width:15%;"/>
			<col style="width:14%;"/>
			<col style="width:13%;"/>
			<col style="width:5%;"/>
		</colgroup>
		<tr>
			<th><%:Index%></th>
			<th><%:Username%></th>
			<th><%:IP Address%></th>
			<th><%:Gateway%></th>
			<th><%:Server Address%></th>
			<th><%:RX / TX Bytes%></th>
			<th><%:Login Time%></th>
			<th><%:Connection Time%></th>
			<th><div><button type="button" class="btn filter button-filter" onclick="filter_result()"><%:Filter%></button></div></th>
		</tr>
		<tr id="filter-id" style="display: none;">
			<td><input type="text" class="connfilter"/></td>
			<td><input type="text" class="connfilter"/></td>
			<td><input type="text" class="connfilter"/></td>
			<td><input type="text" class="connfilter"/></td>
			<td><input type="text" class="connfilter"/></td>
			<td><input type="text" class="connfilter"/></td>
			<td><input type="text" class="connfilter"/></td>
			<td><input type="text" class="connfilter"/></td>
			<td></td>
		</tr>
	</table>

	<table class="history-section-table">
		<colgroup>
			<col style="width:5%;"/>
			<col style="width:9%;"/>
			<col style="width:11%;"/>
			<col style="width:11%;"/>
			<col style="width:17%;"/>
			<col style="width:15%;"/>
			<col style="width:14%;"/>
			<col style="width:13%;"/>
			<col style="width:5%;"/>
		</colgroup>
		<tbody id="history-content-id">
		<%
		if #hist_cont > 0 then
			for k,v in ipairs(hist_cont) do
				local str=""
				if 1 == k%2 then
					str=str.."<tr id='hist-row-"..k.."' class='cbi-rowstyle-odd'"
				else
					str=str.."<tr id='hist-row-"..k.."' class='cbi-rowstyle-even'"
				end
				str=str..">"
				for i,j in ipairs(v) do
					if 8 == i then
						str=str.."<td colspan='2' class='sectohuman text-center' id='hist-sectohuman-"..k.."'>"..j.."</td>"
					else
						str=str.."<td class='text-center'>"..j.."</td>"
					end
				end
				write(str.."</tr>")
			end
		else
			write("<tr><td class='no-value' colspan='10'>"..translate("This section contains no records yet").."</td></tr>")
		end%>
		</tbody>
	</table>
	<button id="btn"><%:click%></button></button>
</fieldset>
</div>
<%+footer%>
