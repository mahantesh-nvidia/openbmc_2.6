#!/bin/sh

# Date modified: 02/18/2020

# This script checks if the ipmb_host driver loaded and
# if the BF is up via the BMC GPIO pins 218.
# If the check is true, then we try to load the ipmb_host module.
I2C12_DEV_PATH=/sys/bus/i2c/devices/i2c-12/new_device
I2C12_DEL_DEV_PATH=/sys/bus/i2c/devices/i2c-12/delete_device
IPMB_HOST_ADD=0x1020
SLAVE_ADD=0x11

if ! lsmod | grep ipmb_host &> /dev/null; then
	mlnx_powerstatus_bf

	if [ $? -eq 1 ]; then
		if modinfo ipmb_host &> /dev/null; then
			modprobe ipmb_host slave_add=$SLAVE_ADD
			echo ipmb-host $IPMB_HOST_ADD > $I2C12_DEV_PATH
			if [ ! -e "/dev/ipmi0" ]; then
				rmmod ipmb_host
				echo $IPMB_HOST_ADD > $I2C12_DEL_DEV_PATH
				exit 1
			fi
		fi
	fi
fi
