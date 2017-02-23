<div class="cbi-value<% if self.last_child then %> cbi-value-last<% end %>" <% if #self.deps > 0  then  %>style="display:none"<%end%> id="cbi-<%=self.config.."-"..section.."-"..self.option%>">

<div class="cbi-value-title"><label style="margin-left:<%=self.margin%>;"><%-=self.title or ""-%></label></div>
<div class="cbi-value-field" style="width:45%;">
<%-
	local value_list = {{[1]="1004",[2]="1",whole="1004::1"},{[1]="1003",[2]="1",whole="1003::1"},{[1]="SIPP-1",[2]="2",[3]="1001",whole="SIPP-1::2::1001"},{[1]="SIPP-2",[2]="1",[3]="1002",whole="SIPP-2::1::1002"},{[1]="SIPP-3",[2]="1",[3]="1003",whole="SIPP-3::1::1003"},{[1]="SIPP-4",[2]="2",[3]="1004",whole="SIPP-4::2::1004"},{[1]="SIPP-5",[2]="3",[3]="1005",whole="SIPP-5::3::1005"},{[1]="SIPP-6",[2]="2",[3]="1004",whole="SIPP-6::2::1004"},{[1]="SIPP-7",[2]="3",[3]="1005",whole="SIPP-7::3::1005"}}
	--local value_list = {{[1]="Deactivate",whole="Deactivate"}}
	--local value_list = {{[1]="1004",whole="1004"}}
	--local value_list = {{[1]="1004",[2]="1",whole="1004::1"}}
	--local value_list = {{[1]="SIPP-1",[2]="2",[3]="1003",whole="SIPP-1::2::1003"},{[1]="SIPP-2",[2]="3",[3]="1004",whole="SIPP-2::3::1004"}}

	self.f_keylist = {"Deactivate","1003","1004","SIPP-1","SIPP-2","SIPP-3","SIPP-4","SIPP-5","SIPP-6","SIPP-7"}
	self.f_vallist = {translate("Off"),"1003","1004","SIPP-1","SIPP-2","SIPP-3","SIPP-4","SIPP-5","SIPP-6","SIPP-7"}
	self.s_keylist = {"","1","2","3","addnew_profile_time/extension-sip-cfg18aa11-edit"}
	self.s_vallist = {translate("Alaway"),"1","2","3",translate("< Add New ...>")}
	self.id_vallist = {"SIPP-1","SIPP-2","SIPP-3","SIPP-4","SIPP-5","SIPP-6","SIPP-7"}
	--local value_list = self:cfgvalue(section);

	if "table" == type(value_list) then
		for k,v in pairs(value_list) do %>
		<div>
			<select class="cbi-input-select" style="width:28%;" size="1"<%=attr("id",cbid)..attr("name",cbid.."-select0")%>>
			<%- for i, key in pairs(self.f_keylist) do %>
				<option id="option0"<%=attr("value",key)..ifattr(v[1]==key,"selected","selected")%>><%=striptags(self.f_vallist[i])%></option>
			<%- end %>
			</select>
			<label <%=(v[1] and v[1] ~= "Deactivate") and '' or 'style="display:none;"'%>>&nbsp;</label>
			<select class="cbi-input-select" style="width:17%;<%=(v[1] and v[1] ~= "Deactivate") and "" or "display:none;"%>" size="1"<%=attr("id",cbid.."-select1."..k)%>>
			<%- for i, key in pairs(self.s_keylist) do %>
				<option id="option1"<%=attr("value",key)..ifattr(v[2]==key,"selected","selected")%>><%=striptags(self.s_vallist[i])%></option>
			<%- end %>
			</select>
			<%-
				local flag = false;
				if self.id_vallist then
					if type(self.id_vallist) == "string" then
						if v[1] == self.vallist then
							flag = true
						end
					elseif type(self.id_vallist) == "table" and next(self.id_vallist) then
						for _,j in pairs(self.id_vallist) do
							if v[1] == j then
								flag = true
							end
						end
					end
				end
				if flag then
			%>
			<label style="display:;">&nbsp;<%:Dest Number%>&nbsp;</label>
			<input class="cbi-input-text" type="text" style="width:16%;"<%=ifattr(v[3],"value",v[3])..attr("id",cbid.."-input."..k)..attr("name",cbid.."-input")%>>
			<%-else%>
			<label style="display:none;">&nbsp;<%:Dest Number%>&nbsp;</label>
			<input class="cbi-input-text" type="text" style="width:16%;display:none;"<%=attr("id",cbid.."-input."..k)..attr("name",cbid.."-input")%>>
			<%-end%>
			<input type="text" style="width:5%;display:none;"<%=ifattr(v["whole"],"value",v["whole"])..attr("name",cbid)%>>
		</div>
		<%-end
	elseif "nil" == type(value_list) then%>
		<div>
			<select class="cbi-input-select" style="width:28%;" size="1"<%=attr("id",cbid)..attr("name",cbid.."-select0")%>>
			<%- for i, key in pairs(self.f_keylist) do %>
				<option id="option0"<%=attr("value",key)%>><%=striptags(self.f_vallist[i])%></option>
			<%- end %>
			</select>
			<label style="display:none;">&nbsp;</label>
			<select class="cbi-input-select" style="width:17%;display:none;" size="1"<%=attr("id",cbid.."-select1.1")%>>
			<% for i, key in pairs(self.s_keylist) do -%>
				<option id="option1"<%=attr("value",key)%>><%=striptags(self.s_vallist[i])%></option>
			<%end%>
			</select>
			<label style="display:none;">&nbsp;<%:Dest Number%>&nbsp;</label>
			<input class="cbi-input-text" type="text" style="width:16%;display:none;"<%=attr("id",cbid.."-input.1")..attr("name",cbid.."-input")%>>
			<input type="text" style="width:5%;display:none;"<%=attr("name",cbid)%>>
		</div>
	<%-end
