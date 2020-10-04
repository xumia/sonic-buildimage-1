#!/bin/bash

TARGET=$1
FILESYSTEM_ROOT=$2
VERSIONS_PATH=$TARGET/versions/host-versions

mkdir -p $VERSIONS_PATH

sudo LANG=C chroot $FILESYSTEM_ROOT post_run_buildinfo

cp $FILESYSTEM_ROOT/usr/local/share/buildinfo/diff-versions/* $VERSIONS_PATH/
