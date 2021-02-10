#!/bin/bash -e

NFS_MOUNT_POINT=$1
NFS_VOLUMN=$2

sudo mkdir -p $NFS_MOUNT_POINT
if ! grep -q "$NFS_MOUNT_POINT" /etc/fstab; then
    if [ ! -e $NFS_MOUNT_POINT ]; then
      sudo mkdir $NFS_MOUNT_POINT
    fi
    echo "$NFS_VOLUMN   $NFS_MOUNT_POINT    nfs rw,rsize=1048576,wsize=1048576,vers=4.1,tcp,nosuid  0   0" | sudo tee -a /etc/fstab
    sudo mount -a
    sudo chmod 777 $NFS_MOUNT_POINT
fi

if ! mount | grep -q "$NFS_MOUNT_POINT"; then
    echo "Failed to mount $NFS_MOUNT_POINT" 1>&2
    exit 1
fi

# Validate the permission
TMP_FILE=$NFS_MOUNT_POINT/_tmp_$HOSTNAME
if ! touch $TMP_FILE; then
    echo "Failed to create $TMP_FILE" 1>&2
    exit 1
fi
if ! rm $TMP_FILE; then
    echo "Failed to remove $TMP_FILE" 1>&2
    exit 1
fi
