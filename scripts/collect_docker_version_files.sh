#!/bin/bash

DOCKER_IMAGE=$1
TARGET_PATH=$2
TARGET_PATH_ABS=$(realpath $TARGET_PATH)

MOUNT_POINT=/share
DOCKER_IMAGE_NAME=$DOCKER_IMAGE
DOCKER_VERSIONS=versions/dockers/$DOCKER_IMAGE_NAME
DOCKER_VERSIONS_PATH=/$MOUNT_POINT/$DOCKER_VERSIONS


mkdir -p $TARGET_PATH/$DOCKER_VERSIONS

docker run -v $TARGET_PATH_ABS:$MOUNT_POINT --rm --entrypoint /bin/bash $DOCKER_IMAGE -c "cp /etc/os-release /usr/local/share/buildinfo/diff-versions/* $DOCKER_VERSIONS_PATH/"
