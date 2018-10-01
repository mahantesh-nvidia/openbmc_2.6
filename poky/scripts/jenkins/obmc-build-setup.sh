#!/bin/bash

# This build script is for running the Jenkins builds
#
# It expects a few variables which are part of Jenkins build job:
#   WORKSPACE
#   EXECUTOR_NUMBER
#   GERRIT_PROJECT

set -exo pipefail

# Setup default variables
BUILD_TYPE={$BUILD_TYPE:-verify}

# Build process type is passed as an optional argument
if [ $# -ge 1 ]; then
    BUILD_TYPE=$1
fi
if [ $# -ge 2 ]; then
    PROGNAME=$(basename $0)
    echo "$PROGNAME: extra operand(s)"
    echo "Usage: $PROGNAME [nightly|verify]"
    exit 1
fi

# This script enables either verification builds or nightly builds.
# Nightly builds run every night and build OpenBMC with its dependancies
# (e.g., kernel, uboot, etc) from scratch. It checks out sources from our
# git repos that include the most recent version of the sources. Unlike
# nightly builds, verification builds are enabled upon changes submitted
# to gerrit for review.

# Constant variables
SRC=${WORKSPACE}/src
BUILD=${WORKSPACE}/build
IMAGE=${WORKSPACE}/images

# Setup the remote directory for building OpenBMC images. We expect
# that the build directory size is at least 21GB.
OBMC_RBUILD=/scratch/$USER/obmc-build/${BUILD_TYPE}
# Setup the remote images directory. This is intended to contain
# the build products that might be tested.
OBMC_RIMAGE=${OBMC_RBUILD}/images

# Set the OpenBMC target image to build
BUILD_TARGET=bluewhale
# Setup bitbake slave
BITBAKE_HOST=mtbu-yocto

# When running nightly builds only 'bmc-openbmc' repo is checked out
# by gerrit; the remaining sources/packages are downloaded later in
# the process.
if [ "${BUILD_TYPE}" = "nightly" ]; then
    OBMC_SRC=${SRC}
else
    OBMC_SRC=${SRC}/bmc-openbmc
fi

# Setup scripts directory
SCRIPTS=${OBMC_SRC}/scripts/jenkins

rm -fr ${BUILD} ${IMAGE}
# Create the build directory, if needed.
mkdir -p ${BUILD} ${IMAGE}

# If a verification build is requested then build the corresponding
# sources, i.e., u-boot, kernel or OpenBMC.
# WARNING: this does not handle co-dependent changes.
if [ "${BUILD_TYPE}" = "verify" ]; then
    # Work out what build we should be running
    case ${GERRIT_PROJECT} in
        bmc-u-boot)
             # Kick off the u-boot build
            env UBOOT_SRC=${SRC}/bmc-u-boot \
                UBOOT_BUILD=${BUILD} \
                UBOOT_IMAGE=${IMAGE} \
            ${SCRIPTS}/u-boot-build.sh mlnxast2500bmc_defconfig
            exit $?
            ;;
        bmc-linux)
            # Kick off the Linux build
            env LINUX_KSRC=${SRC}/bmc-linux \
                LINUX_KBUILD=${BUILD} \
                LINUX_KIMAGE=${IMAGE} \
            ${SCRIPTS}/kernel-build.sh mlx_bmc_defconfig aspeed-bmc-mlx-bluewhale
            exit $?
            ;;
        bmc-openbmc)
            # If the verification builds run in parallel, then we limit the
            # number of builds to the number of Jenkins executors (i.e., 8).
            OBMC_RBUILD=${OBMC_RBUILD}-${EXECUTOR_NUMBER}
            ;;
        *)
            # Die if GERRIT_PROJECT isn't set.
            echo "Couldn't get the GERRIT_PROJECT variable from the environment."
            echo "Either you didn't set up GERRIT_PROJECT or it's empty."
            exit 1
            ;;
    esac
fi

# This is a workaround to build OpenBMC without NFS support; since
# the sanity checker fails because TMPDIR can't be located on NFS,
# then apply a simple patch to fix it. The patch simply disables
# the checker.
sed -i '/status.addresult(check_not_nfs(tmpdir, "TMPDIR"))/d' \
    ${OBMC_SRC}/poky/meta/classes/sanity.bbclass

# Kick off the remote build; this should run for both nightly and OpenBMC
# verification.
ssh -n ${BITBAKE_HOST} \
env OBMC_BOARD=${BUILD_TARGET} \
    OBMC_BUILD=${BUILD} \
    OBMC_RBUILD=${OBMC_RBUILD} \
    OBMC_RIMAGE=${OBMC_RIMAGE} \
    OBMC_SRC=${OBMC_SRC} \
${SCRIPTS}/obmc-build.sh

# Check the remote build status
if [ $? -eq 0 ]; then
    # Copy bitbake build products.
    rsync -avz ${BITBAKE_HOST}:${OBMC_RIMAGE}/ ${IMAGE}
    echo "Remote build completed: SUCCESS"
else
    echo "Remote build completed: FAILURE"
    exit 1
fi

# Save the 'IMAGE' and 'BUILD' directories in a globally visible
# place. For now, we don't save the entire build tree, or the src
# tree, since it's larger than 20GB and there is no particular
# benefit.
if [ "${BUILD_TYPE}" = "nightly" ]; then
    GLOBAL_PROJECT=/auto/sw_soc_dev/bmc

    # Every nightly build will be in a directory named after the
    # build date, and a symbolic link is created to point to the
    # latest stable nightly.
    dir=`date -Idate`
    if [ -e ${GLOBAL_PROJECT}/$dir ]; then
        # Unexpected; perhaps we manually did an extra build
        suffix=1
        while [ -e ${GLOBAL_PROJECT}/$dir.$suffix ]; do
            suffix=$((suffix + 1))
        done
        dir=$dir.$suffix
    fi
    mkdir ${GLOBAL_PROJECT}/$dir

    # Copy in the various components
    mkdir ${GLOBAL_PROJECT}/$dir/${BUILD_TARGET}
    cp -a ${BUILD} ${IMAGE} ${GLOBAL_PROJECT}/$dir/${BUILD_TARGET}

    # Point the "stable-last" symlink to the newly-installed build
    rm -f ${GLOBAL_PROJECT}/stable-last
    ln -s $dir ${GLOBAL_PROJECT}/stable-last

    # Clean up old builds; if you want to save one, touch a file
    # called "KEEP" in the directory.
    OLD_PROJECTS=$(find ${GLOBAL_PROJECT}/* -type d -ctime +7)
    for old in ${OLD_PROJECTS}; do
        if [ $old != ${GLOBAL_PROJECT} -a ! -L $old -a ! -e $old/KEEP ]; then
            rm -fr $old
        fi
    done
fi

exit 0
