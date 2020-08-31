SUMMARY = "OpenBMC for BlueField - Applications"
PR = "r1"

inherit packagegroup

PROVIDES = "${PACKAGES}"
PACKAGES = " \
        ${PN}-system \
        "

PROVIDES += "virtual/obmc-system-mgmt"

RPROVIDES_${PN}-system += "virtual-obmc-system-mgmt"

SUMMARY_${PN}-system = "BlueField System"
RDEPENDS_${PN}-system = " \
        obmc-mgr-system \
        bmcweb \
        entity-manager \
	dbus-sensors \
        phosphor-webui \
        "
