#!/bin/bash

# This script is used for booting the target board.
#
# It expects a few variables to be set:
#   OBMC_SRC       : Path to OpenBMC source directory
#   BOOT_DIR       : Local boot directory
#   BMC_IMAGES     : List of BMC flash images to be tested
#   BMC_TARGET     : Target board. Default target is 'evb'
#   TFTP_HOST_PATH : Path to the TFTP directory in the TFTP host
#   NFS_HOST_PATH  : Path to the NFS directory in the NFS host

set -exo pipefail

# Set default variables
OBMC_SRC=${OBMC_SRC:-.}
BOOT_DIR=${BOOT_DIR:-$(pwd)/boot}
BMC_IMAGES=${BMC_IMAGES:-}
BMC_TARGET=${BMC_TARGET:-evb}
TFTP_HOST_PATH=${TFTP_HOST_PATH:-lab-40:/tftpboot/${USER}/${BMC_TARGET}}
NFS_HOST_PATH=${NFS_HOST_PATH:-lab-15:/scratch/${USER}/${BMC_TARGET}}

# Target board is passed as an optional argument
if [ $# -ge 1 ]; then
    BOOT_OPT=$1
fi
if [ $# -ge 2 ]; then
    PROGNAME=$(basename $0)
    echo "$PROGNAME: extra operand(s)"
    echo "Usage: $PROGNAME [flash|network|reset]"
    exit 1
fi

# Setup scripts directory
SCRIPTS=${OBMC_SRC}/scripts/jenkins/test

# Set the file that will be generated and converted to U-Boot
# script image. The script would be used to boot-up the board.
UBOOT_FILE=${BOOT_DIR}/setenv-${BOOT_OPT}-boot.txt

# The U-Boot script image that is used to bootup the target.
# This must be consistent with the U-Boot Env image already
# installed in the SPI flash.
TFTP_UBOOT_ENV=/tftpboot/setenv.img

# Get NFS information
NFS_ROOT_PATH=$(echo ${NFS_HOST_PATH} | cut -d':' -f2)
NFS_HOST=$(echo ${NFS_HOST_PATH} | cut -d':' -f1)
NFS_HOST_IP=$(ssh -n ${NFS_HOST} hostname -i)

# Get TFTP information
TFTP_DIR=$(echo ${TFTP_HOST_PATH} | cut -d':' -f2)
TFTP_HOST=$(echo ${TFTP_HOST_PATH} | cut -d':' -f1)

# Work out what remote target where we should be running our tests
case ${BMC_TARGET} in
    bluewhale)
        # TBD - Basically check if there is at least an available
        # board to be used for testing, then setup its corresponding
        # parameters.

        # Note that currently we are using the EVB to test BlueWhale
        # images. So use the same parameters. This would be updated
        # very soon.
        echo "ERROR: ${BMC_TARGET} isn't supported yet."
        exit 1
        ;;
    evb)
        # Big assumption: The target IP address must be static. This
        # might be done by appending the option 'ip=' to 'bootargs'.
        TARGET_IP=10.15.8.13
        TARGET_BOOT_TIMEOUT=2m
        TARGET_BOOT_ARGS="${TARGET_IP} admin"
        ;;
    *)
        # Die if BMC_TARGET isn't supported.
        echo "ERROR: ${BMC_TARGET} isn't supported"
        exit 1
        ;;
esac

# Create the test directory, if needed
if [ ! -d "${BOOT_DIR}" ]; then
    mkdir -p ${BOOT_DIR}
fi

# Setup the boot status file. This latter will contain
# the images that has been installed to the target board.
# If target board booted successfully then the status file
# is removed. Otherwise, it is used to backup the flash.
BOOT_STATUS=${BOOT_DIR}/boot.status

