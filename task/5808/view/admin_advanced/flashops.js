<%+header%>
<style type="text/css">
table td{
    text-align:left;
}
</style>
<% if "" ~= result then %>
	<div class='container container-msg' id='alert-msgbox'>
	<% if string.find(result,"Restore Succ") and not string.find(result,"fail") then %>
		<div class='alert-message success'>
		<h4><%= translate(result) %></h4>
		<%:Please reboot to take effect !%><br>
		<a href='<%=pcdata(luci.dispatcher.build_url('admin/system/reboot'))%>'>>><%:Go to reboot...%></a></div>
	<% elseif string.find(result,"apply fail") then %>
		<div class='alert-message error'>
		<h4><%= translate(result) %></h4>
		<%:Please check the config data is correct !%></div>
	<% elseif string.find(string.lower(result),"fail") then%>
		<div class='alert-message error'>
		<h4><%= translate(result) %></h4>
		<%:Please check the file is correct !%></div>
	<% end %>
	</div>
<% end %>
<script language="JavaScript" type="text/JavaScript">
function check()
{
	var mod = ['system', 'network', 'service'];
	var bkp_cnt = 0
	var rst_cnt = 0
	for(i = 0;i < 3;i++)
	{
		if(document.getElementById("backup."+mod[i]).checked)
			bkp_cnt++
		if(document.getElementById("reset."+mod[i]).checked)
			rst_cnt++
	}
	if(bkp_cnt > 0)
		document.getElementById("backup").disabled=""
	else
		document.getElementById("backup").disabled="disabled"
	if(rst_cnt > 0)
		document.getElementById("reset").disabled=""
	else
		document.getElementById("reset").disabled="disabled"
}
function set_btn_status(id)
{
	if (document.getElementById(id).value != "")
	{	if (id == "software" )
			document.getElementById("upgrade").disabled=""
		else
			document.getElementById("restore").disabled=""
	}
	else
	{
		if (id == "software")
			document.getElementById("upgrade").disabled="disabled"
		else
			document.getElementById("restore").disabled="disabled"
	}
}
function set_all_disabled(param)
{
	var tmr = window.setInterval(function() {
		var id = ['archive','restore','backup','reset']
		for(i = 0; i < 4;i++)
		{
			document.getElementById(id[i]).disabled=param
		}

		var id = ['system', 'network', 'service']
		for(i = 0;i < 3;i++)
		{
			document.getElementById("backup."+id[i]).disabled=param
			document.getElementById("reset."+id[i]).disabled=param
		}

		clearInterval(tmr)
	},500)
}
</script>
<h2><a id="content" name="content">高级 / 备份/恢复</a></h2>
<fieldset class="cbi-section">
	<% if true == restore_avail then %>
	<table id="sys_backup" >
		<tr>
			<form method="post" action="<%=REQUEST_URI%>" enctype="multipart/form-data">
				<td width="30%"><label><%:Choose backup files and download%></label></td>
				<td width="40%" style="visibility:hidden;">
					<input class="cbi-input-checkbox" type="checkbox" onclick="check()" id="backup.system"  name="backup.system" checked="checked" />
					<label for="cbid.backup.1"><%:System%></label>
					<input class="cbi-input-checkbox" type="checkbox" onclick="check()" id="backup.network" name="backup.network" checked="checked" />
					<label for="cbid.backup.2"><%:Network%></label>
					<input class="cbi-input-checkbox" type="checkbox" onclick="check()" id="backup.service" name="backup.service" checked="checked" />
					<label for="cbid.backup.3"><%:Service%></label>
				</td>
				<td width="30%">
					<input style="width:100px;" class="cbi-button" type="submit" name="backup" id="backup" value="<%:Download%>" />
				</td>
			</form>
		</tr>
		<tr>
			<form method="post" action="<%=REQUEST_URI%>" enctype="multipart/form-data">
				<td><label><%:Reset to defaults%></label></td>
				<td style="visibility:hidden;">
					<input class="cbi-input-checkbox" type="checkbox" onclick="check()" id="reset.system"  name="reset.system" checked="checked" />
					<label for="cbid.backup.1"><%:System%></label>
					<input class="cbi-input-checkbox" type="checkbox" onclick="check()" id="reset.network" name="reset.network" checked="checked"/>
					<label for="cbid.backup.2"><%:Network%></label>
					<input class="cbi-input-checkbox" type="checkbox" onclick="check()" id="reset.service" name="reset.service" checked="checked" />
					<label for="cbid.backup.3"><%:Service%></label>
				</td>
				<td>
					<input onclick="return confirm('<%:Really reset all changes?%>')" class="cbi-button " style="width:100px;" type="submit" id="reset" name="reset" value="<%:Reset%>" />
				</td>
			</form>
		</tr>
		<% if true == provision_avail then %>
		<tr>
			<form method="post" action="<%=REQUEST_URI%>" enctype="multipart/form-data">
				<td><label><%:Restore backup%></label></td>
				<td>
					<input type="file" name="archive" id="archive" onchange="set_btn_status(this.id)" />
				</td>
				<td>
					<input type="submit" class="cbi-button " style="width:100px;" name="restore" id="restore" onclick="set_all_disabled('disabled');return true" disabled="disabled" value="<%:Restore%>" />
				</td>
			</form>
		</tr>
		<% else %>
		<div class='container'><div class='alert-message error'><%:Upgrade Service stoped, restore is unavailable !%></div></div>
		<% end %>
	</table>
	<% else %>
	<div class='container'>
		<div class='alert-message error'>
			<%:Get device model or sn fail, Backup/Restore is unavailable !%>
		</div>
	</div>
	<% end %>
</fieldset>
<%+footer%>
