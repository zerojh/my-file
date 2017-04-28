#!/bin/sh

passtime=0

while true
do
	if [ $passtime -eq 0 ]; then
		echo "timer" > /sys/class/leds/uc100-run/trigger
		echo "500" > /sys/class/leds/uc100-run/delay_on
		echo "500" > /sys/class/leds/uc100-run/delay_off
	elif [ $passtime -eq 7 ]; then
		echo "timer" > /sys/class/leds/uc100-run/trigger
		echo "1000" > /sys/class/leds/uc100-run/delay_on
		echo "50" > /sys/class/leds/uc100-run/delay_off
	elif [ $passtime -eq 12 ]; then
		echo "timer" > /sys/class/leds/uc100-run/trigger
		echo "1000" > /sys/class/leds/uc100-run/delay_on
		echo "1000" > /sys/class/leds/uc100-run/delay_off
	fi
	sleep 1
	passtime=$((passtime+1))
done
