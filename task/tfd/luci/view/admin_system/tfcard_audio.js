<%+header%>

<%
	local fs = require "luci.fs"
	local util = require "luci.util"
%>

<style type="text/css">
.icon-btn-upload {
	background-color: #3498db;
	display: inline-block;
	vertical-align: middle;
	position: relative;
	padding: 0 12px;
	height: 30px;
	margin: 0 0 0 10px;
	border-radius: 4px;
}
.html5-uploader-ctrl-fld {
	opacity: 0;
	filter:alpha(opacity=0);/*IE 6-8*/
	overflow: hidden;
	cursor: pointer;
	position: absolute;
	left: 0;
	top: 0;
}
.text {
	display: inline-block;
	height: 30px;
	line-height: 30px;
	font-weight: 100;
	color: #FFF;
	vertical-align: top;
	padding: 0;
	font-size: 14px;
}
.cbi-rowstyle-odd {
	background-color: #f3f4eb;
}
.cbi-rowstyle-even {
	background-color: #ECECD7;
}

</style>

<script type="text/javascript" src="<%=resource_cbi_js%>"></script>
<script type="text/javascript" src="<%=resource%>/jquery-1.9.1.min.js"></script>
<script type="text/javascript" src="/luci-static/resources/audio.min.js"></script>
<script type="text/javascript">

	$("document").ready(function(){
		$("#upload").change(function(){
			var upload_file = document.getElementById("upload").files;
			var max_size = <%=max_size%>;

			if (upload_file[0].size >= max_size)
			{
				alert("File size is too large,can not upload!");
			}
			else
			{
				upload_waiting()

				node = document.createElement("input");
				node.name = "cur_dir";
				node.value = "<%=cur_dir%>"

				node2 = document.createElement("input");
				node2.name = "file_upload";
				node2.value = "1";

				form2.insertBefore(node.cloneNode(),form2.firstChild);
				form2.insertBefore(node2.cloneNode(),form2.firstChild);

				form2.submit();
				form2.removeChild(form2.cur_dir);
				form2.removeChild(form2.file_upload);
			}
		})
	})

	function action_delete(obj)
	{
		if (confirm("<%:Please confirm whether to delete .%>")) {
			node = document.createElement("input");
			node.name = "cur_dir";
			node.value = "<%=cur_dir%>";

			node2 = document.createElement("input");
			node2.name = "file_delete";
			node2.value = obj.value;

			form1.appendChild(node.cloneNode());
			form1.appendChild(node2.cloneNode());

			form1.submit();
			form1.removeChild(form1.file_delete);
			form1.removeChild(form1.cur_dir);
		}
	}
	function action_sound(obj)
	{
		a1[0].load("<%=REQUEST_URI%>?cur_dir=<%=cur_dir%>&&sound_name=test1.mp3");
		a1[0].play();
	}
	function action_download(obj)
	{
		node = document.createElement("input");
		node.name = "cur_dir";
		node.value = "<%=cur_dir%>";

		node2 = document.createElement("input");
		node2.name = "file_download";
		if (obj.value)
		{
			node2.value = obj.value;
		}
		else
		{
			node2.value = obj;
		}

		form1.appendChild(node.cloneNode());
		form1.appendChild(node2.cloneNode());

		form1.submit();
		form1.removeChild(form1.file_download);
		form1.removeChild(form1.cur_dir);
	}
	function action_new(obj)
	{
		node = document.createElement("input");
		node.name = "cur_dir";
		node.value = "<%=cur_dir%>";

		form3.appendChild(node.cloneNode());

		form3.submit();
		form3.removeChild(form3.cur_dir);
	}
	function action_change(param)
	{
		node = document.createElement("input");
		node.name = "cur_dir";
		node.value = "<%=cur_dir%>";

		node2 = document.createElement("input");
		node2.name = "change_dir";
		node2.value = param;

		form1.appendChild(node.cloneNode());
		form1.appendChild(node2.cloneNode());

		form1.submit();
		form1.removeChild(form1.change_dir);
		form1.removeChild(form1.cur_dir);
	}
	function action_light(obj)
	{
		obj.style['background-color']="#FFFAFA";
	}
	function action_normal(obj)
	{
		obj.style['background-color']="rgb(222, 222, 222)";
	}
	function refresh_filenew(id)
	{
		var tmp_val = document.getElementById(id).value;
		if (tmp_val && tmp_val != "")
		{
			document.getElementById('file_new').disabled = "";
		}
		else
		{
			document.getElementById('file_new').disabled = "disabled";
		}
	}
	function action_goto(param)
	{
		node = document.createElement("input");
		node.name = "goto_dir";
		node.value = param;

		form1.appendChild(node.cloneNode());

		form1.submit();
		form1.removeChild(form1.goto_dir);
	}

	function upload_waiting()
	{
		$("#tupload").text("<%:Uploading...%>");
	}
	var a = audiojs;
	var a1;
	a.events.ready(function() {
		a1 = a.createAll();
	});
</script>

<form name="form1" method="post" action="<%=REQUEST_URI%>" enctype="multipart/form-data" style="margin-bottom: 0px;" onsubmit="return true">
	<!--for button post-->
</form>

