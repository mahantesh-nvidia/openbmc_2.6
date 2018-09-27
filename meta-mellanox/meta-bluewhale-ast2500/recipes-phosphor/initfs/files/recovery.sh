#!/bin/sh
#
# Script to burn entire 32MB of BMC SPI Flash 1
#
# Usage:
#    a) Local: /run/initramfs/recovery <bmc-image-file>
#
# Assumptions:
#    <bmc-image-file> is a 32MB file representing all partitions in BMC SPI Flash
#    <bmc-image-file> exists on local filesystem
#    /dev/mtd0 represents entire BMC SPI Flash device
#    /dev/mtd4 is a SQUASHFS filesystem (rofs) partition
#    /dev/mtd5 is a JFFS2 filesystem (rwfs) partition
#

if [ -f $1 ]
then
   echo $0: Update BMC SPI Flash with $1
else
   echo $0: File $1 not found on target, exiting
   exit
fi

echo $0: Remounting rwfs "(/dev/mtd5)" as read-only
mount /dev/mtdblock5 /run/initramfs/rw -t jffs2 -o remount,ro

echo $0: Unmounting rofs "(/dev/mtd4)"
umount /dev/mtdblock4

# Write bit1 of WDT2 Clear Timeout Status Register to clear status
/sbin/devmem 0x1e785034 l 0x01;

MAC=`/sbin/fw_printenv ethaddr | sed -n "s/^ethaddr=//p"`
MAC1=`/sbin/fw_printenv eth1addr | sed -n "s/^eth1addr=//p"`

echo $0: Burning SPI Flash "(/dev/mtd0)" with image "$1"
/usr/sbin/flashcp -v $1 /dev/mtd0

if [ -v $MAC ]; then
    echo "MAC env variable not exist. Set eth0 MAC from eeprom."
    MAC=`hexdump -n 6 -s 121 -v -e '/1 "%02x:"' /sys/bus/i2c/devices/6-0055/eeprom`;MAC=${MAC::-1};
else
    echo "MAC env variable exist. Set eth0 MAC from env."
fi;
/sbin/fw_setenv ethaddr $MAC

if [ -v $MAC1 ]; then
    echo "MAC1 env variable not exist. Set eth1 MAC from eeprom."
    MAC1=`hexdump -n 6 -s 127 -v -e '/1 "%02x:"' /sys/bus/i2c/devices/6-0055/eeprom`;MAC1=${MAC1::-1};
else
    echo "MAC1 env variable exist. Set eth1 MAC from env."
fi;
/sbin/fw_setenv eth1addr $MAC1

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


