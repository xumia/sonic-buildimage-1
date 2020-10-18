#!/bin/bash

RET=$1
BLDENV=$2
TARGET_PATH=$3

TIMESTAMP=$(date +"%Y%m%d%H%M%S")
BUILDINFO_PATH="/usr/local/share/buildinfo"
POST_VERSION_PATH="$BUILDINFO_PATH/post-versions"


[ -z "$BLDENV" ] && BLDENV=$(grep VERSION_CODENAME /etc/os-release | cut -d= -f2)
[ -z "$TARGET_PATH" ] && TARGET_PATH=./target

VERSION_BUILD_PATH=$TARGET_PATH/versions/build
VERSION_SLAVE_PATH=$VERSION_BUILD_PATH/sonic-slave-${BLDENV}
LOG_VERSION_PATH=$VERSION_BUILD_PATH/log-${TIMESTAMP}

sudo chmod a+rw $BUILDINFO_PATH
collect_version_files $LOG_VERSION_PATH
mkdir -p $VERSION_SLAVE_PATH

scripts/versions_manager.py merge -t $VERSION_SLAVE_PATH -b $LOG_VERSION_PATH -e $POST_VERSION_PATH

exit $RET
