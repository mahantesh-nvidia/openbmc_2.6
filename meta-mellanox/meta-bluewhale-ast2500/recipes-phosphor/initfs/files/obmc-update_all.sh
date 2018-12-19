#!/bin/sh
#
# Script to burn entire 32MB of BMC SPI Flash
#
# Usage:
#    a) Local: /run/initramfs/update_all <bmc-image-file> [-quiet]
#    b) Remote: sshpass -p "<root-password>" ssh root@<ip> 
#                  '/run/initramfs/update_all <bmc-image-file> [-quiet]'
#
# Assumptions:
#    <bmc-image-file> is a 32MB file representing all partitions in BMC SPI Flash
#    <bmc-image-file> exists on local filesystem
#    "bmc" MTD partition represents entire BMC SPI Flash device
#    /dev/mtd4 is a SQUASHFS filesystem (rofs) partition
#    /dev/mtd5 is a JFFS2 filesystem (rwfs) partition
#

version="12/19/2018"
echo $0: script version $version

if [ -z $1 ]
then
   echo $0: No BMC image file specified, exiting
   echo $0: syntax: update_all \<bmc-image-file\>
   exit 1
fi

if [ -f $1 ]
then
   echo $0: Update BMC SPI Flash with $1
else
   echo $0: File $1 not found on target, exiting
   exit 1
fi

# Get the total size (in hex) of the "bmc" partition
mtdsize=`cat /proc/mtd | grep bmc | cut -d " " -f2`

# Get size (in decimal) of BMC image file
imagesize=`wc -c $1 | cut -d " " -f1`

# Compare size of BMC image file to size of MTD partition
if [ $imagesize -ne $((0x${mtdsize})) ]
then
    echo Size of BMC image file must exactly match size of MTD partition, exiting
    exit 1
fi

# Retrieve current settings for U-Boot environment variables
# we want to restore after the full BMC image update
MAC=`/sbin/fw_printenv ethaddr | sed -n "s/^ethaddr=//p"`
MAC1=`/sbin/fw_printenv eth1addr | sed -n "s/^eth1addr=//p"`
BOOTCMD_STRING=`/sbin/fw_printenv bootcmd_string | sed -n "s/^bootcmd_string=//p"`

echo $0: Stopping system services
systemctl stop mlx_ipmid
systemctl stop avahi-daemon
systemctl stop busybox-klogd
systemctl stop busybox-syslogd
systemctl stop dbus
systemctl stop network-update-dns
systemctl stop obmc-phosphor-sysd
systemctl stop org.openbmc.*
systemctl stop systemd-networkd

echo $0: Remounting rwfs "(/dev/mtd5)" as read-only
mount /dev/mtdblock5 /run/initramfs/rw -t jffs2 -o remount,ro

echo $0: Unmounting rofs "(/dev/mtd4)"
umount /dev/mtdblock4

# Check if we're running out of backup flash based on WDT2 Timeout Status
# Register; if bit1 (0x2) is set it indicates 'second boot code' i.e. CS1
FLASH_CP=`/sbin/devmem 0x1e785030`
FLASH_CP=$(($FLASH_CP & 0x02))

# If running from backup, write bit1 of WDT2 Clear Timeout Status Register
# to clear status.  This allows next flash write to target primary bank (CS0)
# Allow the programming of backup flash while running in backup flash by
# specifying the "-backup" option on the command line.
if [ $FLASH_CP == 2 ]; then
    if [ -v $2 ] || [ $2 != "-backup" ]; then
        echo $0: Clearing WDT2 status to prepare for write to primary bank
        /sbin/devmem 0x1e785034 l 0x01;
    fi
fi

# Get the MTD number for the "bmc" partition
mtdnum=`cat /proc/mtd | grep bmc | cut -d ":" -f1`

# Use "-v" option for flashcp, unless command line specifies "-quiet"
if [ $2 ] && [ $2 == "-quiet" ] ; then
    verbose=
else
    verbose=-v
fi

# Make three attempts to burn BMC image with flashcp
for i in 1 2 3
do 
    echo $0: Burning SPI Flash "(/dev/$mtdnum)" with image "$1"
    /usr/sbin/flashcp $verbose $1 /dev/$mtdnum

    if [ $? -eq 0 ]; then
        echo $0: flashcp completed successfully
        break
    else
        echo $0: flashcp failed on attempt $i
        if [ $i -eq 3 ]; then
            echo $0: Excessive flashcp failures, boot BMC into recovery
            echo $0: mode by issuing the command \"reboot -f\" and then
            echo $0: in U-Boot issue the command \"run recovery_mode\"
            exit 1
        fi
    fi
done

# Restore the setting of bootcmd_string, this is where the user would set
# the bootm option to boot with a non-default fitImage configuration, e.g.
#    bootcmd_string=bootm 0x20070000#conf@aspeed-bmc-mlx-bluewhale2u.dtb
# to boot the Blue Whale 2U BMC.
if [ -z "$BOOTCMD_STRING" ]; then
    /sbin/fw_setenv bootcmd_string bootm 0x20070000
else
    /sbin/fw_setenv bootcmd_string $BOOTCMD_STRING
fi

if [ -v $MAC ] || [ $MAC == "ff:ff:ff:ff:ff:ff" ]; then
    echo "Valid MAC env variable does not exist. Set eth0 MAC from eeprom."
    MAC=`hexdump -n 6 -s 121 -v -e '/1 "%02x:"' /sys/bus/i2c/devices/6-0055/eeprom`
    MAC=${MAC::-1}
else
    echo "MAC env variable exists. Set eth0 MAC from env."
fi;

# If MAC address is all FF, EEPROM is likely not programmed
# In this case do not call "fw_setenv" with this bogus MAC
if [ $MAC == "ff:ff:ff:ff:ff:ff" ]; then
    /sbin/fw_setenv ethaddr
else
    /sbin/fw_setenv ethaddr $MAC
fi

if [ -v $MAC1 ] || [ $MAC1 == "ff:ff:ff:ff:ff:ff" ]; then
    echo "Valid MAC1 env variable does not exist. Set eth1 MAC from eeprom."
    MAC1=`hexdump -n 6 -s 127 -v -e '/1 "%02x:"' /sys/bus/i2c/devices/6-0055/eeprom`
    MAC1=${MAC1::-1}
else
    echo "MAC1 env variable exists. Set eth1 MAC from env."
fi;

# If MAC address is all FF, EEPROM is likely not programmed
# In this case do not call "fw_setenv" with this bogus MAC
if [ $MAC1 == "ff:ff:ff:ff:ff:ff" ]; then
    /sbin/fw_setenv eth1addr
else
    /sbin/fw_setenv eth1addr $MAC1
fi

echo $0: Rebooting BMC

# Use three calls to "devmem" to program WDT1 to do full chip reset

# Change WDT1 Counter Reload Value to be equivalent to 2 seconds
/sbin/devmem 0x1e785004 l 0x1e8480

# Write magic value to WDT1 Counter Restart Value to trigger 
# reload of WDT1 Counter Reload Value
/sbin/devmem 0x1e785008 l 0x4755

# Enable WDT1 Control Register to do full chip reset from default
# boot code source (CS0 Flash bank)
/sbin/devmem 0x1e78500C l 0x37
