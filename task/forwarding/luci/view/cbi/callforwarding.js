<div class="cbi-value<% if self.last_child then %> cbi-value-last<% end %>" <% if #self.deps > 0  then  %>style="display:none"<%end%> id="cbi-<%=self.config.."-"..section.."-"..self.option%>">

<div class="cbi-value-title"><label style="margin-left:<%=self.margin%>;"><%-=self.title or ""-%></label></div>
<div class="cbi-value-field" style="width:45%;">
<<<<<<< HEAD
<%
	--local value_list = {{[1]="1004",[2]="1",whole="1004::1"},{[1]="1003",[2]="1",whole="1003::1"},{[1]="SIPP-1",[2]="2",[3]="1001",whole="SIPP-1::2::1001"},{[1]="SIPP-2",[2]="1",[3]="1002"},{[1]="SIPP-3",[2]="1",[3]="1003",whole="SIPP-3::1::1003"},{[1]="SIPP-4",[2]="2",[3]="1004",whole="SIPP-4::2::1004"},{[1]="SIPP-5",[2]="3",[3]="1005",whole="SIPP-5::3::1005"}}
	local value_list = {{[1]="Deactivate",whole="Deactivate"}}
	local value_list = {{[1]="1004",whole="1004"}}
	--local value_list = {{[1]="1004",[2]="1",whole="1004::1"}}

	self.f_keylist = {"Deactivate","1003","1004","SIPP-1","SIPP-2","SIPP-3","SIPP-4","SIPP-5","SIPP-6","SIPP-7"}
	self.f_vallist = {translate("Off"),"1003","1004","SIPP-1","SIPP-2","SIPP-3","SIPP-4","SIPP-5","SIPP-6","SIPP-7"}
	self.s_keylist = {"1","2","3",""}
	self.s_vallist = {"1","2","3",translate("Alaway")}
	--local value_list = self:cfgvalue(section);

	if "table" == type(value_list) then
		for k,v in pairs(value_list) do%>
		<div>
			<select class="cbi-input-select" style="width:115px;" size="1"<%=attr("id",cbid)..attr("name",cbid.."-select0")%>>
			<%- for i, key in pairs(self.f_keylist) do %>
				<option "option0"<%=attr("value",key)..ifattr(v[1]==key,"selected","selected")%>><%=striptags(self.f_vallist[i])%></option>
			<%- end %>
			</select>
			<%- if v[1] and v[1] ~= "Deactivate" then -%>
				<label style="display:;">
				</label><select class="cbi-input-select" style="width:75px;display:;" size="1"<%=attr("id",cbid.."-select1")%>>
				<%- for i, key in pairs(self.s_keylist) do %>
					<option id="option1"<%=attr("value",key)..ifattr(v[2]==key,"selected","selected")%>><%=striptags(self.s_vallist[i])%></option>
				<%- end %>
				</select><label style="display:;">
					&nbsp;<%:Dest Number%>
				</label><input class="cbi-input-text" type="text" style="width:5em;display:;"<%=ifattr(v[3],"value")..attr("id",cbid.."-input."..k)%>>
			<%- end -%>
			<input type="text" style="display:none;"<%=ifattr(v[whole],"value")..attr("name",cbid)%>>
		</div>
		<% end
	elseif "nil" == type(value_list) then%>
		<div <%=attr("class",cbid.."-class")%>><select class="cbi-input-select" style="width:115px;" onclick="return true;" onchange="return true;"<%=attr("id",cbid)..attr("name",cbid.."-select0.1")..ifattr(self.size,"size")%>>
			<% for i, key in pairs(self.f_keylist) do -%>
			<option id="select0"<%=attr("value",key)%>><%=striptags(self.f_vallist[i])%></option>
			<%end%>
			</select>&nbsp;<span><select class="cbi-input-select" style="width:75px;" onchange="return true;"<%=attr("id",cbid.."-select1.1")..attr("name",cbid.."-select1.1")..ifattr(self.size,"size")%>>
