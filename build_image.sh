#!/bin/bash

DEMO_SYSROOT_IMAGE_GZ=fs.img.gz

## Note: Do NOT use fakeroot because 'cpio --create' will lose file and directory ownership
sudo ./make-sysroot.sh ./make-devices.pl

CONSOLE_SPEED=9600 \
CONSOLE_DEV=0 \
CONSOLE_FLAG=0 \
CONSOLE_PORT=0x3f8 \
./onie-mk-demo.sh x86_64 dell_s6000_s1220 x86_64-dell_s6000_s1220-r0 \
      installer s6000/platform.conf acs.bin OS $DEMO_SYSROOT_IMAGE_GZ
