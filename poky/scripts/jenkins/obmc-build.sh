#!/bin/bash

# This build script is for OpenBMC builds
#
# It expects a few variables to be set:
#   OBMC_SRC    : Path to OpenBMC source directory.
#   OBMC_BUILD  : Path to OpenBMC build directory.
#   OBMC_RBUILD : Path to OpenBMC remote build directory.
#   OBMC_RIMAGE : Path to OpenBMC remote binary directory.
#   OBMC_BOARD  : Target board, either bluewhale or evb (mandatory).

set -exo pipefail

# Default variables
OBMC_SRC=${OBMC_SRC:-.}
OBMC_BUILD=${OBMC_BUILD:-$(pwd)/build}
OBMC_RBUILD=${OBMC_RBUILD:-${OBMC_BUILD}}
OBMC_RIMAGE=${OBMC_RIMAGE:-${OBMC_RBUILD}/images}

# Work out what build configuration we should be running and set
# bitbake command
case ${OBMC_BOARD} in
  bluewhale)
    TEMPLATECONF=meta-mellanox/meta-bluewhale-ast2500/conf
    BITBAKE_IMG="obmc-phosphor-image"
    ;;
  evb)
    TEMPLATECONF=meta-evb/meta-evb-aspeed/meta-evb-ast2500/conf
    BITBAKE_IMG="obmc-phosphor-image"
    ;;
  *)
    # Die if OBMC_BOARD isn't set.
    echo "Couldn't get the OBMC_BOARD variable from the environment."
    echo "Either you didn't set up OBMC_BOARD or it's empty."
    exit 1
    ;;
esac

# Set the build target
TARGET=${OBMC_BOARD}-ast2500

TARGETFILE=${OBMC_BUILD}/${TARGET}

# Set the target logfile
LOG=${TARGETFILE}.log

# Remove the last build directory, if needed. This MUST be revised
# if building multiple targets.
if [ -d ${OBMC_BUILD} ]; then
    echo "Cleaning up ${OBMC_BUILD}"
    rm -fr ${OBMC_BUILD}
fi

# Remove the remote build directory
rm -fr ${OBMC_RBUILD}
# Create the build directories.
mkdir -p ${OBMC_RBUILD} ${OBMC_BUILD}

# Go into the openbmc directory; the openbmc script will put us in
# a build subdirectory.
cd ${OBMC_SRC}

# Use a fixed path for repeatability.
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

if [ -f /etc/redhat-release ]; then
  if grep -q "release 6" /etc/redhat-release; then

      # Yocto requires a newer tar and python than is available on RHEL 6.
      # We add /home/global in that case if it is available; if not, you
      # must independently arrange for tar and python to be the right version.
      global=/home/global/Linux-x86_64-rhel6
      if [ -d $global ]; then
          echo 'Adding /home/global to $PATH for python 2.7/3.5 and newer tar'
          PATH=$global/python2.7:$global/bin:$PATH
      fi

      if [ ! -d /opt/rh/devtoolset-2 ]; then
        echo "Building Yocto requires devtoolset-2 to be installed on CentOS 6" >&2
        exit 1
      fi

      # Using the GCC 4.9 compiler from /auto/sw_tools/OpenSource/gcc/INSTALLS
      # causes some runtime issues with library versions when building
      # Yocto/Poky.  If we are on CentOS 6 we require devtoolset-2 to be
      # installed (GCC 4.8.2).  It is suggested you build on CentOS 7.
      echo "Using devtoolset-2 for GCC toolchain for CentOS 6"
      PATH=/opt/rh/devtoolset-2/root/usr/bin:$PATH
  elif grep -q "release 7" /etc/redhat-release; then
      # By default, git is found at /usr/bin and is version 1.8.3.
      # The new logic to create patches uses git pathspecs, which requires
      # a minimum of git 1.9.5.  Add /home/global/Linux-x86_64-rhel7 to the
      # PATH in order to bring in newer git (2.1.2) to BMC build.
      global=/home/global/Linux-x86_64-rhel7
      if [ -d $global ]; then
          echo 'Adding /home/global/Linux-x86_64-rhel7 to $PATH for newer git'
          PATH=$global/bin:$PATH
      fi
      if [ ! -f /usr/bin/python3 ]; then
          echo "Missing /usr/bin/python3; try yum install epel-release python34"
      fi
  else
      echo "Unsupported version of CentOS (CentOS 6 or 7 required)" >&2
      exit 1
  fi
else
  echo "CentOS 6 or 7 required for build: cannot find /etc/redhat-release" >&2
  exit 1
fi

# Print out build meta-data
cat << EOF_DATA > ${TARGETFILE}-metadata
# Remote build information
REMOTE_HOSTNAME  = $(hostname)
REMOTE_HOSTIP    = $(hostname -i)
REMOTE_BUILD_DIR = ${OBMC_RBUILD}
EOF_DATA

# Timestamp for build start-up
echo "${BITBAKE_IMG}: ${TARGET} build started, $(date)" > ${LOG}

# Source our build environment
source oe-init-build-env ${OBMC_RBUILD}