=======
<%-
	--local value_list = {{[1]="1004",[2]="1",whole="1004::1"},{[1]="1003",[2]="1",whole="1003::1"},{[1]="SIPP-1",[2]="2",[3]="1001",whole="SIPP-1::2::1001"},{[1]="SIPP-2",[2]="1",[3]="1002"},{[1]="SIPP-3",[2]="1",[3]="1003",whole="SIPP-3::1::1003"},{[1]="SIPP-4",[2]="2",[3]="1004",whole="SIPP-4::2::1004"},{[1]="SIPP-5",[2]="3",[3]="1005",whole="SIPP-5::3::1005"}}
	--local value_list = {{[1]="Deactivate",whole="Deactivate"}}
	--local value_list = {{[1]="1004",whole="1004"}}
	--local value_list = {{[1]="1004",[2]="1",whole="1004::1"}}
	local value_list = {{[1]="SIPP-1",[2]="2",[3]="1003",whole="SIPP-1::2::1003"},{[1]="SIPP-2",[2]="3",[3]="1004",whole="SIPP-2::3::1004"}}

	self.f_keylist = {"Deactivate","1003","1004","SIPP-1","SIPP-2","SIPP-3","SIPP-4","SIPP-5","SIPP-6","SIPP-7"}
	self.f_vallist = {translate("Off"),"1003","1004","SIPP-1","SIPP-2","SIPP-3","SIPP-4","SIPP-5","SIPP-6","SIPP-7"}
	self.s_keylist = {"","1","2","3"}
	self.s_vallist = {translate("Alaway"),"1","2","3"}
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
			<select class="cbi-input-select" style="width:17%;<%=(v[1] and v[1] ~= "Deactivate") and "" or "display:none;"%>" size="1"<%=attr("id",cbid.."-select1")%>>
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
			<input type="text" style="display:;width:5%;"<%=ifattr(v["whole"],"value",v["whole"])..attr("name",cbid)%>>
		</div>
		<%-end
	elseif "nil" == type(value_list) then%>
		<div <%=attr("class",cbid.."-class")%>><select class="cbi-input-select" style="width:28%;" onclick="return true;" onchange="return true;"<%=attr("id",cbid)..attr("name",cbid.."-select0.1")..ifattr(self.size,"size")%>>
			<% for i, key in pairs(self.f_keylist) do -%>
			<option id="select0"<%=attr("value",key)%>><%=striptags(self.f_vallist[i])%></option>
			<%end%>
			</select>&nbsp;<span><select class="cbi-input-select" style="width:17%;" onchange="return true;"<%=attr("id",cbid.."-select1.1")..attr("name",cbid.."-select1.1")..ifattr(self.size,"size")%>>
>>>>>>> feature/eat
			<% for i, key in pairs(self.s_keylist) do -%>
			<option id="select1"<%=attr("value",key)%>><%=striptags(self.s_vallist[i])%></option>
			<%end%>
			</select></span><span<%=attr("id",cbid.."-span.1")%>>&nbsp;&nbsp;<%:Dest Number%>&nbsp;<input class="cbi-input-text" type="text" style="width:5em;"<%=attr("id",cbid.."-input.1")..attr("name",cbid.."-input.1")%>/>
		</span><br/></div>
<<<<<<< HEAD
	<% end %>
</div>
<script type="text/javascript">

