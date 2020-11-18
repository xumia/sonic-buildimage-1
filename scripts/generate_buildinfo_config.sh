#!/bin/bash

BUILDINFO_PATH=files/build

TRUSTED_GPG_PATH=$BUILDINFO_PATH/buildinfo/trusted.gpg.d
BUILDINFO_CONFIG=$BUILDINFO_PATH/buildinfo/config/buildinfo.config

[ -d $TRUSTED_GPG_PATH ] && rm -rf $TRUSTED_GPG_PATH
mkdir -p $TRUSTED_GPG_PATH
mkdir -p $BUILDINFO_PATH/buildinfo/config

echo "PACKAGE_URL_PREFIX=$PACKAGE_URL_PREFIX" > $BUILDINFO_CONFIG
echo "SONIC_VERSION_CONTROL_COMPONENTS=$SONIC_VERSION_CONTROL_COMPONENTS" >> $BUILDINFO_CONFIG


# Download trusted gpgs
for url in $(echo $TRUSTED_GPG_URLS | sed 's/[,;]/ /g')
do
    wget -q "$url" -P "$TRUSTED_GPG_PATH/"
done