# Custom bitbake configuration settings
cat >> conf/local.conf << EOF_CONF
BB_NUMBER_THREADS = "$(nproc)"
PARALLEL_MAKE = "-j$(nproc)"
EOF_CONF

# Kick off a build
bitbake ${BITBAKE_IMG} 2>&1 | tee -a ${LOG}

# Catch build errors (if they exist)
grep "ERROR" ${LOG} >&2 ||:

# Create link to images for archiving
TARGET_IMGSL=${OBMC_RBUILD}/${TARGET}-images
ln -sf tmp/deploy/images/${TARGET} ${TARGET_IMGSL}

# Fetch BMC SPI flash images. Those images are packed into tarballs.
# File naming convention: {OBMC_BOARD}-{TIMESTAMP}.all.tar & .tar
BMC_FULL_IMAGE_TAR=$(ls ${TARGET_IMGSL}/${OBMC_BOARD}*.all.tar)
BMC_SEPA_IMAGE_TAR=$(ls ${TARGET_IMGSL}/${OBMC_BOARD}*.tar | grep -v 'all')
BMC_FULL_IMAGE_CNT=$(ls ${TARGET_IMGSL}/${OBMC_BOARD}*.all.tar | wc -l)
BMC_SEPA_IMAGE_CNT=$(ls ${TARGET_IMGSL}/${OBMC_BOARD}*.tar | grep -v 'all' | wc -l)

# Technically, the bitbake build should have generated a single tarball
# that contains the full bmc image and a single tarball that contains
# the separate images. Thus, return an error if more than one (or any)
# tarball of each is detected.
if [ ${BMC_FULL_IMAGE_CNT} -ne 1 ] || [ ${BMC_SEPA_IMAGE_CNT} -ne 1 ]; then
    echo "Cannot copy SPI flash images."
    exit 1
fi

# Fetch the Root File System
BMC_ROOTFS_TAR=$(ls ${TARGET_IMGSL}/*rootfs.squashfs-xz)
BMC_ROOTFS_CNT=$(ls ${TARGET_IMGSL}/*rootfs.squashfs-xz | wc -l)

if [ ${BMC_ROOTFS_CNT} -ne 1 ]; then
    echo "Cannot copy the Root File System."
    exit 1
fi

# Create the image directory.
mkdir -p ${OBMC_RIMAGE}

# Decompress tarball into the BMC images directory
tar -xf ${BMC_SEPA_IMAGE_TAR} -C ${OBMC_RIMAGE}

# Copy the rootfs archive to the image directory
cp ${BMC_ROOTFS_TAR} ${OBMC_RIMAGE}

# Copy BMC full image with timestamp in name
# File naming convention: obmc-phosphor-image-{OBMC_BOARD}-{TIMESTAMP}.static.mtd
BMC_FULL_TIMESTAMP_IMAGE=$(ls ${TARGET_IMGSL}/obmc-phosphor-image-${TARGET}-*.static.mtd)
cp ${BMC_FULL_TIMESTAMP_IMAGE} ${OBMC_RIMAGE}

# Create softlink for image-bmc
ln -sf $(basename ${BMC_FULL_TIMESTAMP_IMAGE}) ${OBMC_RIMAGE}/image-bmc

# Create MD5 checksum for BMC full image with timestamp in name
md5sum ${BMC_FULL_TIMESTAMP_IMAGE} > ${OBMC_RIMAGE}/$(basename ${BMC_FULL_TIMESTAMP_IMAGE}).md5sum

# Copy BMC tarball for customer use
# File naming convention: BlueField-BMC-<version>.tar.xz
BMC_CUSTOMER_TARBALL=$(ls ${TARGET_IMGSL}/BlueField-BMC-*.tar.xz)
cp ${BMC_CUSTOMER_TARBALL} ${OBMC_RIMAGE}

# Create MD5 checksum for BMC tarball
md5sum ${BMC_CUSTOMER_TARBALL} > ${OBMC_RIMAGE}/$(basename ${BMC_CUSTOMER_TARBALL}).md5sum

# Generate the BMC datetime based off field in full image filename
BMC_DATETIME=`echo $(basename ${BMC_FULL_TIMESTAMP_IMAGE}) | cut -d "-" -f 6 | cut -d "." -f 1`

# Copy BMC U-Boot image with version in name, giving it new name with timestamp
BMC_UBOOT_VERSION_IMAGE=$(ls ${TARGET_IMGSL}/u-boot-${TARGET}-*)
cp ${BMC_UBOOT_VERSION_IMAGE} ${OBMC_RIMAGE}/u-boot-${TARGET}-${BMC_DATETIME}

# Create softlink for image-u-boot
rm ${OBMC_RIMAGE}/image-u-boot
ln -sf u-boot-${TARGET}-${BMC_DATETIME} ${OBMC_RIMAGE}/image-u-boot

# Create MD5 checksum for BMC U-Boot image with version in name
md5sum ${BMC_UBOOT_VERSION_IMAGE} > ${OBMC_RIMAGE}/u-boot-${TARGET}-${BMC_DATETIME}.md5sum

# Timestamp for build completion
echo "${BITBAKE_IMG}: ${TARGET} build completed, $(date)" >> ${LOG}
