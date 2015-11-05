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
HOSTNAME=debian
## Default user
DEFAULT_USERNAME=acsadmin
DEFAULT_USERINFO="ACS Admin User,,,"
## Default password for the default user
## You may get a crypted password by: perl -e 'print crypt("<PaSsWoRd>", "salt"),"\n"'
DEFAULT_PASSWORD="sahL5d5V.UWtI"

## Prepare a virtual block device
device_file=$(mktemp)
trap "rm $device_file" exit
## Create a 1024M file with all zero content
dd if=/dev/zero of=$device_file count=2000k
## Connect 0 loopback device to the file
sudo umount /dev/loop0
sudo losetup -d /dev/loop0 || (echo "Failed to detach loopback device 0" >&2; exit 1)
sudo losetup /dev/loop0 $device_file || (echo "Failed to connect loopback device 0" >&2; exit 1)
trap 'sudo losetup -d /dev/loop0' exit
## Creat one partition on the device
yes | sudo mkfs.ext4 /dev/loop0
[ -d $FILESYSTEM_ROOT ] && sudo rm -r $FILESYSTEM_ROOT
mkdir -p $FILESYSTEM_ROOT
sudo mount -t ext4 /dev/loop0 $FILESYSTEM_ROOT
trap 'sudo umount -d /dev/loop0 2> /dev/null' exit

echo '[INFO] Debootstrap...'
sudo debootstrap --arch amd64 jessie $FILESYSTEM_ROOT http://ftp.us.debian.org/debian
## Note: set lang to prevent locale warnings in your chroot
sudo LANG=C chroot $FILESYSTEM_ROOT apt-get -y update
echo '[INFO] Install packages for building image'
sudo LANG=C chroot $FILESYSTEM_ROOT apt-get -y install makedev psmisc

## Prepare the hostname and hosts config, otherwise 'sudo ...' will complain 'sudo: unable to resolve host ...'
hostname $HOSTNAME
sudo LANG=C chroot $FILESYSTEM_ROOT /bin/bash -c "echo '127.0.0.1       $HOSTNAME' >> /etc/hosts"

## Create device files
sudo LANG=C chroot $FILESYSTEM_ROOT /bin/bash -c 'echo "proc /proc proc defaults 0 0" >> /etc/fstab'
sudo LANG=C chroot $FILESYSTEM_ROOT /bin/bash -c 'echo "sysfs /sys sysfs defaults 0 0" >> /etc/fstab'
## Note: mounting is necessary to makedev and install linux image
echo '[INFO] Mount all'
sudo LANG=C chroot $FILESYSTEM_ROOT mount none /proc -t proc
sudo LANG=C chroot $FILESYSTEM_ROOT mount sysfs /sys -t sysfs
echo '[INFO] MAKEDEV'
sudo LANG=C chroot $FILESYSTEM_ROOT /bin/bash -c 'cd /dev && MAKEDEV generic'
echo '[INFO] Install linux-image-amd64'
sudo LANG=C chroot $FILESYSTEM_ROOT apt-get -y install linux-image-amd64

## Umount all
echo '[INFO] Umount all'
sudo LANG=C chroot $FILESYSTEM_ROOT umount /sys
sudo LANG=C chroot $FILESYSTEM_ROOT fuser -km /proc
sudo LANG=C chroot $FILESYSTEM_ROOT umount /proc

## Create user for the default user
## Note: user should be in the group with the same name, and also in sudo group
sudo LANG=C chroot $FILESYSTEM_ROOT useradd -G sudo $DEFAULT_USERNAME -c "$DEFAULT_USERINFO" -m -s /bin/bash
## Create password for the default user
sudo LANG=C chroot $FILESYSTEM_ROOT /bin/bash -c "echo $DEFAULT_USERNAME:$DEFAULT_PASSWORD | chpasswd -e"

## Pre-install the fundamental packages
sudo LANG=C chroot $FILESYSTEM_ROOT apt-get -y install sudo vim screen tcpdump sudo ntp openssh-server python python-apt

## TODO: pre-install all the Azure Cloud Switch packages into the file system

## Config DHCP for eth0
sudo LANG=C chroot $FILESYSTEM_ROOT /bin/bash -c "cat <<EOF >> /etc/network/interfaces

auto eth0
allow-hotplug eth0
iface eth0 inet dhcp

EOF"

## Clean up apt
sudo LANG=C chroot $FILESYSTEM_ROOT apt-get clean

## Dump the device to image
sudo umount -d /dev/loop0 || (echo "Failed to umount or detach loopback device 0 before gzip" >&2; exit 1)
gzip -c < $device_file > $OUTPUT_FILE
