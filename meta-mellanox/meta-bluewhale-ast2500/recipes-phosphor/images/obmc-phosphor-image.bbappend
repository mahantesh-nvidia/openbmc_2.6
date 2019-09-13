OBMC_IMAGE_EXTRA_INSTALL_append = " tcpdump \
                                    iptables \
                                    xinetd \
                                    mft-tools \
                                    mellanox-bmc-tools \
                                    ipmitool \
                                    mlx-ipmid \
                                    obmc-mellanox-fand \
                                    obmc-mellanox-ipmbd \
                                    bridge-utils \
                                    strace \
                                    obmc-mellanox-mac-syncd \
                                    screen \
                                    "

# Directory holding recipe-specific files
OPENBMC_FILES_DIR = "${COREBASE}/meta-mellanox/meta-bluewhale-ast2500/recipes-phosphor/files"

require ${OPENBMC_FILES_DIR}/mlnx_patch_info.inc

# Name of our setup script input file
SETUP_SCRIPT_INPUT = "${OPENBMC_FILES_DIR}/mlnx_setup_openbmc.in"

# Name of our setup script
SETUP_SCRIPT= "${OPENBMC_PATCH_DIR}/mlnx_setup_openbmc"

# Name of our OpenBMC patch file
OPENBMC_PATCH_NAME = "${OPENBMC_PATCH_DIR}/openbmc-${OPENBMC_COMMIT}.patch"

# Create the OpenBMC patch file
create_openbmc_patch() {

    # Clean out the old OpenBMC patch file
    rm -f ${OPENBMC_PATCH_NAME}

    # Use a heredoc to supply the "patch.in" content, and pipe it
    # through sed to insert the actual upstream OpenBMC commit
    sed -e 's/@COMMIT@/${OPENBMC_COMMIT}/' > ${OPENBMC_PATCH_NAME} << !
#!/bin/sh -x

# Feed this file to "patch -p1" in an OpenBMC directory at tag @COMMIT@.
# Or, run this file as a script to download and then patch the OpenBMC sources.

set -e

DIR=openbmc-@COMMIT@
if [ -d \$DIR ]; then
    echo "\$0: Cannot replace existing directory '\$DIR'." >&2
    exit 1
fi

FROM=git://github.com/openbmc/openbmc

git clone -n \$FROM
mv openbmc \$DIR
(cd \$DIR; git checkout @COMMIT@; patch -p1) < \$0

exit 0

# The actual patch starts here.
!
    # Go to base of OpenBMC source directory
    cd ${COREBASE}

    # Append to our OpenBMC patch file with actual git differences
    # NOTE: Exclude internal-only tools (like MFT) from 'git diff'
    git diff -u ${OPENBMC_COMMIT} HEAD -- . \
        ':!meta-mellanox/meta-bluewhale-ast2500/recipes-devtools/mft-tools' >> ${OPENBMC_PATCH_NAME}

    # Allow patch to be executed
    chmod +x ${OPENBMC_PATCH_NAME}
}

# Create the customer tarball with patches, scripts, EULA, etc.
create_sw_tarball() {

    # Place U-Boot upstream commit number into setup script
    sed -e 's/@UBOOT_COMMIT@/${UBOOT_COMMIT}/' \
        < ${SETUP_SCRIPT_INPUT} > ${SETUP_SCRIPT}

    # Place Linux upstream commit number into setup script
    sed -i 's/@LINUX_COMMIT@/${LINUX_COMMIT}/' ${SETUP_SCRIPT}

    # Place Linux upstream commit (long format) into setup script
    sed -i 's/@LINUX_COMMIT_LONG@/${LINUX_COMMIT_LONG}/' ${SETUP_SCRIPT}

    # Place OpenBMC upstream commit number into setup script
    sed -i 's/@OPENBMC_COMMIT@/${OPENBMC_COMMIT}/' ${SETUP_SCRIPT}

    # Allow setup script to be executed
    chmod +x ${SETUP_SCRIPT}

    # Create the OpenBMC patch file
    create_openbmc_patch;

    # Go to base of OpenBMC source directory
    cd ${COREBASE}

    # Fetch the OpenBMC version via 'git describe' command
    VERSION=`git describe | cut -f 1,2 -d '-'`

    # Copy the README help file into the OpenBMC patch directory
    cp ${OPENBMC_FILES_DIR}/README ${OPENBMC_PATCH_DIR}

    # Go to our OpenBMC patch directory
    cd ${OPENBMC_PATCH_DIR}

    # Create the customer tarball, using proper version in file name
    # - place all files in a subdirectory with same name as tarball
    tar cfJ ${DEPLOY_DIR_IMAGE}/BlueField-BMC-${VERSION}.tar.xz \
      --transform "s,^,BlueField-BMC-${VERSION}/," *
}

ROOTFS_POSTPROCESS_COMMAND += "create_sw_tarball; "
