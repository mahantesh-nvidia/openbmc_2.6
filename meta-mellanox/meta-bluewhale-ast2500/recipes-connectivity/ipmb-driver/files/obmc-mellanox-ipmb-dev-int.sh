#!/bin/sh

# Date modified: 02/18/2020

# This script checks if the ipmb_dev_int driver is loaded
# before trying to load it and instantiate the device at
# address 0x10.
I2C12_NEW_DEV_PATH=/sys/bus/i2c/devices/i2c-12/new_device
I2C12_DEL_DEV_PATH=/sys/bus/i2c/devices/i2c-12/delete_device
IPMB_DEV_INT_ADD=0x1010

if ! lsmod | grep ipmb_dev_int &> /dev/null; then
	if modinfo ipmb_dev_int &> /dev/null; then
		modprobe ipmb_dev_int
		echo ipmb-dev $IPMB_DEV_INT_ADD > $I2C12_NEW_DEV_PATH
		if [ ! -e "/dev/ipmb-12" ]; then
			rmmod ipmb_dev_int
			echo $IPMB_DEV_INT_ADD > $I2C12_DEL_DEV_PATH
			exit 1
		fi
	fi
fi
