#!/bin/bash
  
DOCKER_IMAGE=$1
TARGET_PATH=$2

DOCKER_IMAGE_NAME=$(echo $DOCKER_IMAGE | cut -d: -f1)
DOCKER_CONTAINER=$DOCKER_IMAGE_NAME
TARGET_VERSIONS_PATH=$TARGET_PATH/versions/dockers/$DOCKER_IMAGE_NAME

[ -d $TARGET_VERSIONS_PATH ] && rm -rf $TARGET_VERSIONS_PATH
mkdir -p $TARGET_VERSIONS_PATH

docker run --name $DOCKER_CONTAINER --entrypoint /bin/bash $DOCKER_IMAGE
docker cp -L $DOCKER_CONTAINER:/etc/os-release $TARGET_VERSIONS_PATH/
docker cp -L $DOCKER_CONTAINER:/usr/local/share/buildinfo/diff-versions $TARGET_VERSIONS_PATH/
mv $TARGET_VERSIONS_PATH/diff-versions/* $TARGET_VERSIONS_PATH/
rm -rf $TARGET_VERSIONS_PATH/diff-versions
docker container rm $DOCKER_CONTAINER
