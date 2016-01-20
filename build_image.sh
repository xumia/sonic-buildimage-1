#!/bin/bash

TARGET_PLATFORM=x86_64
TARGET_MACHINE=generic
ONIEIMAGE_VERSION=r0
DEMO_SYSROOT_IMAGE_GZ=fs.img.gz
OUTPUT_ONIE_IMAGE=acs-$TARGET_PLATFORM.bin

# Retrieval short version of git revision hash for partition metadata
[[ -z $(git status --untracked-files=no -s) ]] || {
    echo "Error: There is local changes not committed to git repo. Cannot get a revision hash for partition metadata."
    exit 1
}
GIT_REVISION=$(git rev-parse --short HEAD)

CONSOLE_SPEED=9600 \
CONSOLE_DEV=0 \
CONSOLE_FLAG=0 \
CONSOLE_PORT=0x3f8 \
./onie-mk-demo.sh $TARGET_PLATFORM $TARGET_MACHINE $TARGET_PLATFORM-$TARGET_MACHINE-$ONIEIMAGE_VERSION \
      installer $TARGET_MACHINE/platform.conf $OUTPUT_ONIE_IMAGE OS $GIT_REVISION $DEMO_SYSROOT_IMAGE_GZ
