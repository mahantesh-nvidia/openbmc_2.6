SUMMARY = "OpenBMC Mellanox Fan Management."
DESCRIPTION = "OpenBMC Mellanox fan management implementation."
PR = "r1"

LICENSE = "Apache-2.0"
LIC_FILES_CHKSUM = "file://${PHOSPHORBASE}/COPYING.apache-2.0;md5=34400b68072d710fecd0a2940a0d1658"

inherit obmc-phosphor-systemd
inherit autotools

DEPENDS += "systemd"
S = "${WORKDIR}"
SRC_URI += "file://obmc-mellanox-fand.sh \
           file://obmc-mellanox-fand.service \
           "

SYSTEMD_SERVICE_${PN} += "obmc-mellanox-fand.service"

RRECOMMENDS_${PN} += "obmc-targets"

do_compile[noexec] = "1"

do_install() {
        install -d ${D}/${sbindir}
        install -m 755 ${S}/obmc-mellanox-fand.sh ${D}/${sbindir}/obmc-mellanox-fand.sh
}
