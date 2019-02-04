SUMMARY = "OpenBMC Mellanox IPMB driver loader"
DESCRIPTION = "Loads the IPMB driver"
PR = "r1"

LICENSE = "Apache-2.0"
LIC_FILES_CHKSUM = "file://${PHOSPHORBASE}/COPYING.apache-2.0;md5=34400b68072d710fecd0a2940a0d1658"

inherit obmc-phosphor-systemd
inherit autotools

DEPENDS += "systemd"
S = "${WORKDIR}"
SRC_URI += "file://obmc-mellanox-ipmbd.sh \
           file://obmc-mellanox-ipmbd.service \
           "

SYSTEMD_SERVICE_${PN} += "obmc-mellanox-ipmbd.service"

RRECOMMENDS_${PN} += "obmc-targets"

do_compile[noexec] = "1"

do_install() {
        install -d ${D}/${sbindir}
        install -m 755 ${S}/obmc-mellanox-ipmbd.sh ${D}/${sbindir}/obmc-mellanox-ipmbd.sh
}
