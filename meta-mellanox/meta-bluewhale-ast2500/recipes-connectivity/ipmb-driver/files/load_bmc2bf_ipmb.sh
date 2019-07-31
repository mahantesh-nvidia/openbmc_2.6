#!/bin/sh

# This script unloads the ipmb_dev_int driver and
# loads the ipmb_host driver. This enables
# the BMC to operate as the IPMB requester
# as opposed to the IPMB responder.

IPMB_DEV_INT_ADD=0x1010
I2C_DEL_DEV_PATH=/sys/bus/i2c/devices/i2c-12/delete_device
LAN_CONF_FILE=/etc/ipmi/mlxbw.lan.conf

# stop the mlx_ipmid.service since it uses
# ipmb_dev_int
systemctl stop mlx_ipmid

# comment out the ipmb command in the mlxbw.lan.conf file
sed -i '/ipmb 12/s/^/#/g' $LAN_CONF_FILE

# remove the ipmb_dev_int driver
rmmod ipmb_dev_int
echo $IPMB_DEV_INT_ADD > $I2C_DEL_DEV_PATH

# load the ipmb_host driver via
# obmc-mellanox-ipmbd.service
systemctl start obmc-mellanox-ipmbd.service

# restart the mlx_ipmid service
systemctl start mlx_ipmid
