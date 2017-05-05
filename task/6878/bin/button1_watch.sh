#!/bin/sh

passtime=0

while true
do
	echo "none" > /sys/class/leds/wlan-run/trigger
	echo "0" > /sys/class/leds/wlan-run/brightness
	sleep 1
	passtime=$((passtime+1))
done
