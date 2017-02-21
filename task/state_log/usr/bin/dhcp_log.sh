#!/bin/sh

# action:
# "add": means a lease has been created
# "del": means it has been destroyed
# "old": is a notification of an existing lease when dnsmasq starts or a change to MAC address or hostname of an existing lease (also, lease length or expiry
date=`date '+%Y-%m-%d %H:%M:%S'`
action=$1
mac_addr=$2
ip_addr=$3
hostname=$4
echo "date:$date, param:$@" >> /tmp/aaaaaa
