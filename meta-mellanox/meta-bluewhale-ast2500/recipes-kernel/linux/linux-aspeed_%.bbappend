FILESEXTRAPATHS_prepend_bluewhale-ast2500 := "${THISDIR}/${PN}:"
SRC_URI_append_bluewhale-ast2500 = " file://bluewhale-ast2500.cfg"

# Override some values in linux-aspeed.inc and linux-aspeed_git.bb
# with specifics of our Git repo, branch names, and Linux version
KBRANCH = "dev-4.17"
LINUX_VERSION = "4.17.11"
SRCREV = "${AUTOREV}"
KSRC = "git://bu-gerrit.mtbu.labs.mlnx/bmc-linux;protocol=git;branch=${KBRANCH}"
