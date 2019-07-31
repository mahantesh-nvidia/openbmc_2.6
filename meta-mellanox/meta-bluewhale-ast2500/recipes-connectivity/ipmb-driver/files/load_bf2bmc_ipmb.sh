#!/bin/sh

# This script unloads the ipmb_host driver and
# loads the ipmb_dev_int driver. This enables
# the BMC to operate as the IPMB responder
# as opposed to the IPMB requester.
# So whenever the BMC receives an IPMB request
# from the BF, the ipmb_dev_int driver will handle
# the request and pass it to OpenIPMI. Once a response
# is ready, the driver will send it back to the BF.

IPMB_HOST_ADD=0x1020
IPMB_DEV_INT_ADD=0x1010
I2C_DEL_DEV_PATH=/sys/bus/i2c/devices/i2c-12/delete_device
I2C_NEW_DEV_PATH=/sys/bus/i2c/devices/i2c-12/new_device
LAN_CONF_FILE=/etc/ipmi/mlxbw.lan.conf

# stop the obmc-mellanox-ipmbd.service since it
# loads the ipmb_host driver by default at boot
# time.
systemctl stop obmc-mellanox-ipmbd.service

# remove the ipmb_host driver
rmmod ipmb_host
echo $IPMB_HOST_ADD > $I2C_DEL_DEV_PATH

# stop the mlx_ipmid.service since it is needs
# ipmb_dev_int to work for IPMB.
systemctl stop mlx_ipmid

# uncomment the ipmb command in the mlxbw.lan.conf file
sed -i '/ipmb 12/s/^#//g' $LAN_CONF_FILE

# Load the ipmb_dev_int driver
modprobe ipmb_dev_int
echo ipmb-dev $IPMB_DEV_INT_ADD > $I2C_NEW_DEV_PATH

# start the mlx_ipmid.service again.
systemctl start mlx_ipmid
