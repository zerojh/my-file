#!/bin/sh

cdr_file_dir="/etc/freeswitch/"
cdr_file="cdr"
upload_file_dir="/tmp/"
upload_file="cdr.upload"
upload_tar=${upload_file}.tar.gz

cd ${cdr_file_dir}
if [ -e ${cdr_file} ]; then
	LOCKFILE="/tmp/cdr.lock"

	[ ! -e $LOCKFILE ] && touch $LOCKFILE
	exec 9<>$LOCKFILE
	flock 9

	cd ${upload_file_dir}
	[ -e ${upload_file} ] && rm ${upload_file} -rf
	lua /usr/bin/backup_cdr.lua ${upload_file_dir}${upload_file}

	flock -u 9

	cd ${upload_file_dir}
	if [ -e ${upload_file} ]; then
		tar -czf ${upload_tar} ${upload_file} && rm ${upload_file} -rf
		local truth=0
		local count=0
		while [ 0 = $truth ] && [ $count -lt 15 ]; do
			ret=$(curl http://172.16.221.100:4000/uploadCdr --form md5=$(md5sum ${upload_tar}) --form sn=2012-2013-2014-2016 --form compress=tar.gz --form file=@${upload_file_dir}${upload_tar})
			str=`echo $ret | grep 'true'`
			[ ! -z $str ] && truth=1
			count=$(($count+1))
			echo "`date ` upload" >> /tmp/cdr_upload_log
		done
	fi
fi
