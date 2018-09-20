#!/bin/bash

# This script is used for setting the BMC SPI flash. It creates the U-Boot
# script images to be used to install the generated images to the SPI flash
# and boot the target board.
#
# It expects a few variables to be set:
#   OBMC_SRC       : Path to OpenBMC source directory.
#   IMAGE_DIR      : The image binaries directory. We assume that
#                    image filename should be formatted properly:
#                       image-<name>   : Binary images
#                       rootfs.cpio.gz : Root FS archive.
#
#   TFTP_HOST      : Hostname or IP address of the TFTP server.
#   TFTP_DIR       : The target TFTP directory. Should be under '/tftp/'
#
#   NFS_HOST       : Hostname or IP address of the NFS server.
#   NFS_DIR        : The target NFS directory. Should be '/scratch/'

set -exo pipefail

# Set default variables.
OBMC_SRC=${OBMC_SRC:-.}
IMAGE_DIR=${IMAGE_DIR:-.}
TFTP_HOST=${TFTP_HOST:-lab-40}
TFTP_DIR=${TFTP_DIR:-/tftpboot/${USER}/evb}
NFS_HOST=${NFS_HOST:-lab-15}
NFS_DIR=${NFS_DIR:-/scratch/${USER}/evb}

# The list of images is passed as optional arguments
if [ $# -gt 0 ]; then
    echo "Install images: $*"
    images="$*"
else
    echo "WARNING: Nothing to install"
    exit 0
fi

# Setup scripts directory
SCRIPTS=${OBMC_SRC}/scripts/jenkins/test

# Prepare the target TFTP directory
ssh -n ${TFTP_HOST} \
    "rm -fr ${TFTP_DIR}; mkdir -p ${TFTP_DIR}"

# Get into the image directory.
cd ${IMAGE_DIR}

for image in $images; do
    if [ "$image" != "rootfs" ]; then
        # Check whether the image exist otherwise return an error.
        if [ ! -f "image-$image" ]; then
            echo "Cannot find image-$image in $(pwd)"
            exit 1
        fi

        # Copy images into the TFTP server
        echo "Remote copy image-$image to ${TFTP_HOST}:${TFTP_DIR}"
        scp image-$image ${TFTP_HOST}:${TFTP_DIR}

    else
        # Check whether the rootfs cpio exists otherwise return an error.
        if [ ! -f "$image.cpio.gz" ]; then
            echo "Cannot find $image.cpio.gz in $(pwd)"
            exit 1
        fi

        # Copy the Root File System into the NFS host.
        echo "Remote copy $image.cpio.gz to ${NFS_HOST}:${NFS_DIR}"
        ssh -n ${NFS_HOST} mkdir -p ${NFS_DIR}
        scp $image.cpio.gz ${NFS_HOST}:${NFS_DIR}

        # Setup the Root FS in the NFS host
        ipaddr=$(ssh -n ${NFS_HOST} hostname -i)
        passwd=fpga123
        nfspath=${NFS_DIR}
        echo "Configure the Root FS"
        ${SCRIPTS}/rootfs-configure.exp $ipaddr $passwd $nfspath
    fi
done

exit 0
