#!/bin/bash

BUILDINFO_PATH=files/build

TRUSTED_GPG_PATH=$BUILDINFO_PATH/buildinfo/trusted.gpg.d
BUILDINFO_CONFIG=$BUILDINFO_PATH/buildinfo/config/buildinfo.config
BUILDINFO_CONFIG_TEMPLATE=$BUILDINFO_PATH/templates/buildinfo.config.j2

AUTO_GENERATE_CODE_TEXT="Begin Auto-Generated Code"
DOCKERFILE_TEMPLATE="files/build/templates/dockerfile_auto_generate.j2"

[ -d $TRUSTED_GPG_PATH ] && rm -rf $TRUSTED_GPG_PATH
mkdir -p $TRUSTED_GPG_PATH
mkdir -p $BUILDINFO_PATH/buildinfo/config

# Generate build info config file
SONIC_ENABLE_VERSION_CONTROL=${SONIC_ENABLE_VERSION_CONTROL} \
PACKAGE_URL_PREFIX=${PACKAGE_URL_PREFIX} \
j2  $BUILDINFO_CONFIG_TEMPLATE > $BUILDINFO_CONFIG



# Download trusted gpgs
for url in $(echo $TRUSTED_GPG_URLS | sed 's/[,;]/ /g')
do
    wget -q "$url" -P "$TRUSTED_GPG_PATH/"
done
