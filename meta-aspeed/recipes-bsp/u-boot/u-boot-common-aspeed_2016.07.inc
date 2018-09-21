HOMEPAGE = "https://github.com/openbmc/u-boot"
SECTION = "bootloaders"

LICENSE = "GPLv2+"
LIC_FILES_CHKSUM = "file://Licenses/README;md5=a2c678cfd4a4d97135585cad908541c6"
PE = "1"

# We use the revision in order to avoid having to fetch it from the
# repo during parse
SRCREV = "${AUTOREV}"

UBRANCH = "mlnx-1.0"
SRC_URI = "git://bu-gerrit.mtbu.labs.mlnx/bmc-u-boot.git;branch=${UBRANCH}"

S = "${WORKDIR}/git"

PV = "v2016.07+git${SRCPV}"
