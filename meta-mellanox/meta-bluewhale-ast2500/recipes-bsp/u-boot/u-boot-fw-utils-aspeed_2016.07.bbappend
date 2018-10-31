FILESEXTRAPATHS_prepend := "${THISDIR}/files:"

# Override some values in "u-boot-common-aspeed_2016.07.inc" with
# specifics of our Git repo, branch names, and source revision.
SRCREV = "${AUTOREV}"
UBRANCH = "mlnx-1.0"
UBOOT_SRC = "git://bu-gerrit.mtbu.labs.mlnx/bmc-u-boot;branch=${UBRANCH}"
