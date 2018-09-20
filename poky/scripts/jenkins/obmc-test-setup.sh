#!/bin/bash

# This test script is for booting the target board and running
# regression tests.
#
# It expects a few variables to be set:
#   WORKSPACE  : Path to the Jenkins workspace directory
#   OBMC_SRC   : Path to OpenBMC source directory
#   IMAGES_DIR : Path to BMC binary images and rootfs

set -exo pipefail

# Set default variables
WORKSPACE=${WORKSPACE:-.}
OBMC_SRC=${OBMC_SRC:-${WORKSPACE}/src}
IMAGES=${IMAGES:-${WORKSPACE}/images}

# Setup the target board.
TEST_TARGET=evb

#
# Setup remote hosts
#
TFTP_HOST=lab-40
TFTP_DIR=/tftpboot/${USER}/${TEST_TARGET}

NFS_HOST=lab-15
NFS_DIR=/scratch/${USER}/${TEST_TARGET}

# Test option is passed as argument
if [ $# -eq 1 ]; then
    TEST_IMAGE=$1
else
    PROGNAME=$(basename $0)
    echo "$PROGNAME: extra operand(s)"
    echo "Usage: $PROGNAME IMAGE"
    exit 1
fi

# Work out what BMC images we should be booting
case ${TEST_IMAGE} in
    bmc-u-boot)
        # For now, we are not going to install the U-Boot
        # binaries to the flash in order to preserve the
        # state of the U-Boot Env. So skip the test.
        #
        #   BMC_IMAGES="u-boot u-boot-env"
        #   BMC_BOOT_OPT=flash
        #
        echo "WARNING: ${TEST_IMAGE} isn't supported yet."
        echo "Skip test ${TEST_IMAGE}."
        exit 0
        ;;
    bmc-linux)
        BMC_IMAGES="kernel dtb"
        BMC_BOOT_OPT=network
        ;;
    bmc-openbmc)
        # Test the 32MB BMC SPI flash image:
        #
        #   BMC_IMAGES="bmc"
        #   BMC_BOOT_OPT=flash
        #
        # For safety reason, we propose to network boot
        # the kernel and dtb images, mount the Root FS
        # via NFS to test the generated OpenBMC images.
        # If tests are successful, then we can install
        # the full BMC image to the flash. Note that the
        # U-Boot binaries won't be installed to the flash
        # in order to keep the state of the U-Boot Env
        # and continue testing (U-Boot is intended to be
        # tested manually, thus it is not part of those
        # tests)
        BMC_IMAGES="kernel dtb rootfs"
        BMC_BOOT_OPT=network
        ;;
    *)
        # Die if TEST_IMAGE isn't supported.
        echo "ERROR: ${TEST_IMAGE} isn't supported."
        exit 1
        ;;
esac

# Setup scripts directory
SCRIPTS=${OBMC_SRC}/scripts/jenkins/test

# Prepare the test directory
TESTS=${WORKSPACE}/tests
rm -fr ${TESTS}
mkdir -p ${TESTS}

#
# Install images into TFTP/NFS hosts.
#
env OBMC_SRC=${OBMC_SRC} \
    IMAGE_DIR=${IMAGES} \
    TFTP_HOST=${TFTP_HOST} \
    TFTP_DIR=${TFTP_DIR} \
    NFS_HOST=${NFS_HOST} \
    NFS_DIR=${NFS_DIR} \
${SCRIPTS}/image-install.sh ${BMC_IMAGES}

#
# Boot the target board.
#

# Note that we can boot-up several boards, if needed. In that
# case we have to append target names to TEST_TARGET, and run
# the script below for each target. This might be revised later.

# Call the boot-setup.sh script
env OBMC_SRC=${OBMC_SRC} \
    BOOT_DIR=${TESTS}/boot \
    BMC_IMAGES="${BMC_IMAGES}" \
    BMC_TARGET=${TEST_TARGET} \
    TFTP_HOST_PATH=${TFTP_HOST}:${TFTP_DIR} \
    NFS_HOST_PATH=${NFS_HOST}:${NFS_DIR} \
${SCRIPTS}/target-boot.sh ${BMC_BOOT_OPT}

# Check the boot status
if [ $? -eq 0 ]; then
    echo "Test boot: SUCCESS"
else
    echo "Test boot: FAILURE"
    # Call the boot-setup.sh script to reset the SPI flash
    env OBMC_SRC=${OBMC_SRC} \
        BOOT_DIR=${TESTS}/boot \
        BMC_IMAGES=${NETBOOT_IMAGES} \
        BMC_TARGET=${TEST_TARGET} \
        TFTP_HOST_PATH=${TFTP_HOST}:${TFTP_DIR} \
        NFS_HOST_PATH=${NFS_HOST}:${NFS_DIR} \
    ${SCRIPTS}/target-boot.sh reset
    exit 1
fi

# TODO Run regression tests
echo "Done!"

exit 0
