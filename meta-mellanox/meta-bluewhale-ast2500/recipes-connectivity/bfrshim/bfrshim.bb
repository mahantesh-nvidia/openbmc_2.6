DESCRIPTION = "rshim user-space driver for Mellanox BlueField SoC."
SECTION = "console/network"
LICENSE = "GPLv2"
LIC_FILES_CHKSUM = "file://LICENSE;md5=164c749d56ec8da7d59bef44acb1a2ab"
DEPENDS = "libusb1 fuse"

inherit autotools systemd pkgconfig

FILESEXTRAPATHS_prepend := "${THISDIR}/${PN}:"

PV = "2.0+git${SRCPV}"

S = "${WORKDIR}/git"

SRC_URI = "git://github.com/Mellanox/rshim-user-space.git;protocol=https;branch=master"

SRCREV = "${AUTOREV}"

EXTRA_OECONF = "--enable-pcie=no"

PARALLEL_MAKEINST = ""

SYSTEMD_PACKAGES = "${PN}"

SYSTEMD_SERVICE_${PN} = " bfrshim.service"

do_install_append() {
    install -d ${D}/${systemd_unitdir}/system
    install -m 644 ${WORKDIR}/git/bfrshim.service \
        ${D}/${systemd_unitdir}/system/
}
