PV = "git${SRCPV}"

FILESEXTRAPATHS_prepend := "${THISDIR}/${PN}:"

SRC_URI = "git://git.code.sf.net/p/openipmi/code"
SRC_URI += "file://bw-openipmi.patch"
SRC_URI += "file://mlx_ipmid.service"

# 2.0.27 baseline
SRCREV = "e4cea80128dad71b1f4516033384647a8f6b1394"

require mlx-ipmid.inc
