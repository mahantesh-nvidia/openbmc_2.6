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

SRCREV = "e0653ef1b6aa7cba1d8ab0c69c33921d49fab46f"

EXTRA_OECONF = "--enable-pcie=no"

PARALLEL_MAKEINST = ""

SYSTEMD_PACKAGES = "${PN}"

SYSTEMD_SERVICE_${PN} = " rshim.service"

do_install_append() {
    install -d ${D}/${systemd_unitdir}/system
    install -m 644 ${WORKDIR}/git/rshim.service \
        ${D}/${systemd_unitdir}/system/
}
