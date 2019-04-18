DESCRIPTION = "This is Mellanox BMC tools"
SECTION = "console/network"
LICENSE = "GPLv2"
LIC_FILES_CHKSUM = "file://COPYING;md5=94d55d512a9ba36caa9b7df079bae19f"

SRC_URI = "git://bu-gerrit.mtbu.labs.mlnx/bmc-mellanox-bmc-tools"
SRCREV = "${AUTOREV}"

TARGET_CC_ARCH += "${LDFLAGS}"

RDEPENDS_${PN} += "bash"

S = "${WORKDIR}/git"

inherit module

# Directory holding recipe-specific files
OPENBMC_FILES_DIR = "${COREBASE}/meta-mellanox/meta-bluewhale-ast2500/recipes-phosphor/files"

require ${OPENBMC_FILES_DIR}/mlnx_patch_info.inc

# Create source code tarball for Mellanox BMC tools
do_compile_prepend() {
    install -d ${OPENBMC_PATCH_DIR}
    cd ${S}
    tar cfz ${OPENBMC_PATCH_DIR}/mellanox-bmc-tools.tar.gz *
}

do_compile() {
    cd ${B}/mlnx_clkprog
    oe_runmake CC="${CC}"
    cd ${B}/mlnx_cpldprog
    oe_runmake CC="${CC}"
    cd ${B}/mlnx_cpldaccess
    oe_runmake CC="${CC}"
    cd ${B}/mlnx_oem_ncsi
    oe_runmake CC="${CC}"
    cd ${B}/mlnx_strings
    oe_runmake CC="${CC}"
}

do_install() {
    install -d ${D}${sbindir}
    install -d ${D}/usr/share
    install -d ${D}/usr/share/mellanox
    install -m 0755 ${B}/mlnx_clkprog/bin/mlnx_si5341prog ${D}${sbindir}/.mlnx_si5341prog
    install -m 0755 ${B}/mlnx_clkprog/bin/mlnx_si52142prog ${D}${sbindir}/.mlnx_si52142prog
    install -m 0755 ${B}/mlnx_clkprog/si5341_conf.sh ${D}${sbindir}/si5341conf
    install -m 0755 ${B}/mlnx_cpldprog/mlnx_cpldprog ${D}${sbindir}/.mlnx_cpldprog
    install -m 0755 ${B}/mlnx_cpldprog/obmc-update_cpld.sh ${D}${sbindir}/update_cpld
    install -m 0755 ${B}/mlnx_cpldaccess/mlnx_cpldaccess ${D}${sbindir}/.mlnx_cpldaccess
    install -m 0755 ${B}/mlnx_strings/mlnx_strings ${D}${sbindir}/.mlnx_strings
    install -m 0755 ${B}/mlnx_oem_ncsi/send_oem_cmd ${D}${sbindir}
    install -m 0755 ${B}/mlnx_oem_ncsi/recv_oem_rsp ${D}${sbindir}
    install -m 0755 ${B}/mlnx_bmc_sanity.sh ${D}${sbindir}/mlnx_bmc_sanity
    install -m 0755 ${B}/mlnx_tps53679_voltage_margin.sh ${D}${sbindir}/.mlnx_tps53679_voltage_margin
    install -m 0755 ${B}/mlnx_tps53915_voltage_margin.sh ${D}${sbindir}/.mlnx_tps53915_voltage_margin
    install -m 0755 ${B}/obmc-update_seq.sh ${D}${sbindir}/update_seq
    install -m 0755 ${B}/mlnx_powercycle_bf.sh ${D}${sbindir}/mlnx_powercycle_bf
    install -m 0755 ${B}/mlnx_poweron_bf.sh ${D}${sbindir}/mlnx_poweron_bf
    install -m 0755 ${B}/mlnx_poweroff_bf.sh ${D}${sbindir}/mlnx_poweroff_bf
    install -m 0755 ${B}/mlnx_powerstatus_bf.sh ${D}${sbindir}/mlnx_powerstatus_bf
    install -m 0644 ${B}/images/*.svf ${D}/usr/share/mellanox
}

FILES_${PN} += "${sbindir} ./usr/share"
