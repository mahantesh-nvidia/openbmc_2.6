FILESEXTRAPATHS_prepend := "${THISDIR}/files:"

SRC_URI += " \
	file://list-i2c-devices-without-fru-eeprom.patch \
	file://BF_TPS53679.json \
	file://BF_EMC1424.json \
"

do_install_append () {
	install -m 644 ${WORKDIR}/BF_TPS53679.json ${D}/usr/share/entity-manager/configurations/
	install -m 644 ${WORKDIR}/BF_EMC1424.json ${D}/usr/share/entity-manager/configurations/
}
