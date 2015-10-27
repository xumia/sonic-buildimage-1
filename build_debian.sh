#!/bin/bash
## This script is to automate the preparation for a debian file system, which will be used for
## a ONIE installation image.

## Workding directory to prepare the file system
FILESYSTEM_ROOT=./fsroot
## Output file name for compressed file system
OUTPUT_FILE=fs.tar.gz
## Default linux user name
DEFAULT_USERNAME=acsadmin
DEFAULT_USERINFO="ACS Admin User,,,"
## You may get a crypted password by: perl -e 'print crypt("<PaSsWoRd>", "salt"),"\n"'
DEFAULT_PASSWORD="sagt7B6m/efN6"

[ -d $FILESYSTEM_ROOT ] && sudo rm -r $FILESYSTEM_ROOT
mkdir -p $FILESYSTEM_ROOT
echo '[INFO] Debootstrap...'
sudo debootstrap --arch amd64 jessie $FILESYSTEM_ROOT http://ftp.us.debian.org/debian
## Note: set lang to prevent locale warnings in your chroot
sudo LANG=C chroot $FILESYSTEM_ROOT apt-get -y update

## Create device files
sudo LANG=C chroot $FILESYSTEM_ROOT /bin/bash -c 'echo "proc /proc proc defaults 0 0" >> /etc/fstab'
sudo LANG=C chroot $FILESYSTEM_ROOT /bin/bash -c 'echo "sysfs /sys sysfs defaults 0 0" >> /etc/fstab'
echo '[INFO] Mount all'
sudo LANG=C chroot $FILESYSTEM_ROOT mount none /proc -t proc
sudo LANG=C chroot $FILESYSTEM_ROOT mount sysfs /sys -t sysfs
echo '[INFO] Install makedev'
sudo LANG=C chroot $FILESYSTEM_ROOT apt-get -y install makedev
echo '[INFO] MAKEDEV'
sudo LANG=C chroot $FILESYSTEM_ROOT /bin/bash -c 'cd /dev && MAKEDEV generic'
echo '[INFO] Install linux-image-amd64'
sudo LANG=C chroot $FILESYSTEM_ROOT apt-get -y install linux-image-amd64

## Umount all
echo '[INFO] Umount all'
sudo umount $FILESYSTEM_ROOT/sys
sudo umount $FILESYSTEM_ROOT/proc

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

## Compress the whole file system into one output file
## Need sudo because of the dev files
## Exclude all virtual files under /proc, even if already umounted, sometimes the busy system delays the umounting
sudo LANG=C chroot $FILESYSTEM_ROOT apt-get clean
echo '[INFO] Compress the file system into file'
sudo tar --exclude $FILESYSTEM_ROOT/proc -czf $OUTPUT_FILE $FILESYSTEM_ROOT
