#!/bin/bash -e

MOUNTPOINT=$1
STORAGE_ACCOUNT=$2
CONTAINER_NAME=$3
STORAGE_ACCOUNT_SASTOKEN=$4
TEMPPATH=$5

if ! mount | grep -q "$MOUNTPOINT "; then
    if [ ! -e $MOUNTPOINT ]; then
     sudo mkdir -p "$MOUNTPOINT"
     sudo chmod a+rw "$MOUNTPOINT"
    fi
    
    export AZURE_STORAGE_ACCOUNT="$STORAGE_ACCOUNT"
    export AZURE_STORAGE_SAS_TOKEN="$STORAGE_ACCOUNT_SASTOKEN"
    sudo -E blobfuse "$MOUNTPOINT" --container-name="$CONTAINER_NAME" --tmp-path="$TEMPPATH" -o attr_timeout=240 -o entry_timeout=240 -o negative_timeout=120 -o allow_other
fi

# Validate the mount results
if ! mount | grep -q "$MOUNTPOINT "; then
    echo "Failed to mount $MOUNTPOINT" 1>&2
    exit 1
fi