%>
</div>
<script type="text/javascript">

function cbi_callforwarding_init(name, respath, input_depends)
{
	function cbi_callforwarding_tip_check(name)
	{
		var grp = document.getElementsByName(name);
		if (grp.length > 0) {
			if (document.createEvent) {
				var et = document.createEvent("HTMLEvents");
				et.initEvent("blur", false, true);
				grp[0].dispatchEvent(et);
			} else if (document.createEventObject) {
				grp[0].fireEvent("onblur");
			}
		} else {
			var tip_obj = document.getElementById(name + ".tip");
			tip_obj.style.display = "none";
		}
	}

	function cbi_callforwarding_renumber()
	{
		var selobjs = document.getElementsByName(name);
		var options_len = selobjs[0].options.length;
		for (var i = 0; i < selobjs.length; i++) {
			var p = selobjs[i].parentNode;
			var c3 = p.childNodes[2];
			var c5 = p.childNodes[4];
			if (c3 && c3.nodeName.toLowerCase() == "select")
				c3.id = c3.id.replace(/\d+$/,i+1);
			if (c5 && c5.nodeName.toLowerCase() == "input")
				c5.id = c5.id.replace(/\d+$/,i+1);
			p.lastChild.src = respath + (((i+1) < selobjs.length || (i+1+deactivate_num) == options_len) ? '/cbi/remove.png' : '/cbi/add.png');
		}

		if(selobjs.length + deactivate_num < options_len) {
			var n = selobjs[selobjs.length-1].parentNode;

			if (selobjs.length > 1 && "img" != n.lastChild.previousSibling.nodeName.toLowerCase()) {
				var btn = document.createElement('img');
					btn.className = 'cbi-image-button';
					btn.src = respath + '/cbi/remove.png';

				n.insertBefore(btn, n.lastChild);
				cbi_bind(btn,        'click',    cbi_callforwarding_btnclick);
			}
			if (selobjs.length > 1 && "img" == n.lastChild.previousSibling.nodeName.toLowerCase()) {
				n.lastChild.previousSibling.src = respath + '/cbi/remove.png';
			}
			if (1 == selobjs.length && "img" == n.lastChild.previousSibling.nodeName.toLowerCase())
				n.removeChild(n.lastChild.previousSibling);
		}
	}

	function cbi_callforwarding_keydown(ev)
	{
		ev = ev ? ev : window.event;

		var se = ev.target ? ev.target : ev.srcElement;

		switch (ev.keyCode) {
			/* backspace, delete */
			case 8:
			case 46:
				var length = se.parentNode.children.length;
				var c5_name = se.childNodes[4].name != "null" ? se.childNodes[4].name : se.childNodes[4].name1;

				if (length > 1) {
					se.parentNode.removeChild(se);
					cbi_callforwarding_tip_check(c5_name);
					cbi_callforwarding_renumber();
				}
				break;

			/* enter */
			case 13:
				var selobjs = document.getElementsByName(name);
				var n = se.cloneNode(true);
				var c1 = n.firstChild;
				var c2 = c1.nextSibling;
				var c3 = c2.nextSibling;
				var c4 = c3.nextSibling;
				var c5 = c4.nextSibling;
				var c6 = c5.nextSibling;
				n.input_depends = input_depends;

				/* first child */
				var selected_index = 0;
				c1.options[c1.selectedIndex].removeAttribute("selected")
				for (var i = 0; i < selobjs.length; i++) {
					var index = selobjs[i].selectedIndex;
					selected_index |= 1 << index;
				}
				for (var i = 0; i < c1.options.length; i++) {
					if (c1.options[i].value == "Deactivate")
						selected_index |= 1 << i;
				}

				for (var i = 0; i < c1.options.length; i++) {
					if(!((1 << i) & selected_index)) {
						c1.options[i].selected = true;
						c1.options[i].defaultSelected = true;
						break;
					}
				}

				/* third child */
				c3.options[c3.selectedIndex].removeAttribute("selected")
				for (var i = 0; i < c3.options.length; i++) {
					if (c3.options[i].value != "") {
						c3.options[i].selected = true;
						c3.options[i].defaultSelected = true;
						break;
					}
				}
				cbi_bind(c3, 'change',   cbi_callforwarding_select1_update);
				cbi_bind(c3, 'click',   cbi_callforwarding_select1_update);

				/* forth,fifth child */
				var dp_c45 = false;
				c5.defaultValue = "";
				c5.value = "";
				c5.name1 = se.childNodes[4].name1;
				c5.className = c5.className.replace(/ cbi-input-invalid/g, "");
				if (input_depends && input_depends.length > 0) {
					for (var i = 0; i < n.input_depends.length; i++) {
						if (c1.value == n.input_depends[i]) {
							dp_c45 = true;
							break;
						}
					}
				}
				if (dp_c45) {
					c4.style.display = "";
					c5.name = c5.name1;
					c5.style.display = "";
					cbi_bind(c5, 'blur', cbi_callforwarding_input_update);
				} else {
					c4.style.display = "none";
					c5.name = null;
					c5.style.display = "none";
				}

				/* sixth child */
				c6.value = c1.value;
				if (c3.value && c3.value != "") {
					c6.value = c6.value + "::" + c3.value;
					if (c5.value && c5.value != "")
						c6.value = c6.value + "::" + c5.value;
				}

				/* remove img child*/
				if (se.lastChild.previousSibling.nodeName.toLowerCase() == "img")
					se.removeChild(se.lastChild);
				if (n.lastChild.nodeName.toLowerCase() == "img")
					n.removeChild(n.lastChild);
				if (n.lastChild.nodeName.toLowerCase() == "img")
					n.removeChild(n.lastChild);
				var img_obj = document.createElement('img');
				cbi_bind(img_obj, 'click', cbi_callforwarding_btnclick);
				n.appendChild(img_obj);

				/* append */
				se.parentNode.appendChild(n);

				/* bind */
				cbi_bind(c1, 'change',   cbi_callforwarding_select0_update);
				cbi_bind(c1, 'click',   cbi_callforwarding_select0_update);

				/* can do after appending*/
				if (dp_c45)
					cbi_validate_field(c5, false, "phonenumber");


				cbi_callforwarding_renumber();
				break;

			/* arrow up */
			case 38:
				break;

			/* arrow down */
			case 40:
				break;
		}

		return true;
	}

	function cbi_callforwarding_btnclick(ev)
	{
		ev = ev ? ev : window.event;

		var se = ev.target ? ev.target : ev.srcElement;

		if (se.src.indexOf('remove') > -1) { /*click del*/
			cbi_callforwarding_keydown({
				target:  se.parentNode,
				keyCode: 8
			});
		} else { /* click add*/
			cbi_callforwarding_keydown({
				target:  se.parentNode,
				keyCode: 13
			});
		}

		return false;
	}

	function cbi_callforwarding_update()
	{
		var objs = document.getElementsByName(name);
		for (var i = 0; i < objs.length; i++) {
			var n2 = objs[i].nextSibling.nextSibling;
			var p = objs[i].nextSibling.nextSibling.nextSibling;
			p.value = (objs[i].value && n2.value) ? objs[i].value + '::' + n2.value : '';
		}
	}

	function cbi_callforwarding_delete_text_node()
	{
		var s = document.getElementsByName(name);
		for (var i = 0; i < s.length; i++) {
			var p = s[i].parentNode;
			var c = p.firstChild;
			while (c) {
				var n = c.nextSibling;
				if (c.nodeName.toLowerCase() == "#text")
					p.removeChild(c);
				c = n;
			}
		}
	}

	function cbi_callforwarding_delete_invalid_node()
	{
		var selobjs = document.getElementsByName(name);
		var obj;
		for (var i=0; i < selobjs.length; i++) {
			if (selobjs[i].value == "Deactivate") {
				obj = selobjs[i].parentNode;
				break;
			}
		}
		if (!obj) {
			for (var i=0; i < selobjs.length; i++) {
				if (selobjs[i].nextSibling.nextSibling.value == "") {
					obj = selobjs[i].parentNode;
					break;
				}
			}
		}
		if (obj)
			cbi_callforwarding_delete_all_siblingnode(obj);
	}

	function cbi_callforwarding_delete_all_siblingnode(object)
	{
		if (object.parentNode.children.length > 1) {
			while (object.previousSibling)
				object.parentNode.removeChild(object.previousSibling);
			while (object.nextSibling)
				object.parentNode.removeChild(object.nextSibling);
		}
	}

	function cbi_callforwarding_display_c23(c3,flag)
	{
		if (flag) {
			if (c3.style.display == "none") {
				c3.value = "";
				c3.style.display = "";
				c3.previousSibling.style.display = "";
			}
		} else {
			if (c3.style.display == "") {
				c3.style.display = "none";
				c3.value = "";
				c3.previousSibling.style.display = "none";
			}
		}
	}

	function cbi_callforwarding_display_c45(c5,flag)
	{
		if (flag) {
			if (c5.style.display == "none") {

				c5.value = "";
				c5.name = c5.name1;
				c5.style.display = "";
				c5.previousSibling.style.display = "";
				cbi_bind(c5, 'blur', cbi_callforwarding_input_update);
				cbi_validate_field(c5, false, "phonenumber");
			}
		} else {
			if (c5.style.display == "") {
				var c = c5.cloneNode(true);
				var c5_name = c.name;

				c.name = null;
				c.name1 = c5.name1;
				c.style.display = "none";
				c.value = "";
				c.className = c.className.replace(/ cbi-input-invalid/g, "");
				c5.parentNode.replaceChild(c, c5);
				c.previousSibling.style.display = "none";
				cbi_callforwarding_tip_check(c5_name);
			}
		}
	}

	function cbi_callforwarding_display_img(parnode,flag)
	{
		if (flag) {
			var selobjs = document.getElementsByName(name);
			var option_len = selobjs[0].options.length;
			if (selobjs.length == 1 && selobjs.length < option_len && parnode.lastChild.nodeName.toLowerCase() != "img") {
				var btn = document.createElement('img');
				btn.className = 'cbi-image-button';
				btn.src = respath + '/cbi/add.png';
				parnode.appendChild(btn);
				cbi_bind(btn,'click',cbi_callforwarding_btnclick);
			}
		} else {
			if (parnode.lastChild.nodeName.toLowerCase() == "img")
				parnode.removeChild(parnode.lastChild);
			if (parnode.lastChild.nodeName.toLowerCase() == "img")
				parnode.removeChild(parnode.lastChild);
		}
	}

	function cbi_callforwarding_select0_update(ev)
	{
		ev = ev ? ev : window.event;
		var se = ev.target ? ev.target : ev.srcElement;
		var dp_c23_ = false;
		var dp_c45 = false;
		var dp_img = false;

		if (se.value == "Deactivate") {
			cbi_callforwarding_delete_all_siblingnode(se.parentNode);
			dp_c23 = false;
			dp_c45 = false;
			dp_img = false;
		} else {
			var input_depends = se.parentNode.input_depends;

			dp_c23 = true;
			if (input_depends && input_depends.length > 0) {
				for (var i = 0; i < input_depends.length; i++) {
					if (se.value == input_depends[i]) {
						dp_c45 = true;
						break;
					}
				}
			}
			if (se.nextSibling.nextSibling.value != "")
				dp_img = true;
		}

		cbi_callforwarding_display_c23(se.nextSibling.nextSibling, dp_c23);
		cbi_callforwarding_display_c45(se.nextSibling.nextSibling.nextSibling.nextSibling, dp_c45);
		cbi_callforwarding_display_img(se.parentNode, dp_img);
		cbi_callforwarding_whole_update(se.nextSibling.nextSibling.nextSibling.nextSibling.nextSibling);
	}

	function cbi_callforwarding_select1_update(ev)
	{
		ev = ev ? ev : window.event;
		var se = ev.target ? ev.target : ev.srcElement;
		var dp_img = false;

		if (se.value == "") {
			cbi_callforwarding_delete_all_siblingnode(se.parentNode);
			dp_img = false;
		} else {
			if (se.previousSibling.previousSibling.value != "Deactivate")
				dp_img = true;
		}

		cbi_callforwarding_display_img(se.parentNode, dp_img);
		cbi_callforwarding_whole_update(se.nextSibling.nextSibling.nextSibling);

		if (se.value.indexOf("addnew_") >= 0) {
			select_click(se.id);
		}
	}

	function cbi_callforwarding_input_update(ev)
	{
		ev = ev ? ev : window.event;

		var se = ev.target ? ev.target : ev.srcElement;
		cbi_callforwarding_whole_update(se.nextSibling)
	}

	function cbi_callforwarding_whole_update(obj)
	{
		var c1 = obj.parentNode.firstChild;
		var c3 = c1.nextSibling.nextSibling;
		var c5 = c3.nextSibling.nextSibling;

		if (c1.value == "Deactivate" || (c3.value == "" && c5.value == "")) {
			obj.value = c1.value;
		} else {
			if (c3.value.indexOf("addnew_") >= 0)
				obj.value = "";
			else if (c3.value == "" && c5.value != "")
				obj.value = c1.value + "::::" + c5.value;
			else if (c3.value != "" && c5.value == "")
				obj.value = c1.value + "::" + c3.vlaue;
			else
				obj.value = c1.value + "::" + c3.value + "::" + c5.value;
		}
	}

	cbi_callforwarding_delete_text_node();

	var deactivate_num = 1;
	var selobjs = document.getElementsByName(name);
	if (selobjs.length > 0)
		var options_len = document.getElementById(selobjs[selobjs.length-1].id).length;

	for (var i = 0; i < selobjs.length; i++) {
		var c1 = selobjs[i];
		var c3 = c1.nextSibling.nextSibling;
		var c5 = c3.nextSibling.nextSibling;

		if (selobjs.length != 1 || (c1.value != "Deactivate" && c3.value != "")) {
			var btn = document.createElement('img');
				btn.className = 'cbi-image-button';

			if(options_len > 1)
				btn.src = respath + ((((i+1) < selobjs.length) || ((i+1+deactivate_num) >= options_len))  ? '/cbi/remove.png' : '/cbi/add.png');
			cbi_bind(btn, 'click', cbi_callforwarding_btnclick);
			c1.parentNode.appendChild(btn);
		}
		c5.name1 = c5.name;
		c1.parentNode.input_depends = input_depends;
		/* select0 bind event */
		cbi_bind(c1, 'click', cbi_callforwarding_select0_update);
		/* select1 bind event */
		cbi_bind(c3, 'click', cbi_callforwarding_select1_update);
		/* input bind event */
		if (c5.style.display == "") {
			cbi_bind(c5, 'blur', cbi_callforwarding_input_update);
			cbi_validate_field(c5, false, "phonenumber");
		} else {
			c5.name = null;
		}
	}

	if(selobjs.length > 1 && selobjs.length + deactivate_num < options_len) {
		var btn = document.createElement('img');
			btn.className = 'cbi-image-button';
			btn.src = respath + '/cbi/remove.png';

		selobjs[selobjs.length-1].parentNode.insertBefore(btn, selobjs[selobjs.length-1].parentNode.lastChild);
		cbi_bind(btn,        'click',    cbi_callforwarding_btnclick);
	}
}

