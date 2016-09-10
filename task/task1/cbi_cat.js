var cbi_d=[];
var cbi_t=[];
var cbi_c=[];
function ip2number(ip)
{
    var tokens=ip.split(".");
    var numval=0;
    for(var i=0;i<4;i++){
        numval=numval+parseInt(tokens[i])*(Math.pow(256,(3-i)))
    }
    return numval
}
var cbi_validators={
    "integer":function(v){
        return(v.match(/^-?[0-9]+$/)!=null)
    },
    "filename_extensions":function(v){
        if(v.length<=5&&v.match(/^\.[a-zA-Z0-9]+$/)){
            return true
        }else{
            return false
        }
    },
    "uinteger":function(v){
        return(cbi_validators.integer(v)&&(v>=0))
    },
    "float":function(v){
        return !isNaN(parseFloat(v))
    },
    "ufloat":function(v){
        return(cbi_validators["float"](v)&&(v>=0))
    },
    "ipaddr":function(v){
        return cbi_validators.ip4addr(v)||cbi_validators.ip6addr(v)
    },
    "neg_ipaddr":function(v){
        return cbi_validators.ip4addr(v.replace(/^\s*!/,""))||cbi_validators.ip6addr(v.replace(/^\s*!/,""))
    },
    "ip4addr":function(v){
        if(v.match(/^(\d+)\.(\d+)\.(\d+)\.(\d+)(\/(\d+))?$/)){
            return(RegExp.$1>=0)&&(RegExp.$1<255)&&(RegExp.$2>=0)&&(RegExp.$2<255)&&(RegExp.$3>=0)&&(RegExp.$3<255)&&(RegExp.$4>=0)&&(RegExp.$4<255)&&(!RegExp.$5||((RegExp.$6>=0)&&(RegExp.$6<=32)))
        }
        return false
    },
    "abc_ip4addr":function(v,exception){
        var str=""+exception;
        str=str.split("&");
        for(var i=0;i<str.length;i++){
            if(v==str[i]){
                return true
            }
        }
        if(v.match(/^(\d+)\.(\d+)\.(\d+)\.(\d+)(\/(\d+))?$/)){
            return(RegExp.$1>0)&&(RegExp.$1<224)&&(RegExp.$1!=127)&&(RegExp.$2>=0)&&(RegExp.$2<=255)&&(RegExp.$3>=0)&&(RegExp.$3<=255)&&(RegExp.$4>0)&&(RegExp.$4<255)&&(!RegExp.$5||((RegExp.$6>0)&&(RegExp.$6<=32)))
        }
        return false
    },
    "subnet":function(v){
        if(cbi_validators.ip4addr(v)){
            var tmp=v.split(".");
            if(tmp[0]&&tmp[3]&&tmp[0]!=0&&tmp[3]==0){
                return true
            }
        }
        return false
    },
    "ip4addrrange":function(v){
        if(v&&v!=""){
            var ip4addr_arr=v.split("-");
            if(ip4addr_arr&&ip4addr_arr.length==2){
                if(cbi_validators.ip4addr(ip4addr_arr[0])&&cbi_validators.ip4addr(ip4addr_arr[1])){
                    if(ip2number(ip4addr_arr[1])>ip2number(ip4addr_arr[0])){
                        return true
                    }
                }
            }else{
                if(ip4addr_arr&&ip4addr_arr.length==1){
                    return cbi_validators.ip4addr(ip4addr_arr[0])
                }
            }
            return false
        }
        return true
    },
    "dhcp_addrpool":function(v,arg){
        if(v&&cbi_validators.ip4addr(v)){
            var lan_addr=arg[0];
            var lan_netmask=arg[1];
            var lan_net=ip2number(lan_addr)&ip2number(lan_netmask);
            var v_net=ip2number(v)&ip2number(lan_netmask);
            if(lan_net!=v_net){
                return false
            }
            var start_obj=document.getElementById("cbid.dhcp.lan.start");
            var limit_obj=document.getElementById("cbid.dhcp.lan.limit");
            if(start_obj&&limit_obj){
                var start_tmp=start_obj.value.split(".");
                var limit_tmp=limit_obj.value.split(".");
                if(parseInt(start_tmp[3],10)<parseInt(limit_tmp[3],10)){
                    if(lan_net==(ip2number(start_obj.value)&ip2number(lan_netmask))){
                        start_obj.className=start_obj.className.replace(/ cbi-input-invalid/g,"");
                        document.getElementById("cbid.dhcp.lan.start.tip").style.display="none"
                    }
                    if(lan_net==(ip2number(limit_obj.value)&ip2number(lan_netmask))){
                        limit_obj.className=limit_obj.className.replace(/ cbi-input-invalid/g,"");
                        document.getElementById("cbid.dhcp.lan.limit.tip").style.display="none"
                    }
                    return true
                }else{
                    return false
                }
            }
        }return false
    },
    "dhcp_gateway":function(v,arg){
        if(v&&cbi_validators.ip4addr(v)){
            var lan_addr=arg[0];
            var lan_netmask=arg[1];
            var lan_net=ip2number(lan_addr)&ip2number(lan_netmask);
            var v_net=ip2number(v)&ip2number(lan_netmask);
            if(lan_net==v_net){
                return true
            }
        }
        return false
    },
    "neg_ip4addr":function(v){
        return cbi_validators.ip4addr(v.replace(/^\s*!/,""))
    },
    "ip6addr":function(v){
        if(v.match(/^([a-fA-F0-9:.]+)(\/(\d+))?$/)){
            if(!RegExp.$2||((RegExp.$3>=0)&&(RegExp.$3<=128))){
                var addr=RegExp.$1;
                if(addr=="::"){
                    return true
                }
                if(addr.indexOf(".")>0){
                    var off=addr.lastIndexOf(":");
                    if(!(off&&cbi_validators.ip4addr(addr.substr(off+1)))){
                        return false
                    }
                    addr=addr.substr(0,off)+":0:0"
                }
                if(addr.indexOf("::")>=0){
                    var colons=0;
                    var fill="0";
                    for(var i=1;i<(addr.length-1);i++){
                        if(addr.charAt(i)==":"){
                            colons++
                        }
                    }
                    if(colons>7){
                        return false
                    }
                    for(var i=0;i<(7-colons);i++){
                        fill+=":0"
                    }
                    if(addr.match(/^(.*?)::(.*?)$/)){
                        addr=(RegExp.$1?RegExp.$1+":":"")+fill+(RegExp.$2?":"+RegExp.$2:"")
                    }
                }
                return(addr.match(/^(?:[a-fA-F0-9]{1,4}:){7}[a-fA-F0-9]{1,4}$/)!=null)
            }
        }
        return false
    },
    "port":function(v){
        return cbi_validators.integer(v)&&(v>=1)&&(v<=65535)
    },
    "portrange":function(v){
        if(v.match(/^(\d+)-(\d+)$/)){
            var p1=RegExp.$1;
            var p2=RegExp.$2;
            return cbi_validators.port(p1)&&cbi_validators.port(p2)&&(parseInt(p1,10)<=parseInt(p2,10))
        }else{
            return cbi_validators.port(v)
        }
    },
    "qos_port":function(v){
        if(v.match(/^(\d+):(\d+)$/)){
            var p1=RegExp.$1;
            var p2=RegExp.$2;
            return cbi_validators.port(p1)&&cbi_validators.port(p2)&&(parseInt(p1,10)<=parseInt(p2,10))
        }else{
            return cbi_validators.port(v)
        }
    },
    "macaddr":function(v){
        return(v.match(/^([a-fA-F0-9]{2}:){5}[a-fA-F0-9]{2}$/)!=null)
    },
    "unicast_macaddr":function(v){
        return(v.match(/^([fF]{2}:){5}[fF]{2}$/)==null&&v.match(/^[a-fA-F0-9][0248aceACE]:([a-fA-F0-9]{2}:){4}[a-fA-F0-9]{2}$/)!=null)
    },
    "macaddr_dif":function(v,args){
        if(!cbi_validators.unicast_macaddr(v)){
            return false
        }
        var str=""+args;
        str=str.split("&");
        for(var i=0;i<str.length;i++){
            if(str[i]==v){
                return false
            }
        }
        return true
    },
    "host":function(v){
        return cbi_validators.hostname(v)||cbi_validators.ipaddr(v)
    },
    "hostname":function(v){
        if(v.length<=24&&v.length>0){
            return(v.match(/^[a-zA-Z]+$/)!=null||(v.match(/^[a-zA-Z0-9][a-zA-Z0-9\-.]*[a-zA-Z0-9]$/)&&v.match(/[^0-9.]/)))
        }
        return false
    },
    "network":function(v){
        return cbi_validators.uciname(v)||cbi_validators.host(v)
    },
    "wpakey":function(v){
        if(v.length==64){
            return(v.match(/^[a-fA-F0-9]{64}$/)!=null)
        }else{
            return(v.length>=8)&&(v.length<=63)
        }
    },
    "wepkey":function(v){
        if(v.substr(0,2)=="s:"){
            v=v.substr(2)
        }
        if((v.length==10)||(v.length==26)){
            return(v.match(/^[a-fA-F0-9]{10,26}$/)!=null)
        }else{
            return(v.length==5)||(v.length==13)
        }
    },
    "cfgname":function(v){
        if(v.length==0||v.length>32){
            return false
        }
        return true
    },
    "abc_ip4addr_domain":function(v){
        if(v.length>64||v.length<3){
            return false
        }
        if(v.match(/^\d+\.\d+\.\d+\.\d+$/)){
            return cbi_validators.abc_ip4addr(v)
        }else{
            if(v.match(/^[a-zA-Z0-9][-a-zA-Z0-9]{0,62}(\.[a-zA-Z0-9][-a-zA-Z0-9]{0,62})+$/)){
                return true
            }else{
                return false
            }
        }
    },
    "domain":function(v){
        if(v.length>64||v.length<3){
            return false
        }
        if(v.match(/^[0-9\.]+$/)==null&&v.match(/^[a-zA-Z0-9][-a-zA-Z0-9]{0,62}(\.[a-zA-Z0-9][-a-zA-Z0-9]{0,62})+$/)){
            return true
        }else{
            return false
        }
    },
    "username":function(v,args){
        if(v.length>32||!v.match(/^[a-zA-Z0-9]+[a-zA-Z0-9\-\_\.]*$/)){
            return false
        }
        var str=""+args;
        str=str.split("&");
        for(var i=0;i<str.length;i++){
            if(v==str[i]){
                return false
            }
        }
        return true
    },
    "vlanaddr":function(v,args){
        if(v.match(/^(\d+)\.(\d+)\.(\d+)\.(\d+)$/)){
            if(!((RegExp.$1>=0)&&(RegExp.$1<255)&&(RegExp.$2>=0)&&(RegExp.$2<255)&&(RegExp.$3>=0)&&(RegExp.$3<255)&&(RegExp.$4>=0)&&(RegExp.$4<255))){
                return false
            }
        }else{
            return false
        }
        var str=""+args;
        str=str.split("&");
        v_arr=v.split(".");
        for(var i=0;i<str.length;i++){
            var tmp=str[i].split(".");
            if(v_arr[0]==tmp[0]&&v_arr[1]==tmp[1]&&v_arr[2]==tmp[2]){
                return false
            }
        }
        return true
    },
    "ip4addr_dif":function(v,args){
        var section=args[0];
        var add_list=args[1];
        var fvalue="";
        var wan_flag=true;
        if(section.indexOf("tmp_vlan_")>=0){
            wan_flag=false;
            section=section.replace(/tmp_vlan_/,"");
            if(document.getElementById("cbid.network."+section+".tmp_vlan_netmask")){
                fvalue=document.getElementById("cbid.network."+section+".tmp_vlan_netmask").value
            }
        }else{
            if(document.getElementById("cbid.network."+section+".netmask")){
                fvalue=document.getElementById("cbid.network."+section+".netmask").value
            }
        }
        if(v.match(/^(\d+)\.(\d+)\.(\d+)\.(\d+)$/)){
            if(!((RegExp.$1>0)&&(RegExp.$1<255)&&(RegExp.$2>=0)&&(RegExp.$2<255)&&(RegExp.$3>=0)&&(RegExp.$3<255)&&(RegExp.$4>0)&&(RegExp.$4<255))){
                return false
            }
        }else{
            return false
        }
        var tmp_ip=v.split(".");
        var tmp_netmask=fvalue.split(".");
        var tmp_v=(tmp_ip[0]&tmp_netmask[0])+"."+(tmp_ip[1]&tmp_netmask[1])+"."+(tmp_ip[2]&tmp_netmask[2])+"."+(tmp_ip[3]&tmp_netmask[3]);
        add_list=add_list.split("&");
        for(var i=0;i<add_list.length;i++){
            if(add_list[i]==tmp_v){
                return false
            }
        }
        if(section.indexOf("vwan")>=0&&wan_flag){
            if(document.getElementById("cbid.network."+section+".tmp_vlan_ipaddr")&&document.getElementById("cbid.network."+section+".tmp_vlan_netmask")){
                var vlan_ip=document.getElementById("cbid.network."+section+".tmp_vlan_ipaddr").value;
                var vlan_netmask=document.getElementById("cbid.network."+section+".tmp_vlan_netmask").value;
                if(cbi_validators.ipaddr(vlan_ip)&&cbi_validators.netmask(vlan_netmask)){
                    var tmp_ip=vlan_ip.split(".");
                    var tmp_netmask=vlan_netmask.split(".");
                    var vlan_subnet=(tmp_ip[0]&tmp_netmask[0])+"."+(tmp_ip[1]&tmp_netmask[1])+"."+(tmp_ip[2]&tmp_netmask[2])+"."+(tmp_ip[3]&tmp_netmask[3]);
                    if(vlan_subnet==tmp_v){
                        return false
                    }
                }
            }
        }
        return true
    },
    "vlanid":function(v,args){
        if(v.match(/^(\d+)$/)){
            var val=parseInt(v);
            if(isNaN(val)||val<3||val>=4095){
                return false
            }
        }else{
            return false
        }
        var str=""+args;
        str=str.split("&");
        for(var i=0;i<str.length;i++){
            if(str[i]==v){
                return false
            }
        }
        return true
    },
    "numberdiff":function(v,args){
        var sp_disabled=document.getElementById("cbid.network.wan2.disabled");
        if(sp_disabled&&sp_disabled.value=="1"){
            return true
        }
        if(v.match(/^(\d+)$/)){
            var val=parseInt(v);
            if(isNaN(val)||val<10||val>90){
                return false
            }
        }else{
            return false
        }
        var str=""+args;
        str=str.split("&");
        for(var i=0;i<str.length;i++){
            if(str[i]==v){
                return false
            }
        }
        return true
    },
    "extension":function(v,args){
        if(isNaN(v)){
            return false
        }
        var str=""+args;
        str=str.split("&");
        for(var i=0;i<str.length;i++){
            if(v==str[i]){
                return false
            }
        }
        return true
    },
    "localport":function(v,args){
        if(isNaN(v)||parseInt(v)>=65535||parseInt(v)<=1){
            return false
        }
        var str=""+args;
        str=str.split("&");
        for(var i=0;i<str.length;i++){
            if(v==str[i]){
                return false
            }
        }
        return v.match(/^[0-9]+$/)!=null
    },
    "numberprefix":function(v){
        if(v==""){
            return true
        }
        if(v.length>32){
            return false
        }
        if(v.length==1){
            if(v.match(/[0-9a-zA-Z]/)==null){
                return false
            }else{
                return true
            }
        }
        if(v.match(/^[0-9a-zA-Z\+\*]+[0-9a-zA-Z\+\*\|]*[0-9a-zA-Z]+$/)==null){
            return false
        }
        var str=v.split("|");
        for(var i=0;i<str.length;i++){
            if(str[i]==""){
                return false
            }
            if(str[i].length>=33){
                return false
            }
            for(j=0;j<str.length;j++){
                if((j!=i&&str[i]==str[j])||str[j]==""){
                    return false
                }
            }
            if(null==str[i].match(/^[\*\+]*[0-9]+$/)){
                return false
            }
        }
        return true
    },
    "phonenumber":function(v){
        if(v.length==1){
            if(v.match(/[0-9a-zA-Z\*\#\+]/)==null){
                return false
            }else{
                return true
            }
        }
        if(v.length>32){
            return false
        }
        if(v.match(/^[0-9a-zA-Z\*\+]+[0-9a-zA-Z]*[0-9a-zA-Z\*\#]+$/)==null){
            return false
        }
        return true
    },
    "pincode":function(v){
        if(v.length<4||v.length>8||v.match(/^[0-9]+$/)==null){
            return false
        }
        return true
    },
    "numberrange":function(v){
        if(v==""){
            return true
        }
        if(v.length>32){
            return false
        }
        if(v.match(/^\d*[0-9\|\-]*\d+$/)==null){
            return false
        }
        var str=v.split("|");
        for(var i=0;i<str.length;i++){
            if(str[i]==""){
                return false
            }
            for(var j=0;j<str.length;j++){
                if((j!=i&&str[i]==str[j])||str[j]==""){
                    return false
                }
            }
            if(str[i].match(/^(\d+)\-(\d+)$/)){
                var min=parseInt(RegExp.$1,10);
                var max=parseInt(RegExp.$2,10);
                if(min>=1&&min<=32&&max>=1&&max<=32&&min<=max){
                    for(var k=0;k<str.length;k++){
                        if(k!=i){
                            num=parseInt(str[k]);
                            if(!isNaN(num)&&num>=min&&num<=max){
                                return false
                            }
                        }
                    }
                    continue
                }else{
                    return false
                }
            }else{
                if(str[i].match(/^\d+$/)){
                    var num=parseInt(str[i]);
                    if(!isNaN(num)){
                        if(num<1||num>32){
                            return false
                        }
                    }
                }else{
                    return false
                }
            }
        }
        return true
    },
    "uciname":function(v){
        return(v.match(/^[a-zA-Z0-9_]+$/)!=null)
    },
    "neg_network_ip4addr":function(v){
        v=v.replace(/^\s*!/,"");
        return cbi_validators.uciname(v)||cbi_validators.ip4addr(v)
    },
    "cidr":function(v){
        if("0.0.0.0"==v||"0.0.0.0/0"==v||"0.0.0.0/0.0.0.0"==v){
            return true
        }
        if(v.match(/^\d+\.\d+\.\d+\.\d+$/)||v.match(/^\d+\.\d+\.\d+\.\d+\/\d+$/)){
            return cbi_validators.abc_ip4addr(v)
        }else{
            if(v.match(/^(\d+\.\d+\.\d+\.\d+)\/(\d+\.\d+\.\d+\.\d+)$/)){
                var ip=RegExp.$1;
                var netmask=RegExp.$2;
                return cbi_validators.abc_ip4addr(ip)&&cbi_validators.netmask(netmask)
            }else{
                return false
            }
        }
    },
    "range":function(v,args){
        if(null==v.match(/^[0-9]+$/)){
            return false
        }
        var min=parseInt(args[0],10);
        var max=parseInt(args[1],10);
        var val=parseInt(v,10);
        if(!isNaN(min)&&!isNaN(max)&&!isNaN(val)){
            return((val>=min)&&(val<=max))
        }
        return false
    },
    "mtu":function(v,args){
        var section=args[1];
        var fvalue=document.getElementById("cbid.network."+section+".proto").value;
        var val=parseInt(v,10);
        var min=576;
        var max=1500;
        if(fvalue=="pppoe"){
            min=546;
            max=1492
        }
        if(!isNaN(val)){
            return((val>=min)&&(val<=max))
        }
        return false
    },
    "min":function(v,args){
        if(v.length>5){
            return false
        }
        var min=parseInt(args[0]);
        var val=parseInt(v);
        if(!isNaN(min)&&!isNaN(val)){
            return(val>=min)
        }
        return false
    },
    "max":function(v,args){
        if(v.length>5){
            return false
        }
        var max=parseInt(args[0]);
        var val=parseInt(v);
        if(!isNaN(max)&&!isNaN(val)){
            return(val>=0&&val<=max)
        }
        return false
    },
    "neg":function(v,args){
        if(args[0]&&typeof cbi_validators[args[0]]=="function"){
            return cbi_validators[args[0]](v.replace(/^\s*!\s*/,""))
        }
        return false
    },
    "ssid":function(v){
        if((v.match(/^[a-zA-Z0-9_%.%-]+$/)!=null)&&(v.length<=32)){
            return true
        }
        return false
    },
    "list":function(v,args){
        var cb=cbi_validators[args[0]||"string"];
        if(typeof cb=="function"){
            var cbargs=args.slice(1);
            var values=v.match(/[^\s]+/g);
            for(var i=0;i<values.length;i++){
                if(!cb(values[i],cbargs)){
                    return false
                }
            }
            return true
        }
        return false
    },
    "feature_code":function(v,args){
        var str=""+args;
        str=str.split("&");
        for(var i=0;i<str.length;i++){
            if(v==str[i]){
                return false
            }
        }
        if(v.match(/^\*[\*0-9]+$/)){
            return true
        }
        return false
    },
    "url":function(v){
        if(v.match(/^tftp:\/\//)||v.match(/^ftp:\/\//)||v.match(/^http:\/\//)||v.match(/^https:\/\//)||v.match(/^ftps:\/\//)){
            return true
        }
        return false
    },
    "notempty":function(v){
        if(v.length>0){
            return true
        }
        return false
    },
    "digitmap":function(v){
        var blRange=false;
        var Brack=0;
        for(var i=0;i<v.length;i++){
            if(v[i].match(/[0-9*#A-D]/)){
                continue
            }else{
                if(v[i].match(/[\.\?\+x]/)){
                    if(blRange){
                        return false
                    }
                }else{
                    if("["==v[i]){
                        if(blRange){
                            return false
                        }
                        blRange=true
                    }else{
                        if("]"==v[i]){
                            if(!blRange){
                                return false
                            }
                            blRange=false
                        }else{
                            if("-"==v[i]){
                                if(!blRange){
                                    return false
                                }
                            }else{
                                if("("==v[i]){
                                    if(blRange){
                                        return false
                                    }else{
                                        Brack++
                                    }
                                }else{
                                    if(")"==v[i]){
                                        if(blRange||0==Brack){
                                            return false
                                        }else{
                                            Brack--
                                        }
                                    }else{
                                        if("|"==v[i]){
                                            if(blRange){
                                                return false
                                            }
                                        }else{
                                            return false
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        if(0!=Brack||blRange){
            return false
        }else{
            return true
        }
    },
    "regular":function(v){
        var blRange=false;
        var Brack=0;
        var exclam=false;
        if(v.length>1024){
            return false
        }
        for(var i=0;i<v.length;i++){
            if(v[i].match(/[0-9a-zA-Z\^,\|*#]/)){
                continue
            }else{
                if(v[i].match(/[\.\*\$\?\+]/)){
                    if(blRange){
                        return false
                    }
                    if("?"==v[i]){
                        exclam=true
                    }
                }else{
                    if("{"==v[i]){
                        if(blRange){
                            return false
                        }
                        blRange=true
                    }else{
                        if("}"==v[i]){
                            if(!blRange){
                                return false
                            }
                            blRange=false
                        }else{
                            if("["==v[i]){
                                if(blRange){
                                    return false
                                }
                                blRange=true
                            }else{
                                if("]"==v[i]){
                                    if(!blRange){
                                        return false
                                    }
                                    blRange=false
                                }else{
                                    if("-"==v[i]){
                                        if(!blRange){
                                            return false
                                        }
                                    }
                                    else{
                                        if("("==v[i]){
                                            if(blRange){
                                                return false
                                            }else{
                                                Brack++
                                            }
                                        }else{
                                            if(")"==v[i]){
                                                if(blRange||0==Brack){
                                                    return false
                                                }else{
                                                    Brack--
                                                }
                                            }
                                            else{
                                                if("!"==v[i]){
                                                    if(!exclam){
                                                        return false
                                                    }
                                                }
                                                else{
                                                    if("|"==v[i]){
                                                        if(blRange){
                                                            return false
                                                        }
                                                    }
                                                    else{
                                                        if("\\"==v[i]){
                                                            if(i+1>=v.length||"d"!=v[i+1]){
                                                                return false
                                                            }
                                                        }else{
                                                            return false
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        if(0!=Brack||blRange){
            return false
        }else{
            return true
        }
    },
    "regular_simple":function(v){
        if(v.length>32){
            return false
        }
        return cbi_validators.regular(v)
    },
    "netmask":function(v){
        if(v.match(/^(\d+)\.(\d+)\.(\d+)\.(\d+)$/)){
            var netmask=v.split(".");
            var zero=false;
            for(i=0;i<4;i++){
                for(j=0;j<8;j++){
                    var x=(128>>j)&parseInt(netmask[i],10);
                    if(0==x){
                        zero=true
                    }
                    if(x>0&&zero){
                        return false
                    }
                }
            }
            return true
        }
        return false
    },
    "wifi_password":function(v){
        if(v.match(/^[0-9a-zA-Z\`\~\!@#\$\%\^\&\*\(\)\-\_\=\+\[\{\]\}\\\|\;\:\'\"\,\<\.\>\/\?]{8,32}$/)){
            return true
        }
        return false
    },
    "password":function(v){
        if(v.length>=8&&v.length<=32){
            return true
        }
        return false
    },
    "wep_password":function(v){
        var wep_obj=document.getElementById("cbid.network_tmp.network.wifi_wep");
        if(wep_obj&&wep_obj.value=="64bit"){
            if(v.length==5){
                return true
            }else{
                return false
            }
        }else{
            if(v.length==13){
                return true
            }else{
                return false
            }
        }
        return false
    },
    "wan_gateway":function(v,args){
        var section=args[1];
        if(cbi_validators.ip4addr(v)&&section){
            var ip=document.getElementById("cbid.network."+section+".ipaddr");
            var netmask=document.getElementById("cbid.network."+section+".netmask");
            if(ip&&netmask){
                var ip_net=ip2number(ip.value)&ip2number(netmask.value);
                var gateway_net=ip2number(v)&ip2number(netmask.value);
                if(ip_net==gateway_net){
                    return true
                }else{
                    return false
                }
            }else{
                return true
            }
        }
        return false
    },
    "qos_ip_field":function(v){
        if(v.match(/\-/)){
            return cbi_validators.ip4addrrange(v)
        }else{
            return cbi_validators.ip4addr(v)
        }
    },
    "qos_packet_length":function(v){
        if(v.match(/^(\d+):(\d+)$/)){
            var str=v.split(":");
            if(parseInt(str[0])>parseInt(str[1])){
                return false
            }else{
                return true
            }
        }else{
            return false
        }
    },
    "ivr_dtmf":function(v){
        var selobj=document.getElementsByTagName("select");
        var allobj_array=new Array();
        var flag=0;
        for(i=0;i<selobj.length;i++){
            allobj_array[i]=0;
            if(selobj[i].id.match(/cbid\.ivr\.[a-z0-9]+\.dtmf$/)){
                for(j=0;j<selobj.length;j++){
                    if(selobj[j].id.match(/cbid.ivr.[a-z0-9]+\.dtmf$/)&&selobj[i].id!=selobj[j].id&&selobj[i].value==selobj[j].value){
                        allobj_array[i]=1;
                        allobj_array[j]=1
                    }
                }
            }
        }
        for(i=0;i<selobj.length;i++){
            if(allobj_array[i]){
                if(selobj[i].className.match(/cbi\-input\-invalid/)==null){
                    selobj[i].className+=" cbi-input-invalid"
                }
                if(v==selobj[i].value){
                    flag=1
                }
            }else{
                if(selobj[i].id.match(/cbid.ivr.[a-z0-9]+\.dtmf$/)){
                    selobj[i].className=selobj[i].className.replace(/ cbi-input-invalid/g,"")
                }
            }
        }
        if(flag){
            return false
        }else{
            return true
        }
    },
    "arpbind_ipv4":function(v){
        if(false==cbi_validators.ip4addr(v)){
            return false
        }
        var selobj=document.getElementsByTagName("input");
        var allobj_array=new Array();
        var flag=0;
        for(i=0;i<selobj.length;i++){
            allobj_array[i]=0;
            if(selobj[i].id.match(/cbid\.dhcp\.[a-z0-9]+\.ip$/)){
                for(j=0;j<selobj.length;j++){
                    if(selobj[j].id.match(/cbid.dhcp.[a-z0-9]+\.ip$/)&&selobj[i].id!=selobj[j].id&&selobj[i].value==selobj[j].value){
                        allobj_array[i]=1;
                        allobj_array[j]=1
                    }
                }
            }
        }
        for(i=0;i<selobj.length;i++){
            if(allobj_array[i]){
                if(selobj[i].className.match(/cbi\-input\-invalid/)==null){
                    selobj[i].className+=" cbi-input-invalid"
                }
                if(v==selobj[i].value){
                    flag=1
                }
            }else{
                if(selobj[i].id.match(/cbid.dhcp.[a-z0-9]+\.ip$/)){
                    selobj[i].className=selobj[i].className.replace(/ cbi-input-invalid/g,"")
                }
            }
        }
        if(flag){
            return false
        }else{
            return true
        }
    },
    "arpbind_macaddr":function(v){
        if(false==cbi_validators.macaddr(v)){
            return false
        }
        var selobj=document.getElementsByTagName("input");
        var allobj_array=new Array();
        var flag=0;
        for(i=0;i<selobj.length;i++){
            allobj_array[i]=0;
            if(selobj[i].id.match(/cbid\.dhcp\.[a-z0-9]+\.mac$/)){
                for(j=0;j<selobj.length;j++){
                    if(selobj[j].id.match(/cbid.dhcp.[a-z0-9]+\.mac$/)&&selobj[i].id!=selobj[j].id&&selobj[i].value==selobj[j].value){
                        allobj_array[i]=1;
                        allobj_array[j]=1
                    }
                }
            }
        }
        for(i=0;i<selobj.length;i++){
            if(allobj_array[i]){
                if(selobj[i].className.match(/cbi\-input\-invalid/)==null){
                    selobj[i].className+=" cbi-input-invalid"
                }
                if(v==selobj[i].value){
                    flag=1
                }
            }else{
                if(selobj[i].id.match(/cbid.dhcp.[a-z0-9]+\.mac$/)){
                    selobj[i].className=selobj[i].className.replace(/ cbi-input-invalid/g,"")
                }
            }
        }
        if(flag){
            return false
        }else{
            return true
        }
    }
};

function cbi_d_add(field,dep,next)
{
    var obj=document.getElementById(field);
    if(obj){
        var entry;
        for(var i=0;i<cbi_d.length;i++){
            if(cbi_d[i].id==field){
                entry=cbi_d[i];
                break
            }
        }
        if(!entry){
            entry={"node":obj,"id":field,"parent":obj.parentNode.id,"next":next,"deps":[]};
            cbi_d.unshift(entry)
        }
        entry.deps.push(dep)
    }
}

function cbi_d_checkvalue(target,ref)
{
    var t=document.getElementById(target);
    var value;
    if(!t){
        var tl=document.getElementsByName(target);
        if(tl.length>0&&tl[0].type=="radio"){
            for(var i=0;i<tl.length;i++){
                if(tl[i].checked){
                    value=tl[i].value;
                    break
                }
            }
        }
        value=value?value:""
    }else{
        if(!t.value){
            value=""
        }else{
            value=t.value;
            if(t.type=="checkbox"){
                value=t.checked?value:""
            }
        }
    }
    return(value==ref)
}

function cbi_d_check(deps)
{
    var reverse;
    var def=false;
    for(var i=0;i<deps.length;i++){
        var istat=true;
        reverse=false;
        for(var j in deps[i]){
            if(j=="!reverse"){
                reverse=true
            }else{
                if(j=="!default"){
                    def=true;
                    istat=false
                }else{
                    istat=(istat&&cbi_d_checkvalue(j,deps[i][j]))
                }
            }
        }
        if(istat){
            return !reverse
        }
    }
    return def
}

function cbi_d_update()
{
    var state=false;
    for(var i=0;i<cbi_d.length;i++){
        var parent;
        var entry=cbi_d[i];
        var next=document.getElementById(entry.next);
        var node=document.getElementById(entry.id);
        if(entry.parent){
            parent=document.getElementById(entry.parent)
        }
        if(node&&node.parentNode&&!cbi_d_check(entry.deps)){
            node.parentNode.removeChild(node);
            state=true;
            if(entry.parent){
                cbi_c[entry.parent]--
            }
        }else{
            if((!node||!node.parentNode)&&cbi_d_check(entry.deps)){
                entry.node.style.display="";
                if(!next){
                    if(parent){
                        parent.appendChild(entry.node);
                        state=true
                    }
                }else{
                    next.parentNode.insertBefore(entry.node,next);
                    state=true
                }
                if(entry.parent){
                    cbi_c[entry.parent]++
                }
            }else{
                if("none"==entry.node.style.display){
                    entry.node.style.display=""
                }
            }
        }
    }
    if(entry&&entry.parent){
        if(!cbi_t_update()){
            cbi_tag_last(parent)
        }
    }
    if(state){
        cbi_d_update()
    }
}

function cbi_bind(obj,type,callback,mode)
{
    if(!obj.addEventListener){
        obj.attachEvent("on"+type,function(){
            var e=window.event;
            if(!e.target&&e.srcElement){
                e.target=e.srcElement
            }
            return !!callback(e)
        })
    }else{
        obj.addEventListener(type,callback,!!mode)
    }
    return obj
}

function cbi_combobox(id,values,def,man,focus)
{
    var selid="cbi.combobox."+id;
    if(document.getElementById(selid)){
        return
    }
    var obj=document.getElementById(id);
    var sel=document.createElement("select");
    sel.id=selid;
    sel.index=obj.index;
    sel.className=obj.className.replace(/cbi-input-text/,"cbi-input-select");
    if(obj.nextSibling){
        obj.parentNode.insertBefore(sel,obj.nextSibling)
    }else{
        obj.parentNode.appendChild(sel)
    }
    var dt=obj.getAttribute("cbi_datatype");
    var op=obj.getAttribute("cbi_optional");
    if(dt){
        cbi_validate_field(sel,op=="true",dt)
    }
    if(!values[obj.value]){
        if(obj.value==""){
            var optdef=document.createElement("option");
            optdef.value="";
            optdef.appendChild(document.createTextNode(typeof(def)==="string"?def:cbi_strings.label.choose));
            sel.appendChild(optdef)
        }else{
            var opt=document.createElement("option");
            opt.value=obj.value;
            opt.selected="selected";
            opt.appendChild(document.createTextNode(obj.value));
            sel.appendChild(opt)
        }
    }
    for(var i in values){
        var opt=document.createElement("option");
        opt.value=i;
        if(obj.value==i){
            opt.selected="selected"
        }
        opt.appendChild(document.createTextNode(values[i]));
        sel.appendChild(opt)
    }
    var optman=document.createElement("option");
    optman.value="";
    optman.appendChild(document.createTextNode(typeof(man)==="string"?man:cbi_strings.label.custom));
    sel.appendChild(optman);
    obj.style.display="none";
    cbi_bind(sel,"change",function(){
        if(sel.selectedIndex==sel.options.length-1){
            obj.style.display="inline";
            sel.blur();
            sel.parentNode.removeChild(sel);
            obj.focus()
        }else{
            obj.value=sel.options[sel.selectedIndex].value
        }
        try{
            cbi_d_update()
        }catch(e){}
    });
    if(focus){
        sel.focus();
        sel.blur()
    }
}

function cbi_combobox_init(id,values,def,man){
    var obj=document.getElementById(id);
    cbi_bind(obj,"blur",function(){
        cbi_combobox(id,values,def,man,true)
    });
    cbi_combobox(id,values,def,man,false)
}

function cbi_filebrowser(id,url,defpath){
    var field=document.getElementById(id);
    var browser=window.open(url+(field.value||defpath||"")+"?field="+id,"luci_filebrowser","width=300,height=400,left=100,top=200,scrollbars=yes");
    browser.focus()
}

function cbi_browser_init(id,respath,url,defpath){
    function cbi_browser_btnclick(e){
        cbi_filebrowser(id,url,defpath);
        return false
    }
    var field=document.getElementById(id);
    var btn=document.createElement("img");
    btn.className="cbi-image-button";
    btn.src=respath+"/cbi/folder.gif";
    field.parentNode.insertBefore(btn,field.nextSibling);
    cbi_bind(btn,"click",cbi_browser_btnclick)
}

function cbi_dynsellist_init(name,respath){
    function cbi_dynsellist_renumber(e){
        var objs=[];
        for(var i=0;i<e.parentNode.childNodes.length;i++){
            if(e.parentNode.childNodes[i].name==name){
                objs.push(e.parentNode.childNodes[i])
            }
        }
        var selobjs=document.getElementsByName(name);
        var options_len=objs[0].options.length;
        for(var i=0;i<objs.length&&i<options_len;i++){
            objs[i].id=name+"."+(i+1);
            objs[i].nextSibling.src=respath+(((i+1)<selobjs.length||(i+1)==options_len)?"/cbi/remove.png":"/cbi/add.png")
        }
        if(objs.length<options_len){
            if(objs.length>1&&"br"==objs[objs.length-1].nextSibling.nextSibling.tagName.toLowerCase()){
                var btn=document.createElement("img");
                btn.className="cbi-image-button";
                btn.src=respath+"/cbi/remove.png";
                objs[objs.length-1].parentNode.insertBefore(btn,objs[objs.length-1].nextSibling);
                cbi_bind(btn,"click",cbi_dynsellist_btnclick)
            }
            if(objs.length>1&&"img"==objs[objs.length-1].nextSibling.nextSibling.tagName.toLowerCase()){
                objs[objs.length-1].nextSibling.src=respath+"/cbi/remove.png"
            }
            if(1==objs.length&&"img"==objs[objs.length-1].nextSibling.nextSibling.tagName.toLowerCase()){
                objs[objs.length-1].parentNode.removeChild(objs[objs.length-1].nextSibling.nextSibling)
            }
        }
        e.focus()
    }
    function cbi_dynsellist_keypress(ev){
        ev=ev?ev:window.event;
        var se=ev.target?ev.target:ev.srcElement;
        if(se.nodeType==3){
            se=se.parentNode
        }
        switch(ev.keyCode){
            case 8:
            case 46:
                if(se.value.length==0){
                    if(ev.preventDefault){
                        ev.preventDefault()
                    }
                    return false
                }
                return true;
            case 13:
            case 38:
            case 40:
                if(ev.preventDefault){
                    ev.preventDefault()
                }
                return false
        }
        return true
    }
    function cbi_dynsellist_keydown(ev){
        ev=ev?ev:window.event;
        var se=ev.target?ev.target:ev.srcElement;
        if(se.nodeType==3){
            se=se.parentNode
        }
        var prev=se.previousSibling;
        while(prev&&prev.name!=name){
            prev=prev.previousSibling
        }
        var next=se.nextSibling;
        while(next&&next.name!=name){
            next=next.nextSibling
        }
        switch(ev.keyCode){
            case 8:
            case 46:
                var jump=(ev.keyCode==8)?(prev||next):(next||prev);
                if(jump){
                    if("img"==se.nextSibling.nextSibling.tagName.toLowerCase()){
                        se.parentNode.removeChild(se.nextSibling.nextSibling.nextSibling)
                    }
                    se.parentNode.removeChild(se.nextSibling.nextSibling);
                    se.parentNode.removeChild(se.nextSibling);
                    se.parentNode.removeChild(se);
                    cbi_dynsellist_renumber(jump);
                    if(ev.preventDefault){
                        ev.preventDefault()
                    }
                    jump.focus();
                    return false
                }
                break;
            case 13:
                var n=document.createElement("select");
                n.className=se.className;
                n.name=se.name;
                n.id=se.id;
                var selobjs=document.getElementsByName(name);
                var selobj=document.getElementById(selobjs[selobjs.length-1].id);
                var selected_index=0;
                for(var i=0;i<selobjs.length;i++){
                    var index=selobjs[i].selectedIndex;
                    selected_index|=1<<index
                }
                var selected_setflag=0;
                for(var i=0;i<selobj.length;i++){
                    n.options[i]=new Option(selobj.options[i].text,selobj.options[i].value);
                    n.options[i].id=selobj.options[i].id+"."+selobjs.length;
                    if(0==selected_setflag&&!((1<<i)&selected_index)){
                        n.options[i].selected=true;
                        selected_setflag=1
                    }
                }
                var b=document.createElement("img");
                cbi_bind(b,"click",cbi_dynsellist_btnclick);
                if(next){
                    se.parentNode.insertBefore(n,next);
                    se.parentNode.insertBefore(b,next);
                    se.parentNode.insertBefore(document.createElement("br"),next)
                }else{
                    if("img"==se.nextSibling.nextSibling.tagName.toLowerCase()){
                        se.parentNode.removeChild(se.nextSibling.nextSibling)
                    }
                    se.parentNode.appendChild(n);
                    se.parentNode.appendChild(b);
                    se.parentNode.appendChild(document.createElement("br"))
                }
                var dt=se.getAttribute("cbi_datatype");
                var op=se.getAttribute("cbi_optional")=="true";
                if(dt){
                    cbi_validate_field(n,op,dt)
                }
                cbi_dynsellist_renumber(n);
                break;
            case 38:
                if(prev){
                    prev.focus()
                }
                break;
            case 40:
                if(next){
                    next.focus()
                }
                break
        }
        return true
    }
    function cbi_dynsellist_btnclick(ev){
        ev=ev?ev:window.event;
        var se=ev.target?ev.target:ev.srcElement;
        if(se.src.indexOf("remove")>-1){
            cbi_dynsellist_keydown({target:se.previousSibling,keyCode:8})
        }else{
            var objs=document.getElementsByName(name);
            if(1==objs.length){
                cbi_dynsellist_keydown({target:se.previousSibling,keyCode:13})
            }else{
                cbi_dynsellist_keydown({target:se.previousSibling.previousSibling,keyCode:13})
            }
        }
        return false
    }
    var selobjs=document.getElementsByName(name);
    if(selobjs.length>0){
        var options_len=document.getElementById(selobjs[selobjs.length-1].id).length
    }
    for(var i=0;i<selobjs.length;i++){
        var btn=document.createElement("img");
        btn.className="cbi-image-button";
        if(options_len>1){
            btn.src=respath+((((i+1)<selobjs.length)||((i+1)>=options_len))?"/cbi/remove.png":"/cbi/add.png")
        }
        selobjs[i].parentNode.insertBefore(btn,selobjs[i].nextSibling);
        cbi_bind(btn,"click",cbi_dynsellist_btnclick)
    }
    if(selobjs.length>1&&selobjs.length<options_len){
        var btn=document.createElement("img");
        btn.className="cbi-image-button";
        btn.src=respath+"/cbi/remove.png";
        selobjs[selobjs.length-1].parentNode.insertBefore(btn,selobjs[selobjs.length-1].nextSibling);
        cbi_bind(btn,"click",cbi_dynsellist_btnclick)
    }
}

function cbi_dynlist_init(name,respath){
    function cbi_dynlist_renumber(e){
        var inputs=[];
        for(var i=0;i<e.parentNode.childNodes.length;i++){
            if(e.parentNode.childNodes[i].name==name){
                inputs.push(e.parentNode.childNodes[i])
            }
        }
        for(var i=0;i<inputs.length;i++){
            inputs[i].id=name+"."+(i+1);
            inputs[i].nextSibling.src=respath+((i+1)<inputs.length?"/cbi/remove.png":"/cbi/add.png")
        }
        var last=inputs.length-1;
        if(inputs.length>1&&"br"==inputs[last].nextSibling.nextSibling.tagName.toLowerCase()){
            var btn=document.createElement("img");
            btn.className="cbi-image-button";
            btn.src=respath+"/cbi/remove.png";
            inputs[last].parentNode.insertBefore(btn,inputs[last].nextSibling);
            cbi_bind(btn,"click",cbi_dynlist_btnclick)
        }
        if(inputs.length>1&&"img"==inputs[last].nextSibling.nextSibling.tagName.toLowerCase()){
            inputs[last].nextSibling.src=respath+"/cbi/remove.png"
        }
        if(1==inputs.length&&"img"==inputs[last].nextSibling.nextSibling.tagName.toLowerCase()){
            inputs[last].parentNode.removeChild(inputs[last].nextSibling.nextSibling)
        }
        e.focus()
    }
    function cbi_dynlist_keypress(ev){
        ev=ev?ev:window.event;
        var se=ev.target?ev.target:ev.srcElement;
        if(se.nodeType==3){
            se=se.parentNode
        }
        switch(ev.keyCode){
            case 8:
            case 46:
                if(se.value.length==0){
                    if(ev.preventDefault){
                        ev.preventDefault()
                    }
                    return false
                }
                return true;
            case 13:
            case 38:
            case 40:
                if(ev.preventDefault){
                    ev.preventDefault()
                }
                return false
        }
        return true
    }
    function cbi_dynlist_keydown(ev){
        ev=ev?ev:window.event;
        var se=ev.target?ev.target:ev.srcElement;
        if(se.nodeType==3){
            se=se.parentNode
        }
        var prev=se.previousSibling;
        while(prev&&prev.name!=name){
            prev=prev.previousSibling
        }
        var next=se.nextSibling;
        while(next&&next.name!=name){
            next=next.nextSibling
        }
        switch(ev.keyCode){
            case 8:
            case 46:
                var jump=(ev.keyCode==8)?(prev||next):(next||prev);
                if(se.value.length==0&&jump){
                    if("img"==se.nextSibling.nextSibling.tagName.toLowerCase()){
                        se.parentNode.removeChild(se.nextSibling.nextSibling.nextSibling)
                    }
                    se.parentNode.removeChild(se.nextSibling.nextSibling);
                    se.parentNode.removeChild(se.nextSibling);
                    se.parentNode.removeChild(se);
                    cbi_dynlist_renumber(jump);
                    if(ev.preventDefault){
                        ev.preventDefault()
                    }
                    jump.focus();
                    return false
                }
                break;
            case 13:
                var n=document.createElement("input");
                n.name=se.name;
                n.type=se.type;
                var b=document.createElement("img");
                cbi_bind(n,"keydown",cbi_dynlist_keydown);
                cbi_bind(n,"keypress",cbi_dynlist_keypress);
                cbi_bind(b,"click",cbi_dynlist_btnclick);
                if(se.id.indexOf("date_options")>=0){
                    cbi_bind(n,"click",setDate)
                }
                if(se.id.indexOf("time_options")>=0){
                    cbi_bind(n,"click",setTime)
                }
                if(next){
                    se.parentNode.insertBefore(n,next);
                    se.parentNode.insertBefore(b,next);
                    se.parentNode.insertBefore(document.createElement("br"),next)
                }else{
                    if("img"==se.nextSibling.nextSibling.tagName.toLowerCase()){
                        se.parentNode.removeChild(se.nextSibling.nextSibling)
                    }
                    se.parentNode.appendChild(n);
                    se.parentNode.appendChild(b);
                    se.parentNode.appendChild(document.createElement("br"))
                }
                var dt=se.getAttribute("cbi_datatype");
                var op=se.getAttribute("cbi_optional")=="true";
                if(dt){
                    cbi_validate_field(n,op,dt)
                }
                cbi_dynlist_renumber(n);
                break;
            case 38:
                if(prev){
                    prev.focus()
                }
                break;
            case 40:
                if(next){
                    next.focus()
                }
                break
        }
        return true
    }
    function cbi_dynlist_btnclick(ev){
        ev=ev?ev:window.event;
        var se=ev.target?ev.target:ev.srcElement;
        var obj=document.getElementById("calender");
        if(obj){
            obj.parentNode.removeChild(obj)
        }
        obj=document.getElementById("timeSelPanel");
        if(obj){
            obj.parentNode.removeChild(obj)
        }
        if(se.src.indexOf("remove")>-1){
            se.previousSibling.value="";
            cbi_dynlist_keydown({target:se.previousSibling,keyCode:8})
        }else{
            var inputs=document.getElementsByName(name);
            if(1==inputs.length){
                cbi_dynlist_keydown({target:se.previousSibling,keyCode:13})
            }else{
                cbi_dynlist_keydown({target:se.previousSibling.previousSibling,keyCode:13})
            }
        }
        return false
    }
    var inputs=document.getElementsByName(name);
    for(var i=0;i<inputs.length;i++){
        var btn=document.createElement("img");
        btn.className="cbi-image-button";
        btn.src=respath+((i+1)<inputs.length?"/cbi/remove.png":"/cbi/add.png");
        inputs[i].parentNode.insertBefore(btn,inputs[i].nextSibling);
        cbi_bind(inputs[i],"keydown",cbi_dynlist_keydown);
        cbi_bind(inputs[i],"keypress",cbi_dynlist_keypress);
        cbi_bind(btn,"click",cbi_dynlist_btnclick)
    }
    if(inputs.length>1){
        var last=inputs.length-1;
        var btn=document.createElement("img");
        btn.className="cbi-image-button";
        btn.src=respath+"/cbi/remove.png";
        inputs[last].parentNode.insertBefore(btn,inputs[last].nextSibling);
        cbi_bind(btn,"click",cbi_dynlist_btnclick)
    }
}

function cbi_hijack_forms(layer,win,fail,load)
{
    var forms=layer.getElementsByTagName("form");
    for(var i=0;i<forms.length;i++){
        $(forms[i]).observe("submit",function(event){
            event.stop();
            event.element().request({onSuccess:win,onFailure:fail});
            if(load){
                load()
            }
        }
        )
    }
}

function cbi_t_add(section,tab)
{
    var t=document.getElementById("tab."+section+"."+tab);
    var c=document.getElementById("container."+section+"."+tab);
    if(t&&c){
        cbi_t[section]=(cbi_t[section]||[]);
        cbi_t[section][tab]={"tab":t,"container":c,"cid":c.id}
    }
}

function cbi_t_switch(section,tab)
{
    if(cbi_t[section]&&cbi_t[section][tab]){
        var o=cbi_t[section][tab];
        var h=document.getElementById("tab."+section);
        for(var tid in cbi_t[section]){
            var o2=cbi_t[section][tid];
            if(o.tab.id!=o2.tab.id){
                o2.tab.className=o2.tab.className.replace(/(^| )cbi-tab( |$)/," cbi-tab-disabled ");
                o2.container.style.display="none"
            }else{
                if(h){
                    h.value=tab
                }
                o2.tab.className=o2.tab.className.replace(/(^| )cbi-tab-disabled( |$)/," cbi-tab ");
                o2.container.style.display="block"
            }
        }
    }
    return false
}

function cbi_t_update()
{
    var hl_tabs=[];
    var updated=false;
    for(var sid in cbi_t){
        for(var tid in cbi_t[sid]){
            if(cbi_c[cbi_t[sid][tid].cid]==0){
                cbi_t[sid][tid].tab.style.display="none"
            }else{
                if(cbi_t[sid][tid].tab&&cbi_t[sid][tid].tab.style.display=="none"){
                    cbi_t[sid][tid].tab.style.display="";
                    var t=cbi_t[sid][tid].tab;
                    t.className+=" cbi-tab-highlighted";
                    hl_tabs.push(t)
                }
            }
            cbi_tag_last(cbi_t[sid][tid].container);
            updated=true
        }
    }
    if(hl_tabs.length>0){
        window.setTimeout(function(){
            for(var i=0;i<hl_tabs.length;i++){
                hl_tabs[i].className=hl_tabs[i].className.replace(/ cbi-tab-highlighted/g,"")
            }
        },750)
    }
    return updated
}

function cbi_validate_form(form,errmsg)
{
    if(form.cbi_state=="add-section"||form.cbi_state=="del-section"){
        return true
    }
    var err_flag=false;
    if(form.cbi_validators){
        for(var i=0;i<form.cbi_validators.length;i++){
            var validator=form.cbi_validators[i];
            if(!validator()){
                err_flag=true
            }
        }
    }
    if(true==err_flag){
        alert(errmsg);
        return false
    }
    return true
}

function cbi_validate_reset(form){
    window.setTimeout(function(){
        cbi_validate_form(form,null)
    },100);
    return true
}

function cbi_validate_field(cbid,optional,dtype){
    var field=(typeof cbid=="string")?document.getElementById(cbid):cbid;
    var vargs;
    var type;
    if(dtype.match(/^(\w+)\(([^\(\)]*)\)/)){
        type=RegExp.$1;
        vargs=RegExp.$2.split(/\s*,\s*/)
    }else{
        type=dtype
    }
    var vldcb=cbi_validators[type];
    if(field&&vldcb){
        var validator=function(){
            if(field.form){
                field.className=field.className.replace(/ cbi-input-invalid/g,"");
                var field_tips=document.getElementById(cbid+".tip");
                if(field.id.match(/^cbi\.combobox\./)){
                    var field_tips_id=field.id.replace(/cbi\.combobox\./g,"")+".tip";
                    field_tips=document.getElementById(field_tips_id)
                }
                if(field_tips){
                    field_tips.style.display="none"
                }
                var value=(field.options&&field.options.selectedIndex>-1)?field.options[field.options.selectedIndex].value:field.value;
                if(field.nodeName=="SELECT"&&value.length==0){
                    return true
                }
                if(!(((value.length==0)&&optional)||vldcb(value,vargs))){
                    field.className+=" cbi-input-invalid";
                    cbi_bind(field,"keyup",validator);
                    if(field_tips){
                        field_tips.style.display="table"
                    }
                    return false
                }
            }
            return true
        };
        if(!field.form.cbi_validators){
            field.form.cbi_validators=[]
        }
        field.form.cbi_validators.push(validator);
        cbi_bind(field,"blur",validator);
        if(field.nodeName=="SELECT"){
            cbi_bind(field,"change",validator);
            cbi_bind(field,"click",validator)
        }
        field.setAttribute("cbi_validate",validator);
        field.setAttribute("cbi_datatype",dtype);
        field.setAttribute("cbi_optional",(!!optional).toString());
        var fcbox=document.getElementById("cbi.combobox."+field.id);
        if(fcbox){
            cbi_validate_field(fcbox,optional,dtype)
        }
    }
}

function cbi_row_swap(elem,up,store){
    var tr=elem.parentNode;
    while(tr&&tr.nodeName.toLowerCase()!="tr"){
        tr=tr.parentNode
    }
    if(!tr){
        return false
    }
    var table=tr.parentNode;
    while(table&&table.nodeName.toLowerCase()!="table"){
        table=table.parentNode
    }
    if(!table){
        return false
    }
    var s=up?3:2;
    var e=up?table.rows.length:table.rows.length-1;
    for(var idx=s;idx<e;idx++){
        if(table.rows[idx]==tr){
            if(up){
                tr.parentNode.insertBefore(table.rows[idx],table.rows[idx-1])
            }else{
                tr.parentNode.insertBefore(table.rows[idx+1],table.rows[idx])
            }
            break
        }
    }
    var ids=[];
    for(idx=2;idx<table.rows.length;idx++){
        table.rows[idx].className=table.rows[idx].className.replace(/cbi-rowstyle-[12]/,"cbi-rowstyle-"+(1+(idx%2)));
        if(table.rows[idx].id&&table.rows[idx].id.match(/-([^\-]+)$/)){
            ids.push(RegExp.$1)
        }
    }
    var input=document.getElementById(store);
    if(input){
        input.value=ids.join(" ")
    }
    return false
}

function cbi_tag_last(container)
{
    var last;
    for(var i=0;i<container.childNodes.length;i++){
        var c=container.childNodes[i];
        if(c.nodeType==1&&c.nodeName.toLowerCase()=="div"){
            c.className=c.className.replace(/ cbi-value-last$/,"");
            last=c
        }
    }
    if(last){
        last.className+=" cbi-value-last"
    }
}

if(!String.serialize){
    String.serialize=function(o){
        switch(typeof(o)){
            case"object":
                if(o==null){
                    return"null"
                }else{
                    if(o.length){
                        var i,s="";
                        for(var i=0;i<o.length;i++){
                            s+=(s?", ":"")+String.serialize(o[i])
                        }
                        return"[ "+s+" ]"
                    }else{
                        var k,s="";
                        for(k in o){
                            s+=(s?", ":"")+k+": "+String.serialize(o[k])
                        }
                        return"{ "+s+" }"
                    }
                }
                break;
            case"string":
                if(o.match(/[^a-zA-Z0-9_,.: -]/)){
                    return'decodeURIComponent("'+encodeURIComponent(o)+'")'
                }else{
                    return'"'+o+'"'
                }
                break;
            default:
                return o.toString()
        }
    }
}
if(!String.format){
    String.format=function(){
        if(!arguments||arguments.length<1||!RegExp){
            return
        }
        var html_esc=[/&/g,"&#38;",/"/g,"&#34;",/'/g,"&#39;",/</g,"&#60;",/>/g,"&#62;"];
        var quot_esc=[/"/g,"&#34;",/'/g,"&#39;"];
        function esc(s,r){
            for(var i=0;i<r.length;i+=2){
                s=s.replace(r[i],r[i+1])
            }
            return s
        }
        var str=arguments[0];
        var out="";
        var re=/^(([^%]*)%('.|0|\x20)?(-)?(\d+)?(\.\d+)?(%|b|c|d|u|f|o|s|x|X|q|h|j|t|m))/;
        var a=b=[],numSubstitutions=0,numMatches=0;
        while(a=re.exec(str)){
            var m=a[1];
            var leftpart=a[2],pPad=a[3],pJustify=a[4],pMinLength=a[5];
            var pPrecision=a[6],pType=a[7];
            numMatches++;
            if(pType=="%"){
                subst="%"
            }else{
                if(numSubstitutions++<arguments.length){
                    var param=arguments[numSubstitutions];
                    var pad="";
                    if(pPad&&pPad.substr(0,1)=="'"){
                        pad=leftpart.substr(1,1)
                    }else{
                        if(pPad){
                            pad=pPad
                        }
                    }
                    var justifyRight=true;
                    if(pJustify&&pJustify==="-"){
                        justifyRight=false
                    }
                    var minLength=-1;
                    if(pMinLength){
                        minLength=parseInt(pMinLength)
                    }
                    var precision=-1;
                    if(pPrecision&&pType=="f"){
                        precision=parseInt(pPrecision.substring(1))
                    }
                    var subst=param;
                    switch(pType){
                        case"b":
                            subst=(parseInt(param)||0).toString(2);
                            break;
                        case"c":
                            subst=String.fromCharCode(parseInt(param)||0);
                            break;
                        case"d":
                            subst=(parseInt(param)||0);
                            break;
                        case"u":
                            subst=Math.abs(parseInt(param)||0);
                            break;
                        case"f":
                            subst=(precision>-1)?((parseFloat(param)||0)).toFixed(precision):(parseFloat(param)||0);
                            break;
                        case"o":
                            subst=(parseInt(param)||0).toString(8);
                            break;
                        case"s":
                            subst=param;
                            break;
                        case"x":
                            subst=(""+(parseInt(param)||0).toString(16)).toLowerCase();
                            break;
                        case"X":
                            subst=(""+(parseInt(param)||0).toString(16)).toUpperCase();
                            break;
                        case"h":
                            subst=esc(param,html_esc);
                            break;
                        case"q":
                            subst=esc(param,quot_esc);
                            break;
                        case"j":
                            subst=String.serialize(param);
                            break;
                        case"t":
                            var td=0;
                            var th=0;
                            var tm=0;
                            var ts=(param||0);
                            if(ts>60){
                                tm=Math.floor(ts/60);
                                ts=(ts%60)
                            }
                            if(tm>60){
                                th=Math.floor(tm/60);
                                tm=(tm%60)
                            }
                            if(th>24){
                                td=Math.floor(th/24);
                                th=(th%24)
                            }
                            subst=(td>0)?String.format("%dd %dh %dm %ds",td,th,tm,ts):String.format("%dh %dm %ds",th,tm,ts);
                            break;
                        case"m":
                            var mf=pMinLength?parseInt(pMinLength):1000;
                            var pr=pPrecision?Math.floor(10*parseFloat("0"+pPrecision)):2;
                            var i=0;
                            var val=parseFloat(param||0);
                            var units=["","K","M","G","T","P","E"];
                            for(i=0;(i<units.length)&&(val>mf);i++){
                                val/=mf
                            }
                            subst=val.toFixed(pr)+" "+units[i];
                            break
                    }
                }
            }
            out+=leftpart+subst;
            str=str.substr(m.length)
        }
        return out+str
    }
}

XHR=function(){
    this.reinit=function(){
        if(window.XMLHttpRequest){
            this._xmlHttp=new XMLHttpRequest()
        }else{
            if(window.ActiveXObject){
                this._xmlHttp=new ActiveXObject("Microsoft.XMLHTTP")
            }else{
                alert("xhr.js: XMLHttpRequest is not supported by this browser!")
            }
        }
    };
    this.busy=function(){
        if(!this._xmlHttp){
            return false
        }
        switch(this._xmlHttp.readyState){
            case 1:
            case 2:
            case 3:
                return true;
            default:
                return false
        }
    };
    this.abort=function(){
        if(this.busy()){
            this._xmlHttp.abort()
        }
    };
    this.get=function(url,data,callback){
        this.reinit();
        var xhr=this._xmlHttp;
        var code=this._encode(data);
        url=location.protocol+"//"+location.host+url;
        if(code){
            if(url.substr(url.length-1,1)=="&"){
                url+=code\
            }else{
                url+="?"+code\
            }
        }
        xhr.open("GET",url,true);
        xhr.onreadystatechange=function(){
            if(xhr.readyState==4){
                var json=null;
                if(xhr.getResponseHeader("Content-Type")=="application/json"){
                    try{
                        json=eval("("+xhr.responseText+")")
                    }catch(e){
                        json=null
                    }
                }
                callback(xhr,json)
            }
        };
        xhr.send(null)
    };
    this.post=function(url,data,callback){
        this.reinit();
        var xhr=this._xmlHttp;
        var code=this._encode(data);
        xhr.onreadystatechange=function(){
            if(xhr.readyState==4){callback(xhr)}
        };
        xhr.open("POST",url,true);
        xhr.setRequestHeader("Content-type","application/x-www-form-urlencoded");
        xhr.setRequestHeader("Content-length",code.length);
        xhr.setRequestHeader("Connection","close");
        xhr.send(code)
    };
    this.cancel=function(){
        this._xmlHttp.onreadystatechange=function(){};
        this._xmlHttp.abort()
    };
    this.send_form=function(form,callback,extra_values){
        var code="";
        for(var i=0;i<form.elements.length;i++){
            var e=form.elements[i];
            if(e.options){
                code+=(code?"&":"")+form.elements[i].name+"="+encodeURIComponent(e.options[e.selectedIndex].value)
            }else{
                if(e.length){
                    for(var j=0;j<e.length;j++){
                        if(e[j].name){
                            code+=(code?"&":"")+e[j].name+"="+encodeURIComponent(e[j].value)
                        }
                    }
                }else{
                    code+=(code?"&":"")+e.name+"="+encodeURIComponent(e.value)
                }
            }
        }
        if(typeof extra_values=="object"){
            for(var key in extra_values){
                code+=(code?"&":"")+key+"="+encodeURIComponent(extra_values[key])
            }
        }
        return((form.method=="get")?this.get(form.getAttribute("action"),code,callback):this.post(form.getAttribute("action"),code,callback))
    };
    this._encode=function(obj){
        obj=obj?obj:{};
        obj["_"]=Math.random();
        if(typeof obj=="object"){
            var code="";
            var self=this;
            for(var k in obj){
                code+=(code?"&":"")+k+"="+encodeURIComponent(obj[k])
            }
            return code
        }
        return obj
    }
};
XHR.get=function(url,data,callback){
    (new XHR()).get(url,data,callback)
};
XHR.poll=function(interval,url,data,callback){
    if(isNaN(interval)||interval<1){
        interval=5
    }
    if(!XHR._q){
        XHR._t=0;
        XHR._q=[];
        XHR._r=function(){
            for(var i=0,e=XHR._q[0];i<XHR._q.length;e=XHR._q[++i]){
                if(!(XHR._t%e.interval)&&!e.xhr.busy()){
                    e.xhr.get(e.url,e.data,e.callback)
                }
            }
            XHR._t++
        }
    }
    XHR._q.push({interval:interval,callback:callback,url:url,data:data,xhr:new XHR()});
    XHR.run()
};
XHR.halt=function(){
    if(XHR._i){
        try{
            document.getElementById("xhr_poll_status").style.display="";
            document.getElementById("xhr_poll_status_on").style.display="none";
            document.getElementById("xhr_poll_status_off").style.display=""
        }catch(e){}
        window.clearInterval(XHR._i);
        XHR._i=null
    }
};
XHR.run=function(){
    if(XHR._r&&!XHR._i){
        try{
            document.getElementById("xhr_poll_status").style.display="";
            document.getElementById("xhr_poll_status_on").style.display="";
            document.getElementById("xhr_poll_status_off").style.display="none"
        }catch(e){}
        XHR._r();
        XHR._i=window.setInterval(XHR._r,1000)
    }
};
XHR.running=function(){
    return !!(XHR._r&&XHR._i)
};
