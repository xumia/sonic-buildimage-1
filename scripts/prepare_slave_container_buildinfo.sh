#!/bin/bash

SLAVE_DIR=$1

BUILDINFO=$SLAVE_DIR/buildinfo
BUILD_VERSIONS_PATH=$SLAVE_DIR/buildinfo/build/versions
VERSION_DEB_PREFERENCE=$BUILD_VERSIONS_PATH/versions/01-versions-deb

cp -rf $SLAVE_DIR/buildinfo/* /usr/local/share/buildinfo/

[ -d /usr/local/share/buildinfo/versions ] && rm -rf /usr/local/share/buildinfo/versions
mkdir -p /usr/local/share/buildinfo/versions
cp -rf $BUILD_VERSIONS_PATH/* /usr/local/share/buildinfo/versions/

rm -f /etc/apt/preferences.d/01-versions-deb
[ -d $VERSION_DEB_PREFERENCE ] && cp -f $VERSION_DEB_PREFERENCE /etc/apt/preferences.d/