function cbi_callforwarding_init(name, respath)
{
	function cbi_callforwarding_renumber(delete_img)
=======
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

	function cbi_callforwarding_input_check(v)
	{
		ev = ev ? ev : window.event;
		var se = ev.target ? ev.target : ev.srcElement;
		if (se.flag && cbi_validators["phonenumber"]) {
		}
	}

	function cbi_callforwarding_renumber()
>>>>>>> feature/eat
	{
		var selobjs = document.getElementsByName(name);
		var options_len = selobjs[0].options.length;
		for (var i = 0; i < selobjs.length; i++) {
			var p = selobjs[i].parentNode;
			var c5 = p.childNodes[4];
			if (c5 && c5.nodeName.toLowerCase() == "input")
				c5.id = c5.id.replace(/\d+$/,i+1);
<<<<<<< HEAD
			if (delete_img != true) {
				p.lastChild.src = respath + (((i+1) < selobjs.length || (i+1) == options_len) ? '/cbi/remove.png' : '/cbi/add.png');
			} else {
				if (p.lastChild.nodeName.toLowerCase() == "img")
					p.removeChild(p.lastChild);
				if (p.lastChild.nodeName.toLowerCase() == "img")
					p.removeChild(p.lastChild);
			}
		}

		if(delete_img != true && selobjs.length < options_len) {
			var n = selobjs[selobjs.length-1].parentNode;

			if(selobjs.length > 1 && "img" != n.lastChild.previousSibling.nodeName.toLowerCase()) {
=======
			p.lastChild.src = respath + (((i+1) < selobjs.length || (i+1) == options_len) ? '/cbi/remove.png' : '/cbi/add.png');
		}

		if(selobjs.length < options_len) {
			var n = selobjs[selobjs.length-1].parentNode;

			if (selobjs.length > 1 && "img" != n.lastChild.previousSibling.nodeName.toLowerCase()) {
>>>>>>> feature/eat
				var btn = document.createElement('img');
					btn.className = 'cbi-image-button';
					btn.src = respath + '/cbi/remove.png';

				n.insertBefore(btn, n.lastChild);
<<<<<<< HEAD

				cbi_bind(btn,        'click',    cbi_callforwarding_btnclick);
			}
			if(selobjs.length > 1 && "img" == n.lastChild.previousSibling.nodeName.toLowerCase()) {
				n.lastChild.previousSibling.src = respath + '/cbi/remove.png';
			}
			if(1 == selobjs.length && "img" == n.lastChild.previousSibling.nodeName.toLowerCase())
				n.removeChild(n.lastChild.previousSibling);

		}
	}

	function cbi_callforwarding_keypress(ev)
	{
		ev = ev ? ev : window.event;

		var se = ev.target ? ev.target : ev.srcElement;

		if (se.nodeType == 3)
			se = se.parentNode;

		switch (ev.keyCode) {
			/* backspace, delete */
			case 8:
			case 46:
				if (se.value.length == 0)
				{
					if (ev.preventDefault)
						ev.preventDefault();

					return false;
				}

				return true;

			/* enter, arrow up, arrow down */
			case 13:
			case 38:
			case 40:
				if (ev.preventDefault)
					ev.preventDefault();

				return false;
		}

		return true;
=======
				cbi_bind(btn,        'click',    cbi_callforwarding_btnclick);
			}
			if (selobjs.length > 1 && "img" == n.lastChild.previousSibling.nodeName.toLowerCase()) {
				n.lastChild.previousSibling.src = respath + '/cbi/remove.png';
			}
			if (1 == selobjs.length && "img" == n.lastChild.previousSibling.nodeName.toLowerCase())
				n.removeChild(n.lastChild.previousSibling);
		}
>>>>>>> feature/eat
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
<<<<<<< HEAD

				if (length > 1) {
					se.parentNode.removeChild(se);

=======
				var c5_name = se.childNodes[4].name != "null" ? se.childNodes[4].name : se.childNodes[4].name1;

				if (length > 1) {
					se.parentNode.removeChild(se);
					cbi_callforwarding_tip_check(c5_name);
>>>>>>> feature/eat
					cbi_callforwarding_renumber();
				}
				break;

			/* enter */
			case 13:
<<<<<<< HEAD
				var n = se.cloneNode(true);

				var selobjs = document.getElementsByName(name);
				var selobj = document.getElementById(selobjs[selobjs.length-1].id);

				/* first child */
				var c1 = n.firstChild;
				var selected_index = 0;
				var selected_index1 = 0;
=======
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
>>>>>>> feature/eat
				for (var i = 0; i < selobjs.length; i++) {
					var index = selobjs[i].selectedIndex;
					selected_index |= 1 << index;
				}
				for (var i = 0; i < c1.options.length; i++) {
					if (c1.options[i].value == "Deactivate")
<<<<<<< HEAD
						selected_index1 |= 1 << i;
				}
				selected_index |= selected_index1;

				var selected_setflag = 0;

				for (var i = 0; i < selobj.length; i++) {
					if(0 == selected_setflag && !((1 << i) & selected_index)) {
						var div_tmp = document.createElement("div");
						div_tmp.innerHTML="<select><option value="+selobj.options[i].value+" selected>"+selobj.options[i].text+"</select>"
						c1.replaceChild(div_tmp.firstChild.firstChild,c1.options[i])
						c1.options[i].id = selobj.options[i].id;
						selected_setflag = 1;
					} else {
						c1.options[i] = new Option(selobj.options[i].text, selobj.options[i].value);
						c1.options[i].id = selobj.options[i].id;
					}
				}
				cbi_bind(c1, 'change',   cbi_callforwarding_select0_update);
				cbi_bind(c1, 'click',   cbi_callforwarding_select0_update);

				/* third child */
				var c3 = c1.nextSibling.nextSibling;
				for (var i = 0; i < c3.options.length; i++) {
					if (c3.options[i].value != "") {
						c3.value = c3.options[i].value;
=======
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
>>>>>>> feature/eat
						break;
					}
				}
				cbi_bind(c3, 'change',   cbi_callforwarding_select1_update);
				cbi_bind(c3, 'click',   cbi_callforwarding_select1_update);

<<<<<<< HEAD
				/* fifth child */
				var c5 = c3.nextSibling.nextSibling;
				c5.value = "";

				/* sixth child */
				var c6 = c5.nextSibling.nextSibling;
=======
				/* forth,fifth child */
				c5.defaultValue = "";
				c5.value = "";
				c5.name = n.childNodes[4].name;
				c5.name1 = n.childNodes[4].name1 != "null" ? n.childNodes[4].name1 : n.childNodes[4].name;
				c5.className = c5.className.replace(/ cbi-input-invalid/g, "");

				/* sixth child */
>>>>>>> feature/eat
				c6.value = c1.value;
				if (c3.value && c3.value != "") {
					c6.value = c6.value + "::" + c3.value;
					if (c5.value && c5.value != "")
						c6.value = c6.value + "::" + c5.value;
				}

				/* remove img child*/
				if (se.lastChild.previousSibling.nodeName.toLowerCase() == "img")
					se.removeChild(se.lastChild);
<<<<<<< HEAD
				if (n.lastChild.previousSibling.nodeName.toLowerCase() == "img")
					n.removeChild(n.lastChild);
				cbi_bind(n.lastChild,        'click',    cbi_callforwarding_btnclick);
=======
				if (n.lastChild.nodeName.toLowerCase() == "img")
					n.removeChild(n.lastChild);
				if (n.lastChild.nodeName.toLowerCase() == "img")
					n.removeChild(n.lastChild);
				var img_obj = document.createElement('img');
				cbi_bind(img_obj, 'click', cbi_callforwarding_btnclick);
				n.appendChild(img_obj);
>>>>>>> feature/eat

				/* append */
				se.parentNode.appendChild(n);

<<<<<<< HEAD
				/*
				var dt = se.nextSibling.nextSibling.nextSibling.getAttribute('cbi_datatype');
				var op = se.nextSibling.nextSibling.nextSibling.getAttribute('cbi_optional') == 'true';

				if (dt)
					cbi_validate_field(p, op, dt);

				cbi_bind(n1,'change',   cbi_dyndblsellist_update);
				cbi_bind(n2,'change',   cbi_dyndblsellist_update);
				cbi_dyndblsellist_update();
				*/
=======
				/* bind */
				cbi_bind(c1, 'change',   cbi_callforwarding_select0_update);
				cbi_bind(c1, 'click',   cbi_callforwarding_select0_update);
				cbi_bind(c5, 'blur', cbi_callforwarding_input_update);
				cbi_validate_field(c5, false, "phonenumber");

				/* can do after appending*/
				var dp_c45 = false;
				if (input_depends && input_depends.length > 0) {
					for (var i = 0; i < n.input_depends.length; i++) {
						if (c1.value == n.input_depends[i]) {
							dp_c45 = true;
							break;
						}
					}
				}
				cbi_callforwarding_display_c45(c5, dp_c45);

>>>>>>> feature/eat
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

<<<<<<< HEAD
	function cbi_callforwarding_cleartextnode()
=======
	function cbi_callforwarding_delete_text_node()
>>>>>>> feature/eat
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

<<<<<<< HEAD
	function cbi_callforwarding_cleardivnode()
=======
	function cbi_callforwarding_delete_invalid_node()
>>>>>>> feature/eat
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
<<<<<<< HEAD

=======
>>>>>>> feature/eat
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
<<<<<<< HEAD

		}
		cbi_callforwarding_renumber(true);
=======
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
				c5.name = c5.name1 != "null" ? c5.name1 : c5.name;
				c5.style.display = "";
				c5.previousSibling.style.display = "";
				cbi_bind(c5, 'blur', cbi_callforwarding_input_update);
				cbi_validate_field(c5, false, "phonenumber");
			}
		} else {
			if (c5.style.display == "") {
				var c = c5.cloneNode(true);
				var c5_name = c.name;

				c.name1 = c.name;
				c.name = null;
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
>>>>>>> feature/eat
	}

	function cbi_callforwarding_select0_update(ev)
	{
		ev = ev ? ev : window.event;
<<<<<<< HEAD

		var se = ev.target ? ev.target : ev.srcElement;
		console.log("select0",se.value);
		cbi_callforwarding_whole_update(se.nextSibling.nextSibling.nextSibling.nextSibling.nextSibling)

		if (se.value == "Deactivate") {
			cbi_callforwarding_delete_all_siblingnode(se.parentNode);
		} else {
			var selobjs = document.getElementsByName(name);
			var option_len = selobjs[0].options.length;
			if (selobjs.length == 1 && selobjs.length < option_len) {
				var lastchild = se.parentNode.lastChild;
				if (lastchild.nodeName.toLowerCase() != "img") {
					var btn = document.createElement('img');

					btn.className = 'cbi-image-button';
					btn.src = respath + '/cbi/add.png';
					se.parentNode.appendChild(btn);
					cbi_bind(btn,'click',cbi_callforwarding_btnclick);
				}
			}
		}
=======
		var se = ev.target ? ev.target : ev.srcElement;
		var dp_c23_ = false;
		var dp_c45 = false;
		var dp_img = false;
		if (console_flag)
			console.log("select0",se.value);

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
>>>>>>> feature/eat
	}

	function cbi_callforwarding_select1_update(ev)
	{
		ev = ev ? ev : window.event;
<<<<<<< HEAD

		var se = ev.target ? ev.target : ev.srcElement;
		console.log("select1",se.value)
		cbi_callforwarding_whole_update(se.nextSibling.nextSibling.nextSibling)

		if (se.value == "") {
			cbi_callforwarding_delete_all_siblingnode(se.parentNode);
		} else {
			var selobjs = document.getElementsByName(name);
			var option_len = selobjs[0].options.length;
			if (selobjs.length == 1 && selobjs.length < option_len) {
				var lastchild = se.parentNode.lastChild;
				if (lastchild.nodeName.toLowerCase() != "img") {
					var btn = document.createElement('img');

					btn.className = 'cbi-image-button';
					btn.src = respath + '/cbi/add.png';
					se.parentNode.appendChild(btn);
					cbi_bind(btn,'click',cbi_callforwarding_btnclick);
				}
			}
		}

=======
		var se = ev.target ? ev.target : ev.srcElement;
		var dp_img = false;
		if (console_flag)
			console.log("select1",se.value);

		if (se.value == "") {
			cbi_callforwarding_delete_all_siblingnode(se.parentNode);
			dp_img = false;
		} else {
			if (se.previousSibling.previousSibling.value != "Deactivate")
				dp_img = true;
		}

		cbi_callforwarding_display_img(se.parentNode, dp_img);
		cbi_callforwarding_whole_update(se.nextSibling.nextSibling.nextSibling);
>>>>>>> feature/eat
	}

	function cbi_callforwarding_input_update(ev)
	{
		ev = ev ? ev : window.event;

		var se = ev.target ? ev.target : ev.srcElement;
<<<<<<< HEAD
		console.log("input",se.value)
=======
		if (console_flag)
			console.log("input",se.value);
>>>>>>> feature/eat
		cbi_callforwarding_whole_update(se.nextSibling)
	}

	function cbi_callforwarding_whole_update(obj)
	{
<<<<<<< HEAD
		console.log("whole",obj.value)
	}

	cbi_callforwarding_cleartextnode();

	var selobjs = document.getElementsByName(name);
	if(selobjs.length > 0)
		var options_len = document.getElementById(selobjs[selobjs.length-1].id).length;

	var child = selobjs[0];
	var sibling_count = child.parentNode.children.length;
	if (selobjs.length != 1 || ((sibling_count != 2 || child.value != "Deactivate") && ((sibling_count != 4 && sibling_count != 6) || child.nextSibling.nextSibling.value != ""))) {
		for (var i = 0; i < selobjs.length; i++) {
=======
		obj.value = obj.previousSibling.value;
		if (console_flag)
			console.log("whole",obj.value);
	}

	cbi_callforwarding_delete_text_node();

	var console_flag = true;
	var userAgent = navigator.userAgent;
	if (userAgent.indexOf("compatible") > -1 && userAgent.indexOf("MSIE") > -1)
		console_flag = false;
	var selobjs = document.getElementsByName(name);
	if (selobjs.length > 0)
		var options_len = document.getElementById(selobjs[selobjs.length-1].id).length;

	for (var i = 0; i < selobjs.length; i++) {
		var c1 = selobjs[i];
		var c3 = c1.nextSibling.nextSibling;
		var c5 = c3.nextSibling.nextSibling;

		if (selobjs.length != 1 || (c1.value != "Deactivate" && c3.value != "")) {
>>>>>>> feature/eat
			var btn = document.createElement('img');
				btn.className = 'cbi-image-button';

			if(options_len > 1)
				btn.src = respath + ((((i+1) < selobjs.length) || ((i+1) >= options_len))  ? '/cbi/remove.png' : '/cbi/add.png');
<<<<<<< HEAD

			selobjs[i].parentNode.appendChild(btn);
			cbi_bind(btn,        'click',    cbi_callforwarding_btnclick);
			/* select0 bind event */
			cbi_bind(selobjs[i], 'change',   cbi_callforwarding_select0_update);
			cbi_bind(selobjs[i], 'click',   cbi_callforwarding_select0_update);
			/* select1 bind event */
			cbi_bind(selobjs[i].nextSibling.nextSibling, 'change',   cbi_callforwarding_select1_update);
			cbi_bind(selobjs[i].nextSibling.nextSibling, 'click',   cbi_callforwarding_select1_update);
			/* input bind event */
			cbi_bind(selobjs[i].nextSibling.nextSibling.nextSibling.nextSibling, 'change',    cbi_callforwarding_input_update);
		}

		if(selobjs.length > 1 && selobjs.length < options_len) {
			var btn = document.createElement('img');
				btn.className = 'cbi-image-button';
				btn.src = respath + '/cbi/remove.png';

			selobjs[selobjs.length-1].parentNode.insertBefore(btn, selobjs[selobjs.length-1].parentNode.lastChild);
			cbi_bind(btn,        'click',    cbi_callforwarding_btnclick);
		}
	}
}

cbi_callforwarding_init('<%=cbid%>-select0','<%=resource%>');
</script>

<div <%=attr("id", cbid..".tip")%> class="cbi-input-tip" style="display:none;width:15%;margin-left:-10px;">
=======
			cbi_bind(btn, 'click', cbi_callforwarding_btnclick);
			c1.parentNode.appendChild(btn);
		}
		/* select0 bind event */
		cbi_bind(c1, 'change', cbi_callforwarding_select0_update);
		cbi_bind(c1, 'click', cbi_callforwarding_select0_update);
		/* select1 bind event */
		cbi_bind(c3, 'change', cbi_callforwarding_select1_update);
		cbi_bind(c3, 'click', cbi_callforwarding_select1_update);
		/* input bind event */
		cbi_bind(c5, 'blur', cbi_callforwarding_input_update);
		cbi_validate_field(c5, false, "phonenumber");
		c1.parentNode.input_depends = input_depends;
	}

	if(selobjs.length > 1 && selobjs.length < options_len) {
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
>>>>>>> feature/eat
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
