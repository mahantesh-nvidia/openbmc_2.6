DESCRIPTION = "This is the mst library installer"
SECTION = "console/network"
LICENSE = "GPLv2"
LIC_FILES_CHKSUM = "file://LICENSE.txt;md5=acf1f43dc4568f15d675e391d5b73f7e"
RDEPENDS_${PN} += "bash"

SRC_URI = "file:////mswg/release/mft/mft-4.9.0/mft-4.9.0-27/linux/mft-4.9.0-27/RPMS/mft-4.9.0-27-arm6l-rpm.tgz"

S = "${WORKDIR}/mft-4.9.0-27-arm6l-rpm"

SRCREV = "${AUTOREV}"
RPMSDIR = "${S}/RPMS"
INSANE_SKIP_${PN}_append = "already-stripped"


# The "install" make target runs the binary to create links for subcommands.
# The links are excessive and this doesn't work for cross compiling.
#

do_install() {
	rm -f ${RPMSDIR}/tmp.xz
	rm -f ${RPMSDIR}/tmp.cpio
	rm -rf ${S}/usr/
	rm -rf ${S}/etc/

	rpm2cpio ${RPMSDIR}/mft-4.9.0-27.arm6l.rpm > ${RPMSDIR}/tmp.xz
	xz -d -c ${RPMSDIR}/tmp.xz > ${RPMSDIR}/tmp.cpio
	cpio -i -d < ${RPMSDIR}/tmp.cpio

	install -d ${D}/usr/bin/
	install -m 0755 ${S}/etc/init.d/mst ${D}/usr/bin/
	install -m 0755 ${S}/usr/bin/mtserver ${D}/usr/bin/
	install -m 0755 ${S}/usr/bin/i2c ${D}/usr/bin/
	install -m 0755 ${S}/usr/bin/mlxi2c ${D}/usr/bin/
}

