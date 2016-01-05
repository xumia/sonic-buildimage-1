#!/bin/bash
## This script is to automate the preparation for a debian file system, which will be used for
## a ONIE installation image.

## Function Definitions
##
## Appends a command to a trap, which is needed because default trap behavior is to replace
## previous trap for the same signal
## - 1st arg:  code to add
## - ref: http://stackoverflow.com/questions/3338030/multiple-bash-traps-for-the-same-signal
_trap_push() {
    local next="$1"
    eval "trap_push() {
        local oldcmd='$(echo "$next" | sed -e s/\'/\'\\\\\'\'/g)'
        local newcmd=\"\$1; \$oldcmd\"
        trap -- \"\$newcmd\" EXIT INT TERM HUP
        _trap_push \"\$newcmd\"
    }"
}
_trap_push true

## Enable debug output for script
set -x

## Working directory to prepare the file system
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
ONIE_IMAGE_VOLUME_LABEL="ACS-OS"
## Partition size in MB
ONIE_IMAGE_PART_SIZE=2048

## Prepare a virtual block device
device_file=$(mktemp)
trap_push 'sudo rm $device_file'

## Find first unused loop device
loop_device=$(sudo losetup -f)

## Create a file with all zero content. It will hold all the content of the file system
dd if=/dev/zero of=$device_file bs=512 count=$((2 * $ONIE_IMAGE_PART_SIZE))k
## Connect loop device to the file
trap_push 'sudo losetup -d $loop_device || true'
sudo losetup $loop_device $device_file || (echo "Failed to connect loop device 0" >&2; exit 1)
## Create filesystem on the device with a label
sudo mkfs.ext4 -L $ONIE_IMAGE_VOLUME_LABEL $loop_device || (echo "Error: Unable to create file system on $loop_device" >&2; exit 1)
## Mount the loop device
[ -d $FILESYSTEM_ROOT ] && sudo rmdir $FILESYSTEM_ROOT
mkdir -p $FILESYSTEM_ROOT
## Note: NO fuser here, otherwise it kills the script itself
trap_push 'sudo umount -d $loop_device || true'
sudo mount -t ext4 $loop_device $FILESYSTEM_ROOT

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
sudo LANG=C chroot $FILESYSTEM_ROOT apt-get -y install initramfs-tools linux-base
sudo LANG=C dpkg --root=$FILESYSTEM_ROOT -i deps/linux-image-3.16.0-4-amd64_*_amd64.deb

## Install docker
echo '[INFO] Install dcoker'
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
    screen                  \
    tcpdump                 \
    ntp                     \
    openssh-server          \
    python                  \
    python-apt              \
    python-pip              \
    gdisk                   \
    parted

## docker-py is needed by Ansible docker module
sudo LANG=C chroot $FILESYSTEM_ROOT pip install docker-py
    
## Pre-install grub for image OS future partition manipulation
## Note: DEBIAN_FRONTEND is needed to prvent interactive configuration for grub-pc
## Note: grub2 is needed for grub-install in install.sh
sudo LANG=C DEBIAN_FRONTEND=noninteractive chroot $FILESYSTEM_ROOT apt-get -y install grub-pc grub2

echo '[INFO] Install apt-transport-sftp package from deps directory'
sudo LANG=C chroot $FILESYSTEM_ROOT apt-get -y install libssh2-1
sudo LANG=C dpkg --root=$FILESYSTEM_ROOT -i deps/apt-transport-sftp_*.deb

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
sudo fuser -km $loop_device
sudo umount -d $loop_device || (echo "Failed to umount or detach loop device 0 before gzip" >&2; exit 1)
gzip -c < $device_file > $OUTPUT_FILE
