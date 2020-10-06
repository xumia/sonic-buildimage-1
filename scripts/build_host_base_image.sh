#!/bin/bash


CONFIGURED_ARCH=$1
IMAGE_DISTRO=$2
FILESYSTEM_ROOT=$3
http_proxy=$4


if [ $SONIC_ENFORCE_VERSIONS != "y" ]; then
    if [[ $CONFIGURED_ARCH == armhf || $CONFIGURED_ARCH == arm64 ]]; then
        # qemu arm bin executable for cross-building
        sudo mkdir -p $FILESYSTEM_ROOT/usr/bin
        sudo cp /usr/bin/qemu*static $FILESYSTEM_ROOT/usr/bin || true
        sudo http_proxy=$HTTP_PROXY debootstrap --variant=minbase --arch $CONFIGURED_ARCH $IMAGE_DISTRO $FILESYSTEM_ROOT http://deb.debian.org/debian
    else
        sudo http_proxy=$HTTP_PROXY debootstrap --variant=minbase --arch $CONFIGURED_ARCH $IMAGE_DISTRO $FILESYSTEM_ROOT http://debian-archive.trafficmanager.net/debian
    fi
RET=$?
exit $RET
fi

ARCH=$(dpkg --print-architecture)
DISTRO=$(grep CODENAME /etc/os-release | cut -d= -f2)
if [ "$ARCH" != "$CONFIGURED_ARCH" ] || [ "$DISTRO" != "$IMAGE_DISTRO" ]; then
    "Not support to build different ARCH/DISTRO ${CONFIGURED_ARCH}:${$IMAGE_DISTRO} in ${ARCH}:${DISTRO}."
    exit 1
fi

TARGET=target
BASE_VERSIONS=files/build/host-versions/base-versions-deb
BASEIMAGE_TARBALLPATH=$TARGET/baseimage
BASEIMAGE_TARBALL=$(realpath -e $TARGET)/baseimage.tgz

rm -rf $BASEIMAGE_TARBALLPATH $BASEIMAGE_TARBALL

ARCHIEVES=$BASEIMAGE_TARBALLPATH/var/cache/apt/archives
APTLIST=$BASEIMAGE_TARBALLPATH/var/lib/apt/lists
TARGET_DEBOOTSTRAP=$BASEIMAGE_TARBALLPATH/debootstrap
APTDEBIAN="$APTLIST/deb.debian.org_debian_dists_buster_main_binary-${CONFIGURED_ARCH}_Packages"
DEBPATHS=$TARGET_DEBOOTSTRAP/debpaths
DEBOOTSTRAP_BASE=$TARGET_DEBOOTSTRAP/base
DEBOOTSTRAP_REQUIRED=$TARGET_DEBOOTSTRAP/required
[ -d $BASEIMAGE_TARBALLPATH ] && rm -rf $BASEIMAGE_TARBALLPATH
mkdir -p $ARCHIEVES
mkdir -p $APTLIST
mkdir -p $TARGET_DEBOOTSTRAP
PACKAGES=$(sed -E 's/=(=[^=]*)$/\1/' $BASE_VERSIONS)
URL_ARR=($(apt-get download --print-uris $PACKAGES | cut -d" " -f1 | tr -d "'"))
PACKAGE_ARR=($PACKAGES)
LENGTH=${#PACKAGE_ARR[@]}
for ((i=0;i<LENGTH;i++))
do
    package=${PACKAGE_ARR[$i]}
    packagename=$(echo $package | sed -E 's/=[^=]*$//')
    url=${URL_ARR[$i]}
    filename=$(basename "$url")
    wget $url -P $ARCHIEVES
    echo $packagename >> $DEBOOTSTRAP_REQUIRED
    echo "$packagename /var/cache/apt/archives/$filename" >> $DEBPATHS
done
touch $APTDEBIAN
touch $DEBOOTSTRAP_BASE
(cd $BASEIMAGE_TARBALLPATH && tar -zcf $BASEIMAGE_TARBALL .)

sudo debootstrap --verbose --variant=minbase --arch $CONFIGURED_ARCH --unpack-tarball=$BASEIMAGE_TARBALL $IMAGE_DISTRO $FILESYSTEM_ROOT

