#!/bin/sh

# Date modified: 02/20/2019

# This script checks if the IPMB driver is not yet loaded and
# if the BF is up via the BMC GPIO pins 218.
# If the check is true, then we try to load the IPMB module.

if ! lsmod | grep ipmb_host &> /dev/null; then

	# From Aspeed GPIO driver sysfs, get base number for GPIO access
	GPIO_BASE=$(cat /sys/devices/platform/ahb/ahb:apb/1e780000.gpio/gpio/*/base)

	# Use base number to calculate GPIO numbers for pins 218
	GPIO_NUM_218=$(($GPIO_BASE + 218))

	# If any other script is using GPIO pin 218, exit this script,
	# and try again later.
	if [ -d /sys/class/gpio/gpio${GPIO_NUM_218} ]; then
		exit
	fi

	echo ${GPIO_NUM_218} > /sys/class/gpio/export

	# read current gpio pin values
	currval218=$(cat /sys/class/gpio/gpio${GPIO_NUM_218}/value)

	if [ $currval218 -eq 1 ]; then
		if modinfo ipmb_host &> /dev/null; then
			modprobe ipmb_host
		fi
	fi
	echo ${GPIO_NUM_218} > /sys/class/gpio/unexport
fi
