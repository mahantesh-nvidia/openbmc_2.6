#!/bin/sh

# Date modified: 08/26/2019

# This script checks if the IPMB driver is not yet loaded and
# if the BF is up via the BMC GPIO pins 218.
# If the check is true, then we try to load the IPMB module.
I2C12_DEV_PATH=/sys/bus/i2c/devices/i2c-12/new_device
IPMB_HOST_ADD=0x1020
SLAVE_ADD=0x12

if ! lsmod | grep ipmb_host &> /dev/null; then
	mlnx_powerstatus_bf

	if [ $? -eq 1 ]; then
		if modinfo ipmb_host &> /dev/null; then
			modprobe ipmb_host slave_add=$SLAVE_ADD
			last_msg=$(dmesg | grep ipmb-host | tail -1 | cut -f 2 -d ":")
			if [ $last_msg == " probe of 12-0020 failed with error -5" ]; then
				# This means that although the BF is up, it has not
				# yet loaded the IPMB driver. So, try again later.
				rmmod ipmb_host
				exit 1
			fi
			echo ipmb-host $IPMB_HOST_ADD > $I2C12_DEV_PATH
		fi
	fi
fi
