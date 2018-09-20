PV = "git${SRCPV}"

MLX_IPMID_BRANCH = "master"

FILESEXTRAPATHS_prepend := "${THISDIR}/${PN}:"

SRC_URI = "git://bu-gerrit.mtbu.labs.mlnx/bmc-openipmi-code.git;protocol=git;branch=${MLX_IPMID_BRANCH};"
SRC_URI += "file://bw-openipmi.patch"
SRC_URI += "file://mlx_ipmid.service"
SRC_URI += "file://remove_libdir.patch"


SRCREV = "${AUTOREV}"

require mlx-ipmid.inc
