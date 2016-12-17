#!/bin/sh

echo "login: server_ip:$trusted_ip:$trusted_port, proto:$proto_1, dev:$dev, dev_type:$dev_type,\
 local_ip:$ifconfig_local, gateway:$ifconfig_remote login_time:$daemon_start_time" \
 >> /ramlog/openvpnc_log
 
openvpn_ip3=${ifconfig_remote%.*}
echo "$openvpn_ip3.1" > /var/run/openvpn_client_gw
 
iptables -w -t nat -D POSTROUTING -o $dev -j MASQUERADE 2>/dev/null
iptables -w -t nat -I POSTROUTING -o $dev -j MASQUERADE 2>/dev/null

sed -i "/iptables -w -t nat -D POSTROUTING -o $dev -j MASQUERADE/d" /etc/firewall.vpn.reload
sed -i "/iptables -w -t nat -I POSTROUTING -o $dev -j MASQUERADE/d" /etc/firewall.vpn.reload

echo "iptables -w -t nat -D POSTROUTING -o $dev -j MASQUERADE" >> /etc/firewall.vpn.reload
echo "iptables -w -t nat -I POSTROUTING -o $dev -j MASQUERADE" >> /etc/firewall.vpn.reload

autovpn_en=`uci get autovpn.default.enabled 2>/dev/null`
if [ "$autovpn_en" == "1" ]; then
        rt_vpnc=`uci get network.autovpn.lookup 2>/dev/null`
        if [ "$rt_vpnc" == "openvpn" ] || [ "$rt_vpnc" == "autovpn" ] || [ "$rt_vpnc" == "" ]; then
                autovpn_dns=`uci get autovpn.default.dns_server 2>/dev/null`
                if [ "$autovpn_dns" == "" ]; then
                         autovpn_dns="8.8.8.8"
                fi
                ip route add $autovpn_dns via $ifconfig_remote dev $dev metric 1194 2>/dev/null
        fi
fi
ip route add default via $ifconfig_remote dev $dev metric 4 table openvpn 2>/dev/null
ip route add default via $ifconfig_remote dev $dev metric 4 table autovpn 2>/dev/null

. /etc/init.d/updateopenvpnroute $dev $ifconfig_remote

if [ "$route_network_1" != "" ] && [ "$route_netmask_1" != "" ]; then
        iptables -w -t mangle -D mwan3_connected -d $route_network_1/$route_netmask_1 -j MARK --set-xmark 0xff00/0xff00 2>/dev/null
        iptables -w -t mangle -A mwan3_connected -d $route_network_1/$route_netmask_1 -j MARK --set-xmark 0xff00/0xff00 2>/dev/null
fi
if [ "$route_network_2" != "" ] && [ "$route_netmask_2" != "" ]; then
        iptables -w -t mangle -D mwan3_connected -d $route_network_2/$route_netmask_2 -j MARK --set-xmark 0xff00/0xff00 2>/dev/null 
        iptables -w -t mangle -A mwan3_connected -d $route_network_2/$route_netmask_2 -j MARK --set-xmark 0xff00/0xff00 2>/dev/null                     
fi
if [ "$route_network_3" != "" ] && [ "$route_netmask_3" != "" ]; then
        iptables -w -t mangle -D mwan3_connected -d $route_network_3/$route_netmask_3 -j MARK --set-xmark 0xff00/0xff00 2>/dev/null 
        iptables -w -t mangle -A mwan3_connected -d $route_network_3/$route_netmask_3 -j MARK --set-xmark 0xff00/0xff00 2>/dev/null                     
fi
if [ "$route_network_4" != "" ] && [ "$route_netmask_4" != "" ]; then
        iptables -w -t mangle -D mwan3_connected -d $route_network_4/$route_netmask_4 -j MARK --set-xmark 0xff00/0xff00 2>/dev/null 
        iptables -w -t mangle -A mwan3_connected -d $route_network_4/$route_netmask_4 -j MARK --set-xmark 0xff00/0xff00 2>/dev/null                     
fi
if [ "$route_network_5" != "" ] && [ "$route_netmask_5" != "" ]; then
        iptables -w -t mangle -D mwan3_connected -d $route_network_5/$route_netmask_5 -j MARK --set-xmark 0xff00/0xff00 2>/dev/null
        iptables -w -t mangle -A mwan3_connected -d $route_network_5/$route_netmask_5 -j MARK --set-xmark 0xff00/0xff00 2>/dev/null
fi
if [ "$route_network_6" != "" ] && [ "$route_netmask_6" != "" ]; then
        iptables -w -t mangle -D mwan3_connected -d $route_network_6/$route_netmask_6 -j MARK --set-xmark 0xff00/0xff00 2>/dev/null
        iptables -w -t mangle -A mwan3_connected -d $route_network_6/$route_netmask_6 -j MARK --set-xmark 0xff00/0xff00 2>/dev/null
fi
if [ "$route_network_7" != "" ] && [ "$route_netmask_7" != "" ]; then
        iptables -w -t mangle -D mwan3_connected -d $route_network_7/$route_netmask_7 -j MARK --set-xmark 0xff00/0xff00 2>/dev/null
        iptables -w -t mangle -A mwan3_connected -d $route_network_7/$route_netmask_7 -j MARK --set-xmark 0xff00/0xff00 2>/dev/null
fi
if [ "$route_network_8" != "" ] && [ "$route_netmask_8" != "" ]; then
        iptables -w -t mangle -D mwan3_connected -d $route_network_8/$route_netmask_8 -j MARK --set-xmark 0xff00/0xff00 2>/dev/null
        iptables -w -t mangle -A mwan3_connected -d $route_network_8/$route_netmask_8 -j MARK --set-xmark 0xff00/0xff00 2>/dev/null
fi

lock /tmp/service_state_log_lock
echo "Date:$daemon_start_time, Service:OpenVPN, State:Login" >> /ramlog/service_state_log
lock -u /tmp/service_state_log_lock