<h2><a id="content" name="content"><%:System / Mobile Storage %></a></h2>
<fieldset>
	<div>
<%- if util.exec("mount"):match("on /mnt/mmcblk0p1") then %>
		<a hidden width="70%" name="cur_dir" id="cur_dir" value="<%=cur_dir%>" ><%=cur_dir%></a>
		<span style="position:relative;z-index:0;">
			<a href="javascript:void(0);" class="icon-btn-upload" id="aupload" style="float:right">
				<span class="text" id="tupload" ><%:Upload File%></span>
				<form name="form2" method="post" action="<%=REQUEST_URI%>" enctype="multipart/form-data" style="margin-bottom: 0px;" onsubmit="return true">
					<input style="float:right;width:95px;height:30px;" class="html5-uploader-ctrl-fld"  accept="*/*" type="file" name="upload" id="upload" />
				</form >
			</a>
		</span>
		<form name="form3" method="post" action="<%=REQUEST_URI%>" enctype="multipart/form-data" style="margin-bottom: 0px;" onsubmit="return true">
			<input style="float:right;" disabled class="cbi-button top-button" onclick="action_new(this);" type="button" name="file_new" id="file_new" value="<%:New Folder%>" />
			<input style="float:right;margin-right:10px;" onkeyup="refresh_filenew(this.id)" class="cbi-input-text" type="text" name="folder_name" id="folder_name" />
		</form>
		<form name="form4" method="post" action="<%=REQUEST_URI%>" enctype="multipart/form-data" style="margin-bottom: 0px;" onsubmit="return true">
			<input class="cbi-button" type="submit" id="safe_popup" name="safe_popup" value="<%:Safe Popup%>" />
			<a style="margin-left:10%;"><%:Total Size:%><%= total_size or " " %>&nbsp;&nbsp;&nbsp;&nbsp;<%:Available Size:%><%= available_size or " "%></a>
		</form>
		<br />
		<span>
		<%- if cur_dir ~= "" then %>
			<a onclick='action_change("..");return false;' href='javascript:void(0);'><%:Parent Directory%></a>&nbsp;|&nbsp;
		<%- end %>
			<a onclick='action_goto("/");return false;' href='javascript:void(0);'><%: All Files%></a>
		<%-
			local tmp_tb = util.split(cur_dir,"/")
			local dir_str = ""

			for k,v in ipairs(tmp_tb) do
				if v and v ~= "" then
					dir_str = dir_str.."/"..v
					if k == #tmp_tb then %>
			&nbsp;>&nbsp;<%=v%>
					<%- else %>
			&nbsp;>&nbsp;<a onclick='action_goto("<%=dir_str%>");return false;' href='javascript:void(0);'><%=v%></a>
					<%- end
				end
			end %>
		</span>
<%- else %>
	<div class="alert-message warning">
		<h4><%:Failed to check out the mobile storage device%></h4>
	</div>
<%- end %>
	</div>
</fieldset>
<%- if util.exec("mount"):match("on /mnt/mmcblk0p1") then %>
<fieldset id="tf_content" class="cbi-section">
	<table id="show-table" >
		<tbody>
			<tr>
				<th width="50%"><%:File Name%></th>
				<th width="20%"><%:File Size%></th>
				<th width="20%"><%:Modify Time%></th>
				<th width="10%"><%:Action%></th>
			</tr>
			<!--tfcard file-->
<%-
	for k,v in ipairs(file_content or {}) do
		if v and v.file_name and v.file_type and v.size and v.mtime then %>
			<tr style="background-color:rgb(222, 222, 222)" onmousemove="action_light(this)" onmouseout="action_normal(this)">
			<%- if v.file_type == "directory" then %>
				<td style="text-align:left;"><img alt="Directory" src="/luci-static/resources/cbi/folder.gif" /><a onclick="action_change('<%=v.file_name%>');return false;" href="javascript:void(0);" value="<%=v.file_name%>"><%=v.file_name%></a></td>
			<%- else %>
				<td style="text-align:left;"><img alt='File' src='/luci-static/resources/cbi/file.gif' /><a onclick="action_download('<%=v.file_name%>');return false;" href="javascript:void(0);" value="<%=v.file_name%>"><%=v.file_name%></a></td>
			<%- end %>
				<td><%=v.size%></td>
				<td><%=v.mtime%></td>
				<td>
					<input type="image" value="<%=v.file_name%>" name="<%=v.file_type%>" onclick="action_delete(this)" title="Delete" src="/luci-static/resources/cbi/remove.png"></input>
				<%- if v.file_type == "file" then %>
					<input type="image" value="<%=v.file_name%>" onclick="action_download(this)" title="Download" src="/luci-static/resources/cbi/download.gif"></input>
				<%- else %>
					<label style="padding:0 0 0 13px;">&nbsp;</label>
				<%- end %>
				</td>
			</tr>
<%-	end end %>
		</tbody>
	</table>
</fieldset>
<% end %>
<audio src="<%=REQUEST_URI%>?cur_dir=<%=cur_dir%>&&sound_name=test1.mp3" preload="auto"></audio>
<input type="image" onclick="action_sound(this)" title="Download" src="/luci-static/resources/cbi/download.gif"></input>

<%+footer%>