# Work out what boot option we should be setting.
case ${BOOT_OPT} in
    network)
        # Network boot the target board.
        ssh -n ${TFTP_HOST} \
            env UBOOT_FILE=${UBOOT_FILE} \
                TFTP_DIR=${TFTP_DIR} \
                NFS_ROOTFS=${NFS_ROOT_PATH}/rootfs \
                NFS_SRV_IP=${NFS_HOST_IP} \
                TARGET_IP=${TARGET_IP} \
            ${SCRIPTS}/network-boot.sh ${BMC_IMAGES}
        echo "Network boot ${BMC_TARGET} board at ${TARGET_IP}"
        ;;
    flash)
        # Boot the target board from the flash.
        ssh -n ${TFTP_HOST} \
            env UBOOT_FILE=${UBOOT_FILE} \
                TFTP_DIR=${TFTP_DIR} \
            ${SCRIPTS}/flash-boot.sh ${BMC_IMAGES}
        echo "${BMC_IMAGES}" > ${BOOT_STATUS}
        echo "Boot from flash ${BMC_TARGET} board at ${TARGET_IP}"
        ;;
    reset)
        # This option is intended to cover the auto-recovery
        # case where images are corrupted. If network boot was
        # performed last then simply boot from flash.
        # Otherwise, load and install backup images, then boot
        # from flash.
        if [ ! -f "${BOOT_STATUS}" ]; then
            ssh -n ${TFTP_HOST} \
                env UBOOT_FILE=${UBOOT_FILE} \
                    TFTP_DIR=${TFTP_DIR} \
                ${SCRIPTS}/flash-boot.sh
        else
            # Boot status file holds the list of images previously
            # installed. So, simply reinstall the images.
            images=$(cat ${BOOT_STATUS})
            ssh -n ${TFTP_HOST} \
                env UBOOT_FILE=${UBOOT_FILE} \
                    TFTP_DIR=${TFTP_DIR}/backup \
                ${SCRIPTS}/flash-boot.sh $images
        fi
        echo "Boot reset ${BMC_TARGET} board at ${TARGET_IP}"
        ;;
    *)
        # Default: boot with the actual SPI flash image.
        ssh -n ${TFTP_HOST} \
            env UBOOT_FILE=${UBOOT_FILE} \
                TFTP_DIR=/tftp/recovery \
            ${SCRIPTS}/flash-boot.sh
        echo "Default boot ${BMC_TARGET} board at ${TARGET_IP}"
        ;;
esac

# Set PATH so we can use 'mkimage' to generate the script
PATH=$PATH:/auto/sw_soc_dev/tools/gcc/bmc-gcc-8.2.0/bin/arm-openbmc-linux-gnueabi

# Get the script image filename
UBOOT_SCRIPT_IMG=${BOOT_DIR}/$(basename ${TFTP_UBOOT_ENV})

# Convert the generated test file into U-Boot image script
mkimage -T script -C none -n 'Boot Script' \
    -d ${UBOOT_FILE} ${UBOOT_SCRIPT_IMG}

# Finally remote copy the script image to the TFTP server.
scp ${UBOOT_SCRIPT_IMG} ${TFTP_HOST}:${TFTP_UBOOT_ENV}
# Since the u-boot is configured to boot with this unique file, then
# allow all users to overwrite the boot script image.
ssh -n ${TFTP_HOST} "chmod 777 ${TFTP_UBOOT_ENV}"
echo "U-Boot script in ${TFTP_HOST}:${TFTP_UBOOT_ENV} is ready"

#
# TBD (This would be uncommented once the u-boot environment is
# set properly to support tests, i.e. boot with 'setenv.img')
#
# Boot up the target; The U-Boot environment will download the
# the u-boot script image "setenv.img", source it and boot the
# Linux.
#
#
# # Boot the target board with the new images. Note that we will be
# # using exept script to interact with the target.
# ${SCRIPTS}/target-boot.exp ${TARGET_BOOT_ARGS}
#
# # Wait until we can connect to the target board
# sleep ${TARGET_BOOT_TIMEOUT}
#
# ssecs=`date +%s`
# timeout=300
# while ! ping -c 1 ${TARGET_IP} &> /dev/null; do
#     if [ `date +%s` -gt `expr $ssecs + $tiemout` ]; then
#         echo "Failed to reboot the target"
#         echo "Either the network interface is down or kernel crashed"
#         # This means that the target is not viable and
#         # board power cycle is needed. Before issuing
#         # the command, we have to copy the backup images
#         # and U-Boot scripts to the TFTP server. Finally
#         # we have to verify whether the auto-recovery is
#         # successful.
#         exit 1
#     fi
#     echo "Ping failed. Retry in 3s..."
#     sleep 3
# done
#
# echo "The target ${TEST_TARGET} at ${TARGET_IP} is viable"
exit 0
