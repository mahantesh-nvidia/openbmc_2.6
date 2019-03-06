#!/bin/bash

# This build script is for Linux kernel builds
#
# It expects a few variables to be set:
#   LINUX_KSRC        : Path to Linux kernel sources.
#   LINUX_KBUILD      : Path to Linux kernel build directory.
#   LINUX_KIMAGE      : Path to Linux kernel binaries directory.

set -exo pipefail

# Get optional arguments
if [ $# -ge 1 ]; then
    LINUX_DEFCONFIG=$1
fi
if [ $# -ge 2 ]; then
    LINUX_DT_FILENAME=$2
fi
if [ $# -ge 3 ]; then
    PROGNAME=$(basename $0)
    echo "$PROGNAME: extra operand(s)"
    echo "Usage: $PROGNAME [DEFCONFIG_FILE] [DT_FILENAME]"
    exit 1
fi

# Set default variables, if needed.
LINUX_KSRC=${LINUX_KSRC:-.}
LINUX_KBUILD=${LINUX_KBUILD:-$(pwd)/build}
LINUX_KIMAGE=${LINUX_KIMAGE:-${LINUX_KBUILD}}
LINUX_DEFCONFIG=${LINUX_DEFCONFIG:-mlx_bmc_defconfig}
LINUX_DT_FILENAME=${LINUX_DT_FILENAME:-aspeed-bmc-mlx-bluewhale}

# Set constant variables
KSRC=$(basename $(realpath ${LINUX_KSRC}))
KBUILD_DIR=${LINUX_KBUILD}/${KSRC}

LOG=${LINUX_KBUILD}/${KSRC}-build.log

# Remove the build directory.
rm -fr ${LINUX_KBUILD}

# Create the build directory.
mkdir -p ${KBUILD_DIR}

# Timestamp for build start-up
echo "BMC Linux kernel build started, $(date)" > ${LOG}

# Configure PATH
PATH=${PATH}:/auto/sw_soc_dev/tools/gcc/bmc-gcc-8.2.0/bin/arm-openbmc-linux-gnueabi

# Go into the linux directory and the script will put us
# in a build subdirectory.
cd ${LINUX_KSRC}

# Set compilation arguments for the kernel
COMPILE_ARGS="ARCH=arm CROSS_COMPILE=arm-openbmc-linux-gnueabi-"

# Configure the kernel
make ${COMPILE_ARGS} ${LINUX_DEFCONFIG} O=${KBUILD_DIR} \
    2>&1 | tee -a ${LOG}

# Kick off the build
BUILD_IMG_ARGS="uImage LOADADDR=0x80001000 ${LINUX_DT_FILENAME}.dtb modules"
make -j$(nproc) ${COMPILE_ARGS} O=${KBUILD_DIR} ${BUILD_IMG_ARGS} \
    2>&1 | tee -a ${LOG}

# Copy target binaries
KBUILD_BIN_DIR=${KBUILD_DIR}/arch/arm/boot
cp ${KBUILD_BIN_DIR}/uImage ${LINUX_KIMAGE}/image-kernel
cp ${KBUILD_BIN_DIR}/dts/${LINUX_DT_FILENAME}.dtb ${LINUX_KIMAGE}/image-dtb

cat >> ${LOG} << EOF_DATA
echo "Build binaries are in ${LINUX_KIMAGE}"
echo "    Kernel (uImage)   - image-kernel"
echo "    Device tree (DTB) - image-dtb"
EOF_DATA

# Timestamp for build completion
echo "BMC Linux kernel build completed, $(date)" >> ${LOG}
