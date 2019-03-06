#!/bin/bash

# This build script is for U-Boot builds
#
# It expects a few variables to be set:
#   UBOOT_SRC   : Path to U-Boot sources.
#   UBOOT_BUILD : Path to U-boot build directory.
#   UBOOT_IMAGE : Path to U-boot binaries directory.

set -exo pipefail

# Get optional arguments
if [ $# -ge 1 ]; then
    UBOOT_DEFCONFIG=$1
fi
if [ $# -ge 2 ]; then
    PROGNAME=$(basename $0)
    echo "$PROGNAME: extra operand(s)"
    echo "Usage: $PROGNAME [DEFCONFIG_FILE]"
    exit 1
fi

# Default variables
UBOOT_SRC=${UBOOT_SRC:-.}
UBOOT_BUILD=${UBOOT_BUILD:-$(pwd)/build}
UBOOT_IMAGE=${UBOOT_IMAGE:-${UBOOT_BUILD}}
UBOOT_DEFCONFIG=${UBOOT_DEFCONFIG:-mlnxast2500bmc_defconfig}

# Set constant variables
UBOOT_FILENAME=$(basename $(realpath ${UBOOT_SRC}))
UBOOT_BUILD_DIR=${UBOOT_BUILD}/${UBOOT_FILENAME}

LOG=${UBOOT_BUILD_DIR}-build.log

# Remove the build directory.
rm -fr ${UBOOT_BUILD}

# Create the build directory.
mkdir -p ${UBOOT_BUILD_DIR}

# Timestamp for build start-up
echo "BMC U-Boot build started, $(date)" > ${LOG}

# Configure PATH
PATH=${PATH}:/auto/sw_soc_dev/tools/gcc/bmc-gcc-8.2.0/bin/arm-openbmc-linux-gnueabi

# Go into the u-boot directory and the script will put us
# in a build subdirectory.
cd ${UBOOT_SRC}

# Set compilation arguments for u-boot
COMPILE_ARGS="ARCH=arm CROSS_COMPILE=arm-openbmc-linux-gnueabi-"

# Configure u-boot
make ${COMPILE_ARGS} ${UBOOT_DEFCONFIG} O=${UBOOT_BUILD_DIR} \
    2>&1 | tee -a ${LOG}

# Kick off the build
make -j$(nproc) ${COMPILE_ARGS} O=${UBOOT_BUILD_DIR} \
    2>&1 | tee -a ${LOG}

# Copy target binaries
cp ${UBOOT_BUILD_DIR}/u-boot.bin ${UBOOT_IMAGE}/image-u-boot.bin

cat >> ${LOG} << EOF_DATA
echo "Build binaries are in ${UBOOT_IMAGE}"
echo "    U-Boot image         - image-u-boot.bin"
EOF_DATA

# Timestamp for build completion
echo "BMC U-boot build completed, $(date)" >> ${LOG}
