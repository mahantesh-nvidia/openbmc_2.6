do_deploy_append () {
    if [ -e ${WORKDIR}/build/u-boot-env.bin ] ; then
        install -m 644 ${WORKDIR}/build/u-boot-env.bin ${DEPLOYDIR}
    fi
}

