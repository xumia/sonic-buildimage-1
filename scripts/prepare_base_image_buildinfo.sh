#!/bin/bash


ARCH=$1
DISTRO=$2
FILESYSTEM_ROOT=$3

. /usr/local/share/buildinfo/config/buildinfo.config
VERSION_DEB_PREFERENCE="01-versions-deb"
BUILDINFO_PATH=${FILESYSTEM_ROOT}/usr/local/share/buildinfo
BUILDINFO_INSTALL_PATH=${FILESYSTEM_ROOT}/usr/local/sbin
BUILDINFO_VERSION_PATH=${FILESYSTEM_ROOT}/usr/local/share/buildinfo/versions
BUILDINFO_VERSION_DEB=${BUILDINFO_VERSION_PATH}/${VERSION_DEB_PREFERENCE}
OVERRIDE_VERSION_PATH=files/build/versions/host-image
DIFF_VERSIONS_PATH=$BUILDINFO_PATH/diff-versions

# Copy build info scripts
mkdir -p $BUILDINFO_PATH
cp -rf files/build/scripts ${BUILDINFO_PATH}/

# Copy the build info config
cp -rf files/build/buildinfo/* $BUILDINFO_PATH/

# Install the config files
cp -rf $BUILDINFO_PATH/scripts/* "$BUILDINFO_INSTALL_PATH/"
cp $BUILDINFO_PATH/trusted.gpg.d/* "${FILESYSTEM_ROOT}/etc/apt/trusted.gpg.d/"

# Generate version lock files
scripts/versions_manager.py generate -t "$BUILDINFO_VERSION_PATH" -m "$OVERRIDE_VERSION_PATH" -d "$DISTRO" -a "$ARCH"

if [ "$ENABLE_VERSION_CONTROL_DEB" != "y" ]; then
    cp -f $BUILDINFO_VERSION_DEB ${FILESYSTEM_ROOT}/etc/apt/preferences.d/
fi

sudo LANG=C chroot $FILESYSTEM_ROOT /bin/bash -c "pre_run_buildinfo"
