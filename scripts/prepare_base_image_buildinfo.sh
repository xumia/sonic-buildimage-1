#!/bin/bash


FILESYSTEM_ROOT=$1
DISTRO=$2
ARCH=$3


VERSION_DEB_PREFERENCE="01-versions-deb"
BUILDINFO_PATH=${FILESYSTEM_ROOT}/usr/local/share/buildinfo
BUILDINFO_INSTALL_PATH=${FILESYSTEM_ROOT}/usr/local/sbin
BUILDINFO_VERSION_PATH=${FILESYSTEM_ROOT}/usr/local/share/buildinfo/versions
BUILDINFO_VERSION_DEB=${BUILDINFO_VERSION_PATH}/${VERSION_DEB_PREFERENCE}
OVERRIDE_VERSION_PATH=files/build/host-versions


# Copy build info
cp -rf files/build/scripts/* ${BUILDINFO_SCRIPT_PATH}/

# Generate the build info config
SONIC_ENFORCE_VERSIONS=$SONIC_ENFORCE_VERSIONS TRUSTED_GPG_URLS=$TRUSTED_GPG_URLS PACKAGE_URL_PREFIX=$PACKAGE_URL_PREFIX scripts/generate_buildinfo_config.sh $BUILDINFO_PATH

# Install the config files
cp -rf "$BUILDINFO_PATH/scripts/*" "$BUILDINFO_INSTALL_PATH/"
cp "$BUILDINFO_PATH/trusted.gpg.d/*" "${FILESYSTEM_ROOT}/etc/apt/trusted.gpg.d/"

# Generate version lock files
scripts/generate_version_lock_files.py -t "$BUILDINFO_VERSION_PATH" -o "$OVERRIDE_VERSION_PATH" -d "$DISTRO" -a "$ARCH"

if [ "$SONIC_ENFORCE_VERSIONS" != "y" ] && [ -f $BUILDINFO_VERSION_DEB ]; then
    cp -f $BUILDINFO_VERSION_DEB ${FILESYSTEM_ROOT}/etc/apt/preferences.d/
fi
