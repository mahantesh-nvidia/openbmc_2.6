PV = "git${SRCPV}"

FILESEXTRAPATHS_prepend := "${THISDIR}/${PN}:"

SRC_URI = "git://git.code.sf.net/p/openipmi/code"
SRC_URI += "file://mlx-openipmi.patch"
SRC_URI += "file://bw-openipmi.patch"
SRC_URI += "file://mlx_ipmid.service"
SRC_URI += "file://remove_libdir.patch"

# Set SRCREV to OpenIPMI 2.0.22 baseline
SRCREV = "e14d0400ba4fff83926b849834df72124893d0bc"

require mlx-ipmid.inc
