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
var access_state = "ready"
var tmp_access = ""
var starth = 1
var reqnumh = 20

function filter_result()
{
	$("#filter-id").toggle()
	if ("none" == $("#filter-id").css("display")) {
		access_state = tmp_access
		tmp_access = ""
	}
	else {
		tmp_access = access_state
		access_state = "halt"
	}
	keyup_event()
}

function keyup_event()
{
	$(".connfilter").val("")

	/* Simulate a keyup event. */
	var e = $.Event("keyup")
	e.which = 13
	$(".connfilter").trigger(e)
}

function transfer(param)
{

}

function get_list(param)
{
	if ("ready" == access_state)
	{
		access_state = "query"
		XHR.get('<%=luci.dispatcher.build_url("admin","affair","get_service_log")%>',{action:param,starth:starth,reqnumh:reqnumh},function(x, info)
		{
			if (info != null) {
				if (info["content"] != null) {
					var content = info["content"]
					var num = starth
					var raw

					for (i=0;i<content.length;i++) {
						var str = ""
						raw = content[i]

						if (1 == i%2)
							str += "<tr class='cbi-rowstyle-odd'>"
						else
							str += "<tr class='cbi-rowstyle-even'>"
						for (var j=0;j<3;j++) {
							str += "<td class='text-center'>"+raw[j]+"</td>"
						}
						str += "<td class='text-center connlist' colspan='2'>"+raw[3]+"</td>"
						$(".history-section-table tbody").append(str)
						num += 1
					}
					starth = num
					access_state = "ready"
				} else if (1 != starth) {
					$(".history-section-table tbody").append($("<tr><td colspan='5'><%:The End%></td></tr>"));
					access_state = "halt"
				}
				if ($(".history-section-table tbody").find("tr").length == 1)
					$(".history-section-table tbody").append($("<tr><td class='text-center' colspan='5'><%:This section contains no records yet%></td></tr>"));

				$(".div-table td").mouseover(function(e){
					var $input = $(this)
					var cont_w = $input[0].scrollWidth
					var vis_w = $input.outerWidth()
					if (cont_w > vis_w) {
						var $fieldset = $input.parents("fieldset")
						var column_name = $fieldset.find(".col-name").find("th").eq($input.index()).text()
						$("#popover-content").html(column_name+" : "+$input.text())
						$("#popover-content").show()
						$("#popover-content").offset({top:$(this).offset().top+30,left:$(this).offset().left-50})
					}
				})

				$(".div-table td").mouseout(function(e){
					$("#popover-content").html("")
					$("#popover-content").hide()
				})
			}
			$(".history-section-table tbody").find("#loading-id").remove()
		});
	}
}

$(document).ready(function() {
	$(".connfilter").keyup(function(e) {
		$(".no-result").remove();
		if (1 != starth) {
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
				$(".history-section-table tbody").append($("<tr class='no-result'><td colspan='5'><%:No result found%></td></tr>"));
			}
		}
	})

	$(".history-section-table").scroll(function(e) {
		if("ready" == access_state) {
			var cont_h = $(".history-section-table").get(0).scrollHeight
			var vis_h = $(".history-section-table").height()
			var scroll_y = $(".history-section-table").scrollTop()
			if (scroll_y == cont_h - vis_h) {
				$(".history-section-table tbody").append($("<tr id='loading-id'><td colspan='5'><img src='<%=resource%>/icons/loading.gif' alt='<%:Loading%>'/></td></tr>"));
				get_list("more")
			}
		}
	})

	$(".history-section-table tbody").append($("<tr id='loading-id'><td colspan='5'><img src='<%=resource%>/icons/loading.gif' alt='<%:Loading%>'/></td></tr>"));
	get_list("default")
});
</script>
<h2><a id="content" name="content">状态 / 服务状态日志</a></h2>
<fieldset>
	<table>
		<colgroup>
			<col style="width:5%;"/>
			<col style="width:20%;"/>
			<col style="width:15%;"/>
			<col style="width:53%;"/>
			<col style="width:7%;"/>
		</colgroup>
		<tr class="col-name">
			<th>编号</th>
			<th>时间</th>
			<th>服务</th>
			<th>状态</th>
			<th><button type="button" class="filter-btn" onclick="filter_result()"><%:Filter%></button></th>
		</tr>
		<tr id="filter-id" style="display: none;">
			<td><input type="text" class="connfilter"/></td>
			<td><input type="text" class="connfilter"/></td>
			<td><input type="text" class="connfilter"/></td>
			<td colspan="2"><input type="text" class="connfilter"/></td>
		</tr>
	</table>

	<div class="div-table history-section-table">
	<table>
		<colgroup>
			<col style="width:5%;"/>
			<col style="width:20%;"/>
			<col style="width:15%;"/>
			<col style="width:53%;"/>
			<col style="width:7%;"/>
		</colgroup>
		<tbody>
		</tbody>
	</table></div>
</fieldset>
<span id="popover-content" style="display:none;color:#a04112;background:#feffc6;padding:5px;"></span>
<%+footer%>
