#!/bin/bash

# This script is used for setting the BMC SPI flash. It creates the U-Boot
# script images to be used to install the generated images to the SPI flash
# and boot the target board.
#
# It expects a few variables to be set:
#   UBOOT_FILE     : Boot file that will be converted to script image.
#   TFTP_DIR       : The target TFTP directory. Should be under /tftp

set -exo pipefail

# Set default variables.
UBOOT_FILE=${UBOOT_FILE:-boot}
TFTP_DIR=${TFTP_DIR:-/tftpboot/${USER}}

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

# Set the 'loadaddr' used when running tftp command
# to load images.
loadaddr=0x80000000

# Remove the parent directory '/tftp/' from the test
# directory path; the tftp command start fetching
# images in /tftpboot/*.
tftpdir=$(echo ${TFTP_DIR} | sed 's#/tftpboot/##')

for image in $images; do

    image_addr=
    image_size=

    if [ "$image" == "bmc" ]; then
        image_addr=0x20000000
        image_size=0x2000000
    elif [ "$image" == "kernel" ]; then
        image_addr=0x20070000
        image_size=0x280000
    elif [ "$image" == "dtb" ]; then
        image_addr=0x202f0000
        image_size=0x10000
    elif [ "$image" == "initramfs" ]; then
        image_addr=0x20300000
        image_size=0x1c0000
    elif [ "$image" == "rofs" ]; then
        image_addr=0x204c0000
        image_size=0x1740000
    elif [ "$image" == "rwfs" ]; then
        image_addr=0x21c00000
        image_size=0x400000
    fi

    if [ ! -z "$image_addr" ] && [ ! -z "$image_size" ]; then
        image_file=$tftpdir/image-$image

        # Load and install images into the 32MB SPI flash image. We only
        # protect 28MB of 32MB flash, leaving last 4MB writable for the
        # RW file system (image-rwfs).
        if [ "$image" == "bmc" ]; then
            ro_size=0x1c00000
            cat >> ${UBOOT_SCRIPT} << EOF_CONF
echo "============= Full $image settings ============="
setenv load_$image 'tftp ${loadaddr} ${image_file}'
setenv install_$image 'protect off ${image_addr} +${image_size};erase ${image_addr} +${image_size};cp.b ${loadaddr} ${image_addr} ${image_size};protect on ${image_addr} +${ro_size}'
run load_$image install_$image
EOF_CONF
        elif [ "$image" == "rwfs" ]; then
            cat >> ${UBOOT_SCRIPT} << EOF_CONF
echo "============= $image settings ============="
setenv load_$image 'tftp ${loadaddr} ${image_file}'
setenv install_$image 'protect off ${image_addr} +${image_size};erase ${image_addr} +${image_size};cp.b ${loadaddr} ${image_addr} ${image_size}'
run load_$image install_$image
EOF_CONF
        else
            cat >> ${UBOOT_SCRIPT} << EOF_CONF
echo "============= $image settings ============="
setenv load_$image 'tftp ${loadaddr} ${image_file}'
setenv install_$image 'protect off ${image_addr} +${image_size};erase ${image_addr} +${image_size};cp.b ${loadaddr} ${image_addr} ${image_size};protect on ${image_addr} +${image_size}'
run load_$image install_$image
EOF_CONF
        fi
    fi

done

# Setup the 'bootm' arguments
cat >> ${UBOOT_SCRIPT} << EOF_ADDR
echo "============= Bootm settings ============="
setenv kernel_addr 0x20070000
setenv initramfs_addr 0x20300000
setenv dtb_addr 0x202f0000
echo "============= U-Boot script- End ============="
EOF_ADDR

# Clean up the u-boot script; remove empty lines so they are not
# considered as empty commands. Note that an empty command in
# u-boot causes the last command to be re-executed.
sed -i '/^\s*$/d' ${UBOOT_SCRIPT}

echo "${UBOOT_SCRIPT} is created"
exit 0
