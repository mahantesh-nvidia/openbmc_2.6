# NOTE: don't change top 7 lines without updating mlnx_setup_openbmc.in
#
# Override some values in "u-boot-common-aspeed_2016.07.inc" with
# specifics of our Git repo, branch names, and source revision.
SRCREV = "${AUTOREV}"
UBRANCH = "master"
UBOOT_SRC = "git://bu-gerrit.mtbu.labs.mlnx/bmc-u-boot;branch=${UBRANCH}"

# Directory holding recipe-specific files
OPENBMC_FILES_DIR = "${COREBASE}/meta-mellanox/meta-bluewhale-ast2500/recipes-phosphor/files"

require ${OPENBMC_FILES_DIR}/mlnx_patch_info.inc

# Name of our U-Boot patch file
UBOOT_PATCH_NAME = "${OPENBMC_PATCH_DIR}/u-boot-${UBOOT_COMMIT}.patch"

do_deploy_append () {

    # Create the directory to hold our U-Boot patch file
    install -d ${OPENBMC_PATCH_DIR}

    # Clean out the old U-Boot patch file
    rm -f ${UBOOT_PATCH_NAME}

    # Use a heredoc to supply the "patch.in" content, and pipe it
    # through sed to insert the actual upstream U-Boot commit
    sed -e 's/@COMMIT@/${UBOOT_COMMIT}/' > ${UBOOT_PATCH_NAME} << !
#!/bin/sh -x

# Feed this file to "patch -p1" in an U-Boot directory at tag @COMMIT@.
# Or, run this file as a script to download and then patch the U-Boot sources.

set -e

DIR=u-boot-@COMMIT@
if [ -d \$DIR ]; then
    echo "\$0: Cannot replace existing directory '\$DIR'." >&2
    exit 1
fi

FROM=git://github.com/openbmc/u-boot

git clone -n \$FROM
mv u-boot \$DIR
(cd \$DIR; git checkout @COMMIT@; patch -p1) < \$0

exit 0

# The actual patch starts here.
!

    # Go to U-Boot source directory
    cd ${S}

    # Append to our U-Boot patch file with actual git differences
    git diff -u ${UBOOT_COMMIT} HEAD >> ${UBOOT_PATCH_NAME}

    # Allow patch to be executed
    chmod +x ${UBOOT_PATCH_NAME}
}