cbi_callforwarding_init("<%=cbid%>-select0","<%=resource%>", [
	<%-
		if self.id_vallist then
			if type(self.id_vallist) == "string" then -%>
				<%-=self.id_vallist-%>
		<%-
			elseif type(self.id_vallist) == "table" and next(self.id_vallist) then
				for k,v in pairs(self.id_vallist) do -%>
					"<%-=v-%>"
					<%-if k<#self.id_vallist then-%>,<%-end-%>
				<%- end
			end
		end
	-%>
]);
</script>

<div <%=attr("id", cbid.."-input.tip")%> class="cbi-input-tip" style="display:none;width:15%;margin-left:-10px;">
	<div style="display:table-cell;vertical-align:middle;">
		<%- local datatype_tip = require "luci.cbi.datatypes".get_datatypes_tip("phonenumber") %>
		<%=translate(tostring(datatype_tip))%>
	</div>
</div>

</div>
<% if #self.deps > 0 or #self.subdeps > 0 then -%>
	<script type="text/javascript" id="cbip-<%=self.config.."-"..section.."-"..self.option%>">
		<% for j, d in ipairs(self.subdeps) do -%>
			cbi_d_add("cbi-<%=self.config.."-"..section.."-"..self.option..d.add%>", {
		<%-
			for k,v in pairs(d.deps) do
				local depk
				if k:find("!", 1, true) then
					depk = string.format('"%s"', k)
				elseif k:find(".", 1, true) then
					depk = string.format('"cbid.%s"', k)
				else
					depk = string.format('"cbid.%s.%s.%s"', self.config, section, k)
				end
		-%>
			<%-= depk .. ":" .. string.format("%q", v)-%>
			<%-if next(d.deps, k) then-%>,<%-end-%>
		<%-
			end
		-%>
			}, "cbip-<%=self.config.."-"..section.."-"..self.option..d.add%>");
		<%- end %>
		<% for j, d in ipairs(self.deps) do -%>
			cbi_d_add("cbi-<%=self.config.."-"..section.."-"..self.option..d.add%>", {
		<%-
			for k,v in pairs(d.deps) do
				local depk
				if k:find("!", 1, true) then
					depk = string.format('"%s"', k)
				elseif k:find(".", 1, true) then
					depk = string.format('"cbid.%s"', k)
				else
					depk = string.format('"cbid.%s.%s.%s"', self.config, section, k)
				end
		-%>
			<%-= depk .. ":" .. string.format("%q", v)-%>
			<%-if next(d.deps, k) then-%>,<%-end-%>
		<%-
			end
		-%>
			}, "cbip-<%=self.config.."-"..section.."-"..self.option..d.add%>");
		<%- end %>
	</script>
<%- end %>
