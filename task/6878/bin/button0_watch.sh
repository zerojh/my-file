#!/bin/sh

passtime=0

while true
do
	if [ $passtime -eq 7 ]; then
		sleep 1
		sync
		reboot -f
	fi
	sleep 1
	passtime=$((passtime+1))
done
