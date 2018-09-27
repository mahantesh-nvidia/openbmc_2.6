#!/bin/sh

echo "System entered recovery mode. Running from backup flash!!!
Please scp image file to /tmp folder and re-burn main flash with:
/run/initramfs/recovery /tmp/<bmc-image-file>.
";

mkdir /run/lock;

mount /dev/mtdblock5 /run/initramfs/rw -t jffs2 -o remount,ro;
mount tmpfs tmp -t tmpfs -o mode=755,nodev;

IP=`/sbin/fw_printenv ipaddr | sed -n "s/^ipaddr=//p"`;
NETMASK=`/sbin/fw_printenv netmask | sed -n "s/^netmask=//p"`;
GATEWAY=`/sbin/fw_printenv gatewayip | sed -n "s/^gatewayip=//p"`;

if [[ -n $IP && -n $NETMASK && -n $GATEWAY ]]; then
    ifconfig eth1 $IP netmask $NETMASK up;
    route add default gw $GATEWAY eth1;
else
    echo "No ipaddr, netmask or gatewayip env variable.";
fi;

source /etc/profile
export PS1="(recovery)\u@BMC:\w\$"

while true;
do
    sulogin;
done

