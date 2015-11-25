#!/usr/bin/env python
## Script to list partition information and set the boot partition

import re
import os
import sys
import commands
import argparse
import logging
import tempfile

logging.basicConfig(level=logging.WARN)
logger = logging.getLogger(__name__)

re_fixedp = r'\d*\.\d+|\d+'
re_hex = r'[0-9A-F]'

def runcmd(cmd):
    logger.info('runcmd: {0}'.format(cmd))
    rc, out = commands.getstatusoutput(cmd)
    if rc == 0:
        return out
    else:
        logger.error('Failed to run: {0}\n{1}'.format(cmd, out))
        return None

def print_partitions(blkdev):
    assert blkdev
    out = runcmd('sudo sgdisk -p {0}'.format(blkdev))
    ## Parse command output and print
    found_table = False
    for line in out.splitlines():
        if re.match(r'Number\s+Start\s+\S+\s+End\s+\S+\s+Size\s+Code\s+Name', line):
            logger.info('Got the table head!')
            found_table = True
            continue
        if not found_table: continue
        
        ## Parse the table
        m = re.match(r'\s*(\d+)\s+(\d+)\s+(\d+)\s+({0}) \wiB\s+({1}+)\s+(\S+)'.format(re_fixedp, re_hex), line)
        if not m:
            logger.warn('Unexpected sgdisk output: %s', line)
            break
        index = m.group(1)
        label = m.group(6)
        print index, label
   
## Get the current boot partition index
def get_boot_partition(blkdev):
    out = runcmd('cat /proc/mounts')
    if out is None: return None
    
    ## Parse command output and return the current boot partition index
    for line in out.splitlines():
        m = re.match(r'{0}(\d+) / .*'.format(blkdev), line)
        if not m: continue
        index = m.group(1)
        return int(index)
    else:
        logger.error('Unexpected /proc/mounts output: %s', out)
        return None
    
def set_boot_partition(blkdev, index):
    ## Mount the partition
    assert index is not None
    devnode = blkdev + str(index)
    mntpath = tempfile.mkdtemp()
    try:
        out = runcmd('sudo mount {0} {1}'.format(devnode, mntpath))
        logger.info('mount out={0}'.format(out))
        if out is None: return
        ## Set GRUB bootable
        out = runcmd('sudo grub-install --boot-directory="{0}" --recheck "{1}"'.format(mntpath, blkdev))
        if out is None: return
    finally:
        ## Cleanup
        out = runcmd('sudo fuser -km {0} || sudo umount {0}'.format(mntpath))
        logger.info('fuser out={0}'.format(out))
        os.rmdir(mntpath)
    
def main():
    parser = argparse.ArgumentParser(description='The default output is a list of partition information.')
    parser.add_argument('-i', '--index', type=int,
        help='Set the index partition as boot partition. After reboot, GRUB will boot from that partion.')
    parser.add_argument("-v", "--verbose", action="store_true",
        help="increase output verbosity")
    args = parser.parse_args()

    if args.verbose:
        logger.setLevel(logging.INFO)
    
    ## Find ONIE partition and get the block device containing ONIE
    out = runcmd("sudo blkid")
    if not out: return -1
    for line in out.splitlines():
        m = re.match(r'/dev/(\w+)\d+: LABEL="ONIE-BOOT"', line)
        if not m: continue
        blkdev = '/dev/' + m.group(1)
        logger.info('blkdev = {0}'.format(blkdev))
        break
    else:
        logger.error('Cannot find block device containing ONIE')
        return -1
        
    cur = get_boot_partition(blkdev)
    print 'Current rootfs partition is: {0}'.format(cur)
    
    ## Handle the command line
    if args.index is None:
        print_partitions(blkdev)
    elif args.index > 0:
        logger.info("cur={0}".format(cur))
        if cur is None: return -1
        if cur == args.index:
            logger.info('No action needed, the partition is already the boot partition.')
        else:
            set_boot_partition(blkdev, args.index)
    else:
        logger.error('Index should be large than 0.')
    
if __name__ == "__main__":
    rc = main()
    sys.exit(rc)
