#!/bin/bash
## This script is to automate the preparation for a debian file system, which will be used for
## a ONIE installation image.

. functions.sh

## Enable debug output for script
set -x -e

## Working directory to prepare the file system
FILESYSTEM_ROOT=./fsroot
## Hostname for the linux image
HOSTNAME=acs
## Default user
DEFAULT_USERNAME=acsadmin
DEFAULT_USERINFO="ACS Admin User,,,"
## Default password for the default user
## You may get a crypted password by: perl -e 'print crypt("<PaSsWoRd>", "salt"),"\n"'
DEFAULT_PASSWORD="sahL5d5V.UWtI"

## Read ONIE image related config file
. ./onie-image.conf
[ -n "$ONIE_IMAGE_PART_SIZE" ] || {
    echo "Error: Invalid ONIE_IMAGE_PART_SIZE in onie image config file"
    exit 1
}
[ -n "$ONIE_INSTALLER_PAYLOAD" ] || {
    echo "Error: Invalid ONIE_INSTALLER_PAYLOAD in onie image config file"
    exit 1
}
[ -n "$FILESYSTEM_SQUASHFS" ] || {
    echo "Error: Invalid FILESYSTEM_SQUASHFS in onie image config file"
    exit 1
}

## Prepare the chroot directory
if [[ -d $FILESYSTEM_ROOT ]]; then
    sudo rm -r $FILESYSTEM_ROOT || die "Failed to clean chroot directory"
fi
mkdir -p $FILESYSTEM_ROOT

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
## Output all the mounted device for troubleshooting
mount
trap_push 'sudo umount $FILESYSTEM_ROOT/proc || true'
sudo LANG=C chroot $FILESYSTEM_ROOT mount proc /proc -t proc
clean_sys() {
    sudo umount $FILESYSTEM_ROOT/sys/fs/cgroup/*            \
                $FILESYSTEM_ROOT/sys/fs/cgroup              \
                $FILESYSTEM_ROOT/sys || true
}
trap_push 'sudo umount $FILESYSTEM_ROOT/sys || true'
sudo LANG=C chroot $FILESYSTEM_ROOT mount sysfs /sys -t sysfs

## Note: set lang to prevent locale warnings in your chroot
sudo LANG=C chroot $FILESYSTEM_ROOT apt-get -y update
echo '[INFO] Install packages for building image'
sudo LANG=C chroot $FILESYSTEM_ROOT apt-get -y install makedev psmisc

echo '[INFO] MAKEDEV'
sudo LANG=C chroot $FILESYSTEM_ROOT /bin/bash -c 'cd /dev && MAKEDEV generic'
echo '[INFO] Install ACS linux kernel image'
## Note: initramfs-tools recommended depends on busybox, and we really want it for commands such as touch
sudo LANG=C chroot $FILESYSTEM_ROOT apt-get -y install busybox
sudo LANG=C dpkg --root=$FILESYSTEM_ROOT -i deps/{initramfs-tools_,linux-image-3.16.0-4-amd64_}*.deb || \
    sudo LANG=C DEBIAN_FRONTEND=noninteractive chroot $FILESYSTEM_ROOT apt-get -y install -f

## Update initramfs for booting with squashfs+aufs
cat >> $FILESYSTEM_ROOT/etc/initramfs-tools/modules <<EOF
squashfs
aufs
EOF
chroot $FILESYSTEM_ROOT update-initramfs -u

## Install docker
echo '[INFO] Install docker'
curl -sSL https://get.docker.com/ | sudo LANG=C chroot $FILESYSTEM_ROOT sh
## Remove garbage left by docker installation script
sudo rm $FILESYSTEM_ROOT/etc/apt/sources.list.d/docker.list
sudo chroot $FILESYSTEM_ROOT service docker stop
sudo chroot $FILESYSTEM_ROOT service dbus stop

## Umount all
echo '[INFO] Umount all'
sudo LANG=C chroot $FILESYSTEM_ROOT fuser -km /sys || true
sudo LANG=C chroot $FILESYSTEM_ROOT umount -lf /sys
sudo LANG=C chroot $FILESYSTEM_ROOT fuser -km /proc || true
sudo LANG=C chroot $FILESYSTEM_ROOT umount /proc

## Create user for the default user
## Note: user should be in the group with the same name, and also in sudo/docker group
sudo LANG=C chroot $FILESYSTEM_ROOT useradd -G sudo,docker $DEFAULT_USERNAME -c "$DEFAULT_USERINFO" -m -s /bin/bash
## Create password for the default user
sudo LANG=C chroot $FILESYSTEM_ROOT /bin/bash -c "echo $DEFAULT_USERNAME:$DEFAULT_PASSWORD | chpasswd -e"

## Pre-install the fundamental packages
## Note: gdisk is needed for sgdisk in install.sh
## Note: parted is needed for partprobe in install.sh
sudo LANG=C chroot $FILESYSTEM_ROOT apt-get -y install      \
    sudo                    \
    vim                     \
    tcpdump                 \
    ntp                     \
    openssh-server          \
    python                  \
    python-setuptools       \
    python-apt              \
    gdisk                   \
    parted                  \
    efibootmgr

## docker-py is needed by Ansible docker module
sudo LANG=C chroot $FILESYSTEM_ROOT easy_install pip
sudo LANG=C chroot $FILESYSTEM_ROOT pip install 'docker-py==1.6.0'
## Remove pip which is unnecessary in the base image
sudo LANG=C chroot $FILESYSTEM_ROOT pip uninstall -y pip

## Pre-install grub for image OS future partition manipulation
## Note: DEBIAN_FRONTEND is needed to prvent interactive configuration for grub-pc
## Note: grub2 is needed for grub-install in install.sh
sudo LANG=C DEBIAN_FRONTEND=noninteractive chroot $FILESYSTEM_ROOT apt-get -y install grub-pc grub2

echo '[INFO] Install apt-transport-sftp package from deps directory'
sudo LANG=C chroot $FILESYSTEM_ROOT apt-get -y install libssh2-1
sudo LANG=C dpkg --root=$FILESYSTEM_ROOT -i deps/apt-transport-sftp_*.deb

## Pre-install kernel related packages of the Azure Cloud Switch into the host file system
sudo LANG=C dpkg --root=$FILESYSTEM_ROOT -i deps/opennsl-modules-*.deb || die "Failed to install opennsl-modules"

## Config DHCP for eth0
sudo LANG=C chroot $FILESYSTEM_ROOT /bin/bash -c "cat <<EOF >> /etc/network/interfaces

auto eth0
allow-hotplug eth0
iface eth0 inet dhcp

EOF"

## Clean up apt
sudo LANG=C chroot $FILESYSTEM_ROOT apt-get autoremove
sudo LANG=C chroot $FILESYSTEM_ROOT apt-get clean
sudo LANG=C chroot $FILESYSTEM_ROOT rm -rf /tmp/*

## Dump chroot tree excluding /boot to squashfs file, and compress it together with /boot as a installer payload zip file
rm -f $ONIE_INSTALLER_PAYLOAD $FILESYSTEM_SQUASHFS
sudo mksquashfs $FILESYSTEM_ROOT $FILESYSTEM_SQUASHFS -e boot
pushd $FILESYSTEM_ROOT/boot && zip -r $OLDPWD/$ONIE_INSTALLER_PAYLOAD . ; popd
zip -g $ONIE_INSTALLER_PAYLOAD $FILESYSTEM_SQUASHFS
