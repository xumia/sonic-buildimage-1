#!/bin/bash -ex


IMAGE_VERSION_FILE="files/build/host-versions/versions-image"
CONFIGURED_ARCH=$1
IMAGE_DISTRO=$2
FILESYSTEM_ROOT=$3
PACKAGE_URL_PREFIX=$4
IMAGE_VERSION=$(grep image-host $IMAGE_VERSION_FILE | cut -d= -f2)

FILE_NAME="image-host-${CONFIGURED_ARCH}-${IMAGE_DISTRO}_${IMAGE_VERSION}.tar.gz"
FILE_URL="${PACKAGE_URL_PREFIX}${FILE_NAME}"
wget "${FILE_URL}" -O "${FILE_NAME}"
mkdir -p "${FILESYSTEM_ROOT}"
sudo tar -xzf "${FILE_NAME}" -C "${FILESYSTEM_ROOT}"
rm -f "${FILE_NAME}"

