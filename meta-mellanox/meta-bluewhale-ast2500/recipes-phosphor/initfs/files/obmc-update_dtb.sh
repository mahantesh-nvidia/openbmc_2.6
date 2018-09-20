#!/bin/sh
#
# Script to burn new device tree to dtb partition on flash
#
# Usage:
#    a) Local: /run/initramfs/update_dtb <dtb-file>
#    b) Remote: sshpass -p "<root-password>" ssh root@<ip> '/run/initramfs/update_dtb <dtb-file>'
#

if [ -f $1 ]
then
   echo $0: Update Device Tree on BMC SPI Flash with $1
else
   echo $0: File $1 not found on target, exiting
   exit
fi

mtd_dev=$(cat /proc/mtd | grep dtb | cut -d ":" -f1)

# Check if the dtb is valid and if its size will fit the mtd partition
valid_word0="0dd0"
valid_word1="edfe"
dump_word0=$(hexdump -n 4 $1 | grep 0000000 | cut -d " " -f2)
dump_word1=$(hexdump -n 4 $1 | grep 0000000 | cut -d " " -f3)

if [ "$dump_word0" != "$valid_word0" ] || [ "$dump_word1" != "$valid_word1" ]; then
    echo $0: Invalid DTB file $1, exiting
    exit
fi

dtb_size=$(stat $1 | grep "Size" | cut -d ":" -f2 | cut -d " " -f2)
dtb_limit=$(cat /proc/mtd | grep dtb | cut -d " " -f2)

if [ $dtb_size -ge $((0x${dtb_limit})) ]; then
    echo $0: DTB size limit exceeded, exiting
    exit
fi

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

echo $0: Burning DTB in SPI Flash "(/dev/$mtd_dev)" with image "$1"
/usr/sbin/flashcp -v $1 /dev/$mtd_dev

if [ $? -ne 0 ]; then
    echo $0: Failed to update DTB in SPI Flash
    exit
fi

echo $0: Rebooting BMC
reboot
