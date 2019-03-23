#!/bin/sh

# Version 0.1

# This script utilizes fw_printenv and fw_setenv to synchronize
# MAC address information from primary U-Boot environment to the
# backup U-Boot environment.

# Assumptions: MAC addresses ('ethaddr' and 'eth1addr') are valid
#              and intact in primary U-Boot environment
#
#              The MAC address 'eth2addr' for RSHIM is not synced,
#              but the logic could be extended to do so.
#

# Check if we're running out of backup flash based on WDT2 Timeout Status
# Register; if bit1 (0x2) is set it indicates 'second boot code' i.e. CS1
FLASH_CP=`/sbin/devmem 0x1e785030`
FLASH_CP=$(($FLASH_CP & 0x02))

# Exit script if running from backup, only want to run from primary
# so that field upgradeable primary image is always in control
if [ $FLASH_CP == 2 ]; then
    # Silently exit
    exit 0
fi

# Read first MAC address from primary U-Boot env
primary_ethaddr=`/sbin/fw_printenv ethaddr`
if [ $? -ne 0 ] ; then
    echo Error reading ethaddr value from primary flash
    exit 1
fi

# Read second MAC address from primary U-Boot env
primary_eth1addr=`/sbin/fw_printenv eth1addr`
if [ $? -ne 0 ] ; then
    echo Error reading eth1addr value from primary flash
    exit 1
fi

primary_mac=`echo $primary_ethaddr | cut -d "=" -f 2`
primary_mac1=`echo $primary_eth1addr | cut -d "=" -f 2`

# Read both MAC addresses from backup U-Boot env
backup_ethaddr=`/sbin/fw_printenv -c /etc/alt_fw_env.config ethaddr`
backup_eth1addr=`/sbin/fw_printenv -c /etc/alt_fw_env.config eth1addr`

# No need to check for fw_printenv errors, if it fails the
# value returned will be empty and will trigger sync anyway

backup_mac=`echo $backup_ethaddr | cut -d "=" -f 2`
backup_mac1=`echo $backup_eth1addr | cut -d "=" -f 2`

# If backup 'ethaddr' does not exist or is different
# from primary 'ethaddr', then set it in backup flash
if [ -z $backup_mac ] || [ $primary_mac != $backup_mac ]; then
    echo Primary ethaddr $primary_mac Backup ethaddr $backup_mac, will sync
    /sbin/fw_setenv -c /etc/alt_fw_env.config ethaddr $primary_mac
fi

# If backup 'eth1addr' does not exist or is different
# from primary 'eth1addr', then set it in backup flash
if [ -z $backup_mac1 ] || [ $primary_mac1 != $backup_mac1 ]; then
    echo Primary eth1addr $primary_mac1 Backup eth1addr $backup_mac1, will sync
    /sbin/fw_setenv -c /etc/alt_fw_env.config eth1addr $primary_mac1
fi

# Exit successfully
exit 0