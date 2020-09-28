#!/bin/bash -ex

TARGET_PATH=$1
FILESYSTEM_ROOT=$2
BUILDINFO_PATH="${TARGET_PATH}/buildinfo"
BUILDINFO_CONFIG=$BUILDINFO_PATH/scripts/buildinfo.config
[ -d $BUILDINFO_PATH ] && rm -rf $BUILDINFO_PATH
mkdir -p $BUILDINFO_PATH
cp -rf files/build/versions $BUILDINFO_PATH
cp -rf files/build/scripts $BUILDINFO_PATH

echo "BUILD_UPGRADE_VERSION=${BUILD_UPGRADE_VERSION}" > $BUILDINFO_CONFIG
echo "PACKAGE_URL_PREFIX=${PACKAGE_URL_PREFIX}" >> $BUILDINFO_CONFIG


if [ -d "${FILESYSTEM_ROOT}" ]; then
    # Install the apt-get/pip/pip3/wget commands for host image
    cp -rf files/build/scripts/* ${FILESYSTEM_ROOT}/usr/local/sbin/
    cp $BUILDINFO_PATH/scripts/wget.config ${FILESYSTEM_ROOT}/usr/local/sbin/

    cp -rf files/build/host-versions/* $BUILDINFO_PATH/
fi
