#!/bin/bash

FILESYSTEM_ROOT=./fsroot
OUTPUT_FILE=fs.tar.gz

[ -d $FILESYSTEM_ROOT ] && sudo rm -r $FILESYSTEM_ROOT
mkdir -p $FILESYSTEM_ROOT
echo '[INFO] Debootstrap...'
sudo debootstrap --arch amd64 jessie $FILESYSTEM_ROOT http://ftp.us.debian.org/debian
sudo LANG=C.UTF-8 chroot $FILESYSTEM_ROOT apt-get -y update
echo '[INFO] Install aptitude'
sudo LANG=C.UTF-8 chroot $FILESYSTEM_ROOT apt-get -y install aptitude

## Create device files
sudo LANG=C.UTF-8 chroot $FILESYSTEM_ROOT /bin/bash -c 'echo "proc $MY_CHROOT/proc proc defaults 0 0" >> /etc/fstab'
sudo LANG=C.UTF-8 chroot $FILESYSTEM_ROOT /bin/bash -c 'echo "sysfs $MY_CHROOT/sys sysfs defaults 0 0" >> /etc/fstab'
echo '[INFO] Mount all'
sudo LANG=C.UTF-8 chroot $FILESYSTEM_ROOT mount none /proc -t proc
sudo LANG=C.UTF-8 chroot $FILESYSTEM_ROOT mount sysfs $MY_CHROOT/sys -t sysfs
echo '[INFO] Install makedev'
sudo LANG=C.UTF-8 chroot $FILESYSTEM_ROOT apt-get -y install makedev
echo '[INFO] MAKEDEV'
sudo LANG=C.UTF-8 chroot $FILESYSTEM_ROOT /bin/bash -c 'cd /dev && MAKEDEV generic'
echo '[INFO] Install linux-image-amd64'
sudo LANG=C.UTF-8 chroot $FILESYSTEM_ROOT apt-get -y install linux-image-amd64

## Umount all
echo '[INFO] Umount all'
sudo umount $FILESYSTEM_ROOT/sys
sudo umount $FILESYSTEM_ROOT/proc

## Create root password
## You may get a crypted password by: perl -e 'print crypt("<PaSsWoRd>", "salt"),"\n"'
sudo LANG=C.UTF-8 chroot $FILESYSTEM_ROOT /bin/bash -c 'echo "root:sahL5d5V.UWtI" | chpasswd -e'

#aptitude -q -R --schedule-only install $(awk < aptlist.txt '{print $1}')    ## Mark install the packages at specified versions
##aptitude -q -R --schedule-only install $(awk -F'[= ]' '{ print $1 }' < aptlist.txt)    ## Mark install the packages by names and ignore the versions
#aptitude -q -R --schedule-only markauto $(awk -F'[= ]' 'match($3, /A/){ print $1 }' < aptlist.txt)   ## Mark some packages as automatic installing
#aptitude -y -o Dpkg::Options::="--force-confdef" install  ## Truly install the packages, will prompt several dialog to save old config

## Need sudo to compress because of the dev files
echo '[INFO] Compress the file system into file'
sudo tar czf $OUTPUT_FILE $FILESYSTEM_ROOT
