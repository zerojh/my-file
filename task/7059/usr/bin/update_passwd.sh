#!/bin/sh

LOCKFILE="/tmp/pwd.lock"
[ ! -e $LOCKFILE ] && touch $LOCKFILE

exec 8<>$LOCKFILE
flock 8

date=`date '+%m/%d/%Y'`
date_md5=`echo -n $date | md5sum | awk -F '' '{print$1$4$7$10$13$16$19$22$25$28}'`
passwd=`echo -n ${date_md5:0:5} | tr '[a-f]' '[A-F]'`
passwd="$passwd${date_md5:5:5}"
(echo "$passwd"; sleep 1; echo "$passwd") | passwd "admin" >/dev/null 2>&1

cp /etc/config/system /etc/config/system_tmp
uci set system_tmp.main.pwd_date="$date"
uci commit system_tmp
mv /etc/config/system_tmp /etc/config/system

flock -u 8
