#!/bin/bash -ex

TARGET_PATH=$1
FILESYSTEM_ROOT=$2
BUILDINFO_PATH="${TARGET_PATH}/buildinfo"
[ -d $BUILDINFO_PATH ] && rm -rf $BUILDINFO_PATH
mkdir -p $BUILDINFO_PATH
cp -rf files/build/versions $BUILDINFO_PATH
cp -rf files/build/scripts $BUILDINFO_PATH
echo "PACKAGE_URL_PREFIX=${PACKAGE_URL_PREFIX}" > $BUILDINFO_PATH/scripts/wget.config

if ls ${BUILDINFO_PATH}/versions-*  > /dev/null 2>&1; then
    cp ${BUILDINFO_PATH}/versions-* ${BUILDINFO_PATH}/versions-*
fi

if [ -d "${FILESYSTEM_ROOT}" ]; then
    # Install the apt-get/pip/pip3/wget commands for host image
    cp -rf files/build/scripts/* ${FILESYSTEM_ROOT}/usr/local/sbin/
    cp $BUILDINFO_PATH/scripts/wget.config ${FILESYSTEM_ROOT}/usr/local/sbin/

    cp -rf files/build/host-versions/* $BUILDINFO_PATH/
fi
