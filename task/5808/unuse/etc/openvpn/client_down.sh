#!/bin/sh

echo "logout: server_ip:$trusted_ip:$trusted_port, proto:$proto_1, dev:$dev, dev_type:$dev_type,\
 local_ip:$ifconfig_local, gateway:$ifconfig_remote login_time:$daemon_start_time, logout_time:`date '+%s'`" \
 >> /ramlog/openvpnc_log

rm /var/run/openvpn_client_gw
iptables -w -t nat -D POSTROUTING -o $dev -j MASQUERADE 2>/dev/null

sed -i "/iptables -w -t nat -D POSTROUTING -o $dev -j MASQUERADE/d" /etc/firewall.vpn.reload
sed -i "/iptables -w -t nat -I POSTROUTING -o $dev -j MASQUERADE/d" /etc/firewall.vpn.reload

if [ "$route_network_1" != "" ] && [ "$route_netmask_1" != "" ]; then
        iptables -w -t mangle -D mwan3_connected -d $route_network_1/$route_netmask_1 -j MARK --set-xmark 0xff00/0xff00 2>/dev/null
fi
if [ "$route_network_2" != "" ] && [ "$route_netmask_2" != "" ]; then
        iptables -w -t mangle -D mwan3_connected -d $route_network_2/$route_netmask_2 -j MARK --set-xmark 0xff00/0xff00 2>/dev/null                     
fi
if [ "$route_network_3" != "" ] && [ "$route_netmask_3" != "" ]; then
        iptables -w -t mangle -D mwan3_connected -d $route_network_3/$route_netmask_3 -j MARK --set-xmark 0xff00/0xff00 2>/dev/null                     
fi
if [ "$route_network_4" != "" ] && [ "$route_netmask_4" != "" ]; then
        iptables -w -t mangle -D mwan3_connected -d $route_network_4/$route_netmask_4 -j MARK --set-xmark 0xff00/0xff00 2>/dev/null                     
fi
if [ "$route_network_5" != "" ] && [ "$route_netmask_5" != "" ]; then
        iptables -w -t mangle -D mwan3_connected -d $route_network_5/$route_netmask_5 -j MARK --set-xmark 0xff00/0xff00 2>/dev/null
fi
if [ "$route_network_6" != "" ] && [ "$route_netmask_6" != "" ]; then
        iptables -w -t mangle -D mwan3_connected -d $route_network_6/$route_netmask_6 -j MARK --set-xmark 0xff00/0xff00 2>/dev/null
fi
if [ "$route_network_7" != "" ] && [ "$route_netmask_7" != "" ]; then
        iptables -w -t mangle -D mwan3_connected -d $route_network_7/$route_netmask_7 -j MARK --set-xmark 0xff00/0xff00 2>/dev/null
fi
if [ "$route_network_8" != "" ] && [ "$route_netmask_8" != "" ]; then
        iptables -w -t mangle -D mwan3_connected -d $route_network_8/$route_netmask_8 -j MARK --set-xmark 0xff00/0xff00 2>/dev/null
fi

#defroute_vpn=`ip route | grep "default via $ifconfig_remote dev $dev"`
#echo "$defroute_vpn" >> /etc/openvpn/route.log
#if [ "$defroute_vpn" != "" ]; then
        ip route del 0.0.0.0/1 via $ifconfig_remote dev $dev 2>/dev/null
        #echo "ip route add 0.0.0.0/1 via $ifconfig_remote dev $dev 2>/dev/null" >> /etc/openvpn/route.log
        iptables -w -t mangle -D mwan3_connected -d 0.0.0.0/1 -j MARK --set-xmark 0xff00/0xff00 2>/dev/null
        ip route del 128.0.0.0/1 via $ifconfig_remote dev $dev 2>/dev/null
        #echo "ip route del 128.0.0.0/1 via $ifconfig_remote dev $dev 2>/dev/null" >> /etc/openvpn/route.log
        iptables -w -t mangle -D mwan3_connected -d 128.0.0.0/1 -j MARK --set-xmark 0xff00/0xff00 2>/dev/null
#fi

lock /tmp/service_state_log_lock
echo "Date:$daemon_start_time, Service:OpenVPN, State:Logout" >> /ramlog/service_state_log
lock -u /tmp/service_state_log_lock

