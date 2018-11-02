# Override some values in linux-aspeed.inc and linux-aspeed_git.bb
# with specifics of our Git repo, branch names, and Linux version
KBRANCH = "dev-4.17"
LINUX_VERSION = "4.17.11"
SRCREV = "${AUTOREV}"
KSRC = "git://bu-gerrit.mtbu.labs.mlnx/bmc-linux;protocol=git;branch=${KBRANCH}"

FILESEXTRAPATHS_prepend_bluewhale-ast2500 := "${THISDIR}/${PN}:"
SRC_URI_append_bluewhale-ast2500 = " file://bluewhale-ast2500.cfg"

# Commit of upstream Linux that is our baseline
LINUX_COMMIT = "db64579"

# Path to our Linux patch file
LINUX_PATCH_DIR = "${DEPLOY_DIR}/mlnx-bmc-sw"

# Name of our Linux patch file
LINUX_PATCH_NAME = "${LINUX_PATCH_DIR}/linux-${LINUX_COMMIT}.patch"

do_deploy_append () {

    # Create the directory to hold our Linux patch file
    install -d ${LINUX_PATCH_DIR}

    # Clean out the old Linux patch file
    rm -f ${LINUX_PATCH_NAME}

    # Use a heredoc to supply the "patch.in" content, and pipe it
    # through sed to insert the actual upstream Linux commit
    sed -e 's/@COMMIT@/${LINUX_COMMIT}/' > ${LINUX_PATCH_NAME} << !
#!/bin/sh -x

# Feed this file to "patch -p1" in a Linux directory at tag @COMMIT@.
# Or, run this file as a script to download and then patch the Linux sources.

set -e

DIR=linux-@COMMIT@
if [ -d \$DIR ]; then
    echo "\$0: Cannot replace existing directory '\$DIR'." >&2
    exit 1
fi

FROM=git://github.com/openbmc/linux

git clone -n \$FROM
mv linux \$DIR
(cd \$DIR; git checkout @COMMIT@; patch -p1) < \$0

exit 0

# The actual patch starts here.
!

    # Go to Linux kernel source directory
    cd ${S}

    # Append to our Linux patch file with actual git differences
    git diff -u ${LINUX_COMMIT} HEAD >> ${LINUX_PATCH_NAME}
}
