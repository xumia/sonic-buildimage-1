#!/bin/bash

BUILDINFO_PATH=$1

TRUSTED_GPG_PATH=$BUILDINFO_PATH/trusted.gpg.d
BUILDINFO_CONFIG=$BUILDINFO_PATH/config/buildinfo.config

AUTO_GENERATE_CODE_TEXT="Begin Auto-Generated Code"
DOCKERFILE_TEMPLATE="files/build/templates/dockerfile_auto_generate.j2"

mkdir -p $TRUSTED_GPG_PATH
mkdir -p $BUILDINFO_PATH/config

# Generate build info config file
echo "SONIC_ENFORCE_VERSIONS=${SONIC_ENFORCE_VERSIONS}" > $BUILDINFO_CONFIG
echo "PACKAGE_URL_PREFIX=${PACKAGE_URL_PREFIX}" >> $BUILDINFO_CONFIG

# Download trusted gpgs
for url in $(echo $TRUSTED_GPG_URLS | sed 's/[,;]/ /g')
do
    wget -q "$url" -P "$TRUSTED_GPG_PATH/"
done

# Generate version lock files
#scripts/generate_version_lock_files.py -t "$BUILDINFO_VERSION_PATH" -o "$DOCKERFILE_PATH" -d "$DISTRO" -a "$ARCH"
