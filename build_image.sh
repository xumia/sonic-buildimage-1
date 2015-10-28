#!/bin/bash

DEMO_SYSROOT_CPIO=fsroot.cpio
DEMO_SYSROOT_CPIO_XZ=demo.initrd

## Note: Do NOT use fakeroot because 'cpio --create' will lose file and directory ownership
sudo ./make-sysroot.sh ./make-devices.pl fsroot ../$DEMO_SYSROOT_CPIO
xz --compress --force --check=crc32 --stdout -8 $DEMO_SYSROOT_CPIO > $DEMO_SYSROOT_CPIO_XZ
CONSOLE_SPEED=9600 \
CONSOLE_DEV=0 \
CONSOLE_FLAG=0 \
CONSOLE_PORT=0x3f8 \
./onie-mk-demo.sh x86_64 dell_s6000_s1220 x86_64-dell_s6000_s1220-r0 \
      installer s6000/platform.conf acs.bin OS $DEMO_SYSROOT_CPIO_XZ
