#!/bin/bash


CONFIGURED_ARCH=$1
IMAGE_DISTRO=$2
FILESYSTEM_ROOT=$3
HTTP_PROXY=$4

if [[ $CONFIGURED_ARCH == armhf || $CONFIGURED_ARCH == arm64 ]]; then
    # qemu arm bin executable for cross-building
    sudo mkdir -p $FILESYSTEM_ROOT/usr/bin
    sudo cp /usr/bin/qemu*static $FILESYSTEM_ROOT/usr/bin || true
    sudo http_proxy=$HTTP_PROXY debootstrap --variant=minbase --arch $CONFIGURED_ARCH $IMAGE_DISTRO $FILESYSTEM_ROOT http://deb.debian.org/debian
else
    sudo http_proxy=$HTTP_PROXY debootstrap --variant=minbase --arch $CONFIGURED_ARCH $IMAGE_DISTRO $FILESYSTEM_ROOT http://debian-archive.trafficmanager.net/debian
fi
