#!/bin/sh

#  Copyright (C) 2014 Curt Brune <curt@cumulusnetworks.com>
#  Copyright (C) 2014 david_yang <david_yang@accton.com>
#
#  SPDX-License-Identifier:     GPL-2.0

# This script generates a cpio archive of the final sysroot.
#
# The script is run as the "root" user inside of a fakeroot
# environment.
#
# Under fakeroot this script creates all of the required device files.

device_script="$1"
[ -x "$device_script" ] || {
    echo "ERROR: Invalid device creation script: $device_script"
    exit 1
}

##echo "==== Installing the basic set of devices ===="
##rm -rf ${sysroot}/dev
##mkdir -p ${sysroot}/dev
##$device_script $sysroot
