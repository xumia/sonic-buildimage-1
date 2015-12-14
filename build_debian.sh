#!/bin/bash
## This script is to automate the preparation for a debian file system, which will be used for
## a ONIE installation image.

## Enable debug output for script
set -x

## Workding directory to prepare the file system
FILESYSTEM_ROOT=./fsroot
## Output file name for compressed file system
OUTPUT_FILE=fs.img.gz
## Hostname for the linux image
HOSTNAME=acs
## Default user
DEFAULT_USERNAME=acsadmin
DEFAULT_USERINFO="ACS Admin User,,,"
## Default password for the default user
## You may get a crypted password by: perl -e 'print crypt("<PaSsWoRd>", "salt"),"\n"'
DEFAULT_PASSWORD="sahL5d5V.UWtI"
## Partition lable
DEMO_VOLUME_LABEL="ACS-OS"
## Partition size in MB
DEMO_PART_SIZE=2048

## Prepare a virtual block device
device_file=$(mktemp)

function cleanup {
    sudo fuser -km /dev/loop0 || true
    sudo umount -d /dev/loop0 2> /dev/null || true
    sudo losetup -d /dev/loop0 2> /dev/null || true
    sudo rm $device_file
}
trap cleanup exit

## Create a file with all zero content. It will hold all the content of the file system
dd if=/dev/zero of=$device_file bs=512 count=$((2 * $DEMO_PART_SIZE))k
## Connect 0 loopback device to the file
sudo fuser -km /dev/loop0 || true
sudo umount -d /dev/loop0 > /dev/null 2>&1 || true
sudo losetup /dev/loop0 $device_file || (echo "Failed to connect loopback device 0" >&2; exit 1)
## Create filesystem on the device with a label
yes | sudo mkfs.ext4 -L $DEMO_VOLUME_LABEL /dev/loop0 || {
    echo "Error: Unable to create file system on $demo_dev"
    exit 1
}

[ -d $FILESYSTEM_ROOT ] && sudo rm -r $FILESYSTEM_ROOT
mkdir -p $FILESYSTEM_ROOT
sudo mount -t ext4 /dev/loop0 $FILESYSTEM_ROOT

echo '[INFO] Debootstrap...'
sudo debootstrap --arch amd64 jessie $FILESYSTEM_ROOT http://ftp.us.debian.org/debian

## Prepare the hostname and hosts config, otherwise 'sudo ...' will complain 'sudo: unable to resolve host ...'
sudo LANG=C chroot $FILESYSTEM_ROOT /bin/bash -c "echo '$HOSTNAME' > /etc/hostname"
sudo LANG=C chroot $FILESYSTEM_ROOT /bin/bash -c "echo '127.0.0.1       $HOSTNAME' >> /etc/hosts"

## Create device files
sudo LANG=C chroot $FILESYSTEM_ROOT /bin/bash -c 'echo "proc /proc proc defaults 0 0" >> /etc/fstab'
sudo LANG=C chroot $FILESYSTEM_ROOT /bin/bash -c 'echo "sysfs /sys sysfs defaults 0 0" >> /etc/fstab'
## Note: mounting is necessary to makedev and install linux image
echo '[INFO] Mount all'
sudo LANG=C chroot $FILESYSTEM_ROOT mount proc /proc -t proc
sudo LANG=C chroot $FILESYSTEM_ROOT mount sysfs /sys -t sysfs

## Note: set lang to prevent locale warnings in your chroot
sudo LANG=C chroot $FILESYSTEM_ROOT apt-get -y update
echo '[INFO] Install packages for building image'
sudo LANG=C chroot $FILESYSTEM_ROOT apt-get -y install makedev psmisc

echo '[INFO] MAKEDEV'
sudo LANG=C chroot $FILESYSTEM_ROOT /bin/bash -c 'cd /dev && MAKEDEV generic'
echo '[INFO] Install ACS linux kernel image'
sudo LANG=C chroot $FILESYSTEM_ROOT apt-get -y install initramfs-tools
sudo LANG=C dpkg --root=$FILESYSTEM_ROOT -i deps/linux-image-3.16.7-ckt11+_3.16.7-ckt11+-*_amd64.deb

## Install docker
echo '[INFO] Install dcoker'
curl -sSL https://get.docker.com/ | sudo LANG=C chroot $FILESYSTEM_ROOT sh
sudo chroot fsroot service docker stop
sudo chroot fsroot service dbus stop

## Umount all
echo '[INFO] Umount all'
sudo LANG=C chroot $FILESYSTEM_ROOT fuser -km /sys || true
sudo LANG=C chroot $FILESYSTEM_ROOT umount -lf /sys
sudo LANG=C chroot $FILESYSTEM_ROOT fuser -km /proc || true
sudo LANG=C chroot $FILESYSTEM_ROOT umount /proc

## Create user for the default user
## Note: user should be in the group with the same name, and also in sudo group
sudo LANG=C chroot $FILESYSTEM_ROOT useradd -G sudo $DEFAULT_USERNAME -c "$DEFAULT_USERINFO" -m -s /bin/bash
## Create password for the default user
sudo LANG=C chroot $FILESYSTEM_ROOT /bin/bash -c "echo $DEFAULT_USERNAME:$DEFAULT_PASSWORD | chpasswd -e"

## Pre-install the fundamental packages
## Note: gdisk is needed for sgdisk in install.sh
## Note: parted is needed for partprobe in install.sh
sudo LANG=C chroot $FILESYSTEM_ROOT apt-get -y install sudo vim screen tcpdump ntp openssh-server python python-apt \
        gdisk parted

## Pre-install grub for image OS future partition manipulation
## Note: DEBIAN_FRONTEND is needed to prvent interactive configuration for grub-pc
## Note: grub2 is needed for grub-install in install.sh
sudo LANG=C DEBIAN_FRONTEND=noninteractive chroot $FILESYSTEM_ROOT apt-get -y install grub-pc grub2

echo '[INFO] install apt-transport-sftp package for azure repository'
sudo LANG=C chroot $FILESYSTEM_ROOT apt-get -y install libssh2-1
wget http://tux-devrepo.corp.microsoft.com/repos/tux-dev/pool/main/a/apt-transport-sftp/apt-transport-sftp_0.2.2.deb
sudo LANG=C dpkg --root=$FILESYSTEM_ROOT -i apt-transport-sftp_0.2.2.deb

## Pre-install kernel related packages of the Azure Cloud Switch into the host file system
sudo LANG=C dpkg --root=$FILESYSTEM_ROOT -i deps/opennsl-modules-*.deb

## Config DHCP for eth0
sudo LANG=C chroot $FILESYSTEM_ROOT /bin/bash -c "cat <<EOF >> /etc/network/interfaces

auto eth0
allow-hotplug eth0
iface eth0 inet dhcp

EOF"

## Clean up apt
sudo LANG=C chroot $FILESYSTEM_ROOT apt-get autoremove
sudo LANG=C chroot $FILESYSTEM_ROOT apt-get clean

## Dump the device to image
sudo fuser -km /dev/loop0
sudo umount -d /dev/loop0 || (echo "Failed to umount or detach loopback device 0 before gzip" >&2; exit 1)
gzip -c < $device_file > $OUTPUT_FILE
