#!/bin/bash

# This script is used to boot up the target board into Linux with no more
# than U-Boot residing on it. It generates the U-Boot script images to be
# called eventually when booting the target board.
#
# It expects a few variables to be set:
#   UBOOT_FILE     : Boot file that will be converted to script image.
#   TFTP_DIR       : The target TFTP directory. Should be under /tftp
#
#   NFS_ROOTFS     : Path to the target NFS directory that contains the
#                    Root File System (rootfs) to be mounted during the
#                    boot.
#   NFS_HOST_IP    : NFS server IP address (default: lab-15[10.15.4.82]).
#
#   TARGET_IP      : Static IP address to be assigned to the target once
#                    booted into Linux (default: 10.15.8.13).

set -exo pipefail

# Set default variables.
UBOOT_FILE=${UBOOT_FILE:-boot}
TFTP_DIR=${TFTP_DIR:-/tftpboot/${USER}}
NFS_ROOTFS=${NFS_ROOTFS:-/scratch/${USER}/evb/rootfs}
NFS_HOST_IP=${NFS_HOST_IP:-10.15.4.82}
TARGET_IP=${TARGET_IP:-10.15.8.13}

# The list of images is passed as optional arguments
if [ $# -gt 0 ]; then
    echo "Boot images: $*"
    images="$*"
else
    echo "Boot with the actual flash image"
    images=
fi

# Custom U-Boot script
UBOOT_SCRIPT=${UBOOT_FILE}
cat > ${UBOOT_SCRIPT} << EOF_SCRIPT
echo "============= U-Boot script- Start ============="
EOF_SCRIPT

# Remove the parent directory '/tftp/' from the test
# directory path; the tftp command start fetching
# images in /tftpboot/*.
tftpdir=$(echo ${TFTP_DIR} | sed 's#/tftpboot/##')

# Set default 'bootm' arguments.
kernel_addr=0x20070000
initramfs_addr=0x20300000
dtb_addr=0x202f0000

for image in $images; do

    loadaddr=

    # Set the 'loadaddr' used when running tftp command
    # to load images
    if [ "$image" == "kernel" ]; then
        loadaddr=0x80000000
        kernel_addr=$loadaddr
    elif [ "$image" == "dtb" ]; then
        # TBD Figure out how u-boot decompresses and loads
        # the kernel image to the RAM. Is this done before
        # loading the DTB or after.
        loadaddr=0x80280000
        dtb_addr=$loadaddr
    elif [ "$image" == "rootfs" ]; then
        initramfs_addr=-
        rootpath=${NFS_ROOTFS}
        nfsserverip=${NFS_HOST_IP}
        ipaddr=${TARGET_IP}

        cat >> ${UBOOT_SCRIPT} << EOF_CONF
echo "============= NFS settings ============="
setenv nfsargs 'setenv bootargs \${bootargs} root=/dev/nfs rw nfsroot=${nfsserverip}:${rootpath}'
setenv addip 'setenv bootargs \${bootargs} ip=${ipaddr}:${nfsserverip}:\${gatewayip}:\${netmask}:\${hostname}::off'
run nfsargs addip
EOF_CONF
    fi

    if [ ! -z "$loadaddr" ]; then
        if [ "$image" == "kernel" ] || [ "$image" == "dtb" ]; then
            image_file=$tftpdir/image-$image
            cat >> ${UBOOT_SCRIPT} << EOF_CONF
echo "============= $image settings ============="
setenv load_$image 'tftp ${loadaddr} ${image_file}'
run load_$image
EOF_CONF
        fi
    fi

done

# Setup the 'bootm' arguments
cat >> ${UBOOT_SCRIPT} << EOF_ADDR
echo "============= Bootm settings ============="
setenv kernel_addr $kernel_addr
setenv initramfs_addr $initramfs_addr
setenv dtb_addr $dtb_addr
echo "============= U-Boot script- End ============="
EOF_ADDR

# Clean up the u-boot script; remove empty lines so they are not
# considered as empty commands. Note that an empty command in
# u-boot causes the last command to be re-executed.
sed -i '/^\s*$/d' ${UBOOT_SCRIPT}

echo "${UBOOT_SCRIPT} is created"
exit 0
