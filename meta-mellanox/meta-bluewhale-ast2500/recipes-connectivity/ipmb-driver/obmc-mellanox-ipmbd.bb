SUMMARY = "OpenBMC Mellanox IPMB driver loader"
DESCRIPTION = "Loads the IPMB driver"
PR = "r1"

LICENSE = "Apache-2.0"
LIC_FILES_CHKSUM = "file://${PHOSPHORBASE}/COPYING.apache-2.0;md5=34400b68072d710fecd0a2940a0d1658"

inherit obmc-phosphor-systemd
inherit autotools

DEPENDS += "systemd"
S = "${WORKDIR}"
SRC_URI += "file://obmc-mellanox-ipmb-host.sh \
           file://obmc-mellanox-ipmb-dev-int.sh \
           file://obmc-mellanox-ipmb-host.service \
           "

SYSTEMD_SERVICE_${PN} += "obmc-mellanox-ipmb-host.service"

RRECOMMENDS_${PN} += "obmc-targets"

do_compile[noexec] = "1"

do_install() {
        install -d ${D}/${sbindir}
        install -m 755 ${S}/obmc-mellanox-ipmb-host.sh ${D}/${sbindir}/obmc-mellanox-ipmb-host.sh
        install -m 755 ${S}/obmc-mellanox-ipmb-dev-int.sh ${D}/${sbindir}/obmc-mellanox-ipmb-dev-int.sh
}
