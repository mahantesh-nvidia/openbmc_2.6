#!/bin/sh

# Date modified: 04/19/2019

# This script checks if the IPMB driver is not yet loaded and
# if the BF is up via the BMC GPIO pins 218.
# If the check is true, then we try to load the IPMB module.

if ! lsmod | grep ipmb_host &> /dev/null; then
	mlnx_powerstatus_bf

	if [ $? -eq 1 ]; then
		if modinfo ipmb_host &> /dev/null; then
			modprobe ipmb_host
			last_msg=$(dmesg | grep ipmb-host | tail -1 | cut -f 2 -d ":")
			if [ $last_msg == " probe of 12-0020 failed with error -5" ]; then
				# This means that although the BF is up, it has not
				# yet loaded the IPMB driver. So, try again later.
				rmmod ipmb_host
			fi
		fi
	fi
fi
